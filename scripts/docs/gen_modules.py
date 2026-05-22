"""Generate docs/reference/modules.md from ALL_MODULES + 02-analyze/*.R headers."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_table, write_doc  # noqa: E402

ANALYZE_DIR = ROOT / "02-analyze"


def extract_header(path: Path) -> str:
    lines = []
    for line in path.read_text(errors="replace").splitlines()[:40]:
        s = line.strip()
        if s.startswith("#"):
            lines.append(re.sub(r"^#'?\s?", "", s))
        elif s == "" and lines:
            continue
        elif lines:
            break
    return " ".join(l for l in lines if l).strip()


def extract_libs(path: Path) -> list[str]:
    libs = []
    for line in path.read_text(errors="replace").splitlines()[:80]:
        m = re.match(r"\s*library\(([\w.]+)\)", line)
        if m:
            libs.append(m.group(1))
    return libs


def find_output_paths(path: Path) -> list[str]:
    txt = path.read_text(errors="replace")
    return sorted(set(re.findall(r"output/results/[\w./\-]+", txt)))


def build_body() -> str:
    from app.state import ALL_MODULES, MODULE_LABELS_CN

    out = [f"# 分析模块参考 (Analysis Modules)\n",
           f"共 **{len(ALL_MODULES)}** 个统计分析模块（定义于 `app/state.py:ALL_MODULES`）。\n",
           "每个模块对应一个 `02-analyze/<module>.R` 脚本，通过 `run_analysis_module` 工具调用。\n"]

    rows = []
    for mod in ALL_MODULES:
        r_path = ANALYZE_DIR / f"{mod}.R"
        if r_path.exists():
            header = extract_header(r_path)
            libs = ", ".join(f"`{l}`" for l in extract_libs(r_path))
            script = f"`02-analyze/{mod}.R`"
        else:
            header = "(脚本缺失)"
            libs = ""
            script = f"~~`02-analyze/{mod}.R`~~"
        rows.append([
            f"`{mod}`",
            MODULE_LABELS_CN.get(mod, ""),
            script,
            header[:160],
            libs,
        ])
    out.append(md_table(
        ["module id", "中文", "R 脚本", "header 摘要", "R 依赖"],
        rows,
    ))

    out.append("\n## 模块详细 (含输出路径)\n")
    for mod in ALL_MODULES:
        r_path = ANALYZE_DIR / f"{mod}.R"
        if not r_path.exists():
            continue
        out.append(f"\n### `{mod}` — {MODULE_LABELS_CN.get(mod, '')}\n")
        out.append(f"脚本: `02-analyze/{mod}.R`\n")
        header = extract_header(r_path)
        if header:
            out.append(f"> {header}\n")
        outputs = find_output_paths(r_path)
        if outputs:
            out.append("\n**产物路径**:\n")
            for p in outputs:
                out.append(f"- `{p}`")
            out.append("")
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "modules.md",
        source="app/state.py:ALL_MODULES + 02-analyze/*.R headers",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
