"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const SuspendSchema = z.object({
  userId: z.string().min(1),
  suspend: z.coerce.boolean(),
});

export async function setUserSuspended(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = SuspendSchema.safeParse({
    userId: formData.get("userId"),
    suspend: formData.get("suspend"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const updated = await prisma.user.update({
    where: { id: parsed.data.userId },
    data: { isSuspended: parsed.data.suspend },
  });

  await writeAuditLog({
    action: "admin.user_suspended_updated",
    userId: admin.id,
    metadata: { targetUserId: updated.id, isSuspended: updated.isSuspended },
  });

  revalidatePath("/admin/users");
}

