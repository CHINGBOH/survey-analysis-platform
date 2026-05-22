"""Generate docs/reference/api-python.md — Python module/function/class signatures.

Uses ast (NOT import) so docs build cleanly even if a module has import-time
side-effects or missing deps. Walks: app/, 01-clean/, scripts/docs/.
"""
from __future__ import annotations

import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, rel, write_doc  # noqa: E402

SCAN_DIRS = ["app", "01-clean", "scripts/docs"]
SKIP_NAMES = {"__pycache__"}


def _format_args(node: ast.FunctionDef | ast.AsyncFunctionDef) -> str:
    parts = []
    args = node.args
    posonly = getattr(args, "posonlyargs", [])
    all_pos = list(posonly) + list(args.args)
    defaults = args.defaults
    n_defaults = len(defaults)
    n_pos = len(all_pos)
    for i, a in enumerate(all_pos):
        s = a.arg
        if a.annotation is not None:
            s += f": {ast.unparse(a.annotation)}"
        idx_from_end = n_pos - i
        if idx_from_end <= n_defaults:
            d = defaults[n_defaults - idx_from_end]
            s += f"={ast.unparse(d)}"
        parts.append(s)
    if args.vararg:
        s = "*" + args.vararg.arg
        if args.vararg.annotation is not None:
            s += f": {ast.unparse(args.vararg.annotation)}"
        parts.append(s)
    for i, a in enumerate(args.kwonlyargs):
        s = a.arg
        if a.annotation is not None:
            s += f": {ast.unparse(a.annotation)}"
        if i < len(args.kw_defaults) and args.kw_defaults[i] is not None:
            s += f"={ast.unparse(args.kw_defaults[i])}"
        parts.append(s)
    if args.kwarg:
        s = "**" + args.kwarg.arg
        if args.kwarg.annotation is not None:
            s += f": {ast.unparse(args.kwarg.annotation)}"
        parts.append(s)
    out = "(" + ", ".join(parts) + ")"
    if node.returns is not None:
        out += f" -> {ast.unparse(node.returns)}"
    return out


def _summary(doc: str | None) -> str:
    if not doc:
        return ""
    line = doc.strip().splitlines()[0]
    return line[:240]


def _scan_module(path: Path) -> list[str]:
    """Return markdown lines for one .py file."""
    try:
        tree = ast.parse(path.read_text(errors="replace"))
    except SyntaxError as e:
        return [f"### `{rel(path)}`\n\n*(SyntaxError: {e})*\n"]
    out = [f"### `{rel(path)}`\n"]
    mod_doc = ast.get_docstring(tree)
    if mod_doc:
        out.append(f"> {_summary(mod_doc)}\n")
    has_any = False
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.name.startswith("_") and not node.name.startswith("__"):
                continue
            has_any = True
            sig = _format_args(node)
            doc = _summary(ast.get_docstring(node))
            out.append(f"- **`{node.name}{sig}`**" + (f" — {doc}" if doc else ""))
        elif isinstance(node, ast.ClassDef):
            has_any = True
            out.append(f"- **`class {node.name}`** — " +
                       (_summary(ast.get_docstring(node)) or ""))
            for sub in node.body:
                if isinstance(sub, (ast.FunctionDef, ast.AsyncFunctionDef)) and not sub.name.startswith("_"):
                    sig = _format_args(sub)
                    sdoc = _summary(ast.get_docstring(sub))
                    out.append(f"    - `{node.name}.{sub.name}{sig}`" +
                               (f" — {sdoc}" if sdoc else ""))
    if not has_any:
        out.append("*(无公开符号)*")
    out.append("")
    return out


def build_body() -> str:
    out = [f"# Python API 参考\n",
           "由 `ast` 静态解析提取（不会真的 import 模块）。仅列公开符号"
           "（顶层函数/类，不含下划线开头的私有项）。\n"]

    for d in SCAN_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        out.append(f"\n## `{d}/`\n")
        for path in sorted(base.rglob("*.py")):
            if any(p in SKIP_NAMES for p in path.parts):
                continue
            if path.name == "__init__.py" and path.stat().st_size == 0:
                continue
            out.extend(_scan_module(path))
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "api-python.md",
        source="ast.parse of app/**/*.py + 01-clean/**/*.py + scripts/docs/**/*.py",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
