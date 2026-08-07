# iOS 再提出手順(2026-08-07)

## 経緯

1.0.0+17 は 2026-08-06 に審査承認されたが、リリース前に「このリリースを
キャンセル」して品質改善版を再提出する判断をした(未完了項目13、
`internal-docs/DECISIONS.md` 2026-08-07参照)。

なお App Store には「修正扱いの審査ルート」は存在せず、再提出は新規提出
として審査キューに入り直す(審査時間は48時間程度を想定)。ただしメタ
データは承認済みであり、リジェクト理由(2回目リジェクト、Guideline
5.1.1(iv)/5.1.1(i)/5.1.2(i))もPR #36で解消済みのため、実務上の負担は
初回より小さい。

## 提出時の絶対ルール

- **メタデータを一切変更しないこと**。スクリーンショット、説明文、
  プライバシー申告、価格、App内課金設定はすべて承認済みの状態を維持する。
  変更した箇所は改めて審査対象になるため
- **バージョン番号「1.0」は編集しない。ビルド番号のみ上げる**
  (キャンセル後にバージョン番号を編集すると App Store Connect が
  操作不能になる報告事例があるため)
- キャンセル直後に「App内課金」の欄が表示され、サブスクリプション商品
  (`voikerchat_premium_monthly`)を紐付けられることを確認する。表示され
  ない場合は提出せず停止し、Apple サポートへ連絡する(サブスク構成の
  アプリで発生報告あり)

## App Review Notes に記載する文面(そのままコピーして使用)

```
This version was previously approved (build 17) but was not released.
We voluntarily cancelled the release to include quality improvements
found during internal testing. No changes to metadata, pricing,
or in-app purchase configuration. The app functionality remains
the same as the approved build, with bug fixes only.
```

## 修正内容(レビュアー向けの補足として、必要に応じて追記)

- オフライン起動時に画面が進まない不具合の修正(PR #59)
- 購入直後に Premium コンテンツのロックが解除されない不具合の修正(PR #53)
- Premium 判定のクライアント/サーバー間不整合の修正(2026-08-07、
  `internal-docs/reports/premium_state_mismatch_20260807.md`参照)

## 提出前チェックリスト

- [ ] TestFlight で最新ビルドの検証が完了している
- [ ] 「このリリースをキャンセル」を実行した
- [ ] App内課金の欄が表示され、サブスク商品を紐付けられた
- [ ] バージョン番号を編集していない
- [ ] メタデータを変更していない
- [ ] App Review Notes に上記文面を貼り付けた
