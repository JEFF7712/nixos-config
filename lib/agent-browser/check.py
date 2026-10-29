"""Exercise the installed browser over MCP and retain desktop/mobile screenshots."""

import argparse
import json
import queue
import re
import struct
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PAGE = b"""<!doctype html><html><head><title>Agent browser check</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font:20px sans-serif;margin:32px;background:#f0f4ff;color:#172345}
button{padding:16px;font:inherit}main{max-width:800px}h1{color:#2856b6}</style>
</head><body><main><h1>Agent browser check</h1><p>Headless Chromium is working.</p>
<button onclick="document.querySelector('#count').textContent='Count: 1'">Increment</button>
<p id="count">Count: 0</p></main></body></html>"""


class Fixture(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(PAGE)))
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, format: str, *args: object) -> None:
        pass


class Client:
    def __init__(self, command: str, output: Path) -> None:
        self.output = output
        self.process = subprocess.Popen(
            [command, "--output-dir", str(output)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            cwd=output,
        )
        self.messages: queue.Queue[dict | None] = queue.Queue()
        self.sequence = 0
        threading.Thread(target=self.read, daemon=True).start()

    def read(self) -> None:
        assert self.process.stdout is not None
        try:
            for line in self.process.stdout:
                self.messages.put(json.loads(line))
        finally:
            self.messages.put(None)

    def send(self, message: dict) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        self.process.stdin.flush()

    def request(self, method: str, params: dict) -> dict:
        self.sequence += 1
        self.send({"id": self.sequence, "method": method, "params": params})
        while True:
            message = self.messages.get(timeout=90)
            if message is None:
                raise RuntimeError(f"MCP server exited during {method}")
            if message.get("id") == self.sequence:
                if "error" in message:
                    raise RuntimeError(message["error"])
                return message["result"]
            if "method" in message and "id" in message:
                self.send(
                    {
                        "id": message["id"],
                        "error": {"code": -32601, "message": "Unsupported request"},
                    }
                )

    def tool(self, name: str, arguments: dict) -> str:
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        text = "\n".join(block.get("text", "") for block in result.get("content", []))
        if result.get("isError"):
            raise RuntimeError(f"{name}: {text}")
        for filename in re.findall(r"\[Snapshot\]\(([^)]+)\)", text):
            snapshot = (self.output / filename).resolve()
            snapshot.relative_to(self.output)
            text += "\n" + snapshot.read_text()
        return text

    def close(self) -> None:
        if self.process.poll() is None:
            try:
                self.tool("browser_close", {})
            finally:
                assert self.process.stdin is not None
                self.process.stdin.close()
                try:
                    self.process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    self.process.terminate()
                    self.process.wait(timeout=10)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--command", default="agent-browser-mcp")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--url", help="Also verify HTTPS navigation to this URL")
    args = parser.parse_args()
    output = args.output_dir.expanduser().resolve()
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    fixture = ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
    threading.Thread(target=fixture.serve_forever, daemon=True).start()
    client = Client(args.command, output)
    try:
        client.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "agent-browser-check", "version": "1"},
            },
        )
        client.send({"method": "notifications/initialized"})
        tools = client.request("tools/list", {})["tools"]
        assert any(tool["name"] == "browser_take_screenshot" for tool in tools)
        snapshot = client.tool(
            "browser_navigate", {"url": f"http://127.0.0.1:{fixture.server_port}"}
        )
        match = re.search(r'button "Increment" \[ref=([^\]]+)\]', snapshot)
        assert match is not None, snapshot
        snapshot = client.tool(
            "browser_click", {"element": "Increment button", "target": match[1]}
        )
        assert "Count: 1" in snapshot, snapshot
        screenshots = []
        for name, width, height in (("desktop", 1280, 800), ("mobile", 390, 844)):
            client.tool("browser_resize", {"width": width, "height": height})
            path = output / f"{name}.png"
            client.tool(
                "browser_take_screenshot", {"filename": str(path), "fullPage": True}
            )
            data = path.read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) > 1000
            actual_width, actual_height = struct.unpack(">II", data[16:24])
            assert actual_width == width and actual_height >= height
            screenshots.append(
                {"path": str(path), "width": actual_width, "height": actual_height}
            )
        if args.url:
            client.tool("browser_navigate", {"url": args.url})
        print(
            json.dumps(
                {"status": "ok", "interaction": "Count: 1", "screenshots": screenshots},
                indent=2,
            )
        )
    finally:
        client.close()
        fixture.shutdown()
        fixture.server_close()


if __name__ == "__main__":
    main()
