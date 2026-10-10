from pathlib import Path

import pytest

from intentd.catalog import load_catalog
from intentd.render import render
from intentd.state import DesiredState
from intentd.workspace import (
    TamperError,
    init_workspace,
    repair_manifest,
    verify_workspace,
    write_generated,
)


def _rendered() -> str:
    return render(DesiredState(apps=("firefox",)), load_catalog(), None)


def test_init_creates_template_and_manifest(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    assert (root / "flake.nix").exists()
    assert (root / "base.nix").exists()
    assert (root / "manifest.json").exists()
    verify_workspace(root)


def test_init_refuses_nonempty_dir(tmp_path: Path):
    root = tmp_path / "ws"
    root.mkdir()
    (root / "stray.txt").write_text("x")
    with pytest.raises(TamperError, match="not empty"):
        init_workspace(root)


def test_write_generated_then_verify(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    write_generated(root, _rendered())
    assert (root / "generated.nix").read_text() == _rendered()
    verify_workspace(root)


def test_out_of_band_edit_detected(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    write_generated(root, _rendered())
    generated = root / "generated.nix"
    generated.write_text(generated.read_text() + "# hand edit\n")
    with pytest.raises(TamperError, match="modified outside"):
        verify_workspace(root)
    with pytest.raises(TamperError, match="modified outside"):
        write_generated(root, _rendered())


def test_missing_tracked_file_detected(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    (root / "base.nix").unlink()
    with pytest.raises(TamperError, match="missing"):
        verify_workspace(root)


def test_corrupt_manifest_detected(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    (root / "manifest.json").write_text("not json")
    with pytest.raises(TamperError, match="manifest"):
        verify_workspace(root)


def test_preexisting_generated_file_detected(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    (root / "generated.nix").write_text("# planted out of band\n")
    with pytest.raises(TamperError, match="not recorded"):
        verify_workspace(root)
    with pytest.raises(TamperError, match="not recorded"):
        write_generated(root, _rendered())


def test_repair_manifest_recovers_from_hand_edit(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    write_generated(root, _rendered())
    generated = root / "generated.nix"
    generated.write_text(generated.read_text() + "# hand edit\n")
    with pytest.raises(TamperError, match="modified outside"):
        verify_workspace(root)
    repair_manifest(root)
    verify_workspace(root)


def test_concurrent_writes_serialize_without_corruption(tmp_path: Path):
    import threading

    root = tmp_path / "ws"
    init_workspace(root)
    write_generated(root, _rendered())
    rendered_a = _rendered()
    rendered_b = render(DesiredState(apps=("firefox", "vlc")), load_catalog(), None)
    errors: list[Exception] = []

    def spin(payload: str) -> None:
        try:
            for _ in range(20):
                write_generated(root, payload)
        except Exception as exc:  # noqa: BLE001
            errors.append(exc)

    threads = [
        threading.Thread(target=spin, args=(rendered_a,)),
        threading.Thread(target=spin, args=(rendered_b,)),
    ]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert errors == []
    verify_workspace(root)
    assert (root / "generated.nix").read_text() in {rendered_a, rendered_b}
