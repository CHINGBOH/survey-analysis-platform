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

# SPSS-style 分类菜单 → (模块名, 子过程描述, 适用变量类型)
SPSS_CATEGORIES = [
    ("📈 描述统计", [
        ("descriptives", "频率分布 · 描述统计 · 探索 · 正态性 (Shapiro/K-S)", "数值/分类"),
        ("crosstabs",    "交叉表 · χ² · Cramer's V · Phi · Gamma · Fisher", "分类×分类"),
    ]),
    ("📊 比较均值与方差", [
        ("ttest", "单样本 t · 独立样本 t · 配对 t · Mann-Whitney · Wilcoxon", "数值×分组"),
        ("anova", "单因素 ANOVA · MANOVA · η²/ω² · Tukey HSD · Games-Howell · Kruskal-Wallis", "数值×多组"),
    ]),
    ("🔗 相关与回归", [
        ("correlation", "Pearson · Spearman · Kendall · 偏相关 · 距离矩阵", "数值对"),
        ("regression",  "线性 · 逐步 · 层次 · 二元 Logistic · 多分类 Logistic · Poisson", "数值/二分类 ~ 多变量"),
        ("mediation",   "中介效应 · Sobel · Bootstrap · lavaan 路径模型", "X→M→Y"),
        ("moderation",  "调节效应 · 交互项 · Johnson-Neyman · 简单斜率", "X×W→Y"),
    ]),
    ("🧮 信度与降维", [
        ("reliability",     "Cronbach α · 分半信度 · McDonald ω · 项目-总分 · α-if-deleted", "量表"),
        ("factor_analysis", "PCA · EFA · KMO · Bartlett · 碎石图 · 因子旋转 (Varimax/Promax)", "量表/多项"),
    ]),
    ("🗂️ 分类与聚类", [
        ("cluster", "K-Means · 层次聚类 (Ward/Complete/Average) · 判别分析 (LDA) · 树状图", "多变量"),
    ]),
    ("⚙️ 高级与抽样", [
        ("power_bootstrap", "统计功效 · 样本量推算 · Bootstrap CI · 重抽样验证", "任意"),
    ]),
    ("📝 问卷专用", [
        ("survey_specific", "Likert · Top2Box · NPS · 缺失模式 · 多重插补 · 异常值 (Z/IQR/Mahalanobis) · 加权 · 文本/词频/情感", "问卷量表"),
    ]),
]

# 图表索引 → (模块, 图名, 中文描述)
CHART_CATALOG = [
    ("基础图表 (8)", [
        ("chart_bar",       "条形图",     "频数/均值对比"),
        ("chart_pie",       "饼图",       "构成比"),
        ("chart_line",      "折线图",     "趋势对比"),
        ("chart_scatter",   "散点图",     "相关关系 (含拟合)"),
        ("chart_box",       "箱线图",     "分布与离群"),
        ("chart_hist",      "直方图",     "数值分布"),
        ("chart_qq",        "Q-Q 图",     "正态性诊断"),
        ("chart_density",   "密度图",     "概率密度估计"),
    ]),
    ("统计专用 (10)", [
        ("chart_scree",        "碎石图",       "因子/主成分选取"),
        ("chart_biplot",       "双标图",       "PCA 载荷+得分"),
        ("chart_forest",       "森林图",       "效应量 95% CI"),
        ("chart_roc",          "ROC 曲线",     "二分类诊断 AUC"),
        ("chart_volcano",      "火山图",       "效应×显著性"),
        ("chart_mosaic",       "马赛克图",     "交叉表可视化"),
        ("chart_km",           "Kaplan-Meier", "生存曲线"),
        ("chart_diagnostics4", "回归诊断 4 图", "残差/QQ/杠杆/标准化"),
        ("chart_dendrogram",   "树状图",       "层次聚类结构"),
        ("chart_effect_size",  "效应量条形",   "Cohen's d 等"),
    ]),
    ("高级可视化 (10)", [
        ("chart_heatmap",   "热力图",     "矩阵/相关阵"),
        ("chart_radar",     "雷达图",     "多维对比"),
        ("chart_sankey",    "桑基图",     "流向追踪"),
        ("chart_sunburst",  "旭日图",     "层级构成"),
        ("chart_funnel",    "漏斗图",     "转化率"),
        ("chart_waterfall", "瀑布图",     "增量分解"),
        ("chart_wordcloud", "词云",       "文本关键词"),
        ("chart_network",   "网络图",     "关系/共现"),
        ("chart_parallel",  "平行坐标",   "多维数据线"),
        ("chart_china_map", "中国地图",   "省级填色"),
    ]),
]


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


# ─── 分析模块页 (SPSS 风格分类菜单) ──────────────────────
def render_analyses_page(state, api_messages):
    st.subheader("📊 统计分析 — SPSS 等价模块清单")
    st.caption(
        "13 个分析模块按 SPSS 菜单结构分类,每个模块封装多个子过程 "
        "(共 **40+ 种统计方法**)。点击 ▶️ 一键运行,或在 💬 聊天 tab 用自然语言描述需求。"
    )

    # 顶部统计条
    ready = sum(1 for m in MODULE_TITLES if (OUTPUT / "results" / f"{m}_s1.rds").exists())
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("总模块数", len(MODULE_TITLES))
    c2.metric("已完成", ready)
    c3.metric("子过程", "40+")
    c4.metric("图表类型", "28")
    st.divider()

    # SPSS 分类菜单
    for cat_name, items in SPSS_CATEGORIES:
        st.markdown(f"### {cat_name}")
        cols = st.columns(min(2, len(items)) if len(items) > 1 else 1)
        for i, (mod, desc, var_type) in enumerate(items):
            title = MODULE_TITLES.get(mod, mod)
            rds = OUTPUT / "results" / f"{mod}_s1.rds"
            ready_flag = "✅ 已完成" if rds.exists() else "⚪ 待运行"
            with cols[i % len(cols)].container(border=True):
                st.markdown(f"**{title}** &nbsp; <small>`{mod}`</small>", unsafe_allow_html=True)
                st.caption(f"📋 子过程: {desc}")
                st.caption(f"📐 变量类型: {var_type} · {ready_flag}")
                if rds.exists():
                    st.caption(f"📦 输出: {rds.stat().st_size // 1024} KB")
                b1, b2 = st.columns(2)
                if b1.button("▶️ 运行", key=f"run_{mod}", use_container_width=True):
                    api_messages.append({
                        "role": "user",
                        "content": f"请运行 run_analysis_module('{mod}','survey1') 并 render_charts('{mod}')。"
                    })
                    st.rerun()
                if b2.button("📖 查看结果", key=f"view_{mod}", use_container_width=True,
                             disabled=not rds.exists()):
                    api_messages.append({
                        "role": "user",
                        "content": f"请 get_results('{mod}','survey1') 并 interpret_results 给出解读。"
                    })
                    st.rerun()
        st.write("")


# ─── 图表画廊页 ─────────────────────────────────────────
def render_charts_page(state):
    st.subheader("🖼️ 图表系统")
    sub_gallery, sub_catalog = st.tabs(["📁 已生成图表", "📚 图表类型目录 (28 种)"])

    with sub_gallery:
        _render_chart_gallery()

    with sub_catalog:
        _render_chart_catalog()


def _render_chart_catalog():
    """展示所有可用图表类型 (28 种,按基础/统计/高级分类)。"""
    st.caption("本平台共支持 **28 种图表**,覆盖 SPSS / 学术论文 / 商业可视化常见需求。")
    for cat_name, items in CHART_CATALOG:
        st.markdown(f"### {cat_name}")
        cols = st.columns(2)
        for i, (func, name, desc) in enumerate(items):
            with cols[i % 2].container(border=True):
                st.markdown(f"**{name}** &nbsp; <small>`{func}`</small>", unsafe_allow_html=True)
                st.caption(f"💡 {desc}")
        st.write("")


def _render_chart_gallery():
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
    mode = st.radio("视图", ["缩略图网格", "单图大图", "幻灯片", "交互预览"], horizontal=True, key="gallery_mode")
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
    elif mode == "幻灯片":
        idx = st.number_input("第几张", 1, len(pngs), 1, key="slide_idx")
        p = pngs[idx - 1]
        st.image(str(p), caption=f"{idx}/{len(pngs)} — {p.stem}", use_container_width=True)
    else:
        _render_interactive(selected_dir)


def _render_interactive(module: str):
    """从 RDS-derived JSON 构造 plotly 交互图。"""
    import pandas as pd
    import plotly.express as px
    json_path = OUTPUT / "results" / f"{module}_s1.json"
    if not json_path.exists():
        # 尝试现场转换
        rds = OUTPUT / "results" / f"{module}_s1.rds"
        if rds.exists():
            if st.button("⚙️ 生成交互数据 (RDS→JSON)", key=f"conv_{module}"):
                import subprocess
                subprocess.run(["Rscript", str(ROOT / "02-analyze" / "rds_to_json.R"),
                                str(rds), "500"], cwd=str(ROOT))
                st.rerun()
        st.info("尚无交互数据。请先点击上方按钮生成,或运行 export_results_to_json。")
        return

    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
    except Exception as e:
        st.error(f"读取 JSON 失败: {e}"); return

    # 自动找出可绘制 data.frame (list of dicts)
    candidates = []
    def _walk(obj, prefix=""):
        if isinstance(obj, list) and obj and all(isinstance(x, dict) for x in obj):
            candidates.append((prefix or "root", obj))
        elif isinstance(obj, dict):
            for k, v in obj.items():
                _walk(v, f"{prefix}/{k}" if prefix else k)
        elif isinstance(obj, list):
            for i, v in enumerate(obj):
                _walk(v, f"{prefix}[{i}]")
    _walk(data)

    if not candidates:
        st.warning("此模块无表格型数据可作图。"); 
        with st.expander("查看原始 JSON"):
            st.json(data)
        return

    names = [c[0] for c in candidates]
    sel = st.selectbox("数据表", names, key=f"int_tbl_{module}")
    rows = dict(candidates)[sel]
    df = pd.DataFrame(rows)
    if df.empty:
        st.warning("空表"); return

    st.dataframe(df, use_container_width=True, height=200)

    cols = list(df.columns)
    num_cols = [c for c in cols if pd.api.types.is_numeric_dtype(df[c])]
    chart_type = st.selectbox("图类型", ["bar", "line", "scatter", "box", "histogram", "pie"],
                              key=f"int_ct_{module}")
    c1, c2, c3 = st.columns(3)
    x = c1.selectbox("X", cols, key=f"int_x_{module}")
    y = c2.selectbox("Y", num_cols or cols, key=f"int_y_{module}") if chart_type != "histogram" else None
    color = c3.selectbox("分组色", ["(无)"] + cols, key=f"int_c_{module}")
    color_arg = None if color == "(无)" else color

    try:
        if chart_type == "bar":
            fig = px.bar(df, x=x, y=y, color=color_arg)
        elif chart_type == "line":
            fig = px.line(df, x=x, y=y, color=color_arg, markers=True)
        elif chart_type == "scatter":
            fig = px.scatter(df, x=x, y=y, color=color_arg)
        elif chart_type == "box":
            fig = px.box(df, x=x, y=y, color=color_arg)
        elif chart_type == "histogram":
            fig = px.histogram(df, x=x, color=color_arg)
        else:
            fig = px.pie(df, names=x, values=y)
        fig.update_layout(template="plotly_white", height=500)
        st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.error(f"绘图失败: {e}")


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
