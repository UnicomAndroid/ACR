import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'firebase_options.dart';

import 'services/settings_service.dart';
import 'services/recording_service.dart';
import 'pages/home_page.dart';

/// =============================================================================
/// 应用程序入口点
/// =============================================================================
///
/// 启动流程：
///   1. 绑定 Flutter 引擎
///   2. 检测 Android 设备是否支持 Google Play Services（谷歌三大件）
///   3. 条件性初始化 Firebase（仅支持谷歌服务的设备）
///   4. 执行临时的 Google 登录测试逻辑（TODO: 后续移除）
///   5. 加载持久化的用户设置（主题模式、配色方案）
///   6. 启动应用
///
/// 注意事项：
///   - 部分国产 Android 手机不支持谷歌服务，此类设备跳过 Firebase 初始化
///   - 设置服务 (SettingsService) 必须在 runApp 之前完成加载，
///     以确保首个帧渲染时就使用正确的主题配置
void main() async {
  // ---------------------------------------------------------------------------
  // 步骤 1: 确保 Flutter 框架绑定完成，后续才能使用插件
  // ---------------------------------------------------------------------------
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 步骤 2: 集成 Firebase — 仅支持谷歌服务的设备
  // ---------------------------------------------------------------------------
  // Android 平台需要检测 Google Play Services 是否可用。
  // availability.value == 5 表示 GooglePlayServicesAvailability.success
  // 部分国产 ROM（如华为、小米部分机型）可能不内置谷歌服务框架。
  GooglePlayServicesAvailability? availability;
  if (Platform.isAndroid) {
    availability = await GoogleApiAvailability.instance
        .checkGooglePlayServicesAvailability();
  }

  // 仅当设备支持谷歌服务时才初始化 Firebase。
  // 不支持谷歌服务的设备（如某些中国市场 Android 手机）跳过此步骤，
  // 应用将以离线/本地模式运行，不依赖云端功能。
  if (!Platform.isAndroid ||
      availability == GooglePlayServicesAvailability.success) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ---------------------------------------------------------------------------
  // 步骤 3: 初始化用户设置
  // ---------------------------------------------------------------------------
  // 通过工厂构造创建并加载持久化设置
  final settingsService = await SettingsService.create();

  // ---------------------------------------------------------------------------
  // 步骤 4: 初始化录音服务
  // ---------------------------------------------------------------------------
  // 录音服务管理两套录音来源：
  //   - Flutter 端手动录音（flutter_sound → WAV）
  //   - 原生层通话录音（InCallService → Opus/AAC/FLAC 等）
  final recordingService = RecordingService(
    storagePath: settingsService.recordingPath,
    sampleRate: settingsService.sampleRate,
    bitRate: settingsService.bitRate,
  );

  // 加载原生通话录音列表（首次加载 + 定期刷新）
  await recordingService.refreshNativeRecordings();

  // 当设置变更时，同步更新录音服务 + 原生层
  settingsService.addListener(() {
    // 本地录音参数
    recordingService.setStoragePath(settingsService.recordingPath);
    recordingService.setSampleRate(settingsService.sampleRate);
    recordingService.setBitRate(settingsService.bitRate);

    // 存储路径变更后，重新扫描原生录音文件
    recordingService.refreshNativeRecordings();
  });

  // ---------------------------------------------------------------------------
  // 步骤 5: 启动 Flutter 应用
  // ---------------------------------------------------------------------------
  // 将 SettingsService 和 RecordingService 实例通过构造函数注入 MyApp，
  // 整个应用的任何页面都可以通过 widget 树访问到这些服务。
  // 没有使用外部状态管理库（如 Provider/Riverpod），
  // 采用最简单的构造器注入 + ChangeNotifier + ListenableBuilder 模式。
  runApp(MyApp(
    settingsService: settingsService,
    recordingService: recordingService,
  ));
}

/// =============================================================================
/// MyApp — 应用程序根 Widget
/// =============================================================================
///
/// 职责：
///   1. 响应设置变化（主题模式、配色方案），重建 MaterialApp
///   2. 基于当前选中的种子颜色生成 Material 3 的亮色/暗色 ColorScheme
///   3. 配置全局主题（AppBar、Card、InputDecoration、ElevatedButton 等）
///   4. 通过 themeMode 控制亮色/暗色/跟随系统三种模式
///
/// 架构说明：
///   - 使用 ListenableBuilder 包裹 MaterialApp，监听 SettingsService 的变化
///   - 当用户在设置页面切换配色方案或主题模式时，SettingsService 调用
///     notifyListeners()，触发 ListenableBuilder 重建，重新生成 ColorScheme
///   - 不使用 dynamic_color 包——所有颜色由 ColorScheme.fromSeed() 从种子色生成，
///     确保跨平台一致的视觉效果（不受系统壁纸影响）
class MyApp extends StatelessWidget {
  /// 设置服务实例，由 main() 创建并注入
  final SettingsService settingsService;

  /// 录音服务实例，由 main() 创建并注入
  final RecordingService recordingService;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.recordingService,
  });

  /// 默认种子颜色（Ocean Blue），用于 ColorScheme.fromSeed() 生成调色板
  static const _seedColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // ListenableBuilder:
    //   监听 settingsService（ChangeNotifier），当设置项发生变更时自动重建子树。
    //   这是 Flutter 内置的轻量级响应式方案，无需额外依赖。
    // -------------------------------------------------------------------------
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        // 使用默认种子颜色（Ocean Blue）生成配色方案

        // -------------------------------------------------------------------
        // 生成 Material 3 ColorScheme
        // -------------------------------------------------------------------
        // ColorScheme.fromSeed() 是 Material 3 的动态配色生成方法，
        // 接收一个种子颜色 (seedColor)，自动生成完整的语义化调色板：
        //   - primary / onPrimary       : 主色 / 主色上的文字
        //   - secondary / onSecondary   : 辅助色
        //   - tertiary / onTertiary     : 第三色（对比色）
        //   - error / onError           : 错误色
        //   - surface / onSurface       : 表面色 / 表面文字
        //   - surfaceContainerHighest   : 最高层级容器色（用于输入框填充等）
        //   - outline / outlineVariant  : 边框色 / 边框变体
        //
        // 分别生成亮色和暗色两套方案，同时支持 Light/Dark 主题。
        final lightScheme = ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          // 应用标题（Android 任务列表中使用）
          title: 'ACR',

          // 关闭右上角 DEBUG 标签
          debugShowCheckedModeBanner: false,

          // ===================================================================
          // 亮色主题 (Light Theme)
          // ===================================================================
          // 设计理念：
          //   - 白色背景 + 鲜艳主色 + 清晰的阴影层次
          //   - 使用 surfaceTintColor: Colors.transparent 关闭 Material 3
          //     的色调叠加（tint overlay），让 elevation 阴影真实可见
          //   - 圆角 12px 的卡片和按钮，营造现代、柔和的感觉
          theme: ThemeData(
            // 整个应用的色彩方案
            colorScheme: lightScheme,

            // 启用 Material 3（M3）设计语言
            useMaterial3: true,

            // Scaffold 底色设为 surface（亮色下即为纯白 #FFFFFF）
            scaffoldBackgroundColor: lightScheme.surface,

            // ---------------------------------------------------------------
            // AppBar 全局样式
            // ---------------------------------------------------------------
            // elevation: 2 产生轻量阴影，与内容区域形成层级分离
            // surfaceTintColor: transparent 是关键——不启用 M3 的色调叠加，
            // 让 elevation 渲染为真实的灰色投影（shadowColor: black26）
            // centerTitle: false 使标题左对齐（Material Design 建议）
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.surface,
              foregroundColor: lightScheme.onSurface,
              elevation: 2,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              centerTitle: false,
            ),

            // ---------------------------------------------------------------
            // Card 全局样式
            // ---------------------------------------------------------------
            // 卡片使用 elevation: 1.5 和淡黑色投影，
            // 形成轻微的"浮起"效果，增加层次感
            cardTheme: CardThemeData(
              elevation: 1.5,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black12,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),

            // ---------------------------------------------------------------
            // InputDecoration 全局样式
            // ---------------------------------------------------------------
            // 输入框使用浅色填充背景 + 无边框设计，
            // filled: true 启用填充，fillColor 使用 surfaceContainerHighest
            // 这是 M3 语义色中最高层级的容器色，适合输入框背景
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surfaceContainerHighest.withAlpha(120),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),

            // ---------------------------------------------------------------
            // ElevatedButton 全局样式
            // ---------------------------------------------------------------
            // 主色调实心按钮，圆角 12px，
            // 投影使用主色的半透明版本（alpha 60），
            // 产生"发光按钮"的视觉效果
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightScheme.primary,
                foregroundColor: lightScheme.onPrimary,
                elevation: 1,
                surfaceTintColor: Colors.transparent,
                shadowColor: lightScheme.primary.withAlpha(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // ===================================================================
          // 暗色主题 (Dark Theme)
          // ===================================================================
          // 暗色主题与亮色主题保持相同的结构，但调整了投影颜色：
          //   - 亮色下使用 black12/black26 投影
          //   - 暗色下使用 black26/black38 投影（更深的半透明黑）
          //   因为暗色背景下浅色投影不可见
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: darkScheme.surface,

            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.surface,
              foregroundColor: darkScheme.onSurface,
              elevation: 2,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black38,
              centerTitle: false,
            ),

            cardTheme: CardThemeData(
              elevation: 1.5,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              // alpha 80 产生更细腻的暗色填充，不会过亮
              fillColor: darkScheme.surfaceContainerHighest.withAlpha(80),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkScheme.primary,
                foregroundColor: darkScheme.onPrimary,
                elevation: 1,
                surfaceTintColor: Colors.transparent,
                // alpha 80 在暗色下产生更明显的发光感
                shadowColor: darkScheme.primary.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // 主题模式：从设置服务读取
          // -------------------------------------------------------------------
          // ThemeMode.system  : 跟随系统暗色模式自动切换
          // ThemeMode.light   : 始终使用亮色主题
          // ThemeMode.dark    : 始终使用暗色主题
          themeMode: settingsService.themeMode,

          // 主页面 — 带底部导航栏的三标签页主页
          home: HomePage(
            settingsService: settingsService,
            recordingService: recordingService,
          ),
        );
      },
    );
  }
}
