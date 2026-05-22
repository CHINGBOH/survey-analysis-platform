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
                        if arts:
                            st.json(arts, expanded=False)


def render_tool_event_live(evt: dict, container):
    """Write a single event to a live container during agent execution."""
    if evt["type"] == "tool_call":
        container.markdown(f"🔧 **{evt['name']}** `{json.dumps(evt.get('inputs', {}), ensure_ascii=False)[:120]}`")
    elif evt["type"] == "tool_result":
        result = evt["result"]
        icon = "✅" if result.get("status") == "ok" else "❌"
        container.markdown(f"{icon} {result.get('summary', '')}")
