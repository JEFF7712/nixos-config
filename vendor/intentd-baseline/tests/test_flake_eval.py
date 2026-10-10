import subprocess
from pathlib import Path

import pytest

from intentd.catalog import load_catalog
from intentd.render import render
from intentd.state import DesiredState
from intentd.workspace import init_workspace, write_generated


@pytest.mark.nix_eval
def test_rendered_flake_evaluates(tmp_path: Path):
    root = tmp_path / "ws"
    init_workspace(root)
    write_generated(root, render(DesiredState(apps=("firefox",)), load_catalog(), None))
    result = subprocess.run(
        [
            "nix",
            "eval",
            "--raw",
            f"path:{root}#nixosConfigurations.intentd.config.system.build.toplevel.drvPath",
        ],
        capture_output=True,
        text=True,
        timeout=1800,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.endswith(".drv")
