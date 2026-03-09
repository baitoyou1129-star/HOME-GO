import { PrismaClient } from "@prisma/client";

// Prismaのengine typeが誤って "client" になっている環境では、
// adapter/accelerateUrl が必要になりMVPローカル構成で動かなくなるため補正する。
//（通常のNode.js実行では "library" で問題ありません）
if (process.env.PRISMA_CLIENT_ENGINE_TYPE === "client") {
  process.env.PRISMA_CLIENT_ENGINE_TYPE = "library";
}

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "warn", "error"]
        : ["warn", "error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;

