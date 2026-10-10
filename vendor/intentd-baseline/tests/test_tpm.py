from collections.abc import Sequence
from pathlib import Path
from typing import cast

import pytest

from intentd.executor import ExecError
from intentd.tpm import (
    INTENTD_NV_INDEX,
    TpmError,
    define_counter,
    nvdefine_argv,
    nvincrement_argv,
    nvread_argv,
    read_counter,
    system_counter,
)


class _EmulatedTpm:
    def __init__(self) -> None:
        self.value = 0
        self.defined = False
        self.calls: list[list[str]] = []

    def run(self, argv: Sequence[str], **_kwargs: object) -> str:
        args = list(argv)
        self.calls.append(args)
        if args[0] == "tpm2_nvdefine":
            if self.defined:
                raise ExecError("NV index already defined")
            self.defined = True
            return ""
        if not self.defined:
            raise ExecError("NV index undefined")
        if args[0] == "tpm2_nvincrement":
            self.value += 1
            return ""
        if args[0] == "tpm2_nvread":
            out = Path(args[args.index("-o") + 1])
            out.write_bytes(self.value.to_bytes(8, "big"))
            return ""
        raise AssertionError(f"unexpected argv {args}")


def test_define_argv_defaults() -> None:
    assert nvdefine_argv(INTENTD_NV_INDEX) == [
        "tpm2_nvdefine",
        "0x1800001",
        "-C",
        "o",
        "-s",
        "8",
        "-a",
        "ownerread|ownerwrite|authread|authwrite|no_da|orderly|nt=counter",
    ]


def test_argv_thread_auth() -> None:
    assert nvdefine_argv(INTENTD_NV_INDEX, hierarchy_auth="file:/root/owner.auth")[-2:] == [
        "-P",
        "file:/root/owner.auth",
    ]
    assert nvincrement_argv(INTENTD_NV_INDEX, index_auth="secret")[-2:] == ["-P", "secret"]
    read = nvread_argv(INTENTD_NV_INDEX, Path("/tmp/counter.bin"), index_auth="secret")
    assert read[-2:] == ["-P", "secret"]
    assert read[:2] == ["tpm2_nvread", "0x1800001"]


@pytest.mark.parametrize("index", [0x00FFFFFF, 0x02000000, 0, -1, "0x1800001", True, None])
def test_rejects_non_owner_index(index: object) -> None:
    bad = cast(int, index)
    with pytest.raises(TpmError):
        nvdefine_argv(bad)
    with pytest.raises(TpmError):
        nvread_argv(bad, Path("/tmp/counter.bin"))
    with pytest.raises(TpmError):
        nvincrement_argv(bad)


def test_rejects_empty_auth() -> None:
    with pytest.raises(TpmError):
        nvdefine_argv(INTENTD_NV_INDEX, hierarchy_auth="")
    with pytest.raises(TpmError):
        system_counter(Path("/tmp/counter.bin"), index_auth="")


def test_run_failure_becomes_tpm_error(tmp_path: Path) -> None:
    def fail(_argv: object, **_kwargs: object) -> str:
        raise ExecError("no TPM here")

    with pytest.raises(TpmError, match="define failed"):
        define_counter(run=fail)
    with pytest.raises(TpmError, match="read failed"):
        read_counter(INTENTD_NV_INDEX, tmp_path / "counter.bin", run=fail)
    counter = system_counter(tmp_path / "counter.bin", run=fail)
    with pytest.raises(TpmError, match="increment failed"):
        counter.increment()


def test_read_rejects_malformed_readback(tmp_path: Path) -> None:
    out = tmp_path / "counter.bin"

    def short(_argv: object, **_kwargs: object) -> str:
        out.write_bytes(b"\x00" * 4)
        return ""

    with pytest.raises(TpmError, match="expected 8 counter bytes"):
        read_counter(INTENTD_NV_INDEX, out, run=short)

    def silent(_argv: object, **_kwargs: object) -> str:
        return ""

    with pytest.raises(TpmError, match="readback missing"):
        read_counter(INTENTD_NV_INDEX, tmp_path / "absent.bin", run=silent)


def test_counter_round_trip_against_emulated_tpm(tmp_path: Path) -> None:
    emu = _EmulatedTpm()
    define_counter(run=emu.run)
    counter = system_counter(tmp_path / "counter.bin", run=emu.run)
    assert counter.index == INTENTD_NV_INDEX
    assert counter.read() == 0
    assert counter.increment() == 1
    assert counter.increment() == 2
    assert counter.read() == 2


def test_define_twice_fails() -> None:
    emu = _EmulatedTpm()
    define_counter(run=emu.run)
    with pytest.raises(TpmError):
        define_counter(run=emu.run)
