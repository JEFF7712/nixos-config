import asyncio
from pathlib import Path

from intentd.catalog import digest_catalog, load_catalog
from intentd.orchestrator import ApplyResult, Deps
from intentd.picker import ActionRequest, PickerApp, PickerModel
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.registry import resolve_invocation
from intentd.state import DesiredState
from intentd.txn import TransactionRecord, TxnStatus
from intentd.workspace import init_workspace
from tests.helpers import make_store, vm_machine_profile

_CATALOG = load_catalog()


def _model(
    *, installed: tuple[str, ...] = (), history: list[TransactionRecord] | None = None
) -> PickerModel:
    return PickerModel(
        catalog=_CATALOG,
        blessed_state=DesiredState(apps=installed),
        history=history or [],
    )


def _select_available(model: PickerModel, app_id: str) -> None:
    """Drive selection onto `app_id` in the available pane through the
    public move_selection API only (no reaching into model internals)."""
    from intentd.picker import Pane

    model.switch_pane(Pane.AVAILABLE)
    target = next(i for i, a in enumerate(model.available_apps()) if a.id == app_id)
    for _ in range(target):
        model.move_selection(1)


def _record(
    app: str,
    status: TxnStatus,
    *,
    txn_id: int = 1,
    detail: str | None = None,
    prev: DesiredState | None = None,
    new: DesiredState | None = None,
) -> TransactionRecord:
    inv = resolve_invocation(_CATALOG, "app.install", {"app": app})
    return TransactionRecord(
        id=txn_id,
        status=status,
        catalog_hash=digest_catalog(_CATALOG),
        invocation=inv,
        prev_state=prev if prev is not None else DesiredState(),
        new_state=new if new is not None else DesiredState(apps=(app,)),
        decision=PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok"),
        acks=(),
        rendered_hash="r" * 64,
        flake_lock_hash="l" * 64,
        closure_path="/nix/store/x",
        detail=detail,
    )


# --- derived views ---


def test_installed_and_available_partition_the_catalog():
    model = _model(installed=("firefox", "obsidian"))

    assert [a.id for a in model.installed_apps()] == ["firefox", "obsidian"]
    available_ids = {a.id for a in model.available_apps()}
    assert "firefox" not in available_ids
    assert "obsidian" not in available_ids
    assert "vlc" in available_ids


def test_installed_apps_sorted_by_id():
    model = _model(installed=("chromium", "vlc"))
    assert [a.id for a in model.installed_apps()] == ["chromium", "vlc"]


# --- selection movement ---


def test_move_selection_clamps_at_bounds():
    model = _model(installed=("chromium", "firefox", "vlc"))
    model.pane = model.pane.__class__.INSTALLED

    model.move_selection(-1)
    assert model.index_for(model.pane) == 0

    for _ in range(10):
        model.move_selection(1)
    assert model.index_for(model.pane) == 2


def test_move_selection_on_empty_pane_is_a_noop():
    model = _model(installed=())
    model.move_selection(1)
    assert model.index_for(model.pane) == 0
    assert model.selected_installed() is None


def test_cycle_pane_wraps_around():
    from intentd.picker import Pane

    model = _model()
    assert model.pane is Pane.INSTALLED
    model.cycle_pane(-1)
    assert model.pane is Pane.HISTORY
    model.cycle_pane(1)
    assert model.pane is Pane.INSTALLED
    model.cycle_pane(1)
    assert model.pane is Pane.AVAILABLE


def test_switch_and_move_clear_a_pending_ack():
    from intentd.picker import Pane

    model = _model()
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "obsidian"})
    decision = PolicyDecision(
        verdict=PolicyVerdict.NEEDS_ACK, reason="needs ack", required_acks=("obsidian",)
    )
    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=None)
    )
    assert model.pending_ack is not None

    model.switch_pane(Pane.AVAILABLE)
    assert model.pending_ack is None

    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=None)
    )
    assert model.pending_ack is not None
    model.move_selection(1)
    assert model.pending_ack is None


# --- action construction: resolve_invocation must accept everything built ---


def test_request_install_builds_a_valid_free_app_invocation():
    model = _model()
    _select_available(model, "firefox")

    request = model.request_install()

    assert request is not None
    assert request.invocation.capability == "app.install"
    assert request.invocation.params == {"app": "firefox"}
    assert request.acks == frozenset()
    # resolve_invocation must accept the built invocation without raising.
    resolve_invocation(_CATALOG, "app.install", dict(request.invocation.params))


def test_request_install_with_nothing_available_returns_none_and_sets_status():
    all_ids = tuple(sorted(_CATALOG))
    model = _model(installed=all_ids)

    request = model.request_install()

    assert request is None
    assert "no available app" in model.status


def test_request_remove_builds_a_valid_invocation():
    model = _model(installed=("firefox",))

    request = model.request_remove()

    assert request is not None
    assert request.invocation.capability == "app.remove"
    assert request.invocation.params == {"app": "firefox"}


def test_request_remove_with_nothing_installed_returns_none_and_sets_status():
    model = _model(installed=())

    request = model.request_remove()

    assert request is None
    assert "no installed app" in model.status


def test_request_revert_builds_change_revert_invocation():
    model = _model()

    request = model.request_revert()

    assert request.invocation.capability == "change.revert"
    assert request.invocation.params == {}


# --- unfree-ack gating ---


def test_request_install_unfree_app_first_press_has_no_acks():
    model = _model()
    _select_available(model, "obsidian")

    request = model.request_install()

    assert request is not None
    assert request.acks == frozenset()


def test_needs_ack_result_sets_pending_ack_from_the_real_decision():
    model = _model()
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "obsidian"})
    request = ActionRequest(invocation=inv, acks=frozenset())
    decision = PolicyDecision(
        verdict=PolicyVerdict.NEEDS_ACK,
        reason="Obsidian has an unfree license that needs acceptance",
        required_acks=("obsidian",),
    )

    model.on_apply_result(request, ApplyResult(decision=decision, record=None))

    assert model.pending_ack is not None
    assert model.pending_ack.app_id == "obsidian"
    assert model.pending_ack.reason == decision.reason
    assert model.pending_ack.required_acks == frozenset({"obsidian"})
    assert model.status == decision.reason


def test_second_install_press_on_same_pending_app_reissues_with_acks():
    model = _model()
    _select_available(model, "obsidian")

    inv = resolve_invocation(_CATALOG, "app.install", {"app": "obsidian"})
    decision = PolicyDecision(
        verdict=PolicyVerdict.NEEDS_ACK,
        reason="Obsidian has an unfree license that needs acceptance",
        required_acks=("obsidian",),
    )
    model.on_apply_result(
        ActionRequest(invocation=inv, acks=frozenset()), ApplyResult(decision=decision, record=None)
    )

    second = model.request_install()

    assert second is not None
    assert second.acks == frozenset({"obsidian"})
    assert second.invocation.params == {"app": "obsidian"}


def test_pending_ack_for_one_app_does_not_leak_to_a_different_selection():
    model = _model()
    _select_available(model, "obsidian")
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "obsidian"})
    decision = PolicyDecision(
        verdict=PolicyVerdict.NEEDS_ACK, reason="needs ack", required_acks=("obsidian",)
    )
    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=None)
    )

    # Move selection without going through move_selection/switch_pane's
    # clearing logic would be a bug; drive it through move_selection to
    # simulate the user navigating to a different app before pressing i.
    model.move_selection(1)
    firefox_request = model.request_install()

    assert firefox_request is not None
    assert firefox_request.acks == frozenset()


# --- refresh after apply ---


def test_refresh_updates_blessed_state_and_history_and_reclamps_selection():
    model = _model(installed=("firefox", "vlc"))
    from intentd.picker import Pane

    model.pane = Pane.INSTALLED
    model.move_selection(1)  # select vlc (index 1)
    assert model.index_for(Pane.INSTALLED) == 1

    record = _record("vlc", TxnStatus.BLESSED, txn_id=2, new=DesiredState(apps=("firefox",)))
    model.refresh(DesiredState(apps=("firefox",)), [record])

    assert [a.id for a in model.installed_apps()] == ["firefox"]
    assert model.index_for(Pane.INSTALLED) == 0
    assert model.recent_history() == [record]


def test_on_apply_result_blessed_sets_status_with_txn_id():
    model = _model()
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "firefox"})
    record = _record("firefox", TxnStatus.BLESSED, txn_id=5)
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")

    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=record)
    )

    assert "5" in model.status
    assert "blessed" in model.status
    assert model.pending_ack is None


def test_on_apply_result_reject_sets_status_and_clears_pending_ack():
    model = _model()
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "firefox"})
    decision = PolicyDecision(verdict=PolicyVerdict.REJECT, reason="not on allowlist")

    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=None)
    )

    assert "not on allowlist" in model.status
    assert model.pending_ack is None


def test_on_apply_result_aborted_reports_status_with_detail():
    model = _model()
    inv = resolve_invocation(_CATALOG, "app.install", {"app": "vlc"})
    record = _record(
        "vlc", TxnStatus.ABORTED, txn_id=9, detail="health check found new failed units"
    )
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")

    model.on_apply_result(
        ActionRequest(invocation=inv), ApplyResult(decision=decision, record=record)
    )

    assert "aborted" in model.status
    assert "health check found new failed units" in model.status


# --- Textual pilot smoke test ---


def _fake_deps(tmp_path: Path) -> Deps:
    ws = tmp_path / "ws"
    init_workspace(ws)
    store = make_store(tmp_path)
    return Deps(
        store=store,
        workspace=ws,
        catalog=_CATALOG,
        machine_profile=vm_machine_profile(),
        build=lambda p: ("/nix/store/unused", "unused"),
        set_profile=lambda c: None,
        activate=lambda c: 0,
        failed_units=lambda: frozenset(),
        current_profile=lambda: None,
        capture_health=lambda: (_ for _ in ()).throw(AssertionError("unused")),
        inspect_candidate=lambda closure: (_ for _ in ()).throw(AssertionError(closure)),
        verify_artifact=lambda artifact: None,
        retain_artifact=lambda artifact, role: None,
        recovery_artifact=lambda: (_ for _ in ()).throw(AssertionError("unused")),
        install_boot_candidate=lambda closure, candidate, prior: None,
        reboot=lambda: None,
    )


def test_pilot_install_free_app_end_to_end(tmp_path: Path):
    """A minimal Textual pilot smoke test: drive the real App through
    run_test's headless harness (no tty needed) and confirm a key press
    reaches the model and the injected apply_fn."""
    from intentd.orchestrator import apply_intent

    deps = _fake_deps(tmp_path)
    app = PickerApp(deps, apply_intent)

    async def scenario() -> None:
        async with app.run_test() as pilot:
            assert app.model.pane.value == "installed"
            await pilot.press("right")  # -> available pane
            assert app.model.pane.value == "available"
            assert app.model.selected_available() is not None
            firefox_idx = next(
                i for i, a in enumerate(app.model.available_apps()) if a.id == "firefox"
            )
            for _ in range(firefox_idx):
                await pilot.press("down")
            await pilot.press("i")
            assert "firefox" in [a.id for a in app.model.installed_apps()]
            assert "blessed" in app.model.status
            await pilot.press("q")

    asyncio.run(scenario())
