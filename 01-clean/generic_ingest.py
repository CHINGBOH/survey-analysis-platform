#!/usr/bin/env python3
"""
01-clean/generic_ingest.py
通用问卷入库: 任意 .xlsx / .csv → SQLite，不做字段编码。

用法:
  python3 01-clean/generic_ingest.py <survey_id> --source-file data/raw/<file>

行为:
  1. 删除并重建 data/db/<survey_id>.db
  2. 把整个 DataFrame 原样写入表 `raw_data`（列名归一化）
  3. 推断列元数据（dtype / 唯一值数 / 缺失率 / 推断量纲）写入 `variables_meta`
  4. 不会创建 respondents / responses / variables 那套消费券专用 schema
     —— 因此 R 模块（descriptives 等）跑不了，但 preview_data / 自定义 SQL 可用

适用场景: 上传的问卷不是消费券主题（字段名不匹配 schema.sql）。
"""
import argparse
import re
import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "data" / "db"
DB_DIR.mkdir(parents=True, exist_ok=True)


def normalize_col(name: str) -> str:
    """SQL-safe column name: keep CJK & alnum, replace others with _."""
    s = re.sub(r"[^\w\u4e00-\u9fff]+", "_", str(name).strip())
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "col"


def dedupe_cols(cols: list[str]) -> list[str]:
    seen: dict[str, int] = {}
    out = []
    for c in cols:
        if c in seen:
            seen[c] += 1
            out.append(f"{c}_{seen[c]}")
        else:
            seen[c] = 0
            out.append(c)
    return out


def infer_measure(s: pd.Series) -> str:
    """SPSS-style measure inference: scale / ordinal / nominal."""
    if pd.api.types.is_numeric_dtype(s):
        nunique = s.dropna().nunique()
        if nunique <= 7:
            return "ordinal"
        return "scale"
    return "nominal"


def load_dataframe(path: Path) -> pd.DataFrame:
    if path.suffix.lower() in {".xlsx", ".xls"}:
        return pd.read_excel(path)
    if path.suffix.lower() == ".csv":
        return pd.read_csv(path)
    raise ValueError(f"不支持的文件格式: {path.suffix}（支持 .xlsx/.xls/.csv）")


def ingest(survey_id: str, source_file: Path) -> dict:
    df = load_dataframe(source_file)
    original_cols = list(df.columns)
    df.columns = dedupe_cols([normalize_col(c) for c in original_cols])

    db_path = DB_DIR / f"{survey_id}.db"
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        df.to_sql("raw_data", conn, index_label="row_id", if_exists="replace")

        meta_rows = []
        for col_norm, col_orig in zip(df.columns, original_cols):
            s = df[col_norm]
            meta_rows.append({
                "name": col_norm,
                "label_original": str(col_orig),
                "dtype": str(s.dtype),
                "n_unique": int(s.dropna().nunique()),
                "n_missing": int(s.isna().sum()),
                "missing_pct": round(float(s.isna().mean()) * 100, 2),
                "spss_measure": infer_measure(s),
            })
        pd.DataFrame(meta_rows).to_sql(
            "variables_meta", conn, index=False, if_exists="replace"
        )

        conn.execute(
            "CREATE TABLE IF NOT EXISTS ingest_info ("
            "survey_id TEXT, source_file TEXT, n_rows INTEGER, n_cols INTEGER, "
            "ingested_at TEXT)"
        )
        conn.execute("DELETE FROM ingest_info WHERE survey_id=?", (survey_id,))
        conn.execute(
            "INSERT INTO ingest_info VALUES (?, ?, ?, ?, datetime('now'))",
            (survey_id, str(source_file), len(df), len(df.columns)),
        )
        conn.commit()
    finally:
        conn.close()

    return {
        "db": str(db_path),
        "n_rows": len(df),
        "n_cols": len(df.columns),
        "columns": list(df.columns),
    }


def main():
    parser = argparse.ArgumentParser(description="通用问卷入库 (不做字段编码)")
    parser.add_argument("survey_id", help="目标 survey id（如 survey1 / custom_2026q1）")
    parser.add_argument("--source-file", required=True,
                        help="源文件路径（相对仓库根目录或绝对路径）")
    args = parser.parse_args()

    src = Path(args.source_file)
    if not src.is_absolute():
        src = ROOT / src
    if not src.exists():
        print(f"ERROR: 源文件不存在: {src}", file=sys.stderr)
        sys.exit(2)

    result = ingest(args.survey_id, src)
    print(f"=== {args.survey_id} (generic ingest) ===")
    print(f"源文件:  {src.name}")
    print(f"规模:    {result['n_rows']} 行 × {result['n_cols']} 列")
    print(f"DB:      {result['db']}")
    print(f"表:      raw_data, variables_meta, ingest_info")
    print(f"前 8 列: {result['columns'][:8]}")
    print("\n✓ 通用入库完成（R 模块不可用，仅支持 preview_data / 自定义 SQL）")


if __name__ == "__main__":
    main()
