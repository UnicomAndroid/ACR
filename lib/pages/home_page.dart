import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/recording_service.dart';
import '../widgets/search_header.dart';
import 'settings_tab.dart';
import 'recording_tab.dart';
import 'archive_tab.dart';

/// 宽度断点：小于此值使用底部导航，否则左侧导航栏
const _kCompactWidth = 600.0;

enum AppTab { recording, archive, settings }

// ---- 主页面 -------------------------------------------------------------------

class HomePage extends StatefulWidget {
  final SettingsService settingsService;
  final RecordingService recordingService;
  const HomePage({
    super.key,
    required this.settingsService,
    required this.recordingService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppTab _currentTab = AppTab.recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= _kCompactWidth;

    final body = SafeArea(
      child: Column(
        children: [
          const SearchHeader(),
          Expanded(
            child: IndexedStack(
              index: _currentTab.index,
              children: [
                RecordingTab(recordingService: widget.recordingService),
                ArchiveTab(recordingService: widget.recordingService),
                SettingsTab(
                  settingsService: widget.settingsService,
                  recordingService: widget.recordingService,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 宽屏：左侧 NavigationRail
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 6,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: NavigationRail(
                selectedIndex: _currentTab.index,
                onDestinationSelected: (i) =>
                    setState(() => _currentTab = AppTab.values[i]),
                backgroundColor: scheme.surface,
                groupAlignment: 0.0,
                indicatorColor: scheme.secondaryContainer,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.keyboard_voice_outlined),
                    selectedIcon: Icon(Icons.keyboard_voice),
                    label: Text('录音'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.archive_outlined),
                    selectedIcon: Icon(Icons.archive),
                    label: Text('归档'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('设置'),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    // 窄屏：底部 NavigationBar
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (i) =>
            setState(() => _currentTab = AppTab.values[i]),
        backgroundColor: scheme.surface,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        indicatorColor: scheme.secondaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.keyboard_voice_outlined),
            selectedIcon: Icon(Icons.keyboard_voice),
            label: '录音',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: '归档',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
