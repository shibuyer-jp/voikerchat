# STATE.md — Voikerchat 現在状態(外部メモリ)

> **運用ルール**: セッション開始時に読む/終了時に更新してコミット。ここが唯一の正(single source of truth)。
> 最終更新: 2026-07-05(Fable: CLAUDE.mdから状態を分離・メモリと突合して更新)

## 機能ステータス
| 機能 | 状態 | 備考 |
|------|------|------|
| 認証(Supabase匿名認証) | ✅ 稼働 | プロジェクト `rfwbwwhqclabhnbsrygw`(Tokyo)。表示名は旧称"Japanese-learning-app"だが本番DB |
| チャット | ✅ 稼働 | `messages`/`conversation_sessions`/`user_streaks`/`rate_limits`(RLS有) |
| usage_logs | ✅ 稼働 | スキーマは commit `9877de6`。API層整合済(`2124bde`) |
| analytics/rate-limit認証統一 | ✅ 完了 | `supabase.auth.getUser` パターン(`2124bde`) |
| premium_upsell_service i18n | ✅ 完了 | commit `35553aa` |
| lefthook pre-push | ✅ 稼働 | analyze/test(`371b1ea`) |
| プッシュ通知 | 🚧 Phase2 | ブロッカー: APNsキー(Key ID `26PUZTM353`)のFirebase登録待ち。→ RemoteNotificationService実装→実機テスト |
| notification_scheduler i18n | 📋 残 | 21文字列。B案=`lookupAppLocalizations(Locale)`で対応(DECISIONS参照) |
| プレミアム(RevenueCat) | 🚧 配線中 | webhook実装済。upsell wiring未 |
| AdMob | 📋 未着手 | v1.1決定: push通知より先に着手(収益直結優先) |
| fil訳ネイティブレビュー | 📋 未 | 本番化前必須(妻に依頼) |

## 確定定数(変更時はDECISIONSに記録)
- App: Voikerchat / `jp.shibuyer.voikerchat` / voikerchat.com(Dynadot) / Team ID `S6XJP274T2`
- Vercelプロジェクト: `voikerchat-x621`(env: SUPABASE_URL / SUPABASE_SERVICE_KEY=service_role / ANTHROPIC_API_KEY)
- フリーミアム: 無料5回/日(広告+5、最大10)/ プレミアム$12.99月(50回/日・全13シーン・広告なし)
- サポート: kizunavi.support@gmail.com / APNs `.p8`: Drive `00_Project_Credentials`(`1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)
- 設計書: repo `docs/` の Persona/Tutorial/Onboarding-Design(参照のみ・再生成禁止)

## 次タスク(優先順・v1.1ロードマップ準拠: 9月着手)
1. AdMobリワード広告(+5回)実装
2. APNsキーFirebase登録 → RemoteNotificationService → 実機テスト
3. notification_scheduler i18n(B案)
4. fil訳レビュー → 本番化
