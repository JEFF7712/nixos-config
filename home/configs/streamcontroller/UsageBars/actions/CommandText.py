import os
import subprocess
import threading

from gi.repository import GLib
from loguru import logger as log

from src.backend.PluginManager.ActionBase import ActionBase


class CommandText(ActionBase):
    """Shows a command's output as the key's center label.

    Unlike the OS plugin's Run Command, it runs as soon as the page opens,
    then every `interval` seconds and on key press.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._ticks = 0
        self._running = threading.Lock()

    def on_ready(self):
        self._ticks = 0
        self._refresh()

    def on_tick(self):
        self._ticks += 1
        if self._ticks % max(1, int(self.get_settings().get("interval", 10))) == 0:
            self._refresh()

    def on_key_down(self):
        self._refresh()

    def _refresh(self):
        if not self._running.acquire(blocking=False):
            return
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        try:
            result = subprocess.run(
                self.get_settings().get("command", "true"),
                shell=True,
                capture_output=True,
                text=True,
                timeout=20,
                cwd=os.path.expanduser("~"),
            )
            text = result.stdout.rstrip()
        except Exception as exc:
            log.warning(f"CommandText: {exc}")
            text = "error"
        finally:
            self._running.release()
        GLib.idle_add(self._show, text)

    def _show(self, text: str) -> bool:
        if self.on_ready_called and self.get_is_present():
            self.set_center_label(
                text, font_size=self.get_settings().get("font_size", 14)
            )
        return False
