from __future__ import annotations

import json
import logging
from pathlib import Path

from config import DATA_DIR, PENDING_FILE


def ensure_data_dir() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def setup_logging(log_file: Path, console: bool = True) -> None:
    ensure_data_dir()
    handlers: list[logging.Handler] = [
        logging.FileHandler(log_file, encoding="utf-8"),
    ]
    if console:
        handlers.append(logging.StreamHandler())

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=handlers,
        force=True,
    )


def append_pending(payload: dict) -> None:
    ensure_data_dir()
    with PENDING_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def load_pending() -> list[dict]:
    if not PENDING_FILE.exists():
        return []

    pending: list[dict] = []
    with PENDING_FILE.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                pending.append(json.loads(line))
            except json.JSONDecodeError:
                logging.warning("Skipping invalid pending record: %s", line)
    return pending


def save_pending(records: list[dict]) -> None:
    ensure_data_dir()
    with PENDING_FILE.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
