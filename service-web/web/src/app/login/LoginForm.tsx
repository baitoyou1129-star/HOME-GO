"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useId, useMemo, useState } from "react";

function toFriendlyError(code: string | null) {
  switch (code) {
    case "INVALID":
      return "メールアドレスを確認してください。";
    case "RATE_LIMIT":
      return "短時間に送信しすぎています。しばらくしてからお試しください。";
    case "SERVER_ERROR":
      return "サーバーでエラーが発生しました。時間をおいて再度お試しください。";
    default:
      return "送信に失敗しました。";
  }
}

export function LoginForm({ next }: { next: string }) {
  const router = useRouter();
  const emailId = useId();

  const [email, setEmail] = useState("");
  const normalizedEmail = useMemo(() => email.trim(), [email]);
  const [status, setStatus] = useState<"idle" | "sending" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("sending");
    setError(null);

    const res = await fetch("/api/auth/request", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: normalizedEmail }),
    });

    if (res.ok) {
      router.push(
        `/verify?email=${encodeURIComponent(normalizedEmail)}&next=${encodeURIComponent(next)}`,
      );
      return;
    }

    const body: unknown = await res.json().catch(() => null);
    const code =
      typeof body === "object" &&
      body !== null &&
      "error" in body &&
      typeof (body as { error?: unknown }).error === "string"
        ? (body as { error: string }).error
        : null;
    setStatus("error");
    setError(toFriendlyError(code));
  }

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-md flex-col gap-6 px-6 py-16">
        <header className="flex flex-col gap-2">
          <h1 className="text-2xl font-semibold tracking-tight">ログイン</h1>
          <p className="text-sm text-zinc-600">
            メールアドレスにワンタイムコードを送信します（登録も同じ手順です）。
          </p>
        </header>

        <form
          onSubmit={onSubmit}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <label
            htmlFor={emailId}
            className="block text-sm font-medium text-zinc-800"
          >
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
            placeholder="you@example.com"
          />

          {error ? <p className="mt-3 text-sm text-red-600">{error}</p> : null}

          <button
            type="submit"
            disabled={status === "sending"}
            className="mt-4 inline-flex h-11 w-full items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
          >
            {status === "sending" ? "送信中…" : "コードを送信"}
          </button>

          <div className="mt-4 flex items-center justify-between text-xs text-zinc-600">
            <Link className="hover:underline" href="/">
              トップへ戻る
            </Link>
            <span>次へ: コード入力</span>
          </div>
        </form>
      </main>
    </div>
  );
}

