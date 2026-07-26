/// レート制限まわりの定数。
///
/// サーバー側の唯一の定義元は api/_constants.ts。ここはクライアント側の
/// フォールバック用(通信失敗時など)であり、サーバー応答があれば常に
/// サーバー側の値が優先される。値を変更する場合は api/_constants.ts と
/// 揃えること。
class RateLimitConstants {
  RateLimitConstants._();

  static const int freeDailyLimit = 5;
  static const int premiumDailyLimit = 50;
  static const int adBonus = 5;
  static const int freeDailyCap = 10;
}
