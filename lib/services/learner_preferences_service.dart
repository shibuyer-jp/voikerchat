import 'package:shared_preferences/shared_preferences.dart';

/// LearnerPreferencesService: 学習サポート系のローカル設定(T-36)。
class LearnerPreferencesService {
  static const String _furiganaKey = 'furigana_enabled';

  /// ふりがな表示。デフォルトON(初級ターゲットのため)。
  Future<bool> isFuriganaEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_furiganaKey) ?? true;
  }

  Future<void> setFuriganaEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_furiganaKey, enabled);
  }
}
