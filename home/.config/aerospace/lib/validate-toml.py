#!/usr/bin/env python3
"""Offline TOML syntax + generated workspace/route invariants (no desktop IPC)."""
import re
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent / "vendor"))
import tomli


def validate(path):
    document = tomli.loads(Path(path).read_text())
    workspaces = document.get("persistent-workspaces")
    if not isinstance(workspaces, list) or not workspaces:
        raise ValueError("persistent-workspaces must be a nonempty list")
    if any(not isinstance(w, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", w) for w in workspaces):
        raise ValueError("invalid workspace name")
    if len(set(workspaces)) != len(workspaces):
        raise ValueError("duplicate persistent workspace")
    assignments = document.get("workspace-to-monitor-force-assignment", {})
    if not isinstance(assignments, dict) or set(assignments) - set(workspaces):
        raise ValueError("monitor assignment references an unconfigured workspace")
    for workspace, patterns in assignments.items():
        if not isinstance(patterns, (list, str, int)):
            raise ValueError("invalid monitor assignment for " + workspace)
    rules = document.get("on-window-detected", [])
    if not isinstance(rules, list) or any(not isinstance(rule, dict) for rule in rules):
        raise ValueError("on-window-detected must be an array of rule tables")
    for rule in rules:
        commands = rule.get("run", [])
        if isinstance(commands, str):
            commands = [commands]
        if not isinstance(commands, list) or any(not isinstance(c, str) for c in commands):
            raise ValueError("window rule run must be command strings")
        for command in commands:
            match = re.fullmatch(r"move-node-to-workspace\s+([A-Za-z0-9_-]+)", command)
            if match and match[1] not in workspaces:
                raise ValueError("app rule targets unconfigured workspace " + match[1])
    return document


if __name__ == "__main__":
    try:
        validate(sys.argv[1])
    except (ValueError, OSError, KeyError, TypeError, tomli.TOMLDecodeError) as error:
        print("Invalid AeroSpace candidate: " + str(error), file=sys.stderr)
        sys.exit(65)
