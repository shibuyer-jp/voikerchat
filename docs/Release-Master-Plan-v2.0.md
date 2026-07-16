# Release Master Plan v2.0 (2026-07-16)

製品版リリース前の品質改善6項目(ユーザー指示 2026-07-16)を反映した、完成までの設計図の改訂版。
旧計画(即時提出)との最大の違いは、**提出前に品質ゲート(Phase A)を挟む**こと。

## 0. 大方針

1. **Android のクローズドテスト14日間の時計を今すぐ回し始める**(最重要)。
   - Play 製品版公開には「テスター12人以上が14日間連続でオプトイン」+ Google審査(約7日)が必須。
   - テスト中のビルドは更新可能なので、**現行ビルドでトラックを開始し、Phase A の改善はテスト期間中にアップデートとして流し込む**。これで品質改善がリリース日を遅らせない。
2. iOS も同様に、TestFlight 配信は現行ビルドで継続し、Phase A 完了後のビルドで審査提出する。
3. **注意: 2026-07-16 に撮影済みのストアスクリーンショット(iPhone分10枚)は、テーマ色変更(T-30)とシーン画像追加(T-32)で見た目が変わるため再撮影が必要になる。** iPad 分の撮影は Phase A 完了後に一本化する(二度手間防止)。

## 1. タスク一覧(Phase A: 品質ゲート)

| ID | タスク | 仕様書 | 主担当 | 人間の判断が必要な点 |
|----|--------|--------|--------|----------------------|
| T-30 | ブランドカラー確定とテーマ刷新 | docs/tasks/T-30_brand-theme.md | Claude Code | ブランドカラーの最終選択 |
| T-32 | シーンカードにキャラクター画像 | docs/tasks/T-32_character-images.md | Claude Code + 画像生成 | 画像スタイルの承認・生成実行 |
| T-33 | プレミアム購入フロー(ペイウォール) | docs/tasks/T-33_premium-paywall.md | Claude Code | Sandbox 実機購入テスト |
| T-34 | プレミアム専門シーン5本 + Kaigotalk データ設計 | docs/tasks/T-34_premium-pro-scenes.md | Claude Code | シーン内容の最終確認 |
| T-31 | 単語タップ辞書機能 | docs/tasks/T-31_word-lookup.md | Claude Code | なし(UX確認のみ) |
| T-35 | 高品質TTS(3段構成: 端末/広告日/プレミアム) | docs/tasks/T-35_premium-tts.md | Claude Code | OpenAI APIキー設定・実機聴感確認 |
| T-36 | 学習サポート移植(ふりがな/ヒント/単語まとめ) | docs/tasks/T-36_learner-support-carryover.md | Claude Code | なし(UX確認のみ) |

**推奨実施順**: T-30 → T-33 → T-34 → T-36 → T-31 → T-32 → T-35
(T-32 は画像アセット(Gemini生成)待ちのため後方へ。Gemini 分担は docs/tasks/GEMINI-DELEGATION.md)
(T-30 が全画面に影響するため最初。T-35 は外部API契約が絡むため独立して進行可)

## 2. Phase B: 検証・アセット再作成

1. `flutter analyze` / `flutter test` 全緑 + CI 緑(lefthook で強制済み)
2. TestFlight / クローズドテストにアップデート配信 → 実機での回帰確認
   - 会話(529リトライ含む)・PTT音声・広告リワード・購入・復元・単語辞書・新シーン
3. **ストアスクリーンショット再撮影**(iPhone 6.9"=1320x2868 / iPad 13"=2064x2752 / Android phone・tablet)
   - 既存手順: `memory/ios_screenshot_procedure_20260716.md`(shibuyer-ops)、`tools/appstore_screenshot_resize.py`
   - 新シーン・新テーマ・キャラ画像が映る構図に更新
4. プライバシーポリシー / App Privacy(データ収集項目)の確認
   - T-34 の集計ログ・T-35 のクラウドTTS(音声テキストの外部送信)・T-31 の辞書API送信を反映

## 3. Phase C: 提出

1. Apple: 住所ケース(102940383996)クローズ確認 → W-8BEN / 銀行情報 → ビルド選択 → IAP(Premium)をビルドと同時に審査提出
2. Google: クローズドテスト14日+12人達成 → 製品版申請(審査約7日)
3. 提出後: テスター向け告知、リリースノート(ja/en/fil)

## 4. スコープ外(Phase 2 / リリース後)

正式台帳: `docs/tasks/BACKLOG-Phase2.md`(Web版仕様書v1.9との突合済み・出典トレーサビリティ付き)。ダークモード、Kaigotalk本体企画もPhase 2。

## 5. Claude Code への委任

運用手順・キックオフプロンプトは `docs/tasks/RUNBOOK.md` を参照。
原則: **ストア操作・実機テスト・画像生成の実行・API契約・聴き比べ判断以外は全て Claude Code が自走する。**
