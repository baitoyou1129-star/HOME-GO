"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";

const ProfileSchema = z.object({
  displayName: z.string().trim().min(1).max(50),
  bio: z.string().trim().max(1000).optional().default(""),
  areaPref: z.string().trim().max(50).optional().or(z.literal("")).default(""),
  areaCity: z.string().trim().max(50).optional().or(z.literal("")).default(""),
});

export async function updateMyProfile(formData: FormData) {
  const user = await requireUser();
  const parsed = ProfileSchema.safeParse({
    displayName: formData.get("displayName"),
    bio: formData.get("bio"),
    areaPref: formData.get("areaPref"),
    areaCity: formData.get("areaCity"),
  });
  if (!parsed.success) {
    throw new Error("INVALID");
  }

  await prisma.profile.upsert({
    where: { userId: user.id },
    update: {
      displayName: parsed.data.displayName,
      bio: parsed.data.bio ?? "",
      areaPref: parsed.data.areaPref || null,
      areaCity: parsed.data.areaCity || null,
    },
    create: {
      userId: user.id,
      displayName: parsed.data.displayName,
      bio: parsed.data.bio ?? "",
      areaPref: parsed.data.areaPref || null,
      areaCity: parsed.data.areaCity || null,
    },
  });

  await writeAuditLog({
    action: "profile.updated",
    userId: user.id,
    metadata: { displayName: parsed.data.displayName },
  });

  revalidatePath("/me/profile");
  revalidatePath("/app");
}

