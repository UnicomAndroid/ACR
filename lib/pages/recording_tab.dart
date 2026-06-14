import 'package:flutter/material.dart';
import '../services/recording_service.dart';

class RecordingTab extends StatefulWidget {
  final RecordingService recordingService;
  const RecordingTab({super.key, required this.recordingService});

  @override
  State<RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends State<RecordingTab>
    with SingleTickerProviderStateMixin {
  RecordingService get _rs => widget.recordingService;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rs.addListener(_onStateChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_rs.isRecording) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rs.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_rs.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_rs.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    setState(() {});
  }

  void _handleTap() {
    if (_rs.isIdle) _rs.start();
    else if (_rs.isRecording) _rs.pause();
    else if (_rs.isPaused) _rs.resume();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _rs.isRecording || _rs.isPaused;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimerDisplay(
              duration: _rs.durationFormatted,
              isActive: isActive,
              isPaused: _rs.isPaused,
            ),
            const SizedBox(height: 40),
            _MainActionButton(
              isRecording: _rs.isRecording,
              isPaused: _rs.isPaused,
              pulseController: _pulseController,
              onTap: _handleTap,
              onLongPressComplete: isActive ? () => _rs.stop() : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 24,
              child: Center(
                child: _StateLabel(
                  isRecording: _rs.isRecording,
                  isPaused: _rs.isPaused,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 时长显示
// =============================================================================

class _TimerDisplay extends StatelessWidget {
  final String duration;
  final bool isActive;
  final bool isPaused;

  const _TimerDisplay({
    required this.duration,
    required this.isActive,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isActive
        ? (isPaused ? scheme.tertiary : scheme.error)
        : scheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: isActive
              ? _RecordingDot(isPaused: isPaused)
              : null,
        ),
        Text(
          duration,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w200,
                fontFamily: 'monospace',
                letterSpacing: 4,
                fontSize: 72,
                height: 1.1,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// 录音指示灯
// =============================================================================

class _RecordingDot extends StatelessWidget {
  final bool isPaused;
  const _RecordingDot({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPaused ? scheme.tertiary : scheme.error,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isPaused ? '已暂停' : '录音中',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isPaused ? scheme.tertiary : scheme.error,
                  letterSpacing: 1,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 主操作按钮（支持长按进度环）
// =============================================================================

class _MainActionButton extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;
  final AnimationController pulseController;
  final VoidCallback onTap;
  final VoidCallback? onLongPressComplete;

  const _MainActionButton({
    required this.isRecording,
    required this.isPaused,
    required this.pulseController,
    required this.onTap,
    this.onLongPressComplete,
  });

  @override
  State<_MainActionButton> createState() => _MainActionButtonState();
}

class _MainActionButtonState extends State<_MainActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _longPressController;
  bool _isLongPressing = false;

  static const _longPressDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _longPressController = AnimationController(
      vsync: this,
      duration: _longPressDuration,
    );
    _longPressController.addListener(() {
      if (_longPressController.isCompleted) {
        widget.onLongPressComplete?.call();
        _longPressController.reset();
        _isLongPressing = false;
      }
    });
  }

  @override
  void dispose() {
    _longPressController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (widget.onLongPressComplete == null) return;
    _isLongPressing = true;
    _longPressController.forward(from: 0);
    // Haptic feedback
    // HapticFeedback.mediumImpact();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    _longPressController.stop();
    _longPressController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color color;
    final IconData icon;
    final Color iconColor;

    if (widget.isRecording) {
      color = scheme.error;
      icon = Icons.pause_rounded;
      iconColor = scheme.onError;
    } else if (widget.isPaused) {
      color = scheme.tertiary;
      icon = Icons.play_arrow_rounded;
      iconColor = scheme.onPrimary;
    } else {
      color = scheme.primary;
      icon = Icons.mic_rounded;
      iconColor = scheme.onPrimary;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([widget.pulseController, _longPressController]),
      builder: (context, child) {
        final pulseValue = widget.isRecording ? widget.pulseController.value : 0.0;
        final scale = 1.0 + pulseValue * 0.06;
        final longPressProgress = widget.onLongPressComplete != null
            ? _longPressController.value
            : 0.0;

        return GestureDetector(
          onTap: widget.onTap,
          onLongPressStart: widget.onLongPressComplete != null ? _onLongPressStart : null,
          onLongPressEnd: _onLongPressEnd,
          onLongPressUp: () => _onLongPressEnd(const LongPressEndDetails()),
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Long press progress ring
                if (longPressProgress > 0)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: longPressProgress,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                // Pulsing background shadow
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: pulseValue * 0.3 + 0.15),
                          blurRadius: 16 + pulseValue * 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 36),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 状态标签（固定高度占位）
// =============================================================================

class _StateLabel extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;

  const _StateLabel({required this.isRecording, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    final Color? color;

    if (isRecording) {
      text = '轻触暂停 · 长按停止';
      color = scheme.error;
    } else if (isPaused) {
      text = '轻触继续 · 长按停止';
      color = scheme.tertiary;
    } else {
      text = '轻触开始录音';
      color = scheme.onSurfaceVariant;
    }

    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
    );
  }
}
