"""Run only through tests/run-all.sh; fake managers never update the host."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "home/.config/zsh/upgrade-tools.py"
ALIASES = REPO / "home/.config/zsh/aliases.zsh"
STUB = '''#!{python}
import json, os, sys
from pathlib import Path
args = [Path(sys.argv[0]).name, *sys.argv[1:]]
home = Path(os.environ["HOME"])
with (home / "calls.jsonl").open("a") as log:
    log.write(json.dumps({{"args": args, "cwd": os.getcwd(), "GOBIN": os.environ.get("GOBIN"),
        "cleanup": os.environ.get("HOMEBREW_NO_INSTALL_CLEANUP")}}) + "\\n")
entry = json.loads((home / "responses.json").read_text()).get(" ".join(args), {{}})
print(entry.get("output", ""))
sys.exit(entry.get("code", 0))
'''


class UpgradeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        # No inherited manager paths, ownership policy or project configuration.
        self.env = {"HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
                    "TMPDIR": os.environ["TMPDIR"], "XDG_CONFIG_HOME": str(self.home / ".config")}
        (self.bin / "python3").symlink_to(sys.executable)
        self.project = self.home / "project"
        self.project.mkdir()
        for name in ("package.json", "go.mod", "mise.toml"):
            (self.project / name).write_text("must not change\n")
        self.responses = {}
        self.response("brew list --cask -1", "vendor-app\nmanaged-app")
        self.root = self.home / "lib/node_modules"
        self.root.mkdir(parents=True)
        self.response("npm root --global", str(self.root))
        self.response("npm list --global --depth=0 --json", json.dumps({"dependencies": {"example-cli": {"version": "1"}}}))
        self.go_bin = self.home / "go/bin"
        self.response("go env -json GOBIN GOPATH", json.dumps({"GOBIN": str(self.go_bin), "GOPATH": str(self.home / "go")}))

    def response(self, command, output="", code=0):
        self.responses[command] = {"output": output, "code": code}
        (self.home / "responses.json").write_text(json.dumps(self.responses))

    def manager(self, name, owner_path=None):
        target = self.home / owner_path / name if owner_path else self.bin / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(STUB.format(python=sys.executable))
        target.chmod(0o755)
        if owner_path:
            (self.bin / name).symlink_to(target)
        return target

    def all_managers(self):
        for name in ("brew", "mise", "npm", "pnpm", "bun", "rustup", "cargo-install-update", "uv", "go", "mas"):
            self.manager(name)

    def invoke(self, *args):
        return subprocess.run([sys.executable, "-B", str(SCRIPT), *args], env=self.env,
                              cwd=self.project, capture_output=True, text=True, timeout=30)

    def calls(self):
        path = self.home / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def commands(self):
        return [" ".join(call["args"]) for call in self.calls()]

    def policy(self, data):
        path = self.home / ".config/ai-first/software/ownership.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))

    def test_default_updates_installed_managers_and_preserves_projects(self):
        self.all_managers()
        self.policy({"schema": 1, "vendor_casks": ["vendor-app"]})
        result = self.invoke()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        for command in ("brew update", "brew upgrade --formula", "brew upgrade --cask managed-app",
                        "mise self-update --yes", "mise upgrade", "npm update --global example-cli",
                        "pnpm update --global", "bun upgrade", "bun update --global", "rustup update",
                        "cargo-install-update --all", "uv self update", "uv tool upgrade --all", "mas upgrade"):
            self.assertIn(command, self.commands())
        self.assertNotIn("brew upgrade --cask vendor-app", self.commands())
        self.assertTrue(all(call["cwd"] == "/" and call["cleanup"] == "1" for call in self.calls()))
        for file in self.project.iterdir():
            self.assertEqual("must not change\n", file.read_text())

    def test_dry_run_only_probes_inventory(self):
        self.all_managers()
        result = self.invoke("--dry-run")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("PLAN: bun upgrade", result.stdout)
        self.assertEqual(set(self.responses), set(self.commands()))

    def test_aliases_recover_old_names_and_work_from_copied_install(self):
        self.manager("uv")
        deployed = self.home / "copied config"
        deployed.mkdir()
        for source in (SCRIPT, ALIASES):
            shutil.copy2(source, deployed / source.name)
        for name in ("update", "upgrade", "upall", "updates"):
            with self.subTest(name=name):
                log = self.home / "calls.jsonl"
                if log.exists():
                    log.unlink()
                result = subprocess.run(["/bin/zsh", "-f", "-c",
                    'alias update="exit 99" upgrade="exit 99" upall="exit 99" updates="exit 99"; '
                    'source "$1"; source "$1"; "$2" --only uv', "_", str(deployed / "aliases.zsh"), name],
                    env=self.env, cwd=self.project, capture_output=True, text=True)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertEqual([] if name == "updates" else ["uv self update", "uv tool upgrade --all"], self.commands())

    def test_missing_managers_are_skipped_without_installing_helpers(self):
        result = self.invoke()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("is not installed; skipping", result.stdout)
        self.assertEqual([], self.calls())

    def test_failures_continue_other_managers_but_report_failure(self):
        self.manager("brew")
        self.manager("uv")
        self.response("brew update", code=7)
        result = self.invoke("--only", "brew,uv")
        self.assertEqual(1, result.returncode)
        self.assertIn("brew update (exit 7)", result.stderr)
        self.assertNotIn("brew upgrade --formula", self.commands())
        self.assertIn("uv tool upgrade --all", self.commands())

    def test_interrupt_stops_remaining_steps(self):
        self.manager("bun")
        self.manager("uv")
        self.response("bun upgrade", code=130)
        result = self.invoke("--only", "bun,uv")
        self.assertEqual(130, result.returncode)
        self.assertEqual(["bun upgrade"], self.commands())

    def test_package_managed_tools_do_not_self_update(self):
        self.manager("mise", "Cellar/mise/1/bin")
        self.manager("uv", "Cellar/uv/1/bin")
        self.manager("rustup", "Cellar/rustup/1/bin")
        self.manager("bun", ".local/share/mise/installs/bun/1/bin")
        result = self.invoke("--only", "mise,bun,rust,uv")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["mise upgrade", "bun update --global", "rustup update --no-self-update", "uv tool upgrade --all"], self.commands())

    def test_npm_does_not_overwrite_homebrew_npm_or_local_links(self):
        self.manager("npm")
        target = self.home / "Cellar/node/1/lib/node_modules/npm"
        target.mkdir(parents=True)
        (self.root / "npm").symlink_to(target)
        self.response("npm list --global --depth=0 --json", json.dumps({"dependencies": {
            "npm": {"version": "1"}, "local-cli": {"resolved": "file:../project"}, "@example/cli": {"version": "1"}}}))
        result = self.invoke("--only", "npm")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("npm update --global @example/cli", self.commands())
        self.assertNotIn("npm update --global", self.commands())

    def test_empty_or_excluded_casks_never_expand_to_all(self):
        self.manager("brew")
        self.policy({"schema": 1, "vendor_casks": ["vendor-app", "managed-app"]})
        result = self.invoke("--only", "brew")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse(any(command.startswith("brew upgrade --cask") for command in self.commands()))

    def test_npm_does_not_replace_managed_nodes_npm_even_if_previously_overwritten(self):
        self.manager("npm")
        self.manager("node", "Cellar/node/1/bin")
        self.response("npm list --global --depth=0 --json", json.dumps({"dependencies": {"npm": {"version": "1"}}}))
        result = self.invoke("--only", "npm")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse(any(command.startswith("npm update") for command in self.commands()))

    def test_invalid_policy_and_unknown_flags_fail_before_updates(self):
        self.all_managers()
        for data in ({"schema": 1, "vendor_casks": ["--force"]}, {"schema": 1, "vendor_casks": None}, []):
            self.policy(data)
            self.assertEqual(1, self.invoke().returncode)
            self.assertEqual([], self.calls())
        self.policy({"schema": 1})
        self.assertEqual(2, self.invoke("--only", "brwe").returncode)
        self.assertEqual([], self.calls())

    def test_malformed_inventory_is_not_success_or_broad_upgrade(self):
        self.manager("brew")
        self.manager("npm")
        self.manager("uv")
        self.response("brew list --cask -1", "--force")
        self.response("npm list --global --depth=0 --json", "[]")
        result = self.invoke("--only", "brew,npm,uv")
        self.assertEqual(1, result.returncode)
        self.assertNotIn("brew update", self.commands())
        self.assertFalse(any(command.startswith("npm update") for command in self.commands()))
        self.assertIn("uv tool upgrade --all", self.commands())

    def test_go_installs_only_versioned_commands_back_into_original_bin(self):
        self.manager("go")
        self.go_bin.mkdir(parents=True)
        for name, metadata in {
            "gopls": "\tpath\tgolang.org/x/tools/gopls\n\tmod\tgolang.org/x/tools/gopls\tv0.20.0\th1:test",
            "custom": "\tpath\texample.com/custom\n\tmod\texample.com/custom\t(devel)",
            "replaced": "\tpath\texample.com/tool\n\tmod\texample.com/tool\tv1.0.0\n\t=>\t../local\t(devel)",
            "flags": "\tpath\texample.com/tool\n\tmod\texample.com/tool\tv1.0.0\n\tbuild\t-tags=custom",
        }.items():
            binary = self.go_bin / name
            binary.write_text("fixture")
            binary.chmod(0o755)
            self.response(f"go version -m {binary}", metadata)
        result = self.invoke("--only", "go")
        self.assertEqual(0, result.returncode, result.stderr)
        installs = [call for call in self.calls() if call["args"][:2] == ["go", "install"]]
        self.assertEqual(1, len(installs))
        self.assertEqual(["go", "install", "golang.org/x/tools/gopls@latest"], installs[0]["args"])
        self.assertEqual(str(self.go_bin), installs[0]["GOBIN"])


if __name__ == "__main__":
    unittest.main()
