// リワード（報酬型）広告サービスの facade。
// プラットフォーム別に実装を切り替える（既存の stub 方式と同じ方針）:
//   - モバイル: google_mobile_ads を使う実装 (_io)
//   - Web:      広告 SDK が無いため no-op 実装 (_web)
// 利用側は本ファイルだけを import すればよい。
export 'rewarded_ad_service_io.dart'
    if (dart.library.html) 'rewarded_ad_service_web.dart';
