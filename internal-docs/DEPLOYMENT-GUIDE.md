# Vercel Deployment Guide for Voikerchat

**Last Updated**: 2026-06-19(2026-08-04: docs/内部ドキュメント公開問題への対応でFolder Structure節を更新)
**Status**: ✅ Production Verified

**2026-08-04 追記**: `docs/`配下は設計・運用ドキュメントが平文で公開URLからアクセス可能になっていたため、内部専用ドキュメント52件を`internal-docs/`(リポジトリルート直下、Vercelの`outputDirectory`外)へ移動した。`docs/`直下には公開必須のHTML 7件(`index.html`・`support.html`・`Privacy-Policy-v1.0*.html`・`Terms-of-Service-v1.0*.html`・`legal-notice.html`)のみが残る。`vercel.json`の`outputDirectory: "docs"`自体は変更していない(このファイルの記載は引き続き正)。

## Quick Start

```bash
git add docs/
git commit -m "update: docs content"
git push origin main
```

Vercel will automatically deploy after ~30 seconds.

## Configuration

### vercel.json (Final Version)

```json
{
  "outputDirectory": "docs",
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

### Key Points

✅ **DO**:
- Use `outputDirectory: "docs"` for static HTML
- Keep docs/ folder at repository root
- Use single, simple commands for buildCommand (if needed)

❌ **DON'T**:
- Use buildCommand for static HTML (removed in this project)
- Chain commands with `&&` or `|`
- Add debug output with `echo`
- Use glob patterns like `docs/*`

## Troubleshooting

### "Build Failed" Email Loop

**Solution**: Vercel Dashboard > Redeploy (clear cache)

```
Vercel > voikerchat > Deployments > Latest > Redeploy
```

### docs/ Folder Not Found

**Check**:
```bash
git ls-files | grep docs
```

**Fix**:
```bash
git add docs/
git commit -m "add: docs folder"
git push
```

## Folder Structure

```
voikerchat/
├── docs/                    # Static HTML (served directly, PUBLIC — outputDirectory)
│   ├── index.html
│   ├── support.html
│   ├── legal-notice.html
│   ├── Terms-of-Service-v1.0.html / -en.html
│   └── Privacy-Policy-v1.0.html / -en.html
├── internal-docs/           # 内部専用ドキュメント(公開対象外、Vercelがデプロイしない)
│   ├── Tutorial-Design-v1.0.md
│   ├── Persona-Design-v1.0.md
│   ├── Onboarding-Flow-v1.0.md
│   ├── STATE.md / DECISIONS.md 等
│   └── tasks/ / migrations/ / verification/
├── vercel.json              # Deployment config
└── .gitignore
```

## Post-Deploy Checklist

- [ ] Vercel Status: "Ready" (Green ✅)
- [ ] Build Duration < 10s
- [ ] https://voikerchat.com accessible
- [ ] /index.html displays correctly
- [ ] No error emails after 5 minutes

## References

- **Vercel Docs**: https://vercel.com/docs
- **Static File Serving**: https://vercel.com/docs/project-configuration#outputDirectory
- **Voikerchat Project**: https://voikerchat.com
