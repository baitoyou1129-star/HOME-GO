// eslint-disable-next-line @typescript-eslint/no-require-imports
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

const categories = [
  { slug: "housekeeping", name: "家政婦" },
  { slug: "cleaning", name: "部屋掃除" },
  { slug: "babysitting", name: "ベビーシッター" },
  { slug: "elderly_watch", name: "高齢者見守り" },
  { slug: "pet_sitting", name: "ペットシッター" },
];

async function main() {
  for (const c of categories) {
    await prisma.serviceCategory.upsert({
      where: { slug: c.slug },
      update: { name: c.name },
      create: c,
    });
  }
  console.log(`Seeded categories: ${categories.length}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

