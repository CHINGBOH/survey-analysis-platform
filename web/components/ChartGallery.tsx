"use client";

import { useEffect, useState } from "react";
import { apiGet } from "@/lib/api";
import { cn } from "@/lib/cn";

interface ChartFile { name: string; url: string; size: number; }
interface ModuleList { modules: { module: string; count: number; files: string[] }[]; }
interface ModuleDetail { module: string; count: number; files: ChartFile[]; }

export function ChartGallery() {
  const [modules, setModules] = useState<ModuleList["modules"]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [detail, setDetail] = useState<ModuleDetail | null>(null);
  const [lightbox, setLightbox] = useState<string | null>(null);

  useEffect(() => {
    apiGet<ModuleList>("/api/charts").then(d => {
      setModules(d.modules);
      if (d.modules[0]) setSelected(d.modules[0].module);
    });
  }, []);

  useEffect(() => {
    if (!selected) return;
    apiGet<ModuleDetail>(`/api/charts/${selected}`).then(setDetail);
  }, [selected]);

  if (modules.length === 0) {
    return <div className="text-sm text-[var(--color-muted)] py-12 text-center">尚无图表。先在聊天里跑分析,或调用 /api/run/render_charts。</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {modules.map(m => (
          <button
            key={m.module}
            onClick={() => setSelected(m.module)}
            className={cn(
              "px-3 py-1.5 text-xs rounded border font-mono transition-colors cursor-pointer",
              selected === m.module
                ? "bg-[var(--color-accent)] text-[var(--color-accent-fg)] border-[var(--color-accent)]"
                : "bg-[var(--color-card)] hover:bg-[var(--color-border)]"
            )}
          >
            {m.module} <span className="opacity-70">({m.count})</span>
          </button>
        ))}
      </div>

      {detail && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {detail.files.map(f => (
            <div key={f.name} className="rounded border bg-[var(--color-card)] overflow-hidden">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={f.url}
                alt={f.name}
                onClick={() => setLightbox(f.url)}
                className="w-full h-48 object-contain bg-white dark:bg-black cursor-zoom-in hover:opacity-90"
              />
              <div className="px-3 py-2 text-xs">
                <div className="font-mono truncate" title={f.name}>{f.name}</div>
                <a href={f.url} download className="text-[var(--color-accent)] hover:underline text-[10px]">⬇️ 下载</a>
              </div>
            </div>
          ))}
        </div>
      )}

      {lightbox && (
        <div
          onClick={() => setLightbox(null)}
          className="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4 cursor-zoom-out"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightbox} alt="" className="max-w-full max-h-full object-contain" />
        </div>
      )}
    </div>
  );
}
