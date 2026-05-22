"""
app/main.py — Streamlit entry point for Survey Analysis Platform.
Run: streamlit run app/main.py --server.port 8501
"""
import os
import sys
from pathlib import Path

import streamlit as st
import streamlit.components.v1 as components

# Ensure project root is on sys.path when run from any directory
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.agent import run_agent_turn
from app.state import AppState, PipelineStage
from app.ui.chat import render_message_history, render_tool_event_live
from app.ui.sidebar import render_sidebar

st.set_page_config(
    page_title="Survey Analysis Platform",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Session state initialisation ──────────────────────────────────

def _init_state():
    if "app_state" not in st.session_state:
        st.session_state.app_state = AppState()
    if "api_messages" not in st.session_state:
        st.session_state.api_messages = []
    if "display_messages" not in st.session_state:
        st.session_state.display_messages = []
    if "api_key_ok" not in st.session_state:
        st.session_state.api_key_ok = bool(os.environ.get("DEEPSEEK_API_KEY"))


_init_state()
state: AppState = st.session_state.app_state
api_messages: list = st.session_state.api_messages
display_messages: list = st.session_state.display_messages

# ── Sidebar ───────────────────────────────────────────────────────
render_sidebar(state, api_messages)

# ── API key check ─────────────────────────────────────────────────
if not st.session_state.api_key_ok:
    st.error(
        "未检测到 DEEPSEEK_API_KEY 环境变量。\n\n"
        "请设置后重启应用：`export DEEPSEEK_API_KEY=sk-...`"
    )
    st.stop()

# ── Main area ─────────────────────────────────────────────────────
tab_chat, tab_report = st.tabs(["💬 分析助手", "📄 查看报告"])

with tab_chat:
    # Welcome message (shown once, not stored in API messages)
    if not display_messages:
        st.info(
            "**欢迎使用 Survey Analysis Platform**\n\n"
            "- 在左侧上传 Excel/CSV 文件，或选择现有数据\n"
            "- 告诉我您需要哪些统计分析\n"
            "- 我会运行完整的分析管道并生成报告"
        )

    # Replay message history
    render_message_history(display_messages)

    # Chat input
    user_input = st.chat_input("输入分析需求，或询问任何问题…")

    if user_input:
        # Display user message immediately
        display_messages.append({"role": "user", "content": user_input})
        with st.chat_message("user"):
            st.write(user_input)

        # Add to API messages
        api_messages.append({"role": "user", "content": user_input})

        # Run agent
        events_collected = []
        final_text = ""

        with st.chat_message("assistant"):
            status_container = st.status("思考中…", expanded=True)
            text_placeholder = st.empty()

            try:
                for evt in run_agent_turn(api_messages, state):
                    events_collected.append(evt)
                    if evt["type"] == "text":
                        final_text = evt["content"]
                        text_placeholder.markdown(final_text)
                    elif evt["type"] == "phase":
                        status_container.markdown(f"📍 路由阶段: **{evt['phase']}**")
                    elif evt["type"] in ("tool_call", "tool_result"):
                        render_tool_event_live(evt, status_container)

                status_container.update(label="完成", state="complete", expanded=False)

            except Exception as e:
                status_container.update(label=f"错误: {e}", state="error")
                final_text = f"抱歉，处理时出现错误：{e}"
                text_placeholder.error(final_text)

        # Save to display history
        display_messages.append(
            {
                "role": "assistant",
                "content": final_text,
                "events": events_collected,
            }
        )
        # Rerun to refresh sidebar status
        st.rerun()

# ── Report tab ────────────────────────────────────────────────────
with tab_report:
    report_path = state.report_path and Path(state.report_path)
    if report_path and report_path.exists():
        st.success(f"报告路径: `{report_path.relative_to(ROOT)}`")

        col1, col2 = st.columns([1, 1])
        with col1:
            with open(report_path, "rb") as f:
                st.download_button(
                    "⬇️ 下载 HTML 报告",
                    data=f,
                    file_name="survey_analysis_report.html",
                    mime="text/html",
                    use_container_width=True,
                )
        with col2:
            if st.button("🔄 重新生成报告", use_container_width=True):
                api_messages.append(
                    {"role": "user", "content": "请重新运行 run_compile 和 run_report。"}
                )
                st.rerun()

        # Embedded iframe preview
        st.subheader("报告预览")
        html_content = report_path.read_text(encoding="utf-8")
        components.html(html_content, height=900, scrolling=True)
    else:
        st.info("报告尚未生成。完成分析后，报告将显示在这里。")
        if state.stage not in (PipelineStage.IDLE, PipelineStage.UPLOADED):
            if st.button("生成报告"):
                api_messages.append(
                    {"role": "user", "content": "请立即整合结果并生成报告。"}
                )
                st.rerun()
