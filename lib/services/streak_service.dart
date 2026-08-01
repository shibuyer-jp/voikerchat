import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StreakService
/// ユーザーのストリーク（連続学習日数）を管理
/// ローカル：SharedPreferences（高速・通常時の読み書きの正）、
/// リモート：Supabase（端末変更/再インストール時の復元用バックアップ）
///
/// 日付境界(「今日」「昨日」の判定)は端末ローカルタイム基準(Build 13、
/// 2026-07-27)。主要ターゲットがフィリピン(UTC+8)在住の日本語学習者で
/// あり、UTC基準だと日付切替がJST 09:00/フィリピン時間08:00に発生して
/// 朝型ユーザーに「同日2回加算」「学習したのに前日扱い」が起きうるため。
/// 一方、複数端末間の新旧比較(`last_updated`)は絶対時刻の比較が必要な
/// ため、従来通りUTCのまま扱う(`_updateStreakInSupabase`/
/// `_syncStreakFromSupabaseIfNewer`参照)。この2つは別概念。
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

  /// 現在時刻の取得元。テスト時のみ差し替える(日付境界の単体テスト用、
  /// Build 13)。通常は既定値の `DateTime.now`(端末ローカルタイム)のまま。
  DateTime Function() nowProvider = DateTime.now;

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

  /// [dt] の暦日を 'YYYY-MM-DD' へ変換する(端末ローカルタイム基準)。
  /// [dt] がUTCの場合は呼び出し側で `.toLocal()` してから渡すこと。
  String localDateString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// [lastLearnedDate](ローカル暦日の'YYYY-MM-DD'、未記録ならnull)を
  /// 現在時刻と比較し、'today' | 'continuing'(昨日) | 'broken'(一昨日
  /// 以前、または記録無し)のいずれかを返す(案A、2026-07-27決定)。
  String evaluateGap(String? lastLearnedDate) {
    final today = localDateString(nowProvider());
    if (lastLearnedDate == today) return 'today';
    final yesterday =
        localDateString(nowProvider().subtract(const Duration(days: 1)));
    if (lastLearnedDate == yesterday) return 'continuing';
    return 'broken';
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
  ///
  /// 案A(2026-07-27決定): 前回学習日が昨日なら継続(+1)、一昨日以前
  /// (または記録無し)ならリセットして1(当日分としてカウント)。
  Future<int> incrementStreak(String userId, String sceneId) async {
    try {
      final key = 'streak_${userId}_${sceneId}_days';
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';

      final lastUpdate = _prefs.getString(lastUpdateKey);
      final gap = evaluateGap(lastUpdate);

      if (gap == 'today') {
        // 今日は既にインクリメント済み(1日1回制限)
        return _prefs.getInt(key) ?? 0;
      }

      final currentStreak = _prefs.getInt(key) ?? 0;
      final newStreak = gap == 'continuing' ? currentStreak + 1 : 1;

      final today = localDateString(nowProvider());
      // last_updatedは複数端末間の新旧比較に使う絶対時刻のため、
      // 引き続きUTCで記録する(日付境界のローカル化とは別概念)。
      final nowInstant = nowProvider().toUtc();

      // ローカル更新
      await _prefs.setInt(key, newStreak);
      await _prefs.setString(lastUpdateKey, today);
      await _prefs.setString(updatedAtKey, nowInstant.toIso8601String());

      // Supabase へ更新（背景）。ローカルと同じ時刻を使う。
      _updateStreakInSupabase(userId, sceneId, newStreak, nowInstant).ignore();

      logger.info(
          '[StreakService] Streak updated ($gap): $newStreak days for $sceneId');
      return newStreak;
    } catch (e) {
      logger.info('[StreakService] Error incrementing streak: $e');
      return 0;
    }
  }

  /// ストリークを明示的に0へ全リセットする。
  ///
  /// incrementStreak()内蔵のギャップ検知リセット(→1)とは別物。
  /// 現時点でこのメソッドの呼び出し箇所は無いが、将来の明示的リセット
  /// 機能(設定画面での手動リセット、退会時のクリーンアップ等)のための
  /// 公開APIとして残している。
  Future<void> resetStreak(String userId, String sceneId) async {
    try {
      final key = 'streak_${userId}_${sceneId}_days';
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';
      final now = nowProvider().toUtc();

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

  /// 全シーンの中で「現在も継続している(brokenでない)」ストリークの
  /// 最大値を返す(統計画面の「連続学習日数」用、2026-08-01)。
  ///
  /// 単純に streak_days の最大値を取ると、resetStreak() が未使用で
  /// 明示的なリセット処理が無いため、放置されたシーンの古い streak_days
  /// が混ざってしまう(例: シーンAを2週間放置していても、DB上の
  /// streak_daysは最後に更新された時の値のまま)。last_updated を
  /// evaluateGap() で判定し、今日または継続中のものだけに絞り込んでから
  /// 最大値を取る。取得失敗時・該当なしは 0 を返す。
  Future<int> getOverallCurrentStreak(String userId) async {
    try {
      final response = await _supabase
          .from('user_streaks')
          .select('streak_days, last_updated')
          .eq('user_id', userId);

      var maxStreak = 0;
      for (final row in (response as List)) {
        final streakDays = (row['streak_days'] as int?) ?? 0;
        final updatedAtRaw = row['last_updated'] as String?;
        final updatedAt =
            updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;
        if (streakDays <= 0 || updatedAt == null) continue;

        final lastLearnedDate = localDateString(updatedAt.toLocal());
        if (evaluateGap(lastLearnedDate) == 'broken') continue;

        if (streakDays > maxStreak) maxStreak = streakDays;
      }
      return maxStreak;
    } catch (e) {
      logger.info('[StreakService] Error getting overall current streak: $e');
      return 0;
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
  /// 値を採用してローカルへ書き戻す。
  ///
  /// 2026-07-27(Build 13)より、単純に値を採用するのではなく、
  /// incrementStreak()と同じギャップ判定を適用する。復元直後の初回表示
  /// から正確な値にするため(例: 42日間放置していた場合、復元直後に
  /// 「42」と表示され、次の会話送信で「1」に落ちる、というユーザー体験
  /// 上のバグを避ける)。PR #13の複数端末間タイムスタンプ比較方式
  /// (`_syncStreakFromSupabaseIfNewer`)自体は変更しない別レイヤーの対応。
  Future<int> _restoreStreakFromSupabase(String userId, String sceneId) async {
    try {
      final response = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .maybeSingle();

      final remoteStreak = (response?['streak_days'] as int?) ?? 0;
      final remoteUpdatedAtRaw = response?['last_updated'] as String?;
      final remoteUpdatedAt =
          remoteUpdatedAtRaw != null ? DateTime.tryParse(remoteUpdatedAtRaw) : null;

      final key = 'streak_${userId}_${sceneId}_days';
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';
      final updatedAtKey = 'streak_${userId}_${sceneId}_updated_at';

      var effectiveStreak = remoteStreak;
      String? lastLearnedDate;

      if (remoteUpdatedAt != null && remoteStreak > 0) {
        // remote の last_updated(UTC)を端末ローカル暦日へ変換して判定。
        lastLearnedDate = localDateString(remoteUpdatedAt.toLocal());
        if (evaluateGap(lastLearnedDate) == 'broken') {
          // 復元時点で既に途切れている → 0扱い(今日はまだ未学習のため)。
          // 1になるのは実際にincrementStreak()が呼ばれた瞬間。
          effectiveStreak = 0;
        }
      } else {
        effectiveStreak = 0;
      }

      await _prefs.setInt(key, effectiveStreak);
      if (remoteUpdatedAtRaw != null) {
        await _prefs.setString(updatedAtKey, remoteUpdatedAtRaw);
      }
      // 次回incrementStreak()が正しくギャップ判定できるよう、実際の
      // 最終学習日(ローカル暦日)を書き戻す。ストリークが元々0/記録無し
      // の場合はlastLearnedDateもnullのままでよい(記録無し扱い)。
      if (lastLearnedDate != null) {
        await _prefs.setString(lastUpdateKey, lastLearnedDate);
      }

      logger.info(
          '[StreakService] Streak restored from Supabase: $effectiveStreak days for $sceneId (raw remote value: $remoteStreak)');
      return effectiveStreak;
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
      final lastUpdateKey = 'streak_${userId}_${sceneId}_last_update';
      await _prefs.setInt(key, remoteStreak);
      await _prefs.setString(updatedAtKey, remoteUpdatedAtRaw!);
      // last_updatedをローカル暦日に変換し、次回incrementStreak()の
      // ギャップ判定にも反映させる(復元パスと同じ理由)。
      await _prefs.setString(
          lastUpdateKey, localDateString(remoteUpdatedAt.toLocal()));
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
