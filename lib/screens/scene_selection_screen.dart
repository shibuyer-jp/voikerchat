import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/l10n/label_helpers.dart';
import '../models/diagnostic.dart';
import '../services/scene_service.dart';
import '../widgets/scene_preview_card.dart';
import 'chat_screen.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

/// SceneSelectionScreen: シーン選択画面
///
/// セクション構成:
/// 1. おすすめ         — ユーザーレベルに合った無料シーン
/// 2. 全無料           — すべての無料シーン
/// 3. 実用シーン(プレミアム) — 就労・生活シーン(T-34、id 14〜18)
/// 4. アニメシーン(プレミアム) — id 9〜13
/// (非premiumユーザーは3・4ともロック表示)
class SceneSelectionScreen extends StatelessWidget {
  final UserDiagnosticLevel userLevel;
  final bool isPremiumUser;

  /// ペイウォールでの購入/復元が成功した時に呼ばれる(Premium状態の再取得を促す)。
  final VoidCallback? onPremiumUnlocked;

  const SceneSelectionScreen({
    super.key,
    required this.userLevel,
    this.isPremiumUser = false,
    this.onPremiumUnlocked,
  });

  /// 無料シーンを開いてチャット画面へ遷移
  void _openScene(BuildContext context, Scene scene) {
    final l10n = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sceneId: scene.id.toString(),
          sceneName: sceneName(l10n, scene.id),
          sceneData: scene.toSceneData(),
        ),
      ),
    );
  }

  /// ロック済みプレミアムシーンをタップ → ペイウォールへ遷移。
  /// 購入/復元成功で戻ってきたら呼び出し元にPremium状態の再取得を促す。
  Future<void> _openPaywall(BuildContext context) async {
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (unlocked == true) {
      onPremiumUnlocked?.call();
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Scene scene, {
    required bool isLocked,
  }) {
    final l10n = AppLocalizations.of(context);
    return ScenePreviewCard(
      sceneId: scene.id,
      sceneName: sceneName(l10n, scene.id),
      characterName: scene.characterName,
      description: sceneDesc(l10n, scene.id),
      recommendedLevel: scene.recommendedLevel,
      isPremium: scene.isPremium,
      isLocked: isLocked,
      accentColor: scene.accentColor,
      onTap: isLocked
          ? () => _openPaywall(context)
          : () => _openScene(context, scene),
    );
  }

  @override
  Widget build(BuildContext context) {
    // (1) おすすめ: ユーザーレベルに合った無料シーン
    final recommended = SceneService.filterByLevel(userLevel)
        .where((scene) => !scene.isPremium)
        .toList();

    // (2) 全無料シーン
    final freeScenes = SceneService.getFreeScenes();

    // (3) プレミアム実用シーン(T-34、上に配置) / (4) プレミアムアニメシーン
    final premiumPracticalScenes = SceneService.getPremiumPracticalScenes();
    final premiumAnimeScenes = SceneService.getPremiumAnimeScenes();

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.sceneSelectionTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.settingsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (recommended.isNotEmpty) ...[
            _buildSectionHeader(context, l.sceneSectionRecommended),
            ...recommended
                .map((scene) => _buildCard(context, scene, isLocked: false)),
          ],

          _buildSectionHeader(context, l.sceneSectionFree),
          ...freeScenes
              .map((scene) => _buildCard(context, scene, isLocked: false)),

          _buildSectionHeader(context, l.sceneSectionPremiumPractical),
          ...premiumPracticalScenes.map(
            (scene) => _buildCard(context, scene, isLocked: !isPremiumUser),
          ),

          _buildSectionHeader(context, l.sceneSectionPremiumAnime),
          ...premiumAnimeScenes.map(
            (scene) => _buildCard(context, scene, isLocked: !isPremiumUser),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
