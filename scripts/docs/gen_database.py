"""Generate docs/reference/database.md — SQLite schemas from live data/db/*.db.

For each .db file under data/db/, dumps via PRAGMA: table list, column defs,
row counts. Also includes the canonical voucher schema from 01-clean/schema.sql
verbatim.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from scripts.docs._common import REF_DIR, md_table, write_doc  # noqa: E402

DB_DIR = ROOT / "data" / "db"
SCHEMA_SQL = ROOT / "01-clean" / "schema.sql"


def describe_db(path: Path) -> list[str]:
    out = [f"\n### `{path.relative_to(ROOT).as_posix()}`\n"]
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error as e:
        out.append(f"*(打开失败: {e})*\n")
        return out
    try:
        tables = [r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )]
        if not tables:
            out.append("*(无表)*\n")
            return out
        out.append("**表清单 (含行数)**\n")
        out.append(md_table(
            ["表", "行数"],
            [[f"`{t}`",
              str(conn.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0])]
             for t in tables],
        ))
        for t in tables:
            cols = list(conn.execute(f'PRAGMA table_info("{t}")'))
            if not cols:
                continue
            out.append(f"\n**`{t}` 列定义**\n")
            out.append(md_table(
                ["#", "name", "type", "notnull", "default", "pk"],
                [[str(c[0]), f"`{c[1]}`", c[2] or "", "✓" if c[3] else "",
                  str(c[4]) if c[4] is not None else "", "✓" if c[5] else ""]
                 for c in cols],
            ))
    finally:
        conn.close()
    return out


def build_body() -> str:
    out = ["# 数据库 Schema 参考\n",
           "两种入库路径产生两种 schema:\n"
           "- **voucher schema** (`run_clean`): 由 `01-clean/schema.sql` 定义，"
           "包含 `respondents` 宽表 + `responses` 长表 + `variables` 元数据。"
           "字段写死消费券调研。\n"
           "- **generic schema** (`run_generic_ingest`): 由 `01-clean/generic_ingest.py` "
           "动态生成 `raw_data` 表（列名按源 Excel 推断 + 归一化），"
           "外加 `variables_meta` 推断元数据 + `ingest_info` 元信息。\n"]

    # Canonical voucher schema
    if SCHEMA_SQL.exists():
        out.append("\n## 标准 voucher schema (`01-clean/schema.sql`)\n")
        out.append("```sql\n" + SCHEMA_SQL.read_text() + "\n```\n")

    # Live DBs
    if DB_DIR.exists():
        dbs = sorted(DB_DIR.glob("*.db"))
        out.append(f"\n## 当前 `data/db/` 实况 ({len(dbs)} 个 .db)\n")
        if not dbs:
            out.append("*(无 .db 文件)*\n")
        for db in dbs:
            out.extend(describe_db(db))
    else:
        out.append("\n*(data/db/ 目录不存在)*\n")
    return "\n".join(out)


def main():
    changed, path = write_doc(
        REF_DIR / "database.md",
        source="01-clean/schema.sql + PRAGMA scan of data/db/*.db",
        body=build_body(),
    )
    print(f"{'updated' if changed else 'unchanged'}: {path}")


if __name__ == "__main__":
    main()
