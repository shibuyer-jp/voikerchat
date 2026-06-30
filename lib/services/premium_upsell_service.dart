import 'package:shared_preferences/shared_preferences.dart';

/// PremiumUpsellStage: Premium勧導ステージ
enum PremiumUpsellStage {
  stage1, // Day 1: Toast notification
  stage2, // Day 3: Dialog
  stage3, // Day 7: Banner
}

/// PremiumUpsellService: Premium勧導タイミング管理
///
/// 3段階の段階的提案を制御:
/// - Stage 1 (Day 1): 軽いトースト通知
/// - Stage 2 (Day 3): ダイアログ
/// - Stage 3 (Day 7): バナー
class PremiumUpsellService {
  static const String _keyFirstSessionTime = 'premium_upsell_first_session';
  static const String _keyContinuousDays = 'premium_upsell_continuous_days';
  static const String _keyLastResetDate = 'premium_upsell_last_reset_date';
  static const String _keyStage1Shown = 'premium_upsell_stage1_shown';
  static const String _keyStage2Shown = 'premium_upsell_stage2_shown';
  static const String _keyStage3Shown = 'premium_upsell_stage3_shown';
  static const String _keyConversationCount = 'premium_conversation_count';
  static const String _keyLastConversationDate = 'premium_last_conversation_date';

  // late ではなく nullable にして、利用前に確実に初期化する
  // （旧実装は _initialize() を await せず、初期化前アクセスで
  //  LateInitializationError を起こしうるバグがあった）。
  SharedPreferences? _prefs;

  /// 初回セッション時刻を記録
  Future<void> recordFirstSession() async {
    await _ensureInitialized();
    if (!_prefs!.containsKey(_keyFirstSessionTime)) {
      await _prefs!.setInt(
        _keyFirstSessionTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// 連続使用日数を更新（毎日チェック）
  Future<int> updateContinuousDays() async {
    await _ensureInitialized();

    final today = DateTime.now();
    final lastResetStr = _prefs!.getString(_keyLastResetDate);
    final lastReset = lastResetStr != null ? DateTime.parse(lastResetStr) : null;

    // 前回リセット日が今日でなければカウントを増やす
    if (lastReset == null || !_isSameDay(lastReset, today)) {
      final currentDays = _prefs!.getInt(_keyContinuousDays) ?? 0;
      await _prefs!.setInt(_keyContinuousDays, currentDays + 1);
      await _prefs!.setString(_keyLastResetDate, today.toIso8601String());
    }

    return _prefs!.getInt(_keyContinuousDays) ?? 0;
  }

  /// 会話数を記録
  Future<void> recordConversation() async {
    await _ensureInitialized();

    final count = _prefs!.getInt(_keyConversationCount) ?? 0;
    await _prefs!.setInt(_keyConversationCount, count + 1);
    await _prefs!.setString(
      _keyLastConversationDate,
      DateTime.now().toIso8601String(),
    );
  }

  /// 今日の会話数を取得
  Future<int> getTodayConversationCount() async {
    await _ensureInitialized();

    final lastDateStr = _prefs!.getString(_keyLastConversationDate);
    if (lastDateStr == null) return 0;

    final lastDate = DateTime.parse(lastDateStr);
    if (_isSameDay(lastDate, DateTime.now())) {
      return _prefs!.getInt(_keyConversationCount) ?? 0;
    }

    // 日付が変わった場合はカウントをリセット
    await _prefs!.setInt(_keyConversationCount, 0);
    return 0;
  }

  /// 表示すべきUpsellステージを取得
  Future<PremiumUpsellStage?> getNextUpsellStage() async {
    await _ensureInitialized();

    final continuousDays = await updateContinuousDays();
    final conversationCount = await getTodayConversationCount();

    // Stage 1: Day 1, 5回以上会話（Free制限に近づいた場合）
    if (continuousDays >= 1 &&
        conversationCount >= 5 &&
        !(_prefs!.getBool(_keyStage1Shown) ?? false)) {
      return PremiumUpsellStage.stage1;
    }

    // Stage 2: Day 3, 連続使用
    if (continuousDays >= 3 && !(_prefs!.getBool(_keyStage2Shown) ?? false)) {
      return PremiumUpsellStage.stage2;
    }

    // Stage 3: Day 7, 連続使用
    if (continuousDays >= 7 && !(_prefs!.getBool(_keyStage3Shown) ?? false)) {
      return PremiumUpsellStage.stage3;
    }

    return null;
  }

  /// ステージを表示済みにマーク
  Future<void> markStageAsShown(PremiumUpsellStage stage) async {
    await _ensureInitialized();

    switch (stage) {
      case PremiumUpsellStage.stage1:
        await _prefs!.setBool(_keyStage1Shown, true);
        break;
      case PremiumUpsellStage.stage2:
        await _prefs!.setBool(_keyStage2Shown, true);
        break;
      case PremiumUpsellStage.stage3:
        await _prefs!.setBool(_keyStage3Shown, true);
        break;
    }
  }

  /// ステージメッセージを取得
  static String getStageMessage(PremiumUpsellStage stage) {
    switch (stage) {
      case PremiumUpsellStage.stage1:
        return '毎日たくさん使うなら Premium がお得です';
      case PremiumUpsellStage.stage2:
        return 'Premium なら無制限に学習できます';
      case PremiumUpsellStage.stage3:
        return '7日連続達成！Premium でアニメシーンも解放';
    }
  }

  /// ステージボタンテキストを取得
  static String getStageButtonText(PremiumUpsellStage stage) {
    switch (stage) {
      case PremiumUpsellStage.stage1:
        return '詳細';
      case PremiumUpsellStage.stage2:
        return '登録（\$12.99/月）';
      case PremiumUpsellStage.stage3:
        return 'いますぐ登録';
    }
  }

  /// 開発用: リセット
  Future<void> resetForDebug() async {
    await _ensureInitialized();
    await _prefs!.remove(_keyFirstSessionTime);
    await _prefs!.remove(_keyContinuousDays);
    await _prefs!.remove(_keyLastResetDate);
    await _prefs!.remove(_keyStage1Shown);
    await _prefs!.remove(_keyStage2Shown);
    await _prefs!.remove(_keyStage3Shown);
    await _prefs!.remove(_keyConversationCount);
    await _prefs!.remove(_keyLastConversationDate);
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
}
