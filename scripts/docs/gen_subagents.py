"""Generate docs/reference/subagents.md from agent/subagents/*.md."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_table, rel, write_doc  # noqa: E402

SUBAGENTS_DIR = ROOT / "agent" / "subagents"
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_md(path: Path) -> dict:
    text = path.read_text(errors="replace")
    info: dict = {"name": path.stem, "summary": "", "role": ""}
    m = FRONTMATTER_RE.match(text)
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, _, v = line.partition(":")
                info[k.strip()] = v.strip().strip('"').strip("'")
        text = text[m.end():]
    if not info.get("summary"):
        for line in text.splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                info["summary"] = line[:200]
                break
    return info


def build_body() -> str:
    files = sorted(SUBAGENTS_DIR.glob("*.md"))
    out = [f"# 子代理参考 (Subagents Reference)\n",
           f"共 **{len(files)}** 个子代理，通过 `dispatch_subagent` 工具调用。\n",
           "子代理使用 bare OpenAI 客户端直连 DeepSeek (跳过 Langfuse 包裹以避免 governor 拒绝)。\n",
           "默认模型 `deepseek-chat`，可由 `SUBAGENT_MODEL` 环境变量覆盖。\n"]

    rows = []
    for f in files:
        info = parse_md(f)
        rows.append([
            f"`{info['name']}`",
            info.get("role", ""),
            info.get("summary", ""),
            f"`{rel(f)}`",
        ])
    out.append(md_table(["agent", "role / description", "summary", "spec file"], rows))
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "subagents.md",
        source="agent/subagents/*.md",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
