"use client";

import { useEffect, useState } from "react";
import { apiGet, apiPost, type PipelineStatus } from "@/lib/api";
import { cn } from "@/lib/cn";

const MODULE_GROUPS: { name: string; modules: string[]; emoji: string }[] = [
  { emoji: "📈", name: "描述", modules: ["descriptives", "crosstabs"] },
  { emoji: "📊", name: "均值比较", modules: ["ttest", "anova"] },
  { emoji: "🔗", name: "相关回归", modules: ["correlation", "regression", "mediation", "moderation"] },
  { emoji: "🧮", name: "信度降维", modules: ["reliability", "factor_analysis"] },
  { emoji: "🗂️", name: "聚类", modules: ["cluster"] },
  { emoji: "⚙️", name: "高级", modules: ["power_bootstrap"] },
  { emoji: "📝", name: "问卷", modules: ["survey_specific"] },
];

export function AnalysisPanel() {
  const [status, setStatus] = useState<PipelineStatus | null>(null);
  const [running, setRunning] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function refresh() {
    try { setStatus(await apiGet<PipelineStatus>("/api/status")); } catch {/* ignore */}
  }
  useEffect(() => { refresh(); }, []);

  async function runOne(m: string) {
    setRunning(m); setMsg(null);
    try {
      const r = await apiPost<{ status: string; summary: string }>(`/api/run/run_analysis_module`, { inputs: { module: m } });
      setMsg(`${m}: ${r.summary}`);
      await refresh();
    } catch (e) {
      setMsg(`${m}: ❌ ${e}`);
    } finally {
      setRunning(null);
    }
  }

  async function runRender(m: string) {
    setRunning(`chart-${m}`); setMsg(null);
    try {
      const r = await apiPost<{ status: string; summary: string }>(`/api/run/render_charts`, { inputs: { module: m } });
      setMsg(`render_charts(${m}): ${r.summary}`);
    } catch (e) {
      setMsg(`❌ ${e}`);
    } finally {
      setRunning(null);
    }
  }

  return (
    <div className="space-y-6">
      {msg && <div className="text-sm px-3 py-2 rounded bg-[var(--color-card)] border">{msg}</div>}
      {MODULE_GROUPS.map(g => (
        <div key={g.name}>
          <h3 className="font-medium mb-2">{g.emoji} {g.name}</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {g.modules.map(m => {
              const s = status?.modules[m] ?? "pending";
              const color = s === "done" ? "text-emerald-500" : s === "running" ? "text-amber-500" : s === "error" ? "text-red-500" : "text-[var(--color-muted)]";
              return (
                <div key={m} className="rounded border p-3 bg-[var(--color-card)] flex flex-col gap-2">
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-sm">{m}</span>
                    <span className={cn("text-xs", color)}>{s}</span>
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => runOne(m)}
                      disabled={running !== null}
                      className="text-xs px-2 py-1 rounded bg-[var(--color-accent)] text-[var(--color-accent-fg)] disabled:opacity-50 hover:opacity-90 cursor-pointer"
                    >
                      {running === m ? "运行中..." : "▶ 运行"}
                    </button>
                    <button
                      onClick={() => runRender(m)}
                      disabled={running !== null || s !== "done"}
                      className="text-xs px-2 py-1 rounded border disabled:opacity-50 hover:bg-[var(--color-border)] cursor-pointer"
                    >
                      {running === `chart-${m}` ? "..." : "🖼️ 图表"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
