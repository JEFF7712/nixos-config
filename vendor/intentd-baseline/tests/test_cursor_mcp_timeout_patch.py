from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import stat
import tarfile
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

ROOT = Path(__file__).parent.parent
PATCHER_PATH = ROOT / "eval" / "baseline" / "vm" / "cursor-mcp-timeout-patch.py"
ARCHIVE_MEMBER = "dist-package/index.js"
NODE_MEMBER = "dist-package/node"
NODE_PAYLOAD = b"test bundled node executable"


def load_patcher() -> ModuleType:
    assert PATCHER_PATH.is_file(), "cursor MCP timeout patcher is absent"
    spec = importlib.util.spec_from_file_location("cursor_mcp_timeout_patch", PATCHER_PATH)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_archive(path: Path, member_data: bytes, member_name: str = ARCHIVE_MEMBER) -> str:
    with tarfile.open(path, "w:gz") as archive:
        member = tarfile.TarInfo(member_name)
        member.size = len(member_data)
        member.mode = 0o644
        archive.addfile(member, io.BytesIO(member_data))
        node = tarfile.TarInfo(NODE_MEMBER)
        node.size = len(NODE_PAYLOAD)
        node.mode = 0o755
        archive.addfile(node, io.BytesIO(NODE_PAYLOAD))
    return sha256(path.read_bytes())


def make_fixture(tmp_path: Path, payload: bytes) -> tuple[Path, Path, Path, str]:
    archive = tmp_path / "agent-cli-package.tar.gz"
    archive_sha256 = make_archive(archive, payload)
    version_dir = tmp_path / "2026.08.11-e8db854"
    version_dir.mkdir()
    bundle = version_dir / "index.js"
    bundle.write_bytes(payload)
    bundle.chmod(0o640)
    node = version_dir / "node"
    node.write_bytes(NODE_PAYLOAD)
    node.chmod(0o750)
    return archive, node, bundle, archive_sha256


def make_spec(module: ModuleType, payload: bytes, archive_sha256: str) -> Any:
    return module.PatchSpec(
        cli_version="2026.08.11-e8db854",
        archive_sha256=archive_sha256,
        bundle_sha256=sha256(payload),
        archive_member=ARCHIVE_MEMBER,
        node_sha256=sha256(NODE_PAYLOAD),
        node_member=NODE_MEMBER,
        original=b"timeout??6e4",
        patched=b"timeout??3e5",
        timeout_ms=300_000,
    )


def test_patches_exactly_one_expected_same_length_pattern(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    spec = make_spec(module, payload, archive_sha256)

    result = module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    patched = bundle.read_bytes()
    expected = b"prefix:timeout??3e5:suffix"
    assert patched == expected
    assert len(patched) == len(payload)
    assert [
        i for i, pair in enumerate(zip(payload, patched, strict=True)) if pair[0] != pair[1]
    ] == [
        16,
        18,
    ]
    assert stat.S_IMODE(bundle.stat().st_mode) == 0o640
    assert result == {
        "success": True,
        "status": "patched",
        "cursor_cli_version": spec.cli_version,
        "official_archive_sha256": archive_sha256,
        "official_bundle_sha256": sha256(payload),
        "task_facing_node_sha256": sha256(NODE_PAYLOAD),
        "patched_bundle_sha256": sha256(expected),
        "mcp_timeout_ms": 300_000,
        "replacement_count": 1,
    }


def test_second_application_is_an_explicit_no_write_success(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    spec = make_spec(module, payload, archive_sha256)
    module.apply_patch(archive, launcher, bundle, spec, bundle.parent)
    first_stat = bundle.stat()

    result = module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    second_stat = bundle.stat()
    assert result["status"] == "already_patched"
    assert second_stat.st_ino == first_stat.st_ino
    assert second_stat.st_mtime_ns == first_stat.st_mtime_ns


def test_rejects_unexpected_archive_hash_without_touching_bundle(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    spec = make_spec(module, payload, "0" * len(archive_sha256))

    with pytest.raises(module.PatchError, match="archive SHA-256"):
        module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == payload


def test_rejects_unexpected_version_directory_without_touching_bundle(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, _bundle, archive_sha256 = make_fixture(tmp_path, payload)
    unexpected_dir = tmp_path / "2026.08.12-unexpected"
    unexpected_dir.mkdir()
    unexpected_bundle = unexpected_dir / "index.js"
    unexpected_bundle.write_bytes(payload)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="CLI version directory"):
        module.apply_patch(archive, launcher, unexpected_bundle, spec, _bundle.parent)

    assert unexpected_bundle.read_bytes() == payload


def test_rejects_modified_installed_bundle_without_touching_it(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    modified = payload + b":modified"
    bundle.write_bytes(modified)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="installed bundle content"):
        module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == modified


def test_rejects_official_bundle_with_multiple_patterns(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"timeout??6e4:timeout??6e4"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="exactly one timeout pattern"):
        module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == payload


def test_rejects_archive_without_expected_regular_member(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, _ = make_fixture(tmp_path, payload)
    archive_sha256 = make_archive(archive, payload, "dist-package/other.js")
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="archive member"):
        module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == payload


def test_rejects_symlinked_installed_bundle(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, launcher, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    target = bundle.with_name("target.js")
    bundle.rename(target)
    bundle.symlink_to(target)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="canonical regular paths"):
        module.apply_patch(archive, launcher, bundle, spec, bundle.parent)

    assert target.read_bytes() == payload


def test_rejects_node_not_sibling_of_bundle(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, node, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    moved_node = tmp_path / node.name
    node.rename(moved_node)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="exact pinned install root"):
        module.apply_patch(archive, moved_node, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == payload


def test_rejects_modified_task_facing_node(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, node, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    node.write_bytes(NODE_PAYLOAD + b"modified")
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="task-facing Node"):
        module.apply_patch(archive, node, bundle, spec, bundle.parent)

    assert bundle.read_bytes() == payload


def test_rejects_wrong_install_root(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    archive, node, bundle, archive_sha256 = make_fixture(tmp_path, payload)
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="exact pinned install root"):
        module.apply_patch(archive, node, bundle, spec, tmp_path / "wrong-root")

    assert bundle.read_bytes() == payload


def test_rejects_symlinked_install_root_ancestor(tmp_path: Path) -> None:
    module = load_patcher()
    payload = b"prefix:timeout??6e4:suffix"
    real_parent = tmp_path / "real"
    real_parent.mkdir()
    archive, node, bundle, archive_sha256 = make_fixture(real_parent, payload)
    linked_parent = tmp_path / "linked"
    linked_parent.symlink_to(real_parent, target_is_directory=True)
    linked_root = linked_parent / bundle.parent.name
    linked_node = linked_root / node.name
    linked_bundle = linked_root / bundle.name
    spec = make_spec(module, payload, archive_sha256)

    with pytest.raises(module.PatchError, match="canonical regular paths"):
        module.apply_patch(archive, linked_node, linked_bundle, spec, linked_root)

    assert bundle.read_bytes() == payload


def test_production_spec_pins_reviewed_cursor_artifact_and_timeout() -> None:
    module = load_patcher()

    assert module.CURSOR_PATCH.cli_version == "2026.08.11-e8db854"
    assert (
        module.CURSOR_PATCH.archive_sha256
        == "bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a"
    )
    assert (
        module.CURSOR_PATCH.bundle_sha256
        == "f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0"
    )
    assert (
        module.CURSOR_PATCH.node_sha256
        == "e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4"
    )
    assert module.CURSOR_PATCH.node_member == "dist-package/node"
    assert (
        module.CURSOR_PATCH.original
        == b"const A=n?.timeout??6e4;this._setupTimeout(d,A,n?.maxTotalTimeout"
    )
    assert (
        module.CURSOR_PATCH.patched
        == b"const A=n?.timeout??3e5;this._setupTimeout(d,A,n?.maxTotalTimeout"
    )
    assert module.CURSOR_PATCH.timeout_ms == 300_000
    assert len(module.CURSOR_PATCH.original) == len(module.CURSOR_PATCH.patched)
    assert [
        i
        for i, pair in enumerate(
            zip(module.CURSOR_PATCH.original, module.CURSOR_PATCH.patched, strict=True)
        )
        if pair[0] != pair[1]
    ] == [20, 22]


def test_baseline_template_records_cursor_transport_metadata() -> None:
    template = json.loads((ROOT / "eval" / "baseline" / "baseline_arm.template.json").read_text())

    assert template["agent"]["cli_version"] == "2026.08.11-e8db854"
    assert template["cursor_mcp_transport_compatibility"] == {
        "official_cli_version": "2026.08.11-e8db854",
        "official_archive_sha256": (
            "bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a"
        ),
        "official_bundle_sha256": (
            "f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0"
        ),
        "task_facing_node_sha256": (
            "e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4"
        ),
        "patched_bundle_sha256": (
            "7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a"
        ),
        "mcp_timeout_ms": 300_000,
        "immutable_store_path": (
            "/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854"
        ),
        "first_application_status": None,
        "idempotence_verification_status": None,
        "pre_chat_cli_version": None,
        "post_chat_cli_version": None,
        "auto_update_disabled": True,
    }


def test_task_facing_runner_verifies_artifacts_and_forces_no_update() -> None:
    module = load_patcher()
    module_text = (ROOT / "eval" / "baseline" / "vm" / "agent-harness.nix").read_text()

    assert "cursorAgentRunner" in module_text
    assert module_text.count(module.CURSOR_PATCH.node_sha256) == 1
    assert (
        module_text.count("7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a") == 1
    )
    assert (
        "expected_root=/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854"
    ) in module_text
    assert module_text.count("realpath -e") == 2
    assert '"$node_path" != "$expected_root/node"' in module_text
    assert '"$bundle_path" != "$expected_root/index.js"' in module_text
    assert "$(dirname" not in module_text
    assert "$(basename" not in module_text
    assert "export PATH=/run/wrappers/bin:/run/current-system/sw/bin" in module_text
    assert '"$node_path" --use-system-ca "$bundle_path" --disable-auto-update "$@"' in module_text
