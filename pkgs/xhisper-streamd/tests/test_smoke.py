import subprocess
import sys


def test_version_flag_runs():
    """xhisper-streamd --version should print a version string and exit 0."""
    result = subprocess.run(
        [sys.executable, "-m", "xhisper_streamd", "--version"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0, result.stderr
    assert "xhisper-streamd" in result.stdout
