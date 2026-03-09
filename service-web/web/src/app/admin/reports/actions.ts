"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const UpdateSchema = z.object({
  reportId: z.string().min(1),
  status: z.enum(["open", "in_progress", "closed"]),
});

export async function updateReportStatus(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = UpdateSchema.safeParse({
    reportId: formData.get("reportId"),
    status: formData.get("status"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const updated = await prisma.report.update({
    where: { id: parsed.data.reportId },
    data: { status: parsed.data.status },
  });

  await writeAuditLog({
    action: "admin.report_status_updated",
    userId: admin.id,
    metadata: { reportId: updated.id, status: updated.status },
  });

  revalidatePath("/admin/reports");
}

