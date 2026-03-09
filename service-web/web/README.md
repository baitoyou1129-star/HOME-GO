# 訪問型サービスMVP（Web）

Next.js(App Router) + Prisma(Postgres) で、訪問型サービスのMVP（メール認証/提供者検索/予約/チャット/完了/台帳/レビュー/管理）を実装するプロジェクトです。

## ローカル起動（開発）

### 1) 環境変数を用意

`.env.example` を `.env` にコピーして `AUTH_SECRET` を変更してください。

### 2) Postgresを起動（Docker）

```bash
npm run db:up
```

### 3) DBマイグレーション & seed

```bash
npm run db:migrate
npm run db:seed
```

### 4) 開発サーバ起動

```bash
npm run dev
```

`http://localhost:3000` を開きます。

## ログイン（メール認証）

- `EMAIL_MODE="console"` の場合、認証コードは **開発サーバのログに出力**されます。
- 画面は `/login` → `/verify` → `/app` の順です。

## デプロイ/運用

`DEPLOYMENT.md` を参照してください。

