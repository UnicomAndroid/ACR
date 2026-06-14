import 'package:flutter/material.dart';

/// 顶部搜索栏，包含搜索输入框和头像按钮。
class SearchHeader extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  const SearchHeader({super.key, this.avatarUrl, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 44,
        child: TextField(
          onChanged: (_) {},
          decoration: InputDecoration(
            hintText: '搜索录音文件...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withAlpha(150),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            suffixIcon: GestureDetector(
              onTap: onAvatarTap,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 16,
                          color: scheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ),
            ),
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }
}
