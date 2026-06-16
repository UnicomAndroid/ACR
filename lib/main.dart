import 'package:flutter/material.dart';

import 'services/settings_service.dart';
import 'services/recording_service.dart';
import 'services/model_manager.dart';
import 'services/sherpa_service.dart';
import 'pages/home_page.dart';

/// 应用程序入口点
///
/// 启动流程：
///   1. 绑定 Flutter 引擎
///   2. 加载持久化的用户设置
///   3. 初始化录音服务并加载录音列表
///   4. 启动应用
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加载用户设置
  final settingsService = await SettingsService.create();

  // 初始化录音服务
  final recordingService = RecordingService(
    storagePath: settingsService.recordingPath,
    sampleRate: settingsService.sampleRate,
    bitRate: settingsService.bitRate,
  );

  // 同步设置变更
  settingsService.addListener(() {
    recordingService.setStoragePath(settingsService.recordingPath);
    recordingService.setSampleRate(settingsService.sampleRate);
    recordingService.setBitRate(settingsService.bitRate);
    recordingService.refreshNativeRecordings();
  });

  runApp(MyApp(
    settingsService: settingsService,
    recordingService: recordingService,
  ));

  // 非关键初始化 + 录音列表加载延迟到首帧之后，避免阻塞 UI 启动
  WidgetsBinding.instance.addPostFrameCallback((_) {
    recordingService.refreshNativeRecordings();
    SherpaService.I.setRecordingService(recordingService);
    ModelManager.I.init(); SherpaService.I.init();
  });
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  final RecordingService recordingService;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.recordingService,
  });

  static const _seedColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        final lightScheme = ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          title: 'ACR',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: lightScheme.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.surface,
              foregroundColor: lightScheme.onSurface,
              elevation: 2,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              elevation: 1.5,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black12,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surfaceContainerHighest.withAlpha(120),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
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
                shadowColor: darkScheme.primary.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          themeMode: settingsService.themeMode,

          home: HomePage(
            settingsService: settingsService,
            recordingService: recordingService,
          ),
        );
      },
    );
  }
}
