"use client";

import { useRef, useState, useEffect } from "react";
import { chatStream, type ChatEvent } from "@/lib/api";
import { cn } from "@/lib/cn";

interface ToolCallEntry {
  name: string;
  inputs: Record<string, unknown>;
  result?: { status: string; summary: string; artifacts?: Record<string, unknown>; next_actions?: string[] };
}

interface Message {
  role: "user" | "assistant";
  content: string;
  phase?: string;
  toolCalls: ToolCallEntry[];
}

export function Chat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function send() {
    const text = input.trim();
    if (!text || busy) return;
    setInput("");
    setError(null);
    setBusy(true);
    setMessages(m => [...m, { role: "user", content: text, toolCalls: [] }]);

    const asst: Message = { role: "assistant", content: "", toolCalls: [] };
    setMessages(m => [...m, asst]);

    try {
      for await (const ev of chatStream(text)) {
        applyEvent(asst, ev, setMessages, setError);
      }
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col h-[calc(100vh-13rem)] gap-3">
      <div className="flex-1 overflow-y-auto space-y-4 pr-2">
        {messages.length === 0 && (
          <div className="text-sm text-[var(--color-muted)] py-12 text-center">
            👋 上传问卷数据,然后告诉我想做什么分析。例如:&ldquo;跑全套统计 + 输出 Word 报告&rdquo;
          </div>
        )}
        {messages.map((m, i) => (
          <MessageBubble key={i} m={m} />
        ))}
        {error && <div className="text-sm text-red-500 px-4 py-2 rounded bg-red-50 dark:bg-red-950">{error}</div>}
        <div ref={endRef} />
      </div>

      <div className="flex gap-2 border-t border-[var(--color-border)] pt-3">
        <textarea
          rows={2}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => {
            if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); send(); }
          }}
          placeholder="输入消息… (Ctrl/⌘+Enter 发送)"
          className="flex-1 px-3 py-2 rounded border bg-[var(--color-card)] resize-none focus:outline-none focus:ring-2 ring-[var(--color-accent)]"
        />
        <button
          onClick={send}
          disabled={busy || !input.trim()}
          className={cn(
            "px-5 py-2 rounded font-medium transition-colors",
            busy || !input.trim()
              ? "bg-[var(--color-border)] text-[var(--color-muted)] cursor-not-allowed"
              : "bg-[var(--color-accent)] text-[var(--color-accent-fg)] hover:opacity-90 cursor-pointer"
          )}
        >
          {busy ? "..." : "发送"}
        </button>
      </div>
    </div>
  );
}

function applyEvent(
  asst: Message,
  ev: ChatEvent,
  setMessages: React.Dispatch<React.SetStateAction<Message[]>>,
  setError: (e: string | null) => void,
) {
  switch (ev.type) {
    case "phase":
      asst.phase = ev.phase;
      break;
    case "text":
      asst.content += ev.content;
      break;
    case "tool_call":
      asst.toolCalls.push({ name: ev.name, inputs: ev.inputs });
      break;
    case "tool_result": {
      const last = [...asst.toolCalls].reverse().find(t => t.name === ev.name && !t.result);
      if (last) last.result = ev.result;
      break;
    }
    case "error":
      setError(ev.message);
      break;
    case "done":
      break;
  }
  setMessages(prev => [...prev.slice(0, -1), { ...asst }]);
}

function MessageBubble({ m }: { m: Message }) {
  if (m.role === "user") {
    return (
      <div className="flex justify-end">
        <div className="max-w-[80%] px-4 py-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-accent-fg)] whitespace-pre-wrap text-sm">
          {m.content}
        </div>
      </div>
    );
  }
  return (
    <div className="flex flex-col gap-2">
      {m.phase && (
        <div className="text-xs text-[var(--color-muted)] font-mono">phase: {m.phase}</div>
      )}
      {m.toolCalls.map((t, i) => <ToolCard key={i} t={t} />)}
      {m.content && (
        <div className="px-4 py-3 rounded-lg bg-[var(--color-card)] border whitespace-pre-wrap text-sm leading-relaxed">
          {m.content}
        </div>
      )}
    </div>
  );
}

function ToolCard({ t }: { t: ToolCallEntry }) {
  const status = t.result?.status;
  const statusColor =
    status === "ok" ? "text-emerald-600 dark:text-emerald-400" :
    status === "error" ? "text-red-600 dark:text-red-400" :
    status === "blocked" ? "text-amber-600 dark:text-amber-400" :
    "text-[var(--color-muted)]";
  return (
    <details className="text-xs rounded border bg-[var(--color-card)] open:bg-[var(--color-bg)]">
      <summary className="cursor-pointer px-3 py-2 font-mono flex items-center justify-between hover:bg-[var(--color-card)]">
        <span>🔧 {t.name}({Object.keys(t.inputs).slice(0, 3).join(", ")})</span>
        <span className={statusColor}>{status ?? "..."}</span>
      </summary>
      <div className="px-3 pb-3 space-y-2">
        <pre className="text-[10px] overflow-x-auto opacity-70">{JSON.stringify(t.inputs, null, 2)}</pre>
        {t.result && (
          <div className="text-xs">
            <div className={cn("font-medium", statusColor)}>{t.result.summary}</div>
            {t.result.next_actions && t.result.next_actions.length > 0 && (
              <ul className="mt-1 list-disc pl-4 text-[var(--color-muted)]">
                {t.result.next_actions.map((a, i) => <li key={i}>{a}</li>)}
              </ul>
            )}
          </div>
        )}
      </div>
    </details>
  );
}
