import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// =============================================================================
/// NativeBridge — Flutter ↔ Android 原生层通信桥梁
/// =============================================================================
///
/// 通过 MethodChannel "studio.unicom.acr/native" 与 MainActivity.kt 中的
/// 原生代码进行双向通信。
///
/// 职责：
///   - 读写通话录音相关的原生 SharedPreferences
///   - 获取录音文件列表
///   - 删除录音文件
///   - 启动 SAF 目录选择器
///   - 查询当前录音状态
///
/// 使用方式（单例）：
/// ```dart
/// final bridge = NativeBridge.instance;
/// final prefs = await bridge.getPreferences();
/// await bridge.setPreference('call_recording', true);
/// ```
class NativeBridge {
  // ---- 单例 ---------------------------------------------------------------
  static final NativeBridge _instance = NativeBridge._();
  static NativeBridge get instance => _instance;
  NativeBridge._();

  // ---- MethodChannel ------------------------------------------------------
  static const _channel = MethodChannel('studio.unicom.acr/native');

  // ---- 设置读写 -----------------------------------------------------------

  /// 从原生层批量读取所有通话录音相关设置。
  ///
  /// 返回值示例：
  /// ```dart
  /// {
  ///   'call_recording': true,
  ///   'format_name': 'opus',
  ///   'audio_source': 'voice_call',
  ///   'filename_template': '{date}[_{direction}|]...',
  ///   'min_duration': 0,
  ///   'output_retention': 0,
  ///   'record_dialing_state': false,
  ///   'record_telecom_apps': false,
  ///   'write_metadata': true,
  ///   'notification_open_dir': false,
  ///   'bit_rate': 128000,
  ///   'sample_rate': 44100,
  ///   'output_dir': 'content://...',
  ///   'force_direct_boot': false,
  ///   'debug_mode': false,
  /// }
  /// ```
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final result = await _channel.invokeMethod('getPreferences');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      debugPrint('NativeBridge.getPreferences 失败: $e');
      return {};
    }
  }

  /// 向原生层写入单个设置项。
  ///
  /// [key] 支持的值及其类型：
  /// - `call_recording`: bool
  /// - `format_name`: String (opus/aac/flac/wav/amr_wb/amr_nb)
  /// - `audio_source`: String (voice_call/voice_uplink_downlink/voice_uplink/voice_downlink)
  /// - `filename_template`: String
  /// - `min_duration`: int (秒)
  /// - `output_retention`: int (天，0=不限)
  /// - `record_dialing_state`: bool
  /// - `record_telecom_apps`: bool
  /// - `write_metadata`: bool
  /// - `notification_open_dir`: bool
  /// - `bit_rate`: int
  /// - `sample_rate`: int
  /// - `recording_path`: String
  /// - `force_direct_boot`: bool
  /// - `debug_mode`: bool
  Future<bool> setPreference(String key, dynamic value) async {
    try {
      final result = await _channel.invokeMethod('setPreference', {
        'key': key,
        'value': value,
      });
      return result == true;
    } catch (e) {
      debugPrint('NativeBridge.setPreference($key) 失败: $e');
      return false;
    }
  }

  // ---- 录音文件管理 -------------------------------------------------------

  /// 获取录音文件列表。
  ///
  /// 返回 List<Map>，每个元素包含：
  /// ```dart
  /// {
  ///   'uri': 'content://...',
  ///   'name': 'ACR_1234567890.opus',
  ///   'size': 1234567,
  ///   'date': 1700000000000,
  ///   'mimeType': 'audio/opus',
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getRecordings() async {
    try {
      final result = await _channel.invokeMethod('getRecordings');
      if (result is List) {
        return result.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('NativeBridge.getRecordings 失败: $e');
      return [];
    }
  }

  /// 删除指定 URI 的录音文件。
  Future<bool> deleteRecording(String uri) async {
    try {
      final result = await _channel.invokeMethod('deleteRecording', {'uri': uri});
      return result == true;
    } catch (e) {
      debugPrint('NativeBridge.deleteRecording 失败: $e');
      return false;
    }
  }

  // ---- SAF 目录选择器 -----------------------------------------------------

  /// 启动系统 SAF 目录选择器，让用户选择录音存储目录。
  ///
  /// 返回用户选择的目录 URI 字符串，取消则返回 null。
  Future<String?> pickOutputDirectory() async {
    try {
      final result = await _channel.invokeMethod('pickOutputDirectory');
      return result as String?;
    } catch (e) {
      debugPrint('NativeBridge.pickOutputDirectory 失败: $e');
      return null;
    }
  }

  // ---- 录音状态 -----------------------------------------------------------

  /// 查询当前原生层的录音状态。
  ///
  /// 返回：
  /// ```dart
  /// {
  ///   'isRecording': false,
  ///   'callInfo': null,      // 通话信息 Map（录音中时有值）
  ///   'filename': null,      // 当前录音文件名
  ///   'duration': 0,         // 已录制时长（秒）
  /// }
  /// ```
  Future<bool> startManualRecording({String? format, String? audioSource, String? filenameTemplate, bool? debugMode}) async {
    try {
      final result = await _channel.invokeMethod('startManualRecording', {
        if (format != null) 'format': format,
        if (audioSource != null) 'audioSource': audioSource,
        if (filenameTemplate != null) 'filenameTemplate': filenameTemplate,
        if (debugMode != null) 'debugMode': debugMode,
      });
      return result == true;
    } catch (e) { debugPrint('startManualRecording: $e'); return false; }
  }

  Future<bool> stopManualRecording() async {
    try { final r = await _channel.invokeMethod('stopManualRecording'); return r == true; }
    catch (e) { debugPrint('stopManualRecording: $e'); return false; }
  }

  Future<bool> pauseManualRecording() async {
    try { final r = await _channel.invokeMethod('pauseManualRecording'); return r == true; }
    catch (e) { debugPrint('pauseManualRecording: $e'); return false; }
  }

  Future<bool> resumeManualRecording() async {
    try { final r = await _channel.invokeMethod('resumeManualRecording'); return r == true; }
    catch (e) { debugPrint('resumeManualRecording: $e'); return false; }
  }

  Future<Map<String, dynamic>> getManualRecordingState() async {
    try {
      final r = await _channel.invokeMethod('getManualRecordingState');
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'state': 'IDLE', 'duration': 0};
    } catch (e) { debugPrint('getManualRecordingState: $e'); return {'state': 'IDLE', 'duration': 0}; }
  }

  Future<Map<String, dynamic>> getRecordingState() async {
    try {
      final result = await _channel.invokeMethod('getRecordingState');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'isRecording': false};
    } catch (e) {
      debugPrint('NativeBridge.getRecordingState 失败: $e');
      return {'isRecording': false};
    }
  }
}
