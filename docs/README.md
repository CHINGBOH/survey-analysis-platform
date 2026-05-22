# 文档目录 (`docs/`)

**全部内容由 `scripts/docs/` 自动生成。** 不要手编辑这里的 `.md`，会被下次 `make docs` 覆盖。

## 重生成

```bash
make docs            # 一键重生成所有文档
make docs-check      # CI 用：跑 docs 后检查 git diff 是否干净
```

## 入口

→ 看 [`INDEX.md`](INDEX.md)（自动生成的总目录，含每个章节的真源映射与状态）

## 真源 → 文档映射

| 改这里的代码 | 自动同步到这个文档 |
|---|---|
| `app/agent.py:TOOL_DEFS` | `reference/tools.md` |
| `agent/skills/**/SKILL.md` frontmatter | `reference/skills.md` |
| `agent/subagents/*.md` | `reference/subagents.md` |
| `app/state.py:ALL_MODULES` + `02-analyze/*.R` | `reference/modules.md` |
| 任何 `app/**/*.py` 的 docstring / 签名 | `reference/api-python.md` |
| 任何 `02-analyze/*.R` 的注释 / 函数签名 | `reference/api-r.md` |
| `01-clean/schema.sql` + `data/db/*.db` | `reference/database.md` |
| 项目目录结构 + Python imports | `architecture.md` |

## 设计原则

1. **代码即真源** — 文档从代码 introspection（`ast` / 正则 / SQLite PRAGMA / 文件遍历）生成，不依赖手动同步。
2. **幂等** — `make docs` 多次跑结果稳定（结构无变化时不会重写文件，CI `git diff --exit-code` 可靠）。
3. **失败不阻塞其他章节** — 任意 generator 报错只影响自己那一节，`INDEX.md` 会标红。
4. **零运行时依赖** — Python 用 `ast` 不真 import；R 用正则不需要 R runtime。
