#!/usr/bin/env python3
"""Explicit, source-aware updates for installed tools; no project updates."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


GROUPS = ("brew", "mise", "npm", "pnpm", "bun", "rust", "uv", "go", "mas")
TOKEN = r"[a-z0-9][a-z0-9@+._-]*"
PACKAGE = r"(?:@[a-z0-9._-]+/)?[a-z0-9][a-z0-9._-]*"


def vendor_casks():
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    path = config / "ai-first/software/ownership.json"
    if not path.exists():
        return set()
    if path.stat().st_size > 65536:
        raise ValueError("Software ownership policy is too large")
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or type(data.get("schema")) is not int or data["schema"] != 1:
        raise ValueError("Invalid software ownership policy schema")
    casks = data.get("vendor_casks", [])
    if not isinstance(casks, list) or any(not isinstance(c, str) or not re.fullmatch(TOKEN, c) for c in casks):
        raise ValueError("vendor_casks must be a list of literal cask tokens")
    return set(casks)


def owner(path):
    """Inspect links/layouts, never execute a self-updater to identify its owner."""
    candidates = (Path(path), Path(path).resolve())
    if any({"Cellar", "Caskroom"} & set(candidate.parts) for candidate in candidates):
        return "Homebrew"
    mise = Path(os.environ.get("MISE_DATA_DIR", str(Path.home() / ".local/share/mise")))
    if any(root == candidate or root in candidate.parents for candidate in candidates
           for root in (mise / "installs", mise / "shims")):
        return "mise"
    if any("node_modules" in candidate.parts for candidate in candidates):
        return "npm/pnpm/Bun"
    if any("pipx" in candidate.parts or "uv/tools" in candidate.as_posix() for candidate in candidates):
        return "Python tool manager"
    return None


class Updater:
    def __init__(self, dry_run, excluded):
        self.dry_run = dry_run
        self.excluded = excluded
        self.failures = []
        self.completed = 0
        self.env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_ANALYTICS="1",
                        HOMEBREW_NO_INSTALL_CLEANUP="1", npm_config_update_notifier="false",
                        MAS_NO_AUTO_INDEX="1")
        # Never inherit an activated project's working directory override.
        for key in ("MISE_CWD", "UV_WORKING_DIR", "UV_PROJECT"):
            self.env.pop(key, None)

    def note(self, message):
        print("  " + message, flush=True)

    def fail(self, message):
        self.failures.append(message)
        self.note("FAILED: " + message)

    def probe(self, *args):
        try:
            result = subprocess.run(args, cwd="/", env=self.env, stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ValueError(f"Cannot inspect {shlex.join(args)}: {error}") from error
        if result.returncode != 0:
            raise ValueError(f"Cannot inspect {shlex.join(args)} (exit {result.returncode}): {result.stderr.strip()}")
        return result.stdout.strip()

    def run(self, *args, extra_env=None):
        self.note(("PLAN: " if self.dry_run else "$ ") + shlex.join(args))
        if self.dry_run:
            return True
        try:
            result = subprocess.run(args, cwd="/", env=dict(self.env, **(extra_env or {})))
        except OSError as error:
            self.fail(f"{shlex.join(args)}: {error}")
            return False
        if result.returncode in (-2, 130):
            raise KeyboardInterrupt
        if result.returncode != 0:
            self.fail(f"{shlex.join(args)} (exit {result.returncode})")
            return False
        self.completed += 1
        return True

    def self_update(self, name, *args):
        managed = owner(shutil.which(name))
        if managed:
            self.note(f"{name} is managed by {managed}; update it through that owner.")
        else:
            self.run(name, *args)

    def brew(self):
        # Enumerate explicitly: an empty filtered list must NEVER become an
        # unqualified `brew upgrade --cask` (which upgrades all casks).
        casks = self.probe("brew", "list", "--cask", "-1").splitlines()
        if any(not re.fullmatch(TOKEN, c) for c in casks):
            raise ValueError("Invalid Homebrew cask inventory")
        selected = sorted(set(casks) - self.excluded)
        if self.excluded:
            self.note("Vendor-managed casks excluded: " + ", ".join(sorted(self.excluded)))
        if not self.run("brew", "update"):
            self.note("Skipping Homebrew upgrades because its metadata refresh failed.")
            return
        self.run("brew", "upgrade", "--formula")
        if selected:
            self.run("brew", "upgrade", "--cask", *selected)
        else:
            self.note("No Homebrew-owned casks to upgrade.")

    def mise(self):
        self.self_update("mise", "self-update", "--yes")
        # cwd=/ prevents discovery of the caller's project config. Keep the
        # user's global version constraints; do not use --bump.
        self.run("mise", "upgrade")

    def npm(self):
        data = json.loads(self.probe("npm", "list", "--global", "--depth=0", "--json"))
        root = Path(self.probe("npm", "root", "--global"))
        if not isinstance(data, dict) or not isinstance(data.get("dependencies", {}), dict) or not root.is_absolute():
            raise ValueError("Invalid npm global inventory")
        packages = []
        for name, record in data.get("dependencies", {}).items():
            if (not re.fullmatch(PACKAGE, name) or not isinstance(record, dict) or
                    not isinstance(record.get("resolved", ""), str)):
                raise ValueError("Invalid npm package record")
            # Homebrew links npm/corepack/etc. into the global root. Do not
            # overwrite these with a registry install, or update local links.
            managed = owner(root / name)
            node = shutil.which("node")
            bundled_npm = name == "npm" and node and owner(node) in ("Homebrew", "mise")
            if managed in ("Homebrew", "mise") or bundled_npm or record.get("resolved", "").startswith(("file:", "link:")):
                self.note(f"{name}: skipping package managed outside npm.")
            else:
                packages.append(name)
        if packages:
            self.run("npm", "update", "--global", *sorted(packages))
        else:
            self.note("No npm-owned global packages to upgrade.")

    def pnpm(self):
        self.run("pnpm", "update", "--global")

    def bun(self):
        self.self_update("bun", "upgrade")
        self.run("bun", "update", "--global")

    def rust(self):
        if shutil.which("rustup"):
            args = ("--no-self-update",) if owner(shutil.which("rustup")) else ()
            self.run("rustup", "update", *args)
        else:
            self.note("rustup is not installed; packaged Rust is updated by Homebrew/mise.")
        if shutil.which("cargo-install-update"):
            self.run("cargo-install-update", "--all")
        else:
            self.note("Cargo-installed apps: cargo-update is not installed; skipping (no helper installed automatically).")

    def uv(self):
        self.self_update("uv", "self", "update")
        self.run("uv", "tool", "upgrade", "--all")

    def go(self):
        self.note("Go toolchain: updated by its owner (Homebrew/mise); checking installed Go commands.")
        data = json.loads(self.probe("go", "env", "-json", "GOBIN", "GOPATH"))
        if not isinstance(data, dict) or any(not isinstance(data.get(key), str) for key in ("GOBIN", "GOPATH")):
            raise ValueError("Invalid Go environment")
        directory = Path(data["GOBIN"] or str(Path(data["GOPATH"].split(os.pathsep)[0]) / "bin"))
        if not directory.is_absolute():
            raise ValueError("Go binary directory must be absolute")
        if not directory.exists():
            self.note("No Go-installed commands.")
            return
        for binary in sorted(directory.iterdir()):
            if binary.is_symlink() or not binary.is_file() or not os.access(binary, os.X_OK):
                continue
            try:
                fields = [line.split() for line in self.probe("go", "version", "-m", str(binary)).splitlines()]
                paths = [line[1] for line in fields if len(line) == 2 and line[0] == "path"]
                modules = [line for line in fields if len(line) >= 3 and line[0] == "mod"]
                # Local builds/replacements/custom flags cannot be faithfully
                # recreated by `go install path@latest`; leave them alone.
                custom = any(line and (line[0] == "=>" or
                             (line[0] == "build" and any(flag in " ".join(line[1:]) for flag in ("-tags=", "-ldflags=", "-gcflags=", "-asmflags=")))) for line in fields)
                if (len(paths) != 1 or len(modules) != 1 or custom or
                        not re.fullmatch(r"v\d+\.[^\s]+", modules[0][2]) or
                        not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._~+/-]*", paths[0]) or
                        "." not in paths[0].split("/")[0] or ".." in paths[0].split("/")):
                    self.note(f"Skipping {binary.name}: not a standard versioned Go install.")
                    continue
                self.run("go", "install", paths[0] + "@latest", extra_env={"GOBIN": str(directory)})
            except ValueError as error:
                self.fail(str(error))

    def mas(self):
        self.run("mas", "upgrade")

    def execute(self, groups):
        for group in groups:
            print(f"\n[{group}]", flush=True)
            binary = "rustup" if group == "rust" else group
            if not shutil.which(binary) and not (group == "rust" and shutil.which("cargo-install-update")):
                self.note(f"{binary} is not installed; skipping.")
                continue
            try:
                getattr(self, group)()
            except (ValueError, OSError) as error:
                self.fail(f"{group}: {error}")
        print(f"\n{'Preview' if self.dry_run else 'Update'} finished: "
              f"{self.completed} commands completed, {len(self.failures)} failure(s).", flush=True)
        if self.failures:
            print("Failed steps:\n" + "\n".join("  " + item for item in self.failures), file=sys.stderr)
        return int(bool(self.failures))


def main():
    parser = argparse.ArgumentParser(description="Update installed software across package managers. No dotfile or project updates.")
    parser.add_argument("--dry-run", action="store_true", help="print commands; only local inventory probes run")
    parser.add_argument("--only", help="comma-separated managers: " + ",".join(GROUPS))
    args = parser.parse_args()
    selected = set(args.only.split(",")) if args.only is not None else set(GROUPS)
    if selected - set(GROUPS):
        parser.error("unknown manager(s): " + ", ".join(sorted(selected - set(GROUPS))))
    try:
        excluded = vendor_casks()  # Preflight BEFORE any updates.
        print("Preview only; no upgrade commands will run." if args.dry_run else "Updating installed software. Ctrl-C stops the run.", flush=True)
        return Updater(args.dry_run, excluded).execute([g for g in GROUPS if g in selected])
    except (ValueError, OSError) as error:
        print(f"Cannot start updates: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nUpdates interrupted; remaining steps were not run.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
