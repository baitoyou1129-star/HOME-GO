import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import { createBookingRequest } from "./actions";

export default async function BookingRequestPage({
  params,
}: {
  params: { providerId: string };
}) {
  const user = await getCurrentUser();
  if (!user) redirect(`/login?next=/providers/${params.providerId}/book`);

  type ProviderService = {
    id: string;
    categoryId: string;
    priceYenPerHour: number;
    category: { name: string };
  };
  type ProviderProfile = { id: string; displayName: string; services: ProviderService[] };

  const provider = (await prisma.providerProfile.findUnique({
    where: { id: params.providerId },
    include: {
      services: {
        where: { isActive: true },
        include: { category: true },
        orderBy: { priceYenPerHour: "asc" },
      },
    },
  })) as ProviderProfile | null;
  if (!provider) notFound();

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-2xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold tracking-tight">予約リクエスト</h1>
            <p className="text-sm text-zinc-600">
              {provider.displayName} へ予約リクエストを送信します。
            </p>
          </div>
          <Link
            className="text-sm text-zinc-700 hover:underline"
            href={`/providers/${provider.id}`}
          >
            戻る
          </Link>
        </header>

        <form
          action={createBookingRequest}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <input type="hidden" name="providerProfileId" value={provider.id} />

          <label className="block text-sm font-medium text-zinc-800">
            サービス
          </label>
          <select
            name="categoryId"
            required
            className="mt-2 w-full rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
          >
            {provider.services.map((s) => (
              <option key={s.id} value={s.categoryId}>
                {s.category.name}（{s.priceYenPerHour.toLocaleString()}円/時）
              </option>
            ))}
          </select>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                日時
              </label>
              <input
                type="datetime-local"
                name="scheduledAt"
                required
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                予定時間（分）
              </label>
              <input
                name="durationMinutes"
                defaultValue={120}
                inputMode="numeric"
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
              />
            </div>
          </div>

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            場所（市区町村レベル推奨）
          </label>
          <input
            name="locationText"
            required
            placeholder="例: 東京都 新宿区 付近"
            className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
          />

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            メモ（任意）
          </label>
          <textarea
            name="notes"
            className="mt-2 h-28 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm"
            placeholder="例: 掃除道具はこちらで用意します。"
          />

          <button className="mt-5 inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
            リクエスト送信
          </button>
        </form>
      </main>
    </div>
  );
}

