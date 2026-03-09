import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";

function statusLabel(status: string) {
  switch (status) {
    case "requested":
      return "リクエスト中";
    case "accepted":
      return "成立";
    case "cancelled":
      return "キャンセル";
    case "completed":
      return "完了";
    default:
      return status;
  }
}

export default async function BookingsPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/bookings");

  type NameableUser = {
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type BookingAsClientItem = {
    id: string;
    status: string;
    scheduledAt: Date;
    durationMinutes: number;
    locationText: string;
    category: { name: string };
    provider: NameableUser;
  };
  type BookingAsProviderItem = {
    id: string;
    status: string;
    scheduledAt: Date;
    durationMinutes: number;
    locationText: string;
    category: { name: string };
    client: NameableUser;
  };

  const asClient = (await prisma.booking.findMany({
    where: { clientId: user.id },
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      category: true,
      provider: { include: { providerProfile: true, profile: true } },
    },
  })) as BookingAsClientItem[];

  const asProvider = (await prisma.booking.findMany({
    where: { providerId: user.id },
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      category: true,
      client: { include: { profile: true } },
    },
  })) as BookingAsProviderItem[];

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-10">
        <header className="flex items-center justify-between gap-4">
          <h1 className="text-2xl font-semibold tracking-tight">予約一覧</h1>
          <Link className="text-sm text-zinc-700 hover:underline" href="/app">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-zinc-900">依頼した予約</h2>
          <div className="mt-3 flex flex-col gap-2">
            {asClient.length === 0 ? (
              <div className="text-sm text-zinc-700">
                予約はまだありません。{" "}
                <Link className="underline" href="/providers">
                  提供者を探す
                </Link>
              </div>
            ) : null}
            {asClient.map((b) => (
              <Link
                key={b.id}
                href={`/bookings/${b.id}`}
                className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="text-sm font-medium">
                      {b.category.name} /{" "}
                      {b.provider.providerProfile?.displayName ??
                        b.provider.profile?.displayName ??
                        b.provider.email}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      {b.scheduledAt.toLocaleString("ja-JP")} ・ {b.durationMinutes}
                      分 ・ {b.locationText}
                    </div>
                  </div>
                  <div className="text-xs text-zinc-700">
                    {statusLabel(b.status)}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-zinc-900">受けた予約</h2>
          <div className="mt-3 flex flex-col gap-2">
            {asProvider.length === 0 ? (
              <div className="text-sm text-zinc-700">
                受けた予約はまだありません。提供者として公開するには{" "}
                <Link className="underline" href="/me/provider">
                  提供者プロフィール
                </Link>{" "}
                を設定してください。
              </div>
            ) : null}
            {asProvider.map((b) => (
              <Link
                key={b.id}
                href={`/bookings/${b.id}`}
                className="rounded-md border border-zinc-200 p-4 hover:bg-zinc-50"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="text-sm font-medium">
                      {b.category.name} /{" "}
                      {b.client.profile?.displayName ?? b.client.email}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      {b.scheduledAt.toLocaleString("ja-JP")} ・ {b.durationMinutes}
                      分 ・ {b.locationText}
                    </div>
                  </div>
                  <div className="text-xs text-zinc-700">
                    {statusLabel(b.status)}
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

