"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";
import { redirect } from "next/navigation";
import type { Prisma } from "@prisma/client";

const BookingSchema = z.object({
  providerProfileId: z.string().min(1),
  categoryId: z.string().min(1),
  scheduledAt: z.string().min(1),
  durationMinutes: z.coerce.number().int().min(30).max(12 * 60).default(120),
  locationText: z.string().trim().min(1).max(200),
  notes: z.string().trim().max(2000).optional().default(""),
});

export async function createBookingRequest(formData: FormData) {
  const user = await requireUser();
  const parsed = BookingSchema.safeParse({
    providerProfileId: formData.get("providerProfileId"),
    categoryId: formData.get("categoryId"),
    scheduledAt: formData.get("scheduledAt"),
    durationMinutes: formData.get("durationMinutes"),
    locationText: formData.get("locationText"),
    notes: formData.get("notes"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const scheduledAt = new Date(parsed.data.scheduledAt);
  if (Number.isNaN(scheduledAt.getTime())) throw new Error("INVALID_DATE");

  const provider = await prisma.providerProfile.findUnique({
    where: { id: parsed.data.providerProfileId },
    include: {
      services: {
        where: { categoryId: parsed.data.categoryId, isActive: true },
      },
    },
  });
  if (!provider) throw new Error("NOT_FOUND");
  if (provider.userId === user.id) throw new Error("CANNOT_BOOK_SELF");

  const svc = provider.services[0];
  if (!svc) throw new Error("SERVICE_NOT_AVAILABLE");

  const hours = parsed.data.durationMinutes / 60;
  const estimated = Math.round(svc.priceYenPerHour * hours);

  const booking = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    const b = await tx.booking.create({
      data: {
        status: "requested",
        scheduledAt,
        durationMinutes: parsed.data.durationMinutes,
        locationText: parsed.data.locationText,
        notes: parsed.data.notes ?? "",
        priceYenEstimated: estimated,
        clientId: user.id,
        providerId: provider.userId,
        categoryId: parsed.data.categoryId,
      },
    });

    const thread = await tx.chatThread.create({
      data: { bookingId: b.id },
    });
    await tx.chatParticipant.createMany({
      data: [
        { threadId: thread.id, userId: user.id },
        { threadId: thread.id, userId: provider.userId },
      ],
      skipDuplicates: true,
    });

    return b;
  });

  await writeAuditLog({
    action: "booking.requested",
    userId: user.id,
    bookingId: booking.id,
    metadata: { providerProfileId: provider.id, categoryId: parsed.data.categoryId },
  });

  redirect(`/bookings/${booking.id}`);
}

