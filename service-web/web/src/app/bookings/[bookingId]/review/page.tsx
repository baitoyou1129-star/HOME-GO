import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";
import { createReview } from "./actions";

export default async function ReviewPage({
  params,
}: {
  params: { bookingId: string };
}) {
  const user = await getCurrentUser();
  if (!user) redirect(`/login?next=/bookings/${params.bookingId}/review`);

  const booking = await prisma.booking.findUnique({
    where: { id: params.bookingId },
    include: {
      category: true,
      provider: { include: { providerProfile: true, profile: true } },
      review: true,
    },
  });
  if (!booking) notFound();
  if (booking.clientId !== user.id) redirect(`/bookings/${booking.id}`);
  if (booking.status !== "completed") redirect(`/bookings/${booking.id}`);
  if (booking.review) redirect(`/bookings/${booking.id}`);

  const providerName =
    booking.provider.providerProfile?.displayName ??
    booking.provider.profile?.displayName ??
    booking.provider.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-2xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">レビュー投稿</h1>
            <p className="mt-1 text-sm text-zinc-600">
              {booking.category.name} / {providerName}
            </p>
          </div>
          <Link
            className="text-sm text-zinc-700 hover:underline"
            href={`/bookings/${booking.id}`}
          >
            戻る
          </Link>
        </header>

        <form
          action={createReview}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <input type="hidden" name="bookingId" value={booking.id} />

          <label className="block text-sm font-medium text-zinc-800">
            評価（1〜5）
          </label>
          <select
            name="rating"
            defaultValue={5}
            className="mt-2 w-full rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
          >
            <option value={5}>★★★★★ (5)</option>
            <option value={4}>★★★★☆ (4)</option>
            <option value={3}>★★★☆☆ (3)</option>
            <option value={2}>★★☆☆☆ (2)</option>
            <option value={1}>★☆☆☆☆ (1)</option>
          </select>

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            コメント（任意）
          </label>
          <textarea
            name="comment"
            className="mt-2 h-32 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm"
            placeholder="例: 丁寧で安心できました。"
          />

          <button className="mt-5 inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
            投稿
          </button>
        </form>
      </main>
    </div>
  );
}

