import 'package:flutter/material.dart';
import '../utils/login_util.dart';

/// 登录页面，支持 Google 和 GitHub 两种登录方式。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _error;

  Future<void> _login(String provider) async {
    setState(() { _loading = true; _error = null; });
    final token = await LoginUtil.signIn(provider);
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pop(true); // 返回 true 表示登录成功
    } else {
      setState(() { _loading = false; _error = '登录失败，请重试'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- 应用图标 ----
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withAlpha(120),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withAlpha(50),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.mic, size: 36, color: scheme.primary),
                ),
                const SizedBox(height: 24),

                // ---- 标题 ----
                Text('Welcome to ACR',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Sign in to sync your recordings',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 40),

                // ---- Google 登录按钮 ----
                _LoginButton(
                  icon: 'assets/icon/android/play_store_512.png',
                  label: 'Continue with Google',
                  bgColor: scheme.surfaceContainerHighest,
                  textColor: scheme.onSurface,
                  loading: _loading,
                  onTap: () => _login('google'),
                  isAsset: true,
                ),
                const SizedBox(height: 12),

                // ---- GitHub 登录按钮 ----
                _LoginButton(
                  icon: null,
                  gitHubIcon: true,
                  label: 'Continue with GitHub',
                  bgColor: const Color(0xFF24292F),
                  textColor: Colors.white,
                  loading: _loading,
                  onTap: () => _login('github'),
                ),
                const SizedBox(height: 24),

                // ---- 错误提示 ----
                if (_error != null)
                  Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录按钮组件。
class _LoginButton extends StatelessWidget {
  final String? icon;
  final bool? gitHubIcon;
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool loading;
  final VoidCallback onTap;
  final bool isAsset;

  const _LoginButton({
    this.icon, this.gitHubIcon,
    required this.label, required this.bgColor,
    required this.textColor, required this.loading,
    required this.onTap, this.isAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 1,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: bgColor == Theme.of(context).colorScheme.surfaceContainerHighest
                ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80))
                : BorderSide.none,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isAsset && icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Image.asset(icon!, width: 20, height: 20),
                    )
                  else if (gitHubIcon == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(Icons.code, size: 20, color: textColor),
                    ),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
      ),
    );
  }
}
