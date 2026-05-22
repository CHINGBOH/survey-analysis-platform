"""app/ui/pages.py — 多 tab 页面渲染 (数据/分析/图表/报告)"""
from __future__ import annotations
import json, sqlite3
from pathlib import Path
import streamlit as st
import streamlit.components.v1 as components

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output"
DB_DIR = ROOT / "data" / "db"

MODULE_TITLES = {
    "descriptives": "描述统计", "crosstabs": "交叉表分析",
    "ttest": "t 检验", "anova": "方差分析", "correlation": "相关分析",
    "reliability": "信度分析", "factor_analysis": "因子分析",
    "regression": "回归分析", "mediation": "中介效应",
    "moderation": "调节效应", "cluster": "聚类分析",
    "power_bootstrap": "Bootstrap 与效力", "survey_specific": "问卷专用分析",
}


# ─── 数据页 ────────────────────────────────────────────
def render_data_page(state):
    st.subheader("📁 数据浏览")
    surveys = []
    if DB_DIR.exists():
        surveys = sorted([d.stem for d in DB_DIR.glob("*.db")])
    if not surveys:
        st.info("尚无数据库,请先在左侧上传数据。")
        return

    sid = st.selectbox("选择数据集", surveys, key="data_page_sid")
    db_path = DB_DIR / f"{sid}.db"

    try:
        con = sqlite3.connect(str(db_path))
        cur = con.cursor()
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    except Exception as e:
        st.error(f"无法读取数据库: {e}")
        return

    if not tables:
        st.warning("数据库无表"); return
    tbl = st.selectbox("数据表", tables, key="data_page_tbl")

    n_rows = cur.execute(f"SELECT COUNT(*) FROM {tbl}").fetchone()[0]
    cols = [r[1] for r in cur.execute(f"PRAGMA table_info({tbl})").fetchall()]
    st.caption(f"行数: **{n_rows}** · 列数: **{len(cols)}** · 表: `{tbl}`")

    # 分页
    page_size = st.slider("每页行数", 10, 200, 50, step=10, key="data_page_size")
    page = st.number_input("页", min_value=1, max_value=max(1, (n_rows + page_size - 1) // page_size),
                           value=1, step=1, key="data_page_n")
    offset = (page - 1) * page_size

    # 筛选列
    selected_cols = st.multiselect("显示列 (留空 = 全部)", cols, default=cols[:10] if len(cols) > 10 else cols)
    cols_sql = ", ".join([f'"{c}"' for c in (selected_cols or cols)])
    rows = cur.execute(f"SELECT {cols_sql} FROM {tbl} LIMIT {page_size} OFFSET {offset}").fetchall()
    con.close()

    import pandas as pd
    df = pd.DataFrame(rows, columns=(selected_cols or cols))
    st.dataframe(df, use_container_width=True, height=400)
    csv = df.to_csv(index=False).encode("utf-8")
    st.download_button("⬇️ 下载 CSV (当前页)", csv, f"{tbl}_page{page}.csv", "text/csv")


# ─── 分析模块页 ──────────────────────────────────────────
def render_analyses_page(state, api_messages):
    st.subheader("📊 分析模块")
    st.caption("点击模块卡片可一键触发分析;或在对话框中描述需求由 Agent 自动编排。")

    # 模块状态(结果文件是否存在)
    cols = st.columns(4)
    for i, (mod, title) in enumerate(MODULE_TITLES.items()):
        c = cols[i % 4]
        rds = OUTPUT / "results" / f"{mod}_s1.rds"
        status = "✅" if rds.exists() else "⚪"
        with c.container(border=True):
            st.markdown(f"**{status} {title}**")
            st.caption(f"`{mod}`")
            if rds.exists():
                st.caption(f"输出: {rds.stat().st_size // 1024} KB")
            if st.button("▶️ 运行", key=f"run_{mod}", use_container_width=True):
                api_messages.append({"role": "user",
                                     "content": f"请运行 run_analysis_module('{mod}','survey1') 并 render_charts。"})
                st.rerun()


# ─── 图表画廊页 ─────────────────────────────────────────
def render_charts_page(state):
    st.subheader("🖼️ 图表画廊")
    charts_root = OUTPUT / "charts"
    if not charts_root.exists():
        st.info("尚无图表。请先运行分析 + render_charts。"); return

    chart_dirs = sorted([d for d in charts_root.iterdir() if d.is_dir()])
    if not chart_dirs:
        st.info("尚无图表。"); return

    selected_dir = st.selectbox("选择模块", [d.name for d in chart_dirs], key="gallery_dir")
    cdir = charts_root / selected_dir
    pngs = sorted(cdir.glob("*.png"))
    if not pngs:
        st.warning("该模块无图表"); return

    # 查看模式
    mode = st.radio("视图", ["缩略图网格", "单图大图", "幻灯片"], horizontal=True, key="gallery_mode")
    if mode == "缩略图网格":
        cols = st.columns(3)
        for i, p in enumerate(pngs):
            with cols[i % 3]:
                st.image(str(p), caption=p.stem, use_container_width=True)
                with open(p, "rb") as f:
                    st.download_button("⬇️ PNG", f.read(), p.name, "image/png", key=f"dl_{i}")
    elif mode == "单图大图":
        sel = st.selectbox("选择图", [p.name for p in pngs], key="single_chart")
        st.image(str(cdir / sel), use_container_width=True)
    else:
        idx = st.number_input("第几张", 1, len(pngs), 1, key="slide_idx")
        p = pngs[idx - 1]
        st.image(str(p), caption=f"{idx}/{len(pngs)} — {p.stem}", use_container_width=True)


# ─── 报告中心 ───────────────────────────────────────────
def render_reports_page(state, api_messages, ROOT):
    st.subheader("📄 报告中心")
    sub_html, sub_word, sub_pdf, sub_zip = st.tabs(["📊 HTML", "📝 Word", "📑 PDF", "🗂️ 图片包"])

    # ── HTML ────────────────────────
    with sub_html:
        report_path = state.report_path and Path(state.report_path)
        if not (report_path and report_path.exists()):
            report_path = ROOT / "04-report" / "report.html"
        if report_path.exists():
            col1, col2 = st.columns([1, 1])
            with col1:
                with open(report_path, "rb") as f:
                    st.download_button("⬇️ 下载 HTML", f, "report.html", "text/html",
                                       use_container_width=True)
            with col2:
                if st.button("🔄 重新生成", key="rerun_html", use_container_width=True):
                    api_messages.append({"role": "user", "content": "请运行 run_compile + run_report。"})
                    st.rerun()
            html = report_path.read_text(encoding="utf-8")
            components.html(html, height=800, scrolling=True)
        else:
            st.info("HTML 报告尚未生成。")
            if st.button("立即生成", key="gen_html"):
                api_messages.append({"role": "user", "content": "请运行 run_compile + run_report。"})
                st.rerun()

    # ── Word ────────────────────────
    with sub_word:
        st.caption("模板系统:简版只含基础统计;标准版含主要分析;详尽版含全部 13 个模块。")
        template = st.radio("模板", ["minimal", "standard", "full"], horizontal=True, key="word_tpl")
        org = st.text_input("机构名称", value="调查分析平台", key="word_org")
        title = st.text_input("报告标题", value="问卷调查分析报告", key="word_title")
        if st.button("📝 生成 Word", key="gen_word", use_container_width=True):
            api_messages.append({"role": "user",
                                 "content": f"请 generate_word(template='{template}', title='{title}', org_name='{org}')。"})
            st.rerun()
        # 现有 Word
        for docx in sorted((OUTPUT / "reports").glob("*.docx"), reverse=True):
            with st.container(border=True):
                st.markdown(f"📝 **{docx.name}** ({docx.stat().st_size // 1024} KB)")
                with open(docx, "rb") as f:
                    st.download_button("⬇️ 下载", f.read(), docx.name,
                                       "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                       key=f"dl_{docx.name}", use_container_width=True)

    # ── PDF ─────────────────────────
    with sub_pdf:
        template = st.radio("模板", ["minimal", "standard", "full"], horizontal=True, key="pdf_tpl")
        if st.button("📑 生成 PDF", key="gen_pdf", use_container_width=True):
            api_messages.append({"role": "user",
                                 "content": f"请 generate_pdf(template='{template}')。"})
            st.rerun()
        for pdf in sorted((OUTPUT / "reports").glob("*.pdf"), reverse=True):
            with st.container(border=True):
                st.markdown(f"📑 **{pdf.name}** ({pdf.stat().st_size // 1024} KB)")
                # PDF 嵌入预览 (base64 dataURI)
                import base64
                b64 = base64.b64encode(pdf.read_bytes()).decode()
                with st.expander("👁️ 预览"):
                    components.iframe(f"data:application/pdf;base64,{b64}", height=600)
                with open(pdf, "rb") as f:
                    st.download_button("⬇️ 下载", f.read(), pdf.name, "application/pdf",
                                       key=f"dl_{pdf.name}", use_container_width=True)

    # ── 图片包 ───────────────────────
    with sub_zip:
        if st.button("🗂️ 打包图表", key="gen_zip", use_container_width=True):
            api_messages.append({"role": "user", "content": "请 export_charts_bundle。"})
            st.rerun()
        for zp in sorted((OUTPUT / "reports").glob("images_*.zip"), reverse=True):
            with st.container(border=True):
                st.markdown(f"🗂️ **{zp.name}** ({zp.stat().st_size // 1024} KB)")
                with open(zp, "rb") as f:
                    st.download_button("⬇️ 下载 ZIP", f.read(), zp.name, "application/zip",
                                       key=f"dl_{zp.name}", use_container_width=True)
