import argparse
import json
import os
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

from intentd.audit import append_outcome
from intentd.orchestrator import ApplyResult, Deps
from intentd.picker import PickerApp
from intentd.policy import PolicyVerdict
from intentd.registry import CapabilityInvocation, resolve_invocation
from intentd.render import render
from intentd.resolver import Resolution, resolve_utterance, run_claude
from intentd.schema import CatalogApp
from intentd.store import StoreError
from intentd.txn import TransactionRecord, TxnStatus
from intentd.wiring import apply_with_reconcile, production_deps

_INFRA_MESSAGE = (
    "The resolver service is unavailable (not a problem with your request). Try again shortly."
)

_DEFAULT_STATE_DIR = Path.home() / ".local" / "state" / "intentd"
_DEFAULT_HISTORY_N = 10


@dataclass(frozen=True)
class CliCtx:
    """Injected dependencies for every verb. `main()` wires the real ones;
    tests fake all of them end to end (no nix, no claude)."""

    deps_factory: Callable[[Path, Literal["switch", "test"]], Deps]
    resolve_fn: Callable[[str, dict[str, CatalogApp]], Resolution]
    apply_fn: Callable[[Deps, CapabilityInvocation, frozenset[str]], ApplyResult]
    stdout: Callable[[str], None]
    stderr: Callable[[str], None]
    confirm: Callable[[str], str]


def _emit(ctx: CliCtx, json_mode: bool, payload: dict[str, Any], text: str) -> None:
    if json_mode:
        ctx.stdout(json.dumps(payload))
    else:
        ctx.stdout(text)


def _txn_summary(r: TransactionRecord) -> dict[str, Any]:
    return {
        "id": r.id,
        "status": r.status.value,
        "capability": r.invocation.capability,
        "params": dict(r.invocation.params),
        "detail": r.detail,
    }


def _finish_invocation_result(
    ctx: CliCtx,
    deps: Deps,
    json_mode: bool,
    audit_raw: bool,
    utterance: str | None,
    result: ApplyResult,
) -> int:
    decision = result.decision
    if decision.verdict is PolicyVerdict.REJECT:
        append_outcome(deps.store.journal, "policy-reject", decision.reason, utterance, audit_raw)
        _emit(
            ctx,
            json_mode,
            {"outcome": "policy-reject", "reason": decision.reason},
            decision.reason,
        )
        return 2

    record = result.record
    if record is None:
        raise AssertionError("unreachable: needs-ack must be resolved before finishing")

    if record.status is TxnStatus.BLESSED:
        added = sorted(set(record.new_state.apps) - set(record.prev_state.apps))
        removed = sorted(set(record.prev_state.apps) - set(record.new_state.apps))
        if json_mode:
            ctx.stdout(
                json.dumps(
                    {"outcome": "blessed", "txn": record.id, "added": added, "removed": removed}
                )
            )
        else:
            delta = " ".join([f"+{a}" for a in added] + [f"-{r}" for r in removed])
            ctx.stdout(f"txn {record.id} blessed: {delta or '(no change)'}")
        return 0

    if record.status is TxnStatus.PENDING and record.boot_plan is not None:
        _emit(
            ctx,
            json_mode,
            {"outcome": "pending-reboot", "txn": record.id},
            f"txn {record.id} pending reboot",
        )
        return 0

    blessed = deps.store.blessed()
    restored = (
        f"restored to blessed transaction {blessed.id}"
        if blessed is not None
        else "restored to the pre-existing system profile (no blessed transaction yet)"
    )
    if json_mode:
        ctx.stdout(
            json.dumps(
                {
                    "outcome": record.status.value,
                    "txn": record.id,
                    "detail": record.detail,
                    "restored": restored,
                }
            )
        )
    else:
        ctx.stdout(f"txn {record.id} {record.status}: {record.detail}")
        ctx.stdout(restored)
    return 5


def cmd_do(ctx: CliCtx, args: argparse.Namespace) -> int:
    state_dir: Path = args.state_dir
    deps = ctx.deps_factory(state_dir, args.activate_mode)
    ctx.stderr("resolving...")
    resolution = ctx.resolve_fn(args.utterance, deps.catalog)

    if resolution.action == "abstain":
        if resolution.infrastructure:
            append_outcome(
                deps.store.journal,
                "infra-abstain",
                resolution.reason,
                args.utterance,
                args.audit_utterances,
            )
            _emit(
                ctx,
                args.json,
                {"outcome": "infra-abstain", "reason": _INFRA_MESSAGE},
                _INFRA_MESSAGE,
            )
            return 3
        append_outcome(
            deps.store.journal,
            "content-abstain",
            resolution.reason,
            args.utterance,
            args.audit_utterances,
        )
        _emit(
            ctx,
            args.json,
            {"outcome": "content-abstain", "reason": resolution.reason},
            resolution.reason,
        )
        return 2

    assert resolution.invocation is not None
    result = ctx.apply_fn(deps, resolution.invocation, frozenset())

    if result.decision.verdict is PolicyVerdict.NEEDS_ACK and result.record is None:
        if args.json:
            ctx.stdout(
                json.dumps(
                    {
                        "outcome": "needs-ack",
                        "reason": result.decision.reason,
                        "required_acks": list(result.decision.required_acks),
                    }
                )
            )
            return 4
        answer = ctx.confirm(f"{result.decision.reason} Proceed? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            append_outcome(
                deps.store.journal,
                "needs-ack-declined",
                result.decision.reason,
                args.utterance,
                args.audit_utterances,
            )
            ctx.stdout("declined; no changes made")
            return 2
        result = ctx.apply_fn(deps, resolution.invocation, frozenset(result.decision.required_acks))

    return _finish_invocation_result(
        ctx, deps, args.json, args.audit_utterances, args.utterance, result
    )


def cmd_history(ctx: CliCtx, args: argparse.Namespace) -> int:
    deps = ctx.deps_factory(args.state_dir, args.activate_mode)
    records = deps.store.recent(args.n)
    if args.json:
        ctx.stdout(json.dumps([_txn_summary(r) for r in records]))
    else:
        if not records:
            ctx.stdout("no transactions recorded yet")
        for r in records:
            ctx.stdout(
                f"{r.id}\t{r.status}\t{r.invocation.capability}\t"
                f"{json.dumps(dict(r.invocation.params))}\t{r.detail or ''}"
            )
    return 0


def cmd_revert(ctx: CliCtx, args: argparse.Namespace) -> int:
    state_dir: Path = args.state_dir
    deps = ctx.deps_factory(state_dir, args.activate_mode)
    invocation = resolve_invocation(deps.catalog, "change.revert", {})
    result = ctx.apply_fn(deps, invocation, frozenset())
    return _finish_invocation_result(ctx, deps, args.json, args.audit_utterances, None, result)


def cmd_explain(ctx: CliCtx, args: argparse.Namespace) -> int:
    deps = ctx.deps_factory(args.state_dir, args.activate_mode)
    txn_id: int | None = args.txn
    if txn_id is None:
        recent = deps.store.recent(1)
        if not recent:
            ctx.stdout("no transactions recorded yet")
            return 0
        txn_id = recent[0].id

    try:
        record = deps.store.get(txn_id)
    except StoreError as exc:
        ctx.stdout(str(exc))
        return 1
    events = deps.store.events(txn_id)

    if args.json:
        payload = _txn_summary(record)
        payload["events"] = [
            {"seq": seq, "status": status, "detail": detail} for seq, status, detail in events
        ]
        ctx.stdout(json.dumps(payload))
    else:
        ctx.stdout(f"transaction {record.id}: {record.status}")
        ctx.stdout(f"capability: {record.invocation.capability} {dict(record.invocation.params)}")
        if record.detail:
            ctx.stdout(f"detail: {record.detail}")
        ctx.stdout("events:")
        for seq, status, detail in events:
            line = f"  {seq}: {status}"
            if detail:
                line += f" ({detail})"
            ctx.stdout(line)
    return 0


def cmd_status(ctx: CliCtx, args: argparse.Namespace) -> int:
    deps = ctx.deps_factory(args.state_dir, args.activate_mode)
    blessed = deps.store.blessed()
    active = deps.store.active()
    blessed_state = deps.store.blessed_state()
    warnings: list[str] = []

    generated_path = deps.workspace / "generated.nix"
    if generated_path.exists():
        expected = render(blessed_state, deps.catalog, deps.machine_profile)
        if generated_path.read_text() != expected:
            warnings.append("workspace differs from blessed state")
    elif blessed is not None:
        warnings.append("workspace differs from blessed state")

    current = deps.current_profile()
    blessed_closure = blessed.closure_path if blessed is not None else None
    if current != blessed_closure:
        warnings.append("system profile differs from blessed closure")

    if args.json:
        ctx.stdout(
            json.dumps(
                {
                    "blessed_txn": blessed.id if blessed is not None else None,
                    "active_txn": active.id if active is not None else None,
                    "apps": list(blessed_state.apps),
                    "warnings": warnings,
                }
            )
        )
    else:
        ctx.stdout(f"blessed txn: {blessed.id if blessed is not None else 'none'}")
        ctx.stdout(f"active txn: {active.id if active is not None else 'none'}")
        ctx.stdout(f"apps: {', '.join(blessed_state.apps) or '(none)'}")
        for w in warnings:
            ctx.stdout(f"warning: {w}")

    return 6 if warnings else 0


def cmd_apps(ctx: CliCtx, args: argparse.Namespace) -> int:
    deps = ctx.deps_factory(args.state_dir, args.activate_mode)
    apps = sorted(deps.catalog.values(), key=lambda a: a.id)
    if args.json:
        ctx.stdout(
            json.dumps(
                [
                    {"id": a.id, "name": a.name, "unfree": a.unfree, "summary": a.summary}
                    for a in apps
                ]
            )
        )
    else:
        for a in apps:
            flag = " [unfree]" if a.unfree else ""
            ctx.stdout(f"{a.id}: {a.name}{flag} - {a.summary}")
    return 0


def cmd_picker(ctx: CliCtx, args: argparse.Namespace) -> int:
    deps = ctx.deps_factory(args.state_dir, args.activate_mode)
    app = PickerApp(deps, ctx.apply_fn)
    app.run()
    return 0


_VERBS: dict[str, Callable[[CliCtx, argparse.Namespace], int]] = {
    "do": cmd_do,
    "history": cmd_history,
    "revert": cmd_revert,
    "explain": cmd_explain,
    "status": cmd_status,
    "apps": cmd_apps,
    "picker": cmd_picker,
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="intent")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--state-dir", type=Path, default=_DEFAULT_STATE_DIR)
    parser.add_argument(
        "--activate-mode",
        choices=["switch", "test"],
        default="test",
        help="switch is VM-certified only for now; see docs/host-setup.md",
    )
    parser.add_argument(
        "--audit-utterances",
        action="store_true",
        help="store raw utterance text in audit.jsonl instead of a hash",
    )

    sub = parser.add_subparsers(dest="verb", required=True)

    do_p = sub.add_parser("do")
    do_p.add_argument("utterance")

    hist_p = sub.add_parser("history")
    hist_p.add_argument("n", nargs="?", type=int, default=_DEFAULT_HISTORY_N)

    sub.add_parser("revert")

    explain_p = sub.add_parser("explain")
    explain_p.add_argument("txn", nargs="?", type=int, default=None)

    sub.add_parser("status")
    sub.add_parser("apps")
    sub.add_parser("picker")

    return parser


def run_cli(ctx: CliCtx, argv: Sequence[str] | None) -> int:
    args = build_parser().parse_args(argv)
    return _VERBS[args.verb](ctx, args)


def resolve_fn_from_env() -> Callable[[str, dict[str, CatalogApp]], Resolution]:
    """Pick the resolver `main()` wires into `cmd_do`.

    Test-only seam: the offline VM scenarios (nix/vm-cli.nix) cannot run
    `claude -p` (no network, no auth in the harness VM), so
    INTENTD_RESOLVER_STUB=<file> substitutes ONLY the model subprocess with
    the file's canned reply JSON. Prompt construction, reply schema
    validation, and catalog-checked invocation resolution still run through
    resolve_utterance exactly as in production; the live model path is
    proven by the M5 claude_live suite and the eval runner.
    """
    stub_file = os.environ.get("INTENTD_RESOLVER_STUB")
    if stub_file is not None:
        stub_path = Path(stub_file)
        return lambda utterance, catalog: resolve_utterance(
            utterance, catalog, lambda _prompt: stub_path.read_text()
        )
    return lambda utterance, catalog: resolve_utterance(utterance, catalog, run_claude)


def main(argv: Sequence[str] | None = None) -> int:
    ctx = CliCtx(
        deps_factory=production_deps,
        resolve_fn=resolve_fn_from_env(),
        apply_fn=apply_with_reconcile,
        stdout=lambda s: print(s),
        stderr=lambda s: print(s, file=sys.stderr),
        confirm=input,
    )
    return run_cli(ctx, argv)


if __name__ == "__main__":
    raise SystemExit(main())
