"""Orchestrator — regenerate all docs and write docs/INDEX.md + _generated.json.

Run with: python3 scripts/docs/gen_all.py
Or:       make docs
"""
from __future__ import annotations

import json
import sys
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import DOCS_DIR, git_short_sha, now_iso, write_doc  # noqa: E402

# Each entry: (label, module_name)
GENERATORS = [
    ("tools", "scripts.docs.gen_tools"),
    ("skills", "scripts.docs.gen_skills"),
    ("subagents", "scripts.docs.gen_subagents"),
    ("modules", "scripts.docs.gen_modules"),
    ("python_api", "scripts.docs.gen_python_api"),
    ("r_api", "scripts.docs.gen_r_api"),
    ("architecture", "scripts.docs.gen_architecture"),
    ("database", "scripts.docs.gen_database"),
]


def run_all() -> dict:
    import importlib

    results = {}
    for label, modname in GENERATORS:
        t0 = time.time()
        try:
            mod = importlib.import_module(modname)
            mod.main()
            results[label] = {"status": "ok", "duration_ms": int((time.time() - t0) * 1000)}
        except Exception:
            results[label] = {
                "status": "error",
                "traceback": traceback.format_exc(limit=4),
                "duration_ms": int((time.time() - t0) * 1000),
            }
            print(f"!! {label}: ERROR\n{traceback.format_exc(limit=4)}")
    return results


def write_index(results: dict):
    lines = ["# 技术文档 (INDEX)\n",
             "全部自动生成。改代码后跑 `make docs` 即可同步。\n",
             "\n## 生成元信息\n",
             f"- 时间: `{now_iso()}`",
             f"- git: `{git_short_sha()}`",
             ""]
    lines.append("\n## 文档列表\n")
    sections = [
        ("架构总览", "architecture.md", "architecture",
         "文件树 + 顶层目录角色 + `app/` 内部 import 图"),
        ("工具参考", "reference/tools.md", "tools",
         "19 个 agent 工具的参数 schema"),
        ("技能参考", "reference/skills.md", "skills",
         "项目 + 用户技能 (SKILL.md frontmatter)"),
        ("子代理参考", "reference/subagents.md", "subagents",
         "9 个子代理 (dispatch_subagent)"),
        ("分析模块参考", "reference/modules.md", "modules",
         "13 个 R 统计分析模块"),
        ("Python API", "reference/api-python.md", "python_api",
         "所有公开函数/类签名 + docstring"),
        ("R API", "reference/api-r.md", "r_api",
         "所有 R 函数签名 + roxygen 注释"),
        ("数据库 schema", "reference/database.md", "database",
         "voucher schema + 实况 sqlite 表结构"),
    ]
    rows = ["| 章节 | 文件 | 真源 | 状态 |", "|---|---|---|---|"]
    for title, file, label, source in sections:
        st = results.get(label, {})
        status = "✅" if st.get("status") == "ok" else "❌"
        rows.append(f"| **{title}** | [`docs/{file}`]({file}) | {source} | {status} |")
    lines.extend(rows)

    lines.append("\n## 工作流\n")
    lines.append("```bash")
    lines.append("# 改完代码后:")
    lines.append("make docs            # 重生成 docs/")
    lines.append("git diff docs/      # 看哪些文档被更新")
    lines.append("git add -A && git commit")
    lines.append("```")
    lines.append("")
    lines.append("## 添加新文档章节\n")
    lines.append("1. 在 `scripts/docs/` 新建 `gen_<thing>.py`，导出 `main()`")
    lines.append("2. 在 `scripts/docs/gen_all.py` 的 `GENERATORS` 列表注册")
    lines.append("3. 在本 INDEX 的 `sections` 列表加一行")
    lines.append("4. 跑 `make docs` 验证")
    lines.append("")
    write_doc(DOCS_DIR / "INDEX.md", source="scripts/docs/gen_all.py",
              body="\n".join(lines))


def write_metadata(results: dict):
    meta = {
        "generated_at": now_iso(),
        "git": git_short_sha(),
        "generators": results,
    }
    (DOCS_DIR / "_generated.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False))


def main():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    print("=== Regenerating all docs ===")
    results = run_all()
    write_index(results)
    write_metadata(results)
    ok = sum(1 for r in results.values() if r["status"] == "ok")
    print(f"\n=== Done: {ok}/{len(results)} ok ===")
    if ok != len(results):
        sys.exit(1)


if __name__ == "__main__":
    main()
