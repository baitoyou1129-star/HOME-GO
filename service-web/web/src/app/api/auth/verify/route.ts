import { NextResponse } from "next/server";
import { z } from "zod";
import { consumeAuthCode } from "@/lib/authCodes";
import { prisma } from "@/lib/prisma";
import { signSession, getSessionCookieName } from "@/lib/auth";
import { writeAuditLog } from "@/lib/audit";

const VerifySchema = z.object({
  email: z.string().email(),
  code: z.string().min(4).max(12),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = VerifySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  const consumed = await consumeAuthCode(parsed.data);
  if (!consumed) {
    return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  }

  const email = parsed.data.email.trim().toLowerCase();
  const user = await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email },
    include: { profile: true },
  });

  if (!user.profile) {
    const defaultName = email.split("@")[0] || "ユーザー";
    await prisma.profile.create({
      data: { userId: user.id, displayName: defaultName },
    });
  }

  await writeAuditLog({
    action: "auth.login",
    userId: user.id,
    metadata: { email: user.email },
  });

  const token = await signSession({
    userId: user.id,
    email: user.email,
    isAdmin: user.isAdmin,
  });

  const res = NextResponse.json({ ok: true });
  res.cookies.set({
    name: getSessionCookieName(),
    value: token,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
  return res;
}

