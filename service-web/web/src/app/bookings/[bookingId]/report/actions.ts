"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";
import { redirect } from "next/navigation";

const ReportSchema = z.object({
  bookingId: z.string().min(1),
  targetType: z.enum(["booking", "user"]),
  targetId: z.string().min(1),
  reason: z.string().trim().min(1).max(100),
  details: z.string().trim().max(2000).optional().default(""),
});

export async function createReport(formData: FormData) {
  const user = await requireUser();
  const parsed = ReportSchema.safeParse({
    bookingId: formData.get("bookingId"),
    targetType: formData.get("targetType"),
    targetId: formData.get("targetId"),
    reason: formData.get("reason"),
    details: formData.get("details"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await prisma.booking.findUnique({
    where: { id: parsed.data.bookingId },
  });
  if (!booking) throw new Error("NOT_FOUND");
  if (booking.clientId !== user.id && booking.providerId !== user.id) {
    throw new Error("FORBIDDEN");
  }

  // bookingに紐づく範囲の通報に限定（MVP）
  if (parsed.data.targetType === "booking" && parsed.data.targetId !== booking.id) {
    throw new Error("INVALID_TARGET");
  }
  if (parsed.data.targetType === "user") {
    const ok = parsed.data.targetId === booking.clientId || parsed.data.targetId === booking.providerId;
    if (!ok) throw new Error("INVALID_TARGET");
  }

  const report = await prisma.report.create({
    data: {
      reporterId: user.id,
      targetType: parsed.data.targetType,
      targetId: parsed.data.targetId,
      reason: parsed.data.reason,
      details: parsed.data.details ?? "",
      status: "open",
    },
  });

  await writeAuditLog({
    action: "report.created",
    userId: user.id,
    bookingId: booking.id,
    metadata: { reportId: report.id, targetType: report.targetType, targetId: report.targetId },
  });

  redirect(`/bookings/${booking.id}`);
}

