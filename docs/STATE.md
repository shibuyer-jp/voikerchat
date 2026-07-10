# STATE.md — Voikerchat 現在状態(外部メモリ)

> **運用ルール**: セッション開始時に読む/終了時に更新してコミット。ここが唯一の正(single source of truth)。
> 最終更新: 2026-07-10 夜(PR #2マージ+リポジトリ掃除 `1db8073`+tool/起動スクリプト。運用: shibuyer-ops/skills/ 新設 — 作業前に該当スキル参照)

## 機能ステータス
| 機能 | 状態 | 備考 |
|------|------|------|
| 認証(Supabase匿名認証) | ✅ 稼働 | プロジェクト `rfwbwwhqclabhnbsrygw`(Tokyo)。表示名は旧称"Japanese-learning-app"だが本番DB |
| チャット | ✅ 稼働 | `messages`/`conversation_sessions`/`user_streaks`/`rate_limits`(RLS有) |
| usage_logs | ✅ 稼働 | スキーマは commit `9877de6`。API層整合済 |
| analytics/rate-limit認証統一 | ✅ 完了 | `supabase.auth.getUser` パターンに統一済 |
| Supabaseエラーログ化 | ✅ 完了 | `.error` を全 insert/update/select で読む(`72246cf`) |
| premium_upsell_service i18n | ✅ 完了 | commit `35553aa` |
| notification_scheduler i18n | ✅ 完了 | commit `2456098`。B案=`lookupAppLocalizations(Locale)`。en/ja/fil 21キー実訳入り(2026-07-08 現物検証済) |
| プレミアム(RevenueCat) | ✅ 配線済 | webhook→`rate_limits.is_premium`(`283a824`)。CANCELは降格せずEXPIRATIONのみ降格 |
| **アカウント削除(ストア必須)** | ✅ 完了 | `/api/delete-account`+設定画面(⚙)。全テーブル明示削除+`auth.admin.deleteUser`。PR #1(`7142043`/merge `6cfec3b`)本番デプロイ済(2026-07-08) |
| badges | ✅ 実装済 | service/model/screen あり |
| **音声会話(PTT+TTS)** | ✅ 完了・main反映 | PR #2 squash merge `17ee53e`(2026-07-10)。STT `speech_to_text ^7.4.0` / TTS `flutter_tts ^4.2.2`。G6事前説明→OS権限、silent-stop途中送信防止、Android rate2倍換算修正(`defaultRate=0.45`)。テスト: Androidエミュレーター+iOS実機(iOS 26.5.2)全項目合格。iOS 26は約1分自動停止が発生しない(端末内認識化と推測)が保護コードは旧iOS/Android用に有効 |
| lefthook pre-push | ✅ 稼働 | analyze/test(`371b1ea`) |
| プッシュ通知 | 🚧 Phase2(コード実装済/設定待ち) | `remote_notification_service.dart`(285行)実装 + main.dart配線(initialize/setMessageHandler/subscribeToDefaultTopics/premium同期) + FCM設定(google-services.json / GoogleService-Info.plist = 実物・Firebaseプロジェクト`voikerchat`/`446972546346`) + Android google-services plugin(`.kts`済) = **全て済**。残(手動): ①iOS Xcodeで Push Notifications + Background Modes(remote-notification) capability有効化 ②APNsキー(`26PUZTM353`, .p8)を Firebase Console → Cloud Messaging にアップロード ③実機テスト。※submission非必須(機能拡張) |
| AdMob リワード広告 | ✅ コード完了 / 📋 実ID待ち | 実装フル完了: `rewarded_ad_service`(io/web facade) → `chat_screen` 配線(loadAd/isReady/showAd/grantAdBonus +5/snackbar/dispose/showWatchAdButton)。残=**AdMobコンソールで広告ユニット登録(手動)** → `ad_config.dart` の `_prod*` に実ID + `useTestAds=false`(submission必須: テストID出荷はAdMobポリシー違反)。現状テストID(`ca-app-pub-3940256099942544`) |
| fil訳ネイティブレビュー | 📋 未 | 本番化前必須(妻に依頼) |

## 確定定数(変更時はDECISIONSに記録)
- App: Voikerchat / `jp.shibuyer.voikerchat` / voikerchat.com(Dynadot) / Team ID `S6XJP274T2`
- Vercelプロジェクト: `voikerchat-x621`(env: SUPABASE_URL / SUPABASE_SERVICE_KEY=service_role / ANTHROPIC_API_KEY)
- APIエンドポイント(api/): chat / rate-limit / analytics / revenuecat-webhook / delete-account
- フリーミアム: 無料5回/日(広告+5、最大10)/ プレミアム$12.99月(50回/日・全13シーン・広告なし)
- サポート: voikerchat.support@gmail.com(forward→takatoh01@gmail.com)。kizunavi.support は非運用 / APNs `.p8`: Drive `00_Project_Credentials`(`1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)
- 設計書: repo `docs/` の Persona/Tutorial/Onboarding-Design(参照のみ・再生成禁止)

## 次タスク(優先順・submission最短経路)
> 主要機能のコードは概ね完了。残りは大半が手動(コンソール/Xcode/実機)。
1. **AdMob実ID**(submission必須): AdMobコンソールで広告ユニット登録(手動) → `ad_config.dart` の `_prod*` に実ID + `useTestAds=false`
2. **iOS submission**(Xcode導入済で着手可): Xcodeで署名/capabilities → Archive → App Store Connect(スクショ・メタデータ・特商法) → TestFlight → 審査提出
3. **Push Phase2**(submission非必須・機能拡張): iOSで Push/Background Modes capability有効化 + APNsキーをFirebase Consoleにアップロード + 実機テスト
4. **音声のPrivacy開示整合**(submission必須): App Store Connectのプライバシー申告に「音声データ→Appleサーバー送信」を反映(NSSpeechRecognitionUsageDescription対応済、申告のみ)
5. **fil訳ネイティブレビュー**(妻に依頼) → 本番化
6. 小タスク: G6ダイアログを権限取得済み時はスキップする改善(任意)。~~l10n.yaml非推奨行~~ ~~.dart_tool混入~~ → `1db8073` で完了

## 完了(直近・2026-07-10)
- **リポジトリ掃除+devスクリプト**(`1db8073`): `.dart_tool/`(38ファイル)+`.flutter-plugins-dependencies` をgit管理から除外・ignore追加 / `l10n.yaml` 非推奨 `synthetic-package` 行削除 / `tool/run_ios.sh`・`tool/run_android.bat`・`tool/README.md` 追加(dart-define内蔵)。**各マシンは次回pull時に注意**: `.dart_tool` にローカル変更があるとpullが弾かれる → `git checkout -- .dart_tool .flutter-plugins-dependencies` 後にpull(以後は再発しない)
- **PR #2 音声会話マージ**(squash `17ee53e`、ブランチ削除済)。Androidエミュレーター+iOS実機で全テスト項目合格。iOS署名検証エラーは自宅Wi-Fi環境で解消

## 完了(2026-07-08)
- i18nサービス層 全完了(notification_scheduler=最後の残り。現物検証で完了確認)
- premium配線・analytics/rate-limit認証統一・Supabaseエラーログ化(いずれもmain反映済)
- アカウント削除フロー実装+マージ+本番デプロイ(ストア必須要件を充足)
