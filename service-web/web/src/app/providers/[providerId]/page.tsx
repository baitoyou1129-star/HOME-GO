import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/prisma";

export default async function ProviderDetailPage({
  params,
}: {
  params: { providerId: string };
}) {
  const { providerId } = params;

  type ProviderService = {
    id: string;
    priceYenPerHour: number;
    category: { name: string };
  };
  type ProviderProfile = {
    id: string;
    userId: string;
    displayName: string;
    bio: string;
    areaPref: string | null;
    areaCity: string | null;
    availabilityNote: string;
    services: ProviderService[];
  };
  type ReviewItem = {
    id: string;
    rating: number;
    comment: string;
    createdAt: Date;
    author: { profile?: { displayName: string } | null };
  };

  const provider = (await prisma.providerProfile.findUnique({
    where: { id: providerId },
    include: {
      services: {
        where: { isActive: true },
        include: { category: true },
        orderBy: { priceYenPerHour: "asc" },
      },
      user: true,
    },
  })) as ProviderProfile | null;
  if (!provider) notFound();

  const reviews = (await prisma.review.findMany({
    where: { targetUserId: provider.userId, isHidden: false },
    orderBy: { createdAt: "desc" },
    take: 20,
    include: { author: { include: { profile: true } } },
  })) as ReviewItem[];

  const avg =
    reviews.length > 0
      ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length
      : null;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold tracking-tight">
              {provider.displayName}
            </h1>
            <p className="text-sm text-zinc-600">
              {(provider.areaPref ?? "未設定") + " " + (provider.areaCity ?? "")}
            </p>
            <p className="mt-1 text-sm text-zinc-700">{provider.bio}</p>
            <p className="mt-2 text-xs text-zinc-600">
              稼働可能日時: {provider.availabilityNote || "未設定"}
            </p>
          </div>
          <div className="flex flex-col items-end gap-2">
            <Link className="text-sm text-zinc-700 hover:underline" href="/providers">
              一覧へ
            </Link>
            <Link
              className="inline-flex h-10 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800"
              href={`/providers/${provider.id}/book`}
            >
              予約リクエスト
            </Link>
          </div>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-zinc-900">提供サービス</h2>
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            {provider.services.map((s) => (
              <div
                key={s.id}
                className="rounded-md border border-zinc-200 p-4"
              >
                <div className="text-sm font-medium">{s.category.name}</div>
                <div className="mt-1 text-sm text-zinc-700">
                  {s.priceYenPerHour.toLocaleString()}円/時
                </div>
              </div>
            ))}
            {provider.services.length === 0 ? (
              <div className="text-sm text-zinc-700">提供サービスが未設定です。</div>
            ) : null}
          </div>
        </section>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-zinc-900">レビュー</h2>
            <div className="text-xs text-zinc-600">
              {avg ? `平均 ★${avg.toFixed(1)}（${reviews.length}件）` : "評価なし"}
            </div>
          </div>
          <div className="mt-3 flex flex-col gap-3">
            {reviews.length === 0 ? (
              <div className="text-sm text-zinc-700">まだレビューがありません。</div>
            ) : null}
            {reviews.map((r) => (
              <div key={r.id} className="rounded-md border border-zinc-200 p-4">
                <div className="flex items-center justify-between gap-4">
                  <div className="text-sm font-medium">
                    {r.author.profile?.displayName ?? "依頼者"}
                  </div>
                  <div className="text-sm text-zinc-800">★{r.rating}</div>
                </div>
                {r.comment ? (
                  <p className="mt-2 text-sm text-zinc-700">{r.comment}</p>
                ) : null}
                <div className="mt-2 text-xs text-zinc-500">
                  {r.createdAt.toLocaleDateString("ja-JP")}
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}

