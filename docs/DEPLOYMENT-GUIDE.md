# Voikerchat Vercel デプロイメント完全ガイド

**作成日：2026-06-19**
**更新日：2026-06-19**

## トラブルシューティング履歴

### 問題：Vercel デプロイで 404 エラーが発生

#### 根本原因
1. **Vercel プロジェクト未登録**
   - GitHub リポジトリは作成されたが、Vercel にインポートされていなかった
   - voikerchat.com の DNS が Vercel に接続されていなかった

2. **Root Directory / Output Directory 設定エラー**
   - Root Directory を `docs` に設定すると、Vercel は docs フォルダ内を見る
   - Output Directory が `docs` だと、docs/docs パスになり 404 エラー

3. **Build Command の不足**
   - 空の buildCommand では静的 HTML ファイルを処理できない
   - HTML ファイルを公開フォルダにコピーする必要があった

#### 解決ステップ

**ステップ 1：Vercel で GitHub をインポート**
- Vercel → Add New → Project
- shibuyer-jp/voikerchat を選択
- Root Directory：`./` または `voikerchat (root)`
- Output Directory：`public`

**ステップ 2：vercel.json を修正**
```json
{
  "buildCommand": "mkdir -p public && cp -r docs/* public/",
  "outputDirectory": "public",
  "cleanUrls": true,
  "trailingSlash": false
}
```

**理由：**
- `buildCommand`：ビルド時に docs フォルダを public フォルダにコピー
- `outputDirectory`：public フォルダを本番環境として指定

**ステップ 3：GitHub に Push して再デプロイ**
```bash
git add vercel.json
git commit -m "fix: vercel.json - copy docs to public during build"
git push origin main
```

Vercel が自動検出して再デプロイ。

#### 最終設定

**vercel.json（推奨テンプレート）**
```json
{
  "buildCommand": "mkdir -p public && cp -r docs/* public/",
  "outputDirectory": "public",
  "devCommand": "echo 'Development mode'",
  "cleanUrls": true,
  "trailingSlash": false,
  "headers": [
    {
      "source": "/:path*",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=3600, s-maxage=3600"
        }
      ]
    }
  ]
}
```

## 今後の対策

### 1. テンプレート化
- vercel.json（静的 HTML 用）をテンプレートリポジトリに保存
- 新しい静的サイトプロジェクトはこれをコピー

### 2. チェックリスト
- [ ] GitHub にコード push
- [ ] Vercel に GitHub からインポート
- [ ] Root Directory：`./` に確認
- [ ] Output Directory：`public` に確認
- [ ] Build Command：docs コピーコマンド確認
- [ ] 本番 URL で HTML ファイルテスト

### 3. ドメイン設定（次ステップ）
1. Vercel → Settings → Domains
2. `voikerchat.com` を追加
3. DNS 設定ガイダンスに従い Dynadot で設定
4. DNS 伝播待機（数分～24時間）

## デプロイ状況

**本番 URL：** https://voikerchat-x621.vercel.app

**ファイル確認：**
- ✅ Terms-of-Service-v1.0.html
- ✅ Privacy-Policy-v1.0.html

**次のマイルストーン：**
1. voikerchat.com DNS 接続
2. App Store / Google Play 審査提出

---

**担当：Takatoh | 2026-06-19**
