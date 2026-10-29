"""Offline checks for preserving mutable client configuration during activation."""

import json
import tempfile
import unittest
from pathlib import Path

import tomllib
from register import register


class RegistrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        (self.home / ".codex").mkdir()
        (self.home / ".config/opencode").mkdir(parents=True)

    def test_preserves_existing_settings_and_is_idempotent(self) -> None:
        codex = self.home / ".codex/config.toml"
        codex.write_text(
            '# retain this comment\nmodel = "existing-model"\n[mcp_servers.existing]\ncommand = "existing"\n'
        )
        claude = self.home / ".claude.json"
        claude.write_text(
            json.dumps(
                {
                    "existing": {"nested": True},
                    "mcpServers": {"existing": {"command": "existing"}},
                }
            )
        )
        opencode = self.home / ".config/opencode/opencode.json"
        opencode.write_text(
            json.dumps(
                {
                    "model": "existing-model",
                    "mcp": {"existing": {"type": "local", "command": ["existing"]}},
                }
            )
        )
        register(self.home, "/profile/bin/agent-browser-mcp")
        self.assertIn("# retain this comment", codex.read_text())
        settings = tomllib.loads(codex.read_text())
        self.assertEqual(settings["model"], "existing-model")
        self.assertEqual(settings["mcp_servers"]["existing"]["command"], "existing")
        self.assertEqual(
            settings["mcp_servers"]["playwright"]["command"],
            "/profile/bin/agent-browser-mcp",
        )
        self.assertTrue(json.loads(claude.read_text())["existing"]["nested"])
        self.assertEqual(
            json.loads(claude.read_text())["mcpServers"]["existing"]["command"],
            "existing",
        )
        self.assertEqual(
            json.loads(opencode.read_text())["mcp"]["existing"]["command"], ["existing"]
        )
        before = {
            path: (path.read_bytes(), path.stat().st_mtime_ns)
            for path in (codex, claude, opencode)
        }
        register(self.home, "/profile/bin/agent-browser-mcp")
        self.assertEqual(
            before,
            {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in before},
        )
        for path in before:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_malformed_settings_fail_before_any_write(self) -> None:
        path = self.home / ".claude.json"
        path.write_text("{broken")
        with self.assertRaises(json.JSONDecodeError):
            register(self.home, "/browser")
        self.assertEqual(path.read_text(), "{broken")
        self.assertFalse((self.home / ".codex/config.toml").exists())

    def test_managed_symlink_is_preserved(self) -> None:
        source = self.home / "managed.toml"
        source.write_text('model = "managed"\n')
        path = self.home / ".codex/config.toml"
        path.symlink_to(source)
        with self.assertRaisesRegex(RuntimeError, "managed configuration symlink"):
            register(self.home, "/browser")
        self.assertTrue(path.is_symlink())
        self.assertEqual(source.read_text(), 'model = "managed"\n')


if __name__ == "__main__":
    unittest.main()
