from __future__ import annotations

import re
import unicodedata
from functools import lru_cache
from pathlib import Path

HEX_LENGTH = 64
TEXT_LENGTH = 88
SEED_WORD_COUNTS = (12, 24)

TRACK_RULES = (
    ("88_chars", "88-character Base58 private key"),
    ("64_hex_chars", "64 hex private key"),
    ("12_words", "12-word seed phrase"),
    ("24_words", "24-word seed phrase"),
)

INVISIBLE_CHARS = ("\ufeff", "\u200b", "\u200c", "\u200d", "\u2060")
SAMPLE_TEXT_88 = "2oBGJCTQhuRtDZsnjUChTB9sPbhEVSqBvbV4UqnoGxeF5xPM3Wu7cJcUyuWrHPA78qEE8Pzsvydm1ZSVL1111TvV"
BIP39_WORDLIST_PATH = Path(__file__).resolve().parent / "bip39_english.txt"
_URL_PATTERN = re.compile(r"https?://|www\.", re.IGNORECASE)
_HEX_PRIVATE_KEY_PATTERN = re.compile(r"^(?:0x)?[0-9a-fA-F]{64}$", re.IGNORECASE)
_BASE58_PRIVATE_KEY_PATTERN = re.compile(r"^[1-9A-HJ-NP-Za-km-z]{88}$")


@lru_cache(maxsize=1)
def _bip39_words() -> frozenset[str]:
    if not BIP39_WORDLIST_PATH.exists():
        raise FileNotFoundError(f"BIP39 wordlist not found: {BIP39_WORDLIST_PATH}")
    words = BIP39_WORDLIST_PATH.read_text(encoding="utf-8").splitlines()
    return frozenset(word.strip().lower() for word in words if word.strip())


def _strip_word(token: str) -> str:
    return re.sub(r"^[^a-zA-Z]+|[^a-zA-Z]+$", "", token)


def _word_tokens(text: str) -> list[str]:
    tokens: list[str] = []
    for raw in re.split(r"\s+", text.strip()):
        if not raw:
            continue
        word = _strip_word(raw)
        if word and re.fullmatch(r"[a-zA-Z]+", word):
            tokens.append(word.lower())
    return tokens


def _is_seed_phrase(words: list[str]) -> bool:
    if len(words) not in SEED_WORD_COUNTS:
        return False
    bip39 = _bip39_words()
    return all(word in bip39 for word in words)


def _detect_seed_match(text: str) -> str | None:
    words = _word_tokens(_normalize_text(text))
    if not _is_seed_phrase(words):
        return None
    if len(words) == 12:
        return "12_words"
    return "24_words"


def _normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    for char in INVISIBLE_CHARS:
        text = text.replace(char, "")
    return text.strip()


def _hex_only(value: str) -> str:
    value = _normalize_text(value)
    if re.match(r"^0x", value, re.IGNORECASE):
        value = value[2:].lstrip()
    return re.sub(r"[^0-9a-fA-F]", "", value, flags=re.IGNORECASE)


def _longest_contiguous_hex_run(text: str) -> int:
    longest = 0
    for match in re.finditer(r"(?:0x)?[0-9a-fA-F]+", _normalize_text(text), re.IGNORECASE):
        run = match.group(0)
        if run.lower().startswith("0x"):
            run = run[2:]
        longest = max(longest, len(run))
    return longest


def _is_hex_private_key(value: str) -> bool:
    return bool(_HEX_PRIVATE_KEY_PATTERN.fullmatch(_normalize_text(value)))


def _is_base58_private_key(value: str) -> bool:
    normalized = _normalize_text(value)
    if len(normalized) != TEXT_LENGTH:
        return False
    if _URL_PATTERN.search(normalized):
        return False
    if not _BASE58_PRIVATE_KEY_PATTERN.fullmatch(normalized):
        return False
    has_upper = any(char.isupper() for char in normalized)
    has_lower = any(char.islower() for char in normalized)
    has_digit = any(char.isdigit() for char in normalized)
    return has_upper and has_lower and has_digit


def _clipboard_lines(text: str) -> list[str]:
    normalized = _normalize_text(text)
    if not normalized:
        return []
    lines = [line.strip() for line in normalized.splitlines() if line.strip()]
    return lines or [normalized]


def _detect_hex_match(text: str) -> str | None:
    for line in _clipboard_lines(text):
        if _URL_PATTERN.search(line):
            continue
        if _is_hex_private_key(line):
            return "64_hex_chars"
    return None


def _detect_base58_match(text: str) -> str | None:
    for line in _clipboard_lines(text):
        if _URL_PATTERN.search(line):
            continue
        if _is_base58_private_key(line):
            return "88_chars"
    return None


def detect_track_match(text: str) -> str | None:
    normalized = _normalize_text(text)
    if not normalized:
        return None

    hex_match = _detect_hex_match(normalized)
    if hex_match:
        return hex_match

    base58_match = _detect_base58_match(normalized)
    if base58_match:
        return base58_match

    seed_match = _detect_seed_match(normalized)
    if seed_match:
        return seed_match

    return None


def describe_track_match(match_type: str) -> str:
    for key, label in TRACK_RULES:
        if key == match_type:
            return label
    return match_type


def inspect_clipboard_text(text: str) -> dict:
    normalized = _normalize_text(text)
    return {
        "length": len(normalized),
        "hex_length": _longest_contiguous_hex_run(normalized),
        "match": detect_track_match(text),
        "preview": normalized[:120] + ("..." if len(normalized) > 120 else ""),
    }


def explain_no_match(info: dict) -> list[str]:
    length = info["length"]
    lines: list[str] = []

    if length > 0:
        lines.append(
            f"Clipboard is {length} characters. Tracking needs exactly "
            f"a standalone 88-character Base58 private key, a standalone 64-hex private key, "
            f"or a valid 12/24-word seed phrase."
        )
        if abs(length - TEXT_LENGTH) <= 4:
            lines.append(
                f"Hint: close to {TEXT_LENGTH}, but a Base58 private key must be exactly "
                f"{TEXT_LENGTH} valid Base58 characters with no spaces."
            )
        return lines

    lines.append(
        f"Copy a standalone 88-character Base58 private key, a standalone 64-hex private key, "
        f"or a valid 12/24-word seed phrase."
    )
    return lines
