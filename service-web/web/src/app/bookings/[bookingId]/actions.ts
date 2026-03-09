"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";
import type { Prisma } from "@prisma/client";

async function requireBookingParticipant(bookingId: string, userId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { chatThread: true },
  });
  if (!booking) throw new Error("NOT_FOUND");
  if (booking.clientId !== userId && booking.providerId !== userId) {
    throw new Error("FORBIDDEN");
  }
  return booking;
}

const CancelSchema = z.object({
  bookingId: z.string().min(1),
  reason: z.string().trim().max(200).optional().default(""),
});

export async function cancelBooking(formData: FormData) {
  const user = await requireUser();
  const parsed = CancelSchema.safeParse({
    bookingId: formData.get("bookingId"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await requireBookingParticipant(parsed.data.bookingId, user.id);
  if (booking.status === "cancelled" || booking.status === "completed") return;

  await prisma.booking.update({
    where: { id: booking.id },
    data: {
      status: "cancelled",
      cancelledAt: new Date(),
      cancelReason: parsed.data.reason || null,
    },
  });

  await writeAuditLog({
    action: "booking.cancelled",
    userId: user.id,
    bookingId: booking.id,
    metadata: { reason: parsed.data.reason || null },
  });

  revalidatePath(`/bookings/${booking.id}`);
  revalidatePath("/bookings");
}

const AcceptSchema = z.object({
  bookingId: z.string().min(1),
});

export async function acceptBooking(formData: FormData) {
  const user = await requireUser();
  const parsed = AcceptSchema.safeParse({ bookingId: formData.get("bookingId") });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await requireBookingParticipant(parsed.data.bookingId, user.id);
  if (booking.providerId !== user.id) throw new Error("FORBIDDEN");
  if (booking.status !== "requested") return;

  await prisma.booking.update({
    where: { id: booking.id },
    data: { status: "accepted" },
  });

  await writeAuditLog({
    action: "booking.accepted",
    userId: user.id,
    bookingId: booking.id,
  });

  revalidatePath(`/bookings/${booking.id}`);
  revalidatePath("/bookings");
}

const ClientCompleteSchema = z.object({
  bookingId: z.string().min(1),
  amountYen: z.coerce.number().int().min(1),
});

export async function markClientComplete(formData: FormData) {
  const user = await requireUser();
  const parsed = ClientCompleteSchema.safeParse({
    bookingId: formData.get("bookingId"),
    amountYen: formData.get("amountYen"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await requireBookingParticipant(parsed.data.bookingId, user.id);
  if (booking.clientId !== user.id) throw new Error("FORBIDDEN");
  if (booking.status !== "accepted") return;

  const updated = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    const b = await tx.booking.update({
      where: { id: booking.id },
      data: {
        clientMarkedCompleteAt: new Date(),
        priceYenFinal: parsed.data.amountYen,
      },
    });

    if (b.providerMarkedCompleteAt) {
      const completed = await tx.booking.update({
        where: { id: booking.id },
        data: { status: "completed", completedAt: new Date() },
      });
      const commissionYen = Math.round(parsed.data.amountYen * 0.1);
      await tx.commissionLedger.upsert({
        where: { bookingId: booking.id },
        update: {},
        create: {
          bookingId: booking.id,
          amountYen: parsed.data.amountYen,
          commissionRate: 0.1,
          commissionYen,
          status: "unpaid",
        },
      });
      return completed;
    }
    return b;
  });

  await writeAuditLog({
    action: "booking.client_marked_complete",
    userId: user.id,
    bookingId: updated.id,
    metadata: { amountYen: parsed.data.amountYen },
  });
  if (updated.status === "completed") {
    await writeAuditLog({
      action: "commission_ledger.created",
      userId: user.id,
      bookingId: updated.id,
      metadata: { amountYen: parsed.data.amountYen },
    });
  }

  revalidatePath(`/bookings/${booking.id}`);
  revalidatePath("/bookings");
}

const ProviderCompleteSchema = z.object({
  bookingId: z.string().min(1),
});

export async function markProviderComplete(formData: FormData) {
  const user = await requireUser();
  const parsed = ProviderCompleteSchema.safeParse({
    bookingId: formData.get("bookingId"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await requireBookingParticipant(parsed.data.bookingId, user.id);
  if (booking.providerId !== user.id) throw new Error("FORBIDDEN");
  if (booking.status !== "accepted") return;
  if (!booking.priceYenFinal) throw new Error("AMOUNT_REQUIRED");

  const updated = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    const b = await tx.booking.update({
      where: { id: booking.id },
      data: {
        providerMarkedCompleteAt: new Date(),
      },
    });

    if (b.clientMarkedCompleteAt) {
      const completed = await tx.booking.update({
        where: { id: booking.id },
        data: { status: "completed", completedAt: new Date() },
      });
      const amountYen = b.priceYenFinal ?? booking.priceYenFinal ?? 0;
      const commissionYen = Math.round(amountYen * 0.1);
      await tx.commissionLedger.upsert({
        where: { bookingId: booking.id },
        update: {},
        create: {
          bookingId: booking.id,
          amountYen,
          commissionRate: 0.1,
          commissionYen,
          status: "unpaid",
        },
      });
      return completed;
    }
    return b;
  });

  await writeAuditLog({
    action: "booking.provider_marked_complete",
    userId: user.id,
    bookingId: updated.id,
  });
  if (updated.status === "completed") {
    await writeAuditLog({
      action: "commission_ledger.created",
      userId: user.id,
      bookingId: updated.id,
      metadata: { amountYen: booking.priceYenFinal ?? null },
    });
  }

  revalidatePath(`/bookings/${booking.id}`);
  revalidatePath("/bookings");
}

