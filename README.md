# voikerchat
Voikerchat: Japanese learning app for Filipino spouses

## 開発環境セットアップ

- `flutter pub get`
- `lefthook install`(pre-push / post-checkout / post-merge フックを有効化)

### ローカライズ生成物(`lib/l10n/app_localizations*.dart`)について

このファイルは `.gitignore` 対象で、`lib/l10n/*.arb` から `flutter gen-l10n` で生成する。

- `lefthook install` 済みの環境では、ブランチ切替(`post-checkout`)・マージ(`post-merge`)・push前(`pre-push`)のタイミングで自動的に `flutter gen-l10n` が実行されるため、通常は意識不要。
- ただし以下のケースでは手動で `flutter gen-l10n` を実行すること:
  - `lefthook install` を未実施の環境
  - ARB(`lib/l10n/app_*.arb`)を手動編集した直後(lefthookのフック発火前に確認したい場合)
- CI(`flutter-ci.yml` / `ci-cd.yml`)は全ジョブで `flutter analyze` / `flutter test` の直前に `flutter gen-l10n` を実行済みのため、CI側での対処は不要。
