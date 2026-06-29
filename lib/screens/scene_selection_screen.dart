import 'package:flutter/material.dart';
import '../models/diagnostic.dart';
import '../services/scene_service.dart';
import '../widgets/scene_preview_card.dart';
import 'chat_screen.dart';

/// SceneSelectionScreen: シーン選択画面
///
/// セクション構成:
/// 1. おすすめ   — ユーザーレベルに合った無料シーン
/// 2. 全無料     — すべての無料シーン
/// 3. プレミアム — 有料シーン（非premiumユーザーはロック表示）
class SceneSelectionScreen extends StatelessWidget {
  final UserDiagnosticLevel userLevel;
  final bool isPremiumUser;

  const SceneSelectionScreen({
    super.key,
    required this.userLevel,
    this.isPremiumUser = false,
  });

  /// 無料シーンを開いてチャット画面へ遷移
  void _openScene(BuildContext context, Scene scene) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sceneId: scene.id.toString(),
          sceneName: scene.name,
          sceneData: scene.toSceneData(),
        ),
      ),
    );
  }

  /// ロック済みプレミアムシーンをタップした時の案内
  void _showLockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プレミアム機能（近日実装）')),
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
    return ScenePreviewCard(
      sceneId: scene.id,
      sceneName: scene.name,
      characterName: scene.characterName,
      description: scene.description,
      recommendedLevel: scene.recommendedLevel,
      isPremium: scene.isPremium,
      isLocked: isLocked,
      onTap: isLocked
          ? () => _showLockedMessage(context)
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

    // (3) プレミアムシーン
    final premiumScenes = SceneService.getPremiumScenes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('シーンを選ぶ'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (recommended.isNotEmpty) ...[
            _buildSectionHeader(context, 'あなたへのおすすめ'),
            ...recommended
                .map((scene) => _buildCard(context, scene, isLocked: false)),
          ],

          _buildSectionHeader(context, '無料シーン'),
          ...freeScenes
              .map((scene) => _buildCard(context, scene, isLocked: false)),

          _buildSectionHeader(context, 'プレミアムシーン'),
          ...premiumScenes.map(
            (scene) => _buildCard(context, scene, isLocked: !isPremiumUser),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
