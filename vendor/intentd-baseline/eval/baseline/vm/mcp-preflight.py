from __future__ import annotations

import asyncio
import json
import sys
from time import perf_counter
from typing import Any, TypedDict

from fastmcp import Client

TIMEOUT_SECONDS = 300
MCP_CONFIG: dict[str, Any] = {
    "mcpServers": {
        "nix-agent": {
            "command": "/run/wrappers/bin/nix-agent-mcp",
            "args": [],
        }
    }
}


class ToolSummary(TypedDict):
    name: str
    status: str
    elapsed_seconds: float


class PreflightSummary(TypedDict):
    success: bool
    tools: list[ToolSummary]
    elapsed_seconds: float


class PreflightFailure(RuntimeError):
    pass


async def call_checked(client: Client[Any], tool_name: str, attr: str) -> ToolSummary:
    started = perf_counter()
    result = await client.call_tool(
        tool_name,
        {"attr": attr},
        timeout=TIMEOUT_SECONDS,
        raise_on_error=False,
    )
    elapsed_seconds = round(perf_counter() - started, 3)
    if result.is_error:
        raise PreflightFailure(f"{tool_name}: MCP tool returned an error")

    structured = result.structured_content
    if structured is None:
        raise PreflightFailure(f"{tool_name}: missing structured result")
    status = structured.get("status")
    if status != "ok":
        reported_status = status if isinstance(status, str) else "missing"
        raise PreflightFailure(f"{tool_name}: status {reported_status}")

    return {
        "name": tool_name,
        "status": "ok",
        "elapsed_seconds": elapsed_seconds,
    }


async def run_preflight() -> PreflightSummary:
    started = perf_counter()
    async with Client(
        MCP_CONFIG,
        timeout=TIMEOUT_SECONDS,
        init_timeout=TIMEOUT_SECONDS,
    ) as client:
        tools = [
            await call_checked(client, "locate_option", "environment.systemPackages"),
            await call_checked(client, "eval_config", "networking.hostName"),
        ]

    return {
        "success": True,
        "tools": tools,
        "elapsed_seconds": round(perf_counter() - started, 3),
    }


def main() -> int:
    try:
        summary = asyncio.run(run_preflight())
    except Exception as exc:
        message = " ".join(str(exc).splitlines()).strip() or type(exc).__name__
        print(f"baseline-mcp-preflight: {message}", file=sys.stderr)
        return 1

    print(json.dumps(summary, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
