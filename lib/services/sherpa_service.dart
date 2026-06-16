/// 离线语音转写 — Sherpa-ONNX + SenseVoice
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'native_bridge.dart';
import 'model_manager.dart';
import 'recording_service.dart';

/// Isolate 入口 — 在后台线程执行 Sherpa 推理，避免阻塞 UI 导致 ANR
String _transcribeIsolate((String, String, Float32List) args) {
  final (modelPath, tokensPath, pcm) = args;
  initBindings();
  final rec = OfflineRecognizer(OfflineRecognizerConfig(
    model: OfflineModelConfig(
      senseVoice: OfflineSenseVoiceModelConfig(model: modelPath, useInverseTextNormalization: true),
      tokens: tokensPath,
      numThreads: 2,
    ),
  ));
  final stream = rec.createStream();
  stream.acceptWaveform(samples: pcm, sampleRate: 16000);
  rec.decode(stream);
  final txt = rec.getResult(stream).text;
  stream.free();
  rec.free();
  return txt;
}

class SherpaService extends ChangeNotifier {
  SherpaService._singleton();
  static final SherpaService I = SherpaService._singleton();

  final _results = <String, String>{};
  bool _auto = false;
  bool _isRunning = false;
  int _pollInterval = 30;
  RecordingService? _recordingService;
  Timer? _poller;

  bool get ready => ModelManager.I.status == ModelStatus.ready;
  bool get auto => _auto;
  bool get isRunning => _isRunning;
  int get pollInterval => _pollInterval;

  /// 注入录音服务引用（用于轮询时获取录音列表）
  void setRecordingService(RecordingService rs) => _recordingService = rs;

  /// 从外部加载已有转写结果（如从 JSON 元数据恢复）
  void loadResult(String uri, String txt) => _results[uri] = txt;

  String? text(String uri) => _results[uri];

  Future<void> init() async {
    await _loadState();
    ModelManager.I.addListener(_onModelChanged);
    await ModelManager.I.init();
    // 如果模型已就绪且自动转写已开启，启动轮询
    _syncPoller();
  }

  void _onModelChanged() {
    _syncPoller();
    notifyListeners();
  }

  void setAuto(bool v) {
    if (_auto == v) return;
    _auto = v;
    _saveState();
    _syncPoller();
    notifyListeners();
  }

  void setPollInterval(int v) {
    if (_pollInterval == v || v < 10 || v > 3600) return;
    _pollInterval = v;
    _saveState();
    _syncPoller();
    notifyListeners();
  }

  /// 根据 _auto 和 ready 状态启停轮询定时器
  void _syncPoller() {
    _poller?.cancel();
    if (_auto && ready) {
      _poller = Timer.periodic(
        Duration(seconds: _pollInterval),
        (_) => _poll(),
      );
      // 立即执行一次
      _poll();
    } else {
      _poller = null;
    }
  }

  /// 扫描录音列表，对第一个未转写文件进行转写
  Future<void> _poll() async {
    if (!_auto || !ready || _isRunning) return;
    final recordings = _recordingService?.allRecordings;
    if (recordings == null || recordings.isEmpty) return;

    for (final r in recordings) {
      if (_results[r.path] == null) {
        await _transcribeOne(r.path, r.filename);
        return; // 逐个转写，下次轮询处理下一个
      }
    }
  }

  /// 转写单个文件并发送通知
  Future<void> _transcribeOne(String uri, String filename) async {
    await NativeBridge.instance.showTranscriptionNotification(
      type: 'progress',
      title: 'ACR 语音转写',
      body: '正在转写: $filename',
    );
    final ok = await run(uri, notify: false);
    if (ok) {
      final t = text(uri) ?? '';
      await NativeBridge.instance.showTranscriptionNotification(
        type: 'complete',
        title: '转写完成',
        body: '$filename\n${t.length > 80 ? '${t.substring(0, 80)}…' : t}',
      );
    } else {
      await NativeBridge.instance.showTranscriptionNotification(
        type: 'complete',
        title: '转写失败',
        body: '$filename — 请检查音频文件',
      );
    }
  }

  Future<bool> run(String fileUri, {bool notify = true}) async {
    if (!ready || _isRunning) return false;
    _isRunning = true;
    _results[fileUri] = '...';
    if (notify) notifyListeners();
    try {
      final pcm = await NativeBridge.instance.decodeAudioToPcm(fileUri);
      if (pcm == null || pcm.length < 3200) {
        _results.remove(fileUri);
        if (notify) notifyListeners();
        return false;
      }

      final dir = ModelManager.I.modelDir;
      final txt = await Isolate.run(() =>
          _transcribeIsolate(('$dir/model.onnx', '$dir/tokens.txt', pcm)));

      _results[fileUri] = txt;
      if (notify) notifyListeners();
      final written = await NativeBridge.instance.writeTranscription(fileUri, txt);
      debugPrint('转写完成: ${txt.length} 字, 回写JSON: $written');
      return true;
    } catch (e) {
      _results.remove(fileUri);
      if (notify) notifyListeners();
      debugPrint('转写失败: $e');
      return false;
    } finally {
      _isRunning = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> onDone(String uri) async {
    if (_auto && ready) await run(uri);
  }

  Future<void> _saveState() async {
    try {
      final p = await _path('s');
      await File(p).writeAsString('a:${_auto ? 1 : 0}\ni:$_pollInterval');
    } catch (_) {}
  }

  Future<void> _loadState() async {
    try {
      final p = await _path('s');
      if (File(p).existsSync()) {
        final content = await File(p).readAsString();
        _auto = content.contains('a:1');
        final m = RegExp(r'i:(\d+)').firstMatch(content);
        if (m != null) _pollInterval = int.tryParse(m.group(1)!) ?? 30;
      }
    } catch (_) {}
  }

  Future<String> _path(String n) async =>
      '${(await getApplicationDocumentsDirectory()).path}/sh_$n.txt';

  @override
  void dispose() {
    _poller?.cancel();
    ModelManager.I.removeListener(_onModelChanged);
    super.dispose();
  }
}
