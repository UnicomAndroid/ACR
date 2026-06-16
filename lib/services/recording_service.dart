import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native_bridge.dart';
import 'sherpa_service.dart';

enum RecordingState { idle, recording, paused }
enum PlaybackState { stopped, playing, paused }

class RecordingInfo {
  final String path;
  final String filename;
  final DateTime created;
  final int size;
  final String mimeType;
  final bool isManual;
  final String? direction;

  const RecordingInfo({
    required this.path,
    required this.filename,
    required this.created,
    required this.size,
    this.mimeType = 'audio/x-wav',
    this.isManual = false,
    this.direction,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final m = created.month.toString().padLeft(2, '0');
    final d = created.day.toString().padLeft(2, '0');
    final h = created.hour.toString().padLeft(2, '0');
    final min = created.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}

class RecordingService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  RecordingState _state = RecordingState.idle;
  Duration _duration = Duration.zero;

  PlaybackState _playbackState = PlaybackState.stopped;
  String? _playingPath;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  List<RecordingInfo> _recordings = [];
  List<RecordingInfo> _nativeRecordings = [];
  List<RecordingInfo> get recordings => List.unmodifiable(_recordings);
  List<RecordingInfo> get nativeRecordings => List.unmodifiable(_nativeRecordings);
  List<RecordingInfo> get allRecordings {
    final all = <RecordingInfo>[..._recordings, ..._nativeRecordings];
    all.sort((a, b) => b.created.compareTo(a.created));
    return all;
  }

  String _storagePath = '';
  int _sampleRate = 44100;
  int _bitRate = 128000;

  RecordingService({String storagePath = '', int sampleRate = 44100, int bitRate = 128000})
      : _storagePath = storagePath,
        _sampleRate = sampleRate,
        _bitRate = bitRate {
    _init();
  }

  Future<void> _init() async {
    _player.positionStream.listen((p) { _playbackPosition = p; notifyListeners(); });
    _player.durationStream.listen((d) { _playbackDuration = d ?? Duration.zero; notifyListeners(); });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _playbackState = PlaybackState.stopped; _playbackPosition = Duration.zero; notifyListeners();
      }
    });
    await refreshRecordings();
  }

  RecordingState get state => _state;
  Duration get duration => _duration;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;
  bool get isIdle => _state == RecordingState.idle;
  String get durationFormatted {
    final m = _duration.inMinutes.toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PlaybackState get playbackState => _playbackState;
  String? get playingPath => _playingPath;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isPlaybackPaused => _playbackState == PlaybackState.paused;
  String get playbackPositionFormatted {
    final m = _playbackPosition.inMinutes.toString().padLeft(2, '0');
    final s = (_playbackPosition.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  String get playbackDurationFormatted {
    final m = _playbackDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_playbackDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get storagePath => _storagePath;
  Future<void> setStoragePath(String path) async {
    if (_storagePath == path) return;
    await stopPlayback(); _storagePath = path; notifyListeners(); await refreshRecordings();
  }

  int get sampleRate => _sampleRate;
  void setSampleRate(int v) { if (_sampleRate == v) return; _sampleRate = v; notifyListeners(); }
  int get bitRate => _bitRate;
  void setBitRate(int v) { if (_bitRate == v) return; _bitRate = v; notifyListeners(); }

  Future<Directory> _resolveStorageDir() async {
    if (_storagePath.isNotEmpty) { final d = Directory(_storagePath); if (d.existsSync()) return d; }
    return Directory((await getApplicationDocumentsDirectory()).path);
  }

  Future<void> refreshRecordings() async {
    try {
      final directory = await _resolveStorageDir();
      if (!directory.existsSync()) return;
      _recordings = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.wav')).map((f) {
        final stat = f.statSync();
        return RecordingInfo(path: f.path, filename: f.uri.pathSegments.last, created: stat.changed, size: stat.size);
      }).toList()..sort((a, b) => b.created.compareTo(a.created));
      await refreshNativeRecordings();
      notifyListeners();
    } catch (e) { debugPrint('refreshRecordings: $e'); }
  }

  Future<void> refreshNativeRecordings() async {
    if (!Platform.isAndroid) return;
    try {
      final list = await NativeBridge.instance.getRecordings();
      _nativeRecordings = list.map((m) => RecordingInfo(
        path: m['uri'] as String,
        filename: m['name'] as String? ?? '',
        created: DateTime.fromMillisecondsSinceEpoch(m['date'] as int? ?? 0),
        size: m['size'] as int? ?? 0,
        mimeType: m['mimeType'] as String? ?? 'audio/ogg',
        isManual: m['isManual'] as bool? ?? false,
        direction: m['direction'] as String?,
      )).toList();

      // 从 JSON 元数据加载已有的转写结果
      for (final m in list) {
        final uri = m['uri'] as String;
        final transcription = m['transcription'] as String?;
        if (transcription != null && transcription.isNotEmpty) {
          SherpaService.I.loadResult(uri, transcription);
        }
      }

      notifyListeners();
    } catch (e) { debugPrint('refreshNativeRecordings: $e'); }
  }

  Future<bool> requestPermission() async => (await Permission.microphone.request()).isGranted;
  Future<bool> hasPermission() async => (await Permission.microphone.status).isGranted;

  Future<bool> start() async {
    if (!await hasPermission() && !await requestPermission()) return false;
    if (_state != RecordingState.idle) return false;
    try {
      if (!await NativeBridge.instance.startManualRecording()) return false;
      _state = RecordingState.recording; _duration = Duration.zero; _startPollingNativeState(); notifyListeners();
      return true;
    } catch (e) { debugPrint('start: $e'); _state = RecordingState.idle; notifyListeners(); return false; }
  }

  Timer? _nativeStateTimer;
  void _startPollingNativeState() {
    _nativeStateTimer?.cancel();
    _nativeStateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final s = await NativeBridge.instance.getManualRecordingState();
      final ns = s['state'] as String? ?? 'IDLE';
      _duration = Duration(milliseconds: (s['duration'] as int? ?? 0));
      switch (ns) {
        case 'IDLE': _nativeStateTimer?.cancel(); if (_state != RecordingState.idle) { _state = RecordingState.idle; _duration = Duration.zero; refreshRecordings(); }
        case 'RECORDING': _state = RecordingState.recording;
        case 'PAUSED': _state = RecordingState.paused;
        case 'STOPPING': case 'ERROR': _nativeStateTimer?.cancel(); _state = RecordingState.idle;
      }
      notifyListeners();
    });
  }

  Future<void> pause() async {
    if (_state != RecordingState.recording) return;
    try { await NativeBridge.instance.pauseManualRecording(); notifyListeners(); } catch (e) { debugPrint('pause: $e'); }
  }
  Future<void> resume() async {
    if (_state != RecordingState.paused) return;
    try { await NativeBridge.instance.resumeManualRecording(); notifyListeners(); } catch (e) { debugPrint('resume: $e'); }
  }
  Future<String?> stop() async {
    if (_state == RecordingState.idle) return null;
    try { _nativeStateTimer?.cancel(); await NativeBridge.instance.stopManualRecording(); _state = RecordingState.idle; _duration = Duration.zero; notifyListeners(); await refreshRecordings(); return null; }
    catch (e) { debugPrint('stop: $e'); _state = RecordingState.idle; notifyListeners(); return null; }
  }

  // ---- Playback (just_audio with ExoPlayer — supports content:// URIs) ----
  Future<void> playFile(String path) async {
    if (_playingPath == path) {
      if (_playbackState == PlaybackState.playing) { await _player.pause(); _playbackState = PlaybackState.paused; notifyListeners(); return; }
      if (_playbackState == PlaybackState.paused) { await _player.play(); _playbackState = PlaybackState.playing; notifyListeners(); return; }
    }
    await _player.stop();
    _playingPath = path;
    await _player.setAudioSource(AudioSource.uri(Uri.parse(path)));
    await _player.play();
    _playbackState = PlaybackState.playing;
    notifyListeners();
  }

  Future<void> stopPlayback() async { await _player.stop(); _playingPath = null; _playbackState = PlaybackState.stopped; _playbackPosition = Duration.zero; notifyListeners(); }
  Future<void> togglePlayPause(String path) async => playFile(path);
  Future<void> seek(Duration position) async {
    if (_playbackState == PlaybackState.stopped) return;
    await _player.seek(position); _playbackPosition = position; notifyListeners();
  }

  Future<void> deleteRecording(String path) async {
    try {
      if (_playingPath == path) await stopPlayback();
      if (path.startsWith('content://')) {
        await NativeBridge.instance.deleteRecording(path);
      } else {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
      await refreshRecordings();
    } catch (e) { debugPrint('deleteRecording: $e'); }
  }

  @override void dispose() { _nativeStateTimer?.cancel(); _player.dispose(); super.dispose(); }
}
