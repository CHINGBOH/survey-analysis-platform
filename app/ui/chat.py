"""
app/ui/chat.py — Chat message display helpers.
"""
import json

import streamlit as st


def render_message_history(display_messages: list):
    """Replay all stored display messages in the chat."""
    for msg in display_messages:
        role = msg["role"]
        with st.chat_message(role):
            if role == "user":
                st.write(msg["content"])
            else:
                _render_assistant_msg(msg)


def _render_assistant_msg(msg: dict):
    """Render an assistant message with optional tool call details."""
    if msg.get("content"):
        st.write(msg["content"])
    if msg.get("events"):
        tool_events = [e for e in msg["events"] if e["type"] in ("tool_call", "tool_result")]
        if tool_events:
            with st.expander(f"🔧 {len(tool_events)//2} 次工具调用", expanded=False):
                for evt in tool_events:
                    if evt["type"] == "tool_call":
                        st.markdown(f"**→ {evt['name']}**")
                        if evt.get("inputs"):
                            st.json(evt["inputs"], expanded=False)
                    elif evt["type"] == "tool_result":
                        result = evt["result"]
                        icon = "✅" if result.get("status") == "ok" else "❌"
                        st.markdown(f"{icon} {result.get('summary', '')}")
                        arts = result.get("artifacts", {})
                        # render_charts 工具:把 charts manifest 直接展示图片
                        if isinstance(arts, dict) and arts.get("charts"):
                            _render_chart_gallery(arts["charts"])
                        # interpret_results 工具:展示结构化解读
                        if isinstance(arts, dict) and arts.get("interpretation"):
                            _render_interpretation(arts["interpretation"])
                        if arts:
                            st.json(arts, expanded=False)


def _render_chart_gallery(charts: list):
    """把 charts manifest 展示为 2 列网格。"""
    import os
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent.parent
    valid = [c for c in charts if (root / c.get("file", "")).exists()]
    if not valid:
        return
    cols_per_row = 2
    for i in range(0, len(valid), cols_per_row):
        cols = st.columns(cols_per_row)
        for j, c in enumerate(valid[i:i + cols_per_row]):
            with cols[j]:
                st.image(str(root / c["file"]), caption=c.get("title", c.get("name", "")),
                         use_container_width=True)


def _render_interpretation(interp: dict):
    """把 ModuleInterpretation 渲染为人类可读卡片。"""
    st.markdown(f"**📊 {interp.get('module', '')} @ {interp.get('survey_id', '')}**"
                + (f" — N={interp['n_total']}" if interp.get('n_total') else ""))
    findings = interp.get("key_findings", [])
    if findings:
        st.markdown("**关键发现:**")
        for f in findings:
            sig = "🟢" if f.get("significant") else ("⚪" if f.get("significant") is False else "·")
            st.markdown(f"- {sig} `{f['variable']}` **{f['statistic_name']}** = `{f['value']}` — {f['interpretation']}")
    if interp.get("caveats"):
        with st.expander("⚠️ 数据局限与方法警示"):
            for c in interp["caveats"]:
                st.markdown(f"- {c}")
    if interp.get("next_suggestions"):
        with st.expander("💡 后续建议"):
            for s in interp["next_suggestions"]:
                st.markdown(f"- {s}")


def render_tool_event_live(evt: dict, container):
    """Write a single event to a live container during agent execution."""
    if evt["type"] == "tool_call":
        container.markdown(f"🔧 **{evt['name']}** `{json.dumps(evt.get('inputs', {}), ensure_ascii=False)[:120]}`")
    elif evt["type"] == "tool_result":
        result = evt["result"]
        icon = "✅" if result.get("status") == "ok" else "❌"
        container.markdown(f"{icon} {result.get('summary', '')}")
