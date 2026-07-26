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

  // ---- 難易度フィードバック(競合分析B案: Duolingo Max方式) ----

  static const String _difficultyKey = 'difficulty_feedback';

  /// 直近の会話後フィードバック。'easy' | 'good' | 'hard' | null(未回答)。
  /// 'good' と null は「調整なし」としてサーバー側で同義に扱われる。
  Future<String?> getDifficultyFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_difficultyKey);
  }

  Future<void> setDifficultyFeedback(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, value);
  }

  // ---- 前回シーン(競合分析D案: 起動→会話開始を1タップに) ----

  static const String _lastSceneIdKey = 'last_scene_id';

  /// 最後に開いたシーンID("1"〜"18")。未記録なら null。
  Future<String?> getLastSceneId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSceneIdKey);
  }

  Future<void> setLastSceneId(String sceneId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSceneIdKey, sceneId);
  }

  // ---- 最近使ったシーン(シーン選択画面の「最近使ったシーン」セクション) ----

  static const String _recentSceneIdsKey = 'recent_scene_ids';
  static const int _recentSceneIdsMaxLength = 3;

  /// 最近開いたシーンID一覧(最新順、最大3件、重複なし)。履歴が無ければ空リスト。
  Future<List<String>> getRecentSceneIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSceneIdsKey) ?? [];
  }

  /// シーンを開いた際に呼び出し、履歴を最新順で更新する。
  /// 既に履歴にあるIDは一旦除いてから先頭に追加する(重複は最新側に統合)。
  Future<void> recordRecentSceneId(String sceneId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentSceneIdsKey) ?? [];
    final updated = [sceneId, ...current.where((id) => id != sceneId)]
        .take(_recentSceneIdsMaxLength)
        .toList();
    await prefs.setStringList(_recentSceneIdsKey, updated);
  }
}
