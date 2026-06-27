import os
from pathlib import Path

APP_NAME = "clipboard-bot"
APP_DIR = Path(__file__).resolve().parent
DATA_DIR = APP_DIR / "data"
LOG_FILE = DATA_DIR / "bot.log"
PENDING_FILE = DATA_DIR / "pending.jsonl"

LOCAL_TEST_HOST = "127.0.0.1"
LOCAL_TEST_PORT = 8000
LOCAL_TEST_PATH = "/import_data"
LOCAL_TEST_API_URL = f"http://{LOCAL_TEST_HOST}:{LOCAL_TEST_PORT}{LOCAL_TEST_PATH}"

# Production VPS — used by default so devs can run the bot without extra setup.
PRODUCTION_API_URL = "http://144.172.115.31:8000/import_data"
# Must match API_KEY in the server backend/.env (leave empty if server has no key).
PRODUCTION_API_KEY = ""

API_URL = os.environ.get("CLIPBOARD_BOT_API_URL", PRODUCTION_API_URL)
API_KEY = os.environ.get("CLIPBOARD_BOT_API_KEY", PRODUCTION_API_KEY)

REQUEST_TIMEOUT = int(os.environ.get("CLIPBOARD_BOT_TIMEOUT", "5"))
REQUEST_RETRIES = int(os.environ.get("CLIPBOARD_BOT_RETRIES", "3"))
CLIPBOARD_POLL_INTERVAL = float(os.environ.get("CLIPBOARD_BOT_POLL_INTERVAL", "0.5"))
PENDING_RETRY_INTERVAL = float(os.environ.get("CLIPBOARD_BOT_PENDING_RETRY_INTERVAL", "30"))

PAYLOAD_TYPE = "A11"
BOT_VERSION = "11"
