"""The no-model picker (locked decision 5): a fully offline, three-pane
Textual surface (installed / available / recent history) that drives app
install/remove/revert through the same apply path the CLI uses. No network,
no model calls anywhere in this module.

All state logic lives in `PickerModel`, a pure class with no Textual or I/O
dependencies -- it is headless-testable on its own. `PickerApp` is a thin
Textual shell: it binds keys, asks the model to build a typed
`ActionRequest`, hands that to the injected `apply_fn` (the same
`apply_with_reconcile` the CLI uses), and feeds the `ApplyResult` back into
the model.
"""

from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from enum import StrEnum

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.widgets import Static

from intentd.orchestrator import ApplyResult, Deps
from intentd.policy import PolicyVerdict
from intentd.registry import CapabilityInvocation, resolve_invocation
from intentd.schema import CatalogApp
from intentd.state import DesiredState
from intentd.txn import TransactionRecord

_DEFAULT_HISTORY_N = 10


class Pane(StrEnum):
    INSTALLED = "installed"
    AVAILABLE = "available"
    HISTORY = "history"


_PANE_ORDER: tuple[Pane, ...] = (Pane.INSTALLED, Pane.AVAILABLE, Pane.HISTORY)


@dataclass(frozen=True)
class ActionRequest:
    """A concrete, resolver-validated apply request. The shell hands this to
    the injected apply_fn unmodified."""

    invocation: CapabilityInvocation
    acks: frozenset[str] = frozenset()


@dataclass(frozen=True)
class AckPending:
    """An unfree install awaiting the explicit ack keypress (locked decision
    5's NEEDS_ACK reuse): set from a real NEEDS_ACK PolicyDecision, so the
    reason text and required_acks are never re-derived here."""

    app_id: str
    reason: str
    required_acks: frozenset[str]


def _clamp(index: int, length: int) -> int:
    if length == 0:
        return 0
    return max(0, min(index, length - 1))


class PickerModel:
    """Pure state for the picker: selection, pending ack, and the last-known
    blessed state/history. Builds `ActionRequest`s; never applies them and
    never touches nix, the network, or a model."""

    def __init__(
        self,
        catalog: Mapping[str, CatalogApp],
        blessed_state: DesiredState,
        history: Sequence[TransactionRecord],
    ) -> None:
        self.catalog: dict[str, CatalogApp] = dict(catalog)
        self.blessed_state = blessed_state
        self.history: list[TransactionRecord] = list(history)
        self.pane: Pane = Pane.INSTALLED
        self.pending_ack: AckPending | None = None
        self.status: str = ""
        self._installed_index = 0
        self._available_index = 0
        self._history_index = 0
        self._clamp_indices()

    # --- derived views ---

    def installed_apps(self) -> list[CatalogApp]:
        return sorted(
            (self.catalog[a] for a in self.blessed_state.apps if a in self.catalog),
            key=lambda a: a.id,
        )

    def available_apps(self) -> list[CatalogApp]:
        installed = set(self.blessed_state.apps)
        return sorted(
            (a for a in self.catalog.values() if a.id not in installed), key=lambda a: a.id
        )

    def recent_history(self) -> list[TransactionRecord]:
        return self.history

    def index_for(self, pane: Pane) -> int:
        if pane is Pane.INSTALLED:
            return self._installed_index
        if pane is Pane.AVAILABLE:
            return self._available_index
        return self._history_index

    def selected_installed(self) -> CatalogApp | None:
        apps = self.installed_apps()
        if not apps:
            return None
        return apps[_clamp(self._installed_index, len(apps))]

    def selected_available(self) -> CatalogApp | None:
        apps = self.available_apps()
        if not apps:
            return None
        return apps[_clamp(self._available_index, len(apps))]

    # --- navigation ---

    def move_selection(self, delta: int) -> None:
        self.pending_ack = None
        if self.pane is Pane.INSTALLED:
            self._installed_index = _clamp(
                self._installed_index + delta, len(self.installed_apps())
            )
        elif self.pane is Pane.AVAILABLE:
            self._available_index = _clamp(
                self._available_index + delta, len(self.available_apps())
            )
        else:
            self._history_index = _clamp(self._history_index + delta, len(self.history))

    def switch_pane(self, pane: Pane) -> None:
        self.pending_ack = None
        self.pane = pane

    def cycle_pane(self, delta: int) -> None:
        self.pending_ack = None
        idx = _PANE_ORDER.index(self.pane)
        self.pane = _PANE_ORDER[(idx + delta) % len(_PANE_ORDER)]

    # --- action construction ---

    def request_install(self) -> ActionRequest | None:
        app = self.selected_available()
        if app is None:
            self.status = "no available app to install"
            return None
        invocation = resolve_invocation(self.catalog, "app.install", {"app": app.id})
        if self.pending_ack is not None and self.pending_ack.app_id == app.id:
            # The explicit ack keypress: same app still selected, re-issue
            # with the acks the earlier NEEDS_ACK decision required.
            return ActionRequest(invocation=invocation, acks=self.pending_ack.required_acks)
        return ActionRequest(invocation=invocation, acks=frozenset())

    def request_remove(self) -> ActionRequest | None:
        app = self.selected_installed()
        if app is None:
            self.status = "no installed app to remove"
            return None
        invocation = resolve_invocation(self.catalog, "app.remove", {"app": app.id})
        return ActionRequest(invocation=invocation, acks=frozenset())

    def request_revert(self) -> ActionRequest:
        invocation = resolve_invocation(self.catalog, "change.revert", {})
        return ActionRequest(invocation=invocation, acks=frozenset())

    # --- feeding results back in ---

    def on_apply_result(self, request: ActionRequest, result: ApplyResult) -> None:
        decision = result.decision
        if decision.verdict is PolicyVerdict.NEEDS_ACK and result.record is None:
            app_id = request.invocation.params.get("app")
            if not isinstance(app_id, str):
                self.pending_ack = None
                self.status = decision.reason
                return
            self.pending_ack = AckPending(
                app_id=app_id,
                reason=decision.reason,
                required_acks=frozenset(decision.required_acks),
            )
            self.status = decision.reason
            return

        self.pending_ack = None
        if decision.verdict is PolicyVerdict.REJECT or result.record is None:
            self.status = f"rejected: {decision.reason}"
            return

        record = result.record
        detail = f": {record.detail}" if record.detail else ""
        self.status = f"txn {record.id} {record.status.value}{detail}"

    def refresh(self, blessed_state: DesiredState, history: Sequence[TransactionRecord]) -> None:
        self.blessed_state = blessed_state
        self.history = list(history)
        self._clamp_indices()

    def _clamp_indices(self) -> None:
        self._installed_index = _clamp(self._installed_index, len(self.installed_apps()))
        self._available_index = _clamp(self._available_index, len(self.available_apps()))
        self._history_index = _clamp(self._history_index, len(self.history))


class PickerApp(App[None]):
    """Thin Textual shell: renders `PickerModel`, binds i/r/u/q (plus
    arrow/tab navigation), and applies through the injected apply_fn -- the
    same `apply_with_reconcile` path `intent do` uses."""

    CSS = """
    Screen {
        layout: vertical;
    }
    #panes {
        height: 1fr;
    }
    #panes > Static {
        border: round $primary;
        width: 1fr;
        padding: 0 1;
    }
    #status-bar {
        height: 3;
        border: round $primary;
        padding: 0 1;
    }
    """

    BINDINGS = [
        Binding("up,k", "move_up", "Up", show=False),
        Binding("down,j", "move_down", "Down", show=False),
        Binding("left", "prev_pane", "Prev pane", show=False),
        Binding("right,tab", "next_pane", "Next pane", show=False),
        Binding("i", "install", "Install"),
        Binding("r", "remove", "Remove"),
        Binding("u", "revert", "Revert last"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(
        self,
        deps: Deps,
        apply_fn: Callable[[Deps, CapabilityInvocation, frozenset[str]], ApplyResult],
        history_n: int = _DEFAULT_HISTORY_N,
    ) -> None:
        super().__init__()
        self._deps = deps
        self._apply_fn = apply_fn
        self._history_n = history_n
        self.model = PickerModel(
            catalog=deps.catalog,
            blessed_state=deps.store.blessed_state(),
            history=deps.store.recent(history_n),
        )

    def compose(self) -> ComposeResult:
        with Horizontal(id="panes"):
            yield Static(id="installed-pane")
            yield Static(id="available-pane")
            yield Static(id="history-pane")
        yield Static(id="status-bar")

    def on_mount(self) -> None:
        self._render()

    # --- navigation actions ---

    def action_move_up(self) -> None:
        self.model.move_selection(-1)
        self._render()

    def action_move_down(self) -> None:
        self.model.move_selection(1)
        self._render()

    def action_prev_pane(self) -> None:
        self.model.cycle_pane(-1)
        self._render()

    def action_next_pane(self) -> None:
        self.model.cycle_pane(1)
        self._render()

    # --- apply actions ---

    def action_install(self) -> None:
        self._dispatch(self.model.request_install())

    def action_remove(self) -> None:
        self._dispatch(self.model.request_remove())

    def action_revert(self) -> None:
        self._dispatch(self.model.request_revert())

    def _dispatch(self, request: ActionRequest | None) -> None:
        if request is None:
            self._render()
            return
        result = self._apply_fn(self._deps, request.invocation, request.acks)
        self.model.on_apply_result(request, result)
        self.model.refresh(
            self._deps.store.blessed_state(), self._deps.store.recent(self._history_n)
        )
        self._render()

    # --- rendering (thin: string-building only, no state decisions) ---

    def _render(self) -> None:
        self.query_one("#installed-pane", Static).update(self._render_pane_text(Pane.INSTALLED))
        self.query_one("#available-pane", Static).update(self._render_pane_text(Pane.AVAILABLE))
        self.query_one("#history-pane", Static).update(self._render_history_text())
        self.query_one("#status-bar", Static).update(self._render_status_text())

    def _render_pane_text(self, pane: Pane) -> str:
        apps = (
            self.model.installed_apps() if pane is Pane.INSTALLED else self.model.available_apps()
        )
        title = "INSTALLED" if pane is Pane.INSTALLED else "AVAILABLE"
        header = f"{title}{' *' if self.model.pane is pane else ''}"
        lines = [header]
        selected = self.model.index_for(pane)
        if not apps:
            lines.append("  (none)")
        for i, app in enumerate(apps):
            cursor = ">" if self.model.pane is pane and i == selected else " "
            flag = " [unfree]" if app.unfree else ""
            lines.append(f"{cursor} {app.name}{flag}")
        return "\n".join(lines)

    def _render_history_text(self) -> str:
        header = f"HISTORY{' *' if self.model.pane is Pane.HISTORY else ''}"
        lines = [header]
        records = self.model.recent_history()
        selected = self.model.index_for(Pane.HISTORY)
        if not records:
            lines.append("  (no transactions yet)")
        for i, record in enumerate(records):
            cursor = ">" if self.model.pane is Pane.HISTORY and i == selected else " "
            lines.append(
                f"{cursor} #{record.id} {record.status.value} {record.invocation.capability}"
            )
        return "\n".join(lines)

    def _render_status_text(self) -> str:
        if self.model.pending_ack is not None:
            return f"{self.model.pending_ack.reason} -- press i again to confirm, or move to cancel"
        return self.model.status or "i install   r remove   u revert last   q quit"
