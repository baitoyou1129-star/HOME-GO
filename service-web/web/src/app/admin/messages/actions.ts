"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireAdmin } from "@/lib/admin";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const RedactSchema = z.object({
  messageId: z.string().min(1),
});

export async function redactMessage(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = RedactSchema.safeParse({ messageId: formData.get("messageId") });
  if (!parsed.success) throw new Error("INVALID");

  const msg = await prisma.chatMessage.update({
    where: { id: parsed.data.messageId },
    data: { body: "【管理者により削除されました】" },
    include: { thread: true },
  });

  await writeAuditLog({
    action: "admin.chat_message_redacted",
    userId: admin.id,
    metadata: { messageId: msg.id, threadId: msg.threadId },
  });

  revalidatePath("/admin/messages");
}

