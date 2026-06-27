import getpass
import platform
import socket


def detect_os() -> str:
    system = platform.system()
    if system == "Windows":
        return "Windows"
    if system == "Darwin":
        return "macOS"
    if system == "Linux":
        return "Linux"
    return system


def get_hostname() -> str:
    computer = socket.gethostname()
    username = getpass.getuser()
    return f"{computer}${username}"
