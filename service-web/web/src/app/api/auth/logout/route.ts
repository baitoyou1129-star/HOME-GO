import { NextResponse } from "next/server";
import { getSessionCookieName } from "@/lib/auth";
import { writeAuditLog } from "@/lib/audit";

export async function POST() {
  await writeAuditLog({ action: "auth.logout" });
  const res = NextResponse.json({ ok: true });
  res.cookies.set({
    name: getSessionCookieName(),
    value: "",
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  });
  return res;
}

