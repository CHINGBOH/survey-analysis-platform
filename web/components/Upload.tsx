"use client";

import { useEffect, useState } from "react";
import { apiUpload, apiGet } from "@/lib/api";

interface SurveysResp {
  surveys: string[];
  active: string | null;
  default: string | null;
}

export function Upload() {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [surveys, setSurveys] = useState<SurveysResp | null>(null);

  async function refresh() {
    try {
      setSurveys(await apiGet<SurveysResp>("/api/surveys"));
    } catch {/* ignore */}
  }
  useEffect(() => { refresh(); }, []);

  async function onChange(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    setBusy(true); setMsg(null);
    try {
      const r = await apiUpload(f);
      setMsg(`✅ 上传成功: ${r.filename} → survey_id=${r.survey_id}`);
      await refresh();
    } catch (err) {
      setMsg(`❌ ${err}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h3 className="font-medium mb-2">上传问卷数据</h3>
        <input
          type="file"
          accept=".xlsx,.xls,.csv"
          onChange={onChange}
          disabled={busy}
          className="block text-sm file:mr-3 file:px-3 file:py-2 file:rounded file:border-0 file:bg-[var(--color-accent)] file:text-[var(--color-accent-fg)] file:cursor-pointer file:font-medium"
        />
        {busy && <p className="text-sm text-[var(--color-muted)] mt-2">上传中...</p>}
        {msg && <p className="text-sm mt-2">{msg}</p>}
      </div>

      <div>
        <h3 className="font-medium mb-2">已发现的 survey</h3>
        {surveys ? (
          <ul className="text-sm space-y-1">
            {surveys.surveys.map(s => (
              <li key={s} className="font-mono">
                • {s}
                {s === surveys.active && <span className="ml-2 px-2 py-0.5 rounded bg-[var(--color-accent)] text-[var(--color-accent-fg)] text-xs">活跃</span>}
                {s === surveys.default && s !== surveys.active && <span className="ml-2 text-xs text-[var(--color-muted)]">默认</span>}
              </li>
            ))}
            {surveys.surveys.length === 0 && <li className="text-[var(--color-muted)]">无</li>}
          </ul>
        ) : (
          <p className="text-sm text-[var(--color-muted)]">加载中...</p>
        )}
      </div>
    </div>
  );
}
