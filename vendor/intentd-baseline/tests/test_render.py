from pathlib import Path

import pytest

from intentd.catalog import load_catalog
from intentd.machine import GraphicsProfile
from intentd.registry import InvocationError, resolve_invocation
from intentd.render import RenderError, render
from intentd.schema import CatalogApp
from intentd.state import DesiredState
from tests.helpers import vm_machine_profile

GOLDEN = Path(__file__).parent / "golden" / "generated_full.nix"


def test_render_matches_golden_byte_for_byte():
    state = DesiredState(apps=("firefox", "obsidian", "vlc"))
    assert render(state, load_catalog(), None) == GOLDEN.read_text()


def test_render_is_deterministic():
    state = DesiredState(apps=("firefox", "obsidian", "vlc"))
    catalog = load_catalog()
    assert render(state, catalog, None) == render(state, catalog, None)


def test_render_without_unfree_omits_predicate():
    out = render(DesiredState(apps=("firefox",)), load_catalog(), None)
    assert "allowUnfreePredicate" not in out
    assert "pkgs.firefox" in out


def test_render_empty_state():
    out = render(DesiredState(), load_catalog(), None)
    assert "environment.systemPackages = [" in out
    assert "pkgs." not in out


def test_uncatalogued_app_rejected():
    with pytest.raises(RenderError, match="not in the catalog"):
        render(DesiredState(apps=("nope",)), load_catalog(), None)


def test_hostile_attr_rejected_by_audited_constructor():
    catalog = {
        "evil": CatalogApp(id="evil", name="Evil", attr='x; import <nixpkgs> {}"', summary="x")
    }
    with pytest.raises(RenderError, match="audited constructor"):
        render(DesiredState(apps=("evil",)), catalog, None)


def test_nix_keyword_attr_rejected_by_audited_constructor():
    catalog = {
        "kw": CatalogApp(id="kw", name="Kw", attr="if", summary="x"),
    }
    with pytest.raises(RenderError, match="audited constructor"):
        render(DesiredState(apps=("kw",)), catalog, None)


def test_catalog_key_id_mismatch_rejected():
    catalog = {
        "firefox": CatalogApp(id="vlc", name="VLC", attr="vlc", summary="Media player"),
    }
    with pytest.raises(RenderError, match="does not match"):
        render(DesiredState(apps=("firefox",)), catalog, None)


def test_hybrid_profile_render_is_closed() -> None:
    rendered = render(
        DesiredState(graphics_profile=GraphicsProfile.HYBRID_NVIDIA),
        {},
        vm_machine_profile(),
    )
    assert 'services.xserver.videoDrivers = [ "modesetting" "nvidia" ];' in rendered
    assert "hardware.nvidia.modesetting.enable = true;" in rendered
    assert "hardware.nvidia.prime.offload.enable = true;" in rendered
    assert 'hardware.nvidia.prime.intelBusId = "PCI:0:2:0";' in rendered
    assert 'hardware.nvidia.prime.nvidiaBusId = "PCI:1:0:0";' in rendered


def test_graphics_render_requires_machine_profile() -> None:
    with pytest.raises(RenderError, match="machine profile"):
        render(DesiredState(graphics_profile=GraphicsProfile.INTEGRATED), {}, None)


@pytest.mark.parametrize(
    "field",
    ["intel_pci", "package", "driver", "kernel_parameter", "nix"],
)
def test_graphics_invocation_cannot_override_renderer_owned_fields(field: str) -> None:
    with pytest.raises(InvocationError):
        resolve_invocation(
            {},
            "hardware.graphics.profile",
            {"profile": "hybrid-nvidia", field: "attacker-controlled"},
        )
