"""Live eval runner for the resolver suite (script, not pytest; marker claude_live
excludes the real claude -p calls from the default gate).

Usage:
    uv run python eval/resolver_suite/run_eval.py
    uv run python eval/resolver_suite/run_eval.py --only-utterances failed.txt

Scoring/matrix functions are plain, dependency-free, and unit-tested in
tests/test_eval_runner.py against a synthetic corpus with an injected fake
resolver, independent of any live claude -p call.

Infrastructure failures (the claude CLI itself erroring, e.g. a subscription
session limit) surface as abstentions with Resolution.infrastructure=True,
set only on the run_model-exception path in resolve_utterance (never from
model-controlled content, so a model reply cannot spoof its way past this).
Those are NEVER scored as predictions: the case is retried with exponential
backoff, and if the CLI stays down the whole run aborts, writing
report.partial.json with an explicit "aborted" marker instead of report.json,
so a partial run cannot be mistaken for results. Every scored case is
checkpointed to progress.jsonl as it completes and skipped on the next start;
delete that file for a fresh run.
"""

import argparse
import json
import time
from collections.abc import Callable
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from intentd.catalog import load_catalog
from intentd.resolver import Resolution, resolve_utterance, run_claude
from intentd.schema import CatalogApp

CASES_PATH = Path(__file__).resolve().parent / "cases.jsonl"
REPORT_PATH = Path(__file__).resolve().parent / "report.json"
PARTIAL_REPORT_PATH = Path(__file__).resolve().parent / "report.partial.json"
PROGRESS_PATH = Path(__file__).resolve().parent / "progress.jsonl"

CLASSES: tuple[str, ...] = ("app.install", "app.remove", "change.revert", "abstain")

BACKOFF_SECONDS: tuple[float, ...] = (30.0, 120.0, 300.0, 600.0)


class EvalAbortedError(Exception):
    """The claude CLI kept failing through every backoff retry; no report written."""


@dataclass(frozen=True)
class ExpectedInvoke:
    capability: str
    params: dict[str, Any]


@dataclass(frozen=True)
class ExpectedAbstain:
    pass


@dataclass(frozen=True)
class Case:
    utterance: str
    expected: ExpectedInvoke | ExpectedAbstain


@dataclass(frozen=True)
class CaseResult:
    utterance: str
    expected_class: str
    predicted_class: str
    exact_match: bool
    category: str
    reason: str
    expected_params: dict[str, Any] | None
    got_params: dict[str, Any] | None


def load_cases(path: Path) -> list[Case]:
    cases: list[Case] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        expected_obj = obj["expected"]
        expected: ExpectedInvoke | ExpectedAbstain
        if expected_obj["action"] == "invoke":
            expected = ExpectedInvoke(
                capability=expected_obj["capability"],
                params=expected_obj.get("params") or {},
            )
        else:
            expected = ExpectedAbstain()
        cases.append(Case(utterance=obj["utterance"], expected=expected))
    return cases


def expected_class(case: Case) -> str:
    if isinstance(case.expected, ExpectedAbstain):
        return "abstain"
    return case.expected.capability


def predicted_class(resolution: Resolution) -> str:
    if resolution.action == "abstain":
        return "abstain"
    assert resolution.invocation is not None, "invoke resolution without an invocation"
    return resolution.invocation.capability


def score_case(case: Case, resolution: Resolution) -> CaseResult:
    exp_class = expected_class(case)
    pred_class = predicted_class(resolution)
    got_params = dict(resolution.invocation.params) if resolution.invocation is not None else None
    exp_params = case.expected.params if isinstance(case.expected, ExpectedInvoke) else None

    if isinstance(case.expected, ExpectedAbstain):
        if pred_class == "abstain":
            category, exact = "correct", True
        else:
            category, exact = "false_invoke_on_out_of_scope", False
    else:
        if pred_class == "abstain":
            category, exact = "abstain_on_in_scope", False
        elif pred_class != exp_class:
            category, exact = "cross_capability_confusion", False
        elif got_params != exp_params:
            category, exact = "wrong_app", False
        else:
            category, exact = "correct", True

    return CaseResult(
        utterance=case.utterance,
        expected_class=exp_class,
        predicted_class=pred_class,
        exact_match=exact,
        category=category,
        reason=resolution.reason,
        expected_params=exp_params,
        got_params=got_params,
    )


def build_confusion_matrix(results: list[CaseResult]) -> dict[str, dict[str, int]]:
    matrix: dict[str, dict[str, int]] = {p: {e: 0 for e in CLASSES} for p in CLASSES}
    for r in results:
        matrix[r.predicted_class][r.expected_class] += 1
    return matrix


def per_class_precision_recall(matrix: dict[str, dict[str, int]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for c in CLASSES:
        tp = matrix[c][c]
        predicted_total = sum(matrix[c].values())
        actual_total = sum(matrix[p][c] for p in CLASSES)
        precision = tp / predicted_total if predicted_total else None
        recall = tp / actual_total if actual_total else None
        out[c] = {
            "tp": tp,
            "predicted_total": predicted_total,
            "actual_total": actual_total,
            "precision": precision,
            "recall": recall,
        }
    return out


def rule_of_three_bound(n: int) -> float | None:
    return 3 / n if n > 0 else None


def _class_report(cases: list[CaseResult], n_denom: int) -> dict[str, Any]:
    count = len(cases)
    rep: dict[str, Any] = {
        "count": count,
        "rate": count / n_denom if n_denom else None,
        "cases": [c.utterance for c in cases],
    }
    if count == 0:
        rep["rule_of_three_95_upper_bound"] = rule_of_three_bound(n_denom)
    return rep


def compute_report(
    results: list[CaseResult], wall_time_seconds: float, retries: int
) -> dict[str, Any]:
    n_total = len(results)
    in_scope = [r for r in results if r.expected_class != "abstain"]
    out_of_scope = [r for r in results if r.expected_class == "abstain"]
    n_in_scope = len(in_scope)
    n_out_of_scope = len(out_of_scope)

    matrix = build_confusion_matrix(results)
    per_class = per_class_precision_recall(matrix)

    in_scope_correct = sum(1 for r in in_scope if r.exact_match)
    in_scope_accuracy = in_scope_correct / n_in_scope if n_in_scope else None

    per_capability_exact: dict[str, dict[str, Any]] = {}
    for cap in ("app.install", "app.remove", "change.revert"):
        cap_cases = [r for r in in_scope if r.expected_class == cap]
        n = len(cap_cases)
        correct = sum(1 for r in cap_cases if r.exact_match)
        per_capability_exact[cap] = {
            "n": n,
            "correct": correct,
            "accuracy": correct / n if n else None,
        }

    cross_cap = [r for r in results if r.category == "cross_capability_confusion"]
    wrong_app = [r for r in results if r.category == "wrong_app"]
    abstain_on_in_scope = [r for r in results if r.category == "abstain_on_in_scope"]
    false_invoke = [r for r in results if r.category == "false_invoke_on_out_of_scope"]

    abstained = n_out_of_scope - len(false_invoke)
    out_of_scope_rate = abstained / n_out_of_scope if n_out_of_scope else None

    failures = [
        {
            "utterance": r.utterance,
            "expected_class": r.expected_class,
            "expected_params": r.expected_params,
            "predicted_class": r.predicted_class,
            "got_params": r.got_params,
            "category": r.category,
            "reason": r.reason,
        }
        for r in results
        if not r.exact_match
    ]

    return {
        "meta": {
            "n_cases": n_total,
            "n_in_scope": n_in_scope,
            "n_out_of_scope": n_out_of_scope,
            "wall_time_seconds": wall_time_seconds,
            "retries": retries,
        },
        "confusion_matrix": {"classes": list(CLASSES), "matrix": matrix},
        "per_class_precision_recall": per_class,
        "exact_match": {
            "in_scope_total": n_in_scope,
            "in_scope_correct": in_scope_correct,
            "in_scope_accuracy": in_scope_accuracy,
            "per_capability": per_capability_exact,
        },
        "cross_capability_confusion": _class_report(cross_cap, n_in_scope),
        "wrong_app": _class_report(wrong_app, n_in_scope),
        "abstain_on_in_scope_miss": _class_report(abstain_on_in_scope, n_in_scope),
        "out_of_scope_abstention": {
            "n": n_out_of_scope,
            "abstained": abstained,
            "rate": out_of_scope_rate,
            "false_invoke_count": len(false_invoke),
            "false_invoke_cases": [r.utterance for r in false_invoke],
            "rule_of_three_95_upper_bound": (
                rule_of_three_bound(n_out_of_scope) if len(false_invoke) == 0 else None
            ),
        },
        "failures": failures,
    }


def check_acceptance(report: dict[str, Any]) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    exact = report["exact_match"]["in_scope_accuracy"]
    if exact is None or exact < 0.98:
        reasons.append(f"in-scope exact-match accuracy {exact} < 0.98")
    cross = report["cross_capability_confusion"]["count"]
    if cross != 0:
        reasons.append(f"cross-capability confusions = {cross} (must be zero)")
    abst_rate = report["out_of_scope_abstention"]["rate"]
    if abst_rate is None or abst_rate < 0.95:
        reasons.append(f"out-of-scope abstention rate {abst_rate} < 0.95")
    return (len(reasons) == 0, reasons)


def is_infra_error(resolution: Resolution) -> bool:
    """An abstention caused by the model call itself failing (CLI error, timeout,
    session limit). Never a scoreable prediction.

    Keyed on the typed `infrastructure` field, not a string prefix on
    `reason`: `reason` can contain model-controlled content (an abstain
    reply's reason text), so a string-prefix check is spoofable by a model
    reply worded like "model call failed: ...".
    """
    return resolution.infrastructure


def resolve_with_backoff(
    case: Case,
    catalog: dict[str, CatalogApp],
    run_model: Callable[[str], str],
    sleep: Callable[[float], None] = time.sleep,
    log: Callable[[str], None] = print,
) -> tuple[Resolution, int]:
    """Resolve one case, retrying infra errors with exponential backoff.

    Returns (resolution, infra_retries). Raises EvalAbortedError if the CLI is
    still failing after the full backoff schedule.
    """
    resolution = resolve_utterance(case.utterance, catalog, run_model)
    if not is_infra_error(resolution):
        return resolution, 0
    for attempt, delay in enumerate(BACKOFF_SECONDS, start=1):
        log(
            f"  infrastructure error on {case.utterance!r} "
            f"(attempt {attempt}/{len(BACKOFF_SECONDS)}, backing off {delay:.0f}s): "
            f"{resolution.reason}"
        )
        sleep(delay)
        resolution = resolve_utterance(case.utterance, catalog, run_model)
        if not is_infra_error(resolution):
            return resolution, attempt
    raise EvalAbortedError(
        f"claude CLI still failing after {len(BACKOFF_SECONDS)} backoff retries "
        f"on {case.utterance!r}: {resolution.reason}"
    )


def load_progress(path: Path) -> list[CaseResult]:
    if not path.is_file():
        return []
    results: list[CaseResult] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        results.append(CaseResult(**json.loads(line)))
    return results


def append_progress(path: Path, result: CaseResult) -> None:
    with path.open("a") as f:
        f.write(json.dumps(asdict(result), sort_keys=True) + "\n")


def run_cases(
    cases: list[Case],
    catalog: dict[str, CatalogApp],
    run_model: Callable[[str], str],
    progress_every: int = 10,
    log: Callable[[str], None] = print,
    sleep: Callable[[float], None] = time.sleep,
    pace_seconds: float = 0.0,
    prior_results: list[CaseResult] | None = None,
    checkpoint: Callable[[CaseResult], None] | None = None,
) -> tuple[list[CaseResult], int]:
    """Run all not-yet-scored cases; returns (all results incl. prior, infra retries)."""
    results: list[CaseResult] = list(prior_results or [])
    done = {r.utterance for r in results}
    todo = [c for c in cases if c.utterance not in done]
    if done:
        log(f"resuming: {len(done)} cases already scored, {len(todo)} to go")
    total = len(cases)
    infra_retries = 0
    for i, case in enumerate(todo, start=len(done) + 1):
        if pace_seconds > 0 and i > len(done) + 1:
            sleep(pace_seconds)
        resolution, retries = resolve_with_backoff(case, catalog, run_model, sleep=sleep, log=log)
        infra_retries += retries
        result = score_case(case, resolution)
        results.append(result)
        if checkpoint is not None:
            checkpoint(result)
        if i % progress_every == 0 or i == total:
            correct = sum(1 for r in results if r.exact_match)
            n = len(results)
            log(f"[{i}/{total}] running exact-match accuracy: {correct}/{n} ({correct / n:.1%})")
    return results, infra_retries


def _pct(x: float | None) -> str:
    return "n/a" if x is None else f"{x:.1%}"


def format_summary(report: dict[str, Any]) -> str:
    meta = report["meta"]
    exact = report["exact_match"]
    cross = report["cross_capability_confusion"]
    wrong_app = report["wrong_app"]
    abstain_miss = report["abstain_on_in_scope_miss"]
    oos = report["out_of_scope_abstention"]
    pcr = report["per_class_precision_recall"]
    classes = report["confusion_matrix"]["classes"]
    matrix = report["confusion_matrix"]["matrix"]

    lines: list[str] = []
    lines.append("=" * 72)
    lines.append("RESOLVER EVAL SUMMARY")
    lines.append("=" * 72)
    lines.append(
        f"cases: {meta['n_cases']} total, {meta['n_in_scope']} in-scope, "
        f"{meta['n_out_of_scope']} out-of-scope"
    )
    lines.append(f"wall time: {meta['wall_time_seconds']:.1f}s   retries: {meta['retries']}")
    lines.append("")
    lines.append(
        f"IN-SCOPE EXACT MATCH: {exact['in_scope_correct']}/{exact['in_scope_total']} "
        f"({_pct(exact['in_scope_accuracy'])})  [bar: >= 98%]"
    )
    for cap, stats in exact["per_capability"].items():
        lines.append(
            f"  {cap:16s} {stats['correct']:3d}/{stats['n']:3d} ({_pct(stats['accuracy'])})"
        )
    lines.append("")

    cross_line = f"CROSS-CAPABILITY CONFUSIONS: {cross['count']}  [bar: == 0]"
    if cross["count"] == 0:
        cross_line += f"  (rule-of-3 upper bound: {cross['rule_of_three_95_upper_bound']:.4f})"
    lines.append(cross_line)
    for u in cross["cases"]:
        lines.append(f"    - {u}")

    wrong_line = f"WRONG-APP (right capability, wrong params): {wrong_app['count']}"
    if wrong_app["count"] == 0:
        wrong_line += f"  (rule-of-3 upper bound: {wrong_app['rule_of_three_95_upper_bound']:.4f})"
    lines.append(wrong_line)
    for u in wrong_app["cases"]:
        lines.append(f"    - {u}")

    lines.append(f"ABSTAIN-ON-IN-SCOPE MISSES: {abstain_miss['count']}")
    for u in abstain_miss["cases"]:
        lines.append(f"    - {u}")
    lines.append("")

    oos_line = f"OUT-OF-SCOPE ABSTENTION RATE: {oos['abstained']}/{oos['n']} ({_pct(oos['rate'])})  [bar: >= 95%]"
    lines.append(oos_line)
    if oos["false_invoke_count"] == 0:
        lines.append(
            f"  (rule-of-3 upper bound on false-invoke rate: "
            f"{oos['rule_of_three_95_upper_bound']:.4f})"
        )
    else:
        lines.append(f"  false invokes ({oos['false_invoke_count']}): {oos['false_invoke_cases']}")
    lines.append("")

    lines.append("CONFUSION MATRIX (rows = predicted, cols = expected)")
    header = "predicted\\expected".ljust(20) + "".join(c.ljust(16) for c in classes)
    lines.append(header)
    for p in classes:
        row = p.ljust(20) + "".join(str(matrix[p][e]).ljust(16) for e in classes)
        lines.append(row)
    lines.append("")

    lines.append("PER-CLASS PRECISION/RECALL")
    for c in classes:
        stats = pcr[c]
        lines.append(
            f"  {c:16s} precision={_pct(stats['precision'])}  recall={_pct(stats['recall'])}  "
            f"(n_actual={stats['actual_total']}, n_predicted={stats['predicted_total']})"
        )
    lines.append("=" * 72)
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Run the resolver eval suite against live claude -p calls."
    )
    parser.add_argument("--cases", type=Path, default=CASES_PATH)
    parser.add_argument("--out", type=Path, default=REPORT_PATH)
    parser.add_argument("--progress-every", type=int, default=10)
    parser.add_argument(
        "--pace",
        type=float,
        default=3.0,
        help="Seconds to sleep between calls (gentle on the shared subscription).",
    )
    parser.add_argument(
        "--only-utterances",
        type=Path,
        default=None,
        help="Path to a newline-delimited file of utterances; restricts the run to "
        "cases whose utterance appears in it (for cheap re-runs of failed classes).",
    )
    args = parser.parse_args(argv)

    catalog = load_catalog()
    cases = load_cases(args.cases)
    if args.only_utterances is not None:
        wanted = {
            line.strip() for line in args.only_utterances.read_text().splitlines() if line.strip()
        }
        cases = [c for c in cases if c.utterance in wanted]
        print(f"restricted to {len(cases)} cases from {args.only_utterances}")
    print(f"loaded {len(cases)} cases from {args.cases}")

    prior = load_progress(PROGRESS_PATH)
    start = time.monotonic()
    try:
        results, infra_retries = run_cases(
            cases,
            catalog,
            run_claude,
            progress_every=args.progress_every,
            log=print,
            pace_seconds=args.pace,
            prior_results=prior,
            checkpoint=lambda r: append_progress(PROGRESS_PATH, r),
        )
    except EvalAbortedError as exc:
        wall_time = time.monotonic() - start
        scored = len(load_progress(PROGRESS_PATH))
        PARTIAL_REPORT_PATH.write_text(
            json.dumps(
                {
                    "aborted": True,
                    "reason": str(exc),
                    "cases_scored": scored,
                    "cases_total": len(cases),
                    "wall_time_seconds": wall_time,
                    "note": "NOT results. Scored cases are checkpointed in "
                    "progress.jsonl; rerun run_eval.py to resume.",
                },
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )
        print()
        print(f"RUN ABORTED: {exc}")
        print(f"{scored}/{len(cases)} cases scored; checkpoint kept in {PROGRESS_PATH}")
        print(f"wrote {PARTIAL_REPORT_PATH} (no report.json: partial data is not results)")
        return 2
    wall_time = time.monotonic() - start

    report = compute_report(results, wall_time_seconds=wall_time, retries=infra_retries)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print()
    print(format_summary(report))

    passed, reasons = check_acceptance(report)
    print()
    if passed:
        print("ACCEPTANCE: PASS")
    else:
        print("ACCEPTANCE: FAIL")
        for reason in reasons:
            print(f"  - {reason}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
