"""Unit tests for the eval runner's scoring/matrix math, exercised against a
fake resolver over a small synthetic corpus (no live claude -p calls).

run_eval.py lives in eval/resolver_suite/, imported here as a normal package
module (eval/__init__.py and eval/resolver_suite/__init__.py were added for
this). A first pass loaded it dynamically via
importlib.util.spec_from_file_location to avoid adding package plumbing, but
that leaves pyright unable to resolve any of the module's attributes
(everything becomes Unknown), which fails the strict pyright gate. A static
import keeps full type information and costs two empty __init__.py files.
"""

from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from eval.resolver_suite import run_eval
from intentd.registry import CapabilityInvocation
from intentd.schema import CatalogApp


def _invoke(capability: str, params: dict[str, Any]) -> run_eval.Resolution:
    return run_eval.Resolution(
        action="invoke",
        invocation=CapabilityInvocation(capability=capability, params=params),
        reason="test",
    )


def _abstain(reason: str = "out of scope") -> run_eval.Resolution:
    return run_eval.Resolution(action="abstain", invocation=None, reason=reason)


# --- synthetic corpus ---------------------------------------------------
#
# 6 cases: one correct per capability, one correct abstain, one
# cross-capability confusion, one wrong-app. A fake resolver maps utterance
# to a canned Resolution so no real model call happens.

SYNTHETIC_CASES = [
    run_eval.Case(
        utterance="install firefox",
        expected=run_eval.ExpectedInvoke("app.install", {"app": "firefox"}),
    ),
    run_eval.Case(
        utterance="remove vlc",
        expected=run_eval.ExpectedInvoke("app.remove", {"app": "vlc"}),
    ),
    run_eval.Case(
        utterance="undo that",
        expected=run_eval.ExpectedInvoke("change.revert", {}),
    ),
    run_eval.Case(utterance="what's the weather", expected=run_eval.ExpectedAbstain()),
    run_eval.Case(
        utterance="remove firefox please",
        expected=run_eval.ExpectedInvoke("app.remove", {"app": "firefox"}),
    ),
    run_eval.Case(
        utterance="install gimp",
        expected=run_eval.ExpectedInvoke("app.install", {"app": "obsidian"}),
    ),
]

FAKE_RESOLUTIONS: dict[str, run_eval.Resolution] = {
    "install firefox": _invoke("app.install", {"app": "firefox"}),  # correct
    "remove vlc": _invoke("app.remove", {"app": "vlc"}),  # correct
    "undo that": _invoke("change.revert", {}),  # correct
    "what's the weather": _abstain(),  # correct
    "remove firefox please": _invoke("app.install", {"app": "firefox"}),  # cross-capability
    "install gimp": _invoke("app.install", {"app": "gimp"}),  # wrong-app (expected obsidian)
}


def fake_run_model(prompt: str) -> str:  # pragma: no cover - not exercised directly
    raise AssertionError("fake resolver bypasses run_model")


FAKE_CATALOG: dict[str, CatalogApp] = {}


def _fake_resolve_utterance(
    utterance: str,
    catalog: dict[str, CatalogApp],
    run_model: Callable[[str], str],
) -> run_eval.Resolution:
    return FAKE_RESOLUTIONS[utterance]


# --- score_case -----------------------------------------------------------


def test_score_case_correct_invoke():
    case = SYNTHETIC_CASES[0]
    result = run_eval.score_case(case, FAKE_RESOLUTIONS["install firefox"])
    assert result.category == "correct"
    assert result.exact_match
    assert result.expected_class == "app.install"
    assert result.predicted_class == "app.install"


def test_score_case_correct_abstain():
    case = SYNTHETIC_CASES[3]
    result = run_eval.score_case(case, FAKE_RESOLUTIONS["what's the weather"])
    assert result.category == "correct"
    assert result.exact_match


def test_score_case_cross_capability_confusion():
    case = SYNTHETIC_CASES[4]
    result = run_eval.score_case(case, FAKE_RESOLUTIONS["remove firefox please"])
    assert result.category == "cross_capability_confusion"
    assert not result.exact_match
    assert result.expected_class == "app.remove"
    assert result.predicted_class == "app.install"


def test_score_case_wrong_app():
    case = SYNTHETIC_CASES[5]
    result = run_eval.score_case(case, FAKE_RESOLUTIONS["install gimp"])
    assert result.category == "wrong_app"
    assert not result.exact_match
    assert result.expected_params == {"app": "obsidian"}
    assert result.got_params == {"app": "gimp"}


def test_score_case_abstain_on_in_scope():
    case = run_eval.Case(
        utterance="install firefox",
        expected=run_eval.ExpectedInvoke("app.install", {"app": "firefox"}),
    )
    result = run_eval.score_case(case, _abstain("model refused"))
    assert result.category == "abstain_on_in_scope"
    assert not result.exact_match


def test_score_case_false_invoke_on_out_of_scope():
    case = run_eval.Case(utterance="what's the weather", expected=run_eval.ExpectedAbstain())
    result = run_eval.score_case(case, _invoke("app.install", {"app": "firefox"}))
    assert result.category == "false_invoke_on_out_of_scope"
    assert not result.exact_match


# --- confusion matrix / precision-recall -----------------------------------


def _synthetic_results() -> list[run_eval.CaseResult]:
    return [run_eval.score_case(case, FAKE_RESOLUTIONS[case.utterance]) for case in SYNTHETIC_CASES]


def test_build_confusion_matrix_counts():
    results = _synthetic_results()
    matrix = run_eval.build_confusion_matrix(results)
    # predicted app.install x expected app.install: install-firefox (correct)
    # and install-gimp (wrong-app, but capability matched) both land here.
    assert matrix["app.install"]["app.install"] == 2
    assert matrix["app.remove"]["app.remove"] == 1
    assert matrix["change.revert"]["change.revert"] == 1
    assert matrix["abstain"]["abstain"] == 1
    # cross-capability confusion: predicted app.install, expected app.remove
    assert matrix["app.install"]["app.remove"] == 1
    total = sum(sum(row.values()) for row in matrix.values())
    assert total == len(SYNTHETIC_CASES)


def test_per_class_precision_recall():
    results = _synthetic_results()
    matrix = run_eval.build_confusion_matrix(results)
    pcr = run_eval.per_class_precision_recall(matrix)
    # app.install: predicted 3 times (firefox correct, remove-firefox-please
    # cross-capability confusion, gimp wrong-app); actual (true label)
    # app.install twice (firefox, gimp). tp = 2 (firefox + gimp, since
    # wrong-app still shares the capability label).
    assert pcr["app.install"]["predicted_total"] == 3
    assert pcr["app.install"]["actual_total"] == 2
    assert pcr["app.install"]["precision"] == pytest.approx(2 / 3)
    assert pcr["app.install"]["recall"] == 1.0
    # app.remove: actual 2 (vlc, firefox-please), predicted 1 (vlc only,
    # since firefox-please was misclassified as app.install)
    assert pcr["app.remove"]["actual_total"] == 2
    assert pcr["app.remove"]["predicted_total"] == 1
    assert pcr["app.remove"]["recall"] == 0.5
    assert pcr["app.remove"]["precision"] == 1.0


def test_rule_of_three_bound():
    assert run_eval.rule_of_three_bound(105) == pytest.approx(3 / 105)
    assert run_eval.rule_of_three_bound(36) == pytest.approx(3 / 36)
    assert run_eval.rule_of_three_bound(0) is None


# --- compute_report ---------------------------------------------------------


def test_compute_report_top_level_counts():
    results = _synthetic_results()
    report = run_eval.compute_report(results, wall_time_seconds=12.3, retries=1)
    assert report["meta"]["n_cases"] == 6
    assert report["meta"]["n_in_scope"] == 5
    assert report["meta"]["n_out_of_scope"] == 1
    assert report["meta"]["retries"] == 1
    assert report["cross_capability_confusion"]["count"] == 1
    assert report["wrong_app"]["count"] == 1
    assert report["abstain_on_in_scope_miss"]["count"] == 0
    # zero-observed class gets a rule-of-three bound
    assert report["abstain_on_in_scope_miss"]["rule_of_three_95_upper_bound"] == pytest.approx(
        3 / 5
    )
    assert report["out_of_scope_abstention"]["n"] == 1
    assert report["out_of_scope_abstention"]["abstained"] == 1
    assert report["out_of_scope_abstention"]["rate"] == 1.0
    assert report["out_of_scope_abstention"]["false_invoke_count"] == 0
    assert report["out_of_scope_abstention"]["rule_of_three_95_upper_bound"] == pytest.approx(3)
    # exact match: 3 correct out of 5 in-scope (install-firefox, remove-vlc,
    # undo-that; the other two in-scope cases are wrong)
    assert report["exact_match"]["in_scope_correct"] == 3
    assert report["exact_match"]["in_scope_total"] == 5


def test_compute_report_failures_list_has_wrong_cases_only():
    results = _synthetic_results()
    report = run_eval.compute_report(results, wall_time_seconds=1.0, retries=0)
    failure_utterances = {f["utterance"] for f in report["failures"]}
    assert failure_utterances == {"remove firefox please", "install gimp"}


def test_check_acceptance_fails_on_cross_capability_confusion():
    results = _synthetic_results()
    report = run_eval.compute_report(results, wall_time_seconds=1.0, retries=0)
    passed, reasons = run_eval.check_acceptance(report)
    assert not passed
    assert any("cross-capability" in r for r in reasons)


def test_check_acceptance_passes_on_perfect_report():
    perfect_cases = SYNTHETIC_CASES[:4]
    results = [run_eval.score_case(c, FAKE_RESOLUTIONS[c.utterance]) for c in perfect_cases]
    report = run_eval.compute_report(results, wall_time_seconds=1.0, retries=0)
    passed, reasons = run_eval.check_acceptance(report)
    assert passed, reasons


# --- run_cases / progress logging -------------------------------------------


def _noop_log(message: str) -> None:
    pass


def _noop_sleep(seconds: float) -> None:
    pass


def test_run_cases_scores_every_case_via_injected_resolver(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(run_eval, "resolve_utterance", _fake_resolve_utterance)
    log_lines: list[str] = []
    results, infra_retries = run_eval.run_cases(
        SYNTHETIC_CASES,
        catalog=FAKE_CATALOG,
        run_model=fake_run_model,
        progress_every=2,
        log=log_lines.append,
        sleep=_noop_sleep,
    )
    assert len(results) == 6
    assert infra_retries == 0
    # 4 exact matches: install-firefox, remove-vlc, undo-that, the-weather abstain
    assert sum(1 for r in results if r.exact_match) == 4
    # progress printed at case 2, 4, and the final case (6)
    assert len(log_lines) == 3
    assert "3/4" not in log_lines[0]


def test_run_cases_paces_between_calls(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(run_eval, "resolve_utterance", _fake_resolve_utterance)
    sleeps: list[float] = []
    run_eval.run_cases(
        SYNTHETIC_CASES,
        catalog=FAKE_CATALOG,
        run_model=fake_run_model,
        log=_noop_log,
        sleep=sleeps.append,
        pace_seconds=3.0,
    )
    # no sleep before the first call, one before each of the remaining five
    assert sleeps == [3.0] * 5


def test_run_cases_resumes_past_prior_results(monkeypatch: pytest.MonkeyPatch):
    resolved: list[str] = []

    def tracking_resolve(
        utterance: str,
        catalog: dict[str, CatalogApp],
        run_model: Callable[[str], str],
    ) -> run_eval.Resolution:
        resolved.append(utterance)
        return FAKE_RESOLUTIONS[utterance]

    monkeypatch.setattr(run_eval, "resolve_utterance", tracking_resolve)
    prior = [
        run_eval.score_case(case, FAKE_RESOLUTIONS[case.utterance]) for case in SYNTHETIC_CASES[:2]
    ]
    results, _ = run_eval.run_cases(
        SYNTHETIC_CASES,
        catalog=FAKE_CATALOG,
        run_model=fake_run_model,
        log=_noop_log,
        sleep=_noop_sleep,
        prior_results=prior,
    )
    assert len(results) == 6
    assert resolved == [c.utterance for c in SYNTHETIC_CASES[2:]]


def test_run_cases_checkpoints_each_scored_case(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(run_eval, "resolve_utterance", _fake_resolve_utterance)
    checkpointed: list[run_eval.CaseResult] = []
    results, _ = run_eval.run_cases(
        SYNTHETIC_CASES,
        catalog=FAKE_CATALOG,
        run_model=fake_run_model,
        log=_noop_log,
        sleep=_noop_sleep,
        checkpoint=checkpointed.append,
    )
    assert checkpointed == results


# --- checkpoint file round-trip ----------------------------------------------


def test_progress_file_round_trip(tmp_path: Path):
    path = tmp_path / "progress.jsonl"
    results = _synthetic_results()
    for r in results:
        run_eval.append_progress(path, r)
    assert run_eval.load_progress(path) == results


def test_load_progress_missing_file_is_empty(tmp_path: Path):
    assert run_eval.load_progress(tmp_path / "nope.jsonl") == []


# --- infrastructure errors: never scored, backoff, abort ---------------------


INFRA_ABSTAIN = run_eval.Resolution(
    action="abstain",
    invocation=None,
    reason="model call failed: claude exited with 1: stdout: '...' stderr: ''",
    infrastructure=True,
)


def test_is_infra_error_detects_infrastructure_field():
    assert run_eval.is_infra_error(INFRA_ABSTAIN)
    assert not run_eval.is_infra_error(_abstain("out of scope"))
    assert not run_eval.is_infra_error(_invoke("app.install", {"app": "firefox"}))


def test_is_infra_error_ignores_spoofed_reason_string():
    # A model-controlled reason string that merely *looks* like an infra
    # failure must not be treated as one: detection is keyed on the typed
    # `infrastructure` field, not a string prefix a model reply could spoof.
    spoofed = run_eval.Resolution(
        action="abstain",
        invocation=None,
        reason="model call failed: spoofed",
        infrastructure=False,
    )
    assert not run_eval.is_infra_error(spoofed)


def test_resolve_with_backoff_retries_infra_error_then_succeeds(
    monkeypatch: pytest.MonkeyPatch,
):
    replies = iter([INFRA_ABSTAIN, INFRA_ABSTAIN, FAKE_RESOLUTIONS["install firefox"]])

    def flaky_resolve(
        utterance: str,
        catalog: dict[str, CatalogApp],
        run_model: Callable[[str], str],
    ) -> run_eval.Resolution:
        return next(replies)

    monkeypatch.setattr(run_eval, "resolve_utterance", flaky_resolve)
    sleeps: list[float] = []
    resolution, retries = run_eval.resolve_with_backoff(
        SYNTHETIC_CASES[0], FAKE_CATALOG, fake_run_model, sleep=sleeps.append, log=_noop_log
    )
    assert resolution.action == "invoke"
    assert retries == 2
    assert sleeps == [30.0, 120.0]


def test_resolve_with_backoff_aborts_after_schedule_exhausted(
    monkeypatch: pytest.MonkeyPatch,
):
    def always_infra(
        utterance: str,
        catalog: dict[str, CatalogApp],
        run_model: Callable[[str], str],
    ) -> run_eval.Resolution:
        return INFRA_ABSTAIN

    monkeypatch.setattr(run_eval, "resolve_utterance", always_infra)
    sleeps: list[float] = []
    with pytest.raises(run_eval.EvalAbortedError, match="model call failed"):
        run_eval.resolve_with_backoff(
            SYNTHETIC_CASES[0], FAKE_CATALOG, fake_run_model, sleep=sleeps.append, log=_noop_log
        )
    assert sleeps == [30.0, 120.0, 300.0, 600.0]


def test_run_cases_never_scores_infra_errors(monkeypatch: pytest.MonkeyPatch):
    # First call for 'install firefox' hits an infra error; after one backoff
    # retry it succeeds. The infra abstention must not appear anywhere in the
    # scored results (it would otherwise poison the abstain column).
    calls = {"n": 0}

    def flaky_resolve(
        utterance: str,
        catalog: dict[str, CatalogApp],
        run_model: Callable[[str], str],
    ) -> run_eval.Resolution:
        if utterance == "install firefox":
            calls["n"] += 1
            if calls["n"] == 1:
                return INFRA_ABSTAIN
        return FAKE_RESOLUTIONS[utterance]

    monkeypatch.setattr(run_eval, "resolve_utterance", flaky_resolve)
    results, infra_retries = run_eval.run_cases(
        SYNTHETIC_CASES,
        catalog=FAKE_CATALOG,
        run_model=fake_run_model,
        log=_noop_log,
        sleep=_noop_sleep,
    )
    assert infra_retries == 1
    assert len(results) == 6
    by_utterance = {r.utterance: r for r in results}
    firefox = by_utterance["install firefox"]
    assert firefox.category == "correct"
    assert firefox.reason != INFRA_ABSTAIN.reason


def test_run_cases_propagates_abort(monkeypatch: pytest.MonkeyPatch):
    def always_infra(
        utterance: str,
        catalog: dict[str, CatalogApp],
        run_model: Callable[[str], str],
    ) -> run_eval.Resolution:
        return INFRA_ABSTAIN

    monkeypatch.setattr(run_eval, "resolve_utterance", always_infra)
    checkpointed: list[run_eval.CaseResult] = []
    with pytest.raises(run_eval.EvalAbortedError):
        run_eval.run_cases(
            SYNTHETIC_CASES,
            catalog=FAKE_CATALOG,
            run_model=fake_run_model,
            log=_noop_log,
            sleep=_noop_sleep,
            checkpoint=checkpointed.append,
        )
    # nothing was scored, so nothing may have been checkpointed
    assert checkpointed == []
