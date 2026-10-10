import json
from collections.abc import Callable
from pathlib import Path

import pytest

from intentd.boot import HealthSnapshot
from intentd.catalog import digest_catalog, load_catalog
from intentd.cli import (
    _VERBS,  # pyright: ignore[reportPrivateUsage]
    CliCtx,
    build_parser,
    cmd_picker,
    resolve_fn_from_env,
    run_cli,
)
from intentd.journal import Payload
from intentd.orchestrator import ApplyResult, Deps
from intentd.policy import PolicyDecision, PolicyVerdict
from intentd.registry import CapabilityInvocation, resolve_invocation
from intentd.render import render
from intentd.resolver import Resolution
from intentd.schema import CatalogApp, GraphicsProfile
from intentd.state import DesiredState
from intentd.txn import TransactionRecord, TxnStatus
from intentd.workspace import init_workspace, write_generated
from tests.helpers import boot_plan_fixture, make_store, vm_machine_profile

_CATALOG_HASH = digest_catalog(load_catalog())

_Catalog = dict[str, CatalogApp]


class _Recorder:
    def __init__(self) -> None:
        self.lines: list[str] = []

    def __call__(self, s: str) -> None:
        self.lines.append(s)


def _fake_deps(
    tmp_path: Path, *, catalog: _Catalog | None = None, current_profile: str | None = None
) -> Deps:
    ws = tmp_path / "ws"
    init_workspace(ws)
    store = make_store(tmp_path)
    return Deps(
        store=store,
        workspace=ws,
        catalog=catalog if catalog is not None else load_catalog(),
        machine_profile=vm_machine_profile(),
        build=lambda p: ("/nix/store/unused", "unused"),
        set_profile=lambda c: None,
        activate=lambda c: 0,
        failed_units=lambda: frozenset(),
        current_profile=lambda: current_profile,
        capture_health=lambda: HealthSnapshot(
            failed_units=(),
            inactive_critical_units=(),
            display_ready=True,
            root_free_bytes=536_870_912,
            esp_free_bytes=268_435_456,
        ),
        inspect_candidate=lambda closure: (_ for _ in ()).throw(AssertionError(closure)),
        verify_artifact=lambda artifact: None,
        retain_artifact=lambda artifact, role: None,
        recovery_artifact=lambda: (_ for _ in ()).throw(AssertionError("unused")),
        install_boot_candidate=lambda closure, candidate, prior: None,
        reboot=lambda: None,
    )


def _record(
    catalog: _Catalog,
    app: str,
    status: TxnStatus,
    *,
    txn_id: int = 1,
    detail: str | None = None,
    prev: DesiredState | None = None,
    new: DesiredState | None = None,
) -> TransactionRecord:
    inv = resolve_invocation(catalog, "app.install", {"app": app})
    return TransactionRecord(
        id=txn_id,
        status=status,
        catalog_hash=digest_catalog(catalog),
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


def _ctx(
    deps: Deps,
    *,
    state_dir: Path,
    resolve_fn: Callable[[str, _Catalog], Resolution] | None = None,
    apply_fn: Callable[[Deps, CapabilityInvocation, frozenset[str]], ApplyResult] | None = None,
    confirm_answers: list[str] | None = None,
) -> tuple[CliCtx, _Recorder, _Recorder]:
    out, err = _Recorder(), _Recorder()
    answers = iter(confirm_answers or [])

    def _default_resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="abstain", reason="unset")

    def _default_apply(
        d: Deps, inv: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        return ApplyResult(PolicyDecision(verdict=PolicyVerdict.REJECT, reason="unset"), None)

    def _confirm(prompt: str) -> str:
        out.lines.append(f"PROMPT: {prompt}")
        return next(answers, "n")

    ctx = CliCtx(
        deps_factory=lambda _sd, _mode: deps,
        resolve_fn=resolve_fn if resolve_fn is not None else _default_resolve,
        apply_fn=apply_fn if apply_fn is not None else _default_apply,
        stdout=out,
        stderr=err,
        confirm=_confirm,
    )
    return ctx, out, err


def _argv(state_dir: Path, verb: str, *rest: str, json_mode: bool = False) -> list[str]:
    base = ["--state-dir", str(state_dir)]
    if json_mode:
        base.append("--json")
    return [*base, verb, *rest]


def _audit_payloads(deps: Deps) -> list[Payload]:
    return [
        record.payload
        for record in deps.store.journal.read_verified()
        if record.event == "audit.outcome"
    ]


# --- do ---


def test_do_content_abstain_exits_2_and_audits(tmp_path: Path):
    deps = _fake_deps(tmp_path)
    state_dir = tmp_path / "state"

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="abstain", reason="ambiguous request")

    ctx, out, err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve)
    rc = run_cli(ctx, _argv(state_dir, "do", "do something vague"))

    assert rc == 2
    assert "ambiguous request" in "\n".join(out.lines)
    assert any("resolving" in line for line in err.lines)
    entry = _audit_payloads(deps)[0]
    assert entry["outcome"] == "content-abstain"
    assert entry["reason"] == "ambiguous request"
    assert "utterance_sha256" in entry


def test_do_infra_abstain_exits_3_and_audits_with_fixed_message(tmp_path: Path):
    deps = _fake_deps(tmp_path)
    state_dir = tmp_path / "state"

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="abstain", reason="model call failed: boom", infrastructure=True)

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve)
    rc = run_cli(ctx, _argv(state_dir, "do", "install firefox"))

    assert rc == 3
    joined = "\n".join(out.lines)
    assert "not a problem with your request" in joined
    entry = _audit_payloads(deps)[0]
    assert entry["outcome"] == "infra-abstain"


def test_do_blessed_prints_summary_and_exits_0(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        record = _record(catalog, "firefox", TxnStatus.BLESSED, txn_id=7)
        return ApplyResult(PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok"), record)

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "do", "install firefox"))

    assert rc == 0
    joined = "\n".join(out.lines)
    assert "7" in joined
    assert "+firefox" in joined
    assert _audit_payloads(deps) == []


def test_do_boot_pending_reports_pending_reboot(tmp_path: Path) -> None:
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    invocation = resolve_invocation(catalog, "hardware.graphics.profile", {"profile": "integrated"})

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=invocation, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        plan = boot_plan_fixture()
        record = TransactionRecord(
            id=8,
            status=TxnStatus.PENDING,
            catalog_hash=_CATALOG_HASH,
            invocation=invocation,
            prev_state=DesiredState(),
            new_state=DesiredState(graphics_profile=GraphicsProfile.INTEGRATED),
            decision=PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok"),
            machine_profile_id=vm_machine_profile().profile_id,
            rendered_hash=plan.rendered_hash,
            flake_lock_hash=plan.flake_lock_hash,
            closure_path=plan.candidate.closure_path,
            boot_plan=plan,
        )
        return ApplyResult(record.decision, record)

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "do", "set integrated graphics", json_mode=True))

    assert rc == 0
    assert json.loads(out.lines[-1]) == {"outcome": "pending-reboot", "txn": 8}


def test_do_policy_reject_exits_2_and_audits(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        return ApplyResult(
            PolicyDecision(verdict=PolicyVerdict.REJECT, reason="not on allowlist"), None
        )

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "do", "install firefox"))

    assert rc == 2
    assert "not on allowlist" in "\n".join(out.lines)
    entry = _audit_payloads(deps)[0]
    assert entry["outcome"] == "policy-reject"


def test_do_needs_ack_json_mode_exits_4_with_required_acks_no_prompt(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "obsidian"})

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        assert acks == frozenset()
        decision = PolicyDecision(
            verdict=PolicyVerdict.NEEDS_ACK,
            reason="Obsidian has an unfree license",
            required_acks=("obsidian",),
        )
        return ApplyResult(decision, None)

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "do", "install obsidian", json_mode=True))

    assert rc == 4
    payload = json.loads(out.lines[-1])
    assert payload["required_acks"] == ["obsidian"]
    assert not any("PROMPT" in line for line in out.lines)
    assert _audit_payloads(deps) == []


def test_do_needs_ack_interactive_yes_reapplies_and_blesses(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "obsidian"})
    calls: list[frozenset[str]] = []

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        calls.append(acks)
        if not acks:
            decision = PolicyDecision(
                verdict=PolicyVerdict.NEEDS_ACK,
                reason="Obsidian has an unfree license",
                required_acks=("obsidian",),
            )
            return ApplyResult(decision, None)
        record = _record(catalog, "obsidian", TxnStatus.BLESSED, txn_id=3)
        return ApplyResult(PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok"), record)

    ctx, out, _err = _ctx(
        deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply, confirm_answers=["y"]
    )
    rc = run_cli(ctx, _argv(state_dir, "do", "install obsidian"))

    assert rc == 0
    assert calls == [frozenset(), frozenset({"obsidian"})]
    assert "3" in "\n".join(out.lines)


def test_do_needs_ack_interactive_no_declines_and_audits(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "obsidian"})
    calls: list[frozenset[str]] = []

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        calls.append(acks)
        decision = PolicyDecision(
            verdict=PolicyVerdict.NEEDS_ACK,
            reason="Obsidian has an unfree license",
            required_acks=("obsidian",),
        )
        return ApplyResult(decision, None)

    ctx, _out, _err = _ctx(
        deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply, confirm_answers=["n"]
    )
    rc = run_cli(ctx, _argv(state_dir, "do", "install obsidian"))

    assert rc == 2
    assert calls == [frozenset()]
    entry = _audit_payloads(deps)[0]
    assert entry["outcome"] == "needs-ack-declined"


def test_do_aborted_exits_5_with_detail_and_restore_confirmation(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "vlc"})

    def resolve(u: str, c: _Catalog) -> Resolution:
        return Resolution(action="invoke", invocation=inv, reason="ok")

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        record = _record(
            catalog,
            "vlc",
            TxnStatus.ABORTED,
            txn_id=9,
            detail="health check found new failed units",
        )
        return ApplyResult(PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok"), record)

    ctx, out, _err = _ctx(deps, state_dir=state_dir, resolve_fn=resolve, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "do", "install vlc"))

    assert rc == 5
    joined = "\n".join(out.lines)
    assert "health check found new failed units" in joined
    assert "restore" in joined.lower()


# --- history ---


def test_history_lists_recent_transactions(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")
    deps.store.propose(
        inv,
        DesiredState(),
        DesiredState(apps=("firefox",)),
        decision=decision,
        catalog_hash=_CATALOG_HASH,
    )

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "history", "5", json_mode=True))

    assert rc == 0
    payload = json.loads(out.lines[-1])
    assert len(payload) == 1
    assert payload[0]["capability"] == "app.install"
    assert payload[0]["params"] == {"app": "firefox"}


# --- revert ---


def test_revert_success_applies_change_revert_invocation(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    seen: list[CapabilityInvocation] = []

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        seen.append(invocation)
        record = _record(
            catalog,
            "firefox",
            TxnStatus.BLESSED,
            txn_id=4,
            prev=DesiredState(apps=("firefox",)),
            new=DesiredState(),
        )
        return ApplyResult(
            PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="revert"), record
        )

    ctx, out, _err = _ctx(deps, state_dir=state_dir, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "revert"))

    assert rc == 0
    assert seen[0].capability == "change.revert"
    assert "-firefox" in "\n".join(out.lines)


def test_revert_policy_reject_exits_2(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"

    def apply(
        d: Deps, invocation: CapabilityInvocation, acks: frozenset[str] = frozenset()
    ) -> ApplyResult:
        return ApplyResult(
            PolicyDecision(verdict=PolicyVerdict.REJECT, reason="no blessed transaction to revert"),
            None,
        )

    ctx, out, _err = _ctx(deps, state_dir=state_dir, apply_fn=apply)
    rc = run_cli(ctx, _argv(state_dir, "revert"))

    assert rc == 2
    assert "no blessed transaction to revert" in "\n".join(out.lines)
    entry = _audit_payloads(deps)[0]
    assert entry["outcome"] == "policy-reject"
    assert "utterance" not in entry
    assert "utterance_sha256" not in entry


# --- explain ---


def test_explain_default_picks_most_recent_txn(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")
    txn = deps.store.propose(
        inv,
        DesiredState(),
        DesiredState(apps=("firefox",)),
        decision=decision,
        catalog_hash=_CATALOG_HASH,
    )
    deps.store.transition(txn, TxnStatus.VALIDATED, rendered_hash="r" * 64)

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "explain"))

    assert rc == 0
    joined = "\n".join(out.lines)
    assert str(txn) in joined
    assert "validated" in joined


def test_explain_with_explicit_txn_id(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog)
    state_dir = tmp_path / "state"
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")
    txn = deps.store.propose(
        inv,
        DesiredState(),
        DesiredState(apps=("firefox",)),
        decision=decision,
        catalog_hash=_CATALOG_HASH,
    )

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "explain", str(txn), json_mode=True))

    assert rc == 0
    payload = json.loads(out.lines[-1])
    assert payload["id"] == txn
    assert payload["events"][0]["status"] == "proposed"


def test_explain_unknown_txn_returns_error(tmp_path: Path):
    deps = _fake_deps(tmp_path)
    state_dir = tmp_path / "state"

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "explain", "999"))

    assert rc == 1
    assert "999" in "\n".join(out.lines)


def test_explain_with_no_transactions_reports_empty(tmp_path: Path):
    deps = _fake_deps(tmp_path)
    state_dir = tmp_path / "state"

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "explain"))

    assert rc == 0
    assert "no transactions" in "\n".join(out.lines).lower()


# --- status ---


def _bless_firefox(deps: Deps, catalog: _Catalog) -> TransactionRecord:
    inv = resolve_invocation(catalog, "app.install", {"app": "firefox"})
    decision = PolicyDecision(verdict=PolicyVerdict.AUTO_APPLY, reason="ok")
    new_state = DesiredState(apps=("firefox",))
    txn = deps.store.propose(
        inv, DesiredState(), new_state, decision=decision, catalog_hash=_CATALOG_HASH
    )
    rendered = render(new_state, catalog, deps.machine_profile)
    write_generated(deps.workspace, rendered)
    deps.store.transition(txn, TxnStatus.VALIDATED, rendered_hash="ignored-not-checked")
    deps.store.transition(
        txn, TxnStatus.BUILT, closure_path="/nix/store/ff", flake_lock_hash="l" * 64
    )
    deps.store.transition(txn, TxnStatus.PENDING)
    deps.store.transition(txn, TxnStatus.BLESSED)
    return deps.store.get(txn)


def test_status_clean_exits_0(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog, current_profile="/nix/store/ff")
    state_dir = tmp_path / "state"
    _bless_firefox(deps, catalog)

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "status"))

    assert rc == 0
    assert not any("warning" in line.lower() for line in out.lines)


def test_status_dirty_workspace_exits_6(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog, current_profile="/nix/store/ff")
    state_dir = tmp_path / "state"
    _bless_firefox(deps, catalog)
    (deps.workspace / "generated.nix").write_text("# tampered\n")

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "status"))

    assert rc == 6
    assert any("workspace differs from blessed state" in line for line in out.lines)


def test_status_dirty_profile_exits_6(tmp_path: Path):
    catalog = load_catalog()
    deps = _fake_deps(tmp_path, catalog=catalog, current_profile="/nix/store/something-else")
    state_dir = tmp_path / "state"
    _bless_firefox(deps, catalog)

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "status"))

    assert rc == 6
    assert any("system profile differs from blessed closure" in line for line in out.lines)


def test_status_fresh_system_is_clean(tmp_path: Path):
    deps = _fake_deps(tmp_path, current_profile=None)
    state_dir = tmp_path / "state"

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "status"))

    assert rc == 0
    assert not any("warning" in line.lower() for line in out.lines)


# --- apps ---


def test_apps_lists_catalog_with_unfree_flags(tmp_path: Path):
    deps = _fake_deps(tmp_path)
    state_dir = tmp_path / "state"

    ctx, out, _err = _ctx(deps, state_dir=state_dir)
    rc = run_cli(ctx, _argv(state_dir, "apps", json_mode=True))

    assert rc == 0
    payload = json.loads(out.lines[-1])
    by_id = {a["id"]: a for a in payload}
    assert by_id["obsidian"]["unfree"] is True
    assert by_id["firefox"]["unfree"] is False


# --- resolver stub seam (offline VM scenarios) ---


def test_resolver_stub_env_resolves_canned_invoke_reply(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    stub = tmp_path / "stub.json"
    stub.write_text(
        json.dumps(
            {
                "action": "invoke",
                "capability": "app.install",
                "params": {"app": "firefox"},
                "reason": "canned",
            }
        )
    )
    monkeypatch.setenv("INTENTD_RESOLVER_STUB", str(stub))

    resolution = resolve_fn_from_env()("install firefox", load_catalog())

    assert resolution.action == "invoke"
    assert resolution.invocation is not None
    assert resolution.invocation.capability == "app.install"
    assert dict(resolution.invocation.params) == {"app": "firefox"}
    assert resolution.infrastructure is False


def test_resolver_stub_reply_still_validated_against_catalog(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    stub = tmp_path / "stub.json"
    stub.write_text(
        json.dumps(
            {
                "action": "invoke",
                "capability": "app.install",
                "params": {"app": "not-in-catalog"},
                "reason": "canned",
            }
        )
    )
    monkeypatch.setenv("INTENTD_RESOLVER_STUB", str(stub))

    resolution = resolve_fn_from_env()("install whatever", load_catalog())

    assert resolution.action == "abstain"
    assert "invocation rejected" in resolution.reason


def test_resolver_stub_invalid_json_abstains(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    stub = tmp_path / "stub.json"
    stub.write_text("not json")
    monkeypatch.setenv("INTENTD_RESOLVER_STUB", str(stub))

    resolution = resolve_fn_from_env()("install firefox", load_catalog())

    assert resolution.action == "abstain"
    assert "invalid JSON reply" in resolution.reason


def test_resolver_default_path_uses_run_claude(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("INTENTD_RESOLVER_STUB", raising=False)
    prompts: list[str] = []

    def fake_run_claude(prompt: str) -> str:
        prompts.append(prompt)
        return json.dumps(
            {
                "action": "invoke",
                "capability": "app.install",
                "params": {"app": "firefox"},
                "reason": "live",
            }
        )

    monkeypatch.setattr("intentd.cli.run_claude", fake_run_claude)

    resolution = resolve_fn_from_env()("install firefox", load_catalog())

    assert resolution.action == "invoke"
    assert len(prompts) == 1
    assert "install firefox" in prompts[0]


# --- picker ---


def test_picker_verb_is_registered_and_parses(tmp_path: Path):
    args = build_parser().parse_args(_argv(tmp_path, "picker"))
    assert args.verb == "picker"
    assert _VERBS["picker"] is cmd_picker
