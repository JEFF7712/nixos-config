import io
import json
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import usage


class UsageTests(unittest.TestCase):
    def test_expired_window_is_unknown(self):
        self.assertIsNone(usage.Window(100, int(time.time()) - 1).used_now())

    def test_current_window_preserves_usage(self):
        self.assertEqual(usage.Window(30, int(time.time()) + 3600).used_now(), 30)

    def test_api_response_normalization(self):
        response = {
            "five_hour": {"utilization": 30, "resets_at": "2026-11-12T23:00:00Z"},
            "seven_day": {"utilization": 0, "resets_at": None},
        }
        with (
            patch(
                "usage.open",
                return_value=io.StringIO(
                    json.dumps(
                        {
                            "claudeAiOauth": {"accessToken": "test-token"},
                        }
                    )
                ),
            ),
            patch("usage.urlopen", return_value=io.StringIO(json.dumps(response))),
        ):
            limits = usage.fetch_claude_rate_limits()
        self.assertEqual(
            limits["five_hour"],
            {
                "used_percentage": 30,
                "resets_at": 1794524400,
            },
        )
        self.assertEqual(
            limits["seven_day"],
            {
                "used_percentage": 0,
                "resets_at": None,
            },
        )

    def test_refresh_replaces_expired_cache_without_statusline(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / "rate-limits.json"
            cache.write_text(
                json.dumps(
                    {
                        "five_hour": {"used_percentage": 100, "resets_at": 1},
                    }
                )
            )
            current = {
                "five_hour": {
                    "used_percentage": 30,
                    "resets_at": int(time.time()) + 3600,
                },
            }
            with (
                patch("usage.CLAUDE_CACHE", str(cache)),
                patch("usage.fetch_claude_rate_limits", return_value=current),
            ):
                data = usage.UsageData()
                data._read_claude()
                self.assertIsNone(data.get("claude", "5h").used_now())
                data._refresh_claude()
                data._read_claude()
                self.assertEqual(data.get("claude", "5h").used_now(), 30)
                self.assertEqual(json.loads(cache.read_text()), current)

    def test_network_failure_preserves_cache(self):
        data = usage.UsageData()
        data._set_claude(
            {
                "five_hour": {
                    "used_percentage": 30,
                    "resets_at": int(time.time()) + 3600,
                },
            }
        )
        with patch("usage.fetch_claude_rate_limits", side_effect=OSError("offline")):
            data._refresh_claude()
        self.assertEqual(data.get("claude", "5h").used_now(), 30)


if __name__ == "__main__":
    unittest.main()
