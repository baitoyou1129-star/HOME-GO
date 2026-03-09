import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";
import { VerifyForm } from "./VerifyForm";

type PageProps = {
  searchParams?: Record<string, string | string[] | undefined>;
};

export default async function VerifyPage({ searchParams }: PageProps) {
  const user = await getCurrentUser();
  const next =
    typeof searchParams?.next === "string" && searchParams.next.length > 0
      ? searchParams.next
      : "/app";
  const email = typeof searchParams?.email === "string" ? searchParams.email : "";

  if (user) redirect(next);

  return <VerifyForm next={next} initialEmail={email} />;
}

