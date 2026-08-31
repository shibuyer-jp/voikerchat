# INDEX.md — ドキュメント索引(voikerchat / shibuyer-ops 横断、2026-08-17新設)

**このファイルが持つ情報**: 「どのファイルに何が書いてあるか」の唯一の地図。
`voikerchat`(このリポジトリ)と `shibuyer-ops`(運用リポジトリ)の両方を対象に、
ファイルの実体ではなく**所在**を管理する。個別ファイルの内容そのものは持たない
(内容を書けばSTATE.md/DECISIONS.mdとの二重管理になるため)。

**STATE.md / DECISIONS.mdとの境界**: STATE.mdは「今どうなっているか」、
DECISIONS.mdは「なぜそう決めたか」を持つ。本ファイルはそのどちらでもなく、
「それはどこに書いてあるか」だけを持つ。3ファイルはいずれも他の2つの代わりに
ならない。

**更新タイミングと担当**: 新規mdファイルを`internal-docs/`配下または
`shibuyer-ops/`配下(voikerchat関連)に追加・削除・大幅な用途変更をした
コミットと**同一PR内**で本ファイルを更新する。担当はCC(Claude Code、
CLAUDE.md「Claude(チャット)とCC の分担ルール」参照)。棚卸し(全件見直し)は
`internal-docs/`のmdファイル数が前回棚卸し時から+10件増えた時点、または
半年ごとのいずれか早い方で実施する(次回目安: 2027-02、または77件到達時)。

**凡例**(追記専用か否か列):
- **追記専用**: 既存行の削除・書き換え禁止。新しい内容は末尾に足す
- **固定**: 特定時点の記録として完成しており、以後は原則編集しない(誤り訂正のみ追記で対応)
- **都度更新**: 現在地・現在の方針を保持するファイルで、上書き更新が正しい運用
- **追記型**: 都度更新ではないが、新しいエントリを継続的に足していく(ログ的)運用

---

## 今の状態を知りたい

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/STATE.md` | 現在状態の唯一の正(single source of truth)。**やることリスト(バックログ)の唯一の置き場でもある**(2026-08-17、書式はCLAUDE.md「バックログ項目の書式ルール」参照)。セッション開始時に必ず読む | 都度更新 |
| `internal-docs/TRIGGERS.md` | イベント駆動の実行リスト。「何が起きたら何をするか」のみを持つ(日付駆動のSTATE.mdバックログとは排他的に使い分け、2026-08-17新設)。セッション開始時にSTATE.mdと合わせて必ず読む | 都度更新(実行後は該当節を削除しDECISIONS.mdへ記録) |
| `internal-docs/DECISIONS.md` | 決定の履歴(「いつ・何を・なぜ」) | 追記専用 |
| `internal-docs/ARCHIVE.md` | STATE.mdから退避した完了済み事項の全文 | 追記専用 |
| `internal-docs/tasks/PROGRESS.md` | Phase A品質ゲートのタスク進捗台帳(現在地の唯一の真実、STATE.mdとは別軸) | 都度更新 |

## 過去の決定とその理由を知りたい

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/DECISIONS.md` | 決定記録本体。`日付 \| 決定 \| 理由`形式 | 追記専用 |
| `internal-docs/ARCHIVE.md` | 完了済み未完了項目・旧ROADMAP.md全文などの凍結スナップショットを含む | 追記専用 |
| `shibuyer-ops/DECISION_RULES.md` | Fable(Opus級)との対話で確立した判断パターン集(Voikerchat固有ではなく全社横断) | 都度更新 |

## リリース手順を知りたい(Android / iOS)

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/ANDROID_RELEASE.md` | Androidリリースビルド手順書(全工程手動、Windows Laptop) | 都度更新 |
| `internal-docs/runbooks/screenshot_capture_20260901.md` | ストア掲載スクリーンショット英語UI撮り直しの実行手順書(2026-09-01 出先セッション用。単独完走チェックリスト形式) | 固定(セッション後に実施記録を追記) |
| `internal-docs/PRODUCTION_ACCESS.md` | Google Play製品版アクセス申請の手順書 | 都度更新 |
| `internal-docs/PRODUCTION_ACCESS_ANSWERS.md` | 製品版アクセス申請の回答文(提出用完成版) | 固定(提出後は経緯参照用) |
| `internal-docs/IOS_RESUBMISSION_20260807.md` | iOS再提出手順(2026-08-07実施記録) | 固定 |
| `internal-docs/IOS_REJECTION_PLAYBOOK.md` | App Storeリジェクト時の初動プレイブック | 都度更新 |
| `internal-docs/DEPLOYMENT-GUIDE.md` | Vercelデプロイガイド(Folder Structure等) | 都度更新 |
| `internal-docs/GitHub-Push-Automation.md` | GitHub push標準手順(GCM経由)。PAT直書き方式は使用禁止と明記済み | 都度更新 |
| `internal-docs/Firebase-FCM-Setup-Guide.md` | Firebase Cloud Messagingセットアップ手順 | 都度更新 |
| `internal-docs/Release-Notes-Build16.md` | Build16のリリースノート文面(テスター向け表示文の書式サンプル) | 固定(特定ビルドの記録) |
| `shibuyer-ops/skills/android-play-console-registration.md` | Play Consoleパッケージ名登録の手順書(スキル) | 都度更新 |
| `shibuyer-ops/skills/ios-appstore-release.md` | App Store提出の手順書(スキル) | 都度更新 |
| `shibuyer-ops/skills/ios-submission.md` | iOS submission関連の手順書(スキル) | 都度更新 |
| `shibuyer-ops/skills/device-testing.md` | 実機テストの手順書(スキル) | 都度更新 |

## ストア掲載文・申請回答・外部へ送る文面を探している

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/Store-Listing-Copy-v1.5.md` | **ストア掲載文の唯一の正(2026-08-17〜)**。アプリ名・短い説明・App Storeサブタイトル/キーワード等 | 固定(確定版。改版時はv1.6を新設) |
| `internal-docs/Store-Listing-Copy-v1.4.md` | 旧版。冒頭に廃止告知あり。経緯参照用のみ、正として使わない | 固定 |
| `internal-docs/Store-Listing-Copy-v1.2.md` | さらに旧版。経緯参照用 | 固定 |
| `internal-docs/Store-Listing-Copy-v1.1.md` | 最初の方針ドラフト版。経緯参照用 | 固定 |
| `internal-docs/PRODUCTION_ACCESS_ANSWERS.md` | 製品版アクセス申請の回答文(上記「リリース手順」に重複掲載) | 固定 |
| `internal-docs/Release-Notes-Build16.md` | テスター向けリリースノート文面(上記「リリース手順」に重複掲載) | 固定 |
| `shibuyer-ops/templates/voikerchat_launch_outreach_kit_v1.0.md` | 公開時のレビュー依頼文・新規学習者向け紹介文(2026-08-17作成) | 固定(必要なら改版) |
| `shibuyer-ops/templates/voikerchat_tester_recruitment_kit.md` | クローズドテストのテスター募集文面(ja/en/tl)。上記outreach kitとは目的が異なる(募集 vs 公開後案内) | 固定(必要なら改版) |
| `shibuyer-ops/design/Voikerchat-AppStore-Metadata-v0.1.md` | ⚠️**廃止・古い(2026-07-11時点のドラフト)。`Store-Listing-Copy-v1.5.md`に置き換え済みであり、この内容を正として使わないこと**(本タスクの調査で発見。二重管理の実例) | 固定(要棚卸し・廃止告知の追加を推奨) |

## 調査レポート・検証記録を探している

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/reports/aab_size_investigation_20260807.md` | AABサイズ(89.4MB)の調査 | 固定 |
| `internal-docs/reports/ai_generated_content_policy_20260807.md` | Google Play AI生成コンテンツポリシー遵守確認 | 固定 |
| `internal-docs/reports/google_play_target_audience_20260807.md` | 「ターゲットユーザーとコンテンツ」申告の調査 | 固定 |
| `internal-docs/reports/ios_build17_vs_18_risk_20260807.md` | iOS Build 17 vs main 公開リスク評価 | 固定 |
| `internal-docs/reports/onboarding_audit_20260805.md` | オンボーディングと機能の発見可能性の調査 | 固定 |
| `internal-docs/reports/premium_state_mismatch_20260807.md` | Premium判定の不整合調査 | 固定 |
| `internal-docs/reports/premium_unlock_investigation_20260805.md` | Premiumシーンロック解除不具合の調査(PR #53着手前) | 固定 |
| `internal-docs/reports/revenuecat_rtdn_investigation_20260807.md` | RevenueCat RTDN接続の調査 | 固定(2026-08-10追記あり) |
| `internal-docs/reports/website_copy_audit_20260828.md` | voikerchat.comトップページ訴求文言とストア掲載情報の突き合わせ | 固定 |
| `internal-docs/verification/daily_limit_reset_verification_20260726.md` | daily_limit日次リセットの実地検証手順・記録 | 固定 |
| `internal-docs/verification/ios_build20_verification_20260807.md` | iOS 1.0.0+20 実機検証手順 | 固定 |
| `internal-docs/verification/notification_verification_20260726.md` | 通知機能実機検証キット(後継: release_verification_session) | 固定 |
| `internal-docs/verification/release_verification_session_20260726.md` | リリース前統合実機検証セッション | 固定 |
| `internal-docs/Rls-Messages-Contradiction-Investigation.md` | messagesテーブルのRLS矛盾調査 | 固定 |
| `internal-docs/Rls-Policy-Coverage-Audit.md` | RLSポリシー欠如の横断チェック(notification_history DELETEポリシー欠如が発端) | 固定 |

## DB スキーマ・SQL を探している

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/Database-Schema-v1.0.md` | Voikerchat DBスキーマ定義(Supabase PostgreSQL) | 都度更新 |
| `internal-docs/migrations/` | Supabase SQLマイグレーション本体(9ファイル、日付プレフィックス) | 追記型(新規ファイルを追加) |
| `internal-docs/Token-Cost-Queries.md` | トークンコスト集計SQL(採算判断用) | 都度更新(クエリ追加) |
| `internal-docs/Kaigotalk-Data-Queries.md` | Kaigotalk向け集計クエリ(介護・医療シーンの需要仮説検証) | 固定 |

## 事業計画・成長戦略・競合情報を探している

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/GROWTH_PLAN.md` | 販促方針・ASO方針(唯一の正)。確定文字列自体はStore-Listing-Copy-v1.5.mdへ委譲 | 都度更新 |
| `internal-docs/Competitor-Insights.md` | 競合AI会話アプリ分析 | 都度追補 |
| `internal-docs/PH-Regional-Pricing-202607.md` | フィリピン地域価格の検討 | 固定 |
| `internal-docs/Release-Master-Plan-v2.0.md` | 製品版リリース前の品質改善6項目を反映した設計図(Phase A品質ゲートの元計画) | 固定(完了済み計画) |
| `shibuyer-ops/README.md` | Shibuyer事業設計図v1.0(全プロジェクト横断の北極星) | 都度更新 |
| `shibuyer-ops/WEEKLY_PLAN_2026Q3.md` | 週次管理プラン(全プロジェクト横断、Voikerchat以外のタスクも含む) | 都度更新 |
| `shibuyer-ops/sns_playbook.md` | SNSショート動画運用プレイブック。**Tokyo Bible向けで前提が異なり、Voikerchatにはそのまま流用不可**(GROWTH_PLAN.md参照) | 固定 |

## 運用ノウハウ・過去の罠を知りたい

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/OPERATIONS-NOTES.md` | 再利用可能な運用知見・手順の罠・ハマりどころ | 都度更新 |
| `internal-docs/Premium-Purchase-Error-Handling.md` | サブスクリプション購買フローのエラーハンドリング仕様 | 都度更新 |
| `internal-docs/TESTER-FEEDBACK.md` | テスターフィードバックの記録(日付・内容・対応方針) | 追記型 |
| `shibuyer-ops/skills/git-ops.md` | Git運用の手順書(スキル) | 都度更新 |
| `shibuyer-ops/skills/handoff-writing.md` | 引き継ぎMDの書き方(スキル) | 都度更新 |
| `shibuyer-ops/skills/harmone-ops.md` | Harmoneプロジェクトの運用手順(Voikerchat以外) | 都度更新 |
| `shibuyer-ops/skills/nexus-radar-ops.md` | NEXUS Radarプロジェクトの運用手順(Voikerchat以外) | 都度更新 |
| `shibuyer-ops/skills/README.md` | skills/配下の運用ルール(作業前に該当スキルを読む) | 都度更新 |
| `shibuyer-ops/MODEL_WORKFLOW.md` | モデル分担フロー(どのモデルに何を振るか、全社横断) | 都度更新 |

## 設計書・仕様書(実装済み機能の参照用・再生成禁止)

CLAUDE.md「設計書: repo `internal-docs/` の Persona/Tutorial/Onboarding-Design」に対応。実装は完了済みで、これらは事後の参照専用。

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/Persona-Design-v1.0.md` | AIキャラクターのペルソナ定義 | 固定 |
| `internal-docs/Tutorial-Design-v1.0.md` | チュートリアル詳細設計 | 固定 |
| `internal-docs/Onboarding-Flow-v1.0.md` | オンボーディングフロー詳細設計 | 固定 |
| `internal-docs/Voice-Integration-Contract-v1.1.md` | 音声実装統合契約書 | 固定 |
| `internal-docs/T-20-Onboarding-Enhancement-v1.0.md` | T-20タスク仕様(オンボーディング強化) | 固定 |
| `internal-docs/T-21-Notification-System-v1.0.md` | T-21タスク仕様(通知システム) | 固定 |

## タスク管理(Phase A 品質ゲート)

CLAUDE.md「Phase A 品質ゲート」節に対応。着手前に`tasks/RUNBOOK.md`を読むこと。

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/tasks/RUNBOOK.md` | Claude Code自走運用の規約 | 都度更新 |
| `internal-docs/tasks/PROGRESS.md` | タスク進捗台帳(唯一の真実、上表にも掲載) | 都度更新 |
| `internal-docs/tasks/T-30_brand-theme.md` | T-30個別タスク仕様(ブランドカラー・テーマ刷新) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-31_word-lookup.md` | T-31個別タスク仕様(単語タップ辞書機能) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-32_character-images.md` | T-32個別タスク仕様(シーンカードのキャラクター画像) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-33_premium-paywall.md` | T-33個別タスク仕様(プレミアム購入フロー/ペイウォール) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-34_premium-pro-scenes.md` | T-34個別タスク仕様(プレミアム専門シーン5本+Kaigotalkデータ設計) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-35_premium-tts.md` | T-35個別タスク仕様(高品質TTS導入) | 固定(完了後は実装が正) |
| `internal-docs/tasks/T-36_learner-support-carryover.md` | T-36個別タスク仕様(Web版学習サポート機能の移植) | 固定(完了後は実装が正) |
| `internal-docs/tasks/BACKLOG-Phase2.md` | Phase 2(リリース後)候補と出典トレーサビリティ(Web版→Flutter移行での機能漏れ防止台帳)。**STATE.mdのやることリストとは目的が異なり統合していない**(2026-08-17精査、機能候補の出典管理 vs 運用・リリースタスク管理で重複なしと判断) | 都度更新 |
| `internal-docs/tasks/GEMINI-DELEGATION.md` | Gemini分担タスク(トークン余剰の活用) | 都度更新 |

## 過去のスレッド引き継ぎ(歴史的記録・2026-06〜07)

現行の引き継ぎ運用はCLAUDE.md「Claude と CC の分担ルール」節を参照。以下は移行前の旧形式の記録で、内容は当時のスナップショットとして正しいが、現在の運用手順としては参照しない。

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `internal-docs/HANDOFF_2026-06-30_badges_admob.md` | バッジ機能・AdMob基盤完了時点の引き継ぎ | 固定 |
| `internal-docs/HANDOFF_anon-auth_chat-e2e_2026-06-30.md` | 匿名認証マージ+チャットE2E疎通時点の引き継ぎ | 固定 |
| `internal-docs/HANDOFF_T21_Complete_2026-06-23.md` | T-21完全完了時点の引き継ぎ | 固定 |
| `internal-docs/HANDOFF_T21_Phase3B_2026-06-23.md` | T-21 Phase 3B完了時点の引き継ぎ | 固定 |
| `internal-docs/HANDOFF_T21_Phase4A_2026-06-23.md` | T-21 Phase 4A完了時点の引き継ぎ | 固定 |
| `internal-docs/THREAD_HANDOFF_T21_Phase2_Prep_2026-06-24.md` | T-21 Phase 2準備完了時点の引き継ぎ | 固定 |
| `internal-docs/THREAD-HANDOFF_2026-06-23.md` | T-20完了スレッドの引き継ぎ | 固定 |
| `internal-docs/THREAD-HANDOFF_T-21_2026-06-23.md` | T-21 Phase 1-2完成時点の引き継ぎ | 固定 |

対応する`shibuyer-ops`側の引き継ぎ記録(Voikerchat以外の話題も混在する全社横断のセッションhandoff):

| パス | 説明 | 追記専用か否か |
|---|---|---|
| `shibuyer-ops/memory/README.md` | **2026-08-17に運用廃止**。2026-08-07以前のセッションhandoff記録として保存。新規追加はしない(セッション記録は`voikerchat/internal-docs/STATE.md`/`DECISIONS.md`へ一本化) | 固定 |
| `shibuyer-ops/memory/handoff_*.md`(2026-07-11〜2026-08-07、約30件) | セッションhandoff。ファイル名の日付・連番で検索する。**2026-08-17廃止、新規追加なし**(上記README.md参照) | 固定 |
| `shibuyer-ops/memory/archive/handoff_*.md`(2026-07-05〜10、23件) | 上記のうち古いものをarchiveへ移動済み | 固定 |
| `shibuyer-ops/memory/gtm_decisions_20260713.md` / `gtm_decisions_20260715.md` | GTM関連の決定ログ | 固定 |
| `shibuyer-ops/memory/ios_screenshot_procedure_20260716.md` | iOSスクリーンショット撮影手順のメモ | 固定 |
| `shibuyer-ops/memory/play_console_fixes_20260714.md` | Play Console関連の修正メモ | 固定 |

## 未分類・要棚卸し

分類先が明確でない、または内容の現在性が確認できていないファイル。**隠さず可視化する**(このタスクの目的に基づく)。次回棚卸し時に判断すること。

| パス | 未分類とする理由 |
|---|---|
| `internal-docs/chat_screen_integration_patch.md` | `ChatScreen`への統合コードパッチが素のテキストで置かれているのみ。既に適用済みのコードなのか、未適用の提案なのか、本タスクの調査時点では判別できなかった |
| `internal-docs/masterplan.md` | 「渋谷特化・訪日外国人向けビジネス+フィリピン国際結婚相談マスタープラン」。**Voikerchat単体の範囲を超えた全社横断の構想**であり、このリポジトリに置かれている理由・現在の有効性が本タスクの調査時点では確認できなかった。`shibuyer-ops/README.md`(事業設計図)との役割分担が不明瞭 |
| `shibuyer-ops/design/Voikerchat-AppStore-Metadata-v0.1.md` | 上記「ストア掲載文」節に廃止扱いで掲載済みだが、ファイル自体に廃止告知が無い。`shibuyer-ops`側は本タスクの変更対象外のため、告知追加はフォローアップ課題として残す |
| `shibuyer-ops/design/NEXUS-R5-Knowledge-Engine-v1.0.md` / `NEXUS-R6-Radar-v1.0.md` | Voikerchatとは無関係(NEXUS Radarプロジェクト)と推測されるが未確認。本INDEXの対象範囲(Voikerchat関連)に含めるべきか要判断 |
| `shibuyer-ops/tools/appstore_screenshot_resize.py` | ツール本体(mdではない)。App Store提出との関連は推測できるが用途の裏取りは未実施 |

---

## 棚卸しメモ

- 2026-08-17: 新設時点で`internal-docs/`配下のmdファイル67件を全件分類。未分類5件(うち3件はshibuyer-ops側)
- `internal-docs/`配下のサブディレクトリ(`reports/` `verification/` `migrations/` `tasks/`)は上表にファイル単位で展開済み
- 2026-08-17(同日追加分): `internal-docs/TRIGGERS.md`新設に伴い68件目として上表(今の状態を知りたい節)へ追加
- 2026-08-31: `internal-docs/runbooks/`(新設サブディレクトリ)に `screenshot_capture_20260901.md` を追加。上表「リリース手順を知りたい」節へ掲載
