// scripts/smoke/run.mjs — E2E smoke for Survey Analysis Platform
// 用法: node scripts/smoke/run.mjs [path/to/xlsx]
//
// 流程: 启动 chromium → 上传 xlsx → run_clean → 4 模块分析 →
//       render_charts → 截图全部 5 tab + lightbox + chat SSE
//
// 前置: FastAPI :8765 + Next.js prod :3000 必须先启动
//       (开发模式 dev 在 headless 下偶有 hydration 异常,务必用 next start)
//
// 截图: scripts/smoke/shots/01..10.png

import { chromium } from "playwright-chromium";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "shots");
fs.mkdirSync(OUT, { recursive: true });

const BASE = process.env.SMOKE_BASE || "http://127.0.0.1:3000";
const FILE = process.argv[2] ||
  "/home/l/文档/数据分析Excel/问卷调查/问卷数据_完整版_209条.xlsx";

if (!fs.existsSync(FILE)) {
  console.error("[SMOKE] file not found:", FILE);
  process.exit(2);
}

const log = (...a) => console.log("[SMOKE]", ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function shoot(page, name) {
  await page.screenshot({ path: path.join(OUT, `${name}.png`), fullPage: true });
  log("📸", name);
}
async function tab(page, label) {
  await page.locator("button", { hasText: label }).first().click();
  await sleep(700);
}
async function api(page, route, body) {
  return await page.evaluate(
    async ({ r, b }) => {
      const res = await fetch(r, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(b),
      });
      return res.json();
    },
    { r: route, b: body },
  );
}

const errors = [];
(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  page.on("console", (m) => {
    if (m.type() === "error" && !m.text().includes("webpack-hmr"))
      errors.push("console: " + m.text());
  });
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("requestfailed", (r) => {
    const u = r.url();
    if (!u.includes("favicon") && !u.includes(".woff") && !u.includes("hmr"))
      errors.push(`reqfail: ${u} - ${r.failure()?.errorText}`);
  });

  log("FILE:", FILE);
  log("BASE:", BASE);

  await page.goto(BASE, { waitUntil: "networkidle" });
  await sleep(1500);
  await shoot(page, "01-home");

  // 数据 tab — 空状态
  await tab(page, "数据");
  await sleep(800);
  await shoot(page, "02-data-empty");

  // 上传
  log("uploading...");
  await page.locator("input[type=file]").first().setInputFiles(FILE);
  await sleep(4000);
  await shoot(page, "03-data-uploaded");

  const stat = await page.evaluate(async () => (await fetch("/api/status")).json());
  const SID = stat.active_survey_id || "survey1";
  log("active survey:", SID);

  // 清洗 + 4 模块分析
  log("clean...");
  log("  →", (await api(page, "/api/run/run_clean", { inputs: { target: SID } })).status);
  for (const m of ["descriptives", "reliability", "factor_analysis", "correlation"]) {
    const r = await api(page, "/api/run/run_analysis_module", {
      inputs: { module: m, survey_id: SID },
    });
    log(`  ${m} → ${r.status}`);
  }
  log("render_charts (3 modules)...");
  for (const m of ["descriptives", "correlation", "factor_analysis"]) {
    await api(page, "/api/run/render_charts", { inputs: { module: m, survey_id: SID } });
  }

  // 分析面板 — 模块应显示 done
  await tab(page, "分析模块");
  await sleep(2000);
  await shoot(page, "04-analysis-after-runs");

  // 图表画廊
  await tab(page, "图表画廊");
  await sleep(3000);
  await shoot(page, "05-gallery-with-charts");

  // 灯箱
  const img = page.locator("img").first();
  if ((await img.count()) > 0) {
    await img.click({ force: true });
    await sleep(800);
    await shoot(page, "06-lightbox");
    // 点叠层关闭灯箱
    await page.locator(".cursor-zoom-out").first().click({ force: true }).catch(() => {});
    await page.keyboard.press("Escape").catch(() => {});
    await sleep(800);
  }

  // 切到 correlation 模块
  const corrChip = page.locator("button:has-text('correlation')").first();
  if ((await corrChip.count()) > 0) {
    await corrChip.click();
    await sleep(2000);
    await shoot(page, "07-gallery-correlation");
  }

  // 报告
  log("generate word + bundle...");
  await api(page, "/api/run/generate_word", { inputs: { survey_id: SID } });
  await api(page, "/api/run/export_charts_bundle", { inputs: { survey_id: SID } });
  await tab(page, "报告");
  await sleep(2000);
  await shoot(page, "08-reports");

  // 聊天 — 先重置避免历史串台
  await page.evaluate(() => fetch("/api/chat/reset", { method: "POST" }));
  await sleep(500);
  await tab(page, "分析助手");
  await sleep(800);
  await shoot(page, "09-chat-empty");
  await page.locator("textarea").first().fill("用一两句话总结当前已完成的分析和发现");
  await page.locator("button", { hasText: "发送" }).first().click();
  await sleep(30000);
  await shoot(page, "10-chat-reply");

  await browser.close();
  log("\nERRORS:", errors.length);
  errors.forEach((e) => log("❌", e));
  process.exit(errors.length > 0 ? 1 : 0);
})().catch((e) => {
  console.error("[SMOKE] FATAL", e);
  process.exit(1);
});
