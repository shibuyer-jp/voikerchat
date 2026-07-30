import 'package:flutter/foundation.dart';

/// AdMob の広告ユニット / アプリ ID を 1 箇所に集約する。
///
/// 本番リリース時は [useTestAds] を false にし、`_prod*` に AdMob 管理画面で
/// 発行した実 ID を設定するだけで本番広告に切り替わる（差し替えはここだけ）。
class AdConfig {
  /// true の間は Google 公式テスト広告を配信する（登録不要・課金リスクなし）。
  ///
  /// `--dart-define=USE_TEST_ADS=true` で Google 公式テスト広告に切替。
  /// デフォルト false = 本番。ストア提出ビルドでは絶対に true にしないこと。
  static const bool useTestAds =
      bool.fromEnvironment('USE_TEST_ADS', defaultValue: false);

  /// 非パーソナライズ広告のみ配信する（npa=1）。
  ///
  /// 初版は ATT/UMP 同意フロー未実装のためトラッキングなしで提出する方針（方針B）。
  /// App Store Connect のプライバシー申告「トラッキング: なし」と整合させること。
  /// v1.1 で ATT/UMP を実装したら false に変更し、申告も「あり」へ更新する
  /// （skills/ios-submission.md ② 参照）。
  static const bool nonPersonalizedOnly = true;

  // Google 公式テスト用リワード広告ユニット（そのまま使用可）。
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // 本番リワード広告ユニット。2026-07-30、AdMob管理画面で照合済み:
  // Android(ca-app-pub-1612072387421821/5678139568、広告ユニット名
  // rewarded_android)は一致。iOS(.../7701667676)はAdMobのiOSアプリ配下に
  // 別途あるため、Androidアプリの広告ユニット一覧には出ない(正常)。
  // useTestAds=true時のGoogle公式テストID(_testRewardedAndroid/Ios、
  // ca-app-pub-3940256099942544系)とは別枠。
  static const String _prodRewardedAndroid = 'ca-app-pub-1612072387421821/5678139568';
  static const String _prodRewardedIos = 'ca-app-pub-1612072387421821/7701667676';

  /// プラットフォーム別のリワード広告ユニット ID。
  static String get rewardedUnitId {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) {
      return useTestAds ? _testRewardedIos : _prodRewardedIos;
    }
    return useTestAds ? _testRewardedAndroid : _prodRewardedAndroid;
  }
}
