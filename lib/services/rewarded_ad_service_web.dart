/// リワード広告サービスの Web 用 no-op 実装。
///
/// Web では google_mobile_ads が動作しないため、広告は提供しない。
/// [isSupported] が false なので UI 側は広告ボタンを出さない。
class RewardedAdService {
  /// Web は広告非対応。
  bool get isSupported => false;

  bool get isReady => false;

  Future<void> loadAd() async {
    // no-op
  }

  Future<bool> showAd() async => false;

  void dispose() {
    // no-op
  }
}
