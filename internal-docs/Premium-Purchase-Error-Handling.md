# Premium Purchase Error Handling Guide

## Overview
Voikerchat のサブスクリプション購買フロー全体のエラーハンドリング仕様

---

## エラー分類

### 1. User-Initiated Errors（ユーザーキャンセル）
**Code:** `cancelled`
- **原因:** ユーザーが購入をキャンセル
- **表示:** なし（ダイアログを閉じるのみ）
- **リトライ:** 不可
- **ユーザーアクション:** なし

### 2. Network Errors（ネットワークエラー）
**Code:** `network`
- **原因:** インターネット接続がない、遅い、切れた
- **表示:** "Network error. Please check your internet connection."
- **リトライ:** 可能 ✅
- **ユーザーアクション:** WiFi/モバイル接続を確認 → リトライ

### 3. Payment Method Errors（支払い方法エラー）
**Code:** `invalid_credentials`
- **原因:** クレジットカード有効期限切れ、拒否、不正
- **表示:** "Invalid payment method. Please update your payment info in App Store/Play Store."
- **リトライ:** 不可
- **ユーザーアクション:** App Store/Play Store で支払い方法を更新

### 4. Payment Pending（支払い処理中）
**Code:** `payment_pending`
- **原因:** 支払い処理がまだ完了していない（遅延）
- **表示:** "Payment is pending. Please check your payment method and try again."
- **リトライ:** 可能 ✅（少し待ってから）
- **ユーザーアクション:** しばらく待ってリトライ

### 5. Offering Not Found（プロダクト未設定）
**Code:** `offering_not_found`
- **原因:** RevenueCat にプロダクトが登録されていない
- **表示:** "Offerings not available. Please check your internet connection."
- **リトライ:** 可能 ✅
- **ユーザーアクション:** 接続を確認 → アプリを再起動

### 6. Geographic Restriction（地域制限）
**Code:** `not_available`
- **原因:** その国では購入できない（国による規制）
- **表示:** "Product not available for purchase in your region."
- **リトライ:** 不可
- **ユーザーアクション:** なし（技術的に解決不可）

### 7. Entitlement Not Granted（エンタイトルメント未反映）
**Code:** `entitlement_not_granted`
- **原因:** 購入完了したが、権限がまだ有効化されていない
- **表示:** "Purchase completed but subscription not activated. Please try again."
- **リトライ:** 可能 ✅
- **ユーザーアクション:** リトライ、または アプリを再起動

### 8. Unknown Error（未知のエラー）
**Code:** `unknown_error` or `unexpected_error`
- **原因:** 予期しないエラー
- **表示:** `error.message` をそのまま表示
- **リトライ:** 可能 ✅（通常）
- **ユーザーアクション:** リトライ → ダメなら サポートに連絡

---

## UI フロー

### 成功フロー
```
[Pro ボタン] 
  ↓ 
[Premium ダイアログ表示] 
  ↓ 
[Subscribe Now クリック] 
  ↓ 
[処理中ダイアログ] 
  ↓ 
✨ Welcome to Premium! (成功メッセージ)
```

### リトライ可能エラーフロー
```
[Pro ボタン] 
  ↓ 
[Premium ダイアログ表示] 
  ↓ 
[Subscribe Now クリック] 
  ↓ 
[処理中ダイアログ] 
  ↓ 
⚠️ [エラーダイアログ] 
   - メッセージ表示
   - [Retry] ボタン
   - [Cancel] ボタン
  ↓ 
[Retry クリック] → 再度購入フロー
```

### リトライ不可エラーフロー
```
[Pro ボタン] 
  ↓ 
[Premium ダイアログ表示] 
  ↓ 
[Subscribe Now クリック] 
  ↓ 
[処理中ダイアログ] 
  ↓ 
❌ [エラーダイアログ] 
   - エラーメッセージ表示
   - [Close] ボタン
  ↓ 
[Close クリック] → ダイアログ閉じる
```

---

## RevenueCatService Response Format

```dart
{
  'success': bool,                    // 購入成功フラグ
  'message': String,                  // ユーザーに表示するメッセージ
  'error': String?,                   // エラーコード
  'retryable': bool?,                 // リトライ可能か
  'userInitiated': bool?,             // ユーザーキャンセルか
}
```

### 成功例
```dart
{
  'success': true,
  'message': 'Welcome to Voikerchat Premium!',
}
```

### リトライ可能エラー例
```dart
{
  'success': false,
  'error': 'network',
  'message': 'Network error. Please check your internet connection.',
  'retryable': true,
}
```

### リトライ不可エラー例
```dart
{
  'success': false,
  'error': 'invalid_credentials',
  'message': 'Invalid payment method. Please update your payment info in App Store/Play Store.',
  'retryable': false,
}
```

---

## トラブルシューティング

### 「Payment Pending」が続く場合
- App Store/Google Play で支払い履歴を確認
- 重複請求されていないか確認
- 数分待ってアプリを再起動

### 「Offering Not Found」が出る場合
- インターネット接続を確認
- App Store/Google Play のアプリを再起動
- Voikerchat を再起動

### 「Not Available in Your Region」が出る場合
- その国では iPhone アプリの購入が制限されている可能性
- VPN を使用しての購入は AppStore 利用規約違反
- サポートに連絡

### 購入後も Premium にならない場合
- アプリを完全に再起動（終了 → 再起動）
- 数分待ってから確認
- サポートに連絡

---

## 開発者向け

### テスト環境での動作確認
1. **成功:** RevenueCat TestFlight で test_success パッケージ
2. **キャンセル:** User が購入画面で キャンセル
3. **ネットワークエラー:**機内モード ON → リトライ可能確認
4. **無効なカード:** App Store TestFlight 環境で無効カード

### ログ確認
```
[RevenueCat] Purchase error: ...
[RevenueCat] Premium purchased successfully
[RevenueCat] Premium status checked: true/false
```

---

## Webhook Integration（将来）

Premium 購入後の自動更新：
1. RevenueCat → Firebase Cloud Function
2. Supabase `rate_limits.is_premium = true` を更新
3. ユーザーの unlimited calls を有効化
