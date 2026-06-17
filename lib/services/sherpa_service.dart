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
import 'settings_service.dart';
import 'openai_service.dart';

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
  final _summaries = <String, String>{};
  bool _auto = false;
  bool _isRunning = false;
  int _pollInterval = 30;
  RecordingService? _recordingService;
  SettingsService? _settingsService;
  Timer? _poller;

  bool get ready => ModelManager.I.status == ModelStatus.ready;
  bool get auto => _auto;
  bool get isRunning => _isRunning;
  int get pollInterval => _pollInterval;
  bool get canSummarize => _settingsService?.enableSummarization == true && (_settingsService?.apiKey.isNotEmpty == true);

  /// 注入服务引用
  void setRecordingService(RecordingService rs) => _recordingService = rs;
  void setSettingsService(SettingsService ss) => _settingsService = ss;

  /// 从外部加载已有转写结果（如从 JSON 元数据恢复）
  void loadResult(String uri, String txt) => _results[uri] = txt;

  String? text(String uri) => _results[uri];
  String? summary(String uri) => _summaries[uri];

  Future<void> init() async {
    await _loadState();
    ModelManager.I.addListener(_onModelChanged);
    await ModelManager.I.init();
    // 如果模型已就绪且自动转写已开启，启动轮询
    _syncPoller();
    // 延迟加载已持久化的 AI 摘要（等录音列表加载完毕）
    Future.delayed(const Duration(seconds: 1), _loadSummaries);
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

      // 自动触发 AI 总结
      final settings = _settingsService;
      if (settings != null && settings.enableSummarization && settings.apiKey.isNotEmpty && t.isNotEmpty) {
        _summaries[uri] = '...';
        notifyListeners();
        final s = await OpenAIService.I.summarize(
          apiKey: settings.apiKey,
          baseUrl: settings.apiBaseUrl,
          model: settings.summarizeModel,
          transcription: t,
        );
        if (s != null) {
          _summaries[uri] = s;
          final written = await NativeBridge.instance.writeSummary(uri, s);
          debugPrint('AI 摘要完成: ${s.length} 字, 回写JSON: $written');
          notifyListeners();
        } else {
          _summaries.remove(uri);
          notifyListeners();
        }
      }
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

  /// 从本地 JSON 元数据中恢复已保存的 AI 摘要
  Future<void> _loadSummaries() async {
    final recordings = _recordingService?.allRecordings;
    if (recordings == null || recordings.isEmpty) return;
    for (final r in recordings) {
      final s = await NativeBridge.instance.readSummary(r.path);
      if (s != null && s.isNotEmpty) {
        _summaries[r.path] = s;
      }
    }
    notifyListeners();
  }

  /// 刷新摘要缓存并通知 UI
  Future<void> refreshSummaries() => _loadSummaries();

  /// 手动触发 AI 总结（供 UI 按钮调用）
  Future<void> summarize(String uri) async {
    final settings = _settingsService;
    if (settings == null || settings.apiKey.isEmpty || !settings.enableSummarization) return;
    final t = text(uri);
    if (t == null || t.isEmpty || t == '...') return;

    _summaries[uri] = '...';
    notifyListeners();

    final s = await OpenAIService.I.summarize(
      apiKey: settings.apiKey,
      baseUrl: settings.apiBaseUrl,
      model: settings.summarizeModel,
      transcription: t,
    );
    if (s != null) {
      _summaries[uri] = s;
      final written = await NativeBridge.instance.writeSummary(uri, s);
      debugPrint('AI 摘要完成: ${s.length} 字, 回写JSON: $written');
    } else {
      _summaries.remove(uri);
    }
    notifyListeners();
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
