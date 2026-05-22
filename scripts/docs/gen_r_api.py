"""Generate docs/reference/api-r.md — R function signatures + roxygen comments.

Regex-based (no R runtime needed). Extracts:
  - Leading `#` / `#'` doc blocks immediately above each `<name> <- function(...)`
  - The function signature itself
  - `library(...)` calls per file (top-level only)
Scans: 01-clean/*.R, 02-analyze/*.R, 03-integrate/*.R, 04-report/**/*.R
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, rel, write_doc  # noqa: E402

SCAN_DIRS = ["01-clean", "02-analyze", "03-integrate", "04-report"]

FUNC_RE = re.compile(
    r"^([A-Za-z_.][\w.]*)\s*<-\s*function\s*\(([^)]*)\)",
    re.MULTILINE,
)


def extract_docblock(lines: list[str], idx: int) -> str:
    """Walk backwards from line idx collecting consecutive `#'` or `#` lines."""
    block = []
    i = idx - 1
    while i >= 0:
        s = lines[i].strip()
        if s.startswith("#"):
            block.append(re.sub(r"^#'?\s?", "", s))
            i -= 1
        else:
            break
    return " ".join(reversed(block)).strip()


def scan_r_file(path: Path) -> list[str]:
    text = path.read_text(errors="replace")
    lines = text.splitlines()
    out = [f"### `{rel(path)}`\n"]

    # Top-of-file header (consecutive `#` block at line 0..N)
    header = []
    for line in lines[:40]:
        s = line.strip()
        if s.startswith("#"):
            header.append(re.sub(r"^#'?\s?", "", s))
        elif s == "" and header:
            continue
        elif header:
            break
    if header:
        head = " ".join(h for h in header if h)
        if head:
            out.append(f"> {head[:300]}\n")

    libs = sorted({m.group(1) for m in re.finditer(r"library\(([\w.]+)\)", text)})
    if libs:
        out.append("依赖: " + ", ".join(f"`{l}`" for l in libs) + "\n")

    # Functions
    funcs = list(FUNC_RE.finditer(text))
    if not funcs:
        out.append("*(无函数定义；可能是脚本式 R)*\n")
        return out

    # Find each function's line number to look back for doc
    for m in funcs:
        name = m.group(1)
        sig = re.sub(r"\s+", " ", m.group(2)).strip()
        # locate line index
        pre = text[: m.start()]
        line_idx = pre.count("\n")
        doc = extract_docblock(lines, line_idx)
        sig_str = f"`{name}({sig})`"
        if doc:
            out.append(f"- {sig_str} — {doc[:240]}")
        else:
            out.append(f"- {sig_str}")
    out.append("")
    return out


def build_body() -> str:
    out = [f"# R API 参考\n",
           "由正则扫描提取（无需 R 运行时）。文档块识别规则: 函数定义上方连续的 `#` 或 `#'` 注释。\n"]
    for d in SCAN_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        out.append(f"\n## `{d}/`\n")
        for path in sorted(base.rglob("*.R")):
            out.extend(scan_r_file(path))
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "api-r.md",
        source="regex scan of 01-clean/**/*.R, 02-analyze/**/*.R, 03-integrate/**/*.R, 04-report/**/*.R",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
