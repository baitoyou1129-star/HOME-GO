import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { prisma } from "@/lib/prisma";
import { redactMessage } from "./actions";

export default async function AdminMessagesPage() {
  await requireAdmin();

  type NameableUser = {
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type MessageItem = {
    id: string;
    body: string;
    createdAt: Date;
    sender: NameableUser;
    thread: { bookingId: string; booking: { category: { name: string } } };
  };

  const messages = (await prisma.chatMessage.findMany({
    orderBy: { createdAt: "desc" },
    take: 200,
    include: {
      sender: { include: { profile: true, providerProfile: true } },
      thread: { include: { booking: { include: { category: true } } } },
    },
  })) as MessageItem[];

  const nameOf = (u: NameableUser) =>
    u.providerProfile?.displayName ?? u.profile?.displayName ?? u.email;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
        <header className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">
              チャット管理（最小）
            </h1>
            <p className="mt-1 text-sm text-zinc-600">
              直近メッセージの確認と削除（本文置換）
            </p>
          </div>
          <Link className="text-sm text-zinc-700 hover:underline" href="/admin">
            戻る
          </Link>
        </header>

        <section className="rounded-lg border border-zinc-200 bg-white">
          <div className="divide-y divide-zinc-200">
            {messages.map((m) => (
              <div key={m.id} className="p-4">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="text-sm font-medium">
                      {m.thread.booking.category.name} /{" "}
                      <Link
                        className="underline"
                        href={`/bookings/${m.thread.bookingId}`}
                      >
                        {m.thread.bookingId}
                      </Link>
                    </div>
                    <div className="mt-1 text-xs text-zinc-600">
                      送信者: {nameOf(m.sender)} ・{" "}
                      {m.createdAt.toLocaleString("ja-JP")}
                    </div>
                    <div className="mt-2 whitespace-pre-wrap text-sm text-zinc-800">
                      {m.body}
                    </div>
                  </div>

                  <form action={redactMessage}>
                    <input type="hidden" name="messageId" value={m.id} />
                    <button className="inline-flex h-9 items-center justify-center rounded-md border border-zinc-200 bg-white px-3 text-sm font-medium hover:bg-zinc-50">
                      削除（本文置換）
                    </button>
                  </form>
                </div>
              </div>
            ))}
            {messages.length === 0 ? (
              <div className="p-5 text-sm text-zinc-700">
                メッセージがありません。
              </div>
            ) : null}
          </div>
        </section>
      </main>
    </div>
  );
}

