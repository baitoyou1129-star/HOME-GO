import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { updateLedgerStatus } from "./actions";

function label(status: string) {
  switch (status) {
    case "unpaid":
      return "未払い";
    case "paid":
      return "支払済み";
    case "waived":
      return "免除";
    default:
      return status;
  }
}

export default async function AdminLedgersPage() {
  await requireAdmin();

  type NameableUser = {
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type LedgerItem = {
    id: string;
    bookingId: string;
    amountYen: number;
    commissionYen: number;
    status: string;
    adminNote: string | null;
    paidAt: Date | null;
    booking: {
      id: string;
      completedAt: Date | null;
      category: { name: string };
      client: NameableUser;
      provider: NameableUser;
    };
  };

  const ledgers = (await prisma.commissionLedger.findMany({
    orderBy: [{ status: "asc" }, { createdAt: "desc" }],
    take: 200,
    include: {
      booking: {
        include: {
          category: true,
          client: { include: { profile: true } },
          provider: { include: { providerProfile: true, profile: true } },
        },
      },
    },
  })) as LedgerItem[];

  const nameOf = (u: NameableUser) =>
    u.providerProfile?.displayName ?? u.profile?.displayName ?? u.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">手数料台帳</h1>
            <p className="mt-1 text-sm text-zinc-600">
              支払済み更新（MVP）
            </p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/admin">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white">
          <div className="divide-y divide-zinc-200">
            {ledgers.map((l) => (
              <div key={l.id} className="p-4">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="text-sm font-medium">
                      {l.booking.category.name} / 提供者: {nameOf(l.booking.provider)}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      依頼者: {nameOf(l.booking.client)} ・ 完了:{" "}
                      {l.booking.completedAt
                        ? l.booking.completedAt.toLocaleDateString("ja-JP")
                        : "-"}
                      {" ・ "}案件金額: {l.amountYen.toLocaleString()}円{" ・ "}
                      手数料: {l.commissionYen.toLocaleString()}円
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      現在: {label(l.status)}
                      {l.paidAt ? `（支払日: ${l.paidAt.toLocaleDateString("ja-JP")}）` : ""}
                    </div>
                    <div className="mt-2">
                      <Link
                        className="text-sm text-zinc-700 hover:underline"
                        href={`/bookings/${l.bookingId}`}
                      >
                        予約を見る
                      </Link>
                    </div>
                  </div>

                  <form action={updateLedgerStatus} className="flex flex-col gap-2 sm:items-end">
                    <input type="hidden" name="ledgerId" value={l.id} />
                    <select
                      name="status"
                      defaultValue={l.status}
                      className="h-9 w-full rounded-md border border-zinc-200 bg-white px-3 text-sm sm:w-40"
                    >
                      <option value="unpaid">未払い</option>
                      <option value="paid">支払済み</option>
                      <option value="waived">免除</option>
                    </select>
                    <input
                      name="adminNote"
                      defaultValue={l.adminNote ?? ""}
                      placeholder="メモ（任意）"
                      className="h-9 w-full rounded-md border border-zinc-200 px-3 text-sm sm:w-64"
                    />
                    <button className="inline-flex h-9 items-center justify-center rounded-md bg-zinc-900 px-3 text-sm font-medium text-white hover:bg-zinc-800">
                      更新
                    </button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}

