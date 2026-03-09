import { NextResponse } from "next/server";
import { z } from "zod";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { prisma } from "@/lib/prisma";
import { getSessionCookieName, signSession } from "@/lib/auth";
import { writeAuditLog } from "@/lib/audit";

const BodySchema = z.object({
  idToken: z.string().min(1),
});

const JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

async function getFirebaseProjectId(): Promise<string> {
  const fromEnv = process.env.FIREBASE_PROJECT_ID?.trim();
  if (fromEnv) return fromEnv;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (serviceAccountJson) {
    const parsed = JSON.parse(serviceAccountJson) as { project_id?: unknown };
    if (typeof parsed.project_id === "string" && parsed.project_id.trim()) {
      return parsed.project_id.trim();
    }
  }

  // 開発用フォールバック: リポジトリ内の Android 設定から読む
  const candidates = [
    join(process.cwd(), "android", "app", "google-services.json"),
    join(process.cwd(), "..", "android", "app", "google-services.json"),
    join(process.cwd(), "..", "..", "android", "app", "google-services.json"),
    join(process.cwd(), "..", "..", "..", "android", "app", "google-services.json"),
  ];
  for (const p of candidates) {
    try {
      const raw = await readFile(p, "utf8");
      const json = JSON.parse(raw) as { project_info?: { project_id?: unknown } };
      const pid = json.project_info?.project_id;
      if (typeof pid === "string" && pid.trim()) return pid.trim();
    } catch {
      // try next
    }
  }

  throw new Error("FIREBASE_PROJECT_ID is required");
}

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = BodySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  try {
    const projectId = await getFirebaseProjectId();
    const { payload } = await jwtVerify(parsed.data.idToken, JWKS, {
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
    });

    const email = (typeof payload.email === "string" ? payload.email : "").trim().toLowerCase();
    if (!email) {
      return NextResponse.json({ error: "NO_EMAIL" }, { status: 400 });
    }

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
      action: "auth.firebase_login",
      userId: user.id,
      metadata: {
        email: user.email,
        provider:
          typeof payload.firebase === "object" &&
          payload.firebase !== null &&
          "sign_in_provider" in payload.firebase &&
          typeof (payload.firebase as { sign_in_provider?: unknown }).sign_in_provider === "string"
            ? (payload.firebase as { sign_in_provider: string }).sign_in_provider
            : null,
      },
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
  } catch (e) {
    if (e instanceof Error && e.message.includes("FIREBASE_PROJECT_ID")) {
      return NextResponse.json({ error: "SERVER_MISCONFIG" }, { status: 500 });
    }
    // トークン不正など
    return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  }
}

