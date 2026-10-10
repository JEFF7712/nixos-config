import pytest

from intentd.catalog import load_catalog
from intentd.machine import GraphicsProfile
from intentd.policy import PolicyVerdict, evaluate
from intentd.registry import resolve_invocation
from intentd.state import DesiredState, apply_invocation
from tests.helpers import vm_machine_profile


def _catalog():
    return load_catalog()


def test_free_install_auto_applies():
    inv = resolve_invocation(_catalog(), "app.install", {"app": "firefox"})
    decision = evaluate(
        inv, _catalog(), DesiredState(), DesiredState(apps=("firefox",)), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.AUTO_APPLY


def test_unfree_install_needs_ack():
    inv = resolve_invocation(_catalog(), "app.install", {"app": "obsidian"})
    decision = evaluate(
        inv, _catalog(), DesiredState(), DesiredState(apps=("obsidian",)), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.NEEDS_ACK
    assert decision.required_acks == ("obsidian",)


def test_acknowledged_unfree_install_auto_applies():
    inv = resolve_invocation(_catalog(), "app.install", {"app": "obsidian"})
    decision = evaluate(
        inv,
        _catalog(),
        DesiredState(),
        DesiredState(apps=("obsidian",)),
        machine_profile=None,
        acknowledged_unfree=frozenset({"obsidian"}),
    )
    assert decision.verdict is PolicyVerdict.AUTO_APPLY


def test_unfree_remove_needs_no_ack():
    inv = resolve_invocation(_catalog(), "app.remove", {"app": "obsidian"})
    decision = evaluate(
        inv, _catalog(), DesiredState(apps=("obsidian",)), DesiredState(), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.AUTO_APPLY


def test_state_delta_mismatch_rejected():
    inv = resolve_invocation(_catalog(), "app.install", {"app": "firefox"})
    decision = evaluate(
        inv,
        _catalog(),
        DesiredState(),
        DesiredState(apps=("firefox", "vlc")),
        machine_profile=None,
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "does not match" in decision.reason


def test_invalid_transform_rejected():
    inv = resolve_invocation(_catalog(), "app.remove", {"app": "firefox"})
    decision = evaluate(inv, _catalog(), DesiredState(), DesiredState(), machine_profile=None)
    assert decision.verdict is PolicyVerdict.REJECT


def test_catalog_recheck_rejects_dropped_app():
    full = _catalog()
    inv = resolve_invocation(full, "app.install", {"app": "firefox"})
    shrunk = {k: v for k, v in full.items() if k != "firefox"}
    decision = evaluate(
        inv, shrunk, DesiredState(), DesiredState(apps=("firefox",)), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "current catalog" in decision.reason


def test_revert_without_blessed_target_rejected():
    inv = resolve_invocation(_catalog(), "change.revert", {})
    decision = evaluate(
        inv, _catalog(), DesiredState(apps=("firefox",)), DesiredState(), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "revert" in decision.reason


def test_revert_to_matching_target_auto_applies():
    inv = resolve_invocation(_catalog(), "change.revert", {})
    decision = evaluate(
        inv,
        _catalog(),
        DesiredState(apps=("firefox",)),
        DesiredState(),
        machine_profile=None,
        revert_target=DesiredState(),
    )
    assert decision.verdict is PolicyVerdict.AUTO_APPLY


def test_revert_to_mismatched_target_rejected():
    inv = resolve_invocation(_catalog(), "change.revert", {})
    decision = evaluate(
        inv,
        _catalog(),
        DesiredState(apps=("firefox",)),
        DesiredState(apps=("vlc",)),
        machine_profile=None,
        revert_target=DesiredState(),
    )
    assert decision.verdict is PolicyVerdict.REJECT


def test_policy_recomputes_rather_than_trusting_caller():
    inv = resolve_invocation(_catalog(), "app.install", {"app": "vlc"})
    prev = DesiredState(apps=("firefox",))
    decision = evaluate(inv, _catalog(), prev, apply_invocation(prev, inv), machine_profile=None)
    assert decision.verdict is PolicyVerdict.AUTO_APPLY


def test_catalog_key_id_mismatch_rejected():
    full = _catalog()
    inv = resolve_invocation(full, "app.install", {"app": "firefox"})
    mismatched = {"firefox": full["vlc"]}
    decision = evaluate(
        inv, mismatched, DesiredState(), DesiredState(apps=("firefox",)), machine_profile=None
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "does not match" in decision.reason


def test_catalog_recheck_applies_to_deserialized_invocations():
    from intentd.registry import CapabilityInvocation

    full = _catalog()
    inv = resolve_invocation(full, "app.install", {"app": "firefox"})
    restored = CapabilityInvocation.model_validate_json(inv.model_dump_json())
    shrunk = {k: v for k, v in full.items() if k != "firefox"}
    decision = evaluate(
        restored,
        shrunk,
        DesiredState(),
        DesiredState(apps=("firefox",)),
        machine_profile=None,
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "current catalog" in decision.reason


def test_graphics_policy_requires_certified_matching_machine() -> None:
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": "hybrid-nvidia"})
    previous = DesiredState(graphics_profile=GraphicsProfile.INTEGRATED)
    desired = DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA)
    assert (
        evaluate(invocation, {}, previous, desired, machine_profile=None).verdict
        is PolicyVerdict.REJECT
    )
    assert (
        evaluate(
            invocation,
            {},
            previous,
            desired,
            machine_profile=vm_machine_profile(),
        ).verdict
        is PolicyVerdict.AUTO_APPLY
    )


def test_graphics_policy_rejects_uncertified_machine() -> None:
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": "integrated"})
    profile = vm_machine_profile().model_copy(update={"certified": False})
    decision = evaluate(
        invocation,
        {},
        DesiredState(),
        DesiredState(graphics_profile=GraphicsProfile.INTEGRATED),
        machine_profile=profile,
    )
    assert decision.verdict is PolicyVerdict.REJECT


@pytest.mark.parametrize(
    ("profile_name", "profile_update"),
    [
        ("integrated", {"graphics_backend": "unsupported"}),
        ("integrated", {"intel_pci": "0000:00:03.0"}),
        ("hybrid-nvidia", {"nvidia_pci": "0000:02:00.0"}),
    ],
)
def test_graphics_policy_rechecks_authenticated_machine_facts(
    profile_name: str, profile_update: dict[str, object]
) -> None:
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": profile_name})
    profile = vm_machine_profile().model_copy(update=profile_update)
    desired = apply_invocation(DesiredState(), invocation)
    decision = evaluate(
        invocation,
        {},
        DesiredState(),
        desired,
        machine_profile=profile,
    )
    assert decision.verdict is PolicyVerdict.REJECT


def test_graphics_policy_recomputes_state_delta() -> None:
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": "integrated"})
    decision = evaluate(
        invocation,
        {},
        DesiredState(),
        DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA),
        machine_profile=vm_machine_profile(),
    )
    assert decision.verdict is PolicyVerdict.REJECT
    assert "does not match" in decision.reason
