import { SignJWT, jwtVerify } from "jose";

const COOKIE_NAME = "session";

function getAuthSecret(): Uint8Array {
  const secret = process.env.AUTH_SECRET;
  if (secret) return new TextEncoder().encode(secret);
  // 開発時はミドルウェアと同様にフォールバックする（本番では必須）
  if (process.env.NODE_ENV !== "production") {
    return new TextEncoder().encode("dev-secret");
  }
  throw new Error("AUTH_SECRET is required");
}

export type SessionPayload = {
  userId: string;
  email: string;
  isAdmin: boolean;
};

export function getSessionCookieName() {
  return COOKIE_NAME;
}

export async function signSession(payload: SessionPayload, opts?: { days?: number }) {
  const days = opts?.days ?? 30;
  const exp = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * days;
  return await new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuedAt()
    .setExpirationTime(exp)
    .sign(getAuthSecret());
}

export async function verifySession(token: string) {
  const { payload } = await jwtVerify(token, getAuthSecret());
  return payload as unknown as SessionPayload;
}

