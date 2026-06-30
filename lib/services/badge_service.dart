import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/badge.dart';
import '../models/message.dart';

/// BadgeService
///
/// バッジの解除判定と永続化を担う。解除状態は SharedPreferences に保存し、
/// 一度解除したバッジは実績が下がっても解除のまま維持する（取り消さない）。
/// 無料ユーザーでも利用できるよう、判定はローカル + Supabase セッションから行う。
class BadgeService {
  BadgeService._internal();

  static final BadgeService _instance = BadgeService._internal();

  factory BadgeService() => _instance;

  final Logger _logger = Logger('BadgeService');

  static const String _unlockedKeyPrefix = 'badge_unlocked_';
  static const String _unlockedAtKeyPrefix = 'badge_unlocked_at_';
  static const String _streakKeySuffix = '_days';

  /// 会話セッション群と SharedPreferences から判定用スナップショットを構築する。
  ///
  /// - 会話数: 全セッションの総メッセージ数の半分（1 往復 = ユーザー + AI = 2 件）
  /// - 基本/アニメシーン: メッセージのあるシーンの種類数（id 1-8 / 9-13）
  /// - 連続日数: `streak_{userId}_{sceneId}_days` の最大値
  BadgeStats buildStats({
    required String userId,
    required List<ConversationSession> sessions,
    required SharedPreferences prefs,
  }) {
    var totalMessages = 0;
    final basicScenes = <String>{};
    final animeScenes = <String>{};

    for (final session in sessions) {
      if (session.totalMessages <= 0) continue;
      totalMessages += session.totalMessages;

      final sceneNumber = int.tryParse(session.sceneId);
      if (sceneNumber == null) continue;
      if (sceneNumber >= 1 && sceneNumber <= 8) {
        basicScenes.add(session.sceneId);
      } else if (sceneNumber >= 9 && sceneNumber <= 13) {
        animeScenes.add(session.sceneId);
      }
    }

    return BadgeStats(
      totalConversations: totalMessages ~/ 2,
      basicScenesUsed: basicScenes.length,
      animeScenesUsed: animeScenes.length,
      maxStreakDays: _maxStreakDays(userId: userId, prefs: prefs),
    );
  }

  int _maxStreakDays({
    required String userId,
    required SharedPreferences prefs,
  }) {
    final prefix = 'streak_${userId}_';
    var maxDays = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix) && key.endsWith(_streakKeySuffix)) {
        final days = prefs.getInt(key) ?? 0;
        if (days > maxDays) maxDays = days;
      }
    }
    return maxDays;
  }

  /// 解除済みバッジ ID の集合を返す。
  Set<String> loadUnlocked(SharedPreferences prefs) {
    final unlocked = <String>{};
    for (final badge in BadgeCatalog.all) {
      if (prefs.getBool('$_unlockedKeyPrefix${badge.id}') ?? false) {
        unlocked.add(badge.id);
      }
    }
    return unlocked;
  }

  /// バッジ解除日時（解除済みのみ。未解除/不正値は null）。
  DateTime? unlockedAt(SharedPreferences prefs, String badgeId) {
    final raw = prefs.getString('$_unlockedAtKeyPrefix$badgeId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// スナップショットを評価し、新たに解除されたバッジを永続化して返す。
  ///
  /// 戻り値は「今回新たに解除されたバッジ」のリスト（祝福表示用）。
  /// 既に解除済みのバッジは再評価しない（解除を取り消さない）。
  Future<List<AppBadge>> evaluateAndPersist({
    required BadgeStats stats,
    required SharedPreferences prefs,
  }) async {
    final newlyUnlocked = <AppBadge>[];
    final now = DateTime.now().toIso8601String();

    for (final badge in BadgeCatalog.all) {
      final alreadyUnlocked =
          prefs.getBool('$_unlockedKeyPrefix${badge.id}') ?? false;
      if (alreadyUnlocked) continue;

      final current = stats.currentValueFor(badge.conditionType);
      if (current >= badge.threshold) {
        await prefs.setBool('$_unlockedKeyPrefix${badge.id}', true);
        await prefs.setString('$_unlockedAtKeyPrefix${badge.id}', now);
        newlyUnlocked.add(badge);
        _logger.info('[BadgeService] Unlocked: ${badge.id}');
      }
    }
    return newlyUnlocked;
  }
}
