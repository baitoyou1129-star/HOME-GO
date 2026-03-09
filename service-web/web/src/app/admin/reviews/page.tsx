import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { setReviewHidden } from "./actions";

export default async function AdminReviewsPage() {
  await requireAdmin();

  type NameableUser = {
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type ReviewItem = {
    id: string;
    rating: number;
    comment: string;
    isHidden: boolean;
    hiddenReason: string | null;
    createdAt: Date;
    author: NameableUser;
    target: NameableUser;
    booking: { category: { name: string } };
  };

  const reviews = (await prisma.review.findMany({
    orderBy: { createdAt: "desc" },
    take: 200,
    include: {
      author: { include: { profile: true } },
      target: { include: { providerProfile: true, profile: true } },
      booking: { include: { category: true } },
    },
  })) as ReviewItem[];

  const nameOf = (u: NameableUser) =>
    u.providerProfile?.displayName ?? u.profile?.displayName ?? u.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">レビュー管理</h1>
            <p className="mt-1 text-sm text-zinc-600">非表示/復帰（最小）</p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/admin">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white">
          <div className="divide-y divide-zinc-200">
            {reviews.map((r) => (
              <div key={r.id} className="p-4">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="text-sm font-medium">
                      {r.booking.category.name} / {nameOf(r.target)}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      投稿者: {nameOf(r.author)} ・ ★{r.rating} ・{" "}
                      {r.createdAt.toLocaleDateString("ja-JP")}
                      {r.isHidden ? " ・ 非表示" : ""}
                    </div>
                    {r.comment ? (
                      <div className="mt-2 whitespace-pre-wrap text-sm text-zinc-700">
                        {r.comment}
                      </div>
                    ) : null}
                    {r.isHidden && r.hiddenReason ? (
                      <div className="mt-2 text-xs text-zinc-600">
                        理由: {r.hiddenReason}
                      </div>
                    ) : null}
                  </div>

                  <form action={setReviewHidden} className="flex flex-col gap-2 sm:items-end">
                    <input type="hidden" name="reviewId" value={r.id} />
                    <input
                      type="hidden"
                      name="hide"
                      value={r.isHidden ? "false" : "true"}
                    />
                    {!r.isHidden ? (
                      <input
                        name="reason"
                        placeholder="非表示理由（任意）"
                        className="h-9 w-full rounded-md border border-zinc-200 px-3 text-sm sm:w-64"
                      />
                    ) : null}
                    <button
                      className={`inline-flex h-9 items-center justify-center rounded-md px-3 text-sm font-medium ${
                        r.isHidden
                          ? "border border-zinc-200 bg-white hover:bg-zinc-50"
                          : "bg-zinc-900 text-white hover:bg-zinc-800"
                      }`}
                    >
                      {r.isHidden ? "表示に戻す" : "非表示"}
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

