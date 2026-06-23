import 'package:flutter/material.dart';
import '../models/diagnostic.dart';

/// ScenePreviewCard: シーン選択用のカード
/// 
/// 表示内容:
/// - シーン名
/// - キャラクター名
/// - 難易度タグ
/// - お気に入りボタン
class ScenePreviewCard extends StatefulWidget {
  final int sceneId;
  final String sceneName;
  final String characterName;
  final String description;
  final UserDiagnosticLevel recommendedLevel;
  final bool isFavorite;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavoriteToggle;

  const ScenePreviewCard({
    Key? key,
    required this.sceneId,
    required this.sceneName,
    required this.characterName,
    required this.description,
    required this.recommendedLevel,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  }) : super(key: key);

  @override
  State<ScenePreviewCard> createState() => _ScenePreviewCardState();
}

class _ScenePreviewCardState extends State<ScenePreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _toggleFavorite() {
    if (widget.isFavorite) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    widget.onFavoriteToggle?.call(!widget.isFavorite);
  }

  Color _getLevelColor(UserDiagnosticLevel level) {
    switch (level) {
      case UserDiagnosticLevel.beginner:
        return const Color(0xFF66BB6A);
      case UserDiagnosticLevel.intermediate:
        return const Color(0xFFFF9800);
      case UserDiagnosticLevel.advanced:
        return const Color(0xFFEF5350);
    }
  }

  String _getLevelLabel(UserDiagnosticLevel level) {
    return DiagnosticResult.getLevelLabel(level);
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(widget.recommendedLevel);
    final levelLabel = _getLevelLabel(widget.recommendedLevel);

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー: シーン名 + お気に入りボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sceneName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'キャラ: ${widget.characterName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.2)
                        .animate(_animationController),
                    child: IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                    ),
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
                  color: levelColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '推奨: $levelLabel',
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
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
