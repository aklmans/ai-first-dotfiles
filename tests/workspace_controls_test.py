"""Workspace controls; run under tests/run-all.sh's desktop IPC boundary."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
STUB = '''#!{python}
import json, os, sys
from pathlib import Path
home=Path(os.environ["HOME"])
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with (home/"calls").open("a") as f: f.write(json.dumps([name,*args])+"\\n")
data=json.loads((home/"fixture.json").read_text())
if name=="aerospace":
 if args[0]=="list-monitors": print(data["monitors"])
 elif args[0]=="list-workspaces":
  if "--focused" in args: print("3")
  elif "--monitor" in args: print("3" if args[args.index("--monitor")+1]=="2" else "")
  else: print(data["placements"])
 elif args[0]=="list-windows":
  if "--json" in args: print(json.dumps(data["windows"]))
  elif "--format" in args and args[-1]=="%{{workspace-root-container-layout}}": print("h_accordion")
  elif "--format" in args and args[-1]=="%{{workspace}}%{{tab}}%{{app-name}}": print("3\\tEditor\\n3\\tEditor")
  elif "--format" in args and "app-name" in args[-1]: print("11\\t3\\torg.example.Editor\\tEditor\\tDocument\\th_accordion")
  else: print("11\\t3\\torg.example.Editor\\tfloating")
 elif args[0]=="reload-config" and data.get("fail_reload") and "--dry-run" in args: sys.exit(9)
 elif args[0]=="layout" and data.get("fail_layout"): sys.exit(7)
elif name=="sketchybar":
 if args==["--query","bar"]: print(json.dumps({{"items":["space.3","workspace_menu.old.0"]}}))
 elif args==["--query","displays"]: print(json.dumps([{{"arrangement-id":2,"UUID":"MAIN"}},{{"arrangement-id":1,"UUID":"SIDE"}}]))
elif name=="hs": print("Main Display\\t101\\tMAIN\\nSide [Lab]\\t102\\tSIDE")
'''


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.aero = self.home / ".config/aerospace"
        self.bar = self.home / ".config/sketchybar"
        shutil.copytree(REPO / "home/.config/aerospace", self.aero)
        shutil.copytree(REPO / "home/.config/sketchybar", self.bar)
        self.config = self.home / ".aerospace.toml"
        shutil.copy(REPO / "home/.aerospace.toml", self.config)
        self.preferences = self.aero / "workspace-monitors.conf"
        self.bin = self.home / "bin"
        self.bin.mkdir()
        for name in ("aerospace", "sketchybar", "hs"):
            path = self.bin / name
            path.write_text(STUB.format(python=sys.executable))
            path.chmod(0o755)
        (self.bin / "python3").symlink_to(sys.executable)
        self.env = dict(HOME=str(self.home), TMPDIR=os.environ["TMPDIR"],
                        PATH=f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
                        AEROSPACE_BIN=str(self.bin / "aerospace"), AEROSPACE=str(self.bin / "aerospace"),
                        SKETCHYBAR_BIN=str(self.bin / "sketchybar"), HS_BIN=str(self.bin / "hs"),
                        SKETCHYBAR=str(self.bin / "sketchybar"), PYTHON_BIN=sys.executable)
        self.data = {"monitors": "1\tMain Display\n2\tSide [Lab]", "placements": "1\t1\n3\t2",
                     "windows": [{"window-id": 11, "app-name": "Editor", "window-title": "a 'quote'; $(touch owned)"}]}
        self.save()

    def save(self):
        (self.home / "fixture.json").write_text(json.dumps(self.data))

    def run_script(self, name, *args):
        return subprocess.run(["/bin/bash", str(self.aero / name), *args], env=self.env,
                              capture_output=True, text=True, timeout=30)

    def calls(self):
        path = self.home / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_move_remembers_display_renders_exact_pattern_and_refreshes_bar(self):
        result = self.run_script("workspace-display.sh", "set", "2", "3")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("3|Side [Lab]\n", self.preferences.read_text())
        self.assertIn("'3' = ['^Side \\[Lab\\]$', 'main']", self.config.read_text())
        self.assertIn(["aerospace", "reload-config", "--dry-run", "--no-gui"], self.calls())
        self.assertIn(["aerospace", "workspace", "3"], self.calls())
        self.assertFalse(any(c[:2] == ["aerospace", "move-node-to-monitor"] for c in self.calls()))
        self.assertTrue(any(c[0] == "sketchybar" and "display=1" in c for c in self.calls()))
        self.assertTrue(list(self.aero.glob("workspace-monitors.conf")))

    def test_reset_keeps_other_workspace_preferences(self):
        self.preferences.write_text("3|Side [Lab]\n4|Main Display\n")
        result = self.run_script("workspace-display.sh", "reset", "3")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("4|Main Display\n", self.preferences.read_text())
        self.assertIn("'3' = ['main']", self.config.read_text())
        self.assertTrue(list(self.aero.glob("workspace-monitors.conf.bak-*")))

    def test_next_cycles_from_actual_monitor(self):
        result = self.run_script("workspace-display.sh", "next", "3")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("3|Main Display\n", self.preferences.read_text())

    def test_reload_failure_rolls_back_both_files(self):
        before = self.config.read_bytes()
        self.data["fail_reload"] = True
        self.save()
        result = self.run_script("workspace-display.sh", "set", "2", "3")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual(before, self.config.read_bytes())
        self.assertFalse(self.preferences.exists())

    def test_invalid_selection_and_single_display_do_not_write(self):
        before = self.config.read_bytes()
        for args in (("set", "999", "3"), ("set", "2", "999")):
            self.assertNotEqual(0, self.run_script("workspace-display.sh", *args).returncode)
        self.data["monitors"] = "1\tMain Display"
        self.data["placements"] = "3\t1"
        self.save()
        self.assertNotEqual(0, self.run_script("workspace-display.sh", "next", "3").returncode)
        self.assertEqual(before, self.config.read_bytes())
        self.assertFalse(self.preferences.exists())

    def test_bad_preferences_and_bad_candidate_leave_files_untouched(self):
        before = self.config.read_bytes()
        self.preferences.write_text("3|Side [Lab]\n3|Other\n")
        self.assertNotEqual(0, self.run_script("render-layout.sh", "--stdout", "--no-app-rules").returncode)
        self.preferences.unlink()
        self.config.write_text("invalid TOML")
        self.assertNotEqual(0, self.run_script("workspace-display.sh", "set", "2", "3").returncode)
        self.assertFalse(self.preferences.exists())
        self.assertEqual("invalid TOML", self.config.read_text())
        self.config.write_bytes(before)

    def test_disconnected_preference_keeps_fallback_and_is_not_erased(self):
        self.preferences.write_text("3|Disconnected Display\n")
        result = self.run_script("render-layout.sh", "--stdout", "--no-app-rules")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("'3' = ['^Disconnected Display$', 'main']", result.stdout)
        self.assertEqual("3|Disconnected Display\n", self.preferences.read_text())

    def test_refuse_symlink_and_existing_writer_lock(self):
        outside = self.home / "other"
        outside.write_text("unchanged")
        self.preferences.symlink_to(outside)
        self.assertNotEqual(0, self.run_script("workspace-display.sh", "set", "2", "3").returncode)
        self.assertEqual("unchanged", outside.read_text())
        self.preferences.unlink()
        (self.home / ".local/state/ai-first-dotfiles/write.lock").mkdir(parents=True)
        self.assertNotEqual(0, self.run_script("workspace-display.sh", "set", "2", "3").returncode)
        self.assertFalse(self.preferences.exists())

    def test_layout_commands_target_root_even_when_focused_window_floats(self):
        for layout in ("accordion", "tiles"):
            result = self.run_script("layout-control.sh", layout)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn(["aerospace", "layout", "--root", layout, "horizontal"], self.calls())
        self.assertFalse(any("tiling" in call for call in self.calls()))

    def test_repair_preserves_accordion_and_reports_command_failures(self):
        result = self.run_script("layout-control.sh", "repair-workspace")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(["aerospace", "layout", "--root", "accordion", "horizontal"], self.calls())
        self.data["fail_layout"] = True
        self.save()
        self.assertEqual(7, self.run_script("layout-control.sh", "tiles").returncode)

    def test_bar_tracks_actual_display_identity_and_duplicate_window_count(self):
        result = subprocess.run(["/bin/bash", str(self.bar / "plugins/aerospace_spaces.sh")],
                                env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stderr)
        updates = [call for call in self.calls() if call[0] == "sketchybar" and "space.3" in call and "--animate" in call]
        self.assertTrue(updates)
        args = updates[-1]
        row = args[args.index("space.3") + 1:args.index("space.4") - 1]
        self.assertIn("display=1", row)  # AeroSpace monitor 2 != bar display 2.
        self.assertTrue(any(s.startswith("label=") and s.endswith(" 2") for s in row))
        self.assertLessEqual(len([c for c in self.calls() if c[0] == "hs"]), 3)

    def test_menu_uses_exact_window_ids_and_treats_titles_as_data(self):
        result = subprocess.run([sys.executable, "-B", str(self.bar / "plugins/workspace-menu.py"), "3"],
                                env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stderr)
        commands = [arg for call in self.calls() if call[0] == "sketchybar" for arg in call if arg.startswith("click_script=")]
        self.assertTrue(any("focus --window-id 11" in s for s in commands))
        self.assertFalse(any("touch owned" in s for s in commands))
        self.assertTrue(any("workspace-display.sh set 2 3" in s for s in commands))

    def test_arrow_cycle_uses_actual_monitor_group_after_move(self):
        self.data["placements"] = "1\t1\n2\t1\n3\t2\n7\t2\n8\t2"
        self.save()
        result = self.run_script("focus-workspace-arrow.sh", "next")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(["aerospace", "workspace", "7"], self.calls())
        self.assertNotIn(["aerospace", "workspace", "4"], self.calls())


if __name__ == "__main__":
    unittest.main()
