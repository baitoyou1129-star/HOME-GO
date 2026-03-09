import bcrypt from "bcryptjs";
import { prisma } from "./prisma";
import { normalizeEmail, randomNumericCode } from "./util";

const CODE_TTL_MINUTES = 10;
const MAX_CODES_PER_WINDOW = 3;
const WINDOW_MINUTES = 10;

export async function createAndStoreAuthCode(rawEmail: string) {
  const email = normalizeEmail(rawEmail);

  const since = new Date(Date.now() - WINDOW_MINUTES * 60 * 1000);
  const recentCount = await prisma.authCode.count({
    where: { email, createdAt: { gte: since } },
  });
  if (recentCount >= MAX_CODES_PER_WINDOW) {
    const err = new Error("RATE_LIMIT");
    // @ts-expect-error attach code
    err.code = "RATE_LIMIT";
    throw err;
  }

  const code = randomNumericCode(6);
  const codeHash = await bcrypt.hash(code, 10);
  const expiresAt = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);

  await prisma.authCode.create({
    data: { email, codeHash, expiresAt },
  });

  return { email, code, expiresAt };
}

export async function consumeAuthCode(params: { email: string; code: string }) {
  const email = normalizeEmail(params.email);
  const code = params.code.trim();

  const candidate = await prisma.authCode.findFirst({
    where: { email, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: "desc" },
  });
  if (!candidate) return null;

  const ok = await bcrypt.compare(code, candidate.codeHash);
  if (!ok) return null;

  await prisma.authCode.update({
    where: { id: candidate.id },
    data: { consumedAt: new Date() },
  });

  return { email };
}

