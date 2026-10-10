import hashlib
import re
import subprocess
from collections.abc import Sequence
from pathlib import Path
from typing import Literal


class ExecError(Exception):
    pass


def rendered_sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require_store_path(closure: str) -> str:
    path = Path(closure)
    if path.parent != Path("/nix/store") or not path.name or str(path) != closure:
        raise ExecError(f"{closure!r} is not a Nix store path")
    return closure


def build_toplevel_argv(ws: Path, extra_args: Sequence[str] = ()) -> list[str]:
    return [
        "nix",
        "build",
        f"path:{ws}#nixosConfigurations.intentd.config.system.build.toplevel",
        "--out-link",
        str(ws / "result"),
        "--print-out-paths",
        *extra_args,
    ]


def set_profile_argv(closure: str) -> list[str]:
    return [
        "nix-env",
        "--profile",
        "/nix/var/nix/profiles/system",
        "--set",
        _require_store_path(closure),
    ]


def switch_argv(closure: str, action: Literal["switch", "test"]) -> list[str]:
    return [f"{_require_store_path(closure)}/bin/switch-to-configuration", action]


def install_boot_candidate_argv(closure: str) -> list[str]:
    return [f"{_require_store_path(closure)}/bin/switch-to-configuration", "boot"]


def retain_artifact_argv(closure: str, root: Path) -> list[str]:
    expected = Path("/var/lib/intentd/gcroots")
    allowed = root.name in {"blessed", "recovery"} or re.fullmatch(
        r"candidate-[1-9][0-9]*", root.name
    )
    if root.parent != expected or not allowed:
        raise ExecError("GC root is outside the intentd retention directory")
    return [
        "nix-store",
        "--add-root",
        str(root),
        "--indirect",
        "--realise",
        _require_store_path(closure),
    ]


def _bootctl_entry_argv(action: str, entry_id: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+@-]{0,254}", entry_id):
        raise ExecError("invalid boot entry ID")
    return ["bootctl", action, entry_id]


def set_oneshot_argv(entry_id: str) -> list[str]:
    return _bootctl_entry_argv("set-oneshot", entry_id)


def set_default_argv(entry_id: str) -> list[str]:
    return _bootctl_entry_argv("set-default", entry_id)


def run(argv: Sequence[str], *, timeout: float | None = 10) -> str:
    try:
        result = subprocess.run(
            list(argv),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except OSError as exc:
        raise ExecError(f"{argv[0]} could not be executed: {exc}") from exc
    if result.returncode != 0:
        raise ExecError(f"{argv[0]} failed with exit {result.returncode}: {result.stderr.strip()}")
    return result.stdout


def _single_store_path(out: str) -> str:
    lines = out.strip().splitlines()
    if len(lines) != 1:
        raise ExecError(f"expected exactly one output path, got {lines!r}")
    return _require_store_path(lines[0])


def build_toplevel(ws: Path) -> str:
    return _single_store_path(run(build_toplevel_argv(ws), timeout=None))


def set_system_profile(closure: str) -> None:
    run(set_profile_argv(closure))


def install_boot_candidate(closure: str) -> None:
    run(install_boot_candidate_argv(closure))


def retain_artifact(closure: str, root: Path) -> None:
    run(retain_artifact_argv(closure, root))


def set_oneshot(entry_id: str) -> None:
    run(set_oneshot_argv(entry_id))


def set_default(entry_id: str) -> None:
    run(set_default_argv(entry_id))


def mark_boot_bad() -> None:
    run(["/run/current-system/systemd/lib/systemd/systemd-bless-boot", "bad"])


def reboot() -> None:
    run(["systemctl", "reboot", "--no-block"])


def poweroff() -> None:
    run(["systemctl", "poweroff", "--no-block"])


def classify_switch_rc(rc: int) -> int:
    if rc not in (0, 4):
        raise ExecError(f"switch-to-configuration exited with unexpected exit code {rc}")
    return rc


def switch_to(closure: str, action: Literal["switch", "test"]) -> int:
    argv = switch_argv(closure, action)
    try:
        result = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
    except OSError as exc:
        raise ExecError(f"{argv[0]} could not be executed: {exc}") from exc
    return classify_switch_rc(result.returncode)
