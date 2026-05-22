"use client";

import { useState, type ReactNode } from "react";
import { cn } from "@/lib/cn";

export interface TabDef {
  id: string;
  label: string;
  icon?: ReactNode;
  content: ReactNode;
}

export function Tabs({ tabs, initial = 0 }: { tabs: TabDef[]; initial?: number }) {
  const [active, setActive] = useState(initial);
  return (
    <div className="flex flex-col w-full h-full">
      <div className="flex border-b border-[var(--color-border)] sticky top-0 z-10 bg-[var(--color-bg)] overflow-x-auto">
        {tabs.map((t, i) => (
          <button
            key={t.id}
            onClick={() => setActive(i)}
            className={cn(
              "px-4 py-3 text-sm font-medium transition-colors border-b-2 cursor-pointer flex items-center gap-2 whitespace-nowrap",
              active === i
                ? "border-[var(--color-accent)] text-[var(--color-fg)]"
                : "border-transparent text-[var(--color-muted)] hover:text-[var(--color-fg)]"
            )}
          >
            {t.icon}
            {t.label}
          </button>
        ))}
      </div>
      <div className="flex-1 p-6 overflow-y-auto">{tabs[active]?.content}</div>
    </div>
  );
}
