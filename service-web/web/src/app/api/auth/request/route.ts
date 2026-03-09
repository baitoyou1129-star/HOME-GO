import { NextResponse } from "next/server";
import { z } from "zod";
import { createAndStoreAuthCode } from "@/lib/authCodes";
import { sendAuthCodeEmail } from "@/lib/email";
import { writeAuditLog } from "@/lib/audit";

const RequestSchema = z.object({
  email: z.string().email(),
});

function isRateLimitError(e: unknown) {
  if (typeof e !== "object" || e === null) return false;
  if (!("code" in e)) return false;
  return (e as { code?: unknown }).code === "RATE_LIMIT";
}

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = RequestSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }

  try {
    const { email, code } = await createAndStoreAuthCode(parsed.data.email);
    await sendAuthCodeEmail({ to: email, code });
    await writeAuditLog({
      action: "auth.code_requested",
      metadata: { email },
    });
    return NextResponse.json({ ok: true });
  } catch (e) {
    if (isRateLimitError(e)) {
      return NextResponse.json({ error: "RATE_LIMIT" }, { status: 429 });
    }
    return NextResponse.json({ error: "SERVER_ERROR" }, { status: 500 });
  }
}

