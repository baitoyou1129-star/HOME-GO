"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const HideSchema = z.object({
  reviewId: z.string().min(1),
  hide: z.coerce.boolean(),
  reason: z.string().trim().max(200).optional().default(""),
});

export async function setReviewHidden(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = HideSchema.safeParse({
    reviewId: formData.get("reviewId"),
    hide: formData.get("hide"),
    reason: formData.get("reason"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const updated = await prisma.review.update({
    where: { id: parsed.data.reviewId },
    data: {
      isHidden: parsed.data.hide,
      hiddenReason: parsed.data.hide ? parsed.data.reason || "admin" : null,
    },
  });

  await writeAuditLog({
    action: "admin.review_hidden_updated",
    userId: admin.id,
    metadata: {
      reviewId: updated.id,
      isHidden: updated.isHidden,
      hiddenReason: updated.hiddenReason,
    },
  });

  revalidatePath("/admin/reviews");
  revalidatePath(`/providers`);
}

