"""Software ownership and private manifests; run only via the isolated runner."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("software", REPO / "bootstrap/lib/software.py")
software = importlib.util.module_from_spec(spec)
spec.loader.exec_module(software)


class SoftwareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()

    def executable(self, path, text="#!/bin/sh\nexit 99\n"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(0o755)
        return path

    def record(self, name, packages=None, npm_root="", formulae=None, casks=None):
        return software.tool_record(name, self.home, packages or {}, npm_root,
                                    formulae or {}, casks or {}, str(self.bin))

    def test_ownership_not_inferred_from_package_name(self):
        self.executable(self.bin / "codex")
        record = self.record("codex", casks={"codex": "1"})
        self.assertEqual("unknown", record["owner"])
        self.assertIsNone(record["command"])

    def test_brew_and_npm_owners(self):
        target = self.executable(self.home / "Caskroom/codex/1/bin/codex")
        (self.bin / "codex").symlink_to(target)
        self.assertEqual(["brew", "upgrade", "--cask", "codex"], self.record("codex", casks={"codex": "1"})["command"])
        root = self.home / "node_modules"
        package = "@earendil-works/pi-coding-agent"
        target = self.executable(root / package / "dist/cli.js")
        (self.bin / "pi").symlink_to(target)
        result = self.record("pi", {package: {"version": "1.2"}}, str(root))
        self.assertEqual("npm", result["owner"])
        self.assertEqual("1.2", result["version"])
        self.assertIn(package + "@latest", result["command"])

    def test_broken_hermes_is_not_absence_or_install_intent(self):
        path = self.home / ".local/bin/hermes"
        path.parent.mkdir(parents=True)
        path.symlink_to(self.home / "missing/venv/bin/hermes")
        record = self.record("hermes")
        self.assertEqual("broken", record["owner"])
        self.assertIsNone(record["command"])

    def test_private_policy_strict_and_missing_is_empty(self):
        path = self.home / "ownership.json"
        self.assertEqual([], software.load_policy(path)["vendor_casks"])
        path.write_text(json.dumps({"schema": 1, "vendor_casks": ["example-app"]}))
        self.assertEqual(["example-app"], software.load_policy(path)["vendor_casks"])
        for data in ({"schema": 1, "vendor_casks": ["--force"]},
                     {"schema": 1, "vendor_casks": ["x", "x"]},
                     {"schema": 1, "command": "touch secret"},
                     {"schema": 1, "cli_wrappers": {"opencode": {"path": "relative"}}}):
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                software.load_policy(path)

    def test_reviewed_wrapper_shares_owner_until_content_changes(self):
        target = self.executable(self.home / ".opencode/bin/opencode")
        wrapper = self.executable(self.bin / "opencode")
        rule = {"opencode": {"path": str(wrapper), "target": str(target),
                             "sha256": hashlib.sha256(wrapper.read_bytes()).hexdigest()}}
        record = software.tool_record("opencode", self.home, {}, "", {}, {}, str(self.bin), rule)
        self.assertEqual("native-layout", record["owner"])
        self.assertEqual([str(wrapper), "upgrade"], record["command"])
        wrapper.write_text("changed")
        record = software.tool_record("opencode", self.home, {}, "", {}, {}, str(self.bin), rule)
        self.assertEqual("unknown", record["owner"])
        self.assertIsNone(record["command"])

    def test_hermes_git_layout_requires_verified_wrapper_or_real_link(self):
        root = self.home / ".hermes/hermes-agent"
        target = self.executable(root / "hermes")
        (root / ".git").mkdir()
        wrapper = self.executable(self.bin / "hermes")
        self.assertEqual("unknown", self.record("hermes")["owner"])
        rules = {"hermes": {"path": str(wrapper), "target": str(target),
                             "sha256": hashlib.sha256(wrapper.read_bytes()).hexdigest()}}
        record = software.tool_record("hermes", self.home, {}, "", {}, {}, str(self.bin), rules)
        self.assertEqual("vendor-git-layout", record["owner"])
        self.assertEqual([str(wrapper), "update"], record["command"])

    def test_vendor_casks_excluded_without_greedy_query(self):
        def result(argv):
            self.assertNotIn("--greedy-auto-updates", argv)
            return {"status": "ok", "data": {"formulae": [], "casks": [{"name": "vendor-app"}, {"name": "managed-app"}]} if argv[0] == "brew" else {}}
        with patch.object(software, "probe_json", side_effect=result), patch.object(software, "probe_mas", return_value={"status": "ok", "data": []}):
            result = software.check_updates({"vendor_casks": ["vendor-app"]})["providers"]["brew"]
        self.assertEqual([{"name": "managed-app"}], result["data"]["casks"])
        self.assertEqual(["vendor-app"], result["vendor_managed_excluded"])

    def test_duplicate_binary_suppresses_command(self):
        target = self.executable(self.home / ".kimi-code/bin/kimi")
        (self.bin / "kimi").symlink_to(target)
        self.executable(self.home / ".local/bin/kimi")
        record = self.record("kimi")
        self.assertEqual("native-layout", record["owner"])
        self.assertIsNone(record["command"])
        self.assertTrue(any("Multiple" in note for note in record["advice"]))

    def test_openclaw_not_blind_npm_replacement(self):
        root = self.home / "node_modules"
        target = self.executable(root / "openclaw/openclaw.mjs")
        (self.bin / "openclaw").symlink_to(target)
        record = self.record("openclaw", {"openclaw": {"version": "1"}}, str(root))
        self.assertEqual("update", record["command"][-1])
        self.assertTrue(any("Gateway" in note for note in record["advice"]))

    def test_probe_disables_metadata_side_effects_and_never_uses_shell(self):
        self.executable(self.bin / "mas")
        def runner(argv, **kwargs):
            self.assertNotIn("shell", kwargs)
            self.assertEqual("1", kwargs["env"]["MAS_NO_AUTO_INDEX"])
            self.assertEqual("1", kwargs["env"]["HOMEBREW_NO_AUTO_UPDATE"])
            self.assertEqual("/", kwargs["cwd"])
            return subprocess.CompletedProcess(argv, 0, "[]", "")
        with patch.dict(os.environ, PATH=str(self.bin)):
            self.assertEqual("ok", software.probe(["mas", "list", "--json"], runner)["status"])
            self.assertEqual("unavailable", software.probe(["missing"])["status"])

    def test_malformed_json_is_not_successful_empty_inventory(self):
        with patch.object(software, "probe", return_value={"status": "ok", "text": "broken"}):
            self.assertEqual("malformed", software.probe_json(["npm"])["status"])

    def test_update_checks_do_not_upgrade_or_confuse_npm_exit_one(self):
        def result(argv):
            self.assertIn("outdated", argv)
            self.assertNotIn("--accurate", argv)
            if argv[0] == "npm":
                return {"status": "failed", "returncode": 1, "data": {"example": {"latest": "2"}}}
            return {"status": "ok", "data": {"formulae": [], "casks": []} if argv[0] == "brew" else []}
        with patch.object(software, "probe_json", side_effect=result), patch.object(software, "probe_mas", return_value={"status": "ok", "data": []}):
            self.assertEqual("ok", software.check_updates()["providers"]["npm"]["status"])
        with patch.object(software, "probe_json", return_value={"status": "failed", "returncode": 1, "data": {"error": {"code": "EACCES"}}}), patch.object(software, "probe_mas", return_value={"status": "ok", "data": []}):
            self.assertEqual("failed", software.check_updates()["providers"]["npm"]["status"])

    def test_mas_object_stream_not_single_json_document(self):
        for raw, status, count in (('{"id":1}\n{\n"id":2\n}\n', "ok", 2), ("", "ok", 0),
                                   ('{"id":1} BROKEN', "malformed", None)):
            with patch.object(software, "probe", return_value={"status": "ok", "text": raw}):
                result = software.probe_mas(["mas", "list", "--json"])
                self.assertEqual(status, result["status"])
                if count is not None:
                    self.assertEqual(count, len(result["data"]))

    def test_mas_drops_usage_purchase_and_unrelated_metadata(self):
        record = {"adamID": 123, "bundleID": "com.example.notes", "version": "1.2",
                  "usedDates": ["private"], "purchaseDate": "private", "token": "private",
                  "name": {"unexpected": "private"}}
        with patch.object(software, "probe", return_value={"status": "ok", "text": json.dumps(record)}):
            data = software.probe_mas(["mas", "list", "--json"])["data"]
        self.assertEqual([{"adamID": 123, "bundleID": "com.example.notes", "version": "1.2"}], data)

    def test_mas_receipt_coverage_mismatch_is_incomplete(self):
        apps = [{"bundle_id": "com.example.notes", "path": "/Notes.app", "app_store_receipt": True},
                {"bundle_id": "com.example.draw", "path": "/Draw.app", "app_store_receipt": True}]
        result = {"status": "ok", "data": [{"bundleID": "com.example.notes"}]}
        software.check_mas_coverage(result, apps)
        self.assertEqual("incomplete", result["status"])
        self.assertEqual([{"bundle_id": "com.example.draw", "path": "/Draw.app"}], result["receipt_apps_not_listed"])
        complete = {"status": "ok", "data": [{"bundleID": a["bundle_id"]} for a in apps]}
        software.check_mas_coverage(complete, apps)
        self.assertEqual("ok", complete["status"])
        failed = {"status": "failed", "data": None}
        software.check_mas_coverage(failed, apps)
        self.assertEqual("failed", failed["status"])

    def test_apps_metadata_only_and_duplicates_kept(self):
        for name in ("One.app", "Two.app"):
            app = self.home / name
            (app / "Contents/_MASReceipt").mkdir(parents=True)
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "com.example.same", "CFBundleName": "Same"}))
            (app / "Contents/_MASReceipt/receipt").touch()
        apps, errors = software.app_inventory([self.home])
        self.assertEqual(2, len(apps))
        self.assertTrue(all(a["app_store_receipt"] for a in apps))
        self.assertEqual([], errors)

    def shell(self, script, *args):
        env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ":/usr/bin:/bin", XDG_CONFIG_HOME=str(self.home / ".config"),
                   AI_FIRST_BREW_APPS_MANIFEST="", DOTFILES_BREW_PLAN="0")
        return subprocess.run(["/bin/bash", str(REPO / script), *args], env=env, text=True, capture_output=True)

    def test_apps_profile_has_no_author_shopping_list(self):
        result = self.shell("bootstrap/brew.sh", "apps", "--plan")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("No optional apps selected", result.stdout)
        self.assertNotIn("cursor", result.stdout)
        self.assertNotIn("claude-code", result.stdout)

    def test_private_brew_data_plan_and_injection_refusal(self):
        manifest = self.home / "apps with spaces.txt"
        manifest.write_text("cask codex\nformula jq\n")
        result = self.shell("bootstrap/brew.sh", "apps", "--plan", "--apps-manifest", str(manifest))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("codex", result.stdout)
        for invalid in ("cask --force", "cask ../../evil", "cask $(touch owned)", "exec touch owned", "cask good extra"):
            manifest.write_text("cask codex\n" + invalid + "\n")
            result = self.shell("bootstrap/brew.sh", "all", "--plan", "--apps-manifest", str(manifest))
            self.assertEqual(64, result.returncode, invalid)
            self.assertNotIn("codex", result.stdout)
        self.assertFalse((self.home / "owned").exists())

    def test_private_mas_bundle_ids_and_preflight(self):
        self.executable(self.bin / "mas", '#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/mas-calls"\n')
        manifest = self.home / "apps.txt"
        large = self.home / "large.txt"
        manifest.write_text("com.example.notes\tNotes\n")
        large.write_text("")
        result = self.shell("bootstrap/app-store.sh", "--manifest", str(manifest), "--large-manifest", str(large), "--yes")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("install --bundle com.example.notes\n", (self.home / "mas-calls").read_text())
        (self.home / "mas-calls").unlink()
        for invalid in ("123456789", "--force", "$(touch owned)"):
            large.write_text(invalid + "\tInvalid\n")
            result = self.shell("bootstrap/app-store.sh", "--manifest", str(manifest), "--large-manifest", str(large), "--yes")
            self.assertEqual(64, result.returncode)
            self.assertFalse((self.home / "mas-calls").exists())

    def test_unknown_apply_flag_refused_before_inventory(self):
        result = self.shell("bootstrap/setup.sh", "software", "plan", "--apply")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("unrecognized arguments", result.stderr)

    def test_updates_alias_previews_without_upgrading(self):
        self.assertNotIn("alias update=", (REPO / "home/.config/zsh/aliases.zsh").read_text())
        result = subprocess.run(["/bin/zsh", "-f", "-c", 'alias update="exit 99"; source "$1"; updates --only uv', "_", str(REPO / "home/.config/zsh/aliases.zsh")],
                                env=dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ":/usr/bin:/bin"), capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Preview only", result.stdout)

    def test_pnpm_existing_bin_is_on_shell_path_without_setup(self):
        directory = self.home / ".local/share/pnpm/bin"
        directory.mkdir(parents=True)
        result = subprocess.run(["/bin/zsh", "-f", "-c", 'source "$1"; print -l $path', "_", str(REPO / "home/.config/zsh/env.zsh")],
                                env={"HOME": str(self.home), "PATH": "/usr/bin:/bin"}, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(1, result.stdout.splitlines().count(str(directory)))

    def test_native_kimi_resolves_without_inherited_path(self):
        entry = self.executable(self.home / ".kimi-code/bin/kimi")
        result = subprocess.run(["/bin/zsh", "-f", "-c", 'source "$1"; source "$1"; command -v kimi; print -l $path',
                                 "_", str(REPO / "home/.config/zsh/env.zsh")],
                                env={"HOME": str(self.home), "PATH": "/usr/bin:/bin"}, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(str(entry), result.stdout.splitlines()[0])
        self.assertEqual(1, result.stdout.splitlines().count(str(entry.parent)))

    def test_absent_native_kimi_directory_is_not_added_to_path(self):
        result = subprocess.run(["/bin/zsh", "-f", "-c", 'source "$1"; print -l $path',
                                 "_", str(REPO / "home/.config/zsh/env.zsh")],
                                env={"HOME": str(self.home), "PATH": "/usr/bin:/bin"}, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertNotIn(str(self.home / ".kimi-code/bin"), result.stdout.splitlines())


if __name__ == "__main__":
    if os.environ.get("AI_FIRST_TEST_ISOLATED") != "1":
        raise SystemExit("Use tests/run-all.sh tests/smoke/software_inventory_smoke.sh")
    unittest.main()
