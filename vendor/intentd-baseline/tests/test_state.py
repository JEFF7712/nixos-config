import pydantic
import pytest

from intentd.catalog import load_catalog
from intentd.machine import GraphicsProfile
from intentd.registry import resolve_invocation
from intentd.state import DesiredState, StateError, apply_invocation


def test_desired_state_requires_canonical_apps():
    with pytest.raises(pydantic.ValidationError):
        DesiredState(apps=("vlc", "firefox"))
    with pytest.raises(pydantic.ValidationError):
        DesiredState(apps=("firefox", "firefox"))
    assert DesiredState(apps=("firefox", "vlc")).apps == ("firefox", "vlc")


def test_install_adds_app():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    state = apply_invocation(DesiredState(), inv)
    assert state.apps == ("firefox",)


def test_install_of_installed_app_rejected():
    inv = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    with pytest.raises(StateError, match="already installed"):
        apply_invocation(DesiredState(apps=("firefox",)), inv)


def test_remove_drops_app():
    inv = resolve_invocation(load_catalog(), "app.remove", {"app": "firefox"})
    state = apply_invocation(DesiredState(apps=("firefox", "vlc")), inv)
    assert state.apps == ("vlc",)


def test_remove_of_absent_app_rejected():
    inv = resolve_invocation(load_catalog(), "app.remove", {"app": "firefox"})
    with pytest.raises(StateError, match="not installed"):
        apply_invocation(DesiredState(), inv)


def test_revert_is_not_a_state_transform():
    inv = resolve_invocation(load_catalog(), "change.revert", {})
    with pytest.raises(StateError, match="not a state transform"):
        apply_invocation(DesiredState(), inv)


def test_graphics_profile_replaces_only_graphics_state() -> None:
    before = DesiredState(apps=("firefox",), graphics_profile=GraphicsProfile.INTEGRATED)
    invocation = resolve_invocation({}, "hardware.graphics.profile", {"profile": "hybrid-nvidia"})
    assert apply_invocation(before, invocation) == DesiredState(
        apps=("firefox",), graphics_profile=GraphicsProfile.HYBRID_NVIDIA
    )


def test_app_change_preserves_graphics_state() -> None:
    invocation = resolve_invocation(load_catalog(), "app.install", {"app": "firefox"})
    state = DesiredState(graphics_profile=GraphicsProfile.INTEGRATED)
    assert apply_invocation(state, invocation).graphics_profile is GraphicsProfile.INTEGRATED
