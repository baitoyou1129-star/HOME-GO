import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { updateReportStatus } from "./actions";

function label(status: string) {
  switch (status) {
    case "open":
      return "未対応";
    case "in_progress":
      return "対応中";
    case "closed":
      return "クローズ";
    default:
      return status;
  }
}

function labelTarget(type: string) {
  switch (type) {
    case "user":
      return "ユーザー";
    case "booking":
      return "予約（案件）";
    case "message":
      return "チャット";
    case "review":
      return "レビュー";
    default:
      return type;
  }
}

export default async function AdminReportsPage() {
  await requireAdmin();

  type NameableUser = {
    id?: string;
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type ReportItem = {
    id: string;
    reporter: NameableUser;
    targetType: string;
    targetId: string;
    reason: string;
    details: string;
    status: string;
    createdAt: Date;
  };
  type BookingItem = {
    id: string;
    category: { name: string };
    client: NameableUser;
    provider: NameableUser;
  };

  const reports = (await prisma.report.findMany({
    orderBy: [{ status: "asc" }, { createdAt: "desc" }],
    take: 200,
    include: {
      reporter: { include: { profile: true, providerProfile: true } },
    },
  })) as ReportItem[];

  const bookingIds = reports
    .filter((r) => r.targetType === "booking")
    .map((r) => r.targetId);
  const userIds = reports.filter((r) => r.targetType === "user").map((r) => r.targetId);

  const bookings = bookingIds.length
    ? ((await prisma.booking.findMany({
        where: { id: { in: bookingIds } },
        include: {
          category: true,
          client: { include: { profile: true } },
          provider: { include: { providerProfile: true, profile: true } },
        },
      })) as BookingItem[])
    : [];

  const users = userIds.length
    ? ((await prisma.user.findMany({
        where: { id: { in: userIds } },
        include: { profile: true, providerProfile: true },
      })) as NameableUser[])
    : [];

  const bookingById = new Map(bookings.map((b) => [b.id, b]));
  const userById = new Map(users.map((u) => [u.id, u]));

  const nameOf = (u: NameableUser | null | undefined) =>
    u?.providerProfile?.displayName ?? u?.profile?.displayName ?? u?.email ?? "-";

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">通報</h1>
            <p className="mt-1 text-sm text-zinc-600">ステータス更新（最小）</p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/admin">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white">
          <div className="divide-y divide-zinc-200">
            {reports.length === 0 ? (
              <div className="p-6 text-sm text-zinc-700">通報はまだありません。</div>
            ) : null}

            {reports.map((r) => {
              const booking = r.targetType === "booking" ? bookingById.get(r.targetId) : null;
              const targetUser = r.targetType === "user" ? userById.get(r.targetId) : null;
              return (
                <div key={r.id} className="p-4">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                      <div className="text-sm font-medium">
                        {labelTarget(r.targetType)} ・ {label(r.status)}
                      </div>
                      <div className="mt-1 text-xs text-zinc-600">
                        通報者: {nameOf(r.reporter)} ・ {r.createdAt.toLocaleDateString("ja-JP")}
                      </div>

                      <div className="mt-2 text-sm text-zinc-700">
                        <div>
                          <span className="text-zinc-500">理由:</span> {r.reason}
                        </div>
                        {r.details ? (
                          <div className="mt-1 whitespace-pre-wrap">
                            <span className="text-zinc-500">詳細:</span> {r.details}
                          </div>
                        ) : null}
                      </div>

                      <div className="mt-3 rounded-md border border-zinc-200 bg-zinc-50 p-3 text-xs text-zinc-700">
                        <div>
                          <span className="text-zinc-500">targetId:</span> {r.targetId}
                        </div>
                        {booking ? (
                          <div className="mt-1">
                            {booking.category.name} / 依頼者: {nameOf(booking.client)} / 提供者:{" "}
                            {nameOf(booking.provider)}{" "}
                            <Link
                              className="ml-2 text-zinc-700 underline"
                              href={`/bookings/${booking.id}`}
                            >
                              予約を見る
                            </Link>
                          </div>
                        ) : null}
                        {targetUser ? (
                          <div className="mt-1">
                            対象ユーザー: {nameOf(targetUser)}（{targetUser.email}）
                          </div>
                        ) : null}
                      </div>
                    </div>

                    <form action={updateReportStatus} className="flex flex-col gap-2 sm:items-end">
                      <input type="hidden" name="reportId" value={r.id} />
                      <select
                        name="status"
                        defaultValue={r.status}
                        className="h-9 w-full rounded-md border border-zinc-200 bg-white px-3 text-sm sm:w-40"
                      >
                        <option value="open">未対応</option>
                        <option value="in_progress">対応中</option>
                        <option value="closed">クローズ</option>
                      </select>
                      <button className="inline-flex h-9 items-center justify-center rounded-md bg-zinc-900 px-3 text-sm font-medium text-white hover:bg-zinc-800">
                        更新
                      </button>
                    </form>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      </main>
    </div>
  );
}

