import json
from pathlib import Path
from types import SimpleNamespace

import pydantic
import pytest

from intentd.machine import GraphicsBackend, MachineProfile, load_machine_profile


def root_owned_stat(_path: Path) -> SimpleNamespace:
    return SimpleNamespace(st_uid=0)


def profile_data() -> dict[str, object]:
    return {
        "profile_id": "intentd-vm-v1",
        "certified": True,
        "graphics_backend": "intentd-vm",
        "intel_pci": "0000:00:02.0",
        "nvidia_pci": "0000:01:00.0",
        "critical_units": ["intentd-display-ready.service"],
        "display_unit": "intentd-display-ready.service",
        "root_reserve_bytes": 268_435_456,
        "esp_reserve_bytes": 134_217_728,
    }


def test_machine_profile_is_closed() -> None:
    with pytest.raises(pydantic.ValidationError):
        MachineProfile.model_validate(profile_data() | {"kernel_parameter": "init=/bin/sh"})


def test_machine_profile_rejects_unsupported_profile_id() -> None:
    with pytest.raises(pydantic.ValidationError, match="unsupported machine profile"):
        MachineProfile.model_validate(profile_data() | {"profile_id": "unknown-v1"})


@pytest.mark.parametrize(
    ("field", "value"),
    [("intel_pci", "0000:00:03.0"), ("nvidia_pci", "0000:02:00.0")],
)
def test_machine_profile_rejects_wrong_pci_address(field: str, value: str) -> None:
    with pytest.raises(pydantic.ValidationError, match="PCI address"):
        MachineProfile.model_validate(profile_data() | {field: value})


def test_certified_vm_profile_is_accepted() -> None:
    profile = MachineProfile.model_validate(profile_data())
    assert profile.profile_id == "intentd-vm-v1"
    assert profile.certified is True
    assert profile.graphics_backend is GraphicsBackend.INTENTD_VM


@pytest.mark.parametrize(
    ("field", "message"),
    [
        ("root_reserve_bytes", "root reserve"),
        ("esp_reserve_bytes", "ESP reserve"),
    ],
)
def test_machine_profile_requires_positive_capacity_reserves(field: str, message: str) -> None:
    with pytest.raises(pydantic.ValidationError, match=message):
        MachineProfile.model_validate(profile_data() | {field: 0})


def test_load_machine_profile_requires_root_owner(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "machine-profile.json"
    path.write_text(json.dumps(profile_data()))

    with pytest.raises(PermissionError, match="root-owned"):
        load_machine_profile(path)

    monkeypatch.setattr(Path, "stat", root_owned_stat)
    assert load_machine_profile(path).profile_id == "intentd-vm-v1"


def test_load_machine_profile_rejects_uncertified_profile(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "machine-profile.json"
    path.write_text(json.dumps(profile_data() | {"certified": False}))
    monkeypatch.setattr(Path, "stat", root_owned_stat)

    with pytest.raises(ValueError, match="is not certified"):
        load_machine_profile(path)
