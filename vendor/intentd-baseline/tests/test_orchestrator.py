import json
from pathlib import Path

import pytest

from intentd.boot import BootArtifact, BootError, HealthSnapshot
from intentd.catalog import digest_catalog, load_catalog
from intentd.executor import ExecError, rendered_sha256
from intentd.orchestrator import Deps, apply_intent, startup_reconcile
from intentd.policy import PolicyVerdict, evaluate
from intentd.registry import CapabilityInvocation, resolve_invocation
from intentd.render import render
from intentd.schema import CatalogApp
from intentd.state import DesiredState
from intentd.store import StoreError, TransactionStore
from intentd.txn import TxnStatus
from intentd.workspace import TamperError, init_workspace, verify_workspace, write_generated
from tests.helpers import boot_artifact_fixture, make_store, vm_machine_profile

_CATALOG_HASH = digest_catalog(load_catalog())

_Catalog = dict[str, CatalogApp]


def _install(catalog: _Catalog, app: str) -> CapabilityInvocation:
    return resolve_invocation(catalog, "app.install", {"app": app})


def _revert(catalog: _Catalog) -> CapabilityInvocation:
    return resolve_invocation(catalog, "change.revert", {})


class _Fakes:
    def __init__(
        self,
        *,
        closure: str = "/nix/store/closure",
        lock_pin: str = "b" * 64,
        build_fails: bool = False,
        activate_fails_on_call: int | None = None,
        activate_rc: int = 0,
        units: list[frozenset[str]] | None = None,
        pre_profile: str | None = "/nix/store/pre-profile",
        root_free_bytes: int = 536_870_912,
        esp_free_bytes: int = 268_435_456,
        verify_fails_for: str | None = None,
        set_profile_fails: bool = False,
        install_fails: bool = False,
        reboot_fails: bool = False,
        recovery_fails: bool = False,
    ) -> None:
        self.calls: list[tuple[str, ...]] = []
        self.closure = closure
        self.lock_pin = lock_pin
        self._build_fails = build_fails
        self._activate_fails_on_call = activate_fails_on_call
        self._activate_calls = 0
        self._activate_rc = activate_rc
        self._pre_profile = pre_profile
        self._root_free_bytes = root_free_bytes
        self._esp_free_bytes = esp_free_bytes
        self._verify_fails_for = verify_fails_for
        self._set_profile_fails = set_profile_fails
        self._install_fails = install_fails
        self._reboot_fails = reboot_fails
        self._recovery_fails = recovery_fails
        default_units: list[frozenset[str]] = [frozenset(), frozenset()]
        self._units_iter = iter(units if units is not None else default_units)

    def build(self, path: Path) -> tuple[str, str]:
        self.calls.append(("build", str(path)))
        if self._build_fails:
            raise ExecError("nix build failed: boom")
        return (self.closure, self.lock_pin)

    def set_profile(self, closure: str) -> None:
        self.calls.append(("set_profile", closure))
        if self._set_profile_fails:
            raise ExecError("set profile failed: boom")

    def activate(self, closure: str) -> int:
        self.calls.append(("activate", closure))
        self._activate_calls += 1
        if self._activate_calls == self._activate_fails_on_call:
            raise ExecError("switch-to-configuration failed: boom")
        return self._activate_rc

    def failed_units(self) -> frozenset[str]:
        self.calls.append(("failed_units",))
        return next(self._units_iter)

    def current_profile(self) -> str | None:
        self.calls.append(("current_profile",))
        return self._pre_profile

    def capture_health(self) -> HealthSnapshot:
        self.calls.append(("capture_health",))
        return HealthSnapshot(
            failed_units=(),
            inactive_critical_units=(),
            display_ready=True,
            root_free_bytes=self._root_free_bytes,
            esp_free_bytes=self._esp_free_bytes,
        )

    def inspect_candidate(self, closure: str) -> BootArtifact:
        self.calls.append(("inspect_candidate", closure))
        return boot_artifact_fixture(closure_path=closure)

    def verify_artifact(self, artifact: BootArtifact) -> None:
        self.calls.append(("verify_artifact", artifact.entry_id))
        if artifact.entry_id == self._verify_fails_for:
            raise BootError(f"artifact verification failed: {artifact.entry_id}")

    def retain_artifact(self, artifact: BootArtifact, role: str) -> None:
        self.calls.append(("retain_artifact", role, artifact.entry_id))

    def recovery_artifact(self) -> BootArtifact:
        self.calls.append(("recovery_artifact",))
        if self._recovery_fails:
            raise BootError("missing recovery artifact")
        return boot_artifact_fixture(
            closure_path="/nix/store/recovery",
            entry_id="recovery.efi",
            uki_sha256="e" * 64,
        )

    def install_boot_candidate(
        self,
        closure: str,
        candidate_entry_id: str,
        prior_entry_id: str,
    ) -> None:
        self.calls.append(
            (
                "install_boot_candidate",
                closure,
                candidate_entry_id,
                prior_entry_id,
            )
        )
        if self._install_fails:
            raise ExecError("boot installation failed: boom")

    def reboot(self) -> None:
        self.calls.append(("reboot",))
        if self._reboot_fails:
            raise ExecError("reboot failed: boom")


def _fresh_workspace_and_store(tmp_path: Path) -> tuple[Path, TransactionStore]:
    ws = tmp_path / "ws"
    init_workspace(ws)
    store = make_store(tmp_path)
    return ws, store


def _make_deps(store: TransactionStore, ws: Path, catalog: _Catalog, fakes: _Fakes) -> Deps:
    return Deps(
        store=store,
        workspace=ws,
        catalog=catalog,
        machine_profile=vm_machine_profile(),
        build=fakes.build,
        set_profile=fakes.set_profile,
        activate=fakes.activate,
        failed_units=fakes.failed_units,
        current_profile=fakes.current_profile,
        capture_health=fakes.capture_health,
        inspect_candidate=fakes.inspect_candidate,
        verify_artifact=fakes.verify_artifact,
        retain_artifact=fakes.retain_artifact,
        recovery_artifact=fakes.recovery_artifact,
        install_boot_candidate=fakes.install_boot_candidate,
        reboot=fakes.reboot,
    )


def _deps(tmp_path: Path, catalog: _Catalog, fakes: _Fakes) -> Deps:
    ws, store = _fresh_workspace_and_store(tmp_path)
    return _make_deps(store, ws, catalog, fakes)


def _seed_blessed_boot(store: TransactionStore, ws: Path, catalog: _Catalog) -> BootArtifact:
    fakes = _Fakes(closure="/nix/store/blessed", lock_pin="a" * 64)
    result = apply_intent(_make_deps(store, ws, catalog, fakes), _install(catalog, "firefox"))
    assert result.record is not None
    artifact = boot_artifact_fixture(
        closure_path="/nix/store/blessed",
        entry_id="blessed.efi",
        uki_sha256="d" * 64,
    )
    store.anchor_blessed_boot(result.record.id, artifact)
    return artifact


def _graphics() -> CapabilityInvocation:
    return resolve_invocation({}, "hardware.graphics.profile", {"profile": "integrated"})


def test_boot_affecting_apply_stages_and_returns_pending(tmp_path: Path) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)
    fakes = _Fakes(closure="/nix/store/graphics-candidate", lock_pin="b" * 64)

    result = apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    assert result.record is not None
    assert result.record.status is TxnStatus.PENDING
    assert result.record.boot_plan is not None
    assert result.record.boot_plan.root_reserve_bytes == 268_435_456
    assert result.record.boot_plan.esp_reserve_bytes == 134_217_728
    assert result.record.boot_plan.candidate.gc_root == (
        f"/var/lib/intentd/gcroots/candidate-{result.record.id}"
    )
    assert result.record.boot_plan.prior_blessed.gc_root == ("/var/lib/intentd/gcroots/blessed")
    assert result.record.boot_plan.recovery.gc_root == ("/var/lib/intentd/gcroots/recovery")
    assert fakes.calls[1:] == [
        ("capture_health",),
        ("inspect_candidate", "/nix/store/graphics-candidate"),
        ("verify_artifact", "blessed.efi"),
        ("recovery_artifact",),
        ("verify_artifact", "recovery.efi"),
        ("verify_artifact", "graphics-candidate.efi"),
        ("retain_artifact", "blessed", "blessed.efi"),
        ("retain_artifact", "recovery", "recovery.efi"),
        (
            "retain_artifact",
            f"candidate-{result.record.id}",
            "graphics-candidate.efi",
        ),
        ("set_profile", "/nix/store/graphics-candidate"),
        (
            "install_boot_candidate",
            "/nix/store/graphics-candidate",
            "graphics-candidate.efi",
            "blessed.efi",
        ),
        ("reboot",),
    ]


@pytest.mark.parametrize(
    ("fakes", "detail"),
    [
        (_Fakes(root_free_bytes=1), "root free space"),
        (_Fakes(esp_free_bytes=134_217_728 + 4095), "ESP free space"),
        (_Fakes(verify_fails_for="graphics-candidate.efi"), "artifact verification"),
    ],
)
def test_boot_preflight_failure_rejects_without_reboot(
    tmp_path: Path, fakes: _Fakes, detail: str
) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)

    result = apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert detail in (result.record.detail or "")
    assert store.in_flight() is None
    assert ("reboot",) not in fakes.calls
    assert not [
        call for call in fakes.calls if call[0] in ("set_profile", "install_boot_candidate")
    ]


def test_missing_blessed_boot_anchor_rejects_without_reboot(tmp_path: Path) -> None:
    catalog = load_catalog()
    fakes = _Fakes()
    deps = _deps(tmp_path, catalog, fakes)

    result = apply_intent(deps, _graphics())

    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert result.record.detail == "missing authenticated blessed boot anchor"
    assert ("reboot",) not in fakes.calls


def test_missing_recovery_artifact_rejects_without_reboot(tmp_path: Path) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)
    fakes = _Fakes(recovery_fails=True)

    result = apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert result.record.detail == "missing recovery artifact"
    assert ("reboot",) not in fakes.calls


def test_pending_journal_failure_prevents_reboot(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)
    fakes = _Fakes()
    transition = store.transition

    def fail_pending(txn_id: int, to_status: TxnStatus, **kwargs: object) -> None:
        if to_status is TxnStatus.PENDING and kwargs.get("boot_plan") is not None:
            raise StoreError("journal append failed")
        transition(txn_id, to_status, **kwargs)  # pyright: ignore[reportArgumentType]

    monkeypatch.setattr(store, "transition", fail_pending)

    with pytest.raises(StoreError, match="journal append failed"):
        apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    assert ("reboot",) not in fakes.calls


def test_boot_abort_journal_failure_surfaces_without_partial_abort(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)
    blessed_before = store.blessed()
    assert blessed_before is not None
    fakes = _Fakes(install_fails=True)
    transition = store.transition

    def fail_abort(txn_id: int, to_status: TxnStatus, **kwargs: object) -> None:
        if to_status is TxnStatus.ABORTED:
            raise StoreError("journal append failed")
        transition(txn_id, to_status, **kwargs)  # pyright: ignore[reportArgumentType]

    monkeypatch.setattr(store, "transition", fail_abort)

    with pytest.raises(StoreError, match="journal append failed"):
        apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    pending = store.in_flight()
    assert pending is not None
    assert pending.status is TxnStatus.PENDING
    assert pending.boot_outcome is None
    assert pending.boot_staging_failure is None
    blessed_after = store.blessed()
    assert blessed_after is not None and blessed_after.id == blessed_before.id
    assert ("reboot",) not in fakes.calls


@pytest.mark.parametrize(
    ("fakes", "phase"),
    [
        (_Fakes(set_profile_fails=True), "set-profile"),
        (_Fakes(install_fails=True), "install-candidate"),
    ],
)
def test_boot_post_pending_failure_aborts_with_authenticated_staging_evidence(
    tmp_path: Path, fakes: _Fakes, phase: str
) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)

    result = apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    assert result.record is not None
    assert result.record.status is TxnStatus.ABORTED
    assert result.record.boot_staging_failure is not None
    assert result.record.boot_staging_failure.phase.value == phase
    assert ("reboot",) not in fakes.calls


def test_reboot_failure_leaves_boot_transaction_pending(tmp_path: Path) -> None:
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    _seed_blessed_boot(store, ws, catalog)
    fakes = _Fakes(reboot_fails=True)

    with pytest.raises(ExecError, match="reboot failed"):
        apply_intent(_make_deps(store, ws, catalog, fakes), _graphics())

    pending = store.in_flight()
    assert pending is not None
    assert pending.status is TxnStatus.PENDING
    assert pending.boot_plan is not None

    startup_reconcile(_make_deps(store, ws, catalog, fakes))

    reconciled = store.in_flight()
    assert reconciled is not None
    assert reconciled.status is TxnStatus.PENDING


def test_happy_install_blesses_with_correct_evidence_hashes(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes(closure="/nix/store/firefox-closure", lock_pin="lock-a")
    deps = _deps(tmp_path, catalog, fakes)
    inv = _install(catalog, "firefox")

    result = apply_intent(deps, inv)

    assert result.decision.verdict is PolicyVerdict.AUTO_APPLY
    assert result.record is not None
    assert result.record.status is TxnStatus.BLESSED
    rendered = render(DesiredState(apps=("firefox",)), catalog, deps.machine_profile)
    assert result.record.rendered_hash == rendered_sha256(rendered)
    assert result.record.closure_path == "/nix/store/firefox-closure"
    assert result.record.flake_lock_hash == "lock-a"
    assert deps.store.blessed_state() == DesiredState(apps=("firefox",))
    assert fakes.calls == [
        ("build", str(deps.workspace)),
        ("failed_units",),
        ("current_profile",),
        ("set_profile", "/nix/store/firefox-closure"),
        ("activate", "/nix/store/firefox-closure"),
        ("failed_units",),
    ]


def test_unfree_install_without_ack_returns_needs_ack_and_creates_no_transaction(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes()
    deps = _deps(tmp_path, catalog, fakes)
    inv = _install(catalog, "obsidian")

    result = apply_intent(deps, inv)

    assert result.decision.verdict is PolicyVerdict.NEEDS_ACK
    assert result.decision.required_acks == ("obsidian",)
    assert result.record is None
    assert deps.store.in_flight() is None
    assert deps.store.blessed() is None
    assert fakes.calls == []


def test_unfree_install_with_ack_blesses(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes()
    deps = _deps(tmp_path, catalog, fakes)
    inv = _install(catalog, "obsidian")

    result = apply_intent(deps, inv, acks=frozenset({"obsidian"}))

    assert result.decision.verdict is PolicyVerdict.AUTO_APPLY
    assert result.record is not None
    assert result.record.status is TxnStatus.BLESSED
    assert result.record.acks == ("obsidian",)


def test_render_failure_rejects(tmp_path: Path):
    catalog = dict(load_catalog())
    catalog["firefox"] = catalog["firefox"].model_copy(update={"attr": "if"})
    fakes = _Fakes()
    deps = _deps(tmp_path, catalog, fakes)
    inv = _install(catalog, "firefox")

    result = apply_intent(deps, inv)

    assert result.decision.verdict is PolicyVerdict.AUTO_APPLY
    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert "audited constructor" in (result.record.detail or "")
    assert fakes.calls == []


def test_build_failure_rejects(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes(build_fails=True)
    deps = _deps(tmp_path, catalog, fakes)
    inv = _install(catalog, "firefox")

    result = apply_intent(deps, inv)

    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert "nix build failed" in (result.record.detail or "")
    assert fakes.calls == [("build", str(deps.workspace))]


def test_fresh_health_failure_aborts_restores_workspace_and_reactivates_blessed(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)

    fakes1 = _Fakes(closure="/nix/store/firefox-closure", lock_pin="lock-a")
    deps1 = _make_deps(store, ws, catalog, fakes1)
    first = apply_intent(deps1, _install(catalog, "firefox"))
    assert first.record is not None and first.record.status is TxnStatus.BLESSED
    blessed_closure = first.record.closure_path
    assert blessed_closure == "/nix/store/firefox-closure"

    fakes2 = _Fakes(
        closure="/nix/store/vlc-closure",
        lock_pin="lock-b",
        units=[frozenset(), frozenset({"broken.service"})],
    )
    deps2 = _make_deps(store, ws, catalog, fakes2)
    second = apply_intent(deps2, _install(catalog, "vlc"))

    assert second.record is not None
    assert second.record.status is TxnStatus.ABORTED
    assert "broken.service" in (second.record.detail or "")
    active = store.active()
    assert active is not None and active.id == first.record.id
    assert store.blessed_state() == DesiredState(apps=("firefox",))
    expected_rendered = render(DesiredState(apps=("firefox",)), catalog, deps2.machine_profile)
    assert (ws / "generated.nix").read_text() == expected_rendered
    assert fakes2.calls == [
        ("build", str(ws)),
        ("failed_units",),
        ("current_profile",),
        ("set_profile", "/nix/store/vlc-closure"),
        ("activate", "/nix/store/vlc-closure"),
        ("failed_units",),
        ("set_profile", "/nix/store/firefox-closure"),
        ("activate", "/nix/store/firefox-closure"),
    ]


def test_activation_error_aborts_with_exception_text_and_restores(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)

    fakes1 = _Fakes(closure="/nix/store/firefox-closure", lock_pin="lock-a")
    deps1 = _make_deps(store, ws, catalog, fakes1)
    first = apply_intent(deps1, _install(catalog, "firefox"))
    assert first.record is not None and first.record.status is TxnStatus.BLESSED

    fakes2 = _Fakes(
        closure="/nix/store/vlc-closure",
        lock_pin="lock-b",
        activate_fails_on_call=1,
    )
    deps2 = _make_deps(store, ws, catalog, fakes2)
    second = apply_intent(deps2, _install(catalog, "vlc"))

    assert second.record is not None
    assert second.record.status is TxnStatus.ABORTED
    assert "switch-to-configuration failed: boom" in (second.record.detail or "")
    assert store.blessed_state() == DesiredState(apps=("firefox",))
    expected_rendered = render(DesiredState(apps=("firefox",)), catalog, deps2.machine_profile)
    assert (ws / "generated.nix").read_text() == expected_rendered
    assert fakes2.calls == [
        ("build", str(ws)),
        ("failed_units",),
        ("current_profile",),
        ("set_profile", "/nix/store/vlc-closure"),
        ("activate", "/nix/store/vlc-closure"),
        ("failed_units",),
        ("set_profile", "/nix/store/firefox-closure"),
        ("activate", "/nix/store/firefox-closure"),
    ]


def test_restore_failure_propagates_with_durable_event(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)

    fakes1 = _Fakes(closure="/nix/store/firefox-closure", lock_pin="lock-a")
    deps1 = _make_deps(store, ws, catalog, fakes1)
    first = apply_intent(deps1, _install(catalog, "firefox"))
    assert first.record is not None and first.record.status is TxnStatus.BLESSED

    fakes2 = _Fakes(
        closure="/nix/store/vlc-closure",
        lock_pin="lock-b",
        units=[frozenset(), frozenset({"broken.service"})],
        activate_fails_on_call=2,
    )
    deps2 = _make_deps(store, ws, catalog, fakes2)
    with pytest.raises(ExecError, match="switch-to-configuration failed: boom"):
        apply_intent(deps2, _install(catalog, "vlc"))

    aborted = store.recent(1)[0]
    assert aborted.status is TxnStatus.ABORTED
    assert "broken.service" in (aborted.detail or "")
    events = store.events(aborted.id)
    assert events[-1][1] == "aborted"
    assert events[-1][2] == ("restore to blessed failed: switch-to-configuration failed: boom")


def test_first_apply_abort_restores_pre_activation_profile(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes(
        closure="/nix/store/candidate",
        units=[frozenset(), frozenset({"broken.service"})],
        pre_profile="/nix/store/old-system",
    )
    deps = _deps(tmp_path, catalog, fakes)

    result = apply_intent(deps, _install(catalog, "firefox"))

    assert result.record is not None
    assert result.record.status is TxnStatus.ABORTED
    assert deps.store.blessed() is None
    expected_rendered = render(DesiredState(), catalog, deps.machine_profile)
    assert (deps.workspace / "generated.nix").read_text() == expected_rendered
    assert fakes.calls == [
        ("build", str(deps.workspace)),
        ("failed_units",),
        ("current_profile",),
        ("set_profile", "/nix/store/candidate"),
        ("activate", "/nix/store/candidate"),
        ("failed_units",),
        ("set_profile", "/nix/store/old-system"),
        ("activate", "/nix/store/old-system"),
    ]


def test_first_apply_abort_without_restore_target_records_event(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes(
        closure="/nix/store/candidate",
        units=[frozenset(), frozenset({"broken.service"})],
        pre_profile=None,
    )
    deps = _deps(tmp_path, catalog, fakes)

    result = apply_intent(deps, _install(catalog, "firefox"))

    assert result.record is not None
    assert result.record.status is TxnStatus.ABORTED
    events = deps.store.events(result.record.id)
    assert events[-1][1] == "aborted"
    assert events[-1][2] == "no restore target: system profile left on aborted closure"
    assert fakes.calls == [
        ("build", str(deps.workspace)),
        ("failed_units",),
        ("current_profile",),
        ("set_profile", "/nix/store/candidate"),
        ("activate", "/nix/store/candidate"),
        ("failed_units",),
    ]


def test_pre_build_tamper_rejects_before_build(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    import intentd.orchestrator as orchestrator_module

    catalog = load_catalog()
    fakes = _Fakes()
    deps = _deps(tmp_path, catalog, fakes)

    def write_then_tamper(root: Path, rendered: str) -> None:
        write_generated(root, rendered)
        generated = root / "generated.nix"
        generated.write_text(generated.read_text() + "# same-machine edit\n")

    monkeypatch.setattr(orchestrator_module, "write_generated", write_then_tamper)

    result = apply_intent(deps, _install(catalog, "firefox"))

    assert result.record is not None
    assert result.record.status is TxnStatus.REJECTED
    assert "modified outside" in (result.record.detail or "")
    assert fakes.calls == []


def test_rc4_no_fresh_failures_blesses(tmp_path: Path):
    catalog = load_catalog()
    fakes = _Fakes(activate_rc=4)
    deps = _deps(tmp_path, catalog, fakes)

    result = apply_intent(deps, _install(catalog, "firefox"))

    assert result.record is not None
    assert result.record.status is TxnStatus.BLESSED


def test_revert_round_trip(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)

    fakes1 = _Fakes(closure="/nix/store/firefox-closure", lock_pin="lock-a")
    deps1 = _make_deps(store, ws, catalog, fakes1)
    installed = apply_intent(deps1, _install(catalog, "firefox"))
    assert installed.record is not None and installed.record.status is TxnStatus.BLESSED

    fakes2 = _Fakes(closure="/nix/store/empty-closure", lock_pin="lock-empty")
    deps2 = _make_deps(store, ws, catalog, fakes2)
    reverted = apply_intent(deps2, _revert(catalog))

    assert reverted.decision.verdict is PolicyVerdict.AUTO_APPLY
    assert reverted.record is not None
    assert reverted.record.status is TxnStatus.BLESSED
    assert store.blessed_state() == DesiredState()


def test_startup_reconcile_repairs_crash_gap_manifest(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    fakes = _Fakes()
    deps = _make_deps(store, ws, catalog, fakes)
    installed = apply_intent(deps, _install(catalog, "firefox"))
    assert installed.record is not None and installed.record.status is TxnStatus.BLESSED

    manifest_path = ws / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["generated.nix"] = "0" * 64
    manifest_path.write_text(json.dumps(manifest))

    with pytest.raises(TamperError, match="modified outside"):
        verify_workspace(ws)

    startup_reconcile(deps)

    verify_workspace(ws)


def test_startup_reconcile_raises_on_real_tamper(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    fakes = _Fakes()
    deps = _make_deps(store, ws, catalog, fakes)
    installed = apply_intent(deps, _install(catalog, "firefox"))
    assert installed.record is not None

    generated = ws / "generated.nix"
    generated.write_text(generated.read_text() + "# real tamper\n")

    with pytest.raises(TamperError, match="modified outside"):
        startup_reconcile(deps)


def test_startup_reconcile_rejects_interrupted_validated_transaction(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    inv = _install(catalog, "firefox")
    prev = store.blessed_state()
    new = DesiredState(apps=("firefox",))
    decision = evaluate(inv, catalog, prev, new, machine_profile=vm_machine_profile())
    txn = store.propose(inv, prev, new, decision=decision, catalog_hash=_CATALOG_HASH)
    rendered = render(new, catalog, vm_machine_profile())
    write_generated(ws, rendered)
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash=rendered_sha256(rendered))

    fakes = _Fakes()
    deps = _make_deps(store, ws, catalog, fakes)
    startup_reconcile(deps)

    record = store.get(txn)
    assert record.status is TxnStatus.REJECTED
    assert record.detail == "interrupted by restart"
    assert fakes.calls == []


def test_startup_reconcile_aborts_interrupted_pending_transaction(tmp_path: Path):
    catalog = load_catalog()
    ws, store = _fresh_workspace_and_store(tmp_path)
    inv = _install(catalog, "firefox")
    prev = store.blessed_state()
    new = DesiredState(apps=("firefox",))
    decision = evaluate(inv, catalog, prev, new, machine_profile=vm_machine_profile())
    txn = store.propose(inv, prev, new, decision=decision, catalog_hash=_CATALOG_HASH)
    rendered = render(new, catalog, vm_machine_profile())
    write_generated(ws, rendered)
    store.transition(txn, TxnStatus.VALIDATED, rendered_hash=rendered_sha256(rendered))
    store.transition(
        txn, TxnStatus.BUILT, closure_path="/nix/store/firefox-closure", flake_lock_hash="lock-a"
    )
    store.transition(txn, TxnStatus.PENDING)

    fakes = _Fakes()
    deps = _make_deps(store, ws, catalog, fakes)
    startup_reconcile(deps)

    record = store.get(txn)
    assert record.status is TxnStatus.ABORTED
    assert record.detail == "interrupted by restart"
    assert store.blessed() is None
    assert store.active() is None
    expected_rendered = render(DesiredState(), catalog, deps.machine_profile)
    assert (ws / "generated.nix").read_text() == expected_rendered
    assert fakes.calls == []
