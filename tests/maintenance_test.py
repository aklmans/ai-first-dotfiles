"""Run only via tests/run-all.sh -> maintenance_smoke.sh (isolated HOME/IPC)."""
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "bootstrap/lib"))
import maintenance as engine
from intent import export_intent, import_intent


class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="maintenance-unit-")
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.env = patch.dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / ".state"))
        self.env.start()
        self.service = engine.Maintenance()
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()

    def tearDown(self):
        self.output.__exit__(None, None, None)
        self.env.stop()
        self.tmp.cleanup()

    def write(self, rel, text):
        engine.atomic_bytes(self.home / rel, text.encode())

    def operation(self, text, fail=False):
        def action():
            self.write(".config/example/value", text)
            if fail:
                raise engine.Refused("injected write failure")
        return self.service.operation("update", ["home:.config/example/value"], True, action)

    def private(self):
        self.write(".config/ai-first/profile.conf", '''# secret comment is not exported
EXAMPLE_TOKEN="do-not-export"
AI_FIRST_PRESET="private-test"
AI_FIRST_APP_ROUTING="1"
AI_FIRST_ROUTING_PACK="private-pack"
AI_FIRST_FEATURE_RECORDING="1"
AI_FIRST_FEATURE_AI_HOTKEYS="0"
AI_FIRST_FEATURE_WINDOW_AUTOMATION="0"
AI_FIRST_FEATURE_NOTIFICATIONS="0"
AEROSPACE_MAIN_WORKSPACES="1 2 3 4"
AEROSPACE_SIDE_WORKSPACES="5 6 7 8"
AEROSPACE_STAGE_WORKSPACES=""
AEROSPACE_WORKSPACE_ROLE_MAP="focus:2 stage:4"
''')
        self.write(".config/ai-first/modules/private-test/recording.conf", 'AI_FIRST_FEATURE_RECORDING="1"\n')
        self.write(".config/ai-first/modules/unused/not-exported.conf", 'AI_FIRST_ROUTING_PACK="ignored"\n')
        self.write(".config/aerospace/routing-packs/private-pack.conf", "id|org.example.Private|4|prefer|tiling\n")
        self.write(".config/aerospace/app-routes.conf", "id|org.example.Editor|2|fixed|tiling\n")
        self.write(".config/ai-first/captured-routes.conf", "name|Capture|4|prefer|floating\n")
        self.write(".config/ai-first/advisor-routes.conf", "name|Advice|2|prefer|tiling\n")
        self.service.select(["workspace", "bar", "recording"], True)

    def test_three_updates_reverse_in_order(self):
        ids = [self.operation(value) for value in ("one", "two", "three")]
        with self.assertRaises(engine.Refused):
            self.service.rollback(ids[0], True)
        self.service.rollback(ids[2], True)
        self.assertEqual("two", (self.home / ".config/example/value").read_text())
        self.service.rollback(ids[1], True)
        self.assertEqual("one", (self.home / ".config/example/value").read_text())
        self.service.rollback(ids[0], True)
        self.assertFalse((self.home / ".config/example").exists())
        self.service.rollback(ids[0], True)  # Idempotent.

    def test_failure_records_and_recovers_written_subset(self):
        self.operation("original")
        with self.assertRaises(engine.Refused):
            self.operation("partly-written", fail=True)
        directory, meta = self.service.history()[-1]
        self.assertEqual("deploy-failed", meta["status"])
        self.service.rollback(directory.name, True)
        self.assertEqual("original", (self.home / ".config/example/value").read_text())

    def test_user_edit_conflicts_before_any_restore(self):
        op_id = self.operation("deployed")
        self.write(".config/example/value", "user edit")
        with self.assertRaises(engine.Refused):
            self.service.rollback(op_id, True)
        with self.assertRaises(engine.Refused):
            self.service.uninstall(True)
        self.assertEqual("user edit", (self.home / ".config/example/value").read_text())

    def test_interrupted_operation_records_written_state(self):
        def action():
            self.write("value", "partial")
            raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.service.operation("update", ["home:value"], True, action)
        directory, meta = self.service.history()[-1]
        self.assertEqual("interrupted", meta["status"])
        self.service.rollback(directory.name, True)
        self.assertFalse((self.home / "value").exists())

    def test_corrupt_backup_refuses(self):
        self.write(".config/example/value", "original")
        op_id = self.operation("replacement")
        directory, meta = self.service.load_operation(op_id)
        entry = next(e for e in meta["files"] if e["before"]["kind"] == "file")
        engine.atomic_bytes(directory / "before" / entry["image"], b"corrupt")
        with self.assertRaises(engine.Refused):
            self.service.rollback(op_id, True)
        self.assertEqual("replacement", (self.home / ".config/example/value").read_text())

    def test_uninstall_retains_unknown_files_and_all_images(self):
        ids = [self.operation(value) for value in ("a", "b", "c")]
        self.write(".config/example/mine", "keep")
        self.service.uninstall(True)
        self.assertFalse((self.home / ".config/example/value").exists())
        self.assertEqual("keep", (self.home / ".config/example/mine").read_text())
        self.assertTrue(all(self.service.load_operation(i)[1]["status"] == "rolled-back" for i in ids))

    def test_linked_ancestor_refuses(self):
        op_id = self.operation("a")
        original = self.home / ".config/example"
        aside = self.home / "aside"
        original.rename(aside)
        original.symlink_to(aside)
        with self.assertRaises(engine.Refused):
            self.service.rollback(op_id, True)
        self.assertEqual("a", (aside / "value").read_text())

    def test_activation_failure_distinct_from_file_failure(self):
        real = engine.run_child
        def child(argv, **kwargs):
            if any("activate.sh" in str(arg) for arg in argv):
                raise engine.Refused("injected activation failure")
            return real(argv, **kwargs)
        with patch.object(engine, "run_child", child), self.assertRaises(engine.Refused):
            self.service.operation("update", ["home:value"], True, lambda: self.write("value", "new"), activate=True)
        meta = self.service.history()[-1][1]
        self.assertEqual(("activation-failed", "failed"), (meta["status"], meta["activation"]))
        self.assertEqual("new", (self.home / "value").read_text())

    def test_rollback_interruption_can_resume(self):
        for rel in ("a", "b"):
            self.write(rel, "old")
        op_id = self.service.operation("update", ["home:a", "home:b"], True,
                                       lambda: [self.write(rel, "new") for rel in ("a", "b")])
        real = engine.atomic_bytes
        def fail(path, data, mode=0o600):
            if path == self.home / "a":
                raise OSError("injected restore failure")
            real(path, data, mode)
        with patch.object(engine, "atomic_bytes", fail), self.assertRaises(OSError):
            self.service.rollback(op_id, True)
        self.assertEqual("old", (self.home / "b").read_text())
        self.assertEqual("new", (self.home / "a").read_text())
        self.service.rollback(op_id, True)
        self.assertEqual("old", (self.home / "a").read_text())

    def test_asset_inventory_matches_literal_installer_copy_targets(self):
        for module in self.service.modules:
            roots = self.service.assets([module])
            for script in self.service.modules[module][4].split(","):
                content = (REPO / "bootstrap/install" / (script + ".sh")).read_text().replace("\\\n", " ")
                copies = re.findall(r'deploy_repo_path\s+"\$repo_root"\s+"home/([^"\n]+)"', content)
                for rel in copies:
                    self.assertIn(rel, roots, module + " missing asset " + rel)

    def test_render_syntax_failure_preserves_original(self):
        self.private()
        template = self.service.render_candidate() + b'\n[broken\n'
        engine.atomic_bytes(self.home / ".aerospace.toml", template)
        with self.assertRaises(engine.Refused):
            engine.run_child(["/bin/bash", str(REPO / "home/.config/aerospace/render-layout.sh"),
                              str(self.home / ".aerospace.toml")], env=self.service.render_env(), capture=True)
        self.assertEqual(template, (self.home / ".aerospace.toml").read_bytes())

    def test_private_bundle_round_trip(self):
        self.private()
        expected = self.service.render_candidate()
        bundle = self.root / "bundle"
        export_intent(self.service, bundle, True)
        manifest = json.loads((bundle / "manifest.json").read_text())
        self.assertIn(".config/aerospace/routing-packs/private-pack.conf", manifest["files"])
        self.assertNotIn(".config/ai-first/modules/unused/not-exported.conf", manifest["files"])
        exported = (bundle / "files/.config/ai-first/profile.conf").read_text()
        self.assertNotIn("secret", exported)
        self.assertNotIn("do-not-export", exported)
        self.assertEqual(0o700, bundle.stat().st_mode & 0o777)
        restored = self.root / "restored"
        restored.mkdir()
        with patch.dict(os.environ, HOME=str(restored), XDG_STATE_HOME=str(restored / ".state")):
            target = engine.Maintenance()
            import_intent(target, bundle, True)
            target.update(True)
            self.assertEqual(expected, (restored / ".aerospace.toml").read_bytes())
            self.assertFalse((restored / ".zshenv").exists())

    def test_private_preferences_survive_module_growth(self):
        self.private()
        profile = (self.home / ".config/ai-first/profile.conf").read_bytes()
        expected = self.service.render_candidate()
        for modules in (["workspace"], ["bar"], ["recording"], ["recording", "notifications", "ai"]):
            self.service.select(modules, True)
            self.service.update(True)
            self.assertEqual(profile, (self.home / ".config/ai-first/profile.conf").read_bytes())
            self.assertEqual(expected, (self.home / ".aerospace.toml").read_bytes())
        self.assertFalse((self.home / ".zshenv").exists())
        self.assertFalse((self.home / ".warp").exists())

    def test_module_reinstall_adopts_private_data_without_reset(self):
        self.private()  # No copy-deploy baselines exist yet.
        expected = {rel: (self.home / rel).read_bytes() for rel in (
            ".config/ai-first/profile.conf", ".config/aerospace/app-routes.conf",
            ".config/aerospace/routing-packs/private-pack.conf")}
        env = dict(self.service.render_env(), DOTFILES_SKIP_PREFLIGHT="1")
        engine.run_child(["/bin/bash", str(REPO / "bootstrap/setup.sh"), "recording", "--deploy-only"], env=env, capture=True)
        for rel, before in expected.items():
            self.assertEqual(before, (self.home / rel).read_bytes(), rel)

    def test_import_rejects_checksum_traversal_revision_and_existing_edits(self):
        self.private()
        bundle = self.root / "bundle"
        export_intent(self.service, bundle, True)
        original = json.loads((bundle / "manifest.json").read_text())
        for update in ({"revision": "wrong"}, {"files": {"../outside": "bad"}},
                       {"files": {".config/ai-first/profile.conf": "bad"}}):
            engine.save_json(bundle / "manifest.json", dict(original, **update))
            with self.assertRaises(engine.Refused):
                import_intent(self.service, bundle, True)
        engine.save_json(bundle / "manifest.json", original)
        with self.assertRaises(engine.Refused):
            import_intent(self.service, bundle, True)  # Existing comments/data differ: no overwrite.

    def test_cli_import_refusals_are_handled_without_writes(self):
        self.private()
        bundle = self.root / "bundle"
        export_intent(self.service, bundle, True)
        original = json.loads((bundle / "manifest.json").read_text())
        restored = self.root / "restored"
        restored.mkdir()
        cases = (
            ({"revision": "wrong"}, "implementation"),
            ({"files": {"../outside": "bad"}}, "path"),
            ({"files": {".config/ai-first/profile.conf": "bad"}}, "checksum"),
        )
        for update, reason in cases:
            with self.subTest(reason=reason):
                engine.save_json(bundle / "manifest.json", dict(original, **update))
                result = subprocess.run(
                    ["/bin/bash", str(REPO / "bootstrap/setup.sh"), "import", str(bundle), "--apply"],
                    env=dict(os.environ, HOME=str(restored), XDG_STATE_HOME=str(restored / ".state")),
                    capture_output=True, text=True, timeout=30,
                )
                self.assertEqual(3, result.returncode, result.stderr)
                self.assertIn("Refused: ", result.stderr)
                self.assertIn(reason, result.stderr.lower())
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual([], list(restored.iterdir()))

    def test_invalid_render_is_preflight_no_copy(self):
        self.private()
        self.write(".config/aerospace/app-routes.conf", "id|org.example.Bad|999|fixed|tiling\n")
        with self.assertRaises(engine.Refused):
            self.service.update(True)
        self.assertFalse((self.home / ".aerospace.toml").exists())
        self.assertFalse((self.home / ".config/sketchybar").exists())

    def test_type_collisions_refuse_before_implementation_copy(self):
        self.private()
        self.write(".config/sketchybar", "not a directory")
        with self.assertRaises(engine.Refused):
            self.service.update(True)
        self.assertEqual("not a directory", (self.home / ".config/sketchybar").read_text())
        self.assertFalse((self.home / ".config/aerospace/render-layout.sh").exists())
        (self.home / ".config/sketchybar").unlink()
        self.write(".aerospace.toml/user-file", "keep this directory")
        with self.assertRaises(engine.Refused):
            self.service.update(True)
        self.assertEqual("keep this directory", (self.home / ".aerospace.toml/user-file").read_text())

    def test_maintenance_previews_do_not_write_home(self):
        self.private()
        def snapshot():
            return {str(p): engine.fingerprint(p) for p in self.home.rglob("*")}
        before = snapshot()
        self.service.update(False)
        export_intent(self.service, self.root / "preview-bundle", False)
        self.assertEqual(before, snapshot())
        self.assertFalse((self.root / "preview-bundle").exists())

    def test_profile_last_assignment_agrees_with_shell_and_catalog(self):
        profile = self.home / "profile.conf"
        engine.atomic_bytes(profile, b'AI_FIRST_PRESET="first"\nAI_FIRST_PRESET="last"  \nAI_FIRST_PRESET="$(false)"\n')
        self.assertEqual("last", engine.read_profile(profile)["AI_FIRST_PRESET"])
        catalog = engine.run_child(["/bin/bash", "-c", 'source "$1"; ai_first_profile_conf_get "$2" AI_FIRST_PRESET', "_",
                                    str(REPO / "bootstrap/catalog.sh"), str(profile)], capture=True)
        env = dict(self.service.render_env(), AI_FIRST_PROFILE_PATH=str(profile))
        shell = engine.run_child(["/bin/bash", "-c", 'source "$1"; printf "%s" "$AI_FIRST_PRESET"', "_",
                                  str(REPO / "home/.config/ai-first/lib/profile.sh")], env=env, capture=True)
        self.assertEqual("last", catalog.strip())
        self.assertEqual("last", shell)
        if shutil.which("lua"):
            # Compile only the actual pure parser prefix, never Hammerspoon init.
            lua = '''hs={window={}}
local f=assert(io.open(arg[1])); local source=f:read("*a"); f:close()
local prefix=assert(source:match("^(.-)\\n%-%- Keep this in step"))
assert(load(prefix .. '\\nprint(readAiFirstProfileFile("' .. arg[2] .. '", {}).AI_FIRST_PRESET)'))()
'''
            script = self.root / "parser.lua"
            engine.atomic_bytes(script, lua.encode())
            result = engine.run_child(["lua", str(script), str(REPO / "home/.hammerspoon/init.lua"), str(profile)],
                                      env=env, capture=True)
            self.assertEqual("last", result.strip())


if __name__ == "__main__":
    if os.environ.get("AI_FIRST_TEST_ISOLATED") != "1":
        raise SystemExit("Use tests/run-all.sh tests/smoke/maintenance_smoke.sh")
    unittest.main()
