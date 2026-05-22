# E2E Smoke Test

Playwright-driven end-to-end smoke test that uploads an .xlsx, runs clean +
4 analysis modules, generates charts + Word + bundle, and verifies SSE chat —
all captured as 10 fullPage screenshots.

## Prerequisites

```bash
# 1. 启动后端 (terminal 1)
make api                                  # FastAPI :8765

# 2. 启动前端 — 必须是 production build,dev 模式 hydration 在 headless 下不稳
cd web && npx next build && npx next start --port 3000

# 3. 安装 Playwright (首次)
cd scripts/smoke && npm install
```

## 运行

```bash
# 默认数据: 问卷数据_完整版_209条.xlsx
node scripts/smoke/run.mjs

# 自定义文件
node scripts/smoke/run.mjs /path/to/survey.xlsx

# 不同 base URL
SMOKE_BASE=http://127.0.0.1:3000 node scripts/smoke/run.mjs
```

退出码: `0` 表示 0 console errors;`1` 表示有错误(打印 stderr)。

## 截图

输出到 `scripts/smoke/shots/01..10.png`:

| # | 验证内容 |
|---|---|
| 01 | 首页 + StatusBar + 5 tab |
| 02 | 数据 tab 空状态 |
| 03 | 上传后 survey 派生 + active 徽章 |
| 04 | 分析面板 — 4 模块 done badge |
| 05 | 图表画廊 — 缩略图列表 |
| 06 | 灯箱全屏预览 |
| 07 | 切换 correlation 模块 |
| 08 | 报告中心 — docx + zip |
| 09 | 聊天空状态 |
| 10 | 聊天 SSE 回复(含 Markdown) |

## 维护要点

- 上传前不要手动 `rm data/raw data/db` — 脚本依赖前端识别空状态;若要全清,在外面跑 `rm -f data/raw/*.xlsx data/db/*.db && rm -rf output/charts/* output/reports/{*.docx,*.zip,images_*}` 然后等 FastAPI `--reload` 重启再跑。
- survey_id 由 `/api/status.active_survey_id` 动态读取,**不要硬编码** survey1/survey2。
- 聊天前会调 `/api/chat/reset`,避免历史串台。
- Next.js dev 模式 (Turbopack) 不可靠,务必用 `next start`。
