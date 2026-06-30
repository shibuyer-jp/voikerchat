import 'package:flutter/material.dart';
import '../models/diagnostic.dart';
import 'scene_selection_screen.dart';
import 'badges_screen.dart';
import 'stats_screen.dart';
import 'notification_history_screen.dart';

/// HomeScreen: オンボーディング完了後のメインハブ
///
/// 下部ナビゲーションで4タブを切り替える:
/// - シーン   : SceneSelectionScreen（会話練習の入口）
/// - バッジ   : BadgesScreen（獲得バッジ・進捗）
/// - 統計     : StatsScreen（学習統計）
/// - 通知     : NotificationHistoryScreen（通知履歴）
///
/// 各タブは自己完結した Scaffold を持つため IndexedStack で保持し、
/// タブ切替時も状態（スクロール位置など）を維持する。
class HomeScreen extends StatefulWidget {
  final UserDiagnosticLevel userLevel;
  final bool isPremiumUser;

  const HomeScreen({
    super.key,
    required this.userLevel,
    this.isPremiumUser = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _tabs = [
    SceneSelectionScreen(
      userLevel: widget.userLevel,
      isPremiumUser: widget.isPremiumUser,
    ),
    const BadgesScreen(),
    const StatsScreen(),
    const NotificationHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // 選択中のタブのみを生成する（遅延マウント）。
    // IndexedStack は全タブを同時生成するため、Supabase をコンストラクタ/
    // initState で参照する統計・通知画面が Home 表示時に即時実行され、
    // 未初期化時にクラッシュし得る。デフォルトのシーンタブは Supabase 非依存。
    // 代償: タブ切替時に各画面が再生成され状態（スクロール位置等）は保持されない。
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'シーン',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'バッジ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '統計',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: '通知',
          ),
        ],
      ),
    );
  }
}
