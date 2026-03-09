import { prisma } from "@/lib/prisma";

const DEFAULT_CATEGORIES = [
  { slug: "housekeeping", name: "家政婦" },
  { slug: "cleaning", name: "部屋掃除" },
  { slug: "babysitting", name: "ベビーシッター" },
  { slug: "elderly_watch", name: "高齢者見守り" },
  { slug: "pet_sitting", name: "ペットシッター" },
] as const;

export async function ensureServiceCategories() {
  const count = await prisma.serviceCategory.count();
  if (count > 0) return;

  await prisma.serviceCategory.createMany({
    data: DEFAULT_CATEGORIES.map((c) => ({ slug: c.slug, name: c.name })),
  });
}

export async function listServiceCategories() {
  await ensureServiceCategories();
  return await prisma.serviceCategory.findMany({ orderBy: { name: "asc" } });
}

