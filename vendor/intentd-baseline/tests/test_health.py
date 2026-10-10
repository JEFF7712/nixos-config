import subprocess
from typing import Any

import pytest

import intentd.health as health_module
from intentd.health import failed_units, new_failures, parse_failed_units


def test_parse_failed_units_extracts_unit_names():
    raw = (
        '[{"unit": "foo.service", "load": "loaded", "active": "failed",'
        ' "sub": "failed", "description": "Foo"},'
        ' {"unit": "bar.service", "load": "loaded", "active": "failed",'
        ' "sub": "failed", "description": "Bar"}]'
    )
    assert parse_failed_units(raw) == frozenset({"foo.service", "bar.service"})


def test_parse_empty_list():
    assert parse_failed_units("[]") == frozenset()


def test_parse_rejects_garbage():
    import pytest

    from intentd.health import HealthError

    with pytest.raises(HealthError):
        parse_failed_units("not json")
    with pytest.raises(HealthError):
        parse_failed_units('[{"no_unit_key": true}]')


def test_new_failures_is_baseline_relative():
    before = frozenset({"already-broken.service"})
    after = frozenset({"already-broken.service", "fresh-break.service"})
    assert new_failures(before, after) == frozenset({"fresh-break.service"})


def test_recovered_units_are_not_failures():
    before = frozenset({"was-broken.service"})
    after: frozenset[str] = frozenset()
    assert new_failures(before, after) == frozenset()


def test_failed_units_uses_bounded_systemctl_call(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[list[str], int]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, int(kwargs["timeout"])))
        return subprocess.CompletedProcess(args, 0, "[]", "")

    monkeypatch.setattr(health_module.subprocess, "run", fake_run)

    assert failed_units() == frozenset()
    assert calls == [(["systemctl", "list-units", "--failed", "--output=json"], 10)]
