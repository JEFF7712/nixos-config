from pathlib import Path

import pytest

import intentd.executor as executor
from intentd.executor import (
    ExecError,
    build_toplevel,
    build_toplevel_argv,
    classify_switch_rc,
    file_sha256,
    rendered_sha256,
    run,
    set_profile_argv,
    switch_argv,
)


def test_rendered_sha256_known_vector():
    assert rendered_sha256("") == (
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
    assert rendered_sha256("x") == rendered_sha256("x")


def test_file_sha256_matches_rendered(tmp_path: Path):
    p = tmp_path / "f"
    p.write_text("hello\n")
    assert file_sha256(p) == rendered_sha256("hello\n")


def test_build_toplevel_argv_shape():
    assert build_toplevel_argv(Path("/var/lib/intentd/ws")) == [
        "nix",
        "build",
        "path:/var/lib/intentd/ws#nixosConfigurations.intentd.config.system.build.toplevel",
        "--out-link",
        "/var/lib/intentd/ws/result",
        "--print-out-paths",
    ]


def test_build_toplevel_argv_appends_extra_args():
    assert build_toplevel_argv(
        Path("/var/lib/intentd/ws"),
        extra_args=["--no-write-lock-file", "--override-input", "nixpkgs", "path:/nix/store/x"],
    ) == [
        "nix",
        "build",
        "path:/var/lib/intentd/ws#nixosConfigurations.intentd.config.system.build.toplevel",
        "--out-link",
        "/var/lib/intentd/ws/result",
        "--print-out-paths",
        "--no-write-lock-file",
        "--override-input",
        "nixpkgs",
        "path:/nix/store/x",
    ]


def test_build_toplevel_is_not_limited_to_control_command_timeout(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    def fake_run(argv: list[str], *, timeout: float | None = 10) -> str:
        assert argv == build_toplevel_argv(tmp_path)
        assert timeout is None
        return "/nix/store/abc-toplevel\n"

    monkeypatch.setattr(executor, "run", fake_run)

    assert build_toplevel(tmp_path) == "/nix/store/abc-toplevel"


def test_set_profile_argv_shape():
    assert set_profile_argv("/nix/store/abc-toplevel") == [
        "nix-env",
        "--profile",
        "/nix/var/nix/profiles/system",
        "--set",
        "/nix/store/abc-toplevel",
    ]


def test_switch_argv_shape():
    assert switch_argv("/nix/store/abc-toplevel", "test") == [
        "/nix/store/abc-toplevel/bin/switch-to-configuration",
        "test",
    ]
    assert switch_argv("/nix/store/abc-toplevel", "switch") == [
        "/nix/store/abc-toplevel/bin/switch-to-configuration",
        "switch",
    ]


def test_run_returns_stdout():
    assert run(["echo", "ok"]) == "ok\n"


def test_run_raises_exec_error_with_stderr():
    with pytest.raises(ExecError, match="exit 2"):
        run(["python3", "-c", "import sys; sys.stderr.write('boom'); sys.exit(2)"])


def test_non_store_path_arguments_rejected():
    with pytest.raises(ExecError, match="store path"):
        set_profile_argv("/tmp/evil")
    with pytest.raises(ExecError, match="store path"):
        switch_argv("relative/path", "switch")


def test_traversal_inside_store_prefix_rejected():
    with pytest.raises(ExecError, match="store path"):
        set_profile_argv("/nix/store/abc-toplevel/../../../etc")


@pytest.mark.parametrize(
    "path", ["/nix/store/", "/nix/store/abc-system/nested", "/nix/storeish/abc"]
)
def test_store_path_must_name_one_direct_store_object(path: str):
    with pytest.raises(ExecError, match="store path"):
        set_profile_argv(path)


def test_run_wraps_oserror_as_exec_error():
    with pytest.raises(ExecError, match="could not be executed"):
        run(["/nonexistent/definitely-not-a-binary"])


def test_single_store_path_rejects_multiline():
    from intentd.executor import (
        _single_store_path,  # pyright: ignore[reportPrivateUsage]
    )

    with pytest.raises(ExecError, match="exactly one"):
        _single_store_path("/nix/store/a\n/nix/store/b\n")
    assert _single_store_path("/nix/store/a\n") == "/nix/store/a"


def test_classify_switch_rc_passes_through_clean_and_degraded():
    assert classify_switch_rc(0) == 0
    assert classify_switch_rc(4) == 4


def test_classify_switch_rc_rejects_unexpected_codes():
    with pytest.raises(ExecError, match="unexpected exit code 1"):
        classify_switch_rc(1)
    with pytest.raises(ExecError, match="unexpected exit code 100"):
        classify_switch_rc(100)
