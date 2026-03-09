"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const UpdateSchema = z.object({
  ledgerId: z.string().min(1),
  status: z.enum(["unpaid", "paid", "waived"]),
  adminNote: z.string().trim().max(500).optional().default(""),
});

export async function updateLedgerStatus(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = UpdateSchema.safeParse({
    ledgerId: formData.get("ledgerId"),
    status: formData.get("status"),
    adminNote: formData.get("adminNote"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const updated = await prisma.commissionLedger.update({
    where: { id: parsed.data.ledgerId },
    data: {
      status: parsed.data.status,
      paidAt: parsed.data.status === "paid" ? new Date() : null,
      adminNote: parsed.data.adminNote || null,
    },
  });

  await writeAuditLog({
    action: "admin.ledger_status_updated",
    userId: admin.id,
    metadata: {
      ledgerId: updated.id,
      status: updated.status,
      paidAt: updated.paidAt?.toISOString() ?? null,
    },
  });

  revalidatePath("/admin/ledgers");
  revalidatePath(`/bookings/${updated.bookingId}`);
  revalidatePath("/me/ledgers");
}

