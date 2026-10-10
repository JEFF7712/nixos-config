"""Side-by-side comparison of the two comparative-baseline arms.

Usage:
    uv run python -m eval.baseline.compare
    uv run python -m eval.baseline.compare --intentd path.json --baseline path.json

Reads eval/baseline/intentd_arm.json (produced by the scripted pilot, see
PROTOCOL.md section 4) and eval/baseline/baseline_arm.json (produced by a human
running RUNBOOK.md) and prints the six tasks metric by metric.

The one rule this module exists to enforce: it never declares a winner on a
metric where either arm is unscored. PROTOCOL.md leaves four measurements to
human judgment (wall_seconds on the baseline arm, clarification_turns and
terminal_exposure on the baseline arm, post_failure_trust on both), and a
comparison that silently treats a null as a zero would manufacture exactly the
claim the wedge closeout is careful not to make.

Two asymmetries are preserved rather than flattened, both per PROTOCOL.md:

- terminal exposure (section 5.4). The intentd arm reports a pair:
  terminal_exposure_zero_construction (always 0, the user never sees a raw
  shell command) and intent_invocations (how many `intent` calls the task took).
  The baseline arm reports one count of shell commands run or approved. Printing
  "0 vs 14" alone overstates the gap and printing "1 vs 14" alone understates
  it, so both intentd numbers are shown.
- wall_seconds (section 5.2). The intentd arm's are nixosTest driver deltas, the
  baseline arm's are a human stopwatch on different hardware. They are reported
  side by side and explicitly NOT totalled into a verdict.

Scoring functions here are pure and unit-tested in tests/test_baseline_compare.py.
"""

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

EXPECTED_TASK_IDS = [
    "install_named_free_app",
    "install_unfree_app_with_license",
    "remove_an_app",
    "install_by_description",
    "revert_last_change",
    "recover_from_mid_activation_failure",
]

RECOVERY_TASK_ID = "recover_from_mid_activation_failure"
ArmName = Literal["intentd", "baseline"]

CURSOR_TRANSPORT_CONSTANTS: dict[str, object] = {
    "official_cli_version": "2026.08.11-e8db854",
    "official_archive_sha256": "bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a",
    "official_bundle_sha256": "f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0",
    "task_facing_node_sha256": "e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4",
    "patched_bundle_sha256": "7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a",
    "mcp_timeout_ms": 300_000,
    "immutable_store_path": (
        "/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854"
    ),
    "auto_update_disabled": True,
}

CURSOR_TRANSPORT_RUN_VALUES: dict[str, str] = {
    "first_application_status": "patched",
    "idempotence_verification_status": "already_patched",
    "pre_chat_cli_version": "2026.08.11-e8db854",
    "post_chat_cli_version": "2026.08.11-e8db854",
}


class ArmLoadError(Exception):
    """An arm file is missing, malformed, or does not match the protocol's tasks."""


@dataclass(frozen=True)
class TaskRow:
    """One task's measurements for one arm. None means "not scored yet"."""

    task_id: str
    completion: bool | None
    wall_seconds: float | None
    clarification_turns: int | None
    recovery_success: bool | None
    # Baseline arm only: count of shell commands the user ran or approved.
    terminal_exposure: int | None
    # Intentd arm only: the (0-by-construction, invocation-count) pair.
    terminal_exposure_zero_construction: int | None
    intent_invocations: int | None


@dataclass(frozen=True)
class Arm:
    name: str
    tasks: list[TaskRow]
    post_failure_trust: int | None
    cursor_transport_verified: bool | None


def _validate_cursor_transport(clean: dict[str, Any], expected_name: ArmName) -> bool | None:
    if expected_name != "baseline":
        return None

    agent = clean.get("agent")
    if not isinstance(agent, dict) or agent.get("cli_version") != "2026.08.11-e8db854":
        got = agent.get("cli_version") if isinstance(agent, dict) else None
        raise ArmLoadError(
            f"baseline.agent.cli_version: expected '2026.08.11-e8db854', got {got!r}"
        )

    transport = clean.get("cursor_mcp_transport_compatibility")
    if not isinstance(transport, dict):
        raise ArmLoadError("baseline.cursor_mcp_transport_compatibility: expected an object")
    for field, expected in CURSOR_TRANSPORT_CONSTANTS.items():
        if transport.get(field) != expected:
            raise ArmLoadError(
                f"baseline.cursor_mcp_transport_compatibility.{field}: "
                f"expected {expected!r}, got {transport.get(field)!r}"
            )

    verified = True
    for field, expected in CURSOR_TRANSPORT_RUN_VALUES.items():
        value = transport.get(field)
        if value is None:
            verified = False
        elif value != expected:
            raise ArmLoadError(
                f"baseline.cursor_mcp_transport_compatibility.{field}: "
                f"expected {expected!r} or null, got {value!r}"
            )
    return verified


def _strip_doc_keys(obj: dict[str, Any]) -> dict[str, Any]:
    """Drop _-prefixed documentation keys.

    The template carries its own filling instructions inline (JSON has no
    comments), and those keys must not be mistaken for measurements.
    """
    return {k: v for k, v in obj.items() if not k.startswith("_")}


def _opt_int(raw: Any, field: str, task_id: str) -> int | None:
    if raw is None:
        return None
    if isinstance(raw, bool) or not isinstance(raw, int):
        raise ArmLoadError(f"{task_id}.{field}: expected an integer or null, got {raw!r}")
    return raw


def _opt_float(raw: Any, field: str, task_id: str) -> float | None:
    if raw is None:
        return None
    if isinstance(raw, bool) or not isinstance(raw, (int, float)):
        raise ArmLoadError(f"{task_id}.{field}: expected a number or null, got {raw!r}")
    return float(raw)


def _opt_bool(raw: Any, field: str, task_id: str) -> bool | None:
    if raw is None:
        return None
    if not isinstance(raw, bool):
        raise ArmLoadError(f"{task_id}.{field}: expected true/false or null, got {raw!r}")
    return raw


def parse_arm(data: dict[str, Any], expected_name: ArmName) -> Arm:
    """Build an Arm from already-loaded JSON, validating the task set.

    The task set is checked against PROTOCOL.md section 1 rather than taken as
    given: a comparison built from arms that ran different tasks, or the same
    task twice, is not a comparison.
    """
    clean = _strip_doc_keys(data)
    name = clean.get("arm")
    if name != expected_name:
        raise ArmLoadError(f"expected arm {expected_name!r}, got {name!r}")

    raw_tasks = clean.get("tasks")
    if not isinstance(raw_tasks, list):
        raise ArmLoadError(f"{name}: 'tasks' must be a list, got {type(raw_tasks).__name__}")

    rows: list[TaskRow] = []
    for raw in raw_tasks:
        if not isinstance(raw, dict):
            raise ArmLoadError(f"{name}: each task must be an object, got {raw!r}")
        task = _strip_doc_keys(raw)
        task_id = task.get("id")
        if not isinstance(task_id, str):
            raise ArmLoadError(f"{name}: task missing a string 'id', got {task_id!r}")
        rows.append(
            TaskRow(
                task_id=task_id,
                completion=_opt_bool(task.get("completion"), "completion", task_id),
                wall_seconds=_opt_float(task.get("wall_seconds"), "wall_seconds", task_id),
                clarification_turns=_opt_int(
                    task.get("clarification_turns"), "clarification_turns", task_id
                ),
                recovery_success=_opt_bool(
                    task.get("recovery_success"), "recovery_success", task_id
                ),
                terminal_exposure=_opt_int(
                    task.get("terminal_exposure"), "terminal_exposure", task_id
                ),
                terminal_exposure_zero_construction=_opt_int(
                    task.get("terminal_exposure_zero_construction"),
                    "terminal_exposure_zero_construction",
                    task_id,
                ),
                intent_invocations=_opt_int(
                    task.get("intent_invocations"), "intent_invocations", task_id
                ),
            )
        )

    seen = [r.task_id for r in rows]
    if seen != EXPECTED_TASK_IDS:
        raise ArmLoadError(
            f"{name}: tasks must be exactly PROTOCOL.md section 1's six, in order.\n"
            f"  expected: {EXPECTED_TASK_IDS}\n"
            f"  got:      {seen}"
        )

    trust = clean.get("post_failure_trust")
    if trust is not None and (isinstance(trust, bool) or not isinstance(trust, int)):
        raise ArmLoadError(f"{name}: post_failure_trust must be an integer 1-5 or null")
    if isinstance(trust, int) and not 1 <= trust <= 5:
        raise ArmLoadError(f"{name}: post_failure_trust must be 1-5, got {trust}")

    return Arm(
        name=name,
        tasks=rows,
        post_failure_trust=trust,
        cursor_transport_verified=_validate_cursor_transport(clean, expected_name),
    )


def load_arm(path: Path, expected_name: ArmName) -> Arm:
    if not path.exists():
        raise ArmLoadError(f"{path} does not exist")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ArmLoadError(f"{path}: invalid JSON ({exc})") from exc
    if not isinstance(data, dict):
        raise ArmLoadError(f"{path}: top level must be an object")
    return parse_arm(data, expected_name)


def _total(values: list[int | None]) -> int | None:
    """Sum, or None if any value is unscored.

    Deliberately not sum(v or 0 ...): a partially scored arm has no total, and
    inventing one is how a null quietly becomes a zero in a headline number.
    """
    if any(v is None for v in values):
        return None
    return sum(v for v in values if v is not None)


def completion_count(arm: Arm) -> int | None:
    values = [1 if t.completion else 0 if t.completion is not None else None for t in arm.tasks]
    return _total(values)


def clarification_total(arm: Arm) -> int | None:
    return _total([t.clarification_turns for t in arm.tasks])


def terminal_exposure_total(arm: Arm) -> int | None:
    """Baseline-shaped total: sum of shell commands seen or approved.

    None for the intentd arm, which does not report this shape at all (see the
    module docstring); use intent_invocations_total alongside the constant 0.
    """
    return _total([t.terminal_exposure for t in arm.tasks])


def intent_invocations_total(arm: Arm) -> int | None:
    return _total([t.intent_invocations for t in arm.tasks])


def recovery_result(arm: Arm) -> bool | None:
    for task in arm.tasks:
        if task.task_id == RECOVERY_TASK_ID:
            return task.recovery_success
    return None


def unscored_metrics(intentd: Arm, baseline: Arm) -> list[str]:
    """Every metric that cannot be compared because one side is unscored."""
    gaps: list[str] = []
    for arm in (intentd, baseline):
        if completion_count(arm) is None:
            gaps.append(f"completion ({arm.name} arm has an unscored task)")
        if clarification_total(arm) is None:
            gaps.append(f"clarification_turns ({arm.name} arm has an unscored task)")
        if recovery_result(arm) is None:
            gaps.append(f"recovery_success ({arm.name} arm, task 6 unscored)")
        if arm.post_failure_trust is None:
            gaps.append(f"post_failure_trust ({arm.name} arm unscored)")
    if terminal_exposure_total(baseline) is None:
        gaps.append("terminal_exposure (baseline arm has an unscored task)")
    if intent_invocations_total(intentd) is None:
        gaps.append("intent_invocations (intentd arm has an unscored task)")
    if baseline.cursor_transport_verified is not True:
        gaps.append("baseline.cursor_mcp_transport_compatibility")
    return gaps


def _cell(value: object) -> str:
    if value is None:
        return "unscored"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, float):
        return f"{value:.1f}"
    return str(value)


def format_report(intentd: Arm, baseline: Arm) -> str:
    """Render the whole comparison, including its own caveats."""
    lines: list[str] = []
    lines.append("Comparative baseline (eval/baseline/PROTOCOL.md)")
    lines.append("=" * 72)
    lines.append("")

    header = f"{'task':<38} {'intentd':>14} {'baseline':>14}"
    for title, getter in (
        ("completion", lambda t: t.completion),
        ("clarification_turns", lambda t: t.clarification_turns),
        ("wall_seconds", lambda t: t.wall_seconds),
    ):
        lines.append(f"-- {title}")
        lines.append(header)
        for i_task, b_task in zip(intentd.tasks, baseline.tasks, strict=True):
            lines.append(
                f"{i_task.task_id:<38} {_cell(getter(i_task)):>14} {_cell(getter(b_task)):>14}"
            )
        lines.append("")

    lines.append("-- terminal exposure (PROTOCOL section 5.4: two shapes, not one number)")
    lines.append(f"{'task':<38} {'intentd (0 / n)':>18} {'baseline':>10}")
    for i_task, b_task in zip(intentd.tasks, baseline.tasks, strict=True):
        pair = f"{_cell(i_task.terminal_exposure_zero_construction)} / {_cell(i_task.intent_invocations)}"
        lines.append(f"{i_task.task_id:<38} {pair:>18} {_cell(b_task.terminal_exposure):>10}")
    lines.append("")

    lines.append("-- totals")
    lines.append(
        f"  completion            {_cell(completion_count(intentd))} / 6"
        f"   vs  {_cell(completion_count(baseline))} / 6"
    )
    lines.append(
        f"  clarification_turns   {_cell(clarification_total(intentd))}"
        f"       vs  {_cell(clarification_total(baseline))}"
    )
    lines.append(
        f"  terminal exposure     0 (by construction),"
        f" {_cell(intent_invocations_total(intentd))} intent calls"
        f"   vs  {_cell(terminal_exposure_total(baseline))} shell commands"
    )
    lines.append(
        f"  recovery_success      {_cell(recovery_result(intentd))}"
        f"      vs  {_cell(recovery_result(baseline))}"
    )
    lines.append(
        f"  post_failure_trust    {_cell(intentd.post_failure_trust)}"
        f"       vs  {_cell(baseline.post_failure_trust)}"
    )
    lines.append("")

    lines.append("-- caveats carried from the protocol")
    lines.append("  wall_seconds is NOT totalled: the intentd arm's numbers are nixosTest")
    lines.append("  driver deltas and the baseline arm's are a human stopwatch on different")
    lines.append("  hardware (PROTOCOL section 5.2). Compare the shape across tasks, not")
    lines.append("  the absolute magnitudes.")
    lines.append("")

    gaps = unscored_metrics(intentd, baseline)
    if gaps:
        lines.append("-- UNSCORED, no verdict available on:")
        for gap in gaps:
            lines.append(f"  * {gap}")
        lines.append("")
        lines.append("  Fill these in per RUNBOOK.md before quoting this comparison.")
    else:
        lines.append("-- all metrics scored; this comparison is complete.")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    here = Path(__file__).parent
    parser = argparse.ArgumentParser(
        prog="eval.baseline.compare",
        description="Compare the intentd and baseline arms of the comparative baseline protocol.",
    )
    parser.add_argument("--intentd", type=Path, default=here / "intentd_arm.json")
    parser.add_argument("--baseline", type=Path, default=here / "baseline_arm.json")
    args = parser.parse_args(argv)

    try:
        intentd = load_arm(args.intentd, "intentd")
    except ArmLoadError as exc:
        print(f"intentd arm: {exc}")
        return 1

    try:
        baseline = load_arm(args.baseline, "baseline")
    except ArmLoadError as exc:
        print(f"baseline arm: {exc}")
        print()
        print("The baseline arm has not been run yet. It requires a human:")
        print("see eval/baseline/RUNBOOK.md, and start from")
        print("eval/baseline/baseline_arm.template.json.")
        return 1

    print(format_report(intentd, baseline))
    return 0 if not unscored_metrics(intentd, baseline) else 2


if __name__ == "__main__":
    raise SystemExit(main())
