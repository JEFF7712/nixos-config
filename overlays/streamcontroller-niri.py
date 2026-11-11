import json
import os
import re
import subprocess
import threading
import time

from loguru import logger as log

import globals as gl
from src.backend.WindowGrabber.Integration import Integration
from src.backend.WindowGrabber.Window import Window

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from src.backend.WindowGrabber.WindowGrabber import WindowGrabber


AGENTS = ("claude", "codex")
FOCUS_SETTLE_SECONDS = 0.4


def _children() -> dict[int, list[tuple[int, str]]]:
    children: dict[int, list[tuple[int, str]]] = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                stat = f.read()
        except OSError:
            continue
        end = stat.rfind(")")
        comm = stat[stat.find("(") + 1 : end]
        ppid = int(stat[end + 2 :].split()[1])
        children.setdefault(ppid, []).append((int(entry), comm))
    return children


def _agent_in(pid: int | None, title: str) -> str | None:
    """Name the coding agent running in a window: by process, else by title (ssh)."""
    if pid:
        children = _children()
        stack = [pid]
        while stack:
            for child, comm in children.get(stack.pop(), []):
                for agent in AGENTS:
                    if agent in comm:
                        return agent
                stack.append(child)
    match = re.match(rf"({'|'.join(AGENTS)})\b", title)
    return match.group(1) if match else None


class Niri(Integration):
    """Tracks focus from `niri msg --json event-stream` instead of polling."""

    def __init__(self, window_grabber: "WindowGrabber"):
        super().__init__(window_grabber=window_grabber)
        self._lock = threading.Lock()
        self._windows: dict[int, dict[str, Any]] = {}
        self._focused_id: int | None = None
        self._last_emitted: Window | None = None
        self._settle: threading.Timer | None = None
        threading.Thread(
            target=self._watch, name="NiriEventStream", daemon=True
        ).start()

    def get_all_windows(self) -> list[Window]:
        with self._lock:
            return [self._parse(w) for w in self._windows.values()]

    def get_active_window(self) -> Window:
        with self._lock:
            window = self._windows.get(self._focused_id)
            return self._parse(window) if window else None

    @staticmethod
    def _parse(window: dict[str, Any]) -> Window:
        # Coding agents retitle their terminal per task, so the title alone
        # can't identify them. Append the agent to the class instead, e.g.
        # "kitty claude", which rules can match with "^kitty claude".
        app_id = window.get("app_id") or ""
        title = window.get("title") or ""
        agent = _agent_in(window.get("pid"), title)
        return Window(f"{app_id} {agent}" if agent else app_id, title)

    def _watch(self) -> None:
        while gl.threads_running:
            try:
                proc = subprocess.Popen(
                    ["niri", "msg", "--json", "event-stream"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    cwd="/",
                )
                for line in proc.stdout:
                    if not gl.threads_running:
                        break
                    self._handle(json.loads(line))
                proc.kill()
            except Exception as e:
                log.error(f"niri event stream failed: {e}")
            time.sleep(2)

    def _handle(self, event: dict[str, Any]) -> None:
        with self._lock:
            previous_focus = self._focused_id
            if "WindowsChanged" in event:
                self._windows = {w["id"]: w for w in event["WindowsChanged"]["windows"]}
                self._focused_id = next(
                    (w["id"] for w in self._windows.values() if w.get("is_focused")),
                    None,
                )
            elif "WindowOpenedOrChanged" in event:
                window = event["WindowOpenedOrChanged"]["window"]
                self._windows[window["id"]] = window
                if window.get("is_focused"):
                    self._focused_id = window["id"]
            elif "WindowClosed" in event:
                self._windows.pop(event["WindowClosed"]["id"], None)
            elif "WindowFocusChanged" in event:
                self._focused_id = event["WindowFocusChanged"]["id"]
            else:
                return
            focus_moved = self._focused_id != previous_focus

        # Wait for focus to settle so windows passed through on the way to
        # another one don't each reload a page. Title changes on the same
        # window (agent spinners) apply immediately unless a switch is pending.
        if focus_moved:
            if self._settle is not None:
                self._settle.cancel()
            self._settle = threading.Timer(FOCUS_SETTLE_SECONDS, self._emit)
            self._settle.daemon = True
            self._settle.start()
        elif self._settle is None or not self._settle.is_alive():
            self._emit()

    def _emit(self) -> None:
        # Focus events arrive before StreamController has created its decks.
        if getattr(gl, "deck_manager", None) is None:
            return

        active = self.get_active_window()
        if active is None or active == self._last_emitted:
            return
        self._last_emitted = active
        log.debug(f"niri focus: {active.wm_class!r} {active.title!r}")
        try:
            self.window_grabber.on_active_window_changed(active)
        except Exception as e:
            log.error(f"auto page change failed: {e}")
