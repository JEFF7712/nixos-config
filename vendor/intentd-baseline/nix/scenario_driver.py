"""Scenario driver for the M4 Task 6 VM checks.

Shipped into the test VM via virtualisation.additionalPaths (as a plain text
file, not a python package) and invoked by absolute store path with the
seeded python env, as root:

    <pythonEnv>/bin/python3 <this file> --nixpkgs-override '<override>' <subcommand> ...

It assembles a real intentd.orchestrator.Deps against:
  - a TransactionStore at /var/lib/intentd/txn.db
  - a workspace at /var/lib/intentd/ws
  - intentd.catalog.load_catalog()
  - a hermetic build: executor.build_toplevel_argv(ws, extra_args=[...]) with
    --no-write-lock-file --override-input nixpkgs '<override>' appended, so
    the in-VM `nix build` never touches the network (see nix/SPIKE_FINDINGS.md)
  - executor.set_system_profile
  - executor.switch_to(closure, "test") as activate
  - health.failed_units
  - current_profile: resolved /nix/var/nix/profiles/system, or None if absent

Subcommands: init, repair-manifest, install <app>, revert, status. Every
subcommand prints exactly one JSON line to stdout; the testScript parses it
instead of scraping console output.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Never

from intentd import executor, health
from intentd.catalog import load_catalog
from intentd.journal import AuthenticatedJournal
from intentd.machine import load_machine_profile
from intentd.orchestrator import ApplyResult, Deps, apply_intent
from intentd.registry import resolve_invocation
from intentd.store import TransactionStore
from intentd.txn import TransactionRecord
from intentd.workspace import init_workspace, repair_manifest

WORKSPACE = Path("/var/lib/intentd/ws")
DB_PATH = Path("/var/lib/intentd/txn.db")
SYSTEM_PROFILE = Path("/nix/var/nix/profiles/system")
MACHINE_PROFILE = Path("/etc/intentd/machine-profile.json")


def _current_profile() -> str | None:
    return str(SYSTEM_PROFILE.resolve()) if SYSTEM_PROFILE.exists() else None


def _make_build(nixpkgs_override: str):
    def build(ws: Path) -> tuple[str, str]:
        argv = executor.build_toplevel_argv(
            ws,
            extra_args=[
                "--no-write-lock-file",
                "--override-input",
                "nixpkgs",
                nixpkgs_override,
            ],
        )
        out = executor.run(argv, timeout=None)
        lines = out.strip().splitlines()
        if len(lines) != 1:
            raise executor.ExecError(f"expected exactly one output path, got {lines!r}")
        return lines[0], nixpkgs_override

    return build


def _activate(closure: str) -> int:
    return executor.switch_to(closure, "test")


def _store() -> TransactionStore:
    journal = AuthenticatedJournal(DB_PATH.parent, bytes(range(32)))
    return TransactionStore(DB_PATH, journal)


def _boot_dependency_unavailable(*_args: object) -> Never:
    raise RuntimeError("boot dependency used by non-boot VM scenario")


def _deps(nixpkgs_override: str) -> Deps:
    return Deps(
        store=_store(),
        workspace=WORKSPACE,
        catalog=load_catalog(),
        machine_profile=load_machine_profile(MACHINE_PROFILE),
        build=_make_build(nixpkgs_override),
        set_profile=executor.set_system_profile,
        activate=_activate,
        failed_units=health.failed_units,
        current_profile=_current_profile,
        capture_health=_boot_dependency_unavailable,
        inspect_candidate=_boot_dependency_unavailable,
        verify_artifact=_boot_dependency_unavailable,
        retain_artifact=_boot_dependency_unavailable,
        recovery_artifact=_boot_dependency_unavailable,
        install_boot_candidate=_boot_dependency_unavailable,
        reboot=_boot_dependency_unavailable,
    )


def _record_summary(record: TransactionRecord | None) -> dict[str, object] | None:
    if record is None:
        return None
    return {
        "id": record.id,
        "status": record.status.value,
        "closure_path": record.closure_path,
        "apps": list(record.new_state.apps),
        "detail": record.detail,
    }


def _print_result(result: ApplyResult) -> None:
    print(
        json.dumps(
            {
                "decision": {
                    "verdict": result.decision.verdict.value,
                    "reason": result.decision.reason,
                },
                "transaction": _record_summary(result.record),
            }
        )
    )


def cmd_init(_args: argparse.Namespace) -> int:
    init_workspace(WORKSPACE)
    print(json.dumps({"ok": True}))
    return 0


def cmd_repair_manifest(_args: argparse.Namespace) -> int:
    repair_manifest(WORKSPACE)
    print(json.dumps({"ok": True}))
    return 0


def cmd_install(args: argparse.Namespace) -> int:
    deps = _deps(args.nixpkgs_override)
    inv = resolve_invocation(deps.catalog, "app.install", {"app": args.app})
    _print_result(apply_intent(deps, inv))
    return 0


def cmd_revert(args: argparse.Namespace) -> int:
    deps = _deps(args.nixpkgs_override)
    inv = resolve_invocation(deps.catalog, "change.revert", {})
    _print_result(apply_intent(deps, inv))
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    store = _store()
    print(
        json.dumps(
            {
                "latest": _record_summary(store.active()),
                "blessed": _record_summary(store.blessed()),
            }
        )
    )
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--nixpkgs-override",
        default="",
        help="'path:<src>?rev=<rev>&lastModified=<n>' override-input value for the hermetic build",
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    sub.add_parser("repair-manifest")
    install = sub.add_parser("install")
    install.add_argument("app")
    sub.add_parser("revert")
    sub.add_parser("status")

    args = parser.parse_args(argv)
    handlers = {
        "init": cmd_init,
        "repair-manifest": cmd_repair_manifest,
        "install": cmd_install,
        "revert": cmd_revert,
        "status": cmd_status,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
