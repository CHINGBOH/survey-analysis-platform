import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Survey Analysis Platform",
  description: "问卷统计分析平台 — Next.js 前端 (P2)",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
