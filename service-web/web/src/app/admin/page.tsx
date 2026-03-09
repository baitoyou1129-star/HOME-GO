import Link from "next/link";
import { requireAdmin } from "@/lib/admin";

export default async function AdminHomePage() {
  await requireAdmin();

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">管理</h1>
            <p className="mt-1 text-sm text-zinc-600">
              通報対応、ユーザー停止、レビュー/台帳の最小管理。
            </p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/app">
            戻る
          </Link>
        </header>

        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Link
            href="/admin/users"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">ユーザー</div>
            <div className="mt-1 text-xs text-zinc-600">停止/復帰</div>
          </Link>
          <Link
            href="/admin/reviews"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">レビュー</div>
            <div className="mt-1 text-xs text-zinc-600">非表示/復帰</div>
          </Link>
          <Link
            href="/admin/messages"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">チャット</div>
            <div className="mt-1 text-xs text-zinc-600">メッセージ確認/削除</div>
          </Link>
          <Link
            href="/admin/ledgers"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">手数料台帳</div>
            <div className="mt-1 text-xs text-zinc-600">支払済み更新</div>
          </Link>
          <Link
            href="/admin/reports"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">通報</div>
            <div className="mt-1 text-xs text-zinc-600">ステータス更新</div>
          </Link>
          <Link
            href="/admin/messages"
            className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
          >
            <div className="text-sm font-semibold">チャット</div>
            <div className="mt-1 text-xs text-zinc-600">確認/削除（本文置換）</div>
          </Link>
        </section>
      </main>
    </div>
  );
}

