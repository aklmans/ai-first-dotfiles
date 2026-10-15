#!/usr/bin/env python3
"""Option-click a workspace: layouts, display preferences and exact windows."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


def query(binary, *args):
    return subprocess.run([binary, *args], capture_output=True, text=True,
                          check=True, timeout=5).stdout.strip()


def show(workspace):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", workspace):
        raise ValueError("Invalid workspace")
    aero = os.environ.get("AEROSPACE", "/opt/homebrew/bin/aerospace")
    bar = os.environ.get("SKETCHYBAR_BIN", "/opt/homebrew/bin/sketchybar")
    config = Path(os.environ.get("AEROSPACE_CONFIG_DIR", str(Path.home() / ".config/aerospace")))
    parent = "space." + workspace
    known = json.loads(query(bar, "--query", "bar"))["items"]
    if parent not in known:
        raise ValueError("Workspace is not present in SketchyBar")
    args = []
    for item in known:
        if item.startswith("workspace_menu."):
            args.extend(["--remove", item])
        elif item.startswith("space."):
            args.extend(["--set", item, "popup.drawing=off"])

    rows = []
    switch = shlex.join([aero, "workspace", workspace])
    hide = shlex.join([bar, "--set", parent, "popup.drawing=off"])
    for title, mode in (("平铺显示", "tiles"), ("手风琴叠放", "accordion")):
        rows.append((title, switch + " && " + shlex.join(["/bin/bash", str(config / "layout-control.sh"), mode])))
    for line in query(aero, "list-monitors", "--format", "%{monitor-id}%{tab}%{monitor-name}").splitlines():
        identity, name = line.split("\t", 1)
        if not identity.isdigit():
            raise ValueError("Invalid display identity")
        rows.append(("移到并记住：" + name, shlex.join(["/bin/bash", str(config / "workspace-display.sh"), "set", identity, workspace])))
    rows.append(("恢复默认显示器", shlex.join(["/bin/bash", str(config / "workspace-display.sh"), "reset", workspace])))
    windows = json.loads(query(aero, "list-windows", "--workspace", workspace, "--json"))
    for window in windows:
        identity = window["window-id"]
        if type(identity) is not int or identity <= 0:
            raise ValueError("Invalid window identity")
        label = str(window.get("app-name", "")) + " · " + str(window.get("window-title", ""))
        label = " ".join(label.split())[:100]
        rows.append((label, switch + " && " + shlex.join([aero, "focus", "--window-id", str(identity)])))
    for i, (title, command) in enumerate(rows):
        name = f"workspace_menu.{workspace}.{i}"
        args.extend(["--add", "item", name, "popup." + parent, "--set", name,
                     "icon.drawing=off", "label=" + title, "label.font=SF Pro:Regular:13.0",
                     "label.padding_left=12", "label.padding_right=12", "label.color=0xffeeeeee",
                     "background.height=30", "click_script=" + hide + "; " + command])
    args.extend(["--set", parent, "popup.align=left", "popup.background.color=0xff252525",
                 "popup.background.border_color=0xff555555", "popup.background.border_width=1",
                 "popup.background.corner_radius=8", "popup.drawing=on"])
    subprocess.run([bar, *args], check=True, timeout=5)


if __name__ == "__main__":
    try:
        show(sys.argv[1])
    except (ValueError, KeyError, IndexError, OSError, subprocess.SubprocessError) as error:
        print(f"Cannot open workspace menu: {error}", file=sys.stderr)
        sys.exit(1)
