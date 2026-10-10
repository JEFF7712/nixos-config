from enum import StrEnum

from intentd.machine import (
    INTEL_PCI_ADDRESS,
    NVIDIA_PCI_ADDRESS,
    GraphicsBackend,
    MachineProfile,
)
from intentd.registry import REGISTRY, CapabilityInvocation
from intentd.schema import CatalogApp, ClosedModel, EffectClass, GraphicsProfile
from intentd.state import DesiredState, StateError, apply_invocation


class PolicyVerdict(StrEnum):
    AUTO_APPLY = "auto-apply"
    NEEDS_ACK = "needs-ack"
    REJECT = "reject"


class PolicyDecision(ClosedModel):
    verdict: PolicyVerdict
    reason: str
    required_acks: tuple[str, ...] = ()


_ALLOWLIST = frozenset({"app.install", "app.remove", "change.revert", "hardware.graphics.profile"})


def _reject(reason: str) -> PolicyDecision:
    return PolicyDecision(verdict=PolicyVerdict.REJECT, reason=reason)


def evaluate(
    invocation: CapabilityInvocation,
    catalog: dict[str, CatalogApp],
    prev_state: DesiredState,
    new_state: DesiredState,
    *,
    machine_profile: MachineProfile | None,
    acknowledged_unfree: frozenset[str] = frozenset(),
    revert_target: DesiredState | None = None,
) -> PolicyDecision:
    cap = REGISTRY.get(invocation.capability)
    if cap is None:
        return _reject(f"unknown capability {invocation.capability!r}")
    if invocation.capability not in _ALLOWLIST:
        return _reject(f"capability {invocation.capability!r} is not on the allowlist")
    if cap.effect_class is not EffectClass.REVERSIBLE:
        return _reject(f"effect class {cap.effect_class} may not auto-apply")
    if invocation.capability == "change.revert":
        if revert_target is None:
            return _reject("no blessed transaction to revert")
        if new_state != revert_target:
            return _reject("revert state does not match the blessed target")
        return PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="revert to blessed target")
    try:
        recomputed = apply_invocation(prev_state, invocation)
    except StateError as exc:
        return _reject(str(exc))
    if recomputed != new_state:
        return _reject("declared state delta does not match the invocation")
    if invocation.capability == "hardware.graphics.profile":
        if machine_profile is None:
            return _reject("graphics changes require a machine profile")
        if not machine_profile.certified:
            return _reject("graphics changes require a certified machine profile")
        if machine_profile.graphics_backend not in {
            GraphicsBackend.INTENTD_VM,
            GraphicsBackend.UX3404VC,
        }:
            return _reject("unsupported graphics backend")
        if machine_profile.intel_pci != INTEL_PCI_ADDRESS:
            return _reject("machine profile Intel PCI address is not certified")
        if (
            new_state.graphics_profile is GraphicsProfile.HYBRID_NVIDIA
            and machine_profile.nvidia_pci != NVIDIA_PCI_ADDRESS
        ):
            return _reject("machine profile NVIDIA PCI address is not certified")
        return PolicyDecision(
            verdict=PolicyVerdict.AUTO_APPLY,
            reason="certified boot-affecting graphics change",
        )
    app_id = invocation.params.get("app")
    if app_id is None:
        return _reject("app capability without an app parameter")
    app = catalog.get(app_id)
    if app is None:
        return _reject(f"app {app_id!r} is not in the current catalog")
    if app.id != app_id:
        return _reject(f"catalog entry id {app.id!r} does not match key {app_id!r}")
    if invocation.capability == "app.install" and app.unfree and app.id not in acknowledged_unfree:
        return PolicyDecision(
            verdict=PolicyVerdict.NEEDS_ACK,
            reason=f"{app.name} has an unfree license that needs acceptance",
            required_acks=(app.id,),
        )
    return PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="allowlisted reversible change")
