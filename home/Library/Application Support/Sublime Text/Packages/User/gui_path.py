import os


GUI_PATH_PREFIXES = [
    "/opt/homebrew/bin",
    "/opt/homebrew/sbin",
    "/usr/local/bin",
]


def ensure_gui_path():
    current_path = os.environ.get("PATH", "")
    parts = [part for part in current_path.split(os.pathsep) if part]
    for prefix in reversed(GUI_PATH_PREFIXES):
        if prefix not in parts:
            parts.insert(0, prefix)
    os.environ["PATH"] = os.pathsep.join(parts)


ensure_gui_path()


def plugin_loaded():
    ensure_gui_path()
