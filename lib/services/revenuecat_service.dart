import 'package:logging/logging.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

/// RevenueCat サービス - IAP (In-App Purchase) 統合
/// 
/// iOS/Android の App Store / Google Play との連携
/// Premium サブスクリプション管理
class RevenueCatService {
  final logger = Logger('RevenueCatService');

  static final RevenueCatService _instance = RevenueCatService._internal();
  
  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _isPremium = false;

  // RevenueCat API キー（テスト）
  static const String _apiKey = 'test_bvqgeBBNoUiKVbBHI0aPMOnwg7Cw';

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
      await Purchases.setLogLevel(LogLevel.debug);
      
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
      logger.info('[RevenueCat] Initialized successfully');
    } catch (e) {
      logger.info('[RevenueCat] Initialization error: $e');
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
      
      logger.info('[RevenueCat] Premium status checked: $_isPremium');
      return _isPremium;
    } catch (e) {
      logger.info('[RevenueCat] Error checking premium status: $e');
      return _isPremium;
    }
  }

  /// Premium 購入フロー
  /// エラー分類: cancelled, network, payment, unknown
  Future<Map<String, dynamic>> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        return {
          'success': false,
          'error': 'offering_not_found',
          'message': 'Offerings not available. Please check your internet connection.',
        };
      }

      final offering = offerings.current!;
      
      // Monthly package を探す
      Package? monthlyPackage;
      for (var pkg in offering.availablePackages) {
        if (pkg.identifier.contains('monthly')) {
          monthlyPackage = pkg;
          break;
        }
      }

      if (monthlyPackage == null) {
        return {
          'success': false,
          'error': 'package_not_found',
          'message': 'Monthly subscription package not found.',
        };
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
          logger.info('[RevenueCat] Premium purchased successfully');
          return {
            'success': true,
            'message': 'Welcome to Voikerchat Premium!',
          };
        } else {
          // 購入完了したが、エンタイトルメント未反映
          return {
            'success': false,
            'error': 'entitlement_not_granted',
            'message': 'Purchase completed but subscription not activated. Please try again.',
          };
        }
      } catch (e) {
        // エラーハンドリング（汎用）
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('cancel')) {
          return {
            'success': false,
            'error': 'cancelled',
            'message': 'Purchase cancelled.',
            'userInitiated': true,
          };
        } else if (errorString.contains('network')) {
          return {
            'success': false,
            'error': 'network',
            'message': 'Network error. Please check your internet connection.',
            'retryable': true,
          };
        } else if (errorString.contains('pending')) {
          return {
            'success': false,
            'error': 'payment_pending',
            'message': 'Payment is pending. Please check your payment method and try again.',
            'retryable': true,
          };
        } else if (errorString.contains('credential') || errorString.contains('invalid')) {
          return {
            'success': false,
            'error': 'invalid_credentials',
            'message': 'Invalid payment method. Please update your payment info in App Store/Play Store.',
            'retryable': false,
          };
        } else if (errorString.contains('not available') || errorString.contains('region')) {
          return {
            'success': false,
            'error': 'not_available',
            'message': 'Product not available for purchase in your region.',
            'retryable': false,
          };
        } else {
          return {
            'success': false,
            'error': 'unknown_error',
            'message': 'Purchase failed: $e',
            'retryable': true,
          };
        }
      }
    } catch (e) {
      // 予期しないエラー
      return {
        'success': false,
        'error': 'unexpected_error',
        'message': 'Unexpected error: $e',
        'retryable': true,
      };
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
      logger.info('[RevenueCat] Error getting premium info: $e');
      return null;
    }
  }

  /// Premium 復元（別のデバイスから購入した場合）
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') ||
                   entitlements.active.containsKey('voikerchat_premium');
      
      await _prefs.setBool('isPremium', _isPremium);
      
      logger.info('[RevenueCat] Purchases restored: $_isPremium');
      return _isPremium;
    } catch (e) {
      logger.info('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  /// Premium キャンセル（ローカル状態のリセット）
  Future<void> resetPremiumStatus() async {
    _isPremium = false;
    await _prefs.setBool('isPremium', false);
    logger.info('[RevenueCat] Premium status reset');
  }
}
