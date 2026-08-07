# iOS 再提出手順(2026-08-07)

## 実施結果(2026-08-07) ✅完了

1.0.0+20をApp Reviewへ再提出済み。

- 承認済みだった1.0(build 17)の「リリースをキャンセル」を実行。実行後、
  バージョンの状態は「1.0 デベロッパにより却下」となり、編集可能な状態
  に戻った
- **懸念していた「Developer Reject後にIn-App Purchasesを紐付けられなく
  なる」不具合は発生しなかった**。サブスクリプショングループ
  「Premium」(1商品)は正常に残っており、バージョン1.0にビルド20を
  問題なく紐付けられた[確認済 2026-08-07、App Store Connect実画面]
- バージョン番号「1.0」は編集していない。メタデータも一切変更していない
- App Review Notesには、下記の状況説明の定型文に加え、前回審査時から
  継続している操作案内(レビュアーがPaywallへ到達し課金導線を確認できる
  よう案内する文面)を併記して提出した(下記「App Review Notes」節参照)

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
  アプリで発生報告あり)。**[2026-08-07実施結果]** 1.0.0+20の再提出では
  この懸念は発生せず、サブスクリプショングループ「Premium」は正常に
  残っておりビルド20への紐付けも問題なく行えた

## App Review Notes に記載する文面(そのままコピーして使用)

以下の2ブロックを**併記する**運用とする。1つ目は今回のキャンセル/再提出の
状況説明、2つ目はレビュアーが実際にPaywallへ到達し課金導線を確認できる
ようにするための操作案内(前回審査時から継続使用しているもので、今回の
提出でも引き続き必要)。**操作案内を省くと、レビュアーがPaywallへ到達
できず課金導線を確認できないまま差し戻されるリスクがある**ため必ず含める
こと。

```
This version was previously approved (build 17) but was not released.
We voluntarily cancelled the release to include quality improvements
found during internal testing. No changes to metadata, pricing,
or in-app purchase configuration. The app functionality remains
the same as the approved build, with bug fixes only.

A level assessment test is offered immediately after installation
and can be skipped; it remains available from the home screen
afterwards.
```

**2026-08-07修正**: 操作案内の1文目を実態に合わせて修正した。

- 旧: `A level assessment test starts immediately after installation.`
- 新: `A level assessment test is offered immediately after installation
  and can be skipped; it remains available from the home screen
  afterwards.`
- 理由: PR #52(オンボーディングスライド追加と診断テストの任意化)により
  診断テストはスキップ可能になっており、スキップ後もホーム画面から実施
  できることを1.0.0+20の実機で確認した[確認済 2026-08-07]。旧文面のまま
  だと「診断テストが必ず即座に始まる」という誤った案内になり、レビュ
  アーが実機の挙動と食い違うと判断するリスクがあった

## 修正内容(レビュアー向けの補足として、必要に応じて追記)

- オフライン起動時に画面が進まない不具合の修正(PR #59)
- 購入直後に Premium コンテンツのロックが解除されない不具合の修正(PR #53)
- Premium 判定のクライアント/サーバー間不整合の修正(2026-08-07、
  `internal-docs/reports/premium_state_mismatch_20260807.md`参照)

## 提出前チェックリスト

再利用可能なテンプレートのため未チェックのまま維持する。
**2026-08-07提出分は全項目完了済み**(上記「実施結果」参照)。

- [ ] TestFlight で最新ビルドの検証が完了している
- [ ] 「このリリースをキャンセル」を実行した
- [ ] App内課金の欄が表示され、サブスク商品を紐付けられた
- [ ] バージョン番号を編集していない
- [ ] メタデータを変更していない
- [ ] App Review Notes に上記文面(状況説明+操作案内)を貼り付けた
