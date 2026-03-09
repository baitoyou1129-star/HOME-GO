import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { LogoutButton } from "@/components/LogoutButton";

export default async function AppHomePage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/app");

  const name = user.profile?.displayName ?? user.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold tracking-tight">ダッシュボード</h1>
            <p className="text-sm text-zinc-600">{name} としてログイン中</p>
          </div>
          <LogoutButton />
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-zinc-900">メニュー</h2>
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Link
              href="/me/profile"
              className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
            >
              <div className="text-sm font-medium">プロフィール</div>
              <div className="mt-1 text-xs text-zinc-600">
                表示名/エリア/自己紹介を編集
              </div>
            </Link>
            <Link
              href="/providers"
              className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
            >
              <div className="text-sm font-medium">提供者を探す</div>
              <div className="mt-1 text-xs text-zinc-600">
                サービス種別・エリア・価格で検索
              </div>
            </Link>
            <Link
              href="/me/provider"
              className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
            >
              <div className="text-sm font-medium">提供者として登録/編集</div>
              <div className="mt-1 text-xs text-zinc-600">
                提供サービス・料金・稼働可能日時を設定
              </div>
            </Link>
            <Link
              href="/bookings"
              className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
            >
              <div className="text-sm font-medium">予約一覧</div>
              <div className="mt-1 text-xs text-zinc-600">
                依頼/受注の予約とチャットを確認
              </div>
            </Link>
            <Link
              href="/me/ledgers"
              className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
            >
              <div className="text-sm font-medium">手数料台帳</div>
              <div className="mt-1 text-xs text-zinc-600">
                完了案件の手数料10%（未払い/支払済み）を確認
              </div>
            </Link>
            {user.isAdmin ? (
              <Link
                href="/admin"
                className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
              >
                <div className="text-sm font-medium">管理</div>
                <div className="mt-1 text-xs text-zinc-600">
                  通報/凍結/レビュー/台帳
                </div>
              </Link>
            ) : null}
          </div>
        </section>
      </main>
    </div>
  );
}

