"""Tests for the comparative-baseline arm comparison.

The point of most of these is the null discipline: PROTOCOL.md leaves four
measurements to human judgment, and the failure mode worth guarding against is
an unscored metric quietly becoming a zero in a total, which would let the
wedge claim a comparative result it has not measured.
"""

import json
from pathlib import Path
from typing import Any

import pytest

from eval.baseline.compare import (
    EXPECTED_TASK_IDS,
    ArmLoadError,
    clarification_total,
    completion_count,
    format_report,
    intent_invocations_total,
    load_arm,
    main,
    recovery_result,
    terminal_exposure_total,
    unscored_metrics,
)
from eval.baseline.compare import (
    parse_arm as parse_arm_for_role,
)

BASELINE_DIR = Path(__file__).parent.parent / "eval" / "baseline"


def parse_arm(data: dict[str, Any]):
    name = data["arm"]
    assert name in ("intentd", "baseline")
    return parse_arm_for_role(data, name)


def valid_cursor_transport() -> dict[str, Any]:
    return {
        "official_cli_version": "2026.08.11-e8db854",
        "official_archive_sha256": (
            "bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a"
        ),
        "official_bundle_sha256": (
            "f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0"
        ),
        "task_facing_node_sha256": (
            "e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4"
        ),
        "patched_bundle_sha256": (
            "7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a"
        ),
        "mcp_timeout_ms": 300_000,
        "immutable_store_path": (
            "/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854"
        ),
        "first_application_status": "patched",
        "idempotence_verification_status": "already_patched",
        "pre_chat_cli_version": "2026.08.11-e8db854",
        "post_chat_cli_version": "2026.08.11-e8db854",
        "auto_update_disabled": True,
    }


def make_task(task_id: str, **overrides: Any) -> dict[str, Any]:
    task: dict[str, Any] = {
        "id": task_id,
        "completion": True,
        "wall_seconds": 10.0,
        "clarification_turns": 0,
        "recovery_success": None,
        "terminal_exposure": 3,
    }
    task.update(overrides)
    return task


def make_arm(name: str = "baseline", **overrides: Any) -> dict[str, Any]:
    arm: dict[str, Any] = {
        "arm": name,
        "tasks": [make_task(t) for t in EXPECTED_TASK_IDS],
        "post_failure_trust": 4,
    }
    if name == "baseline":
        arm["agent"] = {"cli_version": "2026.08.11-e8db854"}
        arm["cursor_mcp_transport_compatibility"] = valid_cursor_transport()
    arm.update(overrides)
    return arm


def test_parses_a_well_formed_arm() -> None:
    arm = parse_arm(make_arm())
    assert arm.name == "baseline"
    assert [t.task_id for t in arm.tasks] == EXPECTED_TASK_IDS
    assert arm.post_failure_trust == 4


def test_documentation_keys_are_not_measurements() -> None:
    """_-prefixed keys carry the template's inline instructions, not data."""
    raw = make_arm()
    raw["_template"] = "copy me"
    raw["tasks"][0]["_verify_hint"] = "which firefox"
    arm = parse_arm(raw)
    assert arm.tasks[0].completion is True


def test_rejects_a_different_task_set() -> None:
    raw = make_arm()
    raw["tasks"] = raw["tasks"][:5]
    with pytest.raises(ArmLoadError, match="exactly PROTOCOL.md"):
        parse_arm(raw)


def test_rejects_reordered_tasks() -> None:
    """Order matters: the arms chain state, so task N means nothing on its own."""
    raw = make_arm()
    raw["tasks"][0], raw["tasks"][1] = raw["tasks"][1], raw["tasks"][0]
    with pytest.raises(ArmLoadError, match="exactly PROTOCOL.md"):
        parse_arm(raw)


def test_rejects_a_bool_where_a_count_belongs() -> None:
    """bool is an int subclass in Python; True must not pass as a turn count."""
    raw = make_arm()
    raw["tasks"][0]["clarification_turns"] = True
    with pytest.raises(ArmLoadError, match="clarification_turns"):
        parse_arm(raw)


def test_rejects_out_of_range_trust() -> None:
    with pytest.raises(ArmLoadError, match="1-5"):
        parse_arm(make_arm(post_failure_trust=9))


def test_rejects_wrong_baseline_cursor_transport_constant() -> None:
    raw = make_arm()
    raw["cursor_mcp_transport_compatibility"]["mcp_timeout_ms"] = 60_000

    with pytest.raises(ArmLoadError, match="mcp_timeout_ms"):
        parse_arm(raw)


def test_rejects_baseline_agent_cli_mismatch() -> None:
    raw = make_arm()
    raw["agent"]["cli_version"] = "newer-auto-updated-version"

    with pytest.raises(ArmLoadError, match="agent.cli_version"):
        parse_arm(raw)


def test_rejects_mislabeled_baseline_for_expected_role() -> None:
    raw = make_arm("intentd")

    with pytest.raises(ArmLoadError, match="expected arm 'baseline'"):
        parse_arm_for_role(raw, "baseline")


def test_main_rejects_swapped_arm_paths(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    intentd_path = tmp_path / "intentd.json"
    baseline_path = tmp_path / "baseline.json"
    intentd_path.write_text(json.dumps(make_arm("intentd")))
    baseline_path.write_text(json.dumps(make_arm("baseline")))

    result = main(
        [
            "--intentd",
            str(baseline_path),
            "--baseline",
            str(intentd_path),
        ]
    )

    assert result == 1
    assert "expected arm 'intentd', got 'baseline'" in capsys.readouterr().out


def test_null_baseline_cursor_run_statuses_are_unscored() -> None:
    raw = make_arm()
    raw["cursor_mcp_transport_compatibility"]["pre_chat_cli_version"] = None
    baseline = parse_arm(raw)
    intentd = parse_arm(make_arm("intentd"))

    assert baseline.cursor_transport_verified is False
    assert "baseline.cursor_mcp_transport_compatibility" in unscored_metrics(intentd, baseline)


def test_totals_are_none_when_any_task_is_unscored() -> None:
    raw = make_arm()
    raw["tasks"][2]["clarification_turns"] = None
    arm = parse_arm(raw)
    assert clarification_total(arm) is None, "a partially scored arm has no total"


def test_totals_sum_when_fully_scored() -> None:
    raw = make_arm()
    for i, task in enumerate(raw["tasks"]):
        task["clarification_turns"] = i
    arm = parse_arm(raw)
    assert clarification_total(arm) == 15


def test_completion_count_counts_only_true() -> None:
    raw = make_arm()
    raw["tasks"][0]["completion"] = False
    raw["tasks"][1]["completion"] = False
    assert completion_count(parse_arm(raw)) == 4


def test_completion_count_is_none_when_unscored() -> None:
    raw = make_arm()
    raw["tasks"][0]["completion"] = None
    assert completion_count(parse_arm(raw)) is None


def test_recovery_result_reads_task_six_only() -> None:
    raw = make_arm()
    raw["tasks"][5]["recovery_success"] = True
    assert recovery_result(parse_arm(raw)) is True


def test_arm_shapes_do_not_bleed_into_each_other() -> None:
    """The two arms report terminal exposure differently (PROTOCOL 5.4)."""
    baseline = parse_arm(make_arm())
    assert terminal_exposure_total(baseline) == 18
    assert intent_invocations_total(baseline) is None


def test_unscored_metrics_names_every_gap() -> None:
    intentd = parse_arm(
        make_arm(
            "intentd",
            tasks=[
                make_task(t, terminal_exposure=None, intent_invocations=1)
                for t in EXPECTED_TASK_IDS
            ],
            post_failure_trust=None,
        )
    )
    baseline = parse_arm(make_arm())
    gaps = unscored_metrics(intentd, baseline)
    assert any("post_failure_trust" in g and "intentd" in g for g in gaps)
    assert any("recovery_success" in g for g in gaps)


def test_report_refuses_a_verdict_while_anything_is_unscored() -> None:
    intentd = parse_arm(make_arm("intentd", post_failure_trust=None))
    baseline = parse_arm(make_arm())
    report = format_report(intentd, baseline)
    assert "UNSCORED, no verdict available" in report
    assert "complete" not in report.split("-- UNSCORED")[0].split("caveats")[-1]


def test_report_is_complete_when_everything_is_scored() -> None:
    tasks = [
        make_task(
            t, recovery_success=True if t == EXPECTED_TASK_IDS[5] else None, intent_invocations=1
        )
        for t in EXPECTED_TASK_IDS
    ]
    intentd = parse_arm(make_arm("intentd", tasks=tasks))
    baseline = parse_arm(make_arm(tasks=tasks))
    report = format_report(intentd, baseline)
    assert "all metrics scored" in report


def test_report_never_totals_wall_seconds() -> None:
    """PROTOCOL 5.2: the two arms' clocks are not commensurable."""
    arm = parse_arm(make_arm())
    report = format_report(arm, arm)
    assert "wall_seconds is NOT totalled" in report


def test_committed_intentd_arm_parses() -> None:
    """The real pilot output stays readable by this tool."""
    arm = load_arm(BASELINE_DIR / "intentd_arm.json", "intentd")
    assert completion_count(arm) == 6
    assert clarification_total(arm) == 1, "the license ack is the only clarification"
    assert intent_invocations_total(arm) == 7
    assert recovery_result(arm) is True
    assert arm.post_failure_trust == 5


def test_committed_baseline_arm_is_fully_scored() -> None:
    arm = load_arm(BASELINE_DIR / "baseline_arm.json", "baseline")
    assert completion_count(arm) == 6
    assert clarification_total(arm) == 0
    assert terminal_exposure_total(arm) == 32
    assert recovery_result(arm) is True
    assert arm.post_failure_trust == 4
    assert arm.cursor_transport_verified is True


def test_committed_template_parses() -> None:
    """The template must stay valid as a starting point, docs keys and all."""
    arm = load_arm(BASELINE_DIR / "baseline_arm.template.json", "baseline")
    assert completion_count(arm) is None
    assert arm.post_failure_trust is None


def test_main_explains_the_missing_baseline_arm(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    rc = main(
        [
            "--intentd",
            str(BASELINE_DIR / "intentd_arm.json"),
            "--baseline",
            str(tmp_path / "absent.json"),
        ]
    )
    assert rc == 1
    out = capsys.readouterr().out
    assert "RUNBOOK.md" in out


def test_main_returns_two_when_metrics_are_unscored(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    path = tmp_path / "baseline_arm.json"
    path.write_text(json.dumps(make_arm(post_failure_trust=None)), encoding="utf-8")
    rc = main(["--intentd", str(BASELINE_DIR / "intentd_arm.json"), "--baseline", str(path)])
    assert rc == 2, "an incomplete comparison is not a success"
    assert "UNSCORED" in capsys.readouterr().out
