from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import NamedTuple, TypedDict


class PatchError(RuntimeError):
    pass


class PatchSpec(NamedTuple):
    cli_version: str
    archive_sha256: str
    bundle_sha256: str
    archive_member: str
    node_sha256: str
    node_member: str
    original: bytes
    patched: bytes
    timeout_ms: int


class PatchResult(TypedDict):
    success: bool
    status: str
    cursor_cli_version: str
    official_archive_sha256: str
    official_bundle_sha256: str
    task_facing_node_sha256: str
    patched_bundle_sha256: str
    mcp_timeout_ms: int
    replacement_count: int


CURSOR_PATCH = PatchSpec(
    cli_version="2026.08.11-e8db854",
    archive_sha256="bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a",
    bundle_sha256="f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0",
    archive_member="dist-package/index.js",
    node_sha256="e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4",
    node_member="dist-package/node",
    original=b"const A=n?.timeout??6e4;this._setupTimeout(d,A,n?.maxTotalTimeout",
    patched=b"const A=n?.timeout??3e5;this._setupTimeout(d,A,n?.maxTotalTimeout",
    timeout_ms=300_000,
)
CURSOR_INSTALL_ROOT = Path(
    "/home/wedge/.local/share/intentd-baseline/cursor-agent/2026.08.11-e8db854"
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _open_regular(path: Path) -> tuple[int, os.stat_result]:
    try:
        fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    except OSError as exc:
        raise PatchError(f"cannot open regular file: {path}") from exc
    file_stat = os.fstat(fd)
    if not stat.S_ISREG(file_stat.st_mode):
        os.close(fd)
        raise PatchError(f"expected a regular file: {path}")
    return fd, file_stat


def _read_regular(path: Path) -> tuple[bytes, os.stat_result]:
    fd, file_stat = _open_regular(path)
    with os.fdopen(fd, "rb") as source:
        return source.read(), file_stat


def _official_files(archive_path: Path, spec: PatchSpec) -> tuple[bytes, bytes]:
    fd, _ = _open_regular(archive_path)
    with os.fdopen(fd, "rb") as archive_file:
        archive_digest = hashlib.file_digest(archive_file, "sha256").hexdigest()
        if archive_digest != spec.archive_sha256:
            raise PatchError(
                f"unexpected official archive SHA-256: expected {spec.archive_sha256}, "
                f"got {archive_digest}"
            )
        archive_file.seek(0)
        try:
            with tarfile.open(fileobj=archive_file, mode="r:gz") as archive:
                contents: list[bytes] = []
                for member_name in (spec.archive_member, spec.node_member):
                    matching = [
                        member for member in archive.getmembers() if member.name == member_name
                    ]
                    if len(matching) != 1 or not matching[0].isreg():
                        raise PatchError(f"expected one regular archive member named {member_name}")
                    extracted = archive.extractfile(matching[0])
                    if extracted is None:
                        raise PatchError(f"cannot read archive member {member_name}")
                    contents.append(extracted.read())
        except tarfile.TarError as exc:
            raise PatchError("official archive is not a readable gzip tar archive") from exc

    official_bundle, official_node = contents
    official_digest = _sha256(official_bundle)
    if official_digest != spec.bundle_sha256:
        raise PatchError(
            f"unexpected official bundle SHA-256: expected {spec.bundle_sha256}, "
            f"got {official_digest}"
        )
    node_digest = _sha256(official_node)
    if node_digest != spec.node_sha256:
        raise PatchError(
            f"unexpected official Node SHA-256: expected {spec.node_sha256}, got {node_digest}"
        )
    return official_bundle, official_node


def _same_file_state(left: os.stat_result, right: os.stat_result) -> bool:
    return (
        left.st_dev,
        left.st_ino,
        left.st_mode,
        left.st_size,
        left.st_mtime_ns,
    ) == (
        right.st_dev,
        right.st_ino,
        right.st_mode,
        right.st_size,
        right.st_mtime_ns,
    )


def _atomic_replace(path: Path, data: bytes, original_stat: os.stat_result) -> None:
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        os.fchmod(fd, stat.S_IMODE(original_stat.st_mode))
        with os.fdopen(fd, "wb") as destination:
            destination.write(data)
            destination.flush()
            os.fsync(destination.fileno())

        current_stat = path.lstat()
        if not stat.S_ISREG(current_stat.st_mode) or not _same_file_state(
            original_stat, current_stat
        ):
            raise PatchError("installed bundle changed while preparing the patch")
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)


def apply_patch(
    archive_path: Path,
    node_path: Path,
    bundle_path: Path,
    spec: PatchSpec,
    install_root: Path,
) -> PatchResult:
    if bundle_path.name != "index.js" or bundle_path.parent.name != spec.cli_version:
        raise PatchError(
            f"expected index.js in CLI version directory {spec.cli_version}, got {bundle_path}"
        )
    if (
        not install_root.is_absolute()
        or node_path.parent != install_root
        or bundle_path.parent != install_root
    ):
        raise PatchError(f"expected exact pinned install root {install_root}")
    if node_path.name != "node" or node_path.parent != bundle_path.parent:
        raise PatchError("task-facing Node and bundle must share the same pinned version directory")
    try:
        if (
            node_path.resolve(strict=True) != node_path.absolute()
            or bundle_path.resolve(strict=True) != bundle_path.absolute()
        ):
            raise PatchError("task-facing Node and bundle must use canonical regular paths")
    except OSError as exc:
        raise PatchError("cannot resolve task-facing Node and bundle") from exc
    if len(spec.original) != len(spec.patched):
        raise PatchError("timeout patch must preserve bundle length")

    official, official_node = _official_files(archive_path, spec)
    installed_node, node_stat = _read_regular(node_path)
    if installed_node != official_node or not node_stat.st_mode & 0o111:
        raise PatchError("unexpected task-facing Node; refusing to patch its bundle")
    if official.count(spec.original) != 1 or official.count(spec.patched) != 0:
        raise PatchError("official bundle must contain exactly one timeout pattern")
    expected_patched = official.replace(spec.original, spec.patched, 1)
    if len(expected_patched) != len(official):
        raise PatchError("timeout patch changed bundle length")

    installed, installed_stat = _read_regular(bundle_path)
    if installed == expected_patched:
        status = "already_patched"
    elif installed == official:
        _atomic_replace(bundle_path, expected_patched, installed_stat)
        verified, _ = _read_regular(bundle_path)
        if verified != expected_patched:
            raise PatchError("patched bundle verification failed")
        status = "patched"
    else:
        raise PatchError("unexpected installed bundle content; refusing to modify it")

    return {
        "success": True,
        "status": status,
        "cursor_cli_version": spec.cli_version,
        "official_archive_sha256": spec.archive_sha256,
        "official_bundle_sha256": spec.bundle_sha256,
        "task_facing_node_sha256": spec.node_sha256,
        "patched_bundle_sha256": _sha256(expected_patched),
        "mcp_timeout_ms": spec.timeout_ms,
        "replacement_count": 1,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply the pinned Cursor MCP request-timeout compatibility patch."
    )
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--node", required=True, type=Path)
    parser.add_argument("--bundle", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = apply_patch(
            args.archive, args.node, args.bundle, CURSOR_PATCH, CURSOR_INSTALL_ROOT
        )
    except (OSError, PatchError) as exc:
        message = " ".join(str(exc).splitlines()).strip() or type(exc).__name__
        print(f"baseline-patch-cursor-mcp-timeout: {message}", file=sys.stderr)
        return 1
    print(json.dumps(result, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
