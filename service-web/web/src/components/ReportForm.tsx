"use client";

import { useMemo, useState } from "react";

export function ReportForm(props: {
  bookingId: string;
  otherUserId: string;
  action: (formData: FormData) => void;
}) {
  const [targetType, setTargetType] = useState<"user" | "booking">("user");
  const targetId = useMemo(() => {
    return targetType === "booking" ? props.bookingId : props.otherUserId;
  }, [targetType, props.bookingId, props.otherUserId]);

  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-5">
      <label className="block text-sm font-medium text-zinc-800">通報対象</label>
      <div className="mt-2 flex flex-col gap-2 text-sm text-zinc-700 sm:flex-row sm:items-center">
        <label className="inline-flex items-center gap-2">
          <input
            type="radio"
            name="__target"
            checked={targetType === "user"}
            onChange={() => setTargetType("user")}
          />
          相手ユーザー
        </label>
        <label className="inline-flex items-center gap-2">
          <input
            type="radio"
            name="__target"
            checked={targetType === "booking"}
            onChange={() => setTargetType("booking")}
          />
          予約（案件）
        </label>
      </div>

      <form action={props.action} className="mt-4">
        <input type="hidden" name="bookingId" value={props.bookingId} />
        <input type="hidden" name="targetType" value={targetType} />
        <input type="hidden" name="targetId" value={targetId} />

        <label className="block text-sm font-medium text-zinc-800">
          理由（必須）
        </label>
        <input
          name="reason"
          required
          placeholder="例: 暴言 / 無断キャンセル / 迷惑行為"
          className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm"
        />

        <label className="mt-4 block text-sm font-medium text-zinc-800">
          詳細（任意）
        </label>
        <textarea
          name="details"
          className="mt-2 h-32 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm"
          placeholder="状況を具体的に記載してください。個人情報は最小限に。"
        />

        <button className="mt-5 inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
          通報する
        </button>
      </form>
    </div>
  );
}

