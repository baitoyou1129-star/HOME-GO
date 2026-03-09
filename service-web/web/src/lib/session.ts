import { cookies } from "next/headers";
import { getSessionCookieName, verifySession } from "./auth";
import { prisma } from "./prisma";

export async function getCurrentUser() {
  const token = (await cookies()).get(getSessionCookieName())?.value;
  if (!token) return null;

  try {
    const session = await verifySession(token);
    const user = await prisma.user.findUnique({
      where: { id: session.userId },
      include: { profile: true, providerProfile: true },
    });
    if (!user) return null;
    if (user.isSuspended) return null;
    return user;
  } catch {
    return null;
  }
}

export async function requireUser() {
  const user = await getCurrentUser();
  if (!user) {
    // Server Component内で使う想定: リダイレクトは呼び出し側で行う
    throw new Error("UNAUTHORIZED");
  }
  return user;
}

