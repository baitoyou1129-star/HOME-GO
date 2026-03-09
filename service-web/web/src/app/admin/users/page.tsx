import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { setUserSuspended } from "./actions";

export default async function AdminUsersPage() {
  await requireAdmin();

  type UserItem = {
    id: string;
    email: string;
    isAdmin: boolean;
    isSuspended: boolean;
    createdAt: Date;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };

  const users = (await prisma.user.findMany({
    orderBy: { createdAt: "desc" },
    take: 200,
    include: { profile: true, providerProfile: true },
  })) as UserItem[];

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-5xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">ユーザー管理</h1>
            <p className="mt-1 text-sm text-zinc-600">停止/復帰（最小）</p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/admin">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white">
          <div className="divide-y divide-zinc-200">
            {users.map((u) => (
              <div key={u.id} className="flex flex-col gap-2 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="text-sm font-medium">
                    {u.profile?.displayName ?? u.providerProfile?.displayName ?? u.email}
                    {u.isAdmin ? (
                      <span className="ml-2 rounded-full border border-zinc-200 bg-white px-2 py-0.5 text-xs text-zinc-700">
                        admin
                      </span>
                    ) : null}
                  </div>
                  <div className="mt-1 text-xs text-zinc-600">
                    {u.email} ・ 作成: {u.createdAt.toLocaleDateString("ja-JP")}
                  </div>
                </div>

                <form action={setUserSuspended}>
                  <input type="hidden" name="userId" value={u.id} />
                  <input type="hidden" name="suspend" value={u.isSuspended ? "false" : "true"} />
                  <button
                    className={`inline-flex h-9 items-center justify-center rounded-md px-3 text-sm font-medium ${
                      u.isSuspended
                        ? "border border-zinc-200 bg-white hover:bg-zinc-50"
                        : "bg-zinc-900 text-white hover:bg-zinc-800"
                    }`}
                  >
                    {u.isSuspended ? "停止解除" : "停止"}
                  </button>
                </form>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}

