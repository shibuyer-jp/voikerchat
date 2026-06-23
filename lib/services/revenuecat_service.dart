import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

/// RevenueCat サービス - IAP (In-App Purchase) 統合
/// 
/// iOS/Android の App Store / Google Play との連携
/// Premium サブスクリプション管理
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  
  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _isPremium = false;

  // RevenueCat API キー（テスト）
  static const String _apiKey = 'test_bvqgeBBNoUiKVbBHI0aPMOnwg7Cw';
  
  // Product IDs
  static const String _iosProductId = 'voikerchat.premium.monthly';
  static const String _androidProductId = 'voikerchat_premium_monthly';

  RevenueCatService._internal();

  factory RevenueCatService() {
    return _instance;
  }

  /// 初期化（アプリ起動時に呼び出し）
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      
      // RevenueCat SDK 初期化
      await Purchases.setDebugLogsEnabled(true);
      
      if (Platform.isIOS) {
        await Purchases.configure(
          PurchasesConfiguration(_apiKey),
        );
      } else if (Platform.isAndroid) {
        await Purchases.configure(
          PurchasesConfiguration(_apiKey),
        );
      }

      // 既存の Premium ステータスをロード
      _isPremium = _prefs.getBool('isPremium') ?? false;
      
      _initialized = true;
      print('[RevenueCat] Initialized successfully');
    } catch (e) {
      print('[RevenueCat] Initialization error: $e');
      rethrow;
    }
  }

  /// Premium ステータス取得
  bool get isPremium => _isPremium;

  /// Premium ステータスを確認してローカル保存
  Future<bool> checkPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Premium エンタイトルメント確認
      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') || 
                   entitlements.active.containsKey('voikerchat_premium');
      
      // ローカル保存
      await _prefs.setBool('isPremium', _isPremium);
      
      print('[RevenueCat] Premium status checked: $_isPremium');
      return _isPremium;
    } catch (e) {
      print('[RevenueCat] Error checking premium status: $e');
      return _isPremium;
    }
  }

  /// Premium 購入フロー開始
  Future<bool> purchasePremium() async {
    try {
      // 利用可能なプロダクト取得
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }

      final offering = offerings.current!;
      
      // Monthly package を探す
      RevenueCatPackage? monthlyPackage;
      for (var pkg in offering.availablePackages) {
        if (pkg.identifier.contains('monthly')) {
          monthlyPackage = pkg;
          break;
        }
      }

      if (monthlyPackage == null) {
        throw Exception('Monthly package not found');
      }

      // 購入処理
      try {
        final customerInfo = await Purchases.purchasePackage(monthlyPackage);
        
        // 購入成功 → Premium ステータス更新
        final entitlements = customerInfo.entitlements;
        _isPremium = entitlements.active.containsKey('Premium') ||
                     entitlements.active.containsKey('voikerchat_premium');
        
        if (_isPremium) {
          await _prefs.setBool('isPremium', true);
          print('[RevenueCat] Premium purchased successfully');
          return true;
        }
      } on PurchasesErrorCode catch (e) {
        if (e.error.code == PurchasesErrorCode.purchaseCancelledError) {
          print('[RevenueCat] Purchase cancelled by user');
        } else {
          print('[RevenueCat] Purchase error: ${e.error.message}');
        }
        return false;
      }
      
      return false;
    } catch (e) {
      print('[RevenueCat] Purchase error: $e');
      rethrow;
    }
  }

  /// Premium サブスクリプション情報取得
  Future<Map<String, dynamic>?> getPremiumInfo() async {
    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        return null;
      }

      final offering = offerings.current!;
      
      for (var pkg in offering.availablePackages) {
        if (pkg.identifier.contains('monthly')) {
          return {
            'price': pkg.storeProduct.priceString,
            'identifier': pkg.identifier,
            'title': pkg.storeProduct.title,
            'description': pkg.storeProduct.description,
          };
        }
      }
      
      return null;
    } catch (e) {
      print('[RevenueCat] Error getting premium info: $e');
      return null;
    }
  }

  /// Premium 復元（別のデバイスから購入した場合）
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restoreTransactions();
      
      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') ||
                   entitlements.active.containsKey('voikerchat_premium');
      
      await _prefs.setBool('isPremium', _isPremium);
      
      print('[RevenueCat] Purchases restored: $_isPremium');
      return _isPremium;
    } catch (e) {
      print('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  /// Premium キャンセル（ローカル状態のリセット）
  Future<void> resetPremiumStatus() async {
    _isPremium = false;
    await _prefs.setBool('isPremium', false);
    print('[RevenueCat] Premium status reset');
  }
}
