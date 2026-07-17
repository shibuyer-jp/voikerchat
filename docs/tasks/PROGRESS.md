# PROGRESS — Phase A 品質ゲート進捗台帳

運用ルールは RUNBOOK.md 参照。ここが現在地の唯一の真実。

## タスク状態
- [x] T-30 ブランドカラー・テーマ刷新 完了 2026-07-17 commit 31e5228 / CI緑(29545734528, 29545734646)
- [ ] T-33 プレミアム購入フロー(ペイウォール)
- [ ] T-34 プレミアム専門シーン5本 + Kaigotalk データ設計
- [ ] T-32 シーンカード キャラクター画像
- [ ] T-36 学習サポート移植(ふりがな/ヒント/単語まとめ)
- [ ] T-31 単語タップ辞書機能
- [ ] T-35 高品質TTS(3段構成: 端末/広告日解放/プレミアム常時) — 仕様確定 2026-07-16

## 人間へのお願い(未処理)
- Gemini でキャラ画像18枚生成(docs/tasks/GEMINI-DELEGATION.md ①。T-32の前提)
- クローズドテスト(Android)のトラック開始 — 14日の時計を先に回す(Master Plan 方針)
- T-33: Sandbox/ライセンステスターでの実機購入・復元テスト(実装完了後)

## 判断記録
- T-30 ブランドカラー: ユーザー確認の結果、アイコン(assets/icon/app_icon_1024.png)から抽出した主要色を採用(候補A/B/C不採用)。抽出精度を上げた結果の正確な値 `#C73E3A` を採用(ユーザー承認時点の概算値は#C0392B)。
- T-30 スプラッシュ背景色: 仕様書は「決定色またはアイコン背景色の維持」を設計判断事項としていたため、彩度の高いブランド色ではなくアイコン自体の背景色 `#FAF7F0`(生成り)を採用し、アイコン→スプラッシュの視覚的連続性を優先(軽微な判断のため自己決定)。
- T-30 旧「Voikerchatブルー」(`#0099FF`、onboarding_progress_bar / diagnostic_test_screen_enhanced 等に散在)は明示的にブランド色扱いだったため、新ブランド色 `AppColors.brand` に統一置換。
- T-30 git identity: このリポジトリ限定で `.git/config` の `user.email` を `262262561+shibuyer-jp@users.noreply.github.com` にローカル上書き(CLAUDE.md指定、Vercelデプロイブロック回避目的)。global設定は変更していない。

## セッションログ
- 2026-07-16: 計画策定(claude.ai 側)。仕様書 T-30〜T-35 / Master Plan v2.0 / RUNBOOK 作成。
- 2026-07-17: T-30 完了。commit `31e5228`、CI緑(CI/CD - Voikerchat run 29545734528, Flutter CI run 29545734646)。T-33 着手。
