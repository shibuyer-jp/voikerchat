import 'package:flutter/foundation.dart';

/// AdMob の広告ユニット / アプリ ID を 1 箇所に集約する。
///
/// 本番リリース時は [useTestAds] を false にし、`_prod*` に AdMob 管理画面で
/// 発行した実 ID を設定するだけで本番広告に切り替わる（差し替えはここだけ）。
class AdConfig {
  /// true の間は Google 公式テスト広告を配信する（登録不要・課金リスクなし）。
  static const bool useTestAds = true;

  // Google 公式テスト用リワード広告ユニット（そのまま使用可）。
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // 本番リワード広告ユニット（AdMob 登録後に実 ID を設定）。
  static const String _prodRewardedAndroid = 'TODO_SET_ANDROID_REWARDED_ID';
  static const String _prodRewardedIos = 'TODO_SET_IOS_REWARDED_ID';

  /// プラットフォーム別のリワード広告ユニット ID。
  static String get rewardedUnitId {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) {
      return useTestAds ? _testRewardedIos : _prodRewardedIos;
    }
    return useTestAds ? _testRewardedAndroid : _prodRewardedAndroid;
  }
}
