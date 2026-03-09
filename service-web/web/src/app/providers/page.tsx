import Link from "next/link";
import { prisma } from "@/lib/prisma";
import { listServiceCategories } from "@/lib/categories";

type Category = { id: string; name: string };
type ProviderListItem = {
  id: string;
  userId: string;
  displayName: string;
  bio: string;
  areaPref: string | null;
  areaCity: string | null;
  availabilityNote: string;
  updatedAt: Date;
  services: Array<{
    id: string;
    categoryId: string;
    priceYenPerHour: number;
    isActive: boolean;
    category: { id: string; name: string };
  }>;
  user: { id: string; email: string };
};

function toInt(v: string | null | undefined) {
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

export default async function ProvidersPage({
  searchParams,
}: {
  searchParams?: Record<string, string | string[] | undefined>;
}) {
  const sp = searchParams ?? {};

  const categoryId = typeof sp.category === "string" ? sp.category : undefined;
  const pref = typeof sp.pref === "string" ? sp.pref.trim() : "";
  const city = typeof sp.city === "string" ? sp.city.trim() : "";
  const min = toInt(typeof sp.min === "string" ? sp.min : undefined);
  const max = toInt(typeof sp.max === "string" ? sp.max : undefined);
  const minRatingRaw = toInt(typeof sp.minRating === "string" ? sp.minRating : undefined);
  const minRating =
    minRatingRaw !== null && minRatingRaw >= 1 && minRatingRaw <= 5
      ? minRatingRaw
      : null;

  const categories = (await listServiceCategories()) as Category[];

  const serviceWhere: {
    isActive: true;
    categoryId?: string;
    priceYenPerHour?: { gte?: number; lte?: number };
  } = { isActive: true };
  if (categoryId) serviceWhere.categoryId = categoryId;
  if (min !== null || max !== null) {
    serviceWhere.priceYenPerHour = {
      ...(min !== null ? { gte: min } : {}),
      ...(max !== null ? { lte: max } : {}),
    };
  }

  const providers = (await prisma.providerProfile.findMany({
    where: {
      ...(pref ? { areaPref: pref } : {}),
      ...(city ? { areaCity: city } : {}),
      services: { some: serviceWhere },
    },
    include: {
      services: {
        where: { isActive: true, ...(categoryId ? { categoryId } : {}) },
        include: { category: true },
        orderBy: { priceYenPerHour: "asc" },
      },
      user: true,
    },
    orderBy: { updatedAt: "desc" },
    take: 50,
  })) as ProviderListItem[];

  const ratingByUserId = new Map<
    string,
    { avg: number | null; count: number }
  >();
  if (providers.length) {
    const rows = await prisma.review.groupBy({
      by: ["targetUserId"],
      where: {
        targetUserId: { in: providers.map((p) => p.userId) },
        isHidden: false,
      },
      _avg: { rating: true },
      _count: { _all: true },
    });
    for (const r of rows) {
      ratingByUserId.set(r.targetUserId, {
        avg: r._avg.rating ?? null,
        count: r._count._all,
      });
    }
  }

  const filteredProviders =
    minRating !== null
      ? providers.filter((p) => {
          const avg = ratingByUserId.get(p.userId)?.avg ?? null;
          return avg !== null && avg >= minRating;
        })
      : providers;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-4xl flex-col gap-6 px-6 py-10">
        <header className="flex flex-col gap-2">
          <div className="flex items-center justify-between gap-4">
            <h1 className="text-2xl font-semibold tracking-tight">提供者を探す</h1>
            <Link className="text-sm text-zinc-700 hover:underline" href="/app">
              ダッシュボード
            </Link>
          </div>
          <p className="text-sm text-zinc-600">
            サービス種別・エリア・価格帯・評価で絞り込めます。
          </p>
        </header>

        <form className="rounded-lg border border-zinc-200 bg-white p-5">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
            <div>
              <label className="block text-xs font-medium text-zinc-700">
                サービス
              </label>
              <select
                name="category"
                defaultValue={categoryId ?? ""}
                className="mt-1 w-full rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
              >
                <option value="">指定なし</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-medium text-zinc-700">
                都道府県
              </label>
              <input
                name="pref"
                defaultValue={pref}
                placeholder="例: 東京都"
                className="mt-1 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-zinc-700">
                市区町村
              </label>
              <input
                name="city"
                defaultValue={city}
                placeholder="例: 新宿区"
                className="mt-1 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="block text-xs font-medium text-zinc-700">
                  最低(円/時)
                </label>
                <input
                  name="min"
                  defaultValue={min ?? ""}
                  inputMode="numeric"
                  className="mt-1 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-zinc-700">
                  最高(円/時)
                </label>
                <input
                  name="max"
                  defaultValue={max ?? ""}
                  inputMode="numeric"
                  className="mt-1 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-zinc-700">
                評価（最低）
              </label>
              <select
                name="minRating"
                defaultValue={minRating ?? ""}
                className="mt-1 w-full rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
              >
                <option value="">指定なし</option>
                <option value="5">★5以上</option>
                <option value="4">★4以上</option>
                <option value="3">★3以上</option>
                <option value="2">★2以上</option>
                <option value="1">★1以上</option>
              </select>
            </div>
          </div>

          <div className="mt-4 flex items-center gap-3">
            <button className="inline-flex h-10 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
              検索
            </button>
            <Link
              href="/providers"
              className="text-sm text-zinc-700 hover:underline"
            >
              クリア
            </Link>
          </div>
        </form>

        <section className="grid grid-cols-1 gap-3">
          {filteredProviders.length === 0 ? (
            <div className="rounded-lg border border-zinc-200 bg-white p-6 text-sm text-zinc-700">
              条件に合う提供者が見つかりませんでした。提供者側で
              <Link className="mx-1 underline" href="/me/provider">
                提供者プロフィール
              </Link>
              を作成すると一覧に表示されます。
            </div>
          ) : null}

          {filteredProviders.map((p) => {
            const rating = ratingByUserId.get(p.userId);
            const price =
              p.services.length > 0 ? p.services[0].priceYenPerHour : null;
            return (
              <Link
                key={p.id}
                href={`/providers/${p.id}`}
                className="rounded-lg border border-zinc-200 bg-white p-5 hover:bg-zinc-50"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="text-base font-semibold">{p.displayName}</div>
                    <div className="mt-1 text-sm text-zinc-600">
                      {(p.areaPref ?? "未設定") + " " + (p.areaCity ?? "")}
                    </div>
                    <div className="mt-2 flex flex-wrap gap-2">
                      {p.services.slice(0, 4).map((s) => (
                        <span
                          key={s.id}
                          className="rounded-full border border-zinc-200 bg-white px-2 py-0.5 text-xs text-zinc-700"
                        >
                          {s.category.name}
                        </span>
                      ))}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">
                      {price ? `${price.toLocaleString()}円/時〜` : "料金未設定"}
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      {rating?.avg
                        ? `★${rating.avg.toFixed(1)} (${rating.count})`
                        : "評価なし"}
                    </div>
                  </div>
                </div>
                {p.bio ? (
                  <p className="mt-3 line-clamp-2 text-sm text-zinc-700">
                    {p.bio}
                  </p>
                ) : null}
              </Link>
            );
          })}
        </section>
      </main>
    </div>
  );
}

