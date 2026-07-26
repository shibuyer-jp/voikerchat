# STATE.md — Voikerchat 現在状態(外部メモリ)

> **運用ルール**: セッション開始時に読む/終了時に更新してコミット。ここが唯一の正(single source of truth)。
> 最終更新: 2026-07-26(通知機能一式・ストリーク修正・AdMob調査・アプリ内言語切替とiOS下準備をフル反映。ビルド番号は`1.0.0+10`まで進行。詳細は下記「完了(2026-07-25〜26セッション)」)
> 旧: 2026-07-16(App Icon/Launch Image独自素材化 + iOS CI/CDパイプライン再稼働。詳細は下記「完了(直近・2026-07-16)」)

## 機能ステータス
| 機能 | 状態 | 備考 |
|------|------|------|
| 認証(Supabase匿名認証) | ✅ 稼働 | プロジェクト `rfwbwwhqclabhnbsrygw`(Tokyo)。表示名は旧称"Japanese-learning-app"だが本番DB |
| チャット | ✅ 稼働 | `messages`/`conversation_sessions`/`user_streaks`/`rate_limits`(RLS有) |
| usage_logs | ✅ 稼働 | スキーマは commit `9877de6`。API層整合済 |
| analytics/rate-limit認証統一 | ✅ 完了 | `supabase.auth.getUser` パターンに統一済 |
| Supabaseエラーログ化 | ✅ 完了 | `.error` を全 insert/update/select で読む(`72246cf`) |
| premium_upsell_service i18n | ✅ 完了 | commit `35553aa` |
| notification_scheduler i18n | ✅ 完了 | commit `2456098`。B案=`lookupAppLocalizations(Locale)`。en/ja/fil 21キー実訳入り(2026-07-08 現物検証済)。2026-07-26(PR #17): アプリ内言語切替(`LocaleService`)を`_resolveLocale()`が考慮していなかった不具合を修正し、切替時にも再スケジュールされるよう`main.dart`側でリスナー結線(循環import回避のため)。ただし`notification_history`の既存レコードは配信時点の言語のまま(仕様、DECISIONS.md 2026-07-26参照) |
| **通知機能一式(ローカルリマインダー/マイルストーン/ON-OFFトグル/履歴)** | ✅ 完了・main反映 | PR #10(土台+タイムゾーン/Android権限バグ修正)・PR #11(設定トグル)・PR #12(履歴書き込み案B+C)・PR #17(言語切替時の再スケジュール)。実機/エミュレータでの最終検証は`docs/verification/release_verification_session_20260726.md`(旧`notification_verification_20260726.md`をdaily_limit検証と統合)参照 |
| **ストリーク端末間整合性** | ✅ 完了・main反映 | PR #13: 端末変更/再インストールでストリークが消える不具合(ローカル優先読み込みがSupabase復元パスを持っていなかった)と、fire-and-forget同期の競合による値巻き戻りを修正(タイムスタンプ比較方式)。マルチデバイス同時書き込みのロスト更新は明示的にスコープ外(DECISIONS.md 2026-07-25参照) |
| **アプリ内UI言語切替(設定画面)** | ✅ 完了・main反映 | PR #8。`LocaleService`(SharedPreferences永続化、`ValueNotifier<Locale?>`)。ja/en/fil対応 |
| **チャット画面AppBarのシーン名/レベル省略修正** | ✅ 完了・main反映 | PR #9。`ShrinkToFitText`ウィジェット新設(下限85%まで軽く縮小、それ以上はellipsis)。filの一部長いシーン名は省略が残る仕様として許容済み |
| プレミアム(RevenueCat) | ✅ 配線済 | webhook→`rate_limits.is_premium`(`283a824`)。CANCELは降格せずEXPIRATIONのみ降格 |
| **アカウント削除(ストア必須)** | ✅ 完了 | `/api/delete-account`+設定画面(⚙)。全テーブル明示削除+`auth.admin.deleteUser`。PR #1(`7142043`/merge `6cfec3b`)本番デプロイ済(2026-07-08) |
| badges | ✅ 実装済 | service/model/screen あり |
| **音声会話(PTT+TTS)** | ✅ 完了・main反映 | PR #2 squash merge `17ee53e`(2026-07-10)。STT `speech_to_text ^7.4.0` / TTS `flutter_tts ^4.2.2`。G6事前説明→OS権限、silent-stop途中送信防止、Android rate2倍換算修正(`defaultRate=0.45`)。テスト: Androidエミュレーター+iOS実機(iOS 26.5.2)全項目合格。iOS 26は約1分自動停止が発生しない(端末内認識化と推測)が保護コードは旧iOS/Android用に有効 |
| lefthook pre-push | ✅ 稼働 | analyze/test(`371b1ea`) |
| プッシュ通知 | 🚧 Phase2へ明示的に先送り(「道2」決定、2026-07-25) | 受信側コード(`remote_notification_service.dart`+main.dart配線+FCM設定一式)は既存のまま維持するが、自動送信基盤の新規構築・APNs関連の追加対応は今回のリリースでは行わない方針を確定(docs/DECISIONS.md 2026-07-25参照)。iOS APNsエンティトルメント(`ios/Runner/DebugProfile.entitlements`・`Release.entitlements`・pbxproj)はPR #14として実装済みだが**マージ保留**(手動署名の固定プロビジョニングプロファイルとentitlementsの不一致でiOSリリースビルドを壊すリスクがあるため)。Phase2着手時の手順は下記「次タスク」3番を参照 |
| AdMob リワード広告 | ✅ コード完了・実ID設定済 / ⚠️ No Fill(公開後に再検証) | `ad_config.dart`の`_prod*`は実ID設定済(`useTestAds=false`)、`GADApplicationIdentifier`・`SKAdNetworkItems`(PR #16、Google推奨50件)も設定済み。TestFlight Build 8〜10で継続的に`onAdFailedToLoad: code=1 No Fill`(コード側は正常、AdMobサーバーへのリクエスト自体は成功=responseId取得済み)。AdMobコンソール確認の結果、**原因はアプリがApp Store未公開であること**と判断(DECISIONS.md 2026-07-26)。App Store公開後に再検証すること(次タスク参照) |
| fil訳ネイティブレビュー | 📋 未 | 本番化前必須(妻に依頼) |
| **daily_limitの日次リセット漏れ修正** | ✅ コード完了・main反映(PR #19) / ⚠️ 実地検証**必須・未実施** | `api/chat.ts`・`api/rate-limit.ts`の両方にあった日次リセット処理が`used_today`のみリセットし`daily_limit`を放置していたバグを修正(広告視聴ボーナスが恒久化する不具合)。定数を`api/_constants.ts`/`lib/constants/rate_limit_constants.dart`に一元化。api/*.ts自動テストを追加していないため、`docs/verification/release_verification_session_20260726.md`のPART B(daily_limit動作検証)実施が必須(省略可の任意項目ではない。DECISIONS.md 2026-07-26参照)。既存データの是正・動作検証は同ドキュメントに統合済み(旧ファイルは実行禁止マーク済み・記録用) |
| **ストア掲載文の数値非依存化(v1.3→v1.4)** | ✅ 完了・main反映(PR #20) | `docs/Store-Listing-Copy-v1.4.md`。「無料版とプレミアム」段落から具体的回数(5回/日・+5回)を削除し、動的表示に委ねる文言へ変更。ストア本番反映(コンソールへの貼付)はPR #20本文のコピペ用テキストを使用(人間が実行、要)(DECISIONS.md 2026-07-26) |

## 確定定数(変更時はDECISIONSに記録)
- App: Voikerchat / `jp.shibuyer.voikerchat` / voikerchat.com(Dynadot) / Team ID `S6XJP274T2`
- Vercelプロジェクト: `voikerchat-x621`(env: SUPABASE_URL / SUPABASE_SERVICE_KEY=service_role / ANTHROPIC_API_KEY)
- APIエンドポイント(api/): chat / rate-limit / analytics / revenuecat-webhook / delete-account
- フリーミアム: 無料5回/日(広告+5、最大10、当日限り)/ プレミアム$12.99月(50回/日・全13シーン・広告なし)。値の唯一の定義元は`api/_constants.ts`(サーバー)/`lib/constants/rate_limit_constants.dart`(クライアントfallback)
- サポート: voikerchat.support@gmail.com(forward→takatoh01@gmail.com)。kizunavi.support は非運用 / APNs `.p8`: Drive `00_Project_Credentials`(`1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)
- 設計書: repo `docs/` の Persona/Tutorial/Onboarding-Design(参照のみ・再生成禁止)

## 次タスク(優先順・submission最短経路)
> 主要機能のコードは概ね完了。残りは大半が手動(コンソール/Xcode/実機/AdMob/App Store Connect)。
0. **リリース前修正2件(PR #19・#20は2026-07-26にmainへマージ済み。残るは人間の実機検証・ストア作業のみ)**:
   - `docs/verification/release_verification_session_20260726.md`を実施(通知/ストリーク系検証とdaily_limit是正+動作検証(PART A/B、**PART Bは必須**)を1本化した統合セッション。人間作業・未実施)。日をまたぐ/再インストールが必要な項目(Phase D・E)は同ドキュメント末尾に分離済み、別セッションでよい
   - PR #20本文のコピペ用テキスト(en-US/ja-JP)をGoogle Play Console/App Store Connectの該当欄に反映(人間作業・未実施)
1. **iOS submission**: Build 11(`1.0.0+11`)への更新が必要(PR #17がBuild 10に未収録のため、実機検証STEP 4/Phase Bの実施にはBuild 11以降が必須)。2026-07-26のBuild 11起動はArchiveステップで失敗(根本原因・修正はDECISIONS.md 2026-07-26参照、`ios-release.yml`とRunner.xcodeprojのRelease設定を完全な手動署名に修正済み・PR未マージ)。**次回起動前に**: (a) 当該PRをレビュー・マージ、(b) Apple Developer Portalで証明書枚数に余裕があることを確認(2026-07-26に古いDevelopment証明書7枚を失効済み)、(c) `gh workflow run ios-release.yml --ref main` で再実行。成功後の残作業(手動): App Store Connectでビルド処理完了を確認 → メタデータ・スクショ・特商法 → TestFlight → 審査提出。
   **ローカルXcodeでのアーカイブは今後も使わない**(このMacはXcode 26非対応。iOS 26 SDK必須エラーで拒否される)。ビルドを更新する際は必ずCI(`ios-release.yml`をworkflow_dispatchで手動実行)を使う。
2. **App Store公開後タスク**(公開して初めて着手可能。公開前は保留でよい):
   - AdMobリワード広告のNo Fill再検証(上記「AdMob リワード広告」欄参照。公開直後は在庫が薄い場合があるため数日様子を見る)
   - AdMobコンソールにApp Storeのストアリンク(アプリURL)を登録
   - `voikerchat.com`に`app-ads.txt`を設置(認可済み広告枠の申告。未設置だと広告収益に悪影響が出る可能性)
   - AdMobの「準備状況」レビュー(Ready for review的なチェックリスト)を確認し、指摘があれば対応
3. **Push Phase2**(submission非必須・機能拡張・今回のリリースではスコープ外=「道2」)。**2026-07-26のApple Developer Portal実査で判明**: 手順1・2は既に完了済み(「voikerchat App Store 2026」プロファイルには既にPush Notifications capabilityが有効。Created By: API Keyで、経緯は不明・未調査)。よってPR #14マージ時の当初の技術的懸念(capability不一致でarchive失敗するリスク)は解消したと判断(DECISIONS.md 2026-07-26参照)。ただし「道2」の戦略判断自体は独立しており、着手時は以下を**この順で**、手動作業とPR #14マージをセットで行うこと:
   1. ~~Apple Developer PortalでApp ID(`jp.shibuyer.voikerchat`)のPush Notifications capabilityを有効化~~ → 2026-07-26確認時点で既に有効化済み
   2. ~~プロビジョニングプロファイル「voikerchat App Store 2026」を、capability追加後の状態で再作成~~ → 現行プロファイルが既にcapability有効化後の状態
   3. APNsキー(`26PUZTM353`, .p8。Drive `00_Project_Credentials`、file ID `1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)をFirebase Console → Cloud Messagingにアップロード
   4. PR #14(iOS APNsエンティトルメント追加、実装済み・マージ保留中)をマージ
   5. 実機でのプッシュ受信テスト
4. **Android署名fail-fast**(PR #5、実装済み・マージ保留中): key.properties不在時のdebug鍵フォールバック廃止。Windows Laptopでのローカルgradle検証待ち(このMacはAndroid SDK未セットアップのため検証不可)
5. **音声のPrivacy開示整合**(submission必須): App Store Connectのプライバシー申告に「音声データ→Appleサーバー送信」を反映(NSSpeechRecognitionUsageDescription対応済、申告のみ)
6. **fil訳ネイティブレビュー**(妻に依頼) → 本番化。対象は既存21キー(notification_scheduler)に加え、言語切替UI(PR #8)・通知トグル(PR #11)の新規キーも機械翻訳のまま未レビュー
7. 通知履歴の表示時ローカライズ改修(任意・優先度低): 現状「配信時点の言語で保持」が仕様(DECISIONS.md 2026-07-26)。ユーザーから改善要望が出た場合のみ着手
8. 小タスク: G6ダイアログを権限取得済み時はスキップする改善(任意)。~~l10n.yaml非推奨行~~ ~~.dart_tool混入~~ → `1db8073` で完了
9. **api/*.ts のテスト基盤整備**(任意・バックログ、2026-07-26追加): 現状jest/vitest等のTSテスト基盤が皆無、tsconfig.json/testスクリプトも無し。前提としてこのMacへのNode.jsインストールも必要(現状未インストールでローカル実行不可)。daily_limitリセット修正(DECISIONS.md 2026-07-26)ではスコープ肥大回避のため見送り、実機+SQL検証(`docs/verification/daily_limit_reset_verification_20260726.md`)で代替した

## 完了(2026-07-25〜26セッション)
- **オープンPR一式のマージ**: #3(purchases_flutter v10.4.3対応)・#4(規約類の英語版・不整合修正)・#6(AI生成コンテンツ報告機能、Google Playポリシー必須)・#7(ストア掲載文v1.3)・#8(アプリ内UI言語切替)をmainへマージ
- **チャット画面AppBarのシーン名/レベル省略修正**(PR #9): `ShrinkToFitText`ウィジェット新設
- **通知機能一式**(PR #10・#11・#12): ローカルリマインダー/マイルストーンの実接続+タイムゾーン・Android 13+権限バグ修正、設定画面ON/OFFトグル、通知履歴の書き込み(案B: 先行INSERT+起動時確定 / 案C: 即時INSERT)。実装中に`NotificationHistory`モデルの`user_id`/`is_read`列マッピング漏れ(既存バグ、`saveNotification`が今回まで一度も呼ばれておらず未発覚)も修正
- **ストリーク端末間整合性修正**(PR #13): 端末変更/再インストールでの消失、fire-and-forget同期競合を解消
- **iOS APNsエンティトルメント実装**(PR #14): `docs/DECISIONS.md`記載の理由により**マージ保留**(Phase2まで)
- **AdMob広告No Fill調査**: 診断ログ追加(PR #15、ビルド`1.0.0+9`)→実機ログでcode=1(No Fill)を確認→診断ログ削除+`SKAdNetworkItems`50件追加(PR #16、ビルド`1.0.0+10`)→再検証でも改善せず→AdMobコンソール確認の結果、原因はApp Store未公開と判断(DECISIONS.md参照)
- **アプリ内言語切替時の通知再スケジュール修正**(PR #17): `_resolveLocale()`がアプリ内言語切替を考慮していなかった不具合を修正。循環import回避のため`main.dart`側でリスナー結線
- **iOSビルド番号進行**: `1.0.0+7` → `+8`(通知機能一式)→ `+9`(診断ログ)→ `+10`(SKAdNetwork対応)。いずれも`ios-release.yml`経由でApp Store Connectへアップロード成功
- **実機検証キット新設**: `docs/verification/notification_verification_20260726.md`(通知トグル/履歴書き込み/ストリーク回帰/言語切替再スケジュールの統合チェックリスト)
- Android署名fail-fast(PR #5)は前セッションから引き続き**マージ保留**(Windows Laptopでのgradle検証待ち)

## 完了(直近・2026-07-16)
- **App Icon/Launch Imageをプレースホルダーから独自素材に置換**(commit `4cd98ad`): `flutter_launcher_icons ^0.14.4` / `flutter_native_splash ^2.4.8` を導入。素材は `assets/icon/app_icon_1024.png`(1024×1024)/ `assets/icon/splash_logo_2048.png`(2048×2048)。スプラッシュ背景色 `#ffffff` は仮置き(ブランドカラー確定時に変更予定)。
- **ビルド番号を `1.0.0+1` → `1.0.0+4` に更新**: pubspec.yaml上は一度も+1から変わっていなかったが、7/11のCI成功2回分がApp Store Connectへアップロード済みの可能性があるため重複回避で+4に設定。
- **iOS CI/CDパイプライン(`ios-release.yml`)の存在を再確認・活用**: このパイプラインは実は**2026-07-11に既に構築・main反映・Secrets登録・2回の成功実行(うち1回はApp Store Connectへの実アップロードまで成功)済み**だった。しかし当時このSTATE.mdの更新が漏れたため、2026-07-16の別セッションでは「ゼロから作る」前提の依頼が発生し、既存資産の調査に時間を要した(`gh secret list` / `gh run list` で判明)。**教訓: CI/CD・署名まわりの変更は必ずこのSTATE.mdに記録すること。**
- 上記を反映し、CI(run `29471722651`)を手動実行 → 全ステップ成功(9m51s)、build 1.0.0+4 を App Store Connect へ自動アップロード完了。

## 完了(直近・2026-07-10)
- **リポジトリ掃除+devスクリプト**(`1db8073`): `.dart_tool/`(38ファイル)+`.flutter-plugins-dependencies` をgit管理から除外・ignore追加 / `l10n.yaml` 非推奨 `synthetic-package` 行削除 / `tool/run_ios.sh`・`tool/run_android.bat`・`tool/README.md` 追加(dart-define内蔵)。**各マシンは次回pull時に注意**: `.dart_tool` にローカル変更があるとpullが弾かれる → `git checkout -- .dart_tool .flutter-plugins-dependencies` 後にpull(以後は再発しない)
- **PR #2 音声会話マージ**(squash `17ee53e`、ブランチ削除済)。Androidエミュレーター+iOS実機で全テスト項目合格。iOS署名検証エラーは自宅Wi-Fi環境で解消

## 完了(2026-07-08)
- i18nサービス層 全完了(notification_scheduler=最後の残り。現物検証で完了確認)
- premium配線・analytics/rate-limit認証統一・Supabaseエラーログ化(いずれもmain反映済)
- アカウント削除フロー実装+マージ+本番デプロイ(ストア必須要件を充足)
