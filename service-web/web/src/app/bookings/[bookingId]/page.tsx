import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";
import { ChatPanel } from "@/components/ChatPanel";
import {
  acceptBooking,
  cancelBooking,
  markClientComplete,
  markProviderComplete,
} from "./actions";

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

export default async function BookingDetailPage({
  params,
}: {
  params: { bookingId: string };
}) {
  const user = await getCurrentUser();
  if (!user) redirect(`/login?next=/bookings/${params.bookingId}`);

  const booking = await prisma.booking.findUnique({
    where: { id: params.bookingId },
    include: {
      category: true,
      client: { include: { profile: true } },
      provider: { include: { profile: true, providerProfile: true } },
      chatThread: true,
      ledger: true,
      review: true,
    },
  });
  if (!booking) notFound();
  if (booking.clientId !== user.id && booking.providerId !== user.id) {
    redirect("/bookings");
  }

  const viewer = booking.clientId === user.id ? "client" : "provider";
  const otherName =
    viewer === "client"
      ? booking.provider.providerProfile?.displayName ??
        booking.provider.profile?.displayName ??
        booking.provider.email
      : booking.client.profile?.displayName ?? booking.client.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-2xl font-semibold tracking-tight">予約詳細</h1>
            <p className="text-sm text-zinc-600">
              {booking.category.name} / {otherName}
            </p>
          </div>
          <div className="flex items-center gap-4">
            <Link
              className="text-sm text-zinc-700 hover:underline"
              href={`/bookings/${booking.id}/report`}
            >
              通報
            </Link>
            <Link className="text-sm text-zinc-700 hover:underline" href="/bookings">
              一覧へ
            </Link>
          </div>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="text-sm text-zinc-700">
              ステータス:{" "}
              <span className="font-medium text-zinc-900">
                {statusLabel(booking.status)}
              </span>
            </div>
            {booking.priceYenEstimated ? (
              <div className="text-sm text-zinc-700">
                目安:{" "}
                <span className="font-medium text-zinc-900">
                  {booking.priceYenEstimated.toLocaleString()}円
                </span>
              </div>
            ) : null}
          </div>

          <div className="mt-3 grid grid-cols-1 gap-2 text-sm text-zinc-700 sm:grid-cols-2">
            <div>
              <span className="text-zinc-500">日時:</span>{" "}
              {booking.scheduledAt.toLocaleString("ja-JP")}
            </div>
            <div>
              <span className="text-zinc-500">予定:</span> {booking.durationMinutes}
              分
            </div>
            <div className="sm:col-span-2">
              <span className="text-zinc-500">場所:</span> {booking.locationText}
            </div>
            {booking.notes ? (
              <div className="sm:col-span-2">
                <span className="text-zinc-500">メモ:</span> {booking.notes}
              </div>
            ) : null}
          </div>
        </section>

        {booking.status === "requested" ? (
          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h2 className="text-sm font-semibold text-zinc-900">操作</h2>
            <div className="mt-3 flex flex-col gap-3 sm:flex-row">
              {viewer === "provider" ? (
                <form action={acceptBooking}>
                  <input type="hidden" name="bookingId" value={booking.id} />
                  <button className="inline-flex h-10 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
                    承認して成立
                  </button>
                </form>
              ) : null}

              <form action={cancelBooking} className="flex flex-1 gap-2">
                <input type="hidden" name="bookingId" value={booking.id} />
                <input
                  name="reason"
                  placeholder="キャンセル理由（任意）"
                  className="h-10 flex-1 rounded-md border border-zinc-200 px-3 text-sm"
                />
                <button className="inline-flex h-10 items-center justify-center rounded-md border border-zinc-200 bg-white px-4 text-sm font-medium hover:bg-zinc-50">
                  {viewer === "provider" ? "辞退" : "キャンセル"}
                </button>
              </form>
            </div>
          </section>
        ) : null}

        {booking.status === "accepted" ? (
          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h2 className="text-sm font-semibold text-zinc-900">操作</h2>
            <div className="mt-3 flex flex-col gap-3">
              <form action={cancelBooking} className="flex gap-2">
                <input type="hidden" name="bookingId" value={booking.id} />
                <input
                  name="reason"
                  placeholder="キャンセル理由（任意）"
                  className="h-10 flex-1 rounded-md border border-zinc-200 px-3 text-sm"
                />
                <button className="inline-flex h-10 items-center justify-center rounded-md border border-zinc-200 bg-white px-4 text-sm font-medium hover:bg-zinc-50">
                  キャンセル
                </button>
              </form>

              <div className="rounded-md border border-zinc-200 p-4">
                <div className="text-sm font-medium text-zinc-900">
                  完了（双方確認）
                </div>
                <p className="mt-1 text-xs text-zinc-600">
                  依頼者が金額を入力して完了申請 → 提供者が完了承認すると完了になります。
                </p>

                <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center">
                  {viewer === "client" ? (
                    booking.clientMarkedCompleteAt ? (
                      <div className="text-sm text-zinc-700">
                        完了申請済み（確定金額:{" "}
                        <span className="font-medium text-zinc-900">
                          {booking.priceYenFinal?.toLocaleString() ?? "-"}円
                        </span>
                        ）
                      </div>
                    ) : (
                      <form
                        action={markClientComplete}
                        className="flex flex-1 gap-2"
                      >
                        <input
                          type="hidden"
                          name="bookingId"
                          value={booking.id}
                        />
                        <input
                          name="amountYen"
                          inputMode="numeric"
                          required
                          defaultValue={booking.priceYenFinal ?? ""}
                          placeholder="確定金額（円）"
                          className="h-10 flex-1 rounded-md border border-zinc-200 px-3 text-sm"
                        />
                        <button className="inline-flex h-10 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
                          完了申請
                        </button>
                      </form>
                    )
                  ) : (
                    <div className="text-sm text-zinc-700">
                      確定金額:{" "}
                      <span className="font-medium text-zinc-900">
                        {booking.priceYenFinal
                          ? `${booking.priceYenFinal.toLocaleString()}円`
                          : "未入力"}
                      </span>
                    </div>
                  )}

                  {viewer === "provider" ? (
                    <form action={markProviderComplete}>
                      <input type="hidden" name="bookingId" value={booking.id} />
                      <button
                        disabled={
                          !!booking.providerMarkedCompleteAt ||
                          !booking.priceYenFinal
                        }
                        className="inline-flex h-10 items-center justify-center rounded-md border border-zinc-200 bg-white px-4 text-sm font-medium hover:bg-zinc-50 disabled:opacity-60"
                        title={
                          !booking.priceYenFinal
                            ? "依頼者が確定金額を入力してから承認できます"
                            : undefined
                        }
                      >
                        完了承認
                      </button>
                    </form>
                  ) : null}
                </div>

                <div className="mt-3 text-xs text-zinc-600">
                  依頼者:{" "}
                  {booking.clientMarkedCompleteAt ? "完了申請済み" : "未申請"} /{" "}
                  提供者:{" "}
                  {booking.providerMarkedCompleteAt ? "承認済み" : "未承認"}
                </div>
              </div>
            </div>
          </section>
        ) : null}

        {booking.status === "completed" ? (
          <section className="rounded-lg border border-zinc-200 bg-white p-5">
            <h2 className="text-sm font-semibold text-zinc-900">完了</h2>
            <p className="mt-2 text-sm text-zinc-700">
              完了しました。レビューは完了後に投稿できます。
            </p>
            {booking.ledger ? (
              <div className="mt-3 rounded-md border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-700">
                <div>
                  案件金額:{" "}
                  <span className="font-medium text-zinc-900">
                    {booking.ledger.amountYen.toLocaleString()}円
                  </span>
                </div>
                <div className="mt-1">
                  手数料(10%):{" "}
                  <span className="font-medium text-zinc-900">
                    {booking.ledger.commissionYen.toLocaleString()}円
                  </span>{" "}
                  （ステータス: {booking.ledger.status}）
                </div>
              </div>
            ) : (
              <div className="mt-3 text-sm text-zinc-700">
                手数料台帳を作成中です。
              </div>
            )}

            <div className="mt-4 rounded-md border border-zinc-200 p-4">
              <div className="text-sm font-medium text-zinc-900">レビュー</div>
              {booking.review ? (
                <div className="mt-2 text-sm text-zinc-700">
                  <div>評価: ★{booking.review.rating}</div>
                  {booking.review.comment ? (
                    <div className="mt-1 whitespace-pre-wrap">
                      {booking.review.comment}
                    </div>
                  ) : null}
                </div>
              ) : viewer === "client" ? (
                <div className="mt-2">
                  <Link
                    href={`/bookings/${booking.id}/review`}
                    className="inline-flex h-10 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800"
                  >
                    レビューを書く
                  </Link>
                </div>
              ) : (
                <div className="mt-2 text-sm text-zinc-700">
                  依頼者のレビュー待ちです。
                </div>
              )}
            </div>
          </section>
        ) : null}

        <section className="rounded-lg border border-zinc-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-zinc-900">チャット</h2>
          <div className="mt-3">
            <ChatPanel bookingId={booking.id} currentUserId={user.id} />
          </div>
        </section>
      </main>
    </div>
  );
}

