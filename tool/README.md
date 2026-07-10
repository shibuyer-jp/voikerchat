# tool/ — 開発用スクリプト

## 起動スクリプト(dart-define込み、手打ち不要)

| スクリプト | 環境 | 使い方 |
|---|---|---|
| `run_ios.sh` | Mac | `./tool/run_ios.sh`(初回のみ `chmod +x tool/run_ios.sh`)。引数でデバイスID変更可 |
| `run_android.bat` | Windows | `tool\run_android.bat`。エミュレーター未起動なら `tool\run_android.bat emu` |

共通の注意:
- **起動前にブランチ確認**(スクリプトが現在ブランチを表示します)
- キーは `sb_publishable_*`(公開可能キー)。秘密キー(`service_role` 等)は絶対にここへ書かない
- Supabaseキーの出典: Drive「Supabase Keys - Japanese-learning-app.txt」
