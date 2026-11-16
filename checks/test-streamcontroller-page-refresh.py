import ast
import re
import sys
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace


def load_methods(path):
    tree = ast.parse(Path(path).read_text())
    classes = {}
    selected = {
        "MediaPlayerThread": {
            "perform_media_player_tasks",
            "_perform_media_player_tasks",
        },
        "DeckController": {"load_page", "clear_media_player_tasks"},
        "WindowGrabber": {
            "on_active_window_changed",
            "_on_active_window_changed",
            "get_is_window_matching",
        },
    }
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name in selected:
            methods = [
                method
                for method in node.body
                if isinstance(method, ast.FunctionDef)
                and method.name in selected[node.name]
            ]
            for method in methods:
                method.decorator_list = []
            node.body = methods
            node.bases = []
            namespace = {"Window": SimpleNamespace, "re": re}
            exec(
                compile(ast.Module(body=[node], type_ignores=[]), path, "exec"),
                namespace,
            )
            classes[node.name] = namespace[node.name]
    return classes


classes = load_methods(sys.argv.pop(1))
window_classes = load_methods(sys.argv.pop(1))


class PageRefreshTests(unittest.TestCase):
    def setUp(self):
        self.controller = classes["DeckController"]()
        self.controller._page_lock = threading.RLock()
        self.controller.active_page = object()
        self.player = classes["MediaPlayerThread"]()
        self.player.deck_controller = self.controller
        self.controller.media_player = self.player
        self.player.tasks = []
        self.player.image_tasks = {}
        self.player.touchscreen_task = None

    def task(self, callback, page=None):
        return SimpleNamespace(
            page=self.controller.active_page if page is None else page,
            run=callback,
        )

    def test_replacement_image_survives_in_flight_write(self):
        writes = []
        replacement = self.task(lambda: writes.append("new"))

        def write_old():
            writes.append("old")
            self.player.image_tasks[0] = replacement

        self.player.image_tasks[0] = self.task(write_old)
        self.player.perform_media_player_tasks()
        self.assertIs(self.player.image_tasks[0], replacement)
        self.player.perform_media_player_tasks()
        self.assertEqual(writes, ["old", "new"])

    def test_previous_page_images_are_discarded(self):
        writes = []
        stale = self.task(lambda: writes.append("stale"), page=object())
        self.player.image_tasks[0] = stale
        self.player.perform_media_player_tasks()
        self.assertEqual(writes, [])

    def test_page_change_waits_for_input_update(self):
        started = threading.Event()
        release = threading.Event()
        requested = threading.Event()
        changed = threading.Event()

        def update():
            started.set()
            release.wait(2)

        def change():
            requested.set()
            self.controller.load_page("next")

        self.controller._load_page = lambda page: changed.set()
        self.player.tasks.append(self.task(update))
        worker = threading.Thread(target=self.player.perform_media_player_tasks)
        loader = threading.Thread(target=change)
        worker.start()
        try:
            self.assertTrue(started.wait(1))
            loader.start()
            self.assertTrue(requested.wait(1))
            self.assertFalse(changed.wait(0.1))
        finally:
            release.set()
            worker.join(2)
            if loader.ident is not None:
                loader.join(2)
        self.assertTrue(changed.is_set())
        self.assertFalse(worker.is_alive())
        self.assertFalse(loader.is_alive())

    def test_clear_discards_all_queued_work_without_waiting_for_tick(self):
        self.player.tasks.append(self.task(lambda: None))
        self.player.image_tasks[0] = self.task(lambda: None)
        self.player.touchscreen_task = self.task(lambda: None)
        self.controller.clear_media_player_tasks()
        self.assertEqual(self.player.tasks, [])
        self.assertEqual(self.player.image_tasks, {})
        self.assertIsNone(self.player.touchscreen_task)


class AutoReturnTests(unittest.TestCase):
    def setUp(self):
        self.pages = {
            name: SimpleNamespace(json_path=name) for name in ("Main", "AI", "Printer")
        }
        self.controller = SimpleNamespace(
            active_page=self.pages["Main"],
            page_auto_loaded=False,
            last_manual_loaded_page_path=None,
            serial_number=lambda: "deck",
            deck=SimpleNamespace(
                is_open=lambda: True, get_serial_number=lambda: "deck"
            ),
        )
        self.controller.load_page = lambda page, **kwargs: setattr(
            self.controller, "active_page", page
        )
        self.stay = False
        self.default = "Main"
        self.gl = SimpleNamespace(
            deck_manager=SimpleNamespace(deck_controller=[self.controller]),
            page_manager=SimpleNamespace(
                get_pages=lambda: ["AI"],
                get_auto_change_settings=lambda path: {
                    "enable": True,
                    "wm-class": "^kitty (codex|claude)$",
                    "title": ".*",
                    "decks": ["deck"],
                    "stay-on-page": self.stay,
                },
                get_default_page=lambda serial: self.default,
                get_page=lambda path, controller: self.pages[path],
            ),
        )
        cls = window_classes["WindowGrabber"]
        cls.on_active_window_changed.__globals__.update(
            gl=self.gl, log=SimpleNamespace(debug=lambda message: None)
        )
        self.grabber = cls()
        self.grabber._auto_change_lock = threading.Lock()

    def focus(self, app):
        self.grabber.on_active_window_changed(
            SimpleNamespace(wm_class=app, title="window")
        )

    def test_codex_returns_to_home(self):
        self.focus("kitty codex")
        self.assertIs(self.controller.active_page, self.pages["AI"])
        self.focus("firefox")
        self.assertIs(self.controller.active_page, self.pages["Main"])

    def test_already_active_ai_returns_to_default(self):
        self.controller.active_page = self.pages["AI"]
        self.focus("kitty codex")
        self.focus("firefox")
        self.assertIs(self.controller.active_page, self.pages["Main"])

    def test_missing_or_self_referential_return_path_uses_default(self):
        for path in (None, "AI"):
            with self.subTest(path=path):
                self.controller.active_page = self.pages["AI"]
                self.controller.page_auto_loaded = True
                self.controller.last_manual_loaded_page_path = path
                self.focus("firefox")
                self.assertIs(self.controller.active_page, self.pages["Main"])

    def test_previous_manual_page_is_preserved(self):
        self.controller.active_page = self.pages["Printer"]
        self.focus("kitty claude")
        self.focus("kitty codex")
        self.focus("firefox")
        self.assertIs(self.controller.active_page, self.pages["Printer"])

    def test_stay_on_page_is_preserved(self):
        self.stay = True
        self.focus("kitty codex")
        self.focus("firefox")
        self.assertIs(self.controller.active_page, self.pages["AI"])

    def test_missing_default_leaves_page_active(self):
        self.default = None
        self.controller.active_page = self.pages["AI"]
        self.focus("kitty codex")
        self.focus("firefox")
        self.assertIs(self.controller.active_page, self.pages["AI"])


if __name__ == "__main__":
    unittest.main()
