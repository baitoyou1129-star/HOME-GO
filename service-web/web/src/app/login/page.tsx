import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { LoginForm } from "./LoginForm";

type PageProps = {
  searchParams?: Record<string, string | string[] | undefined>;
};

export default async function LoginPage({ searchParams }: PageProps) {
  const user = await getCurrentUser();
  const next =
    typeof searchParams?.next === "string" && searchParams.next.length > 0
      ? searchParams.next
      : "/app";

  if (user) redirect(next);

  return <LoginForm next={next} />;
}

