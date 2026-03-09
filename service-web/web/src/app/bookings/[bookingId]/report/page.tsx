import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { prisma } from "@/lib/prisma";
import { createReport } from "./actions";
import { ReportForm } from "@/components/ReportForm";

export default async function ReportPage({
  params,
}: {
  params: { bookingId: string };
}) {
  const user = await getCurrentUser();
  if (!user) redirect(`/login?next=/bookings/${params.bookingId}/report`);

  const booking = await prisma.booking.findUnique({
    where: { id: params.bookingId },
    include: {
      category: true,
      client: { include: { profile: true, providerProfile: true } },
      provider: { include: { providerProfile: true, profile: true } },
    },
  });
  if (!booking) notFound();
  if (booking.clientId !== user.id && booking.providerId !== user.id) {
    redirect("/bookings");
  }

  const otherUser =
    booking.clientId === user.id ? booking.provider : booking.client;
  const otherName =
    otherUser.providerProfile?.displayName ??
    otherUser.profile?.displayName ??
    otherUser.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-2xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">通報</h1>
            <p className="mt-1 text-sm text-zinc-600">
              {booking.category.name} / {otherName}
            </p>
          </div>
          <Link
            className="text-sm text-zinc-700 hover:underline"
            href={`/bookings/${booking.id}`}
          >
            戻る
          </Link>
        </header>

        <ReportForm
          bookingId={booking.id}
          otherUserId={otherUser.id}
          action={createReport}
        />

        <p className="text-xs text-zinc-600">
          重大な緊急事態は、地域の緊急連絡先へ連絡してください。
        </p>
      </main>
    </div>
  );
}

