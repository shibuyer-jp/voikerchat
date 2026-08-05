import 'package:shared_preferences/shared_preferences.dart';

import '../models/diagnostic.dart';

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

  // ---- オンボーディングスライド(施策③) ----

  static const String _onboardingSlidesCompletedKey =
      'onboarding_slides_completed';

  /// スライド(診断テスト前の説明3枚)を最後まで見た、またはスキップしたか。
  /// 一度完了したら再表示しないためのフラグ。
  Future<bool> isOnboardingSlidesCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSlidesCompletedKey) ?? false;
  }

  Future<void> setOnboardingSlidesCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSlidesCompletedKey, completed);
  }

  // ---- 診断テストの任意化(施策③) ----

  /// main.dart の _resolveInitialScreen が書き込む値と同一キー。
  /// user_diagnostic_level はテスト未受験でも(「あとで」選択時)
  /// beginner が保存されるため、このキーだけでは「実際に受験したか」を
  /// 判別できない。judgeには diagnosticTestCompleted を併用する。
  static const String _userDiagnosticLevelKey = 'user_diagnostic_level';

  static const String _diagnosticTestCompletedKey =
      'diagnostic_test_completed';

  /// 診断テストを実際に受験して完了したか(「あとで」でデフォルト適用された
  /// 場合はfalseのまま)。シーン選択画面のレベルテストカード表示条件に使う。
  Future<bool> isDiagnosticTestCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_diagnosticTestCompletedKey) ?? false;
  }

  Future<void> setDiagnosticTestCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diagnosticTestCompletedKey, completed);
  }

  /// 現在保存されているユーザー診断レベル(未保存/不正値は beginner)。
  Future<UserDiagnosticLevel> getUserDiagnosticLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_userDiagnosticLevelKey);
    return UserDiagnosticLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => UserDiagnosticLevel.beginner,
    );
  }

  /// 診断テスト(再受験含む)完了時にレベルを更新する。
  Future<void> setUserDiagnosticLevel(UserDiagnosticLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDiagnosticLevelKey, level.name);
  }

  // ---- レベルテストカード(施策③、シーン選択画面) ----

  static const String _levelTestCardDismissedDateKey =
      'level_test_card_dismissed_date';

  /// カードの「あとで」を今日押したか(端末ローカル日付で判定。
  /// streak_service.dart と同じくローカルタイム基準、DECISIONS.md
  /// 2026-07-27の方針に合わせる)。
  Future<bool> isLevelTestCardDismissedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_levelTestCardDismissedDateKey);
    if (dateStr == null) return false;
    final dismissedDate = DateTime.tryParse(dateStr);
    if (dismissedDate == null) return false;
    final now = DateTime.now();
    return dismissedDate.year == now.year &&
        dismissedDate.month == now.month &&
        dismissedDate.day == now.day;
  }

  Future<void> dismissLevelTestCardForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _levelTestCardDismissedDateKey,
      DateTime.now().toIso8601String(),
    );
  }
}
