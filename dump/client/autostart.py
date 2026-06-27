from __future__ import annotations

import logging
import os
import subprocess
import sys
from pathlib import Path

from config import APP_DIR, APP_NAME

PROJECT_ROOT = APP_DIR


def _python_executable() -> str:
    return sys.executable


def _launch_command() -> list[str]:
    if sys.platform == "win32":
        from client.windows_runner import build_launch_command

        return build_launch_command()
    return [_python_executable(), str(PROJECT_ROOT / "run_bot.py"), "--service"]


def _windows_startup_folder() -> Path:
    appdata = Path.home() / "AppData" / "Roaming"
    return (
        appdata
        / "Microsoft"
        / "Windows"
        / "Start Menu"
        / "Programs"
        / "Startup"
    )


def _install_windows() -> None:
    from client.windows_runner import build_vbs_launcher

    startup = _windows_startup_folder()
    startup.mkdir(parents=True, exist_ok=True)

    vbs_path = startup / f"{APP_NAME}.vbs"
    vbs_path.write_text(build_vbs_launcher(), encoding="utf-8")
    logging.info("Added startup launcher: %s", vbs_path)

    for legacy_name in (f"{APP_NAME}.bat",):
        legacy_path = startup / legacy_name
        if legacy_path.exists():
            legacy_path.unlink()

    try:
        import winreg

        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            key_path,
            0,
            winreg.KEY_SET_VALUE,
        ) as key:
            winreg.DeleteValue(key, APP_NAME)
    except (FileNotFoundError, OSError):
        pass


def _uninstall_windows() -> None:
    startup = _windows_startup_folder()
    for name in (f"{APP_NAME}.vbs", f"{APP_NAME}.bat"):
        path = startup / name
        if path.exists():
            path.unlink()
            logging.info("Removed startup launcher: %s", path)

    project_vbs = PROJECT_ROOT / "start_hidden.vbs"
    if project_vbs.exists():
        project_vbs.unlink()

    try:
        import winreg

        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            key_path,
            0,
            winreg.KEY_SET_VALUE,
        ) as key:
            winreg.DeleteValue(key, APP_NAME)
        logging.info("Removed registry autostart entry")
    except FileNotFoundError:
        pass
    except OSError as exc:
        logging.warning("Could not remove registry entry: %s", exc)


def _macos_plist_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"com.{APP_NAME}.plist"


def _install_macos() -> None:
    plist_path = _macos_plist_path()
    plist_path.parent.mkdir(parents=True, exist_ok=True)

    command = _launch_command()
    plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.{APP_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{command[0]}</string>
        <string>{command[1]}</string>
        <string>{command[2]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>{PROJECT_ROOT / "data" / "launchd.out.log"}</string>
    <key>StandardErrorPath</key>
    <string>{PROJECT_ROOT / "data" / "launchd.err.log"}</string>
</dict>
</plist>
"""
    plist_path.write_text(plist_content, encoding="utf-8")
    logging.info("Created LaunchAgent plist: %s", plist_path)


def _macos_launchctl_domain() -> str:
    return f"gui/{os.getuid()}/com.{APP_NAME}"


def _activate_macos() -> bool:
    plist_path = _macos_plist_path()
    domain = _macos_launchctl_domain()
    gui_target = f"gui/{os.getuid()}"

    subprocess.run(
        ["launchctl", "bootout", domain],
        capture_output=True,
        text=True,
        check=False,
    )
    subprocess.run(
        ["launchctl", "unload", "-w", str(plist_path)],
        capture_output=True,
        text=True,
        check=False,
    )

    result = subprocess.run(
        ["launchctl", "bootstrap", gui_target, str(plist_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        logging.info("Activated LaunchAgent via launchctl bootstrap")
        return True

    result = subprocess.run(
        ["launchctl", "load", "-w", str(plist_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        logging.info("Activated LaunchAgent via launchctl load -w")
        return True

    detail = (result.stderr or result.stdout or "unknown error").strip()
    logging.warning("Could not activate LaunchAgent automatically: %s", detail)
    return False


def _deactivate_macos() -> None:
    plist_path = _macos_plist_path()
    domain = _macos_launchctl_domain()

    subprocess.run(
        ["launchctl", "bootout", domain],
        capture_output=True,
        text=True,
        check=False,
    )
    if plist_path.exists():
        subprocess.run(
            ["launchctl", "unload", "-w", str(plist_path)],
            capture_output=True,
            text=True,
            check=False,
        )


def _uninstall_macos() -> None:
    _deactivate_macos()
    plist_path = _macos_plist_path()
    if plist_path.exists():
        plist_path.unlink()
        logging.info("Removed LaunchAgent plist")


def _linux_systemd_path() -> Path:
    return Path.home() / ".config" / "systemd" / "user" / f"{APP_NAME}.service"


def _linux_xdg_autostart_path() -> Path:
    return Path.home() / ".config" / "autostart" / f"{APP_NAME}.desktop"


def _install_linux() -> None:
    command = _launch_command()
    systemd_path = _linux_systemd_path()
    systemd_path.parent.mkdir(parents=True, exist_ok=True)

    service_content = f"""[Unit]
Description=Clipboard monitoring bot
After=default.target

[Service]
Type=simple
ExecStart={command[0]} {command[1]} {command[2]}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
"""
    systemd_path.write_text(service_content, encoding="utf-8")
    logging.info("Created systemd user service: %s", systemd_path)

    xdg_path = _linux_xdg_autostart_path()
    xdg_path.parent.mkdir(parents=True, exist_ok=True)
    desktop_content = f"""[Desktop Entry]
Type=Application
Name=Clipboard Bot
Exec={' '.join(command)}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
"""
    xdg_path.write_text(desktop_content, encoding="utf-8")
    logging.info("Created XDG autostart entry: %s", xdg_path)


def _activate_linux() -> bool:
    service_name = f"{APP_NAME}.service"
    subprocess.run(
        ["systemctl", "--user", "daemon-reload"],
        capture_output=True,
        text=True,
        check=False,
    )
    result = subprocess.run(
        ["systemctl", "--user", "enable", "--now", service_name],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        logging.info("Activated systemd user service: %s", service_name)
        return True

    detail = (result.stderr or result.stdout or "unknown error").strip()
    logging.warning("Could not activate systemd service automatically: %s", detail)
    logging.info("XDG autostart entry is installed; log out and back in to enable it")
    return False


def _deactivate_linux() -> None:
    service_name = f"{APP_NAME}.service"
    subprocess.run(
        ["systemctl", "--user", "disable", "--now", service_name],
        capture_output=True,
        text=True,
        check=False,
    )


def _uninstall_linux() -> None:
    _deactivate_linux()
    systemd_path = _linux_systemd_path()
    if systemd_path.exists():
        systemd_path.unlink()
        logging.info("Removed systemd user service")

    xdg_path = _linux_xdg_autostart_path()
    if xdg_path.exists():
        xdg_path.unlink()
        logging.info("Removed XDG autostart entry")


def activate_autostart() -> bool:
    if sys.platform == "darwin":
        return _activate_macos()
    if sys.platform.startswith("linux"):
        return _activate_linux()
    return True


def deactivate_autostart() -> None:
    if sys.platform == "darwin":
        _deactivate_macos()
    elif sys.platform.startswith("linux"):
        _deactivate_linux()


def post_install_message(activated: bool) -> str:
    if sys.platform == "win32":
        return "Bot is running now. It will start automatically at next Windows login."
    if sys.platform == "darwin":
        if activated:
            return "LaunchAgent activated. Bot is running now and will restart at login."
        return (
            "LaunchAgent files created, but activation failed. Run manually:\n"
            f"  launchctl bootstrap gui/{os.getuid()} "
            f"~/Library/LaunchAgents/com.{APP_NAME}.plist"
        )
    if sys.platform.startswith("linux"):
        if activated:
            return "systemd service enabled. Bot is running now and will restart at login."
        return (
            "Autostart files created. Log out and back in (or reboot) to enable login startup."
        )
    return "Autostart installed."


def install_autostart() -> None:
    if sys.platform == "win32":
        _install_windows()
    elif sys.platform == "darwin":
        _install_macos()
    elif sys.platform.startswith("linux"):
        _install_linux()
    else:
        raise OSError(f"Unsupported platform for autostart: {sys.platform}")


def uninstall_autostart() -> None:
    if sys.platform == "win32":
        _uninstall_windows()
    elif sys.platform == "darwin":
        _uninstall_macos()
    elif sys.platform.startswith("linux"):
        _uninstall_linux()
    else:
        raise OSError(f"Unsupported platform for autostart: {sys.platform}")
