import json
from pathlib import Path
from typing import Any, Literal

import pydantic
import pytest
from pydantic import Field

from intentd.catalog import load_catalog
from intentd.registry import InvocationError, resolve_invocation
from intentd.schema import CatalogApp, ClosedModel

CASES_PATH = Path(__file__).resolve().parents[1] / "eval" / "resolver_suite" / "cases.jsonl"

MIN_TOTAL = 120
MIN_PER_CLASS = 30


class ExpectedInvoke(ClosedModel):
    action: Literal["invoke"]
    capability: str
    params: dict[str, Any] = Field(default_factory=dict)


class ExpectedAbstain(ClosedModel):
    action: Literal["abstain"]


class EvalCase(ClosedModel):
    utterance: str
    expected: ExpectedInvoke | ExpectedAbstain = Field(discriminator="action")


def _raw_lines() -> list[str]:
    text = CASES_PATH.read_text()
    return [line for line in text.splitlines() if line.strip()]


@pytest.fixture(scope="module")
def catalog() -> dict[str, CatalogApp]:
    return load_catalog()


@pytest.fixture(scope="module")
def cases() -> list[EvalCase]:
    parsed: list[EvalCase] = []
    for i, line in enumerate(_raw_lines()):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as exc:
            pytest.fail(f"line {i + 1}: invalid JSON: {exc}")
        try:
            parsed.append(EvalCase.model_validate(obj))
        except pydantic.ValidationError as exc:
            pytest.fail(f"line {i + 1}: does not match case schema: {exc}")
    return parsed


def _class_of(case: EvalCase) -> str:
    if isinstance(case.expected, ExpectedAbstain):
        return "abstain"
    return case.expected.capability


def test_cases_file_exists():
    assert CASES_PATH.is_file(), f"missing corpus: {CASES_PATH}"


def test_every_line_parses_as_case_schema(cases: list[EvalCase]):
    assert len(cases) > 0


def test_minimum_total_cases(cases: list[EvalCase]):
    assert len(cases) >= MIN_TOTAL, f"expected >= {MIN_TOTAL} cases, got {len(cases)}"


def test_no_duplicate_utterances(cases: list[EvalCase]):
    seen: dict[str, int] = {}
    dupes: list[str] = []
    for case in cases:
        seen[case.utterance] = seen.get(case.utterance, 0) + 1
    dupes = [u for u, n in seen.items() if n > 1]
    assert not dupes, f"duplicate utterances: {dupes}"


def test_distribution_floors(cases: list[EvalCase]):
    counts: dict[str, int] = {}
    for case in cases:
        cls = _class_of(case)
        counts[cls] = counts.get(cls, 0) + 1
    for expected_class in ("app.install", "app.remove", "change.revert", "abstain"):
        assert counts.get(expected_class, 0) >= MIN_PER_CLASS, (
            f"{expected_class}: expected >= {MIN_PER_CLASS}, got {counts.get(expected_class, 0)}"
        )


def test_invoke_labels_reference_real_capabilities_and_resolve(
    cases: list[EvalCase], catalog: dict[str, CatalogApp]
):
    for case in cases:
        if not isinstance(case.expected, ExpectedInvoke):
            continue
        try:
            resolve_invocation(catalog, case.expected.capability, case.expected.params)
        except InvocationError as exc:
            pytest.fail(
                f"utterance {case.utterance!r}: expected invocation does not resolve "
                f"against the real registry/catalog: {exc}"
            )


def test_abstain_cases_have_no_extra_fields(cases: list[EvalCase]):
    # Enforced by the closed EvalCase/ExpectedAbstain schema at parse time;
    # this test documents the intent so a schema change is caught here too.
    for case in cases:
        if isinstance(case.expected, ExpectedAbstain):
            assert case.expected.model_dump() == {"action": "abstain"}
