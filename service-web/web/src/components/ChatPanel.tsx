"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

type ChatMessage = {
  id: string;
  body: string;
  createdAt: string;
  senderId: string;
  senderName: string;
};

export function ChatPanel(props: { bookingId: string; currentUserId: string }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const latestCreatedAtRef = useRef<string | null>(null);

  const latestCreatedAt = useMemo(() => {
    const last = messages[messages.length - 1];
    return last?.createdAt ?? null;
  }, [messages]);

  useEffect(() => {
    latestCreatedAtRef.current = latestCreatedAt;
  }, [latestCreatedAt]);

  const fetchMessages = useCallback(
    async (opts?: { since?: string | null }) => {
      const u = new URL("/api/chat/messages", window.location.origin);
      u.searchParams.set("bookingId", props.bookingId);
      if (opts?.since) u.searchParams.set("since", opts.since);

      const res = await fetch(u.toString(), { method: "GET" });
      if (!res.ok) return;
      const body: unknown = await res.json().catch(() => null);
      const msgs =
        typeof body === "object" && body !== null && "messages" in body
          ? (body as { messages?: unknown }).messages
          : null;
      if (!Array.isArray(msgs)) return;

      if (opts?.since) {
        if (msgs.length) {
          setMessages((prev) => [...prev, ...(msgs as ChatMessage[])]);
        }
      } else {
        setMessages(msgs as ChatMessage[]);
      }
    },
    [props.bookingId],
  );

  useEffect(() => {
    const t = window.setTimeout(() => {
      void fetchMessages();
    }, 0);
    const id = window.setInterval(() => {
      void fetchMessages({ since: latestCreatedAtRef.current });
    }, 3000);
    return () => {
      window.clearTimeout(t);
      window.clearInterval(id);
    };
  }, [fetchMessages]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function send() {
    const text = draft.trim();
    if (!text) return;
    setSending(true);
    setError(null);
    const res = await fetch("/api/chat/messages", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ bookingId: props.bookingId, body: text }),
    });
    setSending(false);
    if (!res.ok) {
      const body: unknown = await res.json().catch(() => null);
      const err =
        typeof body === "object" &&
        body !== null &&
        "error" in body &&
        typeof (body as { error?: unknown }).error === "string"
          ? (body as { error: string }).error
          : null;
      setError(err ?? "送信に失敗しました");
      return;
    }
    setDraft("");
    await fetchMessages({ since: latestCreatedAtRef.current });
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="max-h-[420px] overflow-auto rounded-md border border-zinc-200 bg-white p-3">
        {messages.length === 0 ? (
          <div className="text-sm text-zinc-600">
            まだメッセージがありません。
          </div>
        ) : null}
        <div className="flex flex-col gap-2">
          {messages.map((m) => {
            const mine = m.senderId === props.currentUserId;
            return (
              <div
                key={m.id}
                className={`flex ${mine ? "justify-end" : "justify-start"}`}
              >
                <div
                  className={`max-w-[85%] rounded-lg border px-3 py-2 text-sm ${
                    mine
                      ? "border-zinc-900 bg-zinc-900 text-white"
                      : "border-zinc-200 bg-white text-zinc-900"
                  }`}
                >
                  <div className={`text-[11px] ${mine ? "text-zinc-200" : "text-zinc-500"}`}>
                    {mine ? "あなた" : m.senderName} ・{" "}
                    {new Date(m.createdAt).toLocaleString("ja-JP")}
                  </div>
                  <div className="mt-1 whitespace-pre-wrap break-words">
                    {m.body}
                  </div>
                </div>
              </div>
            );
          })}
          <div ref={bottomRef} />
        </div>
      </div>

      {error ? <div className="text-sm text-red-600">{error}</div> : null}

      <div className="flex gap-2">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="メッセージを入力…"
          className="h-12 flex-1 resize-none rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
        />
        <button
          type="button"
          disabled={sending}
          onClick={() => void send()}
          className="inline-flex h-12 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
        >
          {sending ? "送信中…" : "送信"}
        </button>
      </div>
    </div>
  );
}

