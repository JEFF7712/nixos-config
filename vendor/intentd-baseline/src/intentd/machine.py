from enum import StrEnum
from pathlib import Path

from pydantic import model_validator

from intentd.schema import ClosedModel, GraphicsProfile

INTEL_PCI_ADDRESS = "0000:00:02.0"
NVIDIA_PCI_ADDRESS = "0000:01:00.0"

__all__ = [
    "GraphicsBackend",
    "GraphicsProfile",
    "INTEL_PCI_ADDRESS",
    "MachineProfile",
    "NVIDIA_PCI_ADDRESS",
    "load_machine_profile",
]


class GraphicsBackend(StrEnum):
    INTENTD_VM = "intentd-vm"
    UX3404VC = "ux3404vc"


class MachineProfile(ClosedModel):
    profile_id: str
    certified: bool
    graphics_backend: GraphicsBackend
    intel_pci: str
    nvidia_pci: str | None
    critical_units: tuple[str, ...]
    display_unit: str
    root_reserve_bytes: int
    esp_reserve_bytes: int

    @model_validator(mode="after")
    def _check_certified_facts(self) -> "MachineProfile":
        expected_backends = {
            "intentd-vm-v1": GraphicsBackend.INTENTD_VM,
            "ux3404vc-v1": GraphicsBackend.UX3404VC,
        }
        expected_backend = expected_backends.get(self.profile_id)
        if expected_backend is None:
            raise ValueError(f"unsupported machine profile: {self.profile_id!r}")
        if self.graphics_backend is not expected_backend:
            raise ValueError("machine profile ID does not match graphics backend")
        if self.intel_pci != INTEL_PCI_ADDRESS:
            raise ValueError("unexpected Intel PCI address")
        if self.nvidia_pci != NVIDIA_PCI_ADDRESS:
            raise ValueError("unexpected NVIDIA PCI address")
        if not self.critical_units or self.display_unit not in self.critical_units:
            raise ValueError("display unit must be a critical unit")
        if self.root_reserve_bytes <= 0:
            raise ValueError("root reserve must be positive")
        if self.esp_reserve_bytes <= 0:
            raise ValueError("ESP reserve must be positive")
        return self


def load_machine_profile(path: Path) -> MachineProfile:
    if path.stat().st_uid != 0:
        raise PermissionError(f"machine profile {path} must be root-owned")
    profile = MachineProfile.model_validate_json(path.read_bytes())
    if not profile.certified:
        raise ValueError(f"machine profile {profile.profile_id!r} is not certified")
    return profile
