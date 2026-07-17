import 'package:shared_preferences/shared_preferences.dart';

/// CloudTtsUnlockService: 「本日クラウドTTSが解放済みか」のローカル表示用フラグ(T-35)。
///
/// 実際の利用可否はサーバー(api/tts.ts)がusage_logs.ad_reward/Premiumで
/// 検証するため、ここはUI表示・無駄な通信回避のためのヒントに過ぎない。
/// 日付判定は rate_limits の日次リセットと同じくUTC日付基準で揃える。
class CloudTtsUnlockService {
  static const String _key = 'cloud_tts_unlocked_date';

  String get _todayUtc => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  Future<void> markUnlockedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _todayUtc);
  }

  Future<bool> isUnlockedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == _todayUtc;
  }
}
