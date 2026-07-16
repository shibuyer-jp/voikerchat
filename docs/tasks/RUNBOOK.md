# RUNBOOK: Claude Code 自走運用(Phase A 品質ゲート)

目的: **本当に人間が必要な作業以外を全て Claude Code に委任する**ための運用規約。

## Claude Code へのキックオフプロンプト(そのまま貼り付け)

```
voikerchat リポジトリで作業します。まず git pull し、docs/tasks/RUNBOOK.md と
docs/Release-Master-Plan-v2.0.md を読んでください。
docs/tasks/ の T-30 → T-33 → T-34 → T-32 → T-31 → T-35 の順で、未完了の
最初のタスクに着手してください。各タスクの仕様書に従い、「人間の判断が必要な点」
だけ私に質問し、それ以外は完了まで自走してください。
タスク完了ごとに: 検証(analyze/test)→コミット→push→CI緑確認→
docs/tasks/PROGRESS.md に完了記録を追記→次タスクへ。
セッション終了時は必ず PROGRESS.md に現在地と次アクションを書いてください。
```

## 自走ルール
1. **CLAUDE.md の絶対ルールを厳守**(push前ローカル検証: pub get → gen-l10n → analyze → test 全緑)。
2. 1タスク = 複数コミット可。ただしタスク途中で日をまたぐ場合も必ず push しておく(GitHub が唯一の真実)。
3. 進捗台帳は `docs/tasks/PROGRESS.md`(このリポジトリ)に一元化。書式:
   `- [x] T-30 完了 2026-07-XX commit abc1234 / 備考`
4. 仕様書に無い設計判断が必要になったら: 軽微なら自分で決めて PROGRESS.md に判断理由を記録、重大(課金・データ・外部API契約に関わる)なら人間に質問して停止。
5. ストア(App Store Connect / Play Console)のブラウザ操作、実機テスト、画像生成の実行、API契約は人間の担当。Claude Code は「人間へのお願いリスト」を PROGRESS.md に書き出す。

## 人間(Takatoh)の担当一覧(これ以外は全部 Claude Code)
- ブランドカラー最終選択(T-30)/ 画像生成の実行と承認(T-32)
- Sandbox/ライセンステスターでの購入テスト(T-33)
- TTS聴き比べ・プロバイダ契約・キー保管(T-35)
- ストアのブラウザ操作全般、スクショ撮影(手順書あり)、TestFlight/クローズドテスト実機確認
- Apple住所ケース等のメール・電話対応

## セッション引き継ぎ
shibuyer-ops の handoff 運用は継続するが、**コード作業の現在地はこのリポジトリの PROGRESS.md が正**とする(2重管理による齟齬防止。handoff からは PROGRESS.md を参照する)。
