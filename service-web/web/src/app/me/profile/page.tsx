import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { updateMyProfile } from "./actions";

export default async function MyProfilePage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/me/profile");

  const profile = user.profile;

  return (
    <div className="min-h-screen bg-zinc-50">
      <main className="mx-auto flex max-w-2xl flex-col gap-6 px-6 py-10">
        <header className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-semibold tracking-tight">プロフィール</h1>
            <Link className="text-sm text-zinc-700 hover:underline" href="/app">
              戻る
            </Link>
          </div>
          <p className="text-sm text-zinc-600">
            住所は詳細公開しない想定です（市区町村レベルまで）。
          </p>
        </header>

        <form
          action={updateMyProfile}
          className="rounded-lg border border-zinc-200 bg-white p-5"
        >
          <label className="block text-sm font-medium text-zinc-800">
            表示名
          </label>
          <input
            name="displayName"
            required
            defaultValue={profile?.displayName ?? user.email.split("@")[0]}
            className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
          />

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                都道府県（任意）
              </label>
              <input
                name="areaPref"
                defaultValue={profile?.areaPref ?? ""}
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
                placeholder="例: 東京都"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-800">
                市区町村（任意）
              </label>
              <input
                name="areaCity"
                defaultValue={profile?.areaCity ?? ""}
                className="mt-2 w-full rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
                placeholder="例: 新宿区"
              />
            </div>
          </div>

          <label className="mt-4 block text-sm font-medium text-zinc-800">
            自己紹介（任意）
          </label>
          <textarea
            name="bio"
            defaultValue={profile?.bio ?? ""}
            className="mt-2 h-32 w-full resize-y rounded-md border border-zinc-200 px-3 py-2 text-sm outline-none focus:border-zinc-400"
            placeholder="例: 丁寧な家事が得意です。平日昼に対応できます。"
          />

          <button className="mt-5 inline-flex h-11 items-center justify-center rounded-md bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800">
            保存
          </button>
        </form>
      </main>
    </div>
  );
}

