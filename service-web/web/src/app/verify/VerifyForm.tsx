"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useId, useMemo, useState } from "react";

function toFriendlyVerifyError(code: string | null) {
  switch (code) {
    case "INVALID":
      return "入力内容を確認してください。";
    case "UNAUTHORIZED":
      return "コードが正しくないか、有効期限が切れています。";
    default:
      return "認証に失敗しました。";
  }
}

function toFriendlyRequestError(code: string | null) {
  switch (code) {
    case "INVALID":
      return "メールアドレスを確認してください。";
    case "RATE_LIMIT":
      return "短時間に送信しすぎています。しばらくしてからお試しください。";
    case "SERVER_ERROR":
      return "サーバーでエラーが発生しました。時間をおいて再度お試しください。";
    default:
      return "再送に失敗しました。";
  }
}

export function VerifyForm({ next, initialEmail }: { next: string; initialEmail: string }) {
  const router = useRouter();
  const emailId = useId();
  const codeId = useId();

  const [email, setEmail] = useState(initialEmail);
  const normalizedEmail = useMemo(() => email.trim(), [email]);
  const [code, setCode] = useState("");

  const [status, setStatus] = useState<"idle" | "verifying" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  const [resendStatus, setResendStatus] = useState<"idle" | "sending" | "sent">(
    "idle",
  );

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("verifying");
    setError(null);

    const res = await fetch("/api/auth/verify", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: normalizedEmail, code: code.trim() }),
    });

    if (res.ok) {
      router.replace(next);
      router.refresh();
      return;
    }

    const body: unknown = await res.json().catch(() => null);
    const errCode =
      typeof body === "object" &&
      body !== null &&
      "error" in body &&
      typeof (body as { error?: unknown }).error === "string"
        ? (body as { error: string }).error
        : null;
    setStatus("error");
    setError(toFriendlyVerifyError(errCode));
  }

  async function onResend() {
    setResendStatus("sending");
    setError(null);

    const res = await fetch("/api/auth/request", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: normalizedEmail }),
    });

    if (res.ok) {
      setResendStatus("sent");
      // 成功メッセージはUI側で表示
      return;
    }

    const body: unknown = await res.json().catch(() => null);
    const errCode =
      typeof body === "object" &&
      body !== null &&
      "error" in body &&
      typeof (body as { error?: unknown }).error === "string"
        ? (body as { error: string }).error
        : null;
    setResendStatus("idle");
    setError(toFriendlyRequestError(errCode));
  }

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-md flex-col gap-6 px-6 py-16">
        <header className="flex flex-col gap-2">
          <h1 className="text-2xl font-semibold tracking-tight">コード確認</h1>
          <p className="text-sm text-zinc-600">
            受信したワンタイムコード（通常6桁）を入力してください。
          </p>
        </header>

        <form
          onSubmit={onSubmit}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <label htmlFor={emailId} className="block text-sm font-medium text-zinc-800">
            メールアドレス
          </label>
          <input
            id={emailId}
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
          />

          <label htmlFor={codeId} className="mt-4 block text-sm font-medium text-zinc-800">
            ワンタイムコード
          </label>
          <input
            id={codeId}
            inputMode="numeric"
            autoComplete="one-time-code"
            required
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
            placeholder="例: 123456"
            maxLength={12}
          />

          {resendStatus === "sent" ? (
            <p className="mt-3 text-sm text-emerald-700">
              コードを再送しました。メールをご確認ください。
            </p>
          ) : null}

          {error ? <p className="mt-3 text-sm text-red-600">{error}</p> : null}

          <button
            type="submit"
            disabled={status === "verifying"}
            className="mt-4 inline-flex h-11 w-full items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
          >
            {status === "verifying" ? "確認中…" : "ログイン"}
          </button>

          <div className="mt-4 flex flex-col gap-2 text-xs text-zinc-600 sm:flex-row sm:items-center sm:justify-between">
            <Link className="hover:underline" href={`/login?next=${encodeURIComponent(next)}`}>
              メールアドレスを変更
            </Link>
            <button
              type="button"
              onClick={onResend}
              disabled={resendStatus === "sending" || normalizedEmail.length === 0}
              className="text-left hover:underline disabled:opacity-60"
            >
              {resendStatus === "sending" ? "再送中…" : "コードを再送"}
            </button>
          </div>
        </form>
      </main>
    </div>
  );
}

