import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StreakService
/// ユーザーのストリーク（連続学習日数）を管理
/// ローカル：SharedPreferences（高速）、リモート：Supabase（バックアップ）
class StreakService {
  final logger = Logger('StreakService');

  static final StreakService _instance = StreakService._internal();

  factory StreakService() {
    return _instance;
  }

  StreakService._internal();

  late SharedPreferences _prefs;
  late SupabaseClient _supabase;
  bool _isInitialized = false;

  /// 初期化
  Future<void> initialize({
    required SharedPreferences prefs,
    required SupabaseClient supabase,
  }) async {
    if (_isInitialized) return;
    _prefs = prefs;
    _supabase = supabase;
    _isInitialized = true;
  }

  /// 現在のストリーク日数を取得
  Future<int> getCurrentStreak(String userId, String sceneId) async {
    try {
      // ローカルから取得（高速）
      final key = 'streak_${userId}_${sceneId}_days';
      final localStreak = _prefs.getInt(key) ?? 0;

      // Supabaseから同期（背景）
      _syncStreakFromSupabase(userId, sceneId).ignore();

      return localStreak;
    } catch (e) {
      logger.info('[StreakService] Error getting current streak: $e');
      return 0;
    }
  }

  /// ストリークをインクリメント（チャット送信時に呼び出し）
  Future<int> incrementStreak(String userId, String sceneId) async {
    try {
      final key = 'streak_${userId}_${sceneId}_days';
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';
      final today = DateTime.now().toUtc();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 最後の更新日を確認（同じ日に複数回インクリメントされないようにする）
      final lastUpdate = _prefs.getString(lastUpdateKey) ?? '';

      if (lastUpdate == todayStr) {
        // 今日は既にインクリメント済み
        return _prefs.getInt(key) ?? 0;
      }

      // ストリーク数をインクリメント
      final currentStreak = _prefs.getInt(key) ?? 0;
      final newStreak = currentStreak + 1;

      // ローカル更新
      await _prefs.setInt(key, newStreak);
      await _prefs.setString(lastUpdateKey, todayStr);

      // Supabase へ更新（背景）
      _updateStreakInSupabase(userId, sceneId, newStreak).ignore();

      logger.info('[StreakService] Streak incremented: $newStreak days for $sceneId');
      return newStreak;
    } catch (e) {
      logger.info('[StreakService] Error incrementing streak: $e');
      return 0;
    }
  }

  /// ストリークをリセット（ストリーク終了時）
  Future<void> resetStreak(String userId, String sceneId) async {
    try {
      final key = 'streak_${userId}_${sceneId}_days';
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';

      // ローカルリセット
      await _prefs.remove(key);
      await _prefs.remove(lastUpdateKey);

      // Supabase へリセット（背景）
      _updateStreakInSupabase(userId, sceneId, 0).ignore();

      logger.info('[StreakService] Streak reset for $sceneId');
    } catch (e) {
      logger.info('[StreakService] Error resetting streak: $e');
    }
  }

  /// 全ストリーク情報を取得（ダッシュボード用）
  Future<Map<String, int>> getAllStreaks(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final streaks = <String, int>{};

      for (final key in allKeys) {
        if (key.startsWith('streak_${userId}_') && key.endsWith('_days')) {
          final sceneId = key.replaceAll('streak_${userId}_', '').replaceAll('_days', '');
          final streakDays = prefs.getInt(key) ?? 0;
          if (streakDays > 0) {
            streaks[sceneId] = streakDays;
          }
        }
      }

      return streaks;
    } catch (e) {
      logger.info('[StreakService] Error getting all streaks: $e');
      return {};
    }
  }

  /// ===== Internal Sync Methods =====

  /// Supabase からストリークを同期
  Future<void> _syncStreakFromSupabase(String userId, String sceneId) async {
    try {
      final response = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .maybeSingle();

      if (response != null) {
        final streakDays = response['streak_days'] ?? 0;
        final key = 'streak_${userId}_${sceneId}_days';
        await _prefs.setInt(key, streakDays);
      }
    } catch (e) {
      logger.info('[StreakService] Error syncing streak from Supabase: $e');
    }
  }

  /// Supabase にストリークを更新
  Future<void> _updateStreakInSupabase(String userId, String sceneId, int streakDays) async {
    try {
      await _supabase.from('user_streaks').upsert({
        'user_id': userId,
        'scene_id': sceneId,
        'streak_days': streakDays,
        'last_updated': DateTime.now().toIso8601String(),
      });
      logger.info('[StreakService] Streak synced to Supabase: $streakDays days');
    } catch (e) {
      logger.info('[StreakService] Error updating streak in Supabase: $e');
    }
  }
}
