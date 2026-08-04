# T-33: プレミアム購入フロー(ペイウォール)実装 — 「近日実装」の廃止

## 現状(事実)
- `revenuecat_service.dart` に entitlement 判定(`Premium` / `voikerchat_premium`)と SharedPreferences キャッシュは実装済み。
- しかし**購入画面が存在せず**、ロック中プレミアムシーンをタップすると `scene_selection_screen.dart` の `_showLockedMessage` が SnackBar「プレミアム機能(近日実装)」(`premiumComingSoon`)を出すだけ。
- Paid Applications Agreement は承認済み(2026-07-13)。ストア側の製品(Premium $12.99/月)設定の最終確認が必要。

## 結論
**リリース前に実装可能。** 残りはUI+購入/復元呼び出しのみで、SDK基盤は完成している。

## 実装手順
1. `lib/screens/paywall_screen.dart` 新設:
   - RevenueCat `getOfferings()` から現地価格を動的表示(価格のハードコード禁止。$12.99 は定数としてフォールバック表示のみ)
   - 訴求内容: 50会話/日・全シーン解放(専門シーン含む)・広告なし・高品質音声(T-35)・学習統計
   - 「購入する」「購入を復元」ボタン、利用規約/プライバシーポリシーへのリンク(App Store 審査要件)
2. `revenuecat_service.dart` に `purchasePremium()` / `restorePurchases()` を追加(既存の entitlement 判定を再利用、エラーは internal-docs/Premium-Purchase-Error-Handling.md に準拠)。
3. `_showLockedMessage` を廃止し、ロック中シーンタップ → PaywallScreen へ遷移。既存の `premium_upsell_widgets.dart` / `premium_upsell_service.dart` の導線(quota到達時アップセル等)も PaywallScreen へ接続。
4. ARB 3言語(ja/en/fil): `premiumComingSoon` を削除し、ペイウォール文言一式を追加。ホーム下部の「プレミアム機能(近日実装)」バナーも購入導線に差し替え。
5. 購入成功時: entitlement 再取得 → シーン解放・広告非表示・上限50/日が即時反映されることを確認。`usage_logs` に `upsell_converted` を記録(既存 event type)。

## 人間の作業
- App Store Connect / Play Console でサブスク製品(Premium $12.99/月)の登録状態・価格・ローカライズを確認
- **Sandbox / ライセンステスターでの実機購入・復元テスト**(iOS: Sandboxアカウント、Android: ライセンステスト)
- iOS 審査時、IAP をアプリバージョンと同時に提出すること(未提出だと審査で弾かれる)

## 受け入れ基準
- ロックシーンタップ → ペイウォール → Sandbox購入 → シーン解放、の一連が実機で通る
- 復元が機能する(再インストール後)
- 「近日実装」文言がアプリ内から完全に消えている
- `flutter analyze` / `flutter test` 緑
