# Release Notes — Build 16 (`1.0.0+16`)

Google Play クローズドテスト向け「リリースノート」欄への貼り付け用(テスターに表示される)。技術用語を避け、ユーザー影響のある変更のみ記載。ユーザー影響のない内部変更(AdMob IDコメント整理・ログレベル分岐・usage_logsのlocale/platform記録・PREMIUM表示文言のARB化(表示上の変化なし))はまとめて一言にした。

含まれるPR: #29 / #30 / #31 / #32 / #33 / #34 / #35(ビルド自体には含まれる。ただしPR #29・#30はAndroidのBuild 13への反映有無が断定できないため、下記リリースノート本文には記載しない。2026-08-01判断、理由は`docs/DECISIONS.md`参照)

## 日本語(ja)

```
Build 16 アップデート内容

・会話のまとめ・単語リストの機能に、1日あたりの利用回数の上限を設けました(無料版は1日10回まで。Premiumは無制限)
・通知履歴で、届いていない通知が表示されたり、削除しても再表示される不具合を修正しました
・学習統計画面(プレミアム限定)で、シーン名が数字のまま表示される、学習時間が0のまま表示される、連続学習日数が正しく表示されない、といった不具合を修正しました
・その他、アプリの安定性向上のための細かな修正を行いました
```

## English (en)

```
Build 16 update

- Added a daily usage limit to conversation recaps and vocabulary lists (up to 10 per day on the free plan; unlimited on Premium)
- Fixed a notification history issue where notifications that hadn't arrived yet could appear, and deleted notifications could seem to come back
- Fixed several display issues on the Learning Stats screen (Premium): scene names showing as numbers, study time stuck at 0, and streak days not showing correctly
- A few other small stability improvements behind the scenes
```

## Filipino (fil)

```
Build 16 update

- Nagdagdag ng pang-araw-araw na limitasyon sa paggamit ng recap ng usapan at listahan ng bokabularyo (hanggang 10 beses sa isang araw sa free plan; walang limitasyon sa Premium)
- Naayos ang isyu sa history ng notification kung saan lumalabas ang mga hindi pa dumadating na notification, at parang bumabalik ang mga tinanggal na notification
- Naayos ang ilang isyu sa Learning Stats screen (Premium): numero ang lumalabas sa pangalan ng eksena, naka-stuck sa 0 ang oras ng pag-aaral, at hindi tama ang streak days
- Iba pang maliliit na pagpapabuti sa likod ng eksena para sa katatagan ng app
```
