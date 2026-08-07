import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/l10n/label_helpers.dart';
import '../models/diagnostic.dart';
import '../services/learner_preferences_service.dart';
import '../services/scene_service.dart';
import '../widgets/level_test_card.dart';
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

  /// レベルテストカードでの受験、または設定画面での再受験によって
  /// レベルが更新された可能性がある際に呼ばれる(施策③)。
  final VoidCallback? onLevelUpdated;

  const SceneSelectionScreen({
    super.key,
    required this.userLevel,
    this.isPremiumUser = false,
    this.onPremiumUnlocked,
    this.onLevelUpdated,
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
          // チャット画面内(レート制限到達時等)での購入成功も
          // シーンロック表示に反映できるようにする。
          onPremiumUnlocked: onPremiumUnlocked,
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

  /// D案(競合分析): 前回シーンの「続きから」バナー。1タップで会話再開できるようにし、
  /// 起動→会話開始の手数を最小化する。前回記録がない/プレミアム未解放シーンの場合は
  /// 何も表示しない。
  Widget _buildResumeBanner(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<String?>(
      future: LearnerPreferencesService().getLastSceneId(),
      builder: (context, snapshot) {
        final lastSceneId = snapshot.data;
        if (lastSceneId == null) return const SizedBox.shrink();

        final id = int.tryParse(lastSceneId);
        if (id == null) return const SizedBox.shrink();

        Scene? scene;
        for (final candidate in SceneService.allScenes) {
          if (candidate.id == id) {
            scene = candidate;
            break;
          }
        }
        if (scene == null) return const SizedBox.shrink();
        // プレミアム未解放シーンはバナーを出さない(タップ即会話の期待を裏切らないため)。
        if (scene.isPremium && !isPremiumUser) return const SizedBox.shrink();

        final resumeScene = scene;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: resumeScene.accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openScene(context, resumeScene),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_fill,
                        color: resumeScene.accentColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.resumeContinue,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${sceneName(l, resumeScene.id)} · ${resumeScene.characterName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 「続きから」バナーが実際に表示される場合の対象シーンIDを返す
  /// (バナーの非表示条件と同一ロジック: 未記録/不正ID/未解放シーンはnull)。
  /// 「最近使ったシーン」セクションでの重複除外にのみ使う。
  Future<String?> _getVisibleResumeSceneId() async {
    final lastSceneId = await LearnerPreferencesService().getLastSceneId();
    if (lastSceneId == null) return null;

    final id = int.tryParse(lastSceneId);
    if (id == null) return null;

    Scene? scene;
    for (final candidate in SceneService.allScenes) {
      if (candidate.id == id) {
        scene = candidate;
        break;
      }
    }
    if (scene == null) return null;
    if (scene.isPremium && !isPremiumUser) return null;

    return lastSceneId;
  }

  /// 「最近使ったシーン」セクション。最近開いたシーン(最大3件、最新順)を
  /// 上部に表示する。履歴が無ければセクションごと非表示にする。
  /// 「続きから」バナーに表示中のシーンは重複して見えるため除外する
  /// (除外後の残り件数が3件未満でも補充はしない)。
  Widget _buildRecentScenesSection(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<(String? resumeSceneId, List<String> recentIds)>(
      future: () async {
        final resumeSceneId = await _getVisibleResumeSceneId();
        final recentIds = await LearnerPreferencesService().getRecentSceneIds();
        return (resumeSceneId, recentIds);
      }(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final (resumeSceneId, recentIds) = data;

        final filteredIds =
            recentIds.where((id) => id != resumeSceneId).toList();
        if (filteredIds.isEmpty) return const SizedBox.shrink();

        final recentScenes = <Scene>[];
        for (final idStr in filteredIds) {
          final id = int.tryParse(idStr);
          if (id == null) continue;
          for (final candidate in SceneService.allScenes) {
            if (candidate.id == id) {
              recentScenes.add(candidate);
              break;
            }
          }
        }
        if (recentScenes.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l.sceneSectionRecentlyPlayed),
            ...recentScenes.map(
              (scene) => _buildCard(
                context,
                scene,
                isLocked: scene.isPremium && !isPremiumUser,
              ),
            ),
          ],
        );
      },
    );
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
            onPressed: () async {
              // 設定画面でレベルテストを再受験した可能性があるため、
              // 戻ってきたら無条件にレベル再取得を促す(害はなく安全側)。
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              onLevelUpdated?.call();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildResumeBanner(context),
          _buildRecentScenesSection(context),
          LevelTestCard(onLevelUpdated: onLevelUpdated),

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
