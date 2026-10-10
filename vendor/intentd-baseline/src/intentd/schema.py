from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class EffectClass(StrEnum):
    REVERSIBLE = "reversible"
    SNAPSHOT_REVERSIBLE = "snapshot-reversible"
    RECONSTRUCTIBLE = "reconstructible"
    COMPENSATABLE = "compensatable"
    IRREVERSIBLE = "irreversible"


class ClosedModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class CatalogApp(ClosedModel):
    id: str
    name: str
    attr: str  # nixpkgs attribute path
    unfree: bool = False
    summary: str


class AppInstallParams(ClosedModel):
    app: str


class AppRemoveParams(ClosedModel):
    app: str


class ChangeRevertParams(ClosedModel):
    pass


class GraphicsProfile(StrEnum):
    INTEGRATED = "integrated"
    HYBRID_NVIDIA = "hybrid-nvidia"


class GraphicsProfileParams(ClosedModel):
    profile: GraphicsProfile


class CapabilityDef(ClosedModel):
    id: str
    title: str
    effect_class: EffectClass
    params_model: type[ClosedModel] = Field(exclude=True)
    boot_affecting: bool = False
