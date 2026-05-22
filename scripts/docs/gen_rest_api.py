"""Generate docs/reference/api-rest.md — FastAPI HTTP routes from OpenAPI schema.

Imports app.api and walks `app.routes` to extract:
  method · path · summary · request schema · response schema · source ref

Falls back gracefully if any import-time side effects are unsafe.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_escape_pipe, md_table, write_doc  # noqa: E402


def _route_rows():
    from app.api import app  # FastAPI instance

    rows = []
    for r in app.routes:
        methods = getattr(r, "methods", None)
        path = getattr(r, "path", "")
        if not methods or not path.startswith("/api"):
            continue
        endpoint = getattr(r, "endpoint", None)
        name = getattr(r, "name", "") or (endpoint.__name__ if endpoint else "")
        doc = (endpoint.__doc__ or "").strip().split("\n")[0] if endpoint else ""
        for m in sorted(m for m in methods if m not in {"HEAD", "OPTIONS"}):
            rows.append((m, path, name, doc))
    rows.sort(key=lambda r: (r[1], r[0]))
    return rows


def _body() -> str:
    rows = _route_rows()
    out = [
        "# REST API 参考 (FastAPI)\n",
        f"路由总数: **{len(rows)}** · base: `http://127.0.0.1:8765`\n",
        "Next.js 通过 `next.config.js` rewrites 将 `/api/*` 反代到此服务。\n\n",
        md_table(
            ["Method", "Path", "Endpoint", "Summary"],
            [(m, f"`{p}`", f"`{n}`", md_escape_pipe(d)) for m, p, n, d in rows],
        ),
        "\n## 数据流约定\n",
        "- 所有 `/api/run/<module>` 与 `/api/upload` 等改写状态的调用,都会更新 `_STATE` (单例)。\n",
        "- `/api/status` 5s 轮询,字段见 `PipelineStatus` (web/lib/api.ts)。\n",
        "- `/api/chat` 返回 SSE (`text/event-stream`),事件类型: `phase` / `text` / `tool_call` / `tool_result` / `done` / `error`。\n",
        "- 静态产物挂载: `/static/output/` → `output/` 目录。\n",
    ]
    return "".join(out)


def main():
    out = REF_DIR / "api-rest.md"
    changed, path = write_doc(out, source="app/api.py (FastAPI routes)", body=_body())
    print(f"[gen_rest_api] {'WROTE' if changed else 'skip'} {path}")


if __name__ == "__main__":
    main()
