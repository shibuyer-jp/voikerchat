# STATE.md — Voikerchat 現在状態(外部メモリ)

## 運用ルール

- **セッション開始時に読む/終了時に更新してコミット**。ここが唯一の正(single source of truth)。
- **このファイルは「現在地」のみを持つ**。過去の経緯・完了済み事項の全文は持たない。都度更新・上書きする(追記専用ではない)。
- **文書の役割分担**(2026-08-13、R4で再定義):
  - `STATE.md`(本書) — 今どうなっているか・次に何をするか。現在地のみ
  - `internal-docs/DECISIONS.md` — 決定の履歴。なぜそう決めたか。追記専用・削除禁止
  - `internal-docs/ARCHIVE.md` — STATE.mdから退避した完了済み事項の全文。追記専用
  - `internal-docs/OPERATIONS-NOTES.md` — 再利用可能な運用知見・手順の罠。都度更新
  - 新規ドキュメントを作る際のルールはCLAUDE.md「internal-docsに新しいファイルを作るときのルール」を参照。`ROADMAP.md`(2026-08-07新設)がSTATE.mdと内容重複する二重管理になり2026-08-13に廃止した教訓による
- 外部サービス(Play Console / App Store Connect等)の配布状況・ステータスは、必ず実画面で確認してから記録する(Android versionCode 7の配布状況誤認が教訓。詳細はOPERATIONS-NOTES.md参照)
- 2026-08-14の完走まで、Play Consoleのトラック設定を一切変更しない(テスターリスト、国/地域、リリース構成)。既存オプトインの切断リスクがあるため。**ただし新AAB配信は例外**(14日タイマーはリセットされない、Build 16/18/21で実績あり。詳細はOPERATIONS-NOTES.md参照)

## 進行中

- **Androidクローズドテスト**: 14日タイマー進行中(起算 2026-07-30 19:31 JST)。2026-08-12時点で12日目、完走見込みは**2026-08-14前後**[確認済 2026-08-12、Play Console実画面]。Build 21(versionCode 21)の配信完了済み(2026-08-10 12:11配信)。業者依頼「テスト中にアップデートを2〜3回」はBuild 16/18/21の3回で**完全充足**。
- **iOS**: 1.0.0+20が**App Review承認 → 「Pending Developer Release」到達済み**(2026-08-10)。方針は「Androidの完走を待って同時公開」を維持、ただし2026-08-14での同時公開は成立せず具体的な公開日は未確定(詳細は未完了項目13参照)。
- **2026-08-13の一連の変更はすべてmainへマージ済み**: R1〜R4(PR #96・#97・#98・#100・#101)、usage_logsアップセル計測PR-A/PR-B(PR #102・#103)。マージ後、本番8エンドポイント(`/api/chat`・`rate-limit`・`premium-sync`・`define`・`hint`・`recap`・`vocab-summary`・`tts`・`revenuecat-webhook`)の疎通を都度確認済み、異常なし。詳細はDECISIONS.md 2026-08-13系列参照
  - PR #14(iOS APNsエンティトルメント)・PR #5(Android署名fail-fast)は上記とは無関係の長期保留PR。詳細はバックログ参照

## 未完了項目(クローズドテスト期間中に対応)

> 完了済み項目(1・2・3・4・6・7・8・9・10・11・14・15・16・17・18・19)は`internal-docs/ARCHIVE.md`「完了済み未完了項目」節へ全文移動済み(番号は維持)。

**公開前に必ず片付けるべき項目はこの3件+バックログ2件のみ**: 5(本番アクセス申請、要作業ゼロで完走待ちのみ)・12(iOS Sandbox課金検証、コードレビュー確認で代替済み、追加作業なし)・13(iOSの公開タイミング判断、Takatohの決定待ち)。加えてバックログ「本番アクセス申請までにクリアしたいこと」のASO見直し・公開日のレビュー依頼準備(いずれも2026-08-14目安)。これ以外の項目(バックログ・改善候補)はすべて公開後でよい。

5. **本番環境へのアクセス申請**
   - 担当: 人間 / 検証: 申請フォームの送信完了 / 期限: 完走確認後すみやかに
   - **申請前の要作業はゼロ**。`internal-docs/PRODUCTION_ACCESS.md`のチェックリスト・`internal-docs/PRODUCTION_ACCESS_ANSWERS.md`の回答文完成版(記述式6問、日英・標準/短縮の4パターンずつ)とも準備済み。残るはクローズドテスト完走待ちのみ
   - 経緯の全文はARCHIVE.md「完了済み未完了項目」5番、DECISIONS.md 2026-08-12系列を参照

12. **iOS Sandbox課金検証** 🚧 中間結果あり
    - 状態: 購入直後のPremiumシーン即時解除(PR #53)は、TestFlight環境では未購入状態を作れない制約により実機検証不能。**実機での直接検証は諦め、コードレビューによる確認に留める方針**(Androidで同一症状が再現しPR #53で修正済み、iOS +17でも同一症状を確認済みのため、プラットフォーム固有の問題ではないことは確定している)
    - 残るリスク: 実際の購入イベントでのみ踏める経路のため、公開後にテスターからの同種報告が無いか監視で代替する
    - 担当: 人間。期限: iOS公開前(未完了項目13の判断待ち)
    - 経緯の全文はARCHIVE.md「完了済み未完了項目」12番、`internal-docs/reports/premium_unlock_investigation_20260805.md`を参照

13. **iOSの公開タイミング判断** 🟡 公開日程は未確定
    - 状態: 1.0.0+20は「Pending Developer Release」到達済み(2026-08-10)。**「Androidの完走を待って同時公開」方針を維持**
    - **2026-08-14での同時公開は成立しない**: Androidの製品版アクセス申請はクローズドテスト完走後に提出、審査は通常7日以内のため、Android一般公開は**2026-08-21〜25頃**の見込み
    - **未確定のまま残る点**: 「iOSのみ先行して8/14頃に公開する」か「Androidの製品版承認(8/21〜25頃)まで待つ」か
    - 担当: 人間。期限: 未確定
    - 経緯の全文はARCHIVE.md「完了済み未完了項目」13番を参照

## 直近の変更(最新1件のみ。過去分はDECISIONS.md参照)

**2026-08-13**: R1(GitHub PAT平文埋め込み、削除・全リポジトリ走査を実施のうえ「PATの新規発行・差し替え・revokeは実施しない」とTakatohが判断)・R2(`api/revenuecat-webhook.ts`へのusage_logs監査ログ追加)・R3(`api/tsconfig.json`新設・型チェックCI導入、`strict: true`まで到達、premium-sync.tsの既存Supabase型エラー6件を解消)・R4(internal-docs再編、STATE.mdを126,151→20,531 bytesへ圧縮、`internal-docs/ARCHIVE.md`・`internal-docs/OPERATIONS-NOTES.md`を新設、`ROADMAP.md`を廃止しSTATE.mdへ一本化)・package-lock.jsonのコミット(依存バージョン固定)・usage_logsアップセルファネル計測基盤(PR-A: session_start/upsell_shown/upsell_clicked/upsell_converted、PR-B: 6エンドポイントへのsession_id配線+tts.tsのmodel記録)を実施し、いずれもmainへマージ済み。詳細はDECISIONS.md 2026-08-13系列参照。

## 確定定数(変更時はDECISIONSに記録)
- App: Voikerchat / `jp.shibuyer.voikerchat` / voikerchat.com(Dynadot) / Team ID `S6XJP274T2`
- Supabaseプロジェクト: ref `rfwbwwhqclabhnbsrygw`(Tokyo)。表示名`voikerchat-prod`(2026-08-01確認。旧称"Japanese-learning-app"という記載は古い)
- Vercelプロジェクト: `voikerchat-x621`(env: SUPABASE_URL / SUPABASE_SERVICE_KEY=service_role / ANTHROPIC_API_KEY)
- APIエンドポイント(api/): chat / rate-limit / analytics / revenuecat-webhook / delete-account
- フリーミアム: 無料5回/日(広告+5、最大10、当日限り)/ プレミアム$12.99月(50回/日・全18シーン・広告なし)。値の唯一の定義元は`api/_constants.ts`(サーバー)/`lib/constants/rate_limit_constants.dart`(クライアントfallback)。シーン数はT-34で13→18に拡張済み(基本8+アニメ5+実用5、`lib/services/scene_service.dart`)
- サポート: voikerchat.support@gmail.com(forward→takatoh01@gmail.com)。kizunavi.support は非運用 / APNs `.p8`: Drive `00_Project_Credentials`(`1mqUWxB3VYrkVcGHCWayXJtIDrXlGBHjM`)
- 設計書: repo `internal-docs/` の Persona/Tutorial/Onboarding-Design(参照のみ・再生成禁止)
- RevenueCat: App ID(Android) `appf7acdb482b` / Product `voikerchat_premium_monthly:monthly-autorenew` / Entitlement `Premium`(iOS/Android併存) / Offering `default`(2026-08-04設定完了)

## 機能ステータス

| 機能 | 状態 | 備考 |
|------|------|------|
| 認証・チャット・usage_logs・analytics/rate-limit認証統一・Supabaseエラーログ化・i18n(通知/premium文言)・通知機能一式・ストリーク(端末間整合性・リセット実装)・アプリ内UI言語切替・チャット画面AppBar省略修正・アカウント削除・badges・音声会話(PTT+TTS)・lefthook pre-push | ✅ 完了・main反映・安定稼働 | 実装経緯・PR番号はARCHIVE.md「STATE.md全文バックアップ」の旧「機能ステータス」表を参照 |
| プレミアム(RevenueCat) | ✅ 配線済み | webhook→`rate_limits.is_premium`。CANCELLATIONは降格せず、EXPIRATION・返金(cancel_reason=CUSTOMER_SUPPORT)のみ降格(PR #89、2026-08-12マージ)。監査ログ追加はPR #97(2026-08-13マージ済み) |
| daily_limit日次リセット漏れ修正・ストア掲載文数値非依存化・プレミアム案内文数値除去・Paywall文言監査/価格表示/フッター化/購読ボタン制御・Androidクローズドテスト配布(Build 16/18/21)・Google Play価格引き下げ・AI生成コンテンツポリシー遵守 | ✅ 完了・main反映 | 詳細はARCHIVE.md参照 |
| プッシュ通知 | 🚧 Phase2へ先送り(「道2」決定) | 受信側コードは維持、自動送信基盤の新規構築・APNs追加対応は今回リリースでは行わない。PR #14(iOS APNsエンティトルメント)は実装済み・マージ保留 |
| AdMobリワード広告 | ✅ コード完了・実ID設定済み / ⚠️ No Fill継続 | 原因はApp Store未公開と判断(DECISIONS.md 2026-07-26)。公開後に再検証(バックログ参照) |
| fil訳ネイティブレビュー | 📋 未 | 本番化前必須から公開後の改善候補へ格下げ(2026-08-07、Takatoh判断) |

## バックログ(テスト完走後)

下記「運用ルール」によりPlay Consoleのトラック設定を変更できないため、着手はテスト完走(2026-08-14目安)後。1項目3行以内に圧縮。詳細な経緯はDECISIONS.mdまたは`internal-docs/reports/`配下の個別レポートを参照。

**本番アクセス申請までにクリアしたいこと(2026-08-14目安、ROADMAP.md区分2より移行)**
- **ストア掲載情報の見直し(ASO)**: フィリピン人学習者が実際に検索する語(Japanese / Nihongo / Tagalog等)がタイトル・短い説明に入っているか確認。`internal-docs/GROWTH_PLAN.md`参照。担当: 人間。期限: 2026-08-14目安
- **公開日のレビュー依頼準備**: 配偶者経由の実テスター(16名)へ、公開日にレビュー投稿を依頼できるよう事前に声をかけておく。公開日確定後に実施。`internal-docs/GROWTH_PLAN.md`参照。担当: 人間

**運用・技術(公開前後)**
- 返金分岐の発火監視: `cancel_reason='CUSTOMER_SUPPORT'`が返金を伴わない解約で誤発火しないか、公開後に問い合わせ有無を注視。担当: 人間。期限: 一般公開後
- Push通知Phase2: APNsキーのFirebaseアップロード→PR #14マージ→実機テスト。担当: 人間+CC。期限: 未定(App Store公開後)
- AdMob公開後タスク: No Fill再検証・app-ads.txt設置・ストアリンク登録・AdMob準備状況レビュー確認。担当: 人間。期限: App Store公開後
- Android署名fail-fast(PR #5、実装済み・マージ保留): Windows Laptopでのローカルgradle検証待ち。担当: 人間
- 音声のPrivacy開示整合: App Store Connectのプライバシー申告に音声データ送信を反映(NSSpeechRecognitionUsageDescription対応済み、申告のみ要確認)。担当: 人間
- PR #20ストアコピペ反映: Google Play Console/App Store Connectの該当欄へ反映。担当: 人間
- release_verification_session_20260726.mdの残タスク(STEP2/4/5、Phase D/E): 実機での破壊的操作を伴うため完走後に実施。担当: 人間
- api/*.tsのテスト基盤整備: jest/vitest等のユニットテスト基盤(型チェックはR3で別途解消済み、本項目は別軸)。担当: 未定
- 本番Supabaseの検証用バックアップテーブル削除(`_rate_limits_daily_limit_backup_20260726` / `_rate_limits_verification_backup`)。担当: 未定。期限: 完走後
- 通知履歴の既存DB行クリーンアップ(is_read=true/status='scheduled'の残存3件、影響軽微)。担当: 未定
- 通知履歴の表示時ローカライズ改修(現状「配信時点の言語で保持」が仕様)。ユーザー要望があれば着手。担当: 未定
- 小タスク: G6ダイアログを権限取得済み時はスキップする改善(任意)。担当: 未定
- git stash@{0}〜{4}の整理(移植済み/ビルドノイズ、完走後にまとめて`git stash drop`)。担当: 未定
- Vercelプロジェクト2重(voikerchat / voikerchat-x621)の整理。完走後。担当: 未定
- RevenueCatダッシュボード未使用Entitlement`Voikerchat Pro`・Offering `$rc_annual`/`$rc_lifetime`の整理。担当: 未定
- voikerchat.comトップページの訴求文言とストア掲載情報のズレ(未確認、次回精査対象)。担当: 未定
- 旧Vercelデプロイ(`*.vercel.app`個別URL)の`internal-docs/`分離前スナップショット露出懸念(プレビュードメインは認証保護済み、個別URLは未確認)。担当: 未定

**製品機能(公開後、ROADMAP.md区分4より移行・Competitor-Insights.md 2026-08-10追補由来)**
- 年額プラン追加[優先: 高、公開後の収益改善の筆頭]: RevenueCatに`$rc_annual`追加、両ストア登録、Paywall2プラン対応。競合が年額主力(月換算2,316〜2,367円、LingoDeerは月額₱999に対し年額₱5,990=月換算₱499)なのに対しVoikerchatは月額単体提示のみで、月額単体提示ではコンバージョン率が著しく低いと推測される[未検証]。RevenueCat側に未使用の`$rc_annual`/`$rc_lifetime`が既に存在するため受け皿はある(下記技術的負債「RevenueCatダッシュボードに未使用のEntitlement」と関連)。実施にはPlay Console/App Store Connect双方の商品追加とPaywall UI改修(新ビルド)が必要なため公開前には着手しない。着手時期: 公開直後。担当: 未定。期限: 一般公開後(2026-08-13追記)
- 学習スコアの可視化[優先: 高]: 会話数・連続日数・使用語彙数など、追加AI呼び出し無しで実装できる範囲から着手(トークンコストゼロ)。着手時期: 公開直後。担当: 未定
- 無料トライアル(全機能開放)[優先: 中]: 初回3日間など短めから試し実績を見て延長判断。トークンコスト増に注意。着手時期: 公開後、運用が落ち着いてから。担当: 未定
- ユーザー定義シーン[優先: 中]: プロンプト長増によるキャッシュ効率低下、ユーザー入力の不適切設定対策が必須。着手時期: 公開後。担当: 未定
- 在日フィリピン人向け実用シーン追加[優先: 中]: 役所手続き・病院受付・職場報連相・ゴミ出し・学校連絡・介護申し送り。着手時期: 公開後。担当: 未定
- Google Play対象年齢層の13〜17歳への拡大検討[優先: 低]: 現行の未成年制限チェックを外す案。外すと保護者同意条項の実効性が失われるリスク・年齢確認画面実装が必要になる可能性あり。着手条件: 学生層の実需要確認後。担当: 未定

## 改善候補(テスト期間中〜リリース後)

### [優先: 高]
- 上限到達時に「次に使えるまでの残り時間」を表示。GET /api/rate-limitのレスポンス拡張要否から調査。iOS/Android両対応必須。担当: 未定
- ~~usage_logsの残る記録漏れ~~ → **解消(2026-08-13)**: session_id全箇所未使用→6エンドポイント(chat/define/hint/recap/vocab-summary/tts)に配線(PR-B)。tts.tsのmodel未記録→`gpt-4o-mini-tts`を記録(PR-B)。session_start/upsell_shown/upsell_clicked/upsell_converted のinsertがゼロ→`lib/services/analytics_service.dart`新設で計測基盤を追加(PR-A)。マイグレーションはいずれも不要(既存の8値CHECK制約・既存列を使用)。詳細はDECISIONS.md 2026-08-13参照

### [優先: 中]
- fil(タガログ語)UIの妥当性検証: テスターにセブアノ語話者を確認済み。フィードバックで使いやすさを確認。担当: 未定
- 高音質TTSへの到達状況を監視: `event='ad_reward' AND metadata->>'fallback'='true'`の発生有無。担当: 未定
- 統計のトークン集計元が二系統(usage_logs.output_tokens vs conversation_sessions.total_tokens_used)に分かれ不整合の実例あり。恒久対応はusage_logs.metadata.sceneを正とする再実装。担当: 未定
- シーン数変更時、Play Console定期購入の特典テキストは手動更新が必要な箇所として残り続ける(コード側は数字非依存化済み)。次回シーン数変更時に横断確認。担当: 未定
- `usage_logs.scene_id`のCHECK制約が実装のシーン数(18)と不一致(`CHECK 1〜13`のまま)。現状`chat.ts`はこの列に書き込まないため実害なし。列を使い始める前にマイグレーションが必要。担当: 未定
- chat.tsのリセット基準が他エンドポイントと不統一(24時間ローリング vs UTC暦日境界)。担当: 未定
- FREE_DAILY_DEFINE_HINT_LIMIT = 30がdefine.ts/hint.tsで重複定義。担当: 未定
- recap_service.dart/vocab_summary_service.dartに429分岐がなく上限到達が「一時的な失敗」表示になる。担当: 未定
- `npm install`時に`@supabase/supabase-js`等がNode 22以上を要求する`EBADENGINE`警告(2026-08-13、R3で発見)。ビルド自体は失敗せず実害なし。Node 18サポートが切れる/依存更新のタイミングで対応。担当: 未定
- Vercelプロジェクト2重・RevenueCat未使用Entitlement整理は上記バックログ参照
- GitHub PAT平文埋め込み(2026-08-01発見)は**判断のうえ据え置き**(2026-08-13): 削除・全リポジトリ走査は完了、PAT差し替え・revokeは実施しないとTakatohが判断(平文の露出範囲が本人PC/OneDrive限定・漏洩形跡ゼロのため)。**再検討トリガー: 将来PATを第三者と共有する場面が生じた時点**。詳細はDECISIONS.md 2026-08-13参照
- linux/macos/windowsの自動生成ファイルがcheckoutのたびに差分として出る。担当: 未定
- `lib/services/revenuecat_service.dart:5`がdart:ioのPlatformをkIsWebガードなしで参照(web実行時の潜在バグ、2026-07-31発見)。担当: 未定
- プライバシーポリシーの節番号が欠番(日英とも12を飛ばして13へ、2026-08-10発見)。次回法務文書改訂時にあわせて解消検討。担当: 未定

### [優先: 低]
- AABサイズの削減(オンボーディング画像の解像度縮小+WebP変換): Play Console実測42.4MB・警告なしのため公開ブロッカーではない。インストール離脱率改善が目的。担当: 未定
- iOS MinimumOSVersionの引き上げ(13.0→15.0以上): Apple公式期限は2027年春。担当: 未定
- シーンのお気に入り機能: 再検討条件はシーン数20超え・「最近使ったシーン」との比較・usage_logs(scene_id分布)確認後。担当: 未定
- AI応答の英訳表示(タップ方式): 無料枠引き上げでQ3不満が解消したため一旦様子見。同種要望が再度出たら着手。担当: 未定
- オフライン起動時間のさらなる短縮: PR #59適用後も実測約15秒(目標8秒)。Wave 2の直列待ちを再調査。担当: 未定

## 市場・競合メモ

在日外国人向けサービスの調査で判明(2026-07-30)。B2B展開を検討する際の参照用。

- **KUROFUNE PASSPORT**(KUROFUNE株式会社): 特定技能の義務的支援10項目をアプリで管理・報告書生成、受入企業・登録支援機関に月額課金。Google Play 1,000+ DL。B2B展開時の直接競合になりうる
- **GTN Living / GTN Assistants**(グローバルトラストネットワークス): 20か国語以上の生活相談。家賃保証・SIM利用者向けに無償提供。Google Play 1万+ DL
- 単価等は未確認。B2B検討時に各社サイトで実物確認すること
- **育成就労制度(2027年開始見込み)**: 雇用主に日本語教育の実施が義務付けられる新制度。Takatohの収益戦略方針(B2Cは通過点、本命はB2B)の延長線上にある具体的なB2B機会。制度の詳細・時期は要継続ウォッチ

## 関連ドキュメント一覧

- `internal-docs/DECISIONS.md` — 決定の履歴(追記専用)
- `internal-docs/ARCHIVE.md` — 完了済み事項の全文アーカイブ(追記専用)
- `internal-docs/OPERATIONS-NOTES.md` — 再利用可能な運用知見・手順の罠
- `internal-docs/PRODUCTION_ACCESS.md` / `PRODUCTION_ACCESS_ANSWERS.md` — 製品版アクセス申請のチェックリスト・回答文完成版
- `internal-docs/TESTER-FEEDBACK.md` — テスターフィードバック記録
- `internal-docs/GROWTH_PLAN.md` / `Competitor-Insights.md` — 成長戦略・競合調査
- `internal-docs/reports/` — 個別調査レポート(iOS/Android/RevenueCat/AI生成コンテンツポリシー等)
- `internal-docs/verification/` — 実機検証手順・記録
- `internal-docs/migrations/` — Supabase SQLマイグレーション
- `internal-docs/IOS_RESUBMISSION_20260807.md` / `IOS_REJECTION_PLAYBOOK.md` / `ANDROID_RELEASE.md` — リリース手順書
