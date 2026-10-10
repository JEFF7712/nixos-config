import subprocess

import pydantic

from intentd.schema import ClosedModel


class HealthError(Exception):
    pass


class _FailedUnit(ClosedModel):
    model_config = pydantic.ConfigDict(extra="ignore", frozen=True)

    unit: str


_units_adapter = pydantic.TypeAdapter(list[_FailedUnit])


def parse_failed_units(raw: str) -> frozenset[str]:
    try:
        units = _units_adapter.validate_json(raw)
    except pydantic.ValidationError as exc:
        raise HealthError(f"unparseable systemctl output: {exc}") from exc
    return frozenset(u.unit for u in units)


def failed_units() -> frozenset[str]:
    result = subprocess.run(
        ["systemctl", "list-units", "--failed", "--output=json"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=10,
    )
    if result.returncode != 0:
        raise HealthError(
            f"systemctl failed with exit {result.returncode}: {result.stderr.strip()}"
        )
    return parse_failed_units(result.stdout)


def new_failures(before: frozenset[str], after: frozenset[str]) -> frozenset[str]:
    return after - before
