# デプロイ/運用手順（MVP）

## 想定構成

- **Web/API**: Vercel（Next.js）
- **DB**: Postgres（Neon / Supabase / RDS など）

## 環境変数（必須）

- **`DATABASE_URL`**: Postgres接続文字列
  - 例: `postgresql://USER:PASSWORD@HOST:5432/DB?schema=public`
- **`AUTH_SECRET`**: セッションCookie(JWT)署名キー（十分長いランダム文字列にする）
- **`EMAIL_MODE`**:
  - 開発: `console`（認証コードをサーバーログに出力）
  - 本番: 送信サービス（Resend/SendGrid等）に合わせて実装を追加してください

## Prisma（本番）

### マイグレーション

1) ローカルでマイグレーションを作成

```bash
npm run db:migrate
```

2) 本番（CI/Vercelのビルド前後）で適用

```bash
npm run db:deploy
```

### seed（任意）

本番でカテゴリが空の場合のみ実行:

```bash
npm run db:seed
```

## Vercel手順（概略）

- Vercelに `service-web/web` をプロジェクトとして追加
- Environment Variables に上記3つを登録
- Build は標準（`npm run build`）でOK
- DBは外部Postgresを用意して `DATABASE_URL` をセット

## 運用メモ（最小）

- **バックアップ**: DB側（Neon/Supabase/RDS）で定期バックアップを有効化
- **不正対策**: ログイン/チャットのレート制限はMVPとして最低限実装済み（必要に応じて強化）
- **凍結対応**: 管理画面 `/admin/users` でユーザー停止が可能

