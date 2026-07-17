# PROGRESS — Phase A 品質ゲート進捗台帳

運用ルールは RUNBOOK.md 参照。ここが現在地の唯一の真実。

## タスク状態
- [x] T-30 ブランドカラー・テーマ刷新 完了 2026-07-17 commit 31e5228 / CI緑(29545734528, 29545734646)
- [x] T-33 プレミアム購入フロー(ペイウォール) 完了 2026-07-17 commit 778a912 / CI緑(29546248589, 29546248599)
- [x] T-34 プレミアム専門シーン5本 + Kaigotalk データ設計 完了 2026-07-17 commit f55e500 / CI緑(29546593781, 29546593782)
- [x] T-32 シーンカード キャラクター画像 完了 2026-07-17 commit 7109444 / CI緑(29547467704, 29547467680)
- [ ] T-36 学習サポート移植(ふりがな/ヒント/単語まとめ)
- [ ] T-31 単語タップ辞書機能
- [ ] T-35 高品質TTS(3段構成: 端末/広告日解放/プレミアム常時) — 仕様確定 2026-07-16

## 人間へのお願い(未処理)
- Gemini でキャラ画像18枚生成(docs/tasks/GEMINI-DELEGATION.md ①。scene_01.webp〜scene_18.webp
  として assets/characters/ に配置すれば自動的にカードへ反映される。未配置分は現状プレースホルダー表示)
- クローズドテスト(Android)のトラック開始 — 14日の時計を先に回す(Master Plan 方針)
- T-33: Sandbox/ライセンステスターでの実機購入・復元テスト
- T-34: 新シーン14〜18(介護のしごと/医療スタッフ/面接/役所・手続き/職場の敬語)を各3往復以上
  実機/シミュレータで会話し、口調・語彙レベルが仕様通りか確認(受け入れ基準の手動確認項目)

## 判断記録
- T-30 ブランドカラー: ユーザー確認の結果、アイコン(assets/icon/app_icon_1024.png)から抽出した主要色を採用(候補A/B/C不採用)。抽出精度を上げた結果の正確な値 `#C73E3A` を採用(ユーザー承認時点の概算値は#C0392B)。
- T-30 スプラッシュ背景色: 仕様書は「決定色またはアイコン背景色の維持」を設計判断事項としていたため、彩度の高いブランド色ではなくアイコン自体の背景色 `#FAF7F0`(生成り)を採用し、アイコン→スプラッシュの視覚的連続性を優先(軽微な判断のため自己決定)。
- T-30 旧「Voikerchatブルー」(`#0099FF`、onboarding_progress_bar / diagnostic_test_screen_enhanced 等に散在)は明示的にブランド色扱いだったため、新ブランド色 `AppColors.brand` に統一置換。
- T-30 git identity: このリポジトリ限定で `.git/config` の `user.email` を `262262561+shibuyer-jp@users.noreply.github.com` にローカル上書き(CLAUDE.md指定、Vercelデプロイブロック回避目的)。global設定は変更していない。
- T-33 revenuecat_service.dart のバグ修正: `restorePurchases()` が実際には `Purchases.getCustomerInfo()` を呼んでおり復元処理を行っていなかった。`Purchases.restorePurchases()` を呼ぶよう修正(仕様書に明記はないが受け入れ基準「復元が機能する」に必須のため軽微な判断で修正)。
- T-33 home_screen.dart のバグ修正: `HomeScreen(userLevel: ...)` 呼び出し側(main.dart)が `isPremiumUser` を一切渡しておらず常に `false` だった(=購入済みユーザーでもシーンがロック表示されたままになる不具合)。RevenueCatServiceの実エンタイトルメントから取得するよう変更。
- T-33 chat_screen.dart 内蔵の購入ダイアログ/処理(`_showPremiumDialog`/`_purchasePremium`等)は全てPaywallScreen遷移に統一し削除(仕様書の「既存導線もPaywallScreenへ接続」に対応)。
- T-34 プレミアムシーンの実用/アニメ2分類は `SceneService` に `id>=14` の判定を集約(UI層に直書きしない)。
- T-34 Kaigotalkデータ設計: `usage_logs.session_id` が現状クライアントから送信されておらず常にNULLのため、正確な「完走率・平均ターン数」はセッション単位集計ができない。日次のuser×scene集計で近似するSQLをdocs/Kaigotalk-Data-Queries.mdに記録し、正確な計測が必要になった場合はsession_id送信の追加実装が別途要ることを明記(新規テーブル/スキーマ変更はしない方針を優先)。
- T-32 `assets/characters/` が空だと `flutter build`(Gradle)が `unable to find directory entry` を出す(pub getは通るがbuildは出る)ことを実機検証で確認。命名規約を記したREADME.mdを配置してディレクトリを非空に保つことで回避(新規判断・軽微)。

## セッションログ
- 2026-07-16: 計画策定(claude.ai 側)。仕様書 T-30〜T-35 / Master Plan v2.0 / RUNBOOK 作成。
- 2026-07-17: T-30 完了。commit `31e5228`、CI緑(CI/CD - Voikerchat run 29545734528, Flutter CI run 29545734646)。
- 2026-07-17: T-33 完了。commit `778a912`、CI緑(CI/CD - Voikerchat run 29546248589, Flutter CI run 29546248599)。
- 2026-07-17: T-34 完了。commit `f55e500`、CI緑(CI/CD - Voikerchat run 29546593781, Flutter CI run 29546593782)。
- 2026-07-17: T-32 完了。commit `7109444`、CI緑(CI/CD - Voikerchat run 29547467704, Flutter CI run 29547467680)。T-31 着手。
