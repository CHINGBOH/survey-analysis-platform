# Copilot Instructions — Survey Analysis Platform

问卷调查数据分析平台：一个 LLM agent 编排的、SPSS 等价的统计分析流水线。前端 Next.js / Streamlit，后端 FastAPI + DeepSeek agent loop，统计计算用 R，数据存 SQLite。

## Architecture (the big picture)

Data flows through a loosely-coupled pipeline. **Read these layers together** — no single file shows the whole flow:

```
Excel (data/raw/) → SQLite (data/db/<id>.db) → R modules (.rds) → compiled.rds → Quarto HTML
       upload          01-clean/*.py             02-analyze/*.R    03-integrate    04-report
```

- **Cleaning is Python, not R.** Despite README prose mentioning RDS, the real ingest path is `01-clean/clean_to_sqlite.py` (consumption-voucher schema) and `01-clean/generic_ingest.py` (arbitrary xlsx). Each rebuilds `data/db/<id>.db` from scratch (delete + recreate, never append). Schema in `01-clean/schema.sql`.
- **R analysis modules** (`02-analyze/*.R`) read SQLite via `lib/db.R`, compute SPSS-equivalent stats, and write `output/results/<module>_<sid>.rds`. They optionally read `output/results/analysis_plan.json` to scope variables; with no plan they auto-select columns.
- **The agent layer** (`app/`) is the real orchestrator. A DeepSeek tool-use loop (`app/agent.py`, ReAct pattern) drives ~19 tools (`app/tools.py`), each of which shells out to `make`/`Rscript`/Python and returns `{status, summary, next_actions, artifacts}`.
- **Two frontends, one backend.** `app/api.py` (FastAPI, SSE) is canonical and is consumed by the Next.js app in `web/`. `app/main.py` (Streamlit) is a legacy fallback — new features land in the FastAPI + Next.js path only.

### Agent control system (the non-obvious core)

The agent's reliability comes from three cooperating layers — understand all three before touching `app/`:

1. **Router** (`app/router.py`) — soft phase gate. Infers `Phase` (EXPLORE→CLEAN→ANALYZE→REPORT→DONE) from **filesystem ground truth** (does `survey1.db` exist? how many `*_s*.rds`?), not from LLM claims. It narrows the exposed tool set per phase to reduce drift. Crucially, the pipeline stays in EXPLORE until the user *explicitly* selects a data file this session — leftover DB/results on disk do NOT auto-resume.
2. **Hooks** (`app/hooks.py`) — hard prerequisite enforcement. `pre_tool_use` BLOCKS a tool if its preconditions aren't met (e.g. `run_analysis_module` needs clean SQLite; `run_compile` needs ≥1 result). All lifecycle events append to `logs/events.jsonl`.
3. **Plan gate** (`app/plan_review_gate.py`) — `set_analysis_plan` passes through a 3-axis review (feasibility / completeness / scope alignment). On `status: blocked`, the agent must fix per `next_actions`, not retry blindly.

State is a single in-process `AppState` (`app/state.py`, `PipelineStage` enum) — P1 is single-user; multi-session isolation is deliberately deferred. The agent system prompt lives in `agent/system_prompt.md` (Chinese; defines analyst persona + workflow + the 13 modules).

### Anti-hallucination invariants (do not break)

- **Never fabricate statistics.** Every number shown to the user must come from a tool's `.rds`/JSON result. This is the platform's reason to exist.
- **No ASCII/text "charts."** Charts are real PNGs from `render_charts` → `output/charts/<module>_<suffix>/*.png`, viewed in the gallery tab. The system prompt forbids simulating plots with characters.
- **survey_id is explicit**, derived from the uploaded filename via `app/surveys.py` — the agent must not invent a second survey or assume a comparison.

## Build / run / test commands

Everything routes through the `Makefile` (run `make help`). Key targets:

```bash
make api            # FastAPI backend on :8765 (uvicorn app.api:app --reload)
make web-dev        # Next.js dev on :3000, rewrites /api/* → :8765 (web/next.config.ts)
make app            # Streamlit legacy UI on :8501

make clean          # Excel → SQLite (clean_to_sqlite.py all); clean_s1 / clean_s2 for one survey
make analyze        # run ALL 02-analyze/*.R; or run ONE module by name: `make descriptives`, `make mediation`
make integrate      # 03-integrate/compile.R → compiled.rds
make report         # quarto render → output/reports/
make all            # clean → analyze → integrate → report

make lint           # R parse-check only (no execution) over 02-analyze/*.R + lib/*.R
make db_info        # row counts in data/db/*.db
make docs           # regenerate ALL docs/ from code (see below)
```

- **Run a single analysis module:** `Rscript 02-analyze/<module>.R <survey_id>` (e.g. `Rscript 02-analyze/ttest.R survey1`). The `make <module>` target wraps this.
- **Frontend checks:** `cd web && npx tsc --noEmit` (or `make web-typecheck`); `next lint`.
- **E2E smoke:** `make smoke` (Playwright via `scripts/smoke/run.mjs`). **Requires** FastAPI `:8765` + Next.js **production** (`next build && next start`) `:3000` already running — Turbopack dev mode has hydration issues under headless Playwright.

There is no Python unit-test suite; validation is the E2E smoke test plus `make lint` for R.

## Conventions

- **Tool contract:** every function in `app/tools.py` returns `{status: "ok"|"error"|"blocked", summary, next_actions, artifacts}`. Use the `_ok()` / `_err()` helpers; on error, point `next_actions` at `read_log`. Don't return raw strings/exceptions to the agent.
- **Adding an analysis module:** create `02-analyze/<name>.R` reading SQLite via `lib/db.R`, output `output/results/<name>_<sid>.rds` with `list(tables=, stats=, notes=)`. Then register the name in `ANALYZE_MODULES` (Makefile), `ALL_MODULES` + `MODULE_LABELS_CN` + `MODULE_GROUPS` (`app/state.py`), and `.hermes/config.yaml`. Keep these lists in sync.
- **R scripts** prepend `.libPaths(c("~/R/libs", .libPaths()))` and accept an optional `survey_id` CLI arg (default = run all surveys).
- **Docs are generated, not hand-written.** Everything under `docs/` (except a few) is emitted by `scripts/docs/gen_*.py`. Edit the generators, then run `make docs`. `make docs-check` fails CI if `docs/` drifts from code — run `make docs` and commit before pushing.
- **Secrets:** `DEEPSEEK_API_KEY` (required) and optional `LANGFUSE_*` live in `.env` (gitignored), auto-loaded via `python-dotenv` at both entrypoints. Never hardcode keys or ask the user to re-export. Copy `.env.example` to start.
- **Language:** user-facing strings, the system prompt, and most comments are Chinese; keep new UI/agent text Chinese to match.
- **Observability:** `app/observability.py` wraps the OpenAI client and reports LLM + tool calls to Langfuse when `LANGFUSE_*` is set; it silently no-ops otherwise — guard new instrumentation the same way.

## Key files to read first

- `agent/system_prompt.md` — agent persona, workflow, the 13 statistical modules.
- `app/agent.py` + `app/tools.py` — the loop and the tools it calls.
- `app/router.py` + `app/hooks.py` — phase gating + hard prerequisites.
- `lib/db.R` + `01-clean/schema.sql` — the SQLite data model (wide `respondents` + long `responses` + `variables`).
- `README.md` — user-facing quickstart (note: its "RDS pipeline" diagram predates the SQLite ingest; trust the Makefile/code).
