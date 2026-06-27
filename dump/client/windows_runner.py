from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from config import APP_DIR

PROJECT_ROOT = APP_DIR
SERVICE_FLAG = "--service"
CREATE_NO_WINDOW = 0x08000000
DETACHED_PROCESS = 0x00000008
SW_HIDE = 0


def pythonw_executable() -> Path:
    pythonw = Path(sys.executable).with_name("pythonw.exe")
    if pythonw.exists():
        return pythonw
    return Path(sys.executable)


def build_launch_command() -> list[str]:
    return [str(pythonw_executable()), str(PROJECT_ROOT / "run_bot.py"), SERVICE_FLAG]


def build_windows_cmdline() -> str:
    command = build_launch_command()
    runner = command[0]
    script = command[1]
    args = " ".join(command[2:])
    project = str(PROJECT_ROOT)
    return f'cmd /c cd /d "{project}" && "{runner}" "{script}" {args}'


def stop_hidden_bots() -> int:
    if sys.platform != "win32":
        return 0

    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-Command",
            (
                "Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe'\" | "
                f"Where-Object {{ $_.CommandLine -like '*{PROJECT_ROOT.name}*run_bot.py*' }} | "
                "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $_.ProcessId }"
            ),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return len([line for line in result.stdout.splitlines() if line.strip().isdigit()])


def start_service() -> None:
    if sys.platform != "win32":
        command = build_launch_command()
        subprocess.Popen(command, cwd=str(PROJECT_ROOT), close_fds=True)
        return

    vbs_path = PROJECT_ROOT / "data" / "_launch_now.vbs"
    vbs_path.parent.mkdir(parents=True, exist_ok=True)
    vbs_path.write_text(build_vbs_launcher(), encoding="utf-8")
    subprocess.Popen(
        ["wscript.exe", str(vbs_path)],
        cwd=str(PROJECT_ROOT),
        creationflags=CREATE_NO_WINDOW,
        close_fds=True,
    )


def _escape_vbs_string(value: str) -> str:
    return value.replace('"', '""')


def build_vbs_launcher() -> str:
    cmdline = _escape_vbs_string(build_windows_cmdline())
    return (
        'Set shell = CreateObject("Wscript.Shell")\r\n'
        f'shell.Run "{cmdline}", 0, False\r\n'
    )
