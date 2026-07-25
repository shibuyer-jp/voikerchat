import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StreakService
/// ユーザーのストリーク（連続学習日数）を管理
/// ローカル：SharedPreferences（高速・通常時の読み書きの正）、
/// リモート：Supabase（端末変更/再インストール時の復元用バックアップ）
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
  ///
  /// ローカルに値があれば即返す(UXを遅延させない)。裏でSupabaseと
  /// タイムスタンプ比較同期を行う(古い値による上書き防止、後述)。
  /// ローカルに値が無い場合(初回起動/再インストール直後)のみ、
  /// Supabaseからの復元を待ってから値を返す。
  Future<int> getCurrentStreak(String userId, String sceneId) async {
    try {
      final key = 'streak_${userId}_${sceneId}_days';

      if (_prefs.containsKey(key)) {
        final localStreak = _prefs.getInt(key) ?? 0;
        _syncStreakFromSupabaseIfNewer(userId, sceneId).ignore();
        return localStreak;
      }

      return await _restoreStreakFromSupabase(userId, sceneId);
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
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';
      final now = DateTime.now().toUtc();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 最後の更新日を確認（同じ日に複数回インクリメントされないようにする）
      final lastUpdate = _prefs.getString(lastUpdateKey) ?? '';

      if (lastUpdate == todayStr) {
        // 今日は既にインクリメント済み
        return _prefs.getInt(key) ?? 0;
      }

      // ストリーク数をインクリメント
      final currentStreak = _prefs.getInt(key) ?? 0;
      final newStreak = currentStreak + 1;

      // ローカル更新（更新時刻も記録し、後の同期での競合判定に使う）
      await _prefs.setInt(key, newStreak);
      await _prefs.setString(lastUpdateKey, todayStr);
      await _prefs.setString(updatedAtKey, now.toIso8601String());

      // Supabase へ更新（背景）。ローカルと同じ時刻を使う。
      _updateStreakInSupabase(userId, sceneId, newStreak, now).ignore();

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
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';
      final now = DateTime.now().toUtc();

      // ローカルリセット
      await _prefs.remove(key);
      await _prefs.remove(lastUpdateKey);
      await _prefs.remove(updatedAtKey);

      // Supabase へリセット（背景）
      _updateStreakInSupabase(userId, sceneId, 0, now).ignore();

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

  /// ローカルに記録が無い場合(初回起動/再インストール直後)、Supabaseの
  /// 値を無条件に採用してローカルへ書き戻す。復元専用のため、
  /// タイムスタンプ比較は行わない(比較対象のローカル値が無いため)。
  Future<int> _restoreStreakFromSupabase(String userId, String sceneId) async {
    try {
      final response = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .maybeSingle();

      final remoteStreak = (response?['streak_days'] as int?) ?? 0;
      final remoteUpdatedAt = response?['last_updated'] as String?;

      final key = 'streak_${userId}_${sceneId}_days';
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';
      await _prefs.setInt(key, remoteStreak);
      if (remoteUpdatedAt != null) {
        await _prefs.setString(updatedAtKey, remoteUpdatedAt);
      }
      logger.info('[StreakService] Streak restored from Supabase: $remoteStreak days for $sceneId');
      return remoteStreak;
    } catch (e) {
      logger.info('[StreakService] Error restoring streak from Supabase: $e');
      return 0;
    }
  }

  /// ローカルに既に値がある場合の裏同期。
  ///
  /// incrementStreak() のSupabase書き込みはfire-and-forgetのため、
  /// この同期の読み取りがそれより先に完了すると、古いDB値でローカルの
  /// 新しい値を上書きしてしまう競合が起きうる。last_updated タイムスタンプを
  /// 比較し、DB側が厳密に新しい場合のみ採用することでこれを防ぐ。
  ///
  /// ローカルに更新時刻の記録が無い場合(このタイムスタンプ比較導入前からの
  /// 既存値)は、安全側としてローカルを優先し上書きしない
  /// （導入直後の初回同期で既存ユーザーの正しい値を誤って古いDB値に
  /// 置き換えないため。次回incrementStreak()で更新時刻が記録されて以降、
  /// 通常通り比較同期の対象になる）。
  ///
  /// マルチデバイス同時書き込み(同一ユーザーが複数端末でほぼ同時に
  /// incrementStreak()を呼ぶ)によるロスト更新は、本比較だけでは
  /// 解消しない(最後にDBへ書き込んだ方が勝つ)。発生頻度が低く、
  /// 解消には別途キューイング等の設計が必要なため、現時点ではスコープ外
  /// とする(docs/DECISIONS.md参照)。
  Future<void> _syncStreakFromSupabaseIfNewer(String userId, String sceneId) async {
    try {
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';
      final localUpdatedAtRaw = _prefs.getString(updatedAtKey);
      if (localUpdatedAtRaw == null) return;
      final localUpdatedAt = DateTime.tryParse(localUpdatedAtRaw);
      if (localUpdatedAt == null) return;

      final response = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .maybeSingle();
      if (response == null) return;

      final remoteUpdatedAtRaw = response['last_updated'] as String?;
      final remoteUpdatedAt =
          remoteUpdatedAtRaw != null ? DateTime.tryParse(remoteUpdatedAtRaw) : null;
      if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        return;
      }

      final remoteStreak = (response['streak_days'] as int?) ?? 0;
      final key = 'streak_${userId}_${sceneId}_days';
      await _prefs.setInt(key, remoteStreak);
      await _prefs.setString(updatedAtKey, remoteUpdatedAtRaw!);
      logger.info('[StreakService] Streak overwritten by newer Supabase value: $remoteStreak days for $sceneId');
    } catch (e) {
      logger.info('[StreakService] Error syncing streak from Supabase: $e');
    }
  }

  /// Supabase にストリークを更新
  Future<void> _updateStreakInSupabase(
    String userId,
    String sceneId,
    int streakDays,
    DateTime updatedAt,
  ) async {
    try {
      await _supabase.from('user_streaks').upsert({
        'user_id': userId,
        'scene_id': sceneId,
        'streak_days': streakDays,
        'last_updated': updatedAt.toIso8601String(),
      });
      logger.info('[StreakService] Streak synced to Supabase: $streakDays days');
    } catch (e) {
      logger.info('[StreakService] Error updating streak in Supabase: $e');
    }
  }
}
