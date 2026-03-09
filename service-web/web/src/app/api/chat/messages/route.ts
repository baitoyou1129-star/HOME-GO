import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { getCurrentUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";

const GetSchema = z.object({
  bookingId: z.string().min(1),
  since: z.string().optional(),
});

export async function GET(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });

  const url = new URL(req.url);
  const parsed = GetSchema.safeParse({
    bookingId: url.searchParams.get("bookingId"),
    since: url.searchParams.get("since") ?? undefined,
  });
  if (!parsed.success) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  const booking = await prisma.booking.findUnique({
    where: { id: parsed.data.bookingId },
    include: { chatThread: true },
  });
  if (!booking) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  if (booking.clientId !== user.id && booking.providerId !== user.id) {
    return NextResponse.json({ error: "FORBIDDEN" }, { status: 403 });
  }
  if (!booking.chatThread) {
    return NextResponse.json({ messages: [] });
  }

  const sinceDate = parsed.data.since ? new Date(parsed.data.since) : null;
  if (sinceDate && Number.isNaN(sinceDate.getTime())) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  type SenderRow = {
    email: string;
    profile?: { displayName: string } | null;
    providerProfile?: { displayName: string } | null;
  };
  type MessageRow = {
    id: string;
    body: string;
    createdAt: Date;
    senderId: string;
    sender: SenderRow;
  };

  const messages = (await prisma.chatMessage.findMany({
    where: {
      threadId: booking.chatThread.id,
      ...(sinceDate ? { createdAt: { gt: sinceDate } } : {}),
    },
    orderBy: { createdAt: "asc" },
    take: 200,
    include: { sender: { include: { profile: true, providerProfile: true } } },
  })) as MessageRow[];

  await prisma.chatParticipant.updateMany({
    where: { threadId: booking.chatThread.id, userId: user.id },
    data: { lastReadAt: new Date() },
  });

  return NextResponse.json({
    messages: messages.map((m) => ({
      id: m.id,
      body: m.body,
      createdAt: m.createdAt.toISOString(),
      senderId: m.senderId,
      senderName:
        m.sender.providerProfile?.displayName ??
        m.sender.profile?.displayName ??
        m.sender.email,
    })),
  });
}

const PostSchema = z.object({
  bookingId: z.string().min(1),
  body: z.string().trim().min(1).max(2000),
});

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });

  const json = await req.json().catch(() => null);
  const parsed = PostSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  const booking = await prisma.booking.findUnique({
    where: { id: parsed.data.bookingId },
    include: { chatThread: true },
  });
  if (!booking) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  if (booking.clientId !== user.id && booking.providerId !== user.id) {
    return NextResponse.json({ error: "FORBIDDEN" }, { status: 403 });
  }
  if (!booking.chatThread) {
    return NextResponse.json({ error: "THREAD_MISSING" }, { status: 500 });
  }

  // 最低限のレート制限（連投防止）
  const last = await prisma.chatMessage.findFirst({
    where: { threadId: booking.chatThread.id, senderId: user.id },
    orderBy: { createdAt: "desc" },
  });
  if (last && Date.now() - last.createdAt.getTime() < 800) {
    return NextResponse.json({ error: "RATE_LIMIT" }, { status: 429 });
  }

  const msg = await prisma.chatMessage.create({
    data: {
      threadId: booking.chatThread.id,
      senderId: user.id,
      body: parsed.data.body,
    },
  });

  await writeAuditLog({
    action: "chat.message_sent",
    userId: user.id,
    bookingId: booking.id,
    metadata: { messageId: msg.id },
  });

  return NextResponse.json({ ok: true, id: msg.id });
}

