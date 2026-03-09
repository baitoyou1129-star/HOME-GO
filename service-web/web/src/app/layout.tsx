import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "訪問型サービスMVP",
  description: "訪問型サービスのMVP",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className="antialiased">{children}</body>
    </html>
  );
}
