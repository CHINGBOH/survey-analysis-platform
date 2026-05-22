"""FastAPI REST + SSE 接口 — Next.js 前端 / curl / 其他客户端共用。

设计原则:
- 复用 app/agent.py:run_agent_turn (SSE 化, 不重写 agent loop)
- 复用 app/tools.py 19 个工具 (走 _dispatch, 共享 hooks/gate/observability)
- 状态用进程内单例 AppState (P1 单用户; 多用户隔离留给后续 issue)
- 错误统一 {"status":"error","summary":...}, 与工具层一致

运行:
    uvicorn app.api:app --host 0.0.0.0 --port 8000 --reload

或:
    make api
"""
from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any, AsyncIterator, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.agent import _dispatch, run_agent_turn
from app.state import AppState
from app.surveys import (
    default_survey,
    derive_survey_id,
    is_valid_survey_id,
    list_surveys,
)

ROOT = Path(__file__).resolve().parent.parent

# 加载 .env (与 streamlit 入口一致)
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass

DATA_RAW = ROOT / "data" / "raw"
OUTPUT = ROOT / "output"
CHARTS = OUTPUT / "charts"
RESULTS = OUTPUT / "results"
REPORTS = OUTPUT / "reports"

# ──────────────────────────────────────────────────────────────────
# 进程内单例 state
# (P1 简化方案; 多用户/多会话隔离见后续 issue)
# ──────────────────────────────────────────────────────────────────
_STATE = AppState()

# 持久化聊天历史 (OpenAI message 格式)
_CHAT_HISTORY: list[dict] = []


def get_state() -> AppState:
    return _STATE


# ──────────────────────────────────────────────────────────────────
# App 初始化
# ──────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Survey Analysis Platform API",
    version="1.0.0",
    description="REST + SSE 接口,封装 agent loop / 19 个分析工具 / 图表 / 报告",
)

# CORS — 允许 Next.js dev (3000) 和生产域名
_origins = os.environ.get(
    "CORS_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000",
).split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件:直接挂载 output/ 让前端用 <img src> 访问图表
if OUTPUT.exists():
    app.mount("/static/output", StaticFiles(directory=str(OUTPUT)), name="output")


# ──────────────────────────────────────────────────────────────────
# Schema
# ──────────────────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str
    reset: bool = False  # 清空历史重开
    session_id: Optional[str] = None
    user_id: Optional[str] = None


class ToolRunRequest(BaseModel):
    inputs: dict[str, Any] = {}


class PlanRequest(BaseModel):
    surveys: list[str]
    modules: list[str]
    compare: bool = False
    focus: str = ""


# ──────────────────────────────────────────────────────────────────
# Health / Meta
# ──────────────────────────────────────────────────────────────────
@app.get("/api/health")
def health():
    return {"status": "ok", "version": app.version}


@app.get("/api/surveys")
def list_all_surveys():
    """列出已发现的所有 survey_id (从 data/db/*.db + data/raw/*.{xlsx,csv} 推导)."""
    surveys = list_surveys()
    return {
        "surveys": surveys,
        "active": _STATE.active_survey_id,
        "default": default_survey(),
    }


@app.get("/api/status")
def pipeline_status():
    """整体管道状态 — stage / 模块进度 / 已完成 / plan."""
    return {
        "stage": _STATE.stage.value,
        "active_survey_id": _STATE.active_survey_id,
        "uploaded_filename": _STATE.uploaded_filename,
        "clean_done": _STATE.clean_done,
        "modules": {m: s.value for m, s in _STATE.module_statuses.items()},
        "done_modules": _STATE.done_modules(),
        "report_path": _STATE.report_path,
        "plan": _STATE.plan,
    }


# ──────────────────────────────────────────────────────────────────
# Charts
# ──────────────────────────────────────────────────────────────────
@app.get("/api/charts")
def list_chart_modules():
    """列出所有已生成图表的模块目录."""
    if not CHARTS.exists():
        return {"modules": []}
    mods = []
    for d in sorted(CHARTS.iterdir()):
        if d.is_dir():
            pngs = sorted(d.glob("*.png"))
            mods.append({
                "module": d.name,
                "count": len(pngs),
                "files": [p.name for p in pngs],
            })
    return {"modules": mods}


@app.get("/api/charts/{module}")
def list_chart_files(module: str):
    """列出单个模块的所有图表文件."""
    d = CHARTS / module
    if not d.is_dir():
        raise HTTPException(404, f"module {module} 无图表")
    pngs = sorted(d.glob("*.png"))
    return {
        "module": module,
        "count": len(pngs),
        "files": [{"name": p.name, "url": f"/static/output/charts/{module}/{p.name}", "size": p.stat().st_size} for p in pngs],
    }


@app.get("/api/charts/{module}/{filename}")
def get_chart_file(module: str, filename: str):
    """直接返回 PNG 文件 (备份路径; 推荐用 /static/output/charts/...)."""
    p = CHARTS / module / filename
    if not p.exists() or p.suffix.lower() != ".png":
        raise HTTPException(404)
    return FileResponse(str(p), media_type="image/png")


# ──────────────────────────────────────────────────────────────────
# Results
# ──────────────────────────────────────────────────────────────────
@app.get("/api/results/{module}")
def get_results_json(module: str, survey_id: Optional[str] = None):
    """读取模块结果 JSON (如不存在则触发 RDS→JSON 转换)."""
    sid = survey_id or _STATE.active_survey_id or default_survey()
    if not sid:
        raise HTTPException(400, "无可用 survey_id")
    from app.tools import survey_suffix
    suf = survey_suffix(sid)
    json_path = RESULTS / f"{module}_{suf}.json"
    if not json_path.exists():
        rds = RESULTS / f"{module}_{suf}.rds"
        if not rds.exists():
            raise HTTPException(404, f"{module}_{suf}.rds 不存在,请先运行该模块")
        import subprocess
        rc = subprocess.run(
            ["Rscript", str(ROOT / "02-analyze" / "rds_to_json.R"), str(rds), "500"],
            cwd=str(ROOT), capture_output=True, text=True, timeout=60,
        )
        if not json_path.exists():
            raise HTTPException(500, f"RDS→JSON 转换失败: {rc.stderr[-300:]}")
    return json.loads(json_path.read_text(encoding="utf-8"))


# ──────────────────────────────────────────────────────────────────
# Reports
# ──────────────────────────────────────────────────────────────────
@app.get("/api/reports")
def list_reports():
    if not REPORTS.exists():
        return {"reports": []}
    items = []
    for p in sorted(REPORTS.iterdir()):
        if p.is_file():
            items.append({
                "name": p.name,
                "size": p.stat().st_size,
                "url": f"/static/output/reports/{p.name}",
                "mtime": p.stat().st_mtime,
            })
    return {"reports": items}


@app.get("/api/reports/{filename}")
def download_report(filename: str):
    p = REPORTS / filename
    if not p.exists():
        raise HTTPException(404)
    return FileResponse(str(p), filename=filename)


# ──────────────────────────────────────────────────────────────────
# Upload
# ──────────────────────────────────────────────────────────────────
@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    """接收 .xlsx/.csv,落到 data/raw/,派生 active_survey_id."""
    if not file.filename:
        raise HTTPException(400, "文件名为空")
    ext = Path(file.filename).suffix.lower()
    if ext not in (".xlsx", ".xls", ".csv"):
        raise HTTPException(400, f"仅支持 xlsx/xls/csv, got {ext}")

    DATA_RAW.mkdir(parents=True, exist_ok=True)
    dest = DATA_RAW / file.filename
    with dest.open("wb") as f:
        shutil.copyfileobj(file.file, f)

    sid = derive_survey_id(file.filename)
    _STATE.uploaded_filename = file.filename
    _STATE.uploaded_path = str(dest)
    _STATE.active_survey_id = sid

    return {
        "status": "ok",
        "filename": file.filename,
        "path": str(dest),
        "survey_id": sid,
        "next_actions": [
            f"调用 /api/run/run_clean (target='{sid}') 或 /api/run/run_generic_ingest",
            "在 /api/chat 告诉 agent 想做哪些分析",
        ],
    }


# ──────────────────────────────────────────────────────────────────
# Tool 直接调用
# ──────────────────────────────────────────────────────────────────
@app.post("/api/run/{tool}")
def run_tool(tool: str, req: ToolRunRequest):
    """直接触发某个工具 (前端按钮用; 不经过 agent loop)."""
    args = json.dumps(req.inputs, ensure_ascii=False)
    result = _dispatch(tool, args, _STATE)
    return result


# ──────────────────────────────────────────────────────────────────
# Chat — SSE 流式
# ──────────────────────────────────────────────────────────────────
def _sse(event_type: str, data: Any) -> str:
    """打包成 Server-Sent Event 文本块."""
    payload = json.dumps({"type": event_type, **(data if isinstance(data, dict) else {"data": data})}, ensure_ascii=False)
    return f"data: {payload}\n\n"


@app.post("/api/chat")
async def chat(req: ChatRequest, request: Request):
    """流式聊天 — SSE 协议.

    事件类型:
      - phase:        {"phase": "..."}
      - text:         {"content": "..."}
      - tool_call:    {"name": "...", "inputs": {...}}
      - tool_result:  {"name": "...", "result": {...}}
      - done:         最后一条
      - error:        {"message": "..."}
    """
    if req.reset:
        _CHAT_HISTORY.clear()

    _CHAT_HISTORY.append({"role": "user", "content": req.message})

    async def stream() -> AsyncIterator[str]:
        try:
            for ev in run_agent_turn(
                _CHAT_HISTORY,
                _STATE,
                session_id=req.session_id,
                user_id=req.user_id,
            ):
                if await request.is_disconnected():
                    break
                yield _sse(ev.pop("type"), ev)
            yield _sse("done", {"history_len": len(_CHAT_HISTORY)})
        except Exception as e:
            yield _sse("error", {"message": f"{type(e).__name__}: {e}"})

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.get("/api/chat/history")
def chat_history():
    """读取当前会话历史 (前端首次加载用)."""
    return {"messages": _CHAT_HISTORY, "length": len(_CHAT_HISTORY)}


@app.post("/api/chat/reset")
def chat_reset():
    _CHAT_HISTORY.clear()
    return {"status": "ok", "length": 0}


# ──────────────────────────────────────────────────────────────────
# 模块 / 工具发现
# ──────────────────────────────────────────────────────────────────
@app.get("/api/tools")
def list_tools():
    """列出所有可用工具 (供前端按钮 UI 渲染)."""
    from app.agent import TOOL_DEFS
    return {
        "tools": [
            {
                "name": t["function"]["name"],
                "description": t["function"].get("description", ""),
                "parameters": t["function"].get("parameters", {}),
            }
            for t in TOOL_DEFS
        ]
    }


@app.get("/api/modules")
def list_modules():
    """列出所有 13 个分析模块."""
    from app.state import ALL_MODULES
    return {"modules": ALL_MODULES}
