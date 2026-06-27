from __future__ import annotations

import logging
import time

import requests

from config import API_KEY, API_URL, REQUEST_RETRIES, REQUEST_TIMEOUT


def _request_headers() -> dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["X-Api-Key"] = API_KEY
    return headers


def ping_api() -> bool:
    try:
        response = requests.get(API_URL, timeout=REQUEST_TIMEOUT, headers=_request_headers())
        return response.ok
    except requests.RequestException:
        return False


def _post_with_retries(payload: dict) -> bool:
    for attempt in range(1, REQUEST_RETRIES + 1):
        try:
            response = requests.post(
                API_URL,
                json=payload,
                timeout=REQUEST_TIMEOUT,
                headers=_request_headers(),
            )
            response.raise_for_status()
            logging.info("Payload sent successfully (attempt %s)", attempt)
            return True
        except requests.RequestException as exc:
            logging.warning(
                "API request failed (attempt %s/%s): %s",
                attempt,
                REQUEST_RETRIES,
                exc,
            )
            if attempt < REQUEST_RETRIES:
                time.sleep(attempt)
    return False


def send_payload(payload: dict, queue_on_failure: bool = True) -> bool:
    if _post_with_retries(payload):
        return True

    if queue_on_failure:
        from client.event_log import append_pending

        append_pending(payload)
        logging.error("Payload queued locally after %s failed attempts", REQUEST_RETRIES)
    return False


def flush_pending() -> None:
    from client.event_log import load_pending, save_pending

    pending = load_pending()
    if not pending:
        return

    remaining: list[dict] = []
    for index, record in enumerate(pending):
        if send_payload(record, queue_on_failure=False):
            continue
        remaining = pending[index:]
        break

    save_pending(remaining)
    if remaining:
        logging.info("%s pending payload(s) remain queued", len(remaining))
