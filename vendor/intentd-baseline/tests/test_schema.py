import pydantic
import pytest

from intentd.schema import CatalogApp, EffectClass, GraphicsProfileParams


def test_effect_classes_match_design_doc_taxonomy():
    assert {e.value for e in EffectClass} == {
        "reversible",
        "snapshot-reversible",
        "reconstructible",
        "compensatable",
        "irreversible",
    }


def test_catalog_app_rejects_unknown_fields():
    import pydantic
    import pytest

    with pytest.raises(pydantic.ValidationError):
        CatalogApp(
            id="firefox",
            name="Firefox",
            attr="firefox",
            summary="Web browser",
            shell_hook="curl evil",  # type: ignore[call-arg]
        )


def test_catalog_app_defaults_to_free():
    app = CatalogApp(id="firefox", name="Firefox", attr="firefox", summary="Web browser")
    assert app.unfree is False


def test_graphics_profile_params_are_closed() -> None:
    with pytest.raises(pydantic.ValidationError):
        GraphicsProfileParams.model_validate(
            {"profile": "integrated", "kernel_parameter": "init=/bin/sh"}
        )
