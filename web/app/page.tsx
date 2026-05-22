import { Tabs } from "@/components/Tabs";
import { Chat } from "@/components/Chat";
import { Upload } from "@/components/Upload";
import { AnalysisPanel } from "@/components/AnalysisPanel";
import { ChartGallery } from "@/components/ChartGallery";
import { Reports } from "@/components/Reports";
import { StatusBar } from "@/components/StatusBar";

export default function Home() {
  return (
    <main className="flex flex-col h-screen">
      <header className="px-6 py-3 border-b border-[var(--color-border)] flex items-center justify-between bg-[var(--color-card)]">
        <h1 className="text-base font-semibold">📊 Survey Analysis Platform</h1>
        <span className="text-xs text-[var(--color-muted)] font-mono">Next.js 16 · FastAPI</span>
      </header>
      <StatusBar />
      <div className="flex-1 overflow-hidden">
        <Tabs
          tabs={[
            { id: "chat",     label: "💬 分析助手",   content: <Chat /> },
            { id: "data",     label: "📁 数据",       content: <Upload /> },
            { id: "analysis", label: "📊 分析模块",   content: <AnalysisPanel /> },
            { id: "charts",   label: "🖼️ 图表画廊",   content: <ChartGallery /> },
            { id: "reports",  label: "📄 报告中心",   content: <Reports /> },
          ]}
        />
      </div>
    </main>
  );
}
