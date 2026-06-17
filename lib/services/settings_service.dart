import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_bridge.dart';

/// =============================================================================
/// SettingsService — 全应用设置状态管理
/// =============================================================================
///
/// 管理两类设置：
///   1. Flutter 专属设置 — 仅影响 UI 行为（如主题模式），
///      存储于 Flutter 端 SharedPreferences
///   2. 共享设置 — 通话录音相关参数，通过 [NativeBridge] 与 Android 原生层
///      的 device-protected SharedPreferences 双向同步
///
/// 设置页布局（参照计划）：
///   - 主题设置：theme_mode
///   - 通知：notification_open_dir
///   - 基本设置：format_name / bit_rate / sample_rate / recording_path
///   - 通话录音：call_recording / audio_source / filename_template /
///              min_duration / output_retention / record_rules /
///              record_dialing_state / record_telecom_apps
///   - 关于：force_direct_boot / debug_mode
class SettingsService extends ChangeNotifier {
  // ---- Flutter 专属键 --------------------------------------------------------
  static const _kThemeMode = 'theme_mode';
  static const _kEnableSummarization = 'enable_summarization';
  static const _kApiKey = 'api_key';
  static const _kApiBaseUrl = 'api_base_url';
  static const _kSummarizeModel = 'summarize_model';

  // ---- 实例字段 ---------------------------------------------------------------
  late final SharedPreferences _prefs;

  // Flutter 专属 — 主题
  ThemeMode _themeMode = ThemeMode.system;

  // Flutter 专属 — AI 总结
  bool _enableSummarization = false;
  String _apiKey = '';
  String _apiBaseUrl = 'https://api.openai.com/v1';
  String _summarizeModel = 'gpt-4o-mini';

  // 基本设置（共享）
  String _formatName = 'opus';
  int _bitRate = 128000;
  int _sampleRate = 44100;
  String _recordingPath = '';

  // 通知（共享）
  bool _notificationOpenDir = false;

  // 通话录音（共享）
  bool _callRecording = true;
  String _audioSource = 'voice_call';
  String _filenameTemplate = '';
  int _minDuration = 0;
  int _outputRetention = 0; // 0 = 无限期
  String _recordRules = ''; // JSON 字符串
  bool _recordDialingState = false;
  bool _recordTelecomApps = false;

  // 关于 / 调试（共享）
  bool _forceDirectBoot = false;
  bool _debugMode = false;

  // ---- 工厂构造 ---------------------------------------------------------------

  SettingsService._();

  /// 创建并初始化设置服务。
  ///
  /// 流程：
  /// 1. 从 Flutter SharedPreferences 加载 Flutter 专属设置
  /// 2. 通过 NativeBridge 从原生层拉取共享设置
  /// 3. 如果原生层返回空值，使用默认值
  static Future<SettingsService> create() async {
    final service = SettingsService._();
    service._prefs = await SharedPreferences.getInstance();

    // ---- Flutter 专属设置 ----
    final stored = service._prefs.getInt(_kThemeMode);
    if (stored != null && stored >= 0 && stored < ThemeMode.values.length) {
      service._themeMode = ThemeMode.values[stored];
    }

    // AI 总结
    service._enableSummarization = service._prefs.getBool(_kEnableSummarization) ?? false;
    service._apiKey = service._prefs.getString(_kApiKey) ?? '';
    service._apiBaseUrl = service._prefs.getString(_kApiBaseUrl) ?? 'https://api.openai.com/v1';
    service._summarizeModel = service._prefs.getString(_kSummarizeModel) ?? 'gpt-4o-mini';

    // ---- 从原生层拉取共享设置 ----
    // 此操作仅在实际存在原生层时有效（Android 平台）。
    // iOS / Desktop 平台会跳过，使用默认值。
    if (Platform.isAndroid) {
      await service._pullFromNative();
    }

    return service;
  }

  /// 从原生层拉取所有共享设置
  Future<void> _pullFromNative() async {
    final bridge = NativeBridge.instance;
    final prefs = await bridge.getPreferences();
    if (prefs.isEmpty) return;

    _callRecording = prefs['call_recording'] as bool? ?? true;
    _formatName = prefs['format_name'] as String? ?? 'opus';
    _audioSource = prefs['audio_source'] as String? ?? 'voice_call';
    _filenameTemplate = prefs['filename_template'] as String? ?? '';
    _minDuration = prefs['min_duration'] as int? ?? 0;
    _outputRetention = prefs['output_retention'] as int? ?? 0;
    _recordDialingState = prefs['record_dialing_state'] as bool? ?? false;
    _recordTelecomApps = prefs['record_telecom_apps'] as bool? ?? false;
    _notificationOpenDir = prefs['notification_open_dir'] as bool? ?? false;
    _forceDirectBoot = prefs['force_direct_boot'] as bool? ?? false;
    _debugMode = prefs['debug_mode'] as bool? ?? false;

    // 基本设置（与 Flutter UI 共用键）
    final nativeBitRate = prefs['bit_rate'] as int?;
    if (nativeBitRate != null) _bitRate = nativeBitRate;

    final nativeSampleRate = prefs['sample_rate'] as int?;
    if (nativeSampleRate != null) _sampleRate = nativeSampleRate;

    final nativeOutputDir = prefs['output_dir'] as String?;
    if (nativeOutputDir != null) _recordingPath = nativeOutputDir;
  }

  // ===========================================================================
  // 主题设置（Flutter 专属）
  // ===========================================================================

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    _prefs.setInt(_kThemeMode, value.index);
    notifyListeners();
  }

  // ===========================================================================
  // AI 总结
  // ===========================================================================

  bool get enableSummarization => _enableSummarization;

  set enableSummarization(bool value) {
    if (_enableSummarization == value) return;
    _enableSummarization = value;
    _prefs.setBool(_kEnableSummarization, value);
    notifyListeners();
  }

  String get apiKey => _apiKey;

  set apiKey(String value) {
    if (_apiKey == value) return;
    _apiKey = value;
    _prefs.setString(_kApiKey, value);
    notifyListeners();
  }

  String get apiBaseUrl => _apiBaseUrl;

  set apiBaseUrl(String value) {
    if (_apiBaseUrl == value) return;
    _apiBaseUrl = value;
    _prefs.setString(_kApiBaseUrl, value);
    notifyListeners();
  }

  String get summarizeModel => _summarizeModel;

  set summarizeModel(String value) {
    if (_summarizeModel == value) return;
    _summarizeModel = value;
    _prefs.setString(_kSummarizeModel, value);
    notifyListeners();
  }

  // ===========================================================================
  // 通知
  // ===========================================================================

  bool get notificationOpenDir => _notificationOpenDir;

  set notificationOpenDir(bool value) {
    if (_notificationOpenDir == value) return;
    _notificationOpenDir = value;
    _pushToNative('notification_open_dir', value);
    notifyListeners();
  }

  // ===========================================================================
  // 基本设置（共享 — 与原生通话录音共用）
  // ===========================================================================

  /// 输出格式（opus / aac / flac / wav / amr_wb / amr_nb）
  String get formatName => _formatName;

  set formatName(String value) {
    if (_formatName == value) return;
    _formatName = value;
    _pushToNative('format_name', value);
    notifyListeners();
  }

  /// 比特率 (bps)，默认 128000
  int get bitRate => _bitRate;

  set bitRate(int value) {
    if (_bitRate == value) return;
    _bitRate = value;
    _pushToNative('bit_rate', value);
    notifyListeners();
  }

  /// 采样率 (Hz)，默认 44100
  int get sampleRate => _sampleRate;

  set sampleRate(int value) {
    if (_sampleRate == value) return;
    _sampleRate = value;
    _pushToNative('sample_rate', value);
    notifyListeners();
  }

  /// 录音文件存储路径。空字符串表示使用系统默认路径。
  String get recordingPath => _recordingPath;

  set recordingPath(String value) {
    if (_recordingPath == value) return;
    _recordingPath = value;
    _pushToNative('recording_path', value);
    notifyListeners();
  }

  /// 重置存储路径为默认值
  void resetRecordingPath() {
    recordingPath = '';
  }

  // ===========================================================================
  // 通话录音
  // ===========================================================================

  /// 通话录音总开关，默认 true
  bool get callRecording => _callRecording;

  set callRecording(bool value) {
    if (_callRecording == value) return;
    _callRecording = value;
    _pushToNative('call_recording', value);
    notifyListeners();
  }

  /// 音频源（voice_call / voice_uplink_downlink / voice_uplink / voice_downlink）
  String get audioSource => _audioSource;

  set audioSource(String value) {
    if (_audioSource == value) return;
    _audioSource = value;
    _pushToNative('audio_source', value);
    notifyListeners();
  }

  /// 文件名模板。空字符串表示使用默认模板。
  String get filenameTemplate => _filenameTemplate;

  set filenameTemplate(String value) {
    if (_filenameTemplate == value) return;
    _filenameTemplate = value;
    _pushToNative('filename_template', value);
    notifyListeners();
  }

  /// 最低录音时长（秒）。0 = 不限。
  int get minDuration => _minDuration;

  set minDuration(int value) {
    if (_minDuration == value) return;
    _minDuration = value;
    _pushToNative('min_duration', value);
    notifyListeners();
  }

  /// 文件保留天数。0 = 无限期保留。
  int get outputRetention => _outputRetention;

  set outputRetention(int value) {
    if (_outputRetention == value) return;
    _outputRetention = value;
    _pushToNative('output_retention', value);
    notifyListeners();
  }

  /// 录音规则 JSON 字符串。
  String get recordRules => _recordRules;

  set recordRules(String value) {
    if (_recordRules == value) return;
    _recordRules = value;
    _pushToNative('record_rules', value);
    notifyListeners();
  }

  /// 是否在拨号阶段就开始录制
  bool get recordDialingState => _recordDialingState;

  set recordDialingState(bool value) {
    if (_recordDialingState == value) return;
    _recordDialingState = value;
    _pushToNative('record_dialing_state', value);
    notifyListeners();
  }

  /// 是否录制第三方电信集成应用的通话
  bool get recordTelecomApps => _recordTelecomApps;

  set recordTelecomApps(bool value) {
    if (_recordTelecomApps == value) return;
    _recordTelecomApps = value;
    _pushToNative('record_telecom_apps', value);
    notifyListeners();
  }

  // ===========================================================================
  // 关于 / 调试
  // ===========================================================================

  /// 强制 Direct Boot 模式（调试用）
  bool get forceDirectBoot => _forceDirectBoot;

  set forceDirectBoot(bool value) {
    if (_forceDirectBoot == value) return;
    _forceDirectBoot = value;
    _pushToNative('force_direct_boot', value);
    notifyListeners();
  }

  /// 保存调试日志（调试用）
  bool get debugMode => _debugMode;

  set debugMode(bool value) {
    if (_debugMode == value) return;
    _debugMode = value;
    _pushToNative('debug_mode', value);
    notifyListeners();
  }

  // ---- 内部同步 ---------------------------------------------------------------

  /// 将单个设置项异步写入原生层。
  ///
  /// 写入操作不阻塞 UI 线程，失败时会打印错误日志。
  void _pushToNative(String key, dynamic value) {
    if (!Platform.isAndroid) return;
    NativeBridge.instance.setPreference(key, value);
  }
}
