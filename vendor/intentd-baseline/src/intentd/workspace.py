import fcntl
import hashlib
import json
from importlib import resources
from pathlib import Path

import pydantic


class TamperError(Exception):
    pass


_TEMPLATE_FILES = ("flake.nix", "base.nix")
_GENERATED = "generated.nix"
_MANIFEST = "manifest.json"

_manifest_adapter = pydantic.TypeAdapter(dict[str, str])


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_manifest(root: Path) -> None:
    hashes = {
        name: _sha256(root / name)
        for name in (*_TEMPLATE_FILES, _GENERATED)
        if (root / name).exists()
    }
    tmp = root / (_MANIFEST + ".tmp")
    tmp.write_text(json.dumps(hashes, indent=2, sort_keys=True) + "\n")
    tmp.replace(root / _MANIFEST)


def init_workspace(root: Path) -> None:
    if root.exists() and any(root.iterdir()):
        raise TamperError(f"workspace {root} already exists and is not empty")
    root.mkdir(parents=True, exist_ok=True)
    for name in _TEMPLATE_FILES:
        content = resources.files("intentd").joinpath(f"flake_template/{name}").read_text()
        (root / name).write_text(content)
    _write_manifest(root)


def verify_workspace(root: Path) -> None:
    try:
        recorded = _manifest_adapter.validate_json((root / _MANIFEST).read_text())
    except (OSError, pydantic.ValidationError) as exc:
        raise TamperError(f"unreadable workspace manifest: {exc}") from exc
    for name, expected in recorded.items():
        target = root / name
        if not target.exists():
            raise TamperError(f"workspace file {name} is missing")
        if _sha256(target) != expected:
            raise TamperError(f"workspace file {name} was modified outside a transaction")
    for name in (*_TEMPLATE_FILES, _GENERATED):
        if name not in recorded and (root / name).exists():
            raise TamperError(f"workspace file {name} exists but is not recorded")


def write_generated(root: Path, rendered: str) -> None:
    with (root / ".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        verify_workspace(root)
        tmp = root / (_GENERATED + ".tmp")
        tmp.write_text(rendered)
        tmp.replace(root / _GENERATED)
        _write_manifest(root)


def repair_manifest(root: Path) -> None:
    with (root / ".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _write_manifest(root)
