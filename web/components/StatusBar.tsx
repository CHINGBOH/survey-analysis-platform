"use client";

import { useEffect, useState } from "react";
import { apiGet, type PipelineStatus } from "@/lib/api";

export function StatusBar() {
  const [s, setS] = useState<PipelineStatus | null>(null);
  useEffect(() => {
    let cancelled = false;
    const tick = async () => {
      try {
        const data = await apiGet<PipelineStatus>("/api/status");
        if (!cancelled) setS(data);
      } catch {/* ignore */}
    };
    tick();
    const id = setInterval(tick, 5000);
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  if (!s) return null;
  const doneCount = s.done_modules.length;
  const totalCount = Object.keys(s.modules).length;
  return (
    <div className="flex items-center gap-4 px-4 py-2 text-xs border-b border-[var(--color-border)] bg-[var(--color-card)] overflow-x-auto whitespace-nowrap">
      <span className="font-mono">阶段: <b>{s.stage}</b></span>
      <span>活跃 survey: <b>{s.active_survey_id ?? "—"}</b></span>
      <span>上传: <b>{s.uploaded_filename ?? "—"}</b></span>
      <span>清洗: <b>{s.clean_done ? "✓" : "✗"}</b></span>
      <span>模块: <b>{doneCount}/{totalCount}</b></span>
      <span>报告: <b>{s.report_path ? "✓" : "✗"}</b></span>
    </div>
  );
}
