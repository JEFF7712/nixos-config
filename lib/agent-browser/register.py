"""Register the VM browser without replacing unrelated agent settings."""

import argparse
import json
import os
import tempfile
from pathlib import Path

import tomlkit


def write_settings(path: Path, content: str) -> None:
    """Replace a mutable configuration atomically; retain the old file on failure."""
    if path.is_symlink():
        raise RuntimeError(f"Refusing to replace managed configuration symlink: {path}")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def register(home: Path, command: str) -> None:
    updates: dict[Path, str] = {}
    codex_path = home / ".codex/config.toml"
    codex = (
        tomlkit.parse(codex_path.read_text())
        if codex_path.exists()
        else tomlkit.document()
    )
    server = {"command": command, "args": []}
    servers = codex.setdefault("mcp_servers", {})
    if servers.get("playwright") != server:
        servers["playwright"] = server
        updates[codex_path] = tomlkit.dumps(codex)

    for relative, key, value in (
        (".claude.json", "mcpServers", {"type": "stdio", **server}),
        (
            ".config/opencode/opencode.json",
            "mcp",
            {"type": "local", "command": [command], "enabled": True},
        ),
    ):
        path = home / relative
        settings = json.loads(path.read_text()) if path.exists() else {}
        servers = settings.setdefault(key, {})
        if servers.get("playwright") != value:
            servers["playwright"] = value
            updates[path] = json.dumps(settings, indent=2) + "\n"

    # Parse every existing file before writing any of them.
    for path in updates:
        if path.is_symlink():
            raise RuntimeError(
                f"Refusing to replace managed configuration symlink: {path}"
            )
    for path, content in updates.items():
        write_settings(path, content)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--command", required=True)
    args = parser.parse_args()
    register(args.home, args.command)


if __name__ == "__main__":
    main()
