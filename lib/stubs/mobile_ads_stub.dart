// google_mobile_ads は Web 非対応のため、Web ビルドでは条件付き import で
// このスタブを使用し、SDK 初期化呼び出しを no-op にする。
// （firebase_messaging_stub.dart と同じ方針）

/// Web 用 MobileAds スタブ。`MobileAds.instance.initialize()` を no-op にする。
class MobileAds {
  MobileAds._();

  static final MobileAds instance = MobileAds._();

  Future<void> initialize() async {
    // Web では広告 SDK を初期化しない。
  }
}
