import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/settings_service.dart';
import '../services/recording_service.dart';
import '../services/native_bridge.dart';
import '../widgets/app_dialog.dart';
import '../services/model_manager.dart';
import '../services/sherpa_service.dart';

/// =============================================================================
/// SettingsTab — 完整的应用设置页
/// =============================================================================
///
/// 布局（按计划）：
///   - 主题设置
///   - 通知
///   - 基本设置
///   - 通话录音
///   - 关于
class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.settingsService,
    required this.recordingService,
  });

  final SettingsService settingsService;
  final RecordingService recordingService;
  static const _repoUrl = 'https://github.com/easterNday/ACR';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // =====================================================================
        // 主题设置
        // =====================================================================
        _SectionHeader(title: '主题设置'),
        _SettingsCard(
          child: _ThemeModeTile(settingsService: settingsService),
        ),

        // =====================================================================
        // 通知
        // =====================================================================
        _SectionHeader(title: '通知'),
        _SettingsCard(
          child: _SwitchTile(
            icon: Icons.folder_open,
            title: '点击通知打开目录',
            subtitle: '录音完成后点击通知打开输出目录而非文件',
            value: settingsService.notificationOpenDir,
            onChanged: (v) => settingsService.notificationOpenDir = v,
          ),
        ),

        // =====================================================================
        // 基本设置
        // =====================================================================
        _SectionHeader(title: '基本设置'),
        _SettingsCard(
          child: Column(
            children: [
              _FormatTile(settingsService: settingsService),
              const Divider(height: 1, indent: 56),
              _QualityTile(
                settingsService: settingsService,
                recordingService: recordingService,
                type: _QualityType.bitRate,
              ),
              const Divider(height: 1, indent: 56),
              _QualityTile(
                settingsService: settingsService,
                recordingService: recordingService,
                type: _QualityType.sampleRate,
              ),
              const Divider(height: 1, indent: 56),
              _StoragePathTile(
                settingsService: settingsService,
                recordingService: recordingService,
              ),
            ],
          ),
        ),

        // =====================================================================
        // 通话录音
        // =====================================================================
        _SectionHeader(title: '通话录音'),
        _SettingsCard(
          child: Column(
            children: [
              _SwitchTile(
                icon: Icons.phone_in_talk,
                title: '通话录音',
                subtitle: '通话接通时自动开始录制',
                value: settingsService.callRecording,
                onChanged: (v) => settingsService.callRecording = v,
              ),
              const Divider(height: 1, indent: 56),
              _AudioSourceTile(settingsService: settingsService),
              const Divider(height: 1, indent: 56),
              _ListTileWithDialog(
                icon: Icons.text_snippet,
                title: '文件名模板',
                subtitle: settingsService.filenameTemplate.isEmpty
                    ? '使用默认模板'
                    : settingsService.filenameTemplate,
                dialogTitle: '文件名模板',
                initialValue: settingsService.filenameTemplate,
                hintText: '留空使用默认模板。变量: {date} {direction} {phone_number} {contact_name} 等',
                onSaved: (v) => settingsService.filenameTemplate = v,
              ),
              const Divider(height: 1, indent: 56),
              _ListTileWithDialog(
                icon: Icons.timer_outlined,
                title: '最低录音时长',
                subtitle: settingsService.minDuration == 0
                    ? '不限'
                    : '${settingsService.minDuration} 秒',
                dialogTitle: '最低录音时长（秒）',
                initialValue: settingsService.minDuration.toString(),
                hintText: '输入秒数，0 = 不限',
                keyboardType: TextInputType.number,
                onSaved: (v) {
                  final s = int.tryParse(v);
                  if (s != null) settingsService.minDuration = s;
                },
              ),
              const Divider(height: 1, indent: 56),
              _ListTileWithDialog(
                icon: Icons.auto_delete,
                title: '文件保留天数',
                subtitle: settingsService.outputRetention == 0
                    ? '无限期保留'
                    : '${settingsService.outputRetention} 天',
                dialogTitle: '文件保留天数',
                initialValue: settingsService.outputRetention.toString(),
                hintText: '输入天数，0 = 无限期保留',
                keyboardType: TextInputType.number,
                onSaved: (v) {
                  final d = int.tryParse(v);
                  if (d != null) settingsService.outputRetention = d;
                },
              ),
              const Divider(height: 1, indent: 56),
              _SwitchTile(
                icon: Icons.dialpad,
                title: '拨号中开始录制',
                subtitle: '去电时在拨号阶段就开始录音',
                value: settingsService.recordDialingState,
                onChanged: (v) => settingsService.recordDialingState = v,
              ),
              const Divider(height: 1, indent: 56),
              _SwitchTile(
                icon: Icons.apps,
                title: '第三方应用通话',
                subtitle: '录制通过电信框架集成应用的 VoIP 通话',
                value: settingsService.recordTelecomApps,
                onChanged: (v) => settingsService.recordTelecomApps = v,
              ),
            ],
          ),
        ),

        // 语音转写(离线)
        _SectionHeader(title: '语音转写'),
        _SettingsCard(child: _TranscriptionSettings()),

        // AI 总结
        _SectionHeader(title: 'AI 总结'),
        _SettingsCard(child: _AISummarySettings(settingsService: settingsService)),

        // =====================================================================
        // 关于
        // =====================================================================
        _SectionHeader(title: '关于'),
        _SettingsCard(
          child: Column(
            children: [
              _SourceCodeTile(),
              const Divider(height: 1, indent: 56),
              _AppVersionTile(),
              const Divider(height: 1, indent: 56),
              _SwitchTile(
                icon: Icons.bug_report_outlined,
                title: '保存调试日志',
                subtitle: '为每次通话保存 logcat 日志',
                value: settingsService.debugMode,
                onChanged: (v) => settingsService.debugMode = v,
              ),
              const Divider(height: 1, indent: 56),
              _SwitchTile(
                icon: Icons.phone_android,
                title: '强制 Direct Boot 模式',
                subtitle: '模拟设备未解锁状态（调试用）',
                value: settingsService.forceDirectBoot,
                onChanged: (v) => settingsService.forceDirectBoot = v,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 可复用组件
// =============================================================================

/// 统一样式的设置项卡片：圆角 12、elevation 1、淡投影
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

/// 分区标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// 通用开关设置项
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      secondary: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 带文本输入对话框的设置项
class _ListTileWithDialog extends StatelessWidget {
  const _ListTileWithDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dialogTitle,
    required this.initialValue,
    required this.onSaved,
    this.hintText,
    this.keyboardType,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String dialogTitle;
  final String initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onSaved;

  Future<void> _showDialog(BuildContext context) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hintText),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && context.mounted) onSaved(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showDialog(context),
    );
  }
}

// =============================================================================
// 主题设置
// =============================================================================

const _themeModeLabels = ['跟随系统', '始终浅色', '始终深色'];

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
      title: const Text('主题模式'),
      subtitle: Text(_themeModeLabels[settingsService.themeMode.index]),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('自动')),
          ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
          ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
        ],
        selected: {settingsService.themeMode},
        onSelectionChanged: (s) => settingsService.themeMode = s.first,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

// =============================================================================
// 基本设置 — 输出格式
// =============================================================================

const _formatLabels = {
  'opus': 'Opus (推荐)',
  'aac': 'AAC',
  'flac': 'FLAC (无损)',
  'wav': 'WAV (PCM)',
  'amr_wb': 'AMR-WB',
  'amr_nb': 'AMR-NB',
};
const _formatOrder = ['opus', 'aac', 'flac', 'wav', 'amr_wb', 'amr_nb'];

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.audio_file_outlined, color: theme.colorScheme.primary),
      title: const Text('输出格式'),
      subtitle: Text(_formatLabels[settingsService.formatName] ?? settingsService.formatName),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text('输出格式',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ..._formatOrder.map((name) {
                  final isSelected = name == settingsService.formatName;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _formatLabels[name] ?? name,
                      style: TextStyle(
                        color: isSelected ? scheme.primary : scheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      settingsService.formatName = name;
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 基本设置 — 音频源
// =============================================================================

const _audioSourceLabels = {
  'voice_call': '麦克风（推荐）',
  'voice_uplink_downlink': '上行 + 下行（立体声）',
  'voice_uplink': '仅上行',
  'voice_downlink': '仅下行',
};
const _audioSourceOrder = [
  'voice_call',
  'voice_uplink_downlink',
  'voice_uplink',
  'voice_downlink',
];

class _AudioSourceTile extends StatelessWidget {
  const _AudioSourceTile({required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.mic, color: theme.colorScheme.primary),
      title: const Text('音频源'),
      subtitle: Text(
          _audioSourceLabels[settingsService.audioSource] ?? settingsService.audioSource),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text('音频源',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ..._audioSourceOrder.map((name) {
                  final isSelected = name == settingsService.audioSource;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _audioSourceLabels[name] ?? name,
                      style: TextStyle(
                        color: isSelected ? scheme.primary : scheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      settingsService.audioSource = name;
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 基本设置 — 录音质量（比特率 / 采样率）
// =============================================================================

enum _QualityType { sampleRate, bitRate }

const _sampleRateLabels = {
  8000: '8 kHz',
  16000: '16 kHz',
  22050: '22.05 kHz',
  44100: '44.1 kHz',
  48000: '48 kHz',
};

const _bitRateLabels = {
  64000: '64 kbps',
  96000: '96 kbps',
  128000: '128 kbps',
  192000: '192 kbps',
  256000: '256 kbps',
};

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.settingsService,
    required this.recordingService,
    required this.type,
  });
  final SettingsService settingsService;
  final RecordingService recordingService;
  final _QualityType type;

  String get _title => type == _QualityType.sampleRate ? '采样率' : '比特率';

  IconData get _icon =>
      type == _QualityType.sampleRate ? Icons.graphic_eq_outlined : Icons.speed_outlined;

  int get _currentValue =>
      type == _QualityType.sampleRate ? settingsService.sampleRate : settingsService.bitRate;

  Map<int, String> get _labels =>
      type == _QualityType.sampleRate ? _sampleRateLabels : _bitRateLabels;

  List<int> get _options => _labels.keys.toList()..sort();

  void _showPicker(BuildContext context) {
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(_title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ..._options.map((value) {
                  final isSelected = value == _currentValue;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _labels[value] ?? '$value',
                      style: TextStyle(
                        color: isSelected ? scheme.primary : scheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      if (type == _QualityType.sampleRate) {
                        settingsService.sampleRate = value;
                        recordingService.setSampleRate(value);
                      } else {
                        settingsService.bitRate = value;
                        recordingService.setBitRate(value);
                      }
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_icon, color: theme.colorScheme.primary),
      title: Text(_title),
      subtitle: Text(_labels[_currentValue] ?? '$_currentValue'),
      onTap: () => _showPicker(context),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

// =============================================================================
// 基本设置 — 存储路径
// =============================================================================

class _StoragePathTile extends StatelessWidget {
  const _StoragePathTile({
    required this.settingsService,
    required this.recordingService,
  });
  final SettingsService settingsService;
  final RecordingService recordingService;

  String get _displayPath {
    final path = settingsService.recordingPath;
    return path.isEmpty ? '系统默认' : path;
  }

  bool get _isCustom => settingsService.recordingPath.isNotEmpty;

  Future<void> _pickDirectory(BuildContext context) async {
    final result = await NativeBridge.instance.pickOutputDirectory();
    if (result != null && context.mounted) {
      settingsService.recordingPath = result;
      recordingService.setStoragePath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
      title: const Text('存储路径'),
      subtitle: Text(
        _displayPath,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _pickDirectory(context),
      trailing: _isCustom
          ? IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: '恢复默认',
              onPressed: () {
                settingsService.resetRecordingPath();
                recordingService.setStoragePath('');
              },
            )
          : const Icon(Icons.chevron_right, size: 20),
    );
  }
}

// =============================================================================
// 关于
// =============================================================================

class _SourceCodeTile extends StatelessWidget {
  const _SourceCodeTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.code, color: theme.colorScheme.primary),
      title: const Text('源码仓库'),
      subtitle: const Text('View on GitHub'),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final uri = Uri.parse(SettingsTab._repoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData
            ? '${snapshot.data!.version} (build ${snapshot.data!.buildNumber})'
            : snapshot.hasError
                ? 'Unknown'
                : 'Loading…';
        return ListTile(
          leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
          title: const Text('版本'),
          subtitle: Text(version),
        );
      },
    );
  }
}

// ---- 离线转写设置 ----------------------------------------------------------

class _TranscriptionSettings extends StatefulWidget {
  @override State<_TranscriptionSettings> createState() => _TranscriptionSettingsState();
}

class _TranscriptionSettingsState extends State<_TranscriptionSettings> {
  final _mm = ModelManager.I; final _ss = SherpaService.I;

  @override void initState() { super.initState(); _mm.addListener(_onChanged); _ss.addListener(_onChanged); }
  @override void dispose() { _mm.removeListener(_onChanged); _ss.removeListener(_onChanged); super.dispose(); }
  void _onChanged() { if (mounted) setState(() {}); }

  static const _intervalOptions = [15, 30, 60, 120, 300];
  static const _intervalLabels = {
    15: '15 秒',
    30: '30 秒',
    60: '1 分钟',
    120: '2 分钟',
    300: '5 分钟',
  };

  void _showIntervalPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final s = Theme.of(ctx).colorScheme;
        final t = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 36, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: s.onSurfaceVariant.withAlpha(60), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text('轮询间隔', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ..._intervalOptions.map((v) {
                  final selected = v == _ss.pollInterval;
                  return ListTile(
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? s.primary : s.onSurfaceVariant,
                    ),
                    title: Text(_intervalLabels[v] ?? '$v 秒',
                      style: TextStyle(color: selected ? s.primary : s.onSurface, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                    ),
                    onTap: () { _ss.setPollInterval(v); Navigator.pop(ctx); },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override Widget build(BuildContext c) {
    final t = Theme.of(c), s = t.colorScheme;
    return Column(children: [
      ListTile(
        leading: Icon(_icon, color: _color),
        title: Text('SenseVoice 模型', style: t.textTheme.bodyMedium),
        subtitle: Text(_status, style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
        trailing: _mm.status == ModelStatus.downloading
          ? SizedBox(width:24,height:24,child:CircularProgressIndicator(value:_mm.progress>0?_mm.progress:null,strokeWidth:2,color:s.primary))
          : _mm.status == ModelStatus.ready ? Icon(Icons.check_circle,color:s.primary,size:22)
          : FilledButton.tonal(onPressed:()=>_mm.download(), child:const Text('下载')),
      ),
      if (_mm.status == ModelStatus.downloading)
        Padding(padding:const EdgeInsets.fromLTRB(56,0,16,8), child:ClipRRect(borderRadius:BorderRadius.circular(4), child:LinearProgressIndicator(value:_mm.progress>0?_mm.progress:null,minHeight:4))),
      if (_mm.status == ModelStatus.error)
        Padding(padding:const EdgeInsets.fromLTRB(56,0,16,8), child:Text(_mm.error, style:t.textTheme.labelSmall?.copyWith(color:s.error))),
      const Divider(height:1,indent:56),
      SwitchListTile(secondary:Icon(Icons.auto_awesome,color:s.primary), title:Text('录音后自动转写', style:t.textTheme.bodyMedium), subtitle:Text('使用本地模型，无需网络', style:t.textTheme.labelSmall?.copyWith(color:s.onSurfaceVariant)), value:_ss.auto, onChanged:(v)=>_ss.setAuto(v)),
      if (_ss.auto) ...[
        const Divider(height:1,indent:56),
        ListTile(
          leading: Icon(Icons.timer_outlined, color: s.primary),
          title: Text('轮询间隔', style: t.textTheme.bodyMedium),
          subtitle: Text(_intervalLabels[_ss.pollInterval] ?? '${_ss.pollInterval} 秒', style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _showIntervalPicker(context),
        ),
      ],
    ]);
  }

  IconData get _icon => switch (_mm.status) {
    ModelStatus.ready => Icons.check_circle, ModelStatus.downloading => Icons.downloading,
    ModelStatus.error => Icons.error, _ => Icons.download,
  };
  Color get _color => switch (_mm.status) {
    ModelStatus.ready => Theme.of(context).colorScheme.primary,
    ModelStatus.downloading => Theme.of(context).colorScheme.primary,
    ModelStatus.error => Theme.of(context).colorScheme.error, _ => Theme.of(context).colorScheme.primary,
  };
  String get _status => switch (_mm.status) {
    ModelStatus.ready => '模型已就绪',
    ModelStatus.downloading => _mm.progress>0?'下载中 ${(_mm.progress*100).toStringAsFixed(0)}%':'准备下载...',
    ModelStatus.error => '下载失败',
    _ => '轻点下载 (~90MB)',
  };
}

// ---- AI 总结设置 --------------------------------------------------------------

class _AISummarySettings extends StatefulWidget {
  final SettingsService settingsService;
  const _AISummarySettings({required this.settingsService});

  @override State<_AISummarySettings> createState() => _AISummarySettingsState();
}

class _AISummarySettingsState extends State<_AISummarySettings> {
  SettingsService get _s => widget.settingsService;

  @override void initState() { super.initState(); _s.addListener(_onChanged); }
  @override void dispose() { _s.removeListener(_onChanged); super.dispose(); }
  void _onChanged() { if (mounted) setState(() {}); }

  Future<void> _editText(String title, String current, ValueChanged<String> onSave) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: title.contains('Key'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && mounted) onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), s = t.colorScheme;
    return Column(children: [
      SwitchListTile(
        secondary: Icon(Icons.auto_awesome, color: s.primary),
        title: Text('启用 AI 总结', style: t.textTheme.bodyMedium),
        subtitle: Text('转写完成后自动调用 API 生成摘要', style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
        value: _s.enableSummarization,
        onChanged: (v) => _s.enableSummarization = v,
      ),
      if (_s.enableSummarization) ...[
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: Icon(Icons.vpn_key_outlined, color: s.primary),
          title: Text('API Key', style: t.textTheme.bodyMedium),
          subtitle: Text(_s.apiKey.isEmpty ? '未设置' : '•' * min(_s.apiKey.length, 20), style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _editText('API Key', _s.apiKey, (v) => _s.apiKey = v),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: Icon(Icons.link, color: s.primary),
          title: Text('API 地址', style: t.textTheme.bodyMedium),
          subtitle: Text(_s.apiBaseUrl, style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _editText('API 地址', _s.apiBaseUrl, (v) => _s.apiBaseUrl = v),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: Icon(Icons.model_training, color: s.primary),
          title: Text('模型', style: t.textTheme.bodyMedium),
          subtitle: Text(_s.summarizeModel, style: t.textTheme.labelSmall?.copyWith(color: s.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _editText('模型名称', _s.summarizeModel, (v) => _s.summarizeModel = v),
        ),
      ],
    ]);
  }
}
