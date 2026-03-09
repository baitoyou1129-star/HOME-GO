"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";
import { redirect } from "next/navigation";

const ReviewSchema = z.object({
  bookingId: z.string().min(1),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().trim().max(2000).optional().default(""),
});

export async function createReview(formData: FormData) {
  const user = await requireUser();
  const parsed = ReviewSchema.safeParse({
    bookingId: formData.get("bookingId"),
    rating: formData.get("rating"),
    comment: formData.get("comment"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const booking = await prisma.booking.findUnique({
    where: { id: parsed.data.bookingId },
    include: { review: true },
  });
  if (!booking) throw new Error("NOT_FOUND");
  if (booking.status !== "completed") throw new Error("NOT_COMPLETED");
  if (booking.clientId !== user.id) throw new Error("FORBIDDEN");
  if (booking.review) redirect(`/bookings/${booking.id}`);

  const review = await prisma.review.create({
    data: {
      bookingId: booking.id,
      authorId: user.id,
      targetUserId: booking.providerId,
      rating: parsed.data.rating,
      comment: parsed.data.comment ?? "",
    },
  });

  await writeAuditLog({
    action: "review.created",
    userId: user.id,
    bookingId: booking.id,
    metadata: { reviewId: review.id, rating: parsed.data.rating },
  });

  redirect(`/bookings/${booking.id}`);
}

