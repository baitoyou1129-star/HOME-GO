import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-zinc-50 text-zinc-900">
      <main className="mx-auto flex max-w-3xl flex-col gap-8 px-6 py-16">
        <header className="flex flex-col gap-2">
          <h1 className="text-3xl font-semibold tracking-tight">
            訪問型サービスMVP
          </h1>
          <p className="text-zinc-600">
            家政婦/掃除/ベビー/見守り/ペットなどの訪問型サービスを、検索→予約→チャット→完了→レビューまで最小構成で提供します。
          </p>
        </header>

        <div className="flex flex-col gap-3 sm:flex-row">
          <Link
            className="inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800"
            href="/login"
          >
            ログイン / 登録
          </Link>
          <Link
            className="inline-flex h-11 items-center justify-center rounded-md border border-zinc-200 bg-white px-4 text-sm font-medium hover:bg-zinc-50"
            href="/app"
          >
            ダッシュボードへ
          </Link>
        </div>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-base font-semibold">MVPでできること</h2>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-zinc-700">
            <li>メール認証（ワンタイムコード）</li>
            <li>提供者プロフィール/サービス設定</li>
            <li>検索/一覧/詳細</li>
            <li>予約リクエスト→承認→成立</li>
            <li>案件単位の1対1チャット</li>
            <li>完了処理と手数料10%台帳</li>
            <li>レビュー（星＋コメント）</li>
          </ul>
        </section>
      </main>
    </div>
  );
}
