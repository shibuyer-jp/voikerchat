import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/l10n/label_helpers.dart';
import '../models/diagnostic.dart';
import '../theme/app_colors.dart';

/// ScenePreviewCard: シーン選択用のカード
///
/// 表示内容:
/// - シーン名
/// - キャラクター名
/// - 難易度タグ
class ScenePreviewCard extends StatefulWidget {
  final int sceneId;
  final String sceneName;
  final String characterName;
  final String description;
  final UserDiagnosticLevel recommendedLevel;
  final bool isPremium;
  final bool isLocked;

  /// シーンごとのアクセント色(未指定時は推奨レベル色にフォールバック)。
  /// キャラクター画像未生成時のプレースホルダー背景にも使う(T-32)。
  final Color? accentColor;

  final VoidCallback? onTap;

  const ScenePreviewCard({
    super.key,
    required this.sceneId,
    required this.sceneName,
    required this.characterName,
    required this.description,
    required this.recommendedLevel,
    this.isPremium = false,
    this.isLocked = false,
    this.accentColor,
    this.onTap,
  });

  @override
  State<ScenePreviewCard> createState() => _ScenePreviewCardState();
}

class _ScenePreviewCardState extends State<ScenePreviewCard> {
  static const double _thumbnailSize = 88;

  Color _getLevelColor(UserDiagnosticLevel level) {
    switch (level) {
      case UserDiagnosticLevel.beginner:
        return AppColors.levelBeginner;
      case UserDiagnosticLevel.intermediate:
        return AppColors.levelIntermediate;
      case UserDiagnosticLevel.advanced:
        return AppColors.levelAdvanced;
    }
  }

  /// `assets/characters/scene_01.webp` 〜 `scene_18.webp`(T-32)。
  /// 未生成のシーンはファイルが存在せず、Image.asset の errorBuilder で
  /// プレースホルダーにフォールバックする。
  String get _assetPath =>
      'assets/characters/scene_${widget.sceneId.toString().padLeft(2, '0')}.webp';

  Widget _buildPlaceholder(Color accentColor) {
    final initial = widget.characterName.isNotEmpty
        ? widget.characterName[0].toUpperCase()
        : '?';
    return Container(
      width: _thumbnailSize,
      height: _thumbnailSize,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),
    );
  }

  Widget _buildThumbnail(Color accentColor) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        _assetPath,
        width: _thumbnailSize,
        height: _thumbnailSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(accentColor),
      ),
    );

    if (!widget.isLocked) return thumbnail;

    // ロック中: 画像を半透明化してロック状態を示す。
    // 鍵アイコンはカード右側(build 内)に1つだけ表示する。以前はサムネイル上にも
    // 白い鍵を重ねていたが、キャラクターの顔を隠すため削除した
    // (DECISIONS.md 2026-09-04)。半透明化はロックの視覚表現として残す。
    return Opacity(opacity: 0.4, child: thumbnail);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levelColor = _getLevelColor(widget.recommendedLevel);
    final levelLabel = levelName(l10n, widget.recommendedLevel);
    final accentColor = widget.accentColor ?? levelColor;

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー: シーン名 + ロックアイコン(プレミアム未解放時)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.sceneName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (widget.isPremium) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.premiumBackground
                                            .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 12,
                                            color: AppColors.premiumText,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            l10n.scenePremiumLabel,
                                            style: const TextStyle(
                                              color: AppColors.premiumText,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.sceneCharacterLabel(widget.characterName),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (widget.isLocked)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.lock, color: Colors.grey),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 説明文
                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    const SizedBox(height: 12),

                    // 推奨レベルタグ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.sceneRecommendedLabel(levelLabel),
                        style: TextStyle(
                          color: levelColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildThumbnail(accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
