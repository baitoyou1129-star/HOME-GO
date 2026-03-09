import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";

function ledgerStatusLabel(status: string) {
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

export default async function MyLedgersPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/me/ledgers");

  type NameableUser = {
    email: string;
    profile?: { displayName: string } | null;
  };
  type LedgerItem = {
    id: string;
    bookingId: string;
    commissionYen: number;
    status: string;
    booking: {
      completedAt: Date | null;
      category: { name: string };
      client: NameableUser;
    };
  };

  const ledgers = (await prisma.commissionLedger.findMany({
    where: { booking: { providerId: user.id } },
    orderBy: { createdAt: "desc" },
    take: 100,
    include: {
      booking: {
        include: {
          category: true,
          client: { include: { profile: true } },
        },
      },
    },
  })) as LedgerItem[];

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-10">
        <header className="flex items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">手数料台帳</h1>
            <p className="mt-1 text-sm text-zinc-600">
              完了した案件の手数料（10%）の記録です。
            </p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/app">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          {ledgers.length === 0 ? (
            <div className="text-sm text-zinc-700">
              まだ台帳がありません（案件が完了すると自動作成されます）。
            </div>
          ) : null}

          <div className="mt-2 flex flex-col gap-2">
            {ledgers.map((l) => (
              <Link
                key={l.id}
                href={`/bookings/${l.bookingId}`}
                className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="text-sm font-medium">
                      {l.booking.category.name} /{" "}
                      {l.booking.client.profile?.displayName ?? l.booking.client.email}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      完了日:{" "}
                      {l.booking.completedAt
                        ? l.booking.completedAt.toLocaleDateString("ja-JP")
                        : "-"}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">
                      手数料 {l.commissionYen.toLocaleString()}円
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      {ledgerStatusLabel(l.status)}
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}

