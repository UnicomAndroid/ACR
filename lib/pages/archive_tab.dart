import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/settings_service.dart';
import '../services/sherpa_service.dart';
import '../widgets/app_dialog.dart';

// ---- 归档标签页 ----------------------------------------------------------------

class ArchiveTab extends StatefulWidget {
  final RecordingService recordingService;
  final SettingsService settingsService;
  const ArchiveTab({super.key, required this.recordingService, required this.settingsService});

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  RecordingService get _rs => widget.recordingService;

  @override
  void initState() {
    super.initState();
    _rs.addListener(_onServiceChanged);
    SherpaService.I.refreshSummaries();
    _refresh();
  }

  @override
  void dispose() {
    _rs.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() => _rs.refreshRecordings();

  @override
  Widget build(BuildContext context) {
    final recordings = _rs.allRecordings;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: recordings.isEmpty
          ? LayoutBuilder(
              builder: (_, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [SizedBox(height: constraints.maxHeight, child: Center(child: _buildEmptyState()))],
              ),
            )
          : Stack(
              children: [
                ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, _rs.playingPath != null ? 150 : 16),
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    return RecordingListItem(key: ValueKey(recordings[index].path), info: recordings[index], service: _rs);
                  },
                ),
                if (_rs.playingPath != null)
                  Positioned(
                    left: 16, right: 16, bottom: 8,
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(16),
                      child: MiniPlayer(service: _rs),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withAlpha(120),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.secondary.withAlpha(50),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.folder_open, size: 38, color: scheme.secondary),
          ),
          const SizedBox(height: 20),
          Text(
            'No Recordings Yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the mic button to start recording',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 文件列表项 ----------------------------------------------------------------

class RecordingListItem extends StatefulWidget {
  final RecordingInfo info;
  final RecordingService service;

  const RecordingListItem({super.key, required this.info, required this.service});

  @override
  State<RecordingListItem> createState() => _RecordingListItemState();
}

class _RecordingListItemState extends State<RecordingListItem> {
  bool _transcriptExpanded = false;
  bool _summaryExpanded = false;

  RecordingInfo get info => widget.info;
  RecordingService get service => widget.service;

  @override
  void initState() {
    super.initState();
    SherpaService.I.addListener(_onSherpaChanged);
    service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    SherpaService.I.removeListener(_onSherpaChanged);
    service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onSherpaChanged() {
    if (mounted) setState(() {});
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isActive = service.playingPath == info.path;
    final isThisPlaying = isActive && service.isPlaying;

    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      elevation: isActive ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: scheme.primary.withAlpha(80), width: 1)
            : BorderSide.none,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 文件信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.filename,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(info.formattedDate, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Icon(Icons.storage, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(info.formattedSize, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    if (info.direction != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _directionColor(info.direction!, scheme).withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _directionLabel(info.direction!),
                          style: theme.textTheme.labelSmall?.copyWith(color: _directionColor(info.direction!, scheme), fontSize: 10),
                        ),
                      ),
                    ],
                    if (info.isManual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer.withAlpha(120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '手动录音',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 转写内容 & AI 摘要（可折叠）
          Builder(builder: (_) {
            final tx = SherpaService.I.text(info.path);
            final hasTx = tx != null && tx.isNotEmpty && tx != '...';
            final sm = SherpaService.I.summary(info.path);
            final hasSm = sm != null && sm.isNotEmpty;
            if (!hasTx && !hasSm && sm != '...') return const SizedBox.shrink();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                // 转写折叠区
                if (hasTx) _CollapsibleSection(
                  icon: Icons.description_outlined,
                  iconColor: scheme.primary,
                  containerColor: scheme.primaryContainer.withAlpha(80),
                  title: '转写内容',
                  subtitle: '点击查看完整转写',
                  isExpanded: _transcriptExpanded,
                  onToggle: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
                  child: Text(tx, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.6)),
                ),
                // AI 摘要折叠区
                if (hasSm) _CollapsibleSection(
                  icon: Icons.auto_awesome,
                  iconColor: scheme.tertiary,
                  containerColor: scheme.tertiaryContainer.withAlpha(80),
                  title: 'AI 摘要',
                  subtitle: '点击查看摘要内容',
                  isExpanded: _summaryExpanded,
                  onToggle: () => setState(() => _summaryExpanded = !_summaryExpanded),
                  child: Text(sm, style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary, height: 1.6)),
                ),
                // AI 总结加载中
                if (!hasSm && sm == '...')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.tertiary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('AI 总结中…', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500)),
                            Text('正在生成摘要，请稍候', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ]),
                  ),
              ],
            );
          }),

          // 底部操作栏
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 播放按钮
                IconButton(
                  icon: Icon(
                    isThisPlaying ? Icons.pause_circle_outlined : Icons.play_circle_outlined,
                    size: 26,
                    color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  onPressed: () => service.togglePlayPause(info.path),
                  tooltip: isThisPlaying ? '暂停' : '播放',
                ),
                // 转写按钮
                ListenableBuilder(
                  listenable: SherpaService.I,
                  builder: (_, __) {
                    final tx = SherpaService.I.text(info.path);
                    if (tx == '...') return const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2));
                    final ok = SherpaService.I.ready;
                    return IconButton(
                      icon: Icon(
                        tx != null ? Icons.check_circle : ok ? Icons.text_snippet : Icons.text_snippet_outlined,
                        size: 22,
                        color: tx != null ? scheme.primary : ok ? scheme.primary : scheme.onSurfaceVariant.withAlpha(80),
                      ),
                      onPressed: () => _onTranscribeTap(context, tx != null, ok),
                      tooltip: tx != null ? '重新转写' : ok ? '转写' : '请先下载模型',
                    );
                  },
                ),
                // AI 总结按钮
                ListenableBuilder(
                  listenable: SherpaService.I,
                  builder: (_, __) {
                    final tx = SherpaService.I.text(info.path);
                    final sm = SherpaService.I.summary(info.path);
                    final canSum = SherpaService.I.canSummarize;
                    final hasTx = tx != null && tx.isNotEmpty && tx != '...';
                    if (!canSum || !hasTx) return const SizedBox.shrink();
                    if (sm == '...') return const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2));
                    final hasSummary = sm != null && sm.isNotEmpty;
                    return IconButton(
                      icon: Icon(
                        hasSummary ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                        size: 22,
                        color: hasSummary ? scheme.tertiary : scheme.onSurfaceVariant.withAlpha(180),
                      ),
                      onPressed: () => _onSummarizeTap(context, hasSummary),
                      tooltip: hasSummary ? '重新总结' : 'AI 总结',
                    );
                  },
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 22, color: scheme.error.withAlpha(180)),
                  onPressed: () => _confirmDelete(context),
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onTranscribeTap(BuildContext context, bool hasResult, bool ready) {
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先在设置中下载语音识别模型'), duration: Duration(seconds: 2)));
      return;
    }
    if (hasResult) {
      _confirmOverwrite(context);
    } else {
      SherpaService.I.run(info.path);
    }
  }

  void _onSummarizeTap(BuildContext context, bool hasSummary) {
    if (hasSummary) {
      showDialog(
        context: context,
        builder: (ctx) => AppDialog(
          title: const Text('重新总结'),
          content: Text('"${info.filename}" 已有 AI 总结，是否重新生成？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () { Navigator.pop(ctx); SherpaService.I.summarize(info.path); },
              child: Text('重新生成', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
            ),
          ],
        ),
      );
    } else {
      SherpaService.I.summarize(info.path);
    }
  }

  void _confirmOverwrite(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('覆盖转写'),
        content: Text('"${info.filename}" 已有转写结果，是否重新转写？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); SherpaService.I.run(info.path); },
            child: Text('覆盖', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Delete Recording'),
        content: Text('Delete "${info.filename}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { service.deleteRecording(info.path); Navigator.pop(ctx); },
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ---- 悬浮迷你播放器（常驻）----------------------------------------------------

class MiniPlayer extends StatefulWidget {
  final RecordingService service;
  final ImageProvider? coverImage;

  const MiniPlayer({super.key, required this.service, this.coverImage});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  RecordingService get _service => widget.service;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasTrack = _service.playingPath != null;

    // 用 allRecordings 而非 recordings，因为原生录音是 content:// URI
    final currentInfo = _service.allRecordings.where(
      (r) => r.path == _service.playingPath,
    );
    final filename = currentInfo.isNotEmpty ? currentInfo.first.filename : '';

    final durationMs = _service.playbackDuration.inMilliseconds.toDouble();
    final positionMs = _service.playbackPosition.inMilliseconds.toDouble();
    final max = durationMs > 0 ? durationMs : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主体：封面 + 信息 + 控制
          Row(
            children: [
              // 封面：外部录音可用 coverImage 传入照片，默认显示录音图标
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasTrack
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                  ),
                  child: widget.coverImage != null
                      ? Image(image: widget.coverImage!, fit: BoxFit.cover)
                      : Icon(
                          Icons.mic,
                          size: 28,
                          color: hasTrack
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant.withAlpha(100),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 文件名 + 进度
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTrack ? filename : 'No track selected',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: hasTrack
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant.withAlpha(150),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: scheme.primary,
                        inactiveTrackColor: scheme.surfaceContainerHighest,
                        thumbColor: scheme.primary,
                        overlayColor: scheme.primary.withAlpha(40),
                      ),
                      child: Slider(
                        value: positionMs.clamp(0.0, max),
                        max: max,
                        onChanged: hasTrack
                            ? (v) => _service.seek(Duration(milliseconds: v.round()))
                            : null,
                      ),
                    ),
                    // 时间行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hasTrack
                              ? _service.playbackPositionFormatted
                              : '--:--',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          hasTrack
                              ? _service.playbackDurationFormatted
                              : '--:--',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // 播放按钮
              IconButton(
                icon: Icon(
                  hasTrack && _service.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 44,
                  color: hasTrack ? scheme.primary : scheme.onSurfaceVariant.withAlpha(100),
                ),
                onPressed: hasTrack
                    ? () => _service.togglePlayPause(_service.playingPath!)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- MD3 可折叠区域 --------------------------------------------------------

/// Google Material Design 3 风格的可折叠内容区。
///
/// 特性：
/// - 圆角图标容器（MD3 chip 风格）
/// - 标题 + 副标题层次
/// - 展开/折叠动画（200ms 缓动 + AnimatedSize）
/// - 展开内容使用 surfaceContainerLow 背景区分层次
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.iconColor,
    required this.containerColor,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color containerColor;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 折叠头部
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 图标容器
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                // 标题区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // 展开箭头（旋转动画）
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开内容
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: child,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---- 通话方向标签 ----
Color _directionColor(String dir, ColorScheme scheme) => switch (dir) {
  'IN' => scheme.primary,
  'OUT' => scheme.tertiary,
  'CONFERENCE' => scheme.secondary,
  _ => scheme.onSurfaceVariant,
};

String _directionLabel(String dir) => switch (dir) {
  'IN' => '来电',
  'OUT' => '去电',
  'CONFERENCE' => '会议',
  _ => dir,
};
