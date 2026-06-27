#!/usr/bin/env python3
"""Quick status check for local debugging."""

from __future__ import annotations

import sys

from config import API_URL, BOT_VERSION, LOG_FILE, PENDING_FILE
from client.api_client import ping_api
from client.event_log import load_pending
from client.os_detect import detect_os, get_hostname


def _last_log_lines(count: int = 5) -> list[str]:
    if not LOG_FILE.exists():
        return []

    lines = LOG_FILE.read_text(encoding="utf-8").splitlines()
    return lines[-count:]


def print_status() -> int:
    print(f"OS:       {detect_os()}")
    print(f"Host:     {get_hostname()}")
    print(f"Code:     v{BOT_VERSION}")
    print(f"API URL:  {API_URL}")
    print(f"API up:   {'yes' if ping_api() else 'no - start test_server.py first'}")
    print(f"Pending:  {len(load_pending())} queued in {PENDING_FILE}")

    if sys.platform == "win32":
        try:
            import subprocess

            result = subprocess.run(
                ["tasklist", "/FI", "IMAGENAME eq pythonw.exe"],
                capture_output=True,
                text=True,
                check=False,
            )
            running = "pythonw.exe" in result.stdout and "No tasks" not in result.stdout
        except OSError:
            running = False
        print(
            f"Bot:      {'running' if running else 'not running - use: python run_bot.py --install'}"
        )

    print(f"Log file: {LOG_FILE}")
    recent = _last_log_lines()
    if recent:
        print("Recent log:")
        for line in recent:
            print(f"  {line}")
        if not any(f"clipboard bot v{BOT_VERSION}" in line for line in recent):
            print("  Warning: run `python run_bot.py --install` to load the latest code")
    else:
        print("Recent log: (empty)")

    return 0 if ping_api() else 1


if __name__ == "__main__":
    raise SystemExit(print_status())
