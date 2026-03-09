export async function sendAuthCodeEmail(params: { to: string; code: string }) {
  const mode = process.env.EMAIL_MODE ?? "console";

  if (mode === "console") {
    // 開発用: 実送信せずログに出す
    console.log(`[auth] code for ${params.to}: ${params.code}`);
    return;
  }

  throw new Error(`Unsupported EMAIL_MODE: ${mode}`);
}

