import os
import re
import subprocess
from enum import StrEnum
from pathlib import Path
from typing import Literal

import pydantic
from pydantic import Field

from intentd.executor import file_sha256
from intentd.health import failed_units
from intentd.machine import MachineProfile
from intentd.schema import ClosedModel
from intentd.state import DesiredState

COMMAND_TIMEOUT_SECONDS = 10
SHA256_PATTERN = r"^[0-9a-f]{64}$"


class BootError(Exception):
    pass


class BootArtifact(ClosedModel):
    closure_path: str
    entry_id: str
    uki_path: str
    uki_sha256: str = Field(pattern=SHA256_PATTERN)
    uki_size_bytes: int = Field(gt=0)
    gc_root: str


class HealthSnapshot(ClosedModel):
    failed_units: tuple[str, ...]
    inactive_critical_units: tuple[str, ...]
    display_ready: bool
    root_free_bytes: int = Field(ge=0)
    esp_free_bytes: int = Field(ge=0)


class BootPlan(ClosedModel):
    candidate: BootArtifact
    prior_blessed: BootArtifact
    recovery: BootArtifact
    baseline: HealthSnapshot
    invocation_hash: str = Field(pattern=SHA256_PATTERN)
    machine_profile_id: str
    root_reserve_bytes: int = Field(gt=0)
    esp_reserve_bytes: int = Field(gt=0)
    rendered_hash: str = Field(pattern=SHA256_PATTERN)
    flake_lock_hash: str = Field(pattern=SHA256_PATTERN)


class BootObservation(ClosedModel):
    closure_path: str
    entry_id: str
    entry_path: str


class BootBaseline(ClosedModel):
    artifact: BootArtifact
    observation: BootObservation
    health: HealthSnapshot
    machine_profile: MachineProfile
    state: DesiredState
    catalog_hash: str = Field(pattern=SHA256_PATTERN)
    flake_lock_hash: str = Field(pattern=SHA256_PATTERN)
    nv_counter: Literal[1] = 1

    @pydantic.model_validator(mode="after")
    def _check_evidence(self) -> "BootBaseline":
        if (
            self.observation.closure_path != self.artifact.closure_path
            or self.observation.entry_id != self.artifact.entry_id
            or not entry_path_matches(self.artifact.entry_id, self.observation.entry_path)
        ):
            raise ValueError("baseline observation does not match artifact")
        if self.artifact.uki_path != self.observation.entry_path:
            raise ValueError("baseline artifact must identify the observed UKI")
        if not self.machine_profile.certified:
            raise ValueError("baseline requires an admitted machine profile")
        if self.health.inactive_critical_units or not self.health.display_ready:
            raise ValueError("baseline requires active critical units and a ready display")
        if self.health.root_free_bytes < self.machine_profile.root_reserve_bytes:
            raise ValueError("baseline root free space is below the reserve")
        if self.health.esp_free_bytes < self.machine_profile.esp_reserve_bytes:
            raise ValueError("baseline ESP free space is below the reserve")
        return self


class BootOutcome(ClosedModel):
    healthy: bool
    recovered: bool
    quarantined: bool
    observation: BootObservation
    health: HealthSnapshot
    failures: tuple[str, ...]


class BootStagingPhase(StrEnum):
    SET_PROFILE = "set-profile"
    INSTALL_CANDIDATE = "install-candidate"


class BootStagingFailure(ClosedModel):
    candidate: BootArtifact
    phase: BootStagingPhase
    detail: str = Field(min_length=1)
    quarantined: Literal[True] = True


class BootEntry(ClosedModel):
    entry_id: str
    entry_path: str


class _BootctlEntry(ClosedModel):
    model_config = pydantic.ConfigDict(extra="ignore", frozen=True)

    entry_id: str = Field(validation_alias="id")
    entry_path: str = Field(validation_alias="path")
    is_selected: bool = Field(validation_alias="isSelected")


_bootctl_adapter = pydantic.TypeAdapter(list[_BootctlEntry])


def parse_bootctl_list(raw: str) -> BootEntry:
    try:
        entries = _bootctl_adapter.validate_json(raw)
    except pydantic.ValidationError as exc:
        raise BootError(f"unparseable bootctl output: {exc}") from exc
    selected = [entry for entry in entries if entry.is_selected]
    if len(selected) != 1:
        raise BootError(f"expected one selected boot entry, found {len(selected)}")
    entry = selected[0]
    return BootEntry(entry_id=entry.entry_id, entry_path=entry.entry_path)


def _entry_filename_matches(entry_id: str, filename: str) -> bool:
    if not entry_id.endswith(".efi") or Path(entry_id).name != entry_id:
        return False
    stem = re.escape(entry_id.removesuffix(".efi"))
    return re.fullmatch(rf"{stem}(?:\+[0-9]+(?:-[0-9]+)?)?\.efi", filename) is not None


def entry_path_matches(entry_id: str, entry_path: str) -> bool:
    path = Path(entry_path)
    if path.parent != Path("/boot/EFI/Linux") or path.name != entry_path.rsplit("/", 1)[-1]:
        return False
    return _entry_filename_matches(entry_id, path.name)


def _resolve_uki_path(artifact: BootArtifact) -> Path:
    stored = Path(artifact.uki_path)
    if stored.is_file():
        return stored
    try:
        aliases = [
            path
            for path in stored.parent.iterdir()
            if path.is_file() and _entry_filename_matches(artifact.entry_id, path.name)
        ]
    except OSError:
        aliases = []
    if len(aliases) == 1:
        return aliases[0]
    if len(aliases) > 1:
        raise BootError(f"ambiguous UKI artifact aliases: {artifact.uki_path}")
    raise BootError(f"missing UKI artifact: {artifact.uki_path}")


def observe_boot(
    current_system: Path = Path("/run/current-system"),
) -> BootObservation:
    try:
        result = subprocess.run(
            ["bootctl", "list", "--json=short"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise BootError(f"bootctl could not inspect the current boot: {exc}") from exc
    if result.returncode != 0:
        raise BootError(f"bootctl failed with exit {result.returncode}: {result.stderr.strip()}")
    entry = parse_bootctl_list(result.stdout)
    try:
        closure_path = str(current_system.resolve(strict=True))
    except OSError as exc:
        raise BootError(f"current system closure is unavailable: {exc}") from exc
    return BootObservation(
        closure_path=closure_path,
        entry_id=entry.entry_id,
        entry_path=entry.entry_path,
    )


def verify_artifact(artifact: BootArtifact) -> None:
    uki_path = _resolve_uki_path(artifact)
    if uki_path.stat().st_size != artifact.uki_size_bytes:
        raise BootError(f"UKI size does not match artifact: {artifact.uki_path}")
    if file_sha256(uki_path) != artifact.uki_sha256:
        raise BootError(f"UKI hash does not match artifact: {artifact.uki_path}")

    closure_path = Path(artifact.closure_path)
    if not closure_path.exists():
        raise BootError(f"missing closure artifact: {artifact.closure_path}")
    gc_root = Path(artifact.gc_root)
    if not gc_root.is_symlink():
        raise BootError(f"missing GC root artifact: {artifact.gc_root}")
    if gc_root.resolve() != closure_path.resolve():
        raise BootError(f"GC root does not match closure: {artifact.gc_root}")


def capture_health(machine_profile: MachineProfile) -> HealthSnapshot:
    inactive: list[str] = []
    for unit in machine_profile.critical_units:
        try:
            result = subprocess.run(
                ["systemctl", "is-active", unit],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=COMMAND_TIMEOUT_SECONDS,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise BootError(f"systemctl could not inspect {unit}: {exc}") from exc
        if result.returncode != 0:
            inactive.append(unit)

    root_filesystem = os.statvfs("/")
    esp_filesystem = os.statvfs("/boot")
    return HealthSnapshot(
        failed_units=tuple(sorted(failed_units())),
        inactive_critical_units=tuple(inactive),
        display_ready=machine_profile.display_unit not in inactive,
        root_free_bytes=root_filesystem.f_bavail * root_filesystem.f_frsize,
        esp_free_bytes=esp_filesystem.f_bavail * esp_filesystem.f_frsize,
    )


def evaluate_boot_health(
    plan: BootPlan,
    observation: BootObservation,
    current: HealthSnapshot,
) -> BootOutcome:
    failures: list[str] = []
    candidate = plan.candidate
    if observation.closure_path != candidate.closure_path:
        failures.append("booted closure does not match candidate")
    if observation.entry_id != candidate.entry_id:
        failures.append("boot entry ID does not match candidate")
    if not entry_path_matches(candidate.entry_id, observation.entry_path):
        failures.append("boot entry path does not match candidate")

    baseline_failed = set(plan.baseline.failed_units)
    for unit in sorted(set(current.failed_units) - baseline_failed):
        failures.append(f"new failed unit: {unit}")
    for unit in sorted(set(current.inactive_critical_units)):
        failures.append(f"inactive critical unit: {unit}")
    if not current.display_ready:
        failures.append("display is not ready")
    if current.root_free_bytes < plan.root_reserve_bytes:
        failures.append("root free space is below the authenticated reserve")
    if current.esp_free_bytes < plan.esp_reserve_bytes:
        failures.append("ESP free space is below the authenticated reserve")

    healthy = not failures
    return BootOutcome(
        healthy=healthy,
        recovered=False,
        quarantined=not healthy,
        observation=observation,
        health=current,
        failures=tuple(failures),
    )
