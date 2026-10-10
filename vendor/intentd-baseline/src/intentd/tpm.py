from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from intentd import executor
from intentd.executor import ExecError

INTENTD_NV_INDEX = 0x01800001
NV_COUNTER_BYTES = 8
_NV_OWNER_FIRST = 0x01000000
_NV_OWNER_LAST = 0x01FFFFFF
_NV_COUNTER_ATTRS = "ownerread|ownerwrite|authread|authwrite|no_da|orderly|nt=counter"


class TpmError(Exception):
    pass


def _require_nv_index(index: int) -> int:
    if isinstance(index, bool):
        raise TpmError(f"{index!r} is not an NV index")
    try:
        in_range = _NV_OWNER_FIRST <= index <= _NV_OWNER_LAST
    except TypeError:
        raise TpmError(f"{index!r} is not an NV index") from None
    if not in_range:
        raise TpmError(f"{index:#x} is outside the owner NV range")
    return index


def _auth_args(auth: str | None) -> list[str]:
    if auth is None:
        return []
    if not auth:
        raise TpmError("authorization value must not be empty")
    return ["-P", auth]


def nvdefine_argv(index: int, *, hierarchy_auth: str | None = None) -> list[str]:
    return [
        "tpm2_nvdefine",
        format(_require_nv_index(index), "#x"),
        "-C",
        "o",
        "-s",
        str(NV_COUNTER_BYTES),
        "-a",
        _NV_COUNTER_ATTRS,
        *_auth_args(hierarchy_auth),
    ]


def nvread_argv(index: int, out_path: Path, *, index_auth: str | None = None) -> list[str]:
    return [
        "tpm2_nvread",
        format(_require_nv_index(index), "#x"),
        "-C",
        "o",
        "-s",
        str(NV_COUNTER_BYTES),
        "-o",
        str(out_path),
        *_auth_args(index_auth),
    ]


def nvincrement_argv(index: int, *, index_auth: str | None = None) -> list[str]:
    return [
        "tpm2_nvincrement",
        format(_require_nv_index(index), "#x"),
        "-C",
        "o",
        *_auth_args(index_auth),
    ]


# A freshly defined counter is not readable (NV-uninitialized) until its first
# increment, so provisioning must increment once after defining.
def define_counter(
    index: int = INTENTD_NV_INDEX,
    *,
    hierarchy_auth: str | None = None,
    run: Callable[..., str] = executor.run,
) -> None:
    try:
        run(nvdefine_argv(index, hierarchy_auth=hierarchy_auth))
    except ExecError as exc:
        raise TpmError(f"NV counter define failed: {exc}") from exc


def read_counter(
    index: int,
    out_path: Path,
    *,
    index_auth: str | None = None,
    run: Callable[..., str] = executor.run,
) -> int:
    try:
        run(nvread_argv(index, out_path, index_auth=index_auth))
    except ExecError as exc:
        raise TpmError(f"NV counter read failed: {exc}") from exc
    try:
        data = out_path.read_bytes()
    except OSError as exc:
        raise TpmError(f"NV counter readback missing at {out_path}: {exc}") from exc
    if len(data) != NV_COUNTER_BYTES:
        raise TpmError(f"expected {NV_COUNTER_BYTES} counter bytes, got {len(data)}")
    return int.from_bytes(data, "big")


@dataclass(frozen=True)
class NvCounter:
    index: int
    read: Callable[[], int]
    increment: Callable[[], int]


def system_counter(
    scratch: Path,
    *,
    index: int = INTENTD_NV_INDEX,
    index_auth: str | None = None,
    run: Callable[..., str] = executor.run,
) -> NvCounter:
    _require_nv_index(index)
    _auth_args(index_auth)

    def _read() -> int:
        return read_counter(index, scratch, index_auth=index_auth, run=run)

    def _increment() -> int:
        try:
            run(nvincrement_argv(index, index_auth=index_auth))
        except ExecError as exc:
            raise TpmError(f"NV counter increment failed: {exc}") from exc
        # nvincrement prints nothing on success, so the recorded value comes
        # from a readback inside the same caller-held critical section.
        return _read()

    return NvCounter(index=index, read=_read, increment=_increment)
