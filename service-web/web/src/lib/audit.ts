import { prisma } from "./prisma";
import type { Prisma } from "@prisma/client";

export async function writeAuditLog(params: {
  action: string;
  userId?: string | null;
  bookingId?: string | null;
  metadata?: Prisma.InputJsonValue;
}) {
  try {
    await prisma.auditLog.create({
      data: {
        action: params.action,
        userId: params.userId ?? null,
        bookingId: params.bookingId ?? null,
        ...(params.metadata !== undefined ? { metadata: params.metadata } : {}),
      },
    });
  } catch {
    // 監査ログが落ちても本処理は継続する（MVP）
  }
}

