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
from contextlib import contextmanager, nullcontext
from typing import Any, Optional


def _init_langfuse():
    """初始化 Langfuse client。失败返回 None。

    本机存在 ALL_PROXY=socks://...,langfuse 4.x 内部的 httpx 不支持
    socks scheme,会抛 ValueError。这里短暂清除 socks 代理,httpx 仍可
    走 HTTPS_PROXY。
    """
    if not (os.environ.get("LANGFUSE_PUBLIC_KEY") and os.environ.get("LANGFUSE_SECRET_KEY")):
        return None
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
                host=os.environ.get("LANGFUSE_HOST", "https://cloud.langfuse.com"),
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


def start_turn(name: str, user_input: str, metadata: Optional[dict] = None) -> Any:
    """开启一个对话轮 root observation(隐式建 trace)。"""
    if not _LANGFUSE_ENABLED or _langfuse_client is None:
        return _NULL_SPAN
    try:
        span = _langfuse_client.start_observation(
            name=name,
            as_type="agent",
            input=user_input,
            metadata=metadata or {},
        )
        return span
    except Exception:
        return _NULL_SPAN


def end_turn(span: Any, output: Any = None, status: str = "ok") -> None:
    if span is _NULL_SPAN or span is None:
        return
    try:
        span.update(output=output)
        span.end()
        if _langfuse_client is not None:
            _langfuse_client.flush()
    except Exception:
        pass


@contextmanager
def record_tool_call(parent: Any, tool_name: str, inputs: dict):
    if parent is _NULL_SPAN or parent is None or not _LANGFUSE_ENABLED:
        with nullcontext(_NULL_SPAN) as s:
            yield s
        return
    child: Any = _NULL_SPAN
    try:
        child = parent.start_observation(name=f"tool:{tool_name}", as_type="tool", input=inputs)
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
