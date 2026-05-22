"use client";

import { useEffect, useState } from "react";
import { apiGet, apiPost } from "@/lib/api";

interface ReportFile { name: string; size: number; url: string; mtime: number; }

export function Reports() {
  const [items, setItems] = useState<ReportFile[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function refresh() {
    const d = await apiGet<{ reports: ReportFile[] }>("/api/reports");
    setItems(d.reports);
  }
  useEffect(() => { refresh(); }, []);

  async function gen(kind: "word" | "pdf" | "bundle") {
    setBusy(kind); setMsg(null);
    const tool = kind === "word" ? "generate_word" : kind === "pdf" ? "generate_pdf" : "export_charts_bundle";
    try {
      const r = await apiPost<{ status: string; summary: string }>(`/api/run/${tool}`, { inputs: {} });
      setMsg(r.summary);
      await refresh();
    } catch (e) {
      setMsg(`❌ ${e}`);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2 flex-wrap">
        <button onClick={() => gen("word")} disabled={busy !== null} className="px-3 py-2 rounded bg-[var(--color-accent)] text-[var(--color-accent-fg)] text-sm disabled:opacity-50 cursor-pointer">{busy === "word" ? "生成中..." : "📄 生成 Word"}</button>
        <button onClick={() => gen("pdf")} disabled={busy !== null} className="px-3 py-2 rounded border text-sm disabled:opacity-50 cursor-pointer">{busy === "pdf" ? "生成中..." : "📑 生成 PDF"}</button>
        <button onClick={() => gen("bundle")} disabled={busy !== null} className="px-3 py-2 rounded border text-sm disabled:opacity-50 cursor-pointer">{busy === "bundle" ? "..." : "📦 打包图表"}</button>
      </div>
      {msg && <div className="text-sm px-3 py-2 rounded bg-[var(--color-card)] border">{msg}</div>}
      <div>
        <h3 className="font-medium mb-2">已生成报告</h3>
        <ul className="space-y-1 text-sm">
          {items.map(r => (
            <li key={r.name} className="flex items-center gap-3 py-1">
              <a href={r.url} download className="text-[var(--color-accent)] hover:underline font-mono">{r.name}</a>
              <span className="text-xs text-[var(--color-muted)]">{(r.size / 1024).toFixed(1)} KB</span>
            </li>
          ))}
          {items.length === 0 && <li className="text-[var(--color-muted)]">无</li>}
        </ul>
      </div>
    </div>
  );
}
