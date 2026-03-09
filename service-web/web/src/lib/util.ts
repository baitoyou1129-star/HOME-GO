import crypto from "crypto";

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function randomNumericCode(length = 6) {
  const max = 10 ** length;
  const n = crypto.randomInt(0, max);
  return String(n).padStart(length, "0");
}

