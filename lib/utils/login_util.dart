import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 用户认证工具类。
///
/// 通过 Firebase Auth 支持两种登录方式：Google 和 GitHub。
/// 提供统一的 API 供外部调用。
class LoginUtil {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---- Google Sign-In --------------------------------------------------------

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  static Future<void> _ensureGoogleInit() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }
  }

  /// Google 账号登录。
  ///
  /// 通过原生 Google Play Services 弹窗获取 Google ID Token，
  /// 交换为 Firebase 凭据完成登录。
  /// 返回 Firebase ID Token，用户取消或失败返回 null。
  static Future<String?> signInWithGoogle() async {
    await _ensureGoogleInit();

    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final user = (await _auth.signInWithCredential(credential)).user;
      return (await user?.getIdTokenResult(true))?.token;
    } catch (_) {
      return null;
    }
  }

  // ---- GitHub 登录 -----------------------------------------------------------

  /// GitHub 账号登录。
  ///
  /// 使用两阶段流程避免 chrome Custom Tab 中 session 状态丢失的问题：
  ///   1. signInWithProvider 发起 OAuth
  ///   2. 如果因 session 问题无法自动完成，从 currentUser 回读结果
  static Future<String?> signInWithGithub() async {
    try {
      // 先尝试标准流程
      final result = await _auth.signInWithProvider(GithubAuthProvider());
      final token = (await result.user?.getIdTokenResult(true))?.token;
      if (token != null && token.isNotEmpty) return token;
    } on FirebaseAuthException {
      // signInWithProvider 内部 redirect 可能丢失 session 状态，
      // 但实际上 Firebase Auth 已将用户写入本地缓存，
      // 尝试从缓存中读取当前用户
    }

    // 回退：检查用户是否实际已登录（Firebase Auth 本地缓存）
    final user = _auth.currentUser;
    if (user != null) {
      try {
        return (await user.getIdTokenResult(true)).token;
      } catch (_) {}
    }

    return null;
  }

  // ---- 通用登录方法 -----------------------------------------------------------

  /// 根据 [provider] 选择对应的登录方式。
  ///
  /// [provider] 可选值：'google' 或 'github'。
  static Future<String?> signIn(String provider) {
    switch (provider) {
      case 'google':
        return signInWithGoogle();
      case 'github':
        return signInWithGithub();
      default:
        throw ArgumentError('Unknown provider: $provider');
    }
  }

  // ---- 用户信息 / 退出 --------------------------------------------------------

  /// 当前登录用户，未登录时返回 null。
  static User? currentUser() => _auth.currentUser;

  /// 退出登录，清除 Firebase 及 Google 会话。
  static Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) await _googleSignIn.signOut();
  }
}
