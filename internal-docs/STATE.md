# STATE.md — Voikerchat 現在状態(外部メモリ)

> **運用ルール**: セッション開始時に読む/終了時に更新してコミット。ここが唯一の正(single source of truth)。ただしPlay Console/App Store Connect等の外部サービスの配布状況は、必ず実画面で確認してから記録すること(2026-07-27、Android versionCode 7の配布状況誤認を教訓に追記)。
> 最終更新: 2026-08-04(RevenueCat Android有効化がほぼ完了。①Google Play定期購入商品作成〈7/29完了〉→②RevenueCatにAndroidアプリ登録+Google Playサービスアカウント認証〈本日完了〉→③Offering/Productマッピング〈本日完了、Entitlement `Premium`にAttach〉まで完了、残るのはReal-Time Developer Notifications接続〈8/6以降〉と④ビルドへの`REVENUECAT_ANDROID_KEY`投入〈テスト完走後〉のみ。あわせて`docs/`配下の内部ドキュメント公開URL露出を是正(PR #38、内部専用52件を`internal-docs/`へ移動)、シーン数記載を実装(18)に統一(PR #37)。Androidクローズドテストは8/4時点で「12人が4日間連続」表示、14日到達見込みを8/14前後に修正(前回の8/13から)。詳細はDECISIONS.md 2026-08-04参照、当日の完全な記録は`shibuyer-ops/memory/handoff_20260804.md`)
> 旧: 2026-08-03(Build 16をAndroidクローズドテストへ配布・10:27 JST「選択したテスターに公開されました」。iOS 2回目リジェクト(Submission ID `94530390-d70e-4942-b6fc-9c709f735099`、審査対象Build 15/iPad Air 11-inch M3、Guideline 5.1.1(iv)+5.1.1(i)/5.1.2(i))を受け、Build 17(PR #36: マイク権限ダイアログのCancel削除+AIデータ同意画面新設+プライバシーポリシー修正)を14:38 JSTに再提出・審査待ち。詳細はDECISIONS.md 2026-08-03参照)
> 旧: 2026-07-31(PR #33マージ: usage_logsのlocale/platform記録漏れを修正。Androidクローズドテスト14日タイマーが2026-07-30 19:31 JSTに起算(完走見込み2026-08-13以降)。オプトイン不通の原因はSNS内蔵ブラウザと特定・解消済み。詳細はDECISIONS.md参照。「次タスク」を「進行中/未完了項目/バックログ」の3分類に再編)
> 旧: 2026-07-29 夜(Google Play の定期購入商品を作成・有効化しP3の①を完了。`voikerchat_premium_monthly:monthly-autorenew`、174か国、JPY 2,120 / PHP 895.00。**Play Console 側の設定作業はこれで全て完了**。アプリのコンテンツ10件は7/14に申告済み、ポリシー違反ゼロ。テスターは16アカウント確保見込みで要件12に対し余裕4)
> 旧: 2026-07-29 夕方(Play Console 実画面確認。Billing Library 8 未対応のポリシー違反は 07-28 18:43 に解消済みと判明(P6クローズ)、Build 13 の対象SDKは 36 で 2026-08-31 期限の要件を充足済みと確認)
> 旧: 2026-07-29 午後(App Store 1.0 審査提出完了(`1.0.0+15`/commit `7c9687c`、10:50 JST、承認後自動リリース)。サブスク価格が米国1か国のみだった問題を修正し175か国へ展開。Androidクローズドテストのテスターリスト「Voikerchat Closed Test - PH」に確定11名を登録、オプトインURL `https://play.google.com/apps/testing/jp.shibuyer.voikerchat` を確認済み。RevenueCatの`app_user_id`はSupabase user_id と結線済みでコード修正不要と確認)
> 旧: 2026-07-28 夜(Build 15。実機で英語ロケールのみPaywallの利用規約/プライバシーポリシーリンクが表示されない不具合を受け、`paywall_screen.dart`のリンクRowを`SingleChildScrollView`内から`Scaffold.bottomNavigationBar`固定フッターへ移動。`pubspec.yaml` 1.0.0+15)
> 旧: 2026-07-28 PM(Build 14。App Store Guideline 3.1.2対応でPaywall価格表示に更新期間を追加。`pricePerMonth`を`premiumPriceFallback`+`premiumPriceWithPeriod({price})`に分割、`paywall_screen.dart`の価格表示を経路によらず期間表記付きに統一、`pubspec.yaml` 1.0.0+14)
> 旧: 2026-07-28 AM(Paywall文言監査。PR #28の数値除去はmain反映済みと確認、`app_fil.arb`の`featureAnimeTitle`/`featureStatsTitle`未翻訳を新規修正、STATE.md内のPR #28「未マージ」表記の訂正、App Store Guideline 3.1.2調査結果を追記)
> 旧: 2026-07-27 PM(Build 13、PR #28。ストリークのリセット実装(案A)+日付境界のローカルタイム化、Paywall購読ボタン制御、通知履歴画面の言語切替時再読み込み追加、プレミアム文面の数値除去、`pubspec.yaml` 1.0.0+13)
> 旧: 2026-07-27 AM(Android versionCode 7が2026-07-23にAlphaトラック公開済みと判明、かつSupabase未接続の不良ビルドの疑いを追記。Build 13投入をクリティカルパス最優先に設定)

## 機能ステータス
| 機能 | 状態 | 備考 |
|------|------|------|
| 認証(Supabase匿名認証) | ✅ 稼働 | プロジェクト `rfwbwwhqclabhnbsrygw`(Tokyo)。表示名は`voikerchat-prod`(2026-08-01確認。旧称"Japanese-learning-app"という記載は古い) |
| チャット | ✅ 稼働 | `messages`/`conversation_sessions`/`user_streaks`/`rate_limits`(RLS有) |
| usage_logs | ✅ 稼働 | スキーマは commit `9877de6`。API層整合済 |
| analytics/rate-limit認証統一 | ✅ 完了 | `supabase.auth.getUser` パターンに統一済 |
| Supabaseエラーログ化 | ✅ 完了 | `.error` を全 insert/update/select で読む(`72246cf`) |
| premium_upsell_service i18n | ✅ 完了 | commit `35553aa` |
| notification_scheduler i18n | ✅ 完了 | commit `2456098`。B案=`lookupAppLocalizations(Locale)`。en/ja/fil 21キー実訳入り(2026-07-08 現物検証済)。2026-07-26(PR #17): アプリ内言語切替(`LocaleService`)を`_resolveLocale()`が考慮していなかった不具合を修正し、切替時にも再スケジュールされるよう`main.dart`側でリスナー結線(循環import回避のため)。ただし`notification_history`の既存レコードは配信時点の言語のまま(仕様、DECISIONS.md 2026-07-26参照)。**2026-07-27(Build 13、PR #28)**: TestFlight Build 12実機で「言語切替後も通知履歴3件が変わらない」と報告あり再調査。バックエンド(予約通知の再スケジュール)自体はPR #17で既に正しく動作するはずと判断したが、`notification_history_screen.dart`にロケール変更を検知して一覧を再読み込みする仕組みが無く(`_setupRealtimeListener()`がTODOのまま未実装)、画面が古いキャッシュを表示し続けていた可能性が高いと判断。`LocaleService.currentLocale`のリスナーを同画面に追加した(DECISIONS.md 2026-07-27参照)。ただし実機再検証は未実施 |
| **通知機能一式(ローカルリマインダー/マイルストーン/ON-OFFトグル/履歴)** | ✅ 完了・main反映 | PR #10(土台+タイムゾーン/Android権限バグ修正)・PR #11(設定トグル)・PR #12(履歴書き込み案B+C)・PR #17(言語切替時の再スケジュール)。実機/エミュレータでの最終検証は`internal-docs/verification/release_verification_session_20260726.md`(旧`notification_verification_20260726.md`をdaily_limit検証と統合)参照 |
| **ストリーク端末間整合性** | ✅ 完了・main反映 | PR #13: 端末変更/再インストールでストリークが消える不具合(ローカル優先読み込みがSupabase復元パスを持っていなかった)と、fire-and-forget同期の競合による値巻き戻りを修正(タイムスタンプ比較方式)。マルチデバイス同時書き込みのロスト更新は明示的にスコープ外(DECISIONS.md 2026-07-25参照) |
| **ストリークのリセット実装(案A)** | ✅ 完了・PR #28(main反映済み) | `resetStreak()`が定義済みだが呼び出し箇所ゼロで、サボっても減らない(単調増加)不具合を修正。`incrementStreak()`に前回学習日からのギャップ判定(today/continuing/broken)を実装、前日継続なら+1・一昨日以前(または記録無し)なら1にリセット。`_restoreStreakFromSupabase()`にも同じ判定を適用(復元直後の初回表示から正確な値に)。あわせて日付境界をUTC→端末ローカルタイムへ変更(フィリピン/日本の朝型ユーザーでの日付ズレ回避)。テスト用に`nowProvider`(現在時刻の差し替え)を追加し`test/services/streak_service_test.dart`で日付境界を9ケース自動検証(DECISIONS.md 2026-07-27参照) |
| **アプリ内UI言語切替(設定画面)** | ✅ 完了・main反映 | PR #8。`LocaleService`(SharedPreferences永続化、`ValueNotifier<Locale?>`)。ja/en/fil対応 |
| **チャット画面AppBarのシーン名/レベル省略修正** | ✅ 完了・main反映 | PR #9。`ShrinkToFitText`ウィジェット新設(下限85%まで軽く縮小、それ以上はellipsis)。filの一部長いシーン名は省略が残る仕様として許容済み |
| プレミアム(RevenueCat) | ✅ 配線済 | webhook→`rate_limits.is_premium`(`283a824`)。CANCELは降格せずEXPIRATIONのみ降格 |
| **アカウント削除(ストア必須)** | ✅ 完了 | `/api/delete-account`+設定画面(⚙)。全テーブル明示削除+`auth.admin.deleteUser`。PR #1(`7142043`/merge `6cfec3b`)本番デプロイ済(2026-07-08) |
| badges | ✅ 実装済 | service/model/screen あり |
| **音声会話(PTT+TTS)** | ✅ 完了・main反映 | PR #2 squash merge `17ee53e`(2026-07-10)。STT `speech_to_text ^7.4.0` / TTS `flutter_tts ^4.2.2`。G6事前説明→OS権限、silent-stop途中送信防止、Android rate2倍換算修正(`defaultRate=0.45`)。テスト: Androidエミュレーター+iOS実機(iOS 26.5.2)全項目合格。iOS 26は約1分自動停止が発生しない(端末内認識化と推測)が保護コードは旧iOS/Android用に有効 |
| lefthook pre-push | ✅ 稼働 | analyze/test(`371b1ea`) |
| プッシュ通知 | 🚧 Phase2へ明示的に先送り(「道2」決定、2026-07-25) | 受信側コード(`remote_notification_service.dart`+main.dart配線+FCM設定一式)は既存のまま維持するが、自動送信基盤の新規構築・APNs関連の追加対応は今回のリリースでは行わない方針を確定(internal-docs/DECISIONS.md 2026-07-25参照)。iOS APNsエンティトルメント(`ios/Runner/DebugProfile.entitlements`・`Release.entitlements`・pbxproj)はPR #14として実装済みだが**マージ保留**(手動署名の固定プロビジョニングプロファイルとentitlementsの不一致でiOSリリースビルドを壊すリスクがあるため)。Phase2着手時の手順は下記「次タスク」3番を参照 |
| AdMob リワード広告 | ✅ コード完了・実ID設定済 / ⚠️ No Fill(公開後に再検証) | `ad_config.dart`の`_prod*`は実ID設定済(`useTestAds=false`)、`GADApplicationIdentifier`・`SKAdNetworkItems`(PR #16、Google推奨50件)も設定済み。TestFlight Build 8〜10で継続的に`onAdFailedToLoad: code=1 No Fill`(コード側は正常、AdMobサーバーへのリクエスト自体は成功=responseId取得済み)。AdMobコンソール確認の結果、**原因はアプリがApp Store未公開であること**と判断(DECISIONS.md 2026-07-26)。App Store公開後に再検証すること(次タスク参照) |
| fil訳ネイティブレビュー | 📋 未 | 本番化前必須(妻に依頼) |
| **Androidクローズドテスト配布** | ✅ **Build 16(versionCode 16)配布中**(2026-08-03 10:27 JST「選択したテスターに公開されました」) | 2026-08-03、Build 16の審査提出・配布が完了。**usage_logsのplatform/localeはBuild 16配信より前から記録が存在していた**(android/ja=4件、android/en=2件、最終記録00:27 UTC、NULLは233件残存。どのPRで実装されたかは未特定、要追跡)。旧: Alphaトラック「公開」、配布中は**Build 13(versionCode 13)**。main(`1.0.0+15`)より2世代古く、PR #29(価格期間表記)・PR #30(Paywallフッター)が未反映。※実機確認ではBuild 13でも `$12.99/月` は表示されていた(要因未確定)。**次に使えるversionCodeは15**(7・13は使用済で永久予約)。テスター: リスト名「Voikerchat Closed Test - PH」に**確定11名+開発者自身=12アカウント**を登録済み。メールアドレス要確認3名(K.G. / L.B. / R.A.、2026-08-04匿名化)は妻の回答後に追加。**確保可能な上限が15名しかなく、要件(12名以上が14日間連続オプトイン)に対して余裕が2名分しかない**。オプトインURL: `https://play.google.com/apps/testing/jp.shibuyer.voikerchat`(Play Consoleの「リンクをコピー」はストア掲載URLを返すためこちらを使用。実機で表示確認済み)。国/地域: フィリピン・日本の2か国。**タイマーの起点は登録ではなくオプトイン**。新AAB配信でタイマーはリセットされない。募集文面(英語/タガログ語)作成済み、タガログ語は妻のネイティブ確認後に送付(DECISIONS.md 2026-07-29参照) |
| **daily_limitの日次リセット漏れ修正** | ✅ コード完了・main反映(PR #19) / ⚠️ 実地検証**必須・未実施** | `api/chat.ts`・`api/rate-limit.ts`の両方にあった日次リセット処理が`used_today`のみリセットし`daily_limit`を放置していたバグを修正(広告視聴ボーナスが恒久化する不具合)。定数を`api/_constants.ts`/`lib/constants/rate_limit_constants.dart`に一元化。api/*.ts自動テストを追加していないため、`internal-docs/verification/release_verification_session_20260726.md`のPART B(daily_limit動作検証)実施が必須(省略可の任意項目ではない。DECISIONS.md 2026-07-26参照)。既存データの是正・動作検証は同ドキュメントに統合済み(旧ファイルは実行禁止マーク済み・記録用) |
| **ストア掲載文の数値非依存化(v1.3→v1.4)** | ✅ 完了・main反映(PR #20) | `internal-docs/Store-Listing-Copy-v1.4.md`。「無料版とプレミアム」段落から具体的回数(5回/日・+5回)を削除し、動的表示に委ねる文言へ変更。ストア本番反映(コンソールへの貼付)はPR #20本文のコピペ用テキストを使用(人間が実行、要)(DECISIONS.md 2026-07-26) |
| **プレミアム案内文の数値除去** | ✅ 完了・PR #28(main反映済み) | `featureAnimeDesc`の「13」(実態18シーンと既に不一致だった)を数字なしの表現に変更(3言語)。`badgeBasicMasterDesc`/`badgeAnimeMasterDesc`は数字を残しつつ`{count}`プレースホルダー化し、`SceneService`の実件数を動的に埋め込む方式に変更(DECISIONS.md 2026-07-27参照) |
| **Paywall文言監査(2026-07-28)** | ✅ 完了(未pushのローカル修正) | TestFlightで「13 engaging scenes」が見えた件を調査した結果、`featureAnimeDesc`の数字除去は既にPR #28でmain反映済みで、観測ビルド(Build 12)がその前のビルドだったための表示遅延と判明(コード修正不要)。横断監査で`app_fil.arb`の`featureAnimeTitle`/`featureStatsTitle`が英語のまま未翻訳だった別件を新たに発見・修正("Mga Eksenang Anime" / "Dashboard ng Estadistika")。他にja/en/filのキー欠落・数字混入は無し(DECISIONS.md 2026-07-28参照) |
| **Paywall価格表示の更新期間追加(Build 14)** | ✅ 完了・main反映(PR #29) | App Store Guideline 3.1.2監査(価格/EULA/プライバシーポリシーのPaywall内表示)の結果、EULA・プライバシーポリシーのリンクは既に充足していたが、RevenueCat設定済み時に優先表示される`_dynamicPrice`(`storeProduct.priceString`)に更新期間表記が無い欠落を検出(iOS TestFlight Build 12実機で「$12.99」のみの表示を確認、裏付け済み)。ARBキー`pricePerMonth`(価格+期間の合成済み固定文字列)を廃止し、`premiumPriceFallback`(価格のみ)+`premiumPriceWithPeriod({price})`(ロケール別の期間サフィックス、en:"{price}/month"/ja:"{price}／月"/fil:"{price}/buwan")に分割。`paywall_screen.dart`はRevenueCat取得値・フォールバック値のどちらでも必ずこのテンプレートを通すよう統一し、経路によらず期間表記が付くようにした(DECISIONS.md 2026-07-28参照) |
| **Paywall利用規約/プライバシーポリシーリンクの固定フッター化(Build 15)** | ✅ 完了(未pushのローカル修正) | iPhone実機(TestFlight Build 14)で英語ロケールのみ「Terms of Service」「Privacy Policy」リンクが表示されない(日本語では正常)不具合を調査。ARBキー欠落・横方向オーバーフロー・スクロール不可固定レイアウト・条件分岐のいずれもコード上の原因として該当せず、iPhone 16 Pro(6.1インチ相当)/iPhone 16 Pro Max(6.9インチ相当)シミュレータでも英語ロケールで再現しなかった(実機のDynamic Type設定等、未検証の変数が残る)。原因を断定できないまま暫定対応とせず、恒久策としてリンクRowを`SingleChildScrollView`内から`Scaffold.bottomNavigationBar`固定フッターへ移動し、スクロール位置・テキストサイズに依存せず常時表示されるようにした(DECISIONS.md 2026-07-28参照) |
| **Paywall購読ボタン制御** | ✅ 完了・PR #28(main反映済み) | RevenueCat未configured時(Androidキー未登録)に購読ボタンをdisabled化+説明文表示。テスターが不具合と誤認しアンインストールして14日タイマー要件に悪影響が出るリスクを先回りして回避(DECISIONS.md 2026-07-27参照) |

## 確定定数(変更時はDECISIONSに記録)
- App: Voikerchat / `jp.shibuyer.voikerchat` / voikerchat.com(Dynadot) / Team ID `S6XJP274T2`
- Vercelプロジェクト: `voikerchat-x621`(env: SUPABASE_URL / SUPABASE_SERVICE_KEY=service_role / ANTHROPIC_API_KEY)
- APIエンドポイント(api/): chat / rate-limit / analytics / revenuecat-webhook / delete-account
- フリーミアム: 無料5回/日(広告+5、最大10、当日限り)/ プレミアム$12.99月(50回/日・全18シーン・広告なし)。値の唯一の定義元は`api/_constants.ts`(サーバー)/`lib/constants/rate_limit_constants.dart`(クライアントfallback)。シーン数はT-34で13→18に拡張済み(基本8+アニメ5+実用5、`lib/services/scene_service.dart`)
- サポート: voikerchat.support@gmail.com(forward→takatoh01@gmail.com)。kizunavi.support は非運用 / APNs `.p8`: Drive `00_Project_Credentials`(`1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)
- 設計書: repo `internal-docs/` の Persona/Tutorial/Onboarding-Design(参照のみ・再生成禁止)
- RevenueCat: App ID(Android) `appf7acdb482b` / Product `voikerchat_premium_monthly:monthly-autorenew` / Entitlement `Premium`(iOS/Android併存) / Offering `default`(2026-08-04設定完了)

## 進行中

- **Androidクローズドテスト**: 14日タイマー進行中(起算 2026-07-30 19:31 JST)。**2026-08-04時点でPlay Consoleは「12人が4日間連続」と表示**[確認済 2026-08-04、Play Console実画面]。14日到達(完走)見込みを**2026-08-14前後**に修正(起算日は変わらず、完走見込み日の記載精度を修正。旧: 2026-08-13以降)。オプトイン不通問題(SNS内蔵ブラウザ起因)は特定・解消済み。詳細はDECISIONS.md 2026-07-30参照。**運用知見**: Play Consoleの「12人」表示は仕様上の固定表示で実数ではなく、実際は毎日16〜19アカウントが稼働(テスター管理業者〈ココナラ経由〉からの回答、2026-08-04)。統計情報が「データを使用できません」と出るのは反映に約1週間かかるためで、配信開始7/30起点なら8/6頃から表示され始める見込み(同回答)
- **iOS**: 2回目リジェクト後、Build 17(`1.0.0+17`)を2026-08-03 14:38 JSTに再提出・審査待ち。Submission ID `94530390-d70e-4942-b6fc-9c709f735099`。アプリ本体・サブスクリプショングループ・サブスクリプション商品の3項目とも「審査待ち」。詳細はDECISIONS.md 2026-08-03参照(旧: `1.0.0+15`/commit `7c9687c`、2026-07-29 10:50 JST提出は2回目リジェクトで終了)

## 未完了項目(クローズドテスト期間中に対応)

1. **Build 16のリリース** ✅ 完了(2026-08-03 10:27 JST「選択したテスターに公開されました」を確認)
   - 内容: A(#31 レート制限) / B(#32 AdMobコメント) / C(#32 PREMIUM i18n、表示上の変化なし) / D(#32 ログレベル) / E(#33 locale・platform記録) / F(#34 通知履歴の削除・表示修正) / G(#35 統計画面の表示修正4件) / H(#29 Paywall価格期間表記) / I(#30 Paywallフッター化)
   - 担当: CC(versionCode更新)+ 人間(AABビルド・Play Consoleアップロード)、いずれも完了
   - 検証: クローズドテストのリリース一覧にBuild 16が「選択したテスターに公開されました」と表示されること → 2026-08-03 10:27 JST確認済み

2. **iOS Build 17の審査結果待ち**
   - 内容: 2回目リジェクト(Guideline 5.1.1(iv)/5.1.1(i)/5.1.2(i))への対応(PR #36)。詳細はDECISIONS.md 2026-08-03参照
   - 担当: CC(実装・再提出)完了、審査結果待ち
   - 検証: App Store Connectでアプリ本体・サブスクリプショングループ・サブスクリプション商品の3項目とも「承認済み」になること
   - 期限: Apple審査完了まで(通常48時間以内)

3. **API原価の実測**
   - 担当: 人間(Anthropic / OpenAIダッシュボード)
   - 検証: 1ユーザー1日あたりのAPI原価が算出されていること
   - 期限: 2026-08-14
   - 現況: Claude Haikuは7/25-7/30累計で$0.084(6日間)。1ユーザー1日あたり約$0.006で、価格設計の制約要因にならない水準。OpenAI TTSはusage_logsに記録が無いためダッシュボードの合計値でしか把握できない

4. **統計情報の共有(外部サービス保証条件)**
   - 担当: 人間
   - 検証: 出品者へPlay Console統計を共有済みであること
   - 期限: 2026-08-14

5. **本番環境へのアクセス申請**
   - 担当: 人間
   - 検証: 申請フォームの送信完了
   - 期限: 完走確認後すみやかに
   - 前提: 「質問のプレビュー」で設問を事前確認しておくこと

6. **年齢設定の不整合を解消**
   - 担当: 人間
   - 検証: 利用規約・プライバシーポリシー・Play Consoleのコンテンツレーティング・App Store Connectのレーティングの4箇所が一致していること
   - 期限: 本番申請前
   - 注記: 法務ページは13歳以上、App Store Connectは18+と記録されているが未確認。実物で確認すること

7. **テスターフィードバックの収集**
   - 担当: 人間(配偶者経由で依頼済み、2026-07-31)
   - 検証: `internal-docs/TESTER-FEEDBACK.md`に日付・内容・対応方針が記録されていること
   - 期限: 2026-08-10
   - 目的: 本番申請の設問「フィードバックに基づく改善」の回答材料

8. **`ai_data_consent_screen.dart`のオーバーフロー対策** ✅ 完了(PR #40、実機確認2026-08-04)
   - 内容: AI同意画面本文の`Column`を`SingleChildScrollView`でラップする(2026-08-03、PR #36で新設時から未対応のまま。「技術的負債」節参照)
   - 担当: CC(実装)+人間(実機確認)、いずれも完了
   - 検証: Android実機(Xiaomi 23073RPBFG、Android 15、フォントサイズ最大)でオーバーフローが発生しないこと → 2026-08-04確認済み。「同意しない」ボタンの動作、iPad Air 11-inch(iOS)での確認は未実施(「技術的負債」節参照)

## バックログ(テスト完走後)

旧「次タスク」の未完了分。下記「運用ルール」によりPlay Consoleのトラック設定を変更できないため、着手はテスト完走(2026-08-14目安)後。

- **RevenueCat Android有効化**(ほぼ完了、残作業のみ。①②③は完了、④のみテスト完走後): ①Google Play Consoleで定期購入商品を作成 ✅完了(2026-07-29、`voikerchat_premium_monthly:monthly-autorenew`、174か国) → ②RevenueCatにAndroidアプリ登録+Google Playサービスアカウント認証 ✅完了(2026-08-04)[本人報告、Claude Code未検証]。Google Cloudプロジェクト`voikerchat`(Firebaseと同一)でPlay Android Developer API/Play Developer Reporting API/Cloud Pub/Sub APIを有効化、サービスアカウント`revenuecat@voikerchat.iam.gserviceaccount.com`(ロール: Pub/Sub編集者+モニタリング閲覧者)を作成しPlay Consoleへ招待(アプリ情報閲覧/売上データ/注文と定期購入の管理)。RevenueCatにPlay StoreアプリをApp ID `appf7acdb482b`で追加、Productインポート成功(Published) → ③Offering/Productをマッピング ✅完了(2026-08-04)。Entitlement `Premium`にAttach(App Store版と併存)、Offering `default`の`$rc_monthly`に追加。**Entitlement識別子の大小文字厳密一致は結果的に`Premium`で確定** → ④ビルドに`REVENUECAT_ANDROID_KEY`を渡す **未着手・テスト完走後(8/14頃)まで意図的に保留**(コード側の準備は完了済み: `internal-docs/ANDROID_RELEASE.md`のビルドコマンドに`--dart-define=REVENUECAT_ANDROID_KEY=<YOUR_ANDROID_KEY>`のプレースホルダを追記済みで、実キーに置き換えるだけの状態。同ドキュメントの5-3節にPaywall/Offering取得確認手順も追加済み)。**キーだけ先行投入は禁止**(DECISIONS.md 2026-07-29)。コード側の`app_user_id`結線は確認済みで修正不要。**残作業**: Real-Time Developer Notifications接続(2026-08-06以降、RevenueCat側の認証情報反映待ち。トラック設定変更を伴わないためテスト期間中でも着手可)。担当: 人間(ダッシュボード作業)+人間(ビルド実行、④のみ完走後)。期限: RTDN接続は8/6以降、④ビルド投入は完走後(8/14頃)
- **Push通知 Phase2**(submission非必須・機能拡張・「道2」でスコープ外継続): Apple Developer Portal側のcapability有効化・プロファイル再作成は2026-07-26確認時点で既に完了済み(DECISIONS.md参照)。残る手順: APNsキー(`26PUZTM353`、.p8、Drive `00_Project_Credentials`、file ID `1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)をFirebase Console → Cloud Messagingにアップロード → PR #14(iOS APNsエンティトルメント追加、実装済み・App Store公開待ちでマージ保留中)をマージ → 実機でのプッシュ受信テスト。担当: 人間+CC。期限: 未定(App Store公開後)
- **AdMob公開後タスク**(承認状況「要審査」。ストア公開が前提のため公開後に再確認): リワード広告No Fillの再検証(公開直後は在庫が薄い場合があるため数日様子見)/ AdMobコンソールにApp Storeのストアリンクを登録 / `voikerchat.com`に`app-ads.txt`を設置 / AdMobの「準備状況」レビューを確認。担当: 人間。期限: App Store公開後
- **Android署名fail-fast**(PR #5、実装済み・マージ保留中): key.properties不在時のdebug鍵フォールバック廃止。Windows Laptopでのローカルgradle検証待ち。担当: 人間。期限: 未定
- **クロスプラットフォーム課金引き継ぎ**(着手条件付きバックログ): 匿名サインインのみのため、iOSで購入した人がAndroidで利用しても課金が引き継がれない(同一端末の再インストールは`restorePurchases()`で復元されるため実害なし)。解消にはメールログイン等の実アカウント導入が必要(登録画面追加による離脱率上昇とのトレードオフ、DECISIONS.md 2026-07-29参照)。着手条件: リリース後に「機種変更したら課金が消えた」という問い合わせが実際に発生してから判断する。担当: 未定。期限: 未定
- **音声のPrivacy開示整合**(submission必須): App Store Connectのプライバシー申告に「音声データ→Appleサーバー送信」を反映(NSSpeechRecognitionUsageDescription対応済、申告のみ)。担当: 人間。期限: 未定(1.0.0+15審査提出時点での申告状況は本ドキュメント上未確認のため要確認)
- **fil訳ネイティブレビュー**(妻に依頼) → 本番化: 既存21キー(notification_scheduler)に加え、言語切替UI(PR #8)・通知トグル(PR #11)の新規キーも機械翻訳のまま未レビュー。担当: 人間(妻)。期限: 本番化前
- **PR #20ストアコピペ反映**: PR #20本文のコピペ用テキスト(en-US/ja-JP)をGoogle Play Console/App Store Connectの該当欄に反映。担当: 人間。期限: 未定
- **release_verification_session_20260726.mdの残タスク(STEP2/STEP4/STEP5/Phase D/Phase E)**: STEP1(本番データ是正、不要と判断)・STEP3(daily_limit動作検証、実質完了)は2026-07-31に解消済み(DECISIONS.md参照)。残るSTEP2/4/5とPhase D/Eは実機での破壊的操作(アンインストール・端末日時変更)を伴い、テスター61名が稼働中に行うと結果の解釈が困難になるため、クローズドテスト完走(2026-08-14見込み)以降に実施する(検証doc自体の冒頭に方針追記済み)。担当: 人間。期限: 完走後
- **通知履歴の表示時ローカライズ改修**(任意・優先度低): 現状「配信時点の言語で保持」が仕様(DECISIONS.md 2026-07-26)。ユーザーから改善要望が出た場合のみ着手。担当: 未定。期限: 未定
- **api/*.tsのテスト基盤整備**(任意): jest/vitest等のTSテスト基盤・tsconfig.json・testスクリプトが皆無。前提としてこのMacへのNode.jsインストールも必要。改善候補「技術的負債」の`api/にtsconfig.json/lint設定が存在しない`と同一課題。担当: 未定。期限: 未定
- **シーンのお気に入り機能**(任意・条件付きバックログ): 未完成のまま放置されていたハートボタンは削除済み(DECISIONS.md 2026-07-26)。再検討条件: (a) シーン数が20を超えた段階、(b) 実装する場合は「一覧・絞り込み」までセットで設計、(c) 代替案(「最近使ったシーン」)も比較対象、(d) 判断は公開後のusage_logs(scene_idの分布)を確認してから。担当: 未定。期限: 未定
- **小タスク: G6ダイアログを権限取得済み時はスキップする改善**(任意)。担当: 未定。期限: 未定
- **本番Supabaseの検証用バックアップテーブルを削除**: 対象 `_rate_limits_daily_limit_backup_20260726` / `_rate_limits_verification_backup`。検証: `information_schema.tables`に該当テーブルが存在しないこと。2026-07-31に本番DBで存在を確認。テスト期間中は本番DB操作を避けるため保留。担当: 未定。期限: 完走後(2026-08-14以降)
- **Google Play Console 定期購入の特典テキスト修正(「Access to all 13 scenes」→18)**: 2026-08-04、シーン数記載監査でコード実装(18シーン)とストア/ドキュメント側の記載乖離を確認した際に発見。`docs/support.html`・`internal-docs/Persona-Design-v1.0.md`・`internal-docs/Onboarding-Flow-v1.0.md`・`internal-docs/Tutorial-Design-v1.0.md`・`internal-docs/T-20-Onboarding-Enhancement-v1.0.md`はリポジトリ側で18に修正済み(PR参照)だが、**Google Play Consoleの定期購入商品(`voikerchat_premium_monthly`)特典テキストの「Access to all 13 scenes」表記はストア側の設定でありコード修正の対象外**。トラック設定変更の運用ルール(本ファイル「運用ルール」節)により、クローズドテスト完走(2026-08-14頃)後に手動で修正すること。担当: 人間。期限: 2026-08-14頃(完走後)
- **AABサイズ(89.4MB)の削減検討**(一般公開前TODO): 2026-08-06、Build 18(`versionCode 18`)ビルド時点のサイズ。Play Consoleからサイズ増加の警告あり(本人報告、Claude Code未確認画面)。オンボーディング画像9枚(`assets/onboarding/`、PR #51で追加。各3〜4.5MBのPNG、合計約29MB)・音声アセットが主要因の疑い。対応候補: オンボーディング画像のWebP変換/圧縮、Android App Bundleの言語別/密度別分割(Play Asset Delivery)が機能しているかの確認。担当: 未定。期限: 一般公開前

## 運用ルール

- 2026-08-14の完走まで、Play Consoleのトラック設定を一切変更しない(テスターリスト、国/地域、リリース構成)。既存オプトインの切断リスクがあるため
- Build 16のリリースのみ例外

## 改善候補(テスト期間中〜リリース後)

### [優先: 高] 上限到達時に「次に使えるまでの残り時間」を表示

**背景**
- rate_limits.used_today のリセットは「last_reset_utc から実時間24時間経過」判定(chat.ts:207-213, rate-limit.ts:77-85)
- 一方、UIの表示は「本日の残り N/5回」「本日の上限に達しました」で、暦日リセットを想起させる
- 2026-07-30、開発者自身がこの不一致で「リセットされないのでは」と誤認する事象が発生
- ユーザーは「いつまた使えるのか」が分からず、離脱リスクがある

**改善案**
- 上限到達ダイアログおよびチャット画面下部のバーに「あと X 時間 Y 分で回復します」を表示
- 文言は ja / en / fil の3言語で用意

**実装調査が必要な項目**
1. GET /api/rate-limit のレスポンスに last_reset_utc または残り時間が含まれているか。含まれていなければレスポンス拡張が必要
2. クライアント側 RateLimitService が値を保持しているか
3. 表示箇所: 上限ダイアログ、チャット画面下部バー、その他「本日の残り」を出している全箇所を洗い出す
4. カウントダウンをリアルタイム更新するか、画面表示時のスナップショットで十分か

**対象プラットフォーム**
- Android: Build 17 で対応予定(Build 16 は A〜D で確定済み)
- **iOS: 同機能を必ず実装すること。Android のみ先行してプラットフォーム間で挙動が乖離しないよう注意**

**申請での位置づけ**
- Google Play 本番申請の設問「フィードバックに基づく改善」の回答材料として使う想定
- ただし「テスターからの指摘」と記載するには、実際にテスターから同趣旨のフィードバックを得ることが前提。開発者の気づきのみで「フィードバック起点」と書かない

### [優先: 高] usage_logs の残る記録漏れ(テスト終了後に対応)

- session_id が全箇所で未使用
- tts.ts の model が未記録(OpenAI TTS の原価が追えない)
- session_start / upsell_shown / upsell_clicked / upsell_converted を insert している箇所がゼロ。アップセル効果測定の基盤が無い
- 対応時期: クローズドテスト完走後(本番APIへの変更を避けるため)

### [優先: 中] fil(タガログ語)UI の妥当性検証

- テスターの一人がセブアノ語(ビサヤ語)で会話していることを確認(2026-07-30、Messenger のやり取りより)
- Voikerchat の fil はタガログ語ベース。ビサヤ語圏の利用者には英語UIの方が自然な可能性がある
- 検証: テスト期間中のフィードバックで「タガログ語と英語のどちらが使いやすいか」を聞く
- 結果次第で初回言語選択の既定値や説明文を見直す

### [優先: 中] 高音質TTSへの到達状況を監視(テスト期間中)

- no fill フォールバック(metadata.fallback=true)が本番で一度も発生していない(2026-07-31時点)
- テスターが「広告を見る」を押さなければ高音質TTSを体験できず、音声品質に関するフィードバックが得られない
- 監視: usage_logs で event='ad_reward' かつ metadata->>'fallback'='true' の発生を確認
- 数日発生しなければ、テスターへの案内文で「広告ボタンを1日1回押してほしい」旨を明示する

### [優先: 中] 統計のトークン集計元が二系統に分かれている

- overview.totalTokens は usage_logs.output_tokens(サーバー権威)
- sceneProgress[x].tokens は conversation_sessions.total_tokens_used(クライアント側 _updateSessionStats のベストエフォート処理、例外を握りつぶす設計)
- 2026-08-01 実機確認で 696 vs 523(差分173)の不整合を観測
- 同一画面で内訳の合計が総合計と一致しないのはユーザーから見て不可解
- 恒久対応案: usage_logs.metadata.scene を正としてシーン別集計を再実装する。ただしシーン別メッセージ数の再定義を伴う設計変更

### [優先: 中] 技術的負債

- chat.ts のリセット基準が他エンドポイントと不統一(chat.ts: 24時間ローリング / define・hint・recap・vocab-summary: UTC暦日境界)
- FREE_DAILY_DEFINE_HINT_LIMIT = 30 が define.ts / hint.ts で重複定義
- recap_service.dart / vocab_summary_service.dart に 429 分岐がなく、上限到達が「一時的な失敗」として表示される
- api/ に tsconfig.json / lint 設定が存在しない
- Vercel プロジェクトが2つ存在(voikerchat / voikerchat-x621)。**`voikerchat.com`/`www.voikerchat.com`は`voikerchat-x621`にのみ割り当て済み(2026-08-03、`vercel domains inspect`で確認)だが、pushの都度両プロジェクトへデプロイが走る構成のまま**。`voikerchat`側は`voikerchat.vercel.app`のみで本番トラフィックには使われていない。完走後に整理すべき技術的負債(不要なデプロイ・Secretsの重複等)
- `lib/screens/ai_data_consent_screen.dart`のAI同意画面オーバーフロー対策(2026-08-03発見、PR #36) → **解決済(PR #40、実機確認 2026-08-04 / Android 15、フォントサイズ最大)**。本文を`SingleChildScrollView`に、同意/非同意ボタンを`Scaffold.bottomNavigationBar`へ分離しPaywall(PR #30)と同じ方針に統一。実機(Xiaomi 23073RPBFG、Android 15、フォントサイズ最大)でレイアウト崩れが無いこと、「同意して続ける」→次画面遷移が正常動作することを確認済み。**「同意しない」ボタンの動作は未検証**(同一Column内の兄弟要素のため今回は確認を省略、DECISIONS.md参照)。iPad Air 11-inch(iOS)での確認はまだ実施していない
- Build 16(現在Androidクローズドテストで配信中のビルド)には、PR #36で新設したAIデータ利用同意画面が含まれていない(Build 16のビルド元コミットがPR #36マージより前のため、DECISIONS.md 2026-08-04参照)。**現在稼働中のAndroidテスターは同意画面を一度も経由せずアプリを利用している**。Build 18の配信で解消予定。ストアのデータセーフティ申告(App Store Guideline 5.1.1(i)/5.1.2(i)対応で追加した開示内容)との整合は**[未確認]**。製品版申請前に必ず確認すること
- linux/ macos/ windows/ の自動生成ファイルが checkout のたびに差分として出る
- lib/services/revenuecat_service.dart:5 が dart:io の Platform を kIsWeb ガードなしで参照している。web 実行時の潜在バグ(2026-07-31発見、PR #33のスコープ外として保留)
- `Documents/voikerchat`(別チェックアウト、2026-06-29時点の古い状態)の git remote URL に GitHub PAT が平文で埋め込まれている(2026-08-01にCCが発見)。対応候補: 該当PATのrevoke、不要チェックアウトの削除、fine-grained PATへの移行。現行PATはclassic/repoスコープ/有効期限なしのため漏洩時の影響が最大
- 過去のVercelデプロイURL(`*.vercel.app`、プレビュー/旧本番デプロイ分)から、`internal-docs/`分離前の旧`docs/`配下ファイルのスナップショットにアクセスできる可能性がある(2026-08-04発見、未確認)。Deployment Protectionの導入を検討
- RevenueCatダッシュボードに未使用のEntitlement `Voikerchat Pro`、Offeringの`$rc_annual`/`$rc_lifetime`が残存(2026-08-04のAndroid有効化作業中に発見。実店舗製品との紐付けなし)。完走後に整理
- voikerchat.comトップページの訴求文言とストア掲載情報の間にズレが残っている可能性(2026-08-04、未確認。次回精査対象)
- `git stash@{0}`〜`{4}`(ローカル、5件)は移植済み/ビルドノイズ。`stash@{0}`(RevenueCat Android関連の`docs/ANDROID_RELEASE.md`・`docs/STATE.md`編集)は2026-08-04に内容を`internal-docs/`側へ手動移植済みで、原本は意図的にdropせず残置(移植漏れ検証用)。`stash@{1}`〜`{4}`は`pubspec.lock`/生成済みプラグイン登録ファイルのみのビルド成果物ノイズで`docs/`とは無関係。いずれもP4完走後にまとめて整理(`git stash drop`)

## 市場・競合メモ

在日外国人向けサービスの調査で判明(2026-07-30)。B2B展開を検討する際の参照用。

- **KUROFUNE PASSPORT**(KUROFUNE株式会社): 特定技能の義務的支援10項目をアプリで管理・報告書生成するツールとして、受入企業・登録支援機関に月額課金。Google Play 1,000+ DL。B2B展開時の直接競合になりうる
- **GTN Living / GTN Assistants**(グローバルトラストネットワークス): 20か国語以上の生活相談。家賃保証・SIM利用者向けに無償提供。Google Play 1万+ DL
- 単価等は未確認。B2B検討時に各社サイトで実物確認すること

## 完了(2026-07-25〜26セッション)
- **オープンPR一式のマージ**: #3(purchases_flutter v10.4.3対応)・#4(規約類の英語版・不整合修正)・#6(AI生成コンテンツ報告機能、Google Playポリシー必須)・#7(ストア掲載文v1.3)・#8(アプリ内UI言語切替)をmainへマージ
- **チャット画面AppBarのシーン名/レベル省略修正**(PR #9): `ShrinkToFitText`ウィジェット新設
- **通知機能一式**(PR #10・#11・#12): ローカルリマインダー/マイルストーンの実接続+タイムゾーン・Android 13+権限バグ修正、設定画面ON/OFFトグル、通知履歴の書き込み(案B: 先行INSERT+起動時確定 / 案C: 即時INSERT)。実装中に`NotificationHistory`モデルの`user_id`/`is_read`列マッピング漏れ(既存バグ、`saveNotification`が今回まで一度も呼ばれておらず未発覚)も修正
- **ストリーク端末間整合性修正**(PR #13): 端末変更/再インストールでの消失、fire-and-forget同期競合を解消
- **iOS APNsエンティトルメント実装**(PR #14): `internal-docs/DECISIONS.md`記載の理由により**マージ保留**(Phase2まで)
- **AdMob広告No Fill調査**: 診断ログ追加(PR #15、ビルド`1.0.0+9`)→実機ログでcode=1(No Fill)を確認→診断ログ削除+`SKAdNetworkItems`50件追加(PR #16、ビルド`1.0.0+10`)→再検証でも改善せず→AdMobコンソール確認の結果、原因はApp Store未公開と判断(DECISIONS.md参照)
- **アプリ内言語切替時の通知再スケジュール修正**(PR #17): `_resolveLocale()`がアプリ内言語切替を考慮していなかった不具合を修正。循環import回避のため`main.dart`側でリスナー結線
- **iOSビルド番号進行**: `1.0.0+7` → `+8`(通知機能一式)→ `+9`(診断ログ)→ `+10`(SKAdNetwork対応)。いずれも`ios-release.yml`経由でApp Store Connectへアップロード成功
- **実機検証キット新設**: `internal-docs/verification/notification_verification_20260726.md`(通知トグル/履歴書き込み/ストリーク回帰/言語切替再スケジュールの統合チェックリスト)
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
