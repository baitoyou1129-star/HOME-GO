import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/session";

export async function requireAdmin() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?next=/admin");
  if (!user.isAdmin) redirect("/app");
  return user;
}

