import 'package:flutter/material.dart';

/// Material 3 统一对话框
///
/// 宽度 80% 屏幕宽，高度自适应内容。
/// 使用方式：
/// ```dart
/// AppDialog(
///   title: Text('标题'),
///   content: Text('内容'),
///   actions: [TextButton(...), FilledButton(...)],
/// )
/// ```
class AppDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  const AppDialog({super.key, this.title, this.content, this.actions});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.8;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 3,
      surfaceTintColor: Colors.transparent,
      child: SizedBox(
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.headlineSmall,
                  child: title!,
                ),
              ),
            if (content != null)
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, title != null ? 12 : 24, 24, actions != null ? 4 : 24),
                  child: content!,
                ),
              ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OverflowBar(
                  spacing: 8,
                  alignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
