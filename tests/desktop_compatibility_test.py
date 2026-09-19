"""Desktop compatibility with synthetic inputs only; run via tests/run-all.sh."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "home/.config/aerospace/lib/vendor"))
sys.path.insert(0, str(REPO / "bootstrap/lib"))
import tomli
from health import workspace_shortcut_conflicts

spec = importlib.util.spec_from_file_location("diagnostics", REPO / "home/.hammerspoon/diagnostics.py")
diagnostics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostics)


class DesktopCompatibility(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("AI_FIRST_", "AEROSPACE_", "SKETCHYBAR_"))}
        self.env.update(HOME=str(self.home), XDG_STATE_HOME=str(self.home / "state"),
                        AEROSPACE_LAYOUT_MONITORS_READ="1",
                        AI_FIRST_CONFIG_DIR=str(self.home / ".config/ai-first"))
        (self.home / ".hammerspoon").mkdir()

    def run_shell(self, script, **env):
        return subprocess.run(["/bin/bash", "-c", script], env=dict(self.env, **env),
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def stub(self, name, body):
        path = self.home / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o700)
        return str(path)

    def workspace(self):
        shutil.copytree(REPO / "home/.config/aerospace", self.home / ".config/aerospace")
        shutil.copy(REPO / "home/.aerospace.toml", self.home / ".aerospace.toml")

    def test_default_log_and_initialization_side_effects_removed(self):
        for name in ("init.lua", "app_reveal.lua"):
            text = (REPO / "home/.hammerspoon" / name).read_text()
            self.assertNotIn('"/tmp/hammerspoon-', text)
            self.assertNotRegex(text, r'log\([^\n]*\.\.')
            self.assertNotIn("hs.autoLaunch(", text)
            self.assertNotIn("hs.ipc.cliInstall(", text)
        self.assertNotIn("launchctl", (REPO / "home/.config/sketchybar/sketchybarrc").read_text())

    def test_private_diagnostics_permissions_retention_and_limit(self):
        diagnostics.write_event(self.home, "watcher-started", 0, now=100000)
        directory = self.home / ".hammerspoon/diagnostics"
        path = directory / "events.log"
        self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        diagnostics.write_event(self.home, "aerospace-failed", 1, now=100001)
        self.assertEqual(len(path.read_text().splitlines()), 2)
        diagnostics.write_event(self.home, "watcher-started", 0, now=200000)
        self.assertEqual(path.read_text(), "200000 watcher-started 0\n")
        path.write_text("200000 watcher-started 0\n" * 4000)
        diagnostics.write_event(self.home, "watcher-started", 0, now=200001)
        self.assertLess(path.stat().st_size, diagnostics.MAX_BYTES)
        before = path.read_bytes()
        with self.assertRaises(ValueError):
            diagnostics.write_event(self.home, "synthetic-private-title", 0)
        self.assertEqual(before, path.read_bytes())

    def test_diagnostics_refuses_symlink_and_loose_permissions(self):
        external = self.home / "external"
        external.write_text("unchanged")
        directory = self.home / ".hammerspoon/diagnostics"
        directory.mkdir(mode=0o700)
        path = directory / "events.log"
        path.symlink_to(external)
        with self.assertRaises(OSError):
            diagnostics.write_event(self.home, "watcher-started", 0)
        self.assertEqual(external.read_text(), "unchanged")
        path.unlink()
        directory.chmod(0o755)
        with self.assertRaises(ValueError):
            diagnostics.write_event(self.home, "watcher-started", 0)
        self.assertFalse(path.exists())

    def test_literal_monitor_names_are_anchored_and_escaped(self):
        self.workspace()
        name = "Panel [4K] (A)+.x?^$|{B}\\monitor's"
        result = self.run_shell('bash "$HOME/.config/aerospace/render-layout.sh" --stdout',
                                AEROSPACE_MAIN_MONITOR_NAME=name, AI_FIRST_APP_ROUTING="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = tomli.loads(result.stdout)
        pattern = data["workspace-to-monitor-force-assignment"]["1"][0]
        self.assertTrue(re.fullmatch(pattern, name))
        self.assertIsNone(re.search(pattern, "Other " + name))
        self.assertIsNone(re.search(pattern, name + " Other"))
        self.assertEqual(data["mode"]["main"]["binding"]["ctrl-3"], "workspace 3")

    def test_duplicate_monitor_names_refuse_resolution(self):
        self.workspace()
        result = self.run_shell('source "$HOME/.config/aerospace/lib/layout.sh"; aerospace_layout_resolve',
                                AEROSPACE_LAYOUT_MONITOR_LINES="1\tPanel\n2\tpanel")
        self.assertEqual(result.returncode, 65, result.stderr)
        self.assertIn("ambiguous", result.stderr)

    def resolve(self, screens, displays):
        hs = self.stub("hs", "printf '%s' \"$SCREENS\"\n")
        bar = self.stub("bar", "printf '%s' \"$DISPLAYS\"\n")
        return self.run_shell('source "$RESOLVER"; sketchybar_display_id_for_monitor Panel',
                              HS_BIN=hs, SKETCHYBAR_BIN=bar, SCREENS=screens,
                              DISPLAYS=json.dumps(displays),
                              RESOLVER=str(REPO / "home/.config/sketchybar/lib/display-resolver.sh"))

    def test_display_identity_not_sequence(self):
        displays = [{"arrangement-id": 9, "DirectDisplayID": 42, "UUID": "synthetic-panel"}]
        answer = self.resolve("Panel\t42\tsynthetic-panel\n", displays)
        self.assertEqual(answer.returncode, 0, answer.stderr)
        self.assertEqual(answer.stdout.strip(), "9")
        self.assertNotEqual(self.resolve("Panel\t42\tsynthetic-panel\n", []).returncode, 0)
        self.assertNotEqual(self.resolve("Panel\t42\tsynthetic-panel\npanel\t43\tother\n", displays).returncode, 0)
        displays[0]["UUID"] = "different-panel"
        self.assertNotEqual(self.resolve("Panel\t42\tsynthetic-panel\n", displays).returncode, 0)

    def test_main_hide_unknown_identity_does_not_write(self):
        self.workspace()
        shutil.copytree(REPO / "home/.config/sketchybar", self.home / ".config/sketchybar")
        bar = self.stub("bar", 'echo attempted >>"$HOME/bar-calls"\nexit 1\n')
        before = (self.home / ".aerospace.toml").read_bytes()
        result = self.run_shell('bash "$HOME/.config/aerospace/toggle-sketchybar-space.sh" hide-main',
                               HS_BIN="/missing/hs", SKETCHYBAR_BIN=bar,
                               AEROSPACE_LAYOUT_MONITOR_LINES="1\tPanel\n2\tSide")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, (self.home / ".aerospace.toml").read_bytes())
        self.assertFalse((self.home / "bar-calls").exists())
        self.assertFalse((self.home / ".config/aerospace/state/sketchybar-space-mode").exists())

    def test_bar_failure_does_not_persist_success(self):
        self.workspace()
        bar = self.stub("bar", "exit 1\n")
        aerospace = self.stub("aerospace", "exit 0\n")
        result = self.run_shell('bash "$HOME/.config/aerospace/toggle-sketchybar-space.sh" hide',
                               SKETCHYBAR_BIN=bar, AEROSPACE_BIN=aerospace,
                               AEROSPACE_LAYOUT_MONITOR_LINES="1\tPanel")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not accept", result.stderr)
        self.assertFalse((self.home / ".config/aerospace/state/sketchybar-space-mode").exists())

    def test_saved_shortcut_conflict_is_read_only(self):
        self.workspace()
        path = self.home / "Library/Preferences/com.apple.symbolichotkeys.plist"
        path.parent.mkdir(parents=True)
        path.write_bytes(plistlib.dumps({"AppleSymbolicHotKeys": {
            "120": {"enabled": True, "value": {"parameters": [65535, 20, 262144]}},
            "119": {"enabled": False, "value": {"parameters": [65535, 19, 262144]}},
        }}))
        before = path.read_bytes()
        warnings = workspace_shortcut_conflicts(self.home, REPO)
        self.assertEqual(len(warnings), 1)
        self.assertIn("ctrl-3", warnings[0])
        self.assertEqual(before, path.read_bytes())


if __name__ == "__main__":
    unittest.main()
