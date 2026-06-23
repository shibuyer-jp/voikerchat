import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:voikerchat/models/onboarding_analytics.dart';

/// OnboardingService: オンボーディングフロー進捗管理
class OnboardingService {
  static const String _keyCurrentStep = 'onboarding_current_step';
  static const String _keyCompletedSteps = 'onboarding_completed_steps';
  static const String _keyStartTime = 'onboarding_start_time';
  static const String _keySkipCount = 'onboarding_skip_count';
  static const String _keyHintUsage = 'onboarding_hint_usage';
  static const String _keyFirstLaunch = 'is_first_launch';

  late SharedPreferences _prefs;

  OnboardingService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 初回起動判定
  Future<bool> isFirstLaunch() async {
    await _ensureInitialized();
    return _prefs.getBool(_keyFirstLaunch) ?? true;
  }

  /// 初回起動フラグをリセット
  Future<void> completeFirstLaunch() async {
    await _ensureInitialized();
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  /// 現在のステップを取得
  Future<int> getCurrentStep() async {
    await _ensureInitialized();
    return _prefs.getInt(_keyCurrentStep) ?? 0;
  }

  /// ステップを更新（進行）
  Future<void> updateStep(int step) async {
    await _ensureInitialized();
    await _prefs.setInt(_keyCurrentStep, step);
    _markStepCompleted(step);
  }

  /// ステップ完了をマーク
  void _markStepCompleted(int step) {
    final completed = _getCompletedSteps();
    if (!completed.contains(step)) {
      completed.add(step);
      _prefs.setStringList(
        _keyCompletedSteps,
        completed.map((s) => s.toString()).toList(),
      );
    }
  }

  /// 完了済みステップ一覧を取得
  Future<List<int>> getCompletedSteps() async {
    await _ensureInitialized();
    return _getCompletedSteps();
  }

  List<int> _getCompletedSteps() {
    final steps = _prefs.getStringList(_keyCompletedSteps) ?? [];
    return steps.map((s) => int.tryParse(s) ?? 0).toList();
  }

  /// スキップ回数を記録
  Future<void> recordSkip() async {
    await _ensureInitialized();
    final skipCount = _prefs.getInt(_keySkipCount) ?? 0;
    await _prefs.setInt(_keySkipCount, skipCount + 1);
  }

  /// ヒント使用回数を記録
  Future<void> recordHintUsage() async {
    await _ensureInitialized();
    final hintCount = _prefs.getInt(_keyHintUsage) ?? 0;
    await _prefs.setInt(_keyHintUsage, hintCount + 1);
  }

  /// オンボーディング統計を取得
  Future<OnboardingAnalytics> getAnalytics({
    required String userId,
  }) async {
    await _ensureInitialized();

    final currentStep = await getCurrentStep();
    final startTimeMs = _prefs.getInt(_keyStartTime) ?? DateTime.now().millisecondsSinceEpoch;
    final timeSpent =
        (DateTime.now().millisecondsSinceEpoch - startTimeMs) ~/ 1000;
    final skipCount = _prefs.getInt(_keySkipCount) ?? 0;
    final hintUsage = _prefs.getInt(_keyHintUsage) ?? 0;

    return OnboardingAnalytics(
      id: const Uuid().v4(),
      userId: userId,
      stepCompleted: currentStep,
      timeSpentSeconds: timeSpent,
      skipCount: skipCount,
      hintUsage: hintUsage,
      createdAt: DateTime.now(),
      completedAt: currentStep >= 5 ? DateTime.now() : null,
    );
  }

  /// オンボーディング進捗をリセット（デバッグ用）
  Future<void> resetOnboarding() async {
    await _ensureInitialized();
    await _prefs.remove(_keyCurrentStep);
    await _prefs.remove(_keyCompletedSteps);
    await _prefs.remove(_keyStartTime);
    await _prefs.remove(_keySkipCount);
    await _prefs.remove(_keyHintUsage);
  }

  Future<void> _ensureInitialized() async {
    if (!_prefs.containsKey('initialized')) {
      await _prefs.setBool('initialized', true);
    }
  }
}
