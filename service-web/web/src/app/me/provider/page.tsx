import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";
import { listServiceCategories } from "@/lib/categories";
import { upsertMyProviderProfile } from "./actions";

export default async function MyProviderPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/me/provider");

  type Category = { id: string; name: string };
  type ProviderService = {
    categoryId: string;
    isActive: boolean;
    priceYenPerHour: number;
  };
  type ProviderProfile = {
    displayName: string;
    bio: string;
    areaPref: string | null;
    areaCity: string | null;
    availabilityNote: string;
    services: ProviderService[];
  };

  const categories = (await listServiceCategories()) as Category[];

  const provider = (await prisma.providerProfile.findUnique({
    where: { userId: user.id },
    include: { services: true },
  })) as ProviderProfile | null;

  const serviceByCategoryId = new Map(
    (provider?.services ?? []).map((s) => [s.categoryId, s]),
  );

  const defaultName =
    provider?.displayName ??
    user.profile?.displayName ??
    user.email.split("@")[0] ??
    "提供者";

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold tracking-tight">
              提供者プロフィール
            </h1>
            <p className="text-sm text-zinc-600">
              ここで設定した内容が提供者一覧/詳細に表示されます。
            </p>
          </div>
          <div className="flex flex-col items-end gap-2">
            <Link className="text-sm text-zinc-700 hover:underline" href="/app">
              戻る
            </Link>
            <Link
              className="text-sm text-zinc-700 hover:underline"
              href="/providers"
            >
              公開ページを見る
            </Link>
          </div>
        </header>

        <form
          action={upsertMyProviderProfile}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <label className="block text-sm font-medium text-zinc-800">
            表示名
          </label>
          <input
            name="displayName"
            required
            defaultValue={defaultName}
            className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
          />

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                都道府県（任意）
              </label>
              <input
                name="areaPref"
                defaultValue={provider?.areaPref ?? ""}
                placeholder="例: 東京都"
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                市区町村（任意）
              </label>
              <input
                name="areaCity"
                defaultValue={provider?.areaCity ?? ""}
                placeholder="例: 新宿区"
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
              />
            </div>
          </div>

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            自己紹介
          </label>
          <textarea
            name="bio"
            defaultValue={provider?.bio ?? ""}
            className="mt-2 h-28 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
            placeholder="例: 丁寧な家事が得意です。"
          />

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            稼働可能日時（任意）
          </label>
          <textarea
            name="availabilityNote"
            defaultValue={provider?.availabilityNote ?? ""}
            className="mt-2 h-20 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
            placeholder="例: 平日 9:00-17:00 / 土日応相談"
          />

          <div className="mt-6">
            <h2 className="text-sm font-semibold text-zinc-900">提供サービス</h2>
            <p className="mt-1 text-xs text-zinc-600">
              チェックしたサービスが一覧に表示されます。料金は「円/時」です。
            </p>
            <div className="mt-3 flex flex-col gap-2">
              {categories.map((c) => {
                const svc = serviceByCategoryId.get(c.id);
                const isActive = svc?.isActive ?? false;
                const price = svc?.priceYenPerHour ?? "";
                return (
                  <div
                    key={c.id}
                    className="flex flex-col gap-2 rounded-md border border-zinc-200 p-4 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <label className="flex items-center gap-2 text-sm font-medium">
                      <input
                        type="checkbox"
                        name={`svc_${c.id}_active`}
                        defaultChecked={isActive}
                        className="h-4 w-4"
                      />
                      {c.name}
                    </label>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-zinc-600">料金</span>
                      <input
                        name={`svc_${c.id}_price`}
                        defaultValue={price}
                        inputMode="numeric"
                        className="w-40 rounded-md border border-zinc-200 px-3 py-2 text-sm"
                        placeholder="例: 3000"
                      />
                      <span className="text-xs text-zinc-600">円/時</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <button className="mt-6 inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
            保存
          </button>
        </form>
      </main>
    </div>
  );
}

