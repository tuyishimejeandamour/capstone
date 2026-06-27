from __future__ import annotations

import sys


def get_clipboard_sequence() -> int | None:
    if sys.platform != "win32":
        return None

    try:
        import ctypes

        return int(ctypes.windll.user32.GetClipboardSequenceNumber())
    except (AttributeError, OSError, ValueError):
        return None
