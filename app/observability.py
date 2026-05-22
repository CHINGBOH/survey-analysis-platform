"""
app/observability.py — Langfuse 可观测性集成(零侵入,langfuse 4.x API)。

设计原则:
- 未配置 LANGFUSE_* 环境变量时,**全部 API 退化为 no-op**,不影响主流程
- import 不抛错(langfuse 是 optional)
- 初始化失败(如代理冲突)静默降级
- 与现有 logs/events.jsonl 互补:本地永远写日志,Langfuse 额外提供 UI/聚合

环境变量:
    LANGFUSE_PUBLIC_KEY   公钥
    LANGFUSE_SECRET_KEY   私钥
    LANGFUSE_HOST         默认 https://cloud.langfuse.com,自部署填本地 URL

langfuse 4.x 基于 OpenTelemetry,API:
    span = langfuse.start_span(name="...")
    span.update(input=..., output=...)
    span.end()
"""
from __future__ import annotations

import os
from contextlib import ExitStack, contextmanager, nullcontext
from typing import Any, Optional


def _init_langfuse():
    """初始化 Langfuse client。失败返回 None。

    本机存在 ALL_PROXY=socks://...,langfuse 4.x 内部的 httpx 不支持
    socks scheme,会抛 ValueError。这里短暂清除 socks 代理,httpx 仍可
    走 HTTPS_PROXY。
    """
    if not (os.environ.get("LANGFUSE_PUBLIC_KEY") and os.environ.get("LANGFUSE_SECRET_KEY")):
        return None
    host = (
        os.environ.get("LANGFUSE_HOST")
        or os.environ.get("LANGFUSE_BASE_URL")
        or "https://cloud.langfuse.com"
    )
    try:
        saved = {}
        for k in ("ALL_PROXY", "all_proxy"):
            if k in os.environ:
                saved[k] = os.environ.pop(k)
        try:
            from langfuse import Langfuse  # type: ignore
            return Langfuse(
                public_key=os.environ["LANGFUSE_PUBLIC_KEY"],
                secret_key=os.environ["LANGFUSE_SECRET_KEY"],
                host=host,
            )
        finally:
            os.environ.update(saved)
    except Exception:
        return None


_langfuse_client = _init_langfuse()
_LANGFUSE_ENABLED = _langfuse_client is not None


def is_enabled() -> bool:
    return _LANGFUSE_ENABLED


def wrap_openai_client(client: Any) -> Any:
    """启用时返回 langfuse 装饰的 OpenAI client。"""
    if not _LANGFUSE_ENABLED:
        return client
    try:
        from langfuse.openai import OpenAI as LangfuseOpenAI  # type: ignore
        return LangfuseOpenAI(
            api_key=client.api_key,
            base_url=str(client.base_url),
            http_client=client._client,
        )
    except Exception:
        return client


class _NullSpan:
    """no-op span。"""

    def __getattr__(self, name: str):
        return lambda *args, **kwargs: self

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


_NULL_SPAN = _NullSpan()


class _TurnHandle:
    """Holds the root agent observation plus an ExitStack for trace attrs."""
    __slots__ = ("span", "stack")

    def __init__(self, span: Any, stack: ExitStack) -> None:
        self.span = span
        self.stack = stack


def start_turn(
    name: str,
    user_input: str,
    metadata: Optional[dict] = None,
    session_id: Optional[str] = None,
    user_id: Optional[str] = None,
    tags: Optional[list] = None,
) -> Any:
    """开启一个对话轮 root observation(隐式建 trace)。

    session_id 把同一对话的多轮 trace 串到 Langfuse Sessions 视图。
    user_id 用于按用户过滤/归集成本。
    tags 用于按功能/租户切片(如 ['survey-chat'])。

    返回 _TurnHandle(失败/未启用时返回 _NULL_SPAN)。
    """
    if not _LANGFUSE_ENABLED or _langfuse_client is None:
        return _NULL_SPAN
    stack = ExitStack()
    try:
        # propagate_attributes 必须包住 start_observation 才能让 trace 继承属性
        try:
            from langfuse import propagate_attributes  # type: ignore
            attrs: dict = {}
            if session_id:
                attrs["session_id"] = session_id
            if user_id:
                attrs["user_id"] = user_id
            if tags:
                attrs["tags"] = tags
            if attrs:
                stack.enter_context(propagate_attributes(**attrs))
        except Exception:
            pass
        # 用 start_as_current_observation 进入 OTel context,这样
        # langfuse.openai 自动把 LLM 调用挂到当前 trace 下,而不是新开 trace
        span = stack.enter_context(
            _langfuse_client.start_as_current_observation(
                name=name,
                as_type="agent",
                input=user_input,
                metadata=metadata or {},
            )
        )
        return _TurnHandle(span, stack)
    except Exception:
        try:
            stack.close()
        except Exception:
            pass
        return _NULL_SPAN


def _unwrap(handle: Any) -> Any:
    """Extract underlying span from _TurnHandle or pass through."""
    if isinstance(handle, _TurnHandle):
        return handle.span
    return handle


def end_turn(handle: Any, output: Any = None, status: str = "ok") -> None:
    if handle is _NULL_SPAN or handle is None:
        return
    span = _unwrap(handle)
    try:
        if status != "ok":
            try:
                span.update(output=output, level="ERROR", status_message=str(status))
            except Exception:
                span.update(output=output)
        else:
            span.update(output=output)
    except Exception:
        pass
    # 关闭 ExitStack 会触发 start_as_current_observation 的 __exit__,
    # 自动 .end() span 并恢复 OTel context
    if isinstance(handle, _TurnHandle):
        try:
            handle.stack.close()
        except Exception:
            pass
    else:
        try:
            span.end()
        except Exception:
            pass
    try:
        if _langfuse_client is not None:
            _langfuse_client.flush()
    except Exception:
        pass


@contextmanager
def record_tool_call(parent: Any, tool_name: str, inputs: dict):
    parent_span = _unwrap(parent)
    if parent_span is _NULL_SPAN or parent_span is None or not _LANGFUSE_ENABLED:
        with nullcontext(_NULL_SPAN) as s:
            yield s
        return
    child: Any = _NULL_SPAN
    try:
        child = parent_span.start_observation(name=f"tool:{tool_name}", as_type="tool", input=inputs)
    except Exception:
        child = _NULL_SPAN
    try:
        yield child
    finally:
        try:
            if child is not _NULL_SPAN and child is not None:
                child.end()
        except Exception:
            pass


def record_tool_result(span: Any, result: dict) -> None:
    if span is _NULL_SPAN or span is None:
        return
    try:
        span.update(
            output={
                "status": result.get("status"),
                "summary": result.get("summary", "")[:500],
            },
        )
    except Exception:
        pass
