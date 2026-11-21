"""Push Spotify desktop playback to the LED matrix."""

import asyncio
import json
import os
import sys

import websockets

URL = os.environ.get("MATRIX_PLAYBACK_URL", "ws://10.0.40.15:8000/playback")
SEP = "\x1f"
FORMAT = SEP.join(["{{status}}", "{{xesam:title}}", "{{artist}}", "{{mpris:artUrl}}"])
STOPPED = {
    "type": "playback",
    "status": "Stopped",
    "title": "",
    "artist": "",
    "art_url": "",
}


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def parse(line: str) -> dict:
    parts = line.split(SEP)
    if len(parts) == 4 and parts[0] in ("Playing", "Paused"):
        return {
            "type": "playback",
            "status": parts[0],
            "title": parts[1],
            "artist": parts[2],
            "art_url": parts[3],
        }
    return dict(STOPPED)


async def follow(state: dict, changed: asyncio.Event) -> None:
    while True:
        try:
            proc = await asyncio.create_subprocess_exec(
                "playerctl",
                "--player=spotify",
                "--follow",
                "metadata",
                "--format",
                FORMAT,
                stdout=asyncio.subprocess.PIPE,
            )
            assert proc.stdout
            async for raw in proc.stdout:
                new = parse(raw.decode(errors="replace").rstrip("\n"))
                if new != state:
                    state.clear()
                    state.update(new)
                    changed.set()
            await proc.wait()
            log(f"playerctl exited with {proc.returncode}")
        except Exception as e:
            log(f"playerctl failed: {e!r}")
        if state != STOPPED:
            state.clear()
            state.update(STOPPED)
            changed.set()
        await asyncio.sleep(2)


async def push(state: dict, changed: asyncio.Event) -> None:
    delay = 2.0
    while True:
        try:
            async with websockets.connect(URL, open_timeout=5) as ws:
                log(f"connected to {URL}")
                delay = 2.0
                closed = asyncio.ensure_future(ws.wait_closed())
                try:
                    while True:
                        changed.clear()
                        await ws.send(json.dumps(state))
                        waiter = asyncio.ensure_future(changed.wait())
                        await asyncio.wait(
                            {waiter, closed},
                            return_when=asyncio.FIRST_COMPLETED,
                        )
                        if closed.done():
                            waiter.cancel()
                            raise ConnectionError("connection closed")
                finally:
                    closed.cancel()
        except Exception as e:
            if delay == 2.0:
                log(f"{URL} unavailable: {e!r}; retrying with backoff")
        await asyncio.sleep(delay)
        delay = min(delay * 2, 10.0)


async def main() -> None:
    state, changed = dict(STOPPED), asyncio.Event()
    await asyncio.gather(follow(state, changed), push(state, changed))


asyncio.run(main())
