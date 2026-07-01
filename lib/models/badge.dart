import 'package:flutter/material.dart';

/// バッジの解除条件タイプ。
enum BadgeConditionType {
  /// 累計会話数（ユーザー + AI のやり取りを 1 往復 = 1 とカウント）
  conversations,

  /// 利用した基本シーン（id 1-8）の種類数
  basicScenes,

  /// 利用したアニメシーン（id 9-13）の種類数
  animeScenes,

  /// 連続学習日数（全シーン中の最大ストリーク）
  streakDays,
}

/// バッジ 1 個の定義（不変）。
///
/// Material の `Badge` ウィジェットと名前が衝突しないよう `AppBadge` とする。
@immutable
class AppBadge {
  const AppBadge({
    required this.id,
    required this.icon,
    required this.conditionType,
    required this.threshold,
    required this.color,
  });

  final String id;
  final IconData icon;
  final BadgeConditionType conditionType;
  final int threshold;
  final Color color;
}

/// バッジ判定に必要な実績スナップショット。
@immutable
class BadgeStats {
  const BadgeStats({
    required this.totalConversations,
    required this.basicScenesUsed,
    required this.animeScenesUsed,
    required this.maxStreakDays,
  });

  final int totalConversations;
  final int basicScenesUsed;
  final int animeScenesUsed;
  final int maxStreakDays;

  /// 指定タイプの現在値を返す（進捗バー算出・解除判定に使用）。
  int currentValueFor(BadgeConditionType type) {
    switch (type) {
      case BadgeConditionType.conversations:
        return totalConversations;
      case BadgeConditionType.basicScenes:
        return basicScenesUsed;
      case BadgeConditionType.animeScenes:
        return animeScenesUsed;
      case BadgeConditionType.streakDays:
        return maxStreakDays;
    }
  }
}

/// アプリ内バッジのカタログ（単一の正本）。
class BadgeCatalog {
  static const List<AppBadge> all = [
    AppBadge(
      id: 'first_step',
      icon: Icons.flag,
      conditionType: BadgeConditionType.conversations,
      threshold: 1,
      color: Color(0xFF4CAF50),
    ),
    AppBadge(
      id: 'talkative_10',
      icon: Icons.forum,
      conditionType: BadgeConditionType.conversations,
      threshold: 10,
      color: Color(0xFF2196F3),
    ),
    AppBadge(
      id: 'conversation_master_50',
      icon: Icons.workspace_premium,
      conditionType: BadgeConditionType.conversations,
      threshold: 50,
      color: Color(0xFF9C27B0),
    ),
    AppBadge(
      id: 'basic_master',
      icon: Icons.school,
      conditionType: BadgeConditionType.basicScenes,
      threshold: 8,
      color: Color(0xFF0099FF),
    ),
    AppBadge(
      id: 'anime_explorer',
      icon: Icons.auto_awesome,
      conditionType: BadgeConditionType.animeScenes,
      threshold: 1,
      color: Color(0xFFFF9800),
    ),
    AppBadge(
      id: 'anime_master',
      icon: Icons.star,
      conditionType: BadgeConditionType.animeScenes,
      threshold: 5,
      color: Color(0xFFE91E63),
    ),
    AppBadge(
      id: 'streak_3',
      icon: Icons.local_fire_department,
      conditionType: BadgeConditionType.streakDays,
      threshold: 3,
      color: Color(0xFFFF5722),
    ),
    AppBadge(
      id: 'streak_7',
      icon: Icons.whatshot,
      conditionType: BadgeConditionType.streakDays,
      threshold: 7,
      color: Color(0xFFF44336),
    ),
    AppBadge(
      id: 'streak_30',
      icon: Icons.emoji_events,
      conditionType: BadgeConditionType.streakDays,
      threshold: 30,
      color: Color(0xFFFFC107),
    ),
  ];
}
