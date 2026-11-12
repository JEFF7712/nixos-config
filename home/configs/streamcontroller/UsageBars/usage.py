import json
import os
import shutil
import subprocess
import tempfile
import threading
import time
from datetime import datetime
from urllib.request import Request, urlopen

from loguru import logger as log

CLAUDE_CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "claude-code",
    "rate-limits.json",
)
CLAUDE_WINDOWS = {"5h": "five_hour", "week": "seven_day"}
CODEX_WINDOWS = {"5h": "primary", "week": "secondary"}
CLAUDE_INTERVAL = 5
CLAUDE_API_INTERVAL = 300
CLAUDE_REFRESH_MIN = 60
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
            return None
        return max(0.0, min(100.0, float(self.used)))


class UsageData:
    """Polls both sources on one background thread and exposes the latest values."""

    def __init__(self):
        self._lock = threading.Lock()
        self._windows: dict[tuple[str, str], Window] = {}
        self._refresh = threading.Event()
        self._thread: threading.Thread | None = None
        self.version = 0

    def start(self):
        if self._thread is not None and self._thread.is_alive():
            return
        self._thread = threading.Thread(
            target=self._loop, name="usage-bars-poller", daemon=True
        )
        self._thread.start()

    def refresh(self):
        self._refresh.set()

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
        next_claude = 0.0
        last_claude = -CLAUDE_REFRESH_MIN
        next_codex = 0.0
        while True:
            refresh = self._refresh.is_set()
            self._refresh.clear()
            now = time.monotonic()
            if now >= next_claude or (
                refresh and now - last_claude >= CLAUDE_REFRESH_MIN
            ):
                self._refresh_claude()
                last_claude = time.monotonic()
                next_claude = last_claude + CLAUDE_API_INTERVAL
            self._read_claude()
            if refresh or time.monotonic() >= next_codex:
                self._read_codex()
                next_codex = time.monotonic() + CODEX_INTERVAL
            self._refresh.wait(timeout=CLAUDE_INTERVAL)

    def _refresh_claude(self):
        try:
            limits = fetch_claude_rate_limits()
        except (OSError, ValueError, KeyError, TypeError) as exc:
            log.warning(f"UsageBars: claude rate limits unavailable: {exc}")
            return
        self._set_claude(limits)
        temporary = None
        try:
            directory = os.path.dirname(CLAUDE_CACHE)
            os.makedirs(directory, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                mode="w", dir=directory, delete=False
            ) as f:
                temporary = f.name
                json.dump(limits, f)
            os.replace(temporary, CLAUDE_CACHE)
        except OSError as exc:
            log.warning(f"UsageBars: cannot cache claude rate limits: {exc}")
        finally:
            if temporary is not None and os.path.exists(temporary):
                os.unlink(temporary)

    def _read_claude(self):
        try:
            with open(CLAUDE_CACHE) as f:
                limits = json.load(f)
        except (OSError, ValueError):
            return
        self._set_claude(limits)

    def _set_claude(self, limits):
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


def fetch_claude_rate_limits() -> dict:
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
    with open(os.path.join(config_dir, ".credentials.json")) as f:
        credentials = json.load(f)["claudeAiOauth"]
    request = Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={
            "Authorization": f"Bearer {credentials['accessToken']}",
            "anthropic-beta": "oauth-2025-04-20",
        },
    )
    with urlopen(request, timeout=10) as response:
        usage = json.load(response)
    limits = {}
    for key in CLAUDE_WINDOWS.values():
        window = usage.get(key) or {}
        reset = window.get("resets_at")
        limits[key] = {
            "used_percentage": window.get("utilization"),
            "resets_at": int(datetime.fromisoformat(reset).timestamp())
            if reset
            else None,
        }
    return limits


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
