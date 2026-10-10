from pathlib import Path

import pytest

import intentd.executor as executor
from intentd.executor import (
    ExecError,
    install_boot_candidate,
    install_boot_candidate_argv,
    mark_boot_bad,
    reboot,
    retain_artifact,
    retain_artifact_argv,
    set_default,
    set_default_argv,
    set_oneshot,
    set_oneshot_argv,
)


def test_install_boot_candidate_argv() -> None:
    assert install_boot_candidate_argv("/nix/store/abc-system") == [
        "/nix/store/abc-system/bin/switch-to-configuration",
        "boot",
    ]


@pytest.mark.parametrize("name", ["blessed", "recovery", "candidate-42"])
def test_retain_artifact_argv_uses_only_named_retention_roots(name: str) -> None:
    root = Path(f"/var/lib/intentd/gcroots/{name}")
    assert retain_artifact_argv("/nix/store/abc-system", root) == [
        "nix-store",
        "--add-root",
        str(root),
        "--indirect",
        "--realise",
        "/nix/store/abc-system",
    ]


@pytest.mark.parametrize(
    "root",
    [
        Path("/var/lib/intentd/gcroots/../escape"),
        Path("/var/lib/intentd/gcroots/candidate"),
        Path("/var/lib/intentd/gcroots/candidate-latest"),
        Path("/tmp/blessed"),
    ],
)
def test_gc_root_rejects_escape_or_unreserved_name(root: Path) -> None:
    with pytest.raises(ExecError, match="retention directory"):
        retain_artifact_argv("/nix/store/abc", root)


@pytest.mark.parametrize(
    "entry_id",
    ["nixos-generation-4.efi", "candidate+0-1.efi", "recovery@intentd.efi"],
)
def test_set_oneshot_accepts_closed_entry_id_grammar(entry_id: str) -> None:
    assert set_oneshot_argv(entry_id) == ["bootctl", "set-oneshot", entry_id]


def test_set_default_uses_the_same_closed_entry_id_grammar() -> None:
    assert set_default_argv("prior-blessed.efi") == [
        "bootctl",
        "set-default",
        "prior-blessed.efi",
    ]


@pytest.mark.parametrize(
    "entry_id",
    ["", "--help", "../escape.efi", "entry with spaces.efi", "x" * 256],
)
def test_set_oneshot_rejects_invalid_entry(entry_id: str) -> None:
    with pytest.raises(ExecError, match="boot entry ID"):
        set_oneshot_argv(entry_id)


def test_boot_wrappers_execute_only_fixed_argv(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def record(argv: list[str]) -> str:
        calls.append(argv)
        return ""

    monkeypatch.setattr(executor, "run", record)

    install_boot_candidate("/nix/store/abc-system")
    retain_artifact("/nix/store/blessed-system", Path("/var/lib/intentd/gcroots/blessed"))
    set_oneshot("candidate+0-1.efi")
    set_default("blessed.efi")
    mark_boot_bad()
    reboot()

    assert calls == [
        ["/nix/store/abc-system/bin/switch-to-configuration", "boot"],
        [
            "nix-store",
            "--add-root",
            "/var/lib/intentd/gcroots/blessed",
            "--indirect",
            "--realise",
            "/nix/store/blessed-system",
        ],
        ["bootctl", "set-oneshot", "candidate+0-1.efi"],
        ["bootctl", "set-default", "blessed.efi"],
        ["/run/current-system/systemd/lib/systemd/systemd-bless-boot", "bad"],
        ["systemctl", "reboot", "--no-block"],
    ]
