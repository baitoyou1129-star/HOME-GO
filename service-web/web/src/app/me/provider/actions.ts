"use server";

import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { listServiceCategories } from "@/lib/categories";
import { writeAuditLog } from "@/lib/audit";
import { revalidatePath } from "next/cache";
import type { Prisma } from "@prisma/client";

const ProviderSchema = z.object({
  displayName: z.string().trim().min(1).max(50),
  bio: z.string().trim().max(2000).optional().default(""),
  areaPref: z.string().trim().max(50).optional().or(z.literal("")).default(""),
  areaCity: z.string().trim().max(50).optional().or(z.literal("")).default(""),
  availabilityNote: z
    .string()
    .trim()
    .max(2000)
    .optional()
    .default(""),
});

export async function upsertMyProviderProfile(formData: FormData) {
  const user = await requireUser();
  const parsed = ProviderSchema.safeParse({
    displayName: formData.get("displayName"),
    bio: formData.get("bio"),
    areaPref: formData.get("areaPref"),
    areaCity: formData.get("areaCity"),
    availabilityNote: formData.get("availabilityNote"),
  });
  if (!parsed.success) throw new Error("INVALID");

  const categories = await listServiceCategories();

  const result = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    const provider = await tx.providerProfile.upsert({
      where: { userId: user.id },
      update: {
        displayName: parsed.data.displayName,
        bio: parsed.data.bio ?? "",
        areaPref: parsed.data.areaPref || null,
        areaCity: parsed.data.areaCity || null,
        availabilityNote: parsed.data.availabilityNote ?? "",
      },
      create: {
        userId: user.id,
        displayName: parsed.data.displayName,
        bio: parsed.data.bio ?? "",
        areaPref: parsed.data.areaPref || null,
        areaCity: parsed.data.areaCity || null,
        availabilityNote: parsed.data.availabilityNote ?? "",
      },
    });

    for (const c of categories) {
      const active = formData.get(`svc_${c.id}_active`) === "on";
      const rawPrice = String(formData.get(`svc_${c.id}_price`) ?? "").trim();
      const price = rawPrice ? Number(rawPrice) : NaN;

      if (!active) {
        await tx.providerService.upsert({
          where: { providerId_categoryId: { providerId: provider.id, categoryId: c.id } },
          update: { isActive: false },
          create: {
            providerId: provider.id,
            categoryId: c.id,
            priceYenPerHour: 0,
            isActive: false,
          },
        });
        continue;
      }

      if (!Number.isFinite(price) || price <= 0) {
        throw new Error("INVALID_PRICE");
      }

      await tx.providerService.upsert({
        where: { providerId_categoryId: { providerId: provider.id, categoryId: c.id } },
        update: { isActive: true, priceYenPerHour: Math.trunc(price) },
        create: {
          providerId: provider.id,
          categoryId: c.id,
          priceYenPerHour: Math.trunc(price),
          isActive: true,
        },
      });
    }

    return provider;
  });

  await writeAuditLog({
    action: "provider_profile.updated",
    userId: user.id,
    metadata: { providerProfileId: result.id },
  });

  revalidatePath("/me/provider");
  revalidatePath("/providers");
  revalidatePath("/app");
}

