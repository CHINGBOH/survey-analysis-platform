/**
 * FastAPI 客户端 — 所有调用走 /api/* (经 Next.js rewrites 反代到 :8765).
 */
export const API_BASE = "";

export async function apiGet<T = unknown>(path: string): Promise<T> {
  const r = await fetch(`${API_BASE}${path}`, { cache: "no-store" });
  if (!r.ok) throw new Error(`GET ${path} → ${r.status}`);
  return r.json();
}

export async function apiPost<T = unknown>(path: string, body: unknown): Promise<T> {
  const r = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
    cache: "no-store",
  });
  if (!r.ok) throw new Error(`POST ${path} → ${r.status}`);
  return r.json();
}

export async function apiUpload(file: File): Promise<{ status: string; filename: string; survey_id: string; path: string }> {
  const fd = new FormData();
  fd.append("file", file);
  const r = await fetch(`${API_BASE}/api/upload`, { method: "POST", body: fd });
  if (!r.ok) throw new Error(`upload → ${r.status}`);
  return r.json();
}

/* ─── SSE 聊天流 ─── */
export type ChatEvent =
  | { type: "phase"; phase: string }
  | { type: "text"; content: string }
  | { type: "tool_call"; name: string; inputs: Record<string, unknown> }
  | { type: "tool_result"; name: string; result: { status: string; summary: string; artifacts?: Record<string, unknown>; next_actions?: string[] } }
  | { type: "done"; history_len: number }
  | { type: "error"; message: string };

export async function* chatStream(message: string, opts: { reset?: boolean; sessionId?: string } = {}): AsyncGenerator<ChatEvent> {
  const r = await fetch(`${API_BASE}/api/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ message, reset: opts.reset ?? false, session_id: opts.sessionId }),
  });
  if (!r.ok || !r.body) throw new Error(`chat → ${r.status}`);

  const reader = r.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let nl: number;
    while ((nl = buffer.indexOf("\n\n")) !== -1) {
      const chunk = buffer.slice(0, nl).trim();
      buffer = buffer.slice(nl + 2);
      if (chunk.startsWith("data:")) {
        const payload = chunk.slice(5).trim();
        try {
          yield JSON.parse(payload) as ChatEvent;
        } catch {
          /* skip parse errors */
        }
      }
    }
  }
}

/* ─── 类型 ─── */
export interface PipelineStatus {
  stage: string;
  active_survey_id: string | null;
  uploaded_filename: string | null;
  clean_done: boolean;
  modules: Record<string, string>;
  done_modules: string[];
  report_path: string | null;
  plan: { surveys: string[]; modules: string[]; compare: boolean; focus: string } | null;
}

export interface ChartModule {
  module: string;
  count: number;
  files: string[];
}
