from pydantic import model_validator

from intentd.registry import CapabilityInvocation
from intentd.schema import ClosedModel, GraphicsProfile


class StateError(Exception):
    pass


class DesiredState(ClosedModel):
    apps: tuple[str, ...] = ()
    graphics_profile: GraphicsProfile | None = None

    @model_validator(mode="after")
    def _check_canonical(self) -> "DesiredState":
        if self.apps != tuple(sorted(set(self.apps))):
            raise ValueError("apps must be sorted and unique")
        return self


def apply_invocation(state: DesiredState, invocation: CapabilityInvocation) -> DesiredState:
    apps = set(state.apps)
    if invocation.capability == "app.install":
        app = invocation.params["app"]
        if app in apps:
            raise StateError(f"app {app!r} is already installed")
        apps.add(app)
        return state.model_copy(update={"apps": tuple(sorted(apps))})
    if invocation.capability == "app.remove":
        app = invocation.params["app"]
        if app not in apps:
            raise StateError(f"app {app!r} is not installed")
        apps.remove(app)
        return state.model_copy(update={"apps": tuple(sorted(apps))})
    if invocation.capability == "hardware.graphics.profile":
        profile = GraphicsProfile(invocation.params["profile"])
        return state.model_copy(update={"graphics_profile": profile})
    raise StateError(f"capability {invocation.capability!r} is not a state transform")
