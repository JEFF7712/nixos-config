import json
import subprocess
from collections.abc import Callable
from typing import Any, Literal, cast

import pydantic

from intentd.registry import REGISTRY, CapabilityInvocation, InvocationError, resolve_invocation
from intentd.schema import CatalogApp, ClosedModel


class ResolverError(Exception):
    pass


CAPABILITY_PARAM_HINTS: dict[str, str] = {
    "app.install": '{"app": "<catalog id>"}',
    "app.remove": '{"app": "<catalog id>"}',
    "change.revert": "{}",
    "hardware.graphics.profile": '{"profile": "integrated"|"hybrid-nvidia"}',
}


class Resolution(ClosedModel):
    action: Literal["invoke", "abstain"]
    invocation: CapabilityInvocation | None = None
    reason: str
    # True only when run_model itself raised (subprocess/CLI failure). Never
    # set from model-controlled content (e.g. an abstain reason string) -
    # that content is untrusted and must not be able to spoof this flag.
    infrastructure: bool = False


class _ReplyPayload(ClosedModel):
    action: Literal["invoke", "abstain"]
    capability: str | None
    params: dict[str, Any] | None
    reason: str


REPLY_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "required": ["action", "capability", "params", "reason"],
    "properties": {
        "action": {"type": "string", "enum": ["invoke", "abstain"]},
        "capability": {"type": ["string", "null"]},
        "params": {"type": ["object", "null"]},
        "reason": {"type": "string"},
    },
}


def _capability_lines() -> list[str]:
    lines: list[str] = []
    for cap in sorted(REGISTRY.values(), key=lambda c: c.id):
        lines.append(f"- {cap.id} ({cap.title}): params {CAPABILITY_PARAM_HINTS[cap.id]}")
    return lines


def _catalog_lines(catalog: dict[str, CatalogApp]) -> list[str]:
    lines: list[str] = []
    for app in sorted(catalog.values(), key=lambda a: a.id):
        unfree = "unfree" if app.unfree else "free"
        lines.append(f"- {app.id}: {app.name} ({unfree}) - {app.summary}")
    return lines


def build_prompt(catalog: dict[str, CatalogApp]) -> str:
    capability_block = "\n".join(_capability_lines())
    catalog_block = "\n".join(_catalog_lines(catalog))
    return (
        "You resolve a single natural-language utterance into exactly one of the "
        "following four capabilities, or an abstention.\n\n"
        "Capabilities:\n"
        f"{capability_block}\n\n"
        "Catalog (id: name (free/unfree) - summary). Only apps listed here may be "
        "referenced by id in params.app:\n"
        f"{catalog_block}\n\n"
        "Abstain (action=abstain) when: the request is out of scope for the four "
        "capabilities above; the request is ambiguous; the request names multiple "
        "apps; or the request names an app that is not in the catalog above. If an "
        "app has an unfree license, you may still resolve to invoke, but mention "
        "the license need in reason text; the license gate itself is enforced "
        "elsewhere.\n\n"
        "Reply with exactly one JSON object and no prose, no markdown fences, and "
        "no explanation outside the object. The object must have exactly these "
        "fields: "
        '{"action": "invoke"|"abstain", "capability": <capability id>|null, '
        '"params": <object matching the capability>|null, "reason": "<short reason>"}. '
        "For change.revert, params is {}. For app.install and app.remove, params is "
        '{"app": "<catalog id>"}. For hardware.graphics.profile, params is '
        '{"profile": "integrated"|"hybrid-nvidia"}.'
    )


def _abstain(reason: str, *, infrastructure: bool = False) -> Resolution:
    return Resolution(
        action="abstain", invocation=None, reason=reason, infrastructure=infrastructure
    )


def resolve_utterance(
    utterance: str,
    catalog: dict[str, CatalogApp],
    run_model: Callable[[str], str],
) -> Resolution:
    prompt = build_prompt(catalog) + f"\n\nUser utterance: {utterance!r}\n"
    try:
        raw_reply = run_model(prompt)
    except Exception as exc:  # noqa: BLE001 - any model-call failure must abstain
        return _abstain(f"model call failed: {exc}", infrastructure=True)

    try:
        parsed = json.loads(raw_reply)
    except (json.JSONDecodeError, TypeError) as exc:
        return _abstain(f"invalid JSON reply: {exc}")

    try:
        payload = _ReplyPayload.model_validate(parsed)
    except pydantic.ValidationError as exc:
        return _abstain(f"reply schema violation: {exc}")

    if payload.action == "abstain":
        return _abstain(payload.reason)

    if payload.capability is None:
        return _abstain("invoke action missing a capability")

    raw_params = payload.params if payload.params is not None else {}
    try:
        invocation = resolve_invocation(catalog, payload.capability, raw_params)
    except (InvocationError, ValueError) as exc:
        return _abstain(f"invocation rejected: {exc}")

    return Resolution(action="invoke", invocation=invocation, reason=payload.reason)


def claude_argv(prompt: str) -> list[str]:
    return [
        "claude",
        "-p",
        prompt,
        "--output-format",
        "json",
        "--json-schema",
        json.dumps(REPLY_SCHEMA, sort_keys=True),
        "--model",
        "sonnet",
        # Tools are disabled with the documented kill switch (--tools "":
        # "Specify the list of available tools from the built-in set. Use ""
        # to disable all tools", per `claude --help` on the installed CLI).
        # --allowedTools "" is kept too: it costs nothing and additionally
        # ensures nothing is pre-approved if --tools is ever dropped.
        "--allowedTools",
        "",
        "--tools",
        "",
    ]


def parse_claude_output(raw: str) -> str:
    try:
        parsed: Any = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ResolverError(f"claude -p output is not valid JSON: {exc}") from exc

    if not isinstance(parsed, dict):
        raise ResolverError("claude -p output is not a JSON object")
    wrapper = cast(dict[str, Any], parsed)

    if wrapper.get("is_error"):
        result_snippet = str(wrapper.get("result", ""))[:600]
        raise ResolverError(
            f"claude -p output is error-shaped (is_error=true) even though it "
            f"exited 0: {result_snippet!r}"
        )

    structured_output = wrapper.get("structured_output")
    if structured_output is None:
        raise ResolverError("claude -p output is missing a structured_output field")

    return json.dumps(structured_output)


def run_claude(prompt: str) -> str:
    argv = claude_argv(prompt)
    try:
        result = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
        )
    except OSError as exc:
        raise ResolverError(f"claude could not be executed: {exc}") from exc
    except subprocess.TimeoutExpired as exc:
        raise ResolverError(f"claude timed out: {exc}") from exc

    if result.returncode != 0:
        # In --output-format json mode error details land on stdout, so both
        # streams must appear in the message for the failure to be diagnosable.
        stdout_snippet = result.stdout.strip()[:600]
        stderr_snippet = result.stderr.strip()[:600]
        raise ResolverError(
            f"claude exited with {result.returncode}: "
            f"stdout: {stdout_snippet!r} stderr: {stderr_snippet!r}"
        )

    return parse_claude_output(result.stdout)
