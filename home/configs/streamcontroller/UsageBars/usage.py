import json
import os
import shutil
import subprocess
import threading
import time

from loguru import logger as log

CLAUDE_CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "claude-code",
    "rate-limits.json",
)
CLAUDE_WINDOWS = {"5h": "five_hour", "week": "seven_day"}
CODEX_WINDOWS = {"5h": "primary", "week": "secondary"}
CLAUDE_INTERVAL = 5
CODEX_INTERVAL = 60
CODEX_TIMEOUT = 30


class Window:
    def __init__(self, used: float | None, resets_at: int | None):
        self.used = used
        self.resets_at = resets_at

    def used_now(self) -> float | None:
        if self.used is None:
            return None
        if self.resets_at is not None and self.resets_at <= time.time():
            return 0.0
        return max(0.0, min(100.0, float(self.used)))


class UsageData:
    """Polls both sources on one background thread and exposes the latest values."""

    def __init__(self):
        self._lock = threading.Lock()
        self._windows: dict[tuple[str, str], Window] = {}
        self._codex_refresh = threading.Event()
        self._thread: threading.Thread | None = None
        self.version = 0

    def start(self):
        if self._thread is not None and self._thread.is_alive():
            return
        self._thread = threading.Thread(
            target=self._loop, name="usage-bars-poller", daemon=True
        )
        self._thread.start()

    def refresh_codex(self):
        self._codex_refresh.set()

    def get(self, source: str, window: str) -> Window | None:
        with self._lock:
            return self._windows.get((source, window))

    def _set(self, values: dict[tuple[str, str], Window]):
        with self._lock:
            changed = any(
                (self._windows.get(k) is None)
                or (self._windows[k].used, self._windows[k].resets_at)
                != (v.used, v.resets_at)
                for k, v in values.items()
            )
            self._windows.update(values)
            if changed:
                self.version += 1

    def _loop(self):
        next_codex = 0.0
        while True:
            self._read_claude()
            if self._codex_refresh.is_set() or time.monotonic() >= next_codex:
                self._codex_refresh.clear()
                self._read_codex()
                next_codex = time.monotonic() + CODEX_INTERVAL
            self._codex_refresh.wait(timeout=CLAUDE_INTERVAL)

    def _read_claude(self):
        try:
            with open(CLAUDE_CACHE) as f:
                limits = json.load(f)
        except (OSError, ValueError):
            return
        values = {}
        for name, key in CLAUDE_WINDOWS.items():
            w = limits.get(key) or {}
            values[("claude", name)] = Window(
                w.get("used_percentage"), w.get("resets_at")
            )
        self._set(values)

    def _read_codex(self):
        try:
            limits = fetch_codex_rate_limits()
        except Exception as exc:
            log.warning(f"UsageBars: codex rate limits unavailable: {exc}")
            return
        values = {}
        for name, key in CODEX_WINDOWS.items():
            w = limits.get(key) or {}
            values[("codex", name)] = Window(w.get("usedPercent"), w.get("resetsAt"))
        self._set(values)


def fetch_codex_rate_limits() -> dict:
    codex = shutil.which("codex") or "codex"
    proc = subprocess.Popen(
        [codex, "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        cwd=os.path.expanduser("~"),
        start_new_session=True,
    )
    timer = threading.Timer(CODEX_TIMEOUT, proc.kill)
    timer.start()
    try:

        def send(message):
            proc.stdin.write(json.dumps(message) + "\n")
            proc.stdin.flush()

        send(
            {
                "method": "initialize",
                "id": 1,
                "params": {
                    "clientInfo": {
                        "name": "streamcontroller-usage-bars",
                        "title": "Usage Bars",
                        "version": "1.0.0",
                    },
                    "capabilities": {"experimentalApi": True},
                },
            }
        )
        for line in proc.stdout:
            message = json.loads(line)
            if message.get("id") == 1:
                send({"method": "initialized", "params": {}})
                send({"method": "account/rateLimits/read", "id": 2, "params": None})
            elif message.get("id") == 2:
                if "error" in message:
                    raise RuntimeError(message["error"])
                return message["result"]["rateLimits"]
        raise RuntimeError("codex app-server exited without a response")
    finally:
        timer.cancel()
        proc.kill()
        proc.wait()
