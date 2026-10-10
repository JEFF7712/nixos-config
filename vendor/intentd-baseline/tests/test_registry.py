import pydantic
import pytest

from intentd.catalog import load_catalog
from intentd.registry import REGISTRY, CapabilityInvocation, InvocationError, resolve_invocation
from intentd.schema import (
    AppInstallParams,
    AppRemoveParams,
    ChangeRevertParams,
    EffectClass,
    GraphicsProfileParams,
)


def test_registry_contains_the_stage_two_capabilities():
    assert set(REGISTRY) == {
        "app.install",
        "app.remove",
        "change.revert",
        "hardware.graphics.profile",
    }


def test_all_wedge_capabilities_are_reversible():
    assert all(c.effect_class is EffectClass.REVERSIBLE for c in REGISTRY.values())


def test_graphics_profile_is_boot_affecting() -> None:
    capability = REGISTRY["hardware.graphics.profile"]
    assert capability.boot_affecting is True
    assert capability.params_model is GraphicsProfileParams


def test_install_params_model_is_closed():
    with pytest.raises(pydantic.ValidationError):
        AppInstallParams(app="firefox", hook="x")  # type: ignore[call-arg]


def test_capability_def_serializes_without_params_model():
    import json

    d = json.loads(REGISTRY["app.install"].model_dump_json())
    assert d["id"] == "app.install"
    assert "params_model" not in d


def test_valid_install_invocation_resolves():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    assert inv.capability == "app.install"
    assert inv.params == {"app": "firefox"}


def test_unknown_capability_rejected():
    with pytest.raises(InvocationError, match="unknown capability"):
        resolve_invocation(load_catalog(), "system.wipe", {})


def test_uncatalogued_app_rejected():
    with pytest.raises(InvocationError, match="not in the catalog"):
        resolve_invocation(load_catalog(), "app.install", {"app": "definitely-not-real"})


def test_extra_params_rejected():
    with pytest.raises(InvocationError):
        resolve_invocation(
            load_catalog(), "app.install", {"app": "firefox", "postscript": "rm -rf /"}
        )


def test_each_capability_wired_to_its_own_params_model():
    assert REGISTRY["app.install"].params_model is AppInstallParams
    assert REGISTRY["app.remove"].params_model is AppRemoveParams
    assert REGISTRY["change.revert"].params_model is ChangeRevertParams
    assert REGISTRY["hardware.graphics.profile"].params_model is GraphicsProfileParams


def test_change_revert_params_are_closed():
    with pytest.raises(pydantic.ValidationError):
        ChangeRevertParams(stray="x")  # type: ignore[call-arg]


def test_revert_invocation_needs_no_app():
    inv = resolve_invocation(load_catalog(), "change.revert", {})
    assert inv.capability == "change.revert"
    assert inv.params == {}


def test_valid_remove_invocation_resolves():
    inv = resolve_invocation(load_catalog(), "app.remove", {"app": "vlc"})
    assert inv.params == {"app": "vlc"}


def test_duplicate_capability_id_fails_loudly():
    import pytest

    from intentd.registry import _build_registry  # pyright: ignore[reportPrivateUsage]
    from intentd.schema import AppInstallParams, CapabilityDef, EffectClass

    dup = CapabilityDef(
        id="app.install",
        title="Duplicate",
        effect_class=EffectClass.REVERSIBLE,
        params_model=AppInstallParams,
    )
    with pytest.raises(ValueError, match="duplicate capability id"):
        _build_registry(dup, dup)


def test_invocation_params_are_immutable():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    with pytest.raises(TypeError):
        inv.params["app"] = "evil"  # type: ignore[index]


def test_direct_construction_rejects_unknown_capability():
    with pytest.raises(pydantic.ValidationError):
        CapabilityInvocation(capability="system.wipe", params={})


def test_direct_construction_rejects_invalid_params():
    with pytest.raises(pydantic.ValidationError):
        CapabilityInvocation(capability="app.install", params={"app": "firefox", "postscript": "x"})


def test_invocation_round_trips_through_json():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    restored = CapabilityInvocation.model_validate_json(inv.model_dump_json())
    assert restored == inv
