import hashlib
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

import intentd.boot as boot_module
from intentd.boot import (
    BootArtifact,
    BootError,
    BootObservation,
    BootPlan,
    HealthSnapshot,
    capture_health,
    entry_path_matches,
    evaluate_boot_health,
    observe_boot,
    parse_bootctl_list,
    verify_artifact,
)
from tests.helpers import vm_machine_profile

HASH_A = "a" * 64
HASH_B = "b" * 64
HASH_C = "c" * 64


def boot_plan_fixture() -> BootPlan:
    return BootPlan(
        candidate=BootArtifact(
            closure_path="/nix/store/candidate",
            entry_id="candidate.efi",
            uki_path="/boot/EFI/Linux/candidate.efi",
            uki_sha256=HASH_A,
            uki_size_bytes=4096,
            gc_root="/var/lib/intentd/gcroots/candidate",
        ),
        prior_blessed=BootArtifact(
            closure_path="/nix/store/blessed",
            entry_id="blessed.efi",
            uki_path="/boot/EFI/Linux/blessed.efi",
            uki_sha256=HASH_B,
            uki_size_bytes=4096,
            gc_root="/var/lib/intentd/gcroots/blessed",
        ),
        recovery=BootArtifact(
            closure_path="/nix/store/recovery",
            entry_id="recovery.efi",
            uki_path="/boot/EFI/Linux/recovery.efi",
            uki_sha256=HASH_C,
            uki_size_bytes=4096,
            gc_root="/var/lib/intentd/gcroots/recovery",
        ),
        baseline=HealthSnapshot(
            failed_units=(),
            inactive_critical_units=(),
            display_ready=True,
            root_free_bytes=536_870_912,
            esp_free_bytes=268_435_456,
        ),
        machine_profile_id="intentd-vm-v1",
        invocation_hash="f" * 64,
        root_reserve_bytes=268_435_456,
        esp_reserve_bytes=134_217_728,
        rendered_hash=HASH_A,
        flake_lock_hash=HASH_B,
    )


def candidate_observation() -> BootObservation:
    return BootObservation(
        closure_path="/nix/store/candidate",
        entry_id="candidate.efi",
        entry_path="/boot/EFI/Linux/candidate.efi",
    )


def healthy_snapshot() -> HealthSnapshot:
    return HealthSnapshot(
        failed_units=(),
        inactive_critical_units=(),
        display_ready=True,
        root_free_bytes=536_870_912,
        esp_free_bytes=268_435_456,
    )


def materialized_artifact(tmp_path: Path) -> BootArtifact:
    content = b"candidate"
    uki = tmp_path / "candidate.efi"
    uki.write_bytes(content)
    closure = tmp_path / "closure"
    closure.mkdir()
    gc_root = tmp_path / "candidate-root"
    gc_root.symlink_to(closure)
    return boot_plan_fixture().candidate.model_copy(
        update={
            "closure_path": str(closure),
            "uki_path": str(uki),
            "uki_sha256": hashlib.sha256(content).hexdigest(),
            "uki_size_bytes": len(content),
            "gc_root": str(gc_root),
        }
    )


def test_parse_bootctl_selects_exactly_one_current_entry() -> None:
    raw = json.dumps(
        [
            {
                "id": "old.efi",
                "path": "/boot/EFI/Linux/old.efi",
                "isSelected": False,
            },
            {
                "id": "new.efi",
                "path": "/boot/EFI/Linux/new+0-1.efi",
                "isSelected": True,
            },
        ]
    )
    assert parse_bootctl_list(raw).entry_id == "new.efi"


@pytest.mark.parametrize(
    "path",
    [
        "/boot/EFI/Linux/candidate.efi",
        "/boot/EFI/Linux/candidate+1.efi",
        "/boot/EFI/Linux/candidate+0-1.efi",
        "/boot/EFI/Linux/candidate+3-2.efi",
    ],
)
def test_entry_path_accepts_only_boot_count_renames(path: str) -> None:
    assert entry_path_matches("candidate.efi", path)


@pytest.mark.parametrize(
    "path",
    [
        "/boot/EFI/Linux/other+0-1.efi",
        "/boot/EFI/Linux/candidate+bad.efi",
        "/boot/EFI/Linux/candidate+0-1.efi/../other.efi",
        "/tmp/candidate+0-1.efi",
    ],
)
def test_entry_path_rejects_other_entries_and_locations(path: str) -> None:
    assert not entry_path_matches("candidate.efi", path)


@pytest.mark.parametrize(
    "raw",
    [
        json.dumps(
            [
                {"id": "one.efi", "path": "/one.efi", "isSelected": True},
                {"id": "two.efi", "path": "/two.efi", "isSelected": True},
            ]
        ),
        json.dumps([{"id": "one.efi", "path": "/one.efi", "isSelected": False}]),
        "not json",
    ],
)
def test_parse_bootctl_rejects_ambiguous_or_malformed_input(raw: str) -> None:
    with pytest.raises(BootError):
        parse_bootctl_list(raw)


def test_observe_boot_binds_selected_entry_to_current_closure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    closure = tmp_path / "candidate"
    closure.mkdir()
    current_system = tmp_path / "current-system"
    current_system.symlink_to(closure)
    raw = json.dumps(
        [
            {
                "id": "candidate.efi",
                "path": "/boot/EFI/Linux/candidate.efi",
                "isSelected": True,
            }
        ]
    )
    calls: list[tuple[list[str], int]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, int(kwargs["timeout"])))
        return subprocess.CompletedProcess(args, 0, raw, "")

    monkeypatch.setattr(boot_module.subprocess, "run", fake_run)

    observation = observe_boot(current_system=current_system)

    assert observation.closure_path == str(closure)
    assert observation.entry_id == "candidate.efi"
    assert calls == [(["bootctl", "list", "--json=short"], 10)]


def test_verify_artifact_rejects_uki_hash_mismatch(tmp_path: Path) -> None:
    uki = tmp_path / "candidate.efi"
    uki.write_bytes(b"candidate")
    closure = tmp_path / "closure"
    closure.mkdir()
    gc_root = tmp_path / "candidate-root"
    gc_root.symlink_to(closure)
    artifact = boot_plan_fixture().candidate.model_copy(
        update={
            "closure_path": str(closure),
            "uki_path": str(uki),
            "uki_sha256": "0" * 64,
            "uki_size_bytes": len(b"candidate"),
            "gc_root": str(gc_root),
        }
    )

    with pytest.raises(BootError, match="UKI hash"):
        verify_artifact(artifact)


@pytest.mark.parametrize("artifact_name", ["prior_blessed", "recovery"])
def test_verify_artifact_rejects_missing_prior_or_recovery_artifact(
    artifact_name: str, tmp_path: Path
) -> None:
    artifact = getattr(boot_plan_fixture(), artifact_name).model_copy(
        update={
            "closure_path": str(tmp_path / "missing-closure"),
            "uki_path": str(tmp_path / "missing.efi"),
            "gc_root": str(tmp_path / "missing-root"),
        }
    )

    with pytest.raises(BootError, match="missing"):
        verify_artifact(artifact)


def test_verify_artifact_accepts_matching_uki_and_gc_root(tmp_path: Path) -> None:
    verify_artifact(materialized_artifact(tmp_path))


def test_verify_artifact_accepts_authenticated_boot_count_rename(tmp_path: Path) -> None:
    artifact = materialized_artifact(tmp_path)
    counted = tmp_path / "candidate+1.efi"
    Path(artifact.uki_path).replace(counted)
    renamed = artifact.model_copy(update={"uki_path": str(counted)})
    counted.replace(tmp_path / "candidate.efi")

    verify_artifact(renamed)


def test_verify_artifact_rejects_uki_size_mismatch(tmp_path: Path) -> None:
    artifact = materialized_artifact(tmp_path).model_copy(update={"uki_size_bytes": 1})

    with pytest.raises(BootError, match="UKI size"):
        verify_artifact(artifact)


def test_capture_health_uses_profile_units_and_filesystem_capacity(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    profile = vm_machine_profile()
    calls: list[tuple[list[str], int]] = []

    def fake_run(args: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append((args, int(kwargs["timeout"])))
        return subprocess.CompletedProcess(args, 0, "active\n", "")

    def no_failed_units() -> frozenset[str]:
        return frozenset()

    paths: list[str] = []

    def fake_statvfs(path: str) -> SimpleNamespace:
        paths.append(path)
        available = 1024 if path == "/" else 512
        return SimpleNamespace(f_bavail=available, f_frsize=4096)

    monkeypatch.setattr(boot_module, "failed_units", no_failed_units)
    monkeypatch.setattr(boot_module.subprocess, "run", fake_run)
    monkeypatch.setattr(boot_module.os, "statvfs", fake_statvfs)

    snapshot = capture_health(profile)

    assert snapshot == HealthSnapshot(
        failed_units=(),
        inactive_critical_units=(),
        display_ready=True,
        root_free_bytes=4_194_304,
        esp_free_bytes=2_097_152,
    )
    assert paths == ["/", "/boot"]
    assert calls == [(["systemctl", "is-active", "intentd-display-ready.service"], 10)]


def test_health_rejects_identity_mismatch() -> None:
    decision = evaluate_boot_health(
        plan=boot_plan_fixture(),
        observation=candidate_observation().model_copy(update={"closure_path": "/nix/store/wrong"}),
        current=healthy_snapshot(),
    )
    assert decision.healthy is False
    assert decision.failures == ("booted closure does not match candidate",)


@pytest.mark.parametrize(
    ("current", "expected"),
    [
        (
            healthy_snapshot().model_copy(update={"failed_units": ("fresh-break.service",)}),
            ("new failed unit: fresh-break.service",),
        ),
        (
            healthy_snapshot().model_copy(
                update={"inactive_critical_units": ("critical.service",)}
            ),
            ("inactive critical unit: critical.service",),
        ),
        (
            healthy_snapshot().model_copy(update={"display_ready": False}),
            ("display is not ready",),
        ),
        (
            healthy_snapshot().model_copy(update={"root_free_bytes": 268_435_455}),
            ("root free space is below the authenticated reserve",),
        ),
        (
            healthy_snapshot().model_copy(update={"esp_free_bytes": 134_217_727}),
            ("ESP free space is below the authenticated reserve",),
        ),
    ],
)
def test_health_rejects_regressions(current: HealthSnapshot, expected: tuple[str, ...]) -> None:
    decision = evaluate_boot_health(
        plan=boot_plan_fixture(),
        observation=candidate_observation(),
        current=current,
    )
    assert decision.healthy is False
    assert decision.failures == expected


def test_health_accepts_exact_candidate_and_baseline() -> None:
    decision = evaluate_boot_health(
        plan=boot_plan_fixture(),
        observation=candidate_observation(),
        current=healthy_snapshot(),
    )
    assert decision.healthy is True
    assert decision.recovered is False
    assert decision.quarantined is False
    assert decision.failures == ()


def test_health_accepts_candidate_after_boot_count_rename() -> None:
    observation = candidate_observation().model_copy(
        update={"entry_path": "/boot/EFI/Linux/candidate+0-1.efi"}
    )

    decision = evaluate_boot_health(
        plan=boot_plan_fixture(), observation=observation, current=healthy_snapshot()
    )

    assert decision.healthy is True


def test_health_uses_authenticated_reserves_not_raw_capacity_baseline() -> None:
    plan = boot_plan_fixture().model_copy(
        update={
            "baseline": healthy_snapshot().model_copy(
                update={
                    "root_free_bytes": 1_000_000_000,
                    "esp_free_bytes": 500_000_000,
                }
            )
        }
    )
    current = healthy_snapshot().model_copy(
        update={"root_free_bytes": 300_000_000, "esp_free_bytes": 150_000_000}
    )

    assert evaluate_boot_health(plan, candidate_observation(), current).healthy is True


def test_boot_artifact_requires_positive_uki_size() -> None:
    artifact = boot_plan_fixture().candidate
    with pytest.raises(ValueError):
        BootArtifact.model_validate(artifact.model_copy(update={"uki_size_bytes": 0}).model_dump())


def test_network_and_model_are_not_health_inputs() -> None:
    assert "network" not in HealthSnapshot.model_fields
    assert "model" not in HealthSnapshot.model_fields


def test_boot_hashes_require_64_lowercase_hexadecimal_characters() -> None:
    with pytest.raises(ValueError):
        boot_plan_fixture().model_copy(update={"rendered_hash": "A" * 64}).model_validate(
            boot_plan_fixture().model_copy(update={"rendered_hash": "A" * 64}).model_dump()
        )
