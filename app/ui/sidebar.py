"""
app/ui/sidebar.py — Upload panel + pipeline status indicators.
"""
from pathlib import Path

import streamlit as st

from app.state import (
    ALL_MODULES,
    MODULE_LABELS_CN,
    MODULE_GROUPS,
    PipelineStage,
)

ROOT = Path(__file__).resolve().parent.parent.parent


def render_sidebar(state, api_messages: list):
    """Render sidebar: file upload section + pipeline status grid."""
    st.sidebar.title("📊 Survey Analysis")

    # ── Data Source Section (explicit selection only, never auto-default) ──
    st.sidebar.subheader("数据文件")

    raw_dir = ROOT / "data" / "raw"
    existing = sorted(raw_dir.glob("*.xlsx")) + sorted(raw_dir.glob("*.csv"))

    # Current selection (only set after an explicit click/upload)
    if state.uploaded_path:
        st.sidebar.success(f"已选用: {Path(state.uploaded_path).name}")
        if st.sidebar.button("取消选择", use_container_width=True):
            state.uploaded_path = None
            state.uploaded_filename = None
            state.stage = PipelineStage.IDLE
            st.rerun()
    else:
        st.sidebar.caption("请选择数据文件后点击确认（不会自动使用）")

    # Existing files: pick + explicit confirm click
    if existing:
        choice = st.sidebar.selectbox(
            "现有数据文件",
            ["（未选择）"] + [p.name for p in existing],
            index=0,
        )
        if choice != "（未选择）":
            if st.sidebar.button(f"确认使用「{choice}」", use_container_width=True):
                sel = raw_dir / choice
                state.uploaded_path = str(sel)
                state.uploaded_filename = choice
                state.stage = PipelineStage.UPLOADED
                _inject_data_notice(api_messages, choice, state)
                st.rerun()

    # Upload a new file (writing the file alone does NOT select it — must confirm)
    uploaded = st.sidebar.file_uploader(
        "或上传新文件 (xlsx / csv)",
        type=["xlsx", "csv"],
        label_visibility="collapsed",
    )
    if uploaded is not None and uploaded.name != st.session_state.get("last_uploaded"):
        save_path = raw_dir / uploaded.name
        raw_dir.mkdir(parents=True, exist_ok=True)
        save_path.write_bytes(uploaded.read())
        state.uploaded_path = str(save_path)
        state.uploaded_filename = uploaded.name
        state.stage = PipelineStage.UPLOADED
        st.session_state["last_uploaded"] = uploaded.name
        _inject_data_notice(api_messages, uploaded.name, state)
        st.sidebar.success(f"已上传并选用: {uploaded.name}")
        st.rerun()

    # ── Pipeline Status ─────────────────────────────────────────────
    st.sidebar.divider()
    st.sidebar.subheader("管道状态")

    # Router phase (ground-truth, derived from filesystem each render)
    from app.router import route
    from app.tools import load_plan
    decision = route(state)
    phase_color = "green" if decision.phase.value == "done" else "blue"
    st.sidebar.markdown(f"**路由阶段:** :{phase_color}[{decision.phase.value}]")
    st.sidebar.caption(f"可用工具: {len(decision.allowed_tools)} 个")

    # Active analysis plan (the agent's confirmed understanding of intent)
    plan = state.plan or load_plan()
    if plan:
        with st.sidebar.container(border=True):
            st.markdown("**📋 当前分析计划**")
            sv = "、".join(plan.get("surveys", []))
            mode = "对比" if plan.get("compare") else "单组"
            st.caption(f"调查: {sv}（{mode}）")
            mods = plan.get("modules", [])
            mod_cn = "、".join(MODULE_LABELS_CN.get(m, m) or m for m in mods)
            st.caption(f"模块({len(mods)}): {mod_cn}")
            if plan.get("focus"):
                st.caption(f"聚焦: {plan['focus']}")

    # Clean status
    clean_icon = "✅" if state.clean_done else "⬜"
    st.sidebar.markdown(f"{clean_icon} 数据清洗入库")

    # Module grid — status synced from disk via check_pipeline_status (plan-aware).
    # Modules outside the active plan are dimmed.
    from app.tools import check_pipeline_status
    disk = check_pipeline_status(state).get("artifacts", {}).get("modules", {})
    planned = set(plan.get("modules", ALL_MODULES)) if plan else set(ALL_MODULES)

    st.sidebar.caption(f"分析模块 (共 {len(ALL_MODULES)} 个,SPSS 分类):")
    disk_icon = {"done": "✅", "partial": "🟡", "missing": "⬜"}
    for group_name, mods in MODULE_GROUPS:
        n_done = sum(1 for m in mods if disk.get(m) == "done")
        with st.sidebar.expander(f"{group_name}  ({n_done}/{len(mods)})",
                                 expanded=(n_done > 0 and n_done < len(mods))):
            for mod in mods:
                label = MODULE_LABELS_CN.get(mod, mod)
                if mod not in planned:
                    st.markdown(f"➖ :gray[{label}]", help="不在当前计划")
                else:
                    icon = disk_icon.get(disk.get(mod, "missing"), "⬜")
                    st.markdown(f"{icon} {label}  <small>`{mod}`</small>",
                                unsafe_allow_html=True, help=mod)

    # Report link
    if state.report_path and Path(state.report_path).exists():
        st.sidebar.divider()
        st.sidebar.success("报告已就绪")
        rel = Path(state.report_path).relative_to(ROOT)
        st.sidebar.caption(f"路径: {rel}")

    # ── 能力一览 (永久显示) ──
    st.sidebar.divider()
    with st.sidebar.expander("📚 平台能力总览", expanded=False):
        st.markdown("**📊 统计分析**")
        st.caption(f"- 13 模块 / 40+ SPSS 子过程")
        st.caption(f"- 描述/交叉/t/ANOVA/相关/回归")
        st.caption(f"- 中介/调节/信度/因子/聚类")
        st.caption(f"- Bootstrap/Likert/NPS/文本")
        st.markdown("**🖼️ 图表系统**")
        st.caption(f"- 基础 8 (条/饼/线/散点/箱/直方/QQ/密度)")
        st.caption(f"- 统计 10 (碎石/双标/森林/ROC/火山等)")
        st.caption(f"- 高级 10 (热力/雷达/桑基/词云等)")
        st.markdown("**📄 报告输出**")
        st.caption(f"- HTML / Word / PDF / 图片包 ZIP")
        st.caption(f"- 3 套模板: minimal/standard/full")


def _inject_data_notice(api_messages: list, filename: str, state):
    """Tell the agent that the user has explicitly selected a specific data file."""
    state.stage = PipelineStage.UPLOADED
    content = (
        f"[系统通知] 用户已显式选择数据文件: {filename}（路径 data/raw/{filename}）。"
        f"请 preview_data 预览该文件，然后询问用户的分析意图（哪个调查/哪些模块/核心问题），"
        f"意图清楚后用 set_analysis_plan 锁定计划。\n"
        f"⚠️ 调用 run_clean 时必须传 source_file='data/raw/{filename}'，"
        f"否则会读默认硬编码文件而不是用户刚选的这个。"
        f"target 取 survey1（消费券完整版）或 survey2（消费券精简版）—— 当前 cleaner 只支持"
        f"消费券问卷 schema，若用户上传的是其他主题问卷，请明确告知尚不支持并停止。"
    )
    # Only inject once per file
    already = any(
        isinstance(m.get("content"), str)
        and "[系统通知]" in m["content"]
        and filename in m["content"]
        for m in api_messages
        if m.get("role") == "user"
    )
    if not already:
        api_messages.append({"role": "user", "content": content})
