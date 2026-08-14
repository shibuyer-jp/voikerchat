# Android リリースビルド手順書(Windows Laptop)

Androidの本番/クローズドテスト向けAABビルドはCI化されておらず、**全工程手動**(`.github/workflows/`にはdebug APKビルドのみで、appbundle生成・Play Console投入のジョブは存在しない)。本手順書はWindows Laptop(`C:\Users\takat`)での実行を前提とする。

**前回実績(versionCode 7、`shibuyer-ops/memory/handoff_20260723_4.md`)からの重要な訂正**: 前回実行したビルドコマンドは`flutter build appbundle --release`のみで、`--dart-define`を一切渡していなかった。このAAB自体は(未アップロードのまま残っていたため実害はなかったが)そのままPlay Consoleに投入されていれば、`SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`が空文字列のままコンパイルされ、**認証・チャット機能が一切動作しない状態**でテスターに配布されていた可能性が高い(`lib/main.dart`は両方空の場合Supabase初期化自体をスキップする設計のため)。本手順書ではこの手順を踏襲せず、`tool/run_android.bat`と`lib/main.dart`/`lib/services/*.dart`のコードを精査し直して必要な`--dart-define`を明記する。

---

## 1. 事前確認

```powershell
cd C:\Users\takat\voikerchat
git status
git pull origin main
```

- `git status`で作業ツリーがクリーンであることを確認(未commitの変更があると意図しない内容がビルドに混入する)。
- `flutter clean`は**毎回は不要**。以下の場合のみ実行:
  - 直前に大きな依存関係変更(pubspec.yaml更新)やFlutter/Gradleバージョン変更があった場合
  - ビルドエラーの原因がキャッシュ起因と疑われる場合(後述「よくある失敗」参照)
- `flutter gen-l10n`は**必須**。ARBを直接編集していなくても、フレッシュチェックアウト直後や別ブランチからの切替直後は`lib/l10n/app_localizations*.dart`が生成されていない/古い場合があるため、ビルド前に必ず実行する(lefthookの`post-checkout`/`post-merge`で自動実行される設定だが、念のため手動でも確認する):

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

全て緑(`No issues found!` / `All tests passed!`)を確認してから次に進む。**ここで赤が出た場合はビルドに進まない。**

---

## 2. keystore / 署名設定の状態確認

### keystoreの場所
```
%USERPROFILE%\Voikerchat-Release-Keys\upload-keystore.jks
```
(リポジトリ外。Google Driveの`00_Project_Credentials/Android_Signing`にもバックアップ済み、2026-07-23確認)

### 確認コマンド

```powershell
# keystore実体の存在確認
Test-Path "$env:USERPROFILE\Voikerchat-Release-Keys\upload-keystore.jks"

# key.properties(リポジトリ内、git-ignore対象)の存在確認
Test-Path "android\key.properties"
```

両方とも`True`が返ること。**`android/key.properties`の中身(パスワード含む)は絶対にチャット・ログ・コミットに出力しないこと。**

### 署名設定の仕組み(`android/app/build.gradle.kts`)

- `key.properties`が存在する場合のみ、そこから`keyAlias`/`keyPassword`/`storeFile`/`storePassword`を読み込み、releaseビルドに適用する
- `key.properties`が存在しない場合は**debug鍵に自動フォールバックする**(PR #5でこのフォールバックを廃止する変更が実装済みだが**マージ保留中**。現時点のmainではフォールバックが生きているため、`key.properties`の存在確認を怠ると、気づかずdebug署名のAABが生成されるリスクが今も残っている)

---

## 3. ビルドコマンド

### 3-1. バージョン確認(ビルド前に必須)

```powershell
Select-String -Path pubspec.yaml -Pattern "^version:"
```

`version: 1.0.0+22`になっていることを確認する(Build 22の場合。以降のビルドでも、この記述は「その時点でビルド対象とするversionCode」に読み替えること。pubspec.yaml側の値が唯一の正である点は変わらない。`flutter.versionCode`/`flutter.versionName`は`android/app/build.gradle.kts`がこの値を直接参照するため)。**なっていなければビルドコマンドを実行する前にpubspec.yamlの更新を先に済ませること。**

### 3-2. 実行するコマンド(全文)

`lib/`配下の`String.fromEnvironment`/`bool.fromEnvironment`呼び出し(`lib/main.dart`・`lib/services/ad_config.dart`・`lib/services/revenuecat_service.dart`)を全て洗い出した結果、渡すべき/渡してはいけない値は以下の通り。

**⚠️ 渡し忘れ厳禁(versionCode 7の再発防止)**: 前回のversionCode 7ビルドでは`SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`を渡し忘れたまま、アプリはクラッシュせず「チャット機能(中核機能)だけが動作しない不良ビルド」としてPlay Consoleに投入されかけた事例がある(`internal-docs/DECISIONS.md` 2026-07-27参照)。`REVENUECAT_ANDROID_KEY`も同じ性質を持つ: 渡し忘れても`lib/services/revenuecat_service.dart`の設計上`Purchases.configure()`が黙ってスキップされるだけでアプリはクラッシュせず、ビルド・アップロード・審査を全て素通りしてから「テスターが購読ボタンを押しても反応しない」という形で初めて発覚する、**サイレント失敗**になる。ビルド実行前に必ずコマンド全文を目視し、`<YOUR_ANDROID_KEY>`が実キーに置き換わっていることを確認すること。

**⚠️ キーの種別を厳密に区別すること(2026-08-10、埋め込みかけインシデントを受け追記)**: RevenueCatには性質の異なる2種類のキーが存在する。
- **渡すべきキー**: Public SDK Key(RevenueCatダッシュボード「API keys → Public app-specific API keys」)。**`goog_`で始まる**。アプリに埋め込む前提で作られており、解析されても実害は無い
- **絶対に渡してはいけないキー**: Secret API Key(同ダッシュボード「API keys → Secret keys」)。**`sk_`で始まる**。サーバー専用で、Vercel環境変数`REVENUECAT_SECRET_KEY`(`api/premium-sync.ts`が使用)にのみ設定する。**アプリへ埋め込むと解析により購読データの読み書きが可能になるため絶対に埋め込まない**
- 2026-08-10の実作業で、`sk_`で始まるSecret API Keyを誤って`REVENUECAT_ANDROID_KEY`へ埋め込みかけるインシデントが発生した(ビルド実行前に気づき未実行、実害なし)

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://rfwbwwhqclabhnbsrygw.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_jirMoWsnc0AtQc4c2tUJ6Q_3uc43qHT `
  --dart-define=REVENUECAT_ANDROID_KEY=goog_XXXXXXXXXXXXXXXXXXXXXXXXXXX
```

`<YOUR_ANDROID_KEY>`は、2026-08-04にRevenueCatダッシュボードへ登録したGoogle Playアプリ(App ID: `appf7acdb482b`、Package name: `jp.shibuyer.voikerchat`)に対して発行されたAndroid用Public API Key(`goog_`で始まる)に置き換える。**キーの値自体はこの手順書を含むリポジトリには一切記載しない**(開発者が手元で管理)。

**⚠️ `< >`はプレースホルダ記号であり、実際のコマンドには含めないこと**: 本書中の`<YOUR_ANDROID_KEY>`等の山括弧はプレースホルダを表す記号であり、PowerShellではリダイレクト演算子として解釈される。実行するコマンドには`<`や`>`を含めず、実際のキー文字列(上記コマンド例の`goog_...`のように)へそのまま置き換えること。

**含めない(意図的)**:
- `USE_TEST_ADS`: 渡さない。デフォルト`false`(本番広告)。`lib/services/ad_config.dart`のコメントに「ストア提出ビルドでは絶対にtrueにしないこと」と明記されている。
- `REVENUECAT_IOS_KEY`: iOS専用のため無関係。

初回ビルドはGradleの依存解決等で数分かかる。2回目以降はキャッシュが効き短縮される。

---

## 4. 生成物の出力パス

```
build\app\outputs\bundle\release\app-release.aab
```

実績(Build 18・versionCode 18時点、Play Console実画面で確認): AABファイル自体のサイズは約89.4MB。Build 21(versionCode 21)もversionCode変更のみで同ソースからの差分がないため同水準の見込み。**89.4MBはユーザーの実ダウンロードサイズではない**(3ABI中1つのみ配信されBUNDLE-METADATAは配信対象外のため。Play Console上の「新規インストールのサイズ」は42.4MB、更新時32.5MB。詳細は`internal-docs/reports/aab_size_investigation_20260807.md`参照)。極端にサイズが異なる場合は不要なアセット混入等を疑うこと。

---

## 5. ビルド後の検証

### 5-1. versionCodeの確認(必須)

最も確実なのは**ビルド前**の3-1の確認(pubspec.yamlはgradleが直接参照する値の唯一の正のため)。ビルド後に生成物自体から再検証したい場合は、Android SDK付属の`bundletool`が必要だが、本マシンには未インストール(2026-07-27時点)。代わりに以下のいずれかで確認する:

- **簡易確認**: `android/local.properties`(Flutterツールが毎回自動更新する非トラッキングファイル)の`flutter.versionCode=`行を確認(ビルド実行後に自動更新される)
  ```powershell
  Select-String -Path android\local.properties -Pattern "flutter.versionCode"
  ```
- **確定的な確認**: Play Consoleへのアップロード後、「リリースの詳細」画面に表示されるバージョンコードで最終確認する(6章参照)

### 5-2. 署名の確認(推奨)

```powershell
$KEYTOOL = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
& $KEYTOOL -list -v -keystore "$env:USERPROFILE\Voikerchat-Release-Keys\upload-keystore.jks" -alias upload
```
パスワード入力を求められる。表示された発行者(`CN=Voikerchat, OU=Shibuyer, ...`)がdebug鍵の`CN=Android Debug`になっていないことを確認する。SHA1/SHA256フィンガープリントは`shibuyer-ops/memory/handoff_20260723_4.md`記載の値と一致するはず:
```
SHA1:   D1:0A:DD:50:75:F8:BF:53:76:02:6C:80:65:2F:23:65:DD:F6:5B:80
SHA256: 32:6E:51:4F:85:70:30:1E:92:3A:10:53:B5:D4:69:29:04:3C:9E:60:8E:7E:D5:2F:6E:BD:B0:D7:95:F4:EC:F1
```

### 5-3. Paywall / RevenueCat Offering取得の確認(必須、REVENUECAT_ANDROID_KEYを渡したビルドのみ)

実機(クローズドテスト経由でインストールしたビルド)でPaywall画面(`lib/screens/paywall_screen.dart`)を開き、以下を確認する。3-2でのdart-define渡し忘れは実行時エラーを一切出さないため、**この画面確認が渡し忘れを検知できる唯一の手段**。

1. 「購読する」ボタンがグレーアウトしていないこと(`_purchasingAvailable`= `revenueCatService.isConfigured`。falseだと自動的にグレーアウトする設計)
2. 表示価格がARBのフォールバック値`$12.99`(`premiumPriceFallback`、`lib/l10n/app_ja.arb`)固定表示ではなく、Google Play Consoleで設定した現地価格(例: 日本ならJPY 1,818、フィリピンならPHP 713)になっていること。**JPY 2,120 / PHP 895 は2026-08-07の値下げ前の旧価格であり、これが表示された場合はOffering取得の失敗ではなく価格設定の巻き戻りを疑うこと**(値下げの経緯はARCHIVE.md該当項目参照)。フォールバック値のまま表示される場合は`Purchases.getOfferings()`が失敗しているか、RevenueCatダッシュボード側のOffering/Product未マッピングを疑う

いずれかを満たさない場合、購入テストには進まず、まず3-2のコマンドで`REVENUECAT_ANDROID_KEY`を渡し忘れていないか、次に`internal-docs/STATE.md`の「RevenueCat Android有効化」進捗(Offering/Productマッピング完了状況)を確認する。

**計測イベントの記録確認(Build 22以降で必須)**: 実機でアプリを
更新・起動しPaywallを開いたうえで、Supabase SQL Editorで下記を
実行し `session_start` と `upsell_shown` が記録されることを確認する。
2026-08-14に、PR-Aの計測コードがリリース済みのどのビルドにも
含まれていなかった事例が発生したため(詳細はDECISIONS.md
2026-08-14参照)、計測系のコードを追加した場合はマージ確認だけで
済ませず必ず実機で記録を確認すること。

```sql
select event, count(*) as n, max(created_at) as latest
from usage_logs
where created_at >= current_date
group by event
order by n desc;
```

---

## 6. Play Consoleへのアップロード手順(ブラウザ操作・人間作業)

1. [Google Play Console](https://play.google.com/console/)にログインし、Voikerchatアプリを選択
2. 左メニュー「テストとリリース」→「テスト」→「クローズドテスト」を選択(トラック未作成なら新規作成)
3. 「新しいリリースを作成」
4. AABファイルをアップロード欄にドラッグ&ドロップ、または選択(`build\app\outputs\bundle\release\app-release.aab`)
5. アップロード完了後、画面に表示されるバージョンコード・バージョン名を確認(ここが5-1の最終確認ポイント)
6. リリースノートを入力(日本語・英語。テスターに表示される)
7. データセーフティ申告・対象年齢(18+)の設定がストア側でも一致しているか確認(コード側の年齢18+方針との整合、既存タスク参照)
8. テスター名簿(12名以上)のメールアドレスを登録、またはメーリングリストを紐付け
9. 「レビューを開始」→「公開」
10. テスターへオプトインURLを共有し、一斉オプトインを依頼(14日タイマーはテスターがオプトインしてアプリを取得した時点から起算されるため、告知と同時並行で進める)

---

## 7. よくある失敗と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `ProcessException`で`font-subset.exe`関連のビルド失敗 | Windowsのアプリケーション制御ポリシーが、Flutter engine同梱の未署名exeを初回実行時にブロックする | 該当exeを一度直接実行(ダブルクリック等)してWindowsの初回スキャンを通過させてから再ビルド。前回(Build 7)もこれで解消済み、再発しても同じ対処でよい |
| 生成されたAABがdebug署名になっている(6章のフィンガープリント確認で発覚) | `android/key.properties`が存在しない、またはパスが誤っている状態でビルドしてしまった(2章参照、現状フォールバックが生きている) | `key.properties`の存在・中身を再確認し、`android/app/build.gradle.kts`を再ビルド。PR #5(fail-fast化)がマージされていれば、この状態は明示的なビルドエラーとして検知できるようになる予定 |
| `flutter analyze`/`flutter test`が赤 | `flutter gen-l10n`未実行(ARB生成物が古い/存在しない) | `flutter gen-l10n`を実行してから再度analyze/test |
| アプリ起動後チャット画面で`Supabase.instance`関連のAssertionError | `--dart-define=SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`を渡し忘れた(3-2参照。前回Build 7で実際に発生したリスク) | 3-2のコマンド全文をそのまま使用し、dart-defineを渡し忘れていないか再確認 |
| Play Consoleでアップロード時に「バージョンコードは既に使用されています」エラー | pubspec.yamlのビルド番号を上げ忘れたまま過去に一度アップロード済みのversionCodeで再ビルドした | pubspec.yamlの`version:`を1つ上げてから再ビルド(iOS/Android共通のビルド番号のため、iOS側で既に番号を消費していないかも確認) |
| Paywall画面で購読ボタンが押せない(グレーアウト) | **2026-08-04以降**: RevenueCat Androidキーは発行済みのため、このボタンがグレーアウトしている場合は不具合の可能性が高い(3-2の`REVENUECAT_ANDROID_KEY`渡し忘れ、または5-3のOffering未取得)。**2026-08-04より前のビルド(Build 17以前)**では意図した動作(キー未発行のため) | 3-2のビルドコマンドに`REVENUECAT_ANDROID_KEY`が含まれているか再確認し、5-3の手順で原因を切り分ける |

---

## 参照
- keystore作成・初回AABビルドの経緯: `shibuyer-ops/memory/handoff_20260723_4.md`
- Android署名fail-fast化(未マージ): PR #5
- RevenueCat Android設定の進捗(Service Credentials/Real-Time Developer Notifications等): `internal-docs/STATE.md`「RevenueCat Android有効化」参照
- RevenueCat Androidキー未設定時のコード動作調査(Build 13関連、`isConfigured`ガード等の設計根拠): 過去セッションの調査結果
