import hashlib
import json
from collections.abc import Mapping
from types import MappingProxyType
from typing import Any

import pydantic
from pydantic import field_serializer, field_validator, model_validator

from intentd.schema import (
    AppInstallParams,
    AppRemoveParams,
    CapabilityDef,
    CatalogApp,
    ChangeRevertParams,
    ClosedModel,
    EffectClass,
    GraphicsProfileParams,
)


class InvocationError(Exception):
    pass


class CapabilityInvocation(ClosedModel):
    capability: str
    params: Mapping[str, Any]

    @field_validator("params", mode="after")
    @classmethod
    def _freeze_params(cls, v: Mapping[str, Any]) -> Mapping[str, Any]:
        return MappingProxyType(dict(v))

    @field_serializer("params")
    def _serialize_params(self, v: Mapping[str, Any]) -> dict[str, Any]:
        return dict(v)

    @model_validator(mode="after")
    def _check_against_registry(self) -> "CapabilityInvocation":
        # Catalog membership is deliberately not checked here: the catalog is
        # runtime context that changes between releases, so a stored invocation
        # is evidence of what was resolved, not authority to execute. Policy
        # must re-check the current catalog before any invocation acts.
        cap = REGISTRY.get(self.capability)
        if cap is None:
            raise ValueError(f"unknown capability: {self.capability!r}")
        cap.params_model.model_validate(dict(self.params))
        return self


def _build_registry(*caps: CapabilityDef) -> dict[str, CapabilityDef]:
    registry: dict[str, CapabilityDef] = {}
    for cap in caps:
        if cap.id in registry:
            raise ValueError(f"duplicate capability id: {cap.id}")
        registry[cap.id] = cap
    return registry


REGISTRY: dict[str, CapabilityDef] = _build_registry(
    CapabilityDef(
        id="app.install",
        title="Install a catalogued application",
        effect_class=EffectClass.REVERSIBLE,
        params_model=AppInstallParams,
    ),
    CapabilityDef(
        id="app.remove",
        title="Remove a catalogued application",
        effect_class=EffectClass.REVERSIBLE,
        params_model=AppRemoveParams,
    ),
    CapabilityDef(
        id="change.revert",
        title="Revert the latest transaction",
        effect_class=EffectClass.REVERSIBLE,
        params_model=ChangeRevertParams,
    ),
    CapabilityDef(
        id="hardware.graphics.profile",
        title="Select a certified graphics profile",
        effect_class=EffectClass.REVERSIBLE,
        params_model=GraphicsProfileParams,
        boot_affecting=True,
    ),
)


def digest_invocation(invocation: CapabilityInvocation) -> str:
    canonical = json.dumps(
        invocation.model_dump(mode="json"), sort_keys=True, separators=(",", ":")
    ).encode()
    return hashlib.sha256(canonical).hexdigest()


def resolve_invocation(
    catalog: dict[str, CatalogApp], capability_id: str, raw_params: dict[str, Any]
) -> CapabilityInvocation:
    cap = REGISTRY.get(capability_id)
    if cap is None:
        raise InvocationError(f"unknown capability: {capability_id!r}")
    try:
        params = cap.params_model.model_validate(raw_params)
    except pydantic.ValidationError as exc:
        raise InvocationError(f"invalid parameters for {capability_id}: {exc}") from exc
    app_id = getattr(params, "app", None)
    if app_id is not None and app_id not in catalog:
        raise InvocationError(f"app {app_id!r} is not in the catalog")
    return CapabilityInvocation(capability=capability_id, params=params.model_dump())
