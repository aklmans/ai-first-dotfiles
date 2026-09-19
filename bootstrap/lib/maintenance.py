#!/usr/bin/env python3
"""Local, opt-in file maintenance. No packages, service ownership or cloud I/O.

The existing copy deployer remains authoritative for source/local conflicts.
Operation images add bounded, content-checked recovery around that deployer.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid

REPO = Path(__file__).resolve().parents[2]
SCHEMA = 1
PROFILE_RE = re.compile(r'^([A-Z0-9_]+)="([^"$`]*)"\s*$')
SAFE_NAME = re.compile(r"[A-Za-z0-9_-]+\Z")
ID_RE = re.compile(r"[0-9]{8}T[0-9]{6}Z-[a-f0-9]{12}\Z")


class Refused(Exception):
    pass


def read_profile(path):
    """Same literal grammar and last-assignment rule as Shell/Lua runtime."""
    values = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        match = PROFILE_RE.fullmatch(line)
        if match:
            values[match[1]] = match[2]
    return values


def checked_relative(value):
    path = Path(value)
    if not value or path.is_absolute() or any(p in ("", ".", "..") for p in value.split("/")):
        raise Refused("Unsafe relative path: " + value)
    return path


def guard(path, home=None):
    path = Path(path)
    home = home or Path(os.environ["HOME"])
    if not path.is_absolute() or ".." in path.parts:
        raise Refused("Write path must be absolute and normalized: " + str(path))
    for part in (path, *path.parents):
        if home is not None and part == home:
            break
        if part.is_symlink():
            if str(part) in ("/tmp", "/var") and os.readlink(part) == "private" + str(part):
                continue
            raise Refused("Refusing linked path: " + str(part))
        if part != path and part.exists() and not part.is_dir():
            raise Refused("Parent is not a directory: " + str(part))


def fingerprint(path):
    if path.is_symlink():
        raise Refused("Refusing linked file: " + str(path))
    if not path.exists():
        return {"kind": "absent"}
    info = path.stat()
    if stat.S_ISDIR(info.st_mode):
        return {"kind": "directory"}
    if not stat.S_ISREG(info.st_mode):
        raise Refused("Not a regular file: " + str(path))
    return {"kind": "file", "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "mode": stat.S_IMODE(info.st_mode)}


def atomic_bytes(path, data, mode=0o600):
    guard(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".ai-first-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        guard(path)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def save_json(path, value):
    atomic_bytes(path, (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def run_child(argv, env=None, capture=False):
    """Terminate only this command's group on interruption, before recovery."""
    child = subprocess.Popen(argv, env=env, start_new_session=True,
                             stdout=subprocess.PIPE if capture else None,
                             stderr=subprocess.PIPE if capture else None)
    try:
        out, err = child.communicate()
    except BaseException:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        raise
    if child.returncode:
        detail = (err or b"").decode(errors="replace")[-2000:]
        raise Refused("Command failed (%s): %s\n%s" % (child.returncode, argv[0], detail))
    return (out or b"").decode()


class Maintenance:
    def __init__(self, home=None, state=None, repo=REPO):
        self.repo = Path(repo)
        self.home = Path(home or os.environ["HOME"]).absolute()
        self.state = Path(state or os.environ.get("XDG_STATE_HOME", str(self.home / ".local/state"))) / "ai-first-dotfiles"
        self.config = self.home / ".config/ai-first"
        self.selection_path = self.config / "selection.json"
        self.operations = self.state / "operations"
        data = run_child(["/bin/bash", "-c", 'source "$1"; catalog_module_records; printf "\\n"; catalog_preset_records',
                          "_", str(self.repo / "bootstrap/catalog.sh")], capture=True)
        modules, presets = data.strip().split("\n\n", 1)
        self.modules = {row.split("\t")[0]: row.split("\t") for row in modules.splitlines()}
        self.presets = {row.split("\t")[0]: row.split("\t")[2].split(",") for row in presets.splitlines()}

    def scope(self):
        value = read_profile(self.config / "profile.conf").get("AI_FIRST_PRESET", "custom")
        return value if SAFE_NAME.fullmatch(value) else "custom"

    def expand(self, choices):
        found = []
        def add(name):
            if name in self.presets:
                for member in self.presets[name]:
                    add(member)
                return
            if name not in self.modules:
                raise Refused("Unknown module: " + name)
            if name in found:
                return
            deps = self.modules[name][5]
            for dep in ([] if deps == "-" else deps.split(",")):
                add(dep)
            found.append(name)
        for choice in choices:
            add(choice)
        return found

    def selection(self, required=True):
        if not self.selection_path.exists():
            if required:
                raise Refused("No confirmed module selection. Preview 'setup.sh select', then confirm explicit modules with --apply.")
            return None
        guard(self.selection_path, self.home)
        data = json.loads(self.selection_path.read_text())
        if data.get("schema") != SCHEMA or not isinstance(data.get("modules"), list):
            raise Refused("Unsupported selection schema; no automatic migration.")
        if data.get("scope") != self.scope():
            raise Refused("Profile scope changed. Reconfirm modules with 'setup.sh select MODULE... --apply'.")
        self.expand(data["modules"])
        return data

    def candidates(self):
        scope = self.scope()
        if scope in self.presets:
            choices = list(self.presets[scope])
            choices += [p.stem for p in sorted((self.config / "modules" / scope).glob("*.conf")) if p.stem in self.modules]
            return self.expand(choices)
        return []  # Asset presence is not proof of user selection.

    @contextlib.contextmanager
    def lock(self):
        lock = self.state / "write.lock"
        guard(lock, self.home)
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        token = os.environ.get("AI_FIRST_WRITE_LOCK_TOKEN")
        inherited = os.environ.get("AI_FIRST_WRITE_LOCK_DIR") == str(lock)
        if token and inherited and (lock / "owner").is_file() and (lock / "owner").read_text().strip() == token:
            try:
                os.kill(int(token.split(":")[0]), 0)
            except (ValueError, ProcessLookupError):
                raise Refused("Inherited write lock has no live owner.")
            yield
            return
        try:
            lock.mkdir(mode=0o700)
        except FileExistsError:
            raise Refused("Another/interrupted writer owns %s; inspect before retrying." % lock)
        token = "%s:%s" % (os.getpid(), uuid.uuid4().hex)
        (lock / "owner").write_text(token + "\n")
        previous = {k: os.environ.get(k) for k in ("AI_FIRST_WRITE_LOCK_DIR", "AI_FIRST_WRITE_LOCK_TOKEN")}
        os.environ.update(AI_FIRST_WRITE_LOCK_DIR=str(lock), AI_FIRST_WRITE_LOCK_TOKEN=token)
        try:
            yield
        finally:
            if (lock / "owner").read_text().strip() == token:
                (lock / "owner").unlink()
                lock.rmdir()
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value

    def revision(self):
        return run_child(["git", "-C", str(self.repo), "rev-parse", "HEAD"], capture=True).strip()

    def assets(self, modules):
        scripts = {s for module in modules for s in self.modules[module][4].split(",")}
        roots = [".config/ai-first"]
        for line in (self.repo / "bootstrap/assets.tsv").read_text().splitlines():
            if line and not line.startswith("#"):
                script, rel = line.split("|", 1)
                checked_relative(rel)
                if script in scripts and rel not in roots:
                    roots.append(rel)
        return roots

    def source_files(self, roots):
        paths = {}
        for rel in roots:
            source = self.repo / "home" / checked_relative(rel)
            if source.is_symlink():
                raise Refused("Linked source: " + str(source))
            if not source.exists():
                raise Refused("Missing declared asset: " + rel)
            files = sorted(source.rglob("*")) if source.is_dir() else [source]
            for path in files:
                if path.is_symlink():
                    raise Refused("Linked source: " + str(path))
                if path.is_file():
                    paths[str(path.relative_to(self.repo / "home"))] = path
        return paths

    def path(self, key):
        prefix, rel = key.split(":", 1)
        relative = checked_relative(rel)
        if prefix == "home":
            return self.home / relative
        if prefix == "state" and relative.parts[0] == "manifests":
            return self.state / relative
        raise Refused("Operation has an unsupported target: " + key)

    def observe(self, keys):
        result = {}
        for key in keys:
            path = self.path(key)
            guard(path, self.home)
            result[key] = fingerprint(path)
        return result

    def manifest_keys(self, roots):
        # Legacy deploy uses percent-encoded absolute targets as manifest names.
        keys = []
        for rel in roots:
            name = str(self.home / rel).replace("%", "%25").replace("\t", "%09").replace("\n", "%0A").replace("/", "%2F")
            keys.append("state:manifests/" + name)
        return keys

    def with_parents(self, keys):
        found = set(keys)
        for key in keys:
            prefix, rel = key.split(":", 1)
            if prefix != "home":
                continue
            for parent in checked_relative(rel).parents:
                if str(parent) != "." and not (self.home / parent).exists():
                    found.add("home:" + str(parent))
        return sorted(found)

    def operation(self, kind, keys, apply, action, modules=(), activate=False):
        keys = self.with_parents(keys)
        before = self.observe(keys)
        print("%s plan (%s targets; files only):" % (kind, len(keys)))
        for key in keys:
            print("  " + key)
        if not apply:
            print("Preview only; use --apply after review. No activation is implied.")
            return None
        with self.lock():
            if self.observe(keys) != before:
                raise Refused("Files changed after planning; review again.")
            op_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:12]
            directory = self.operations / op_id
            guard(directory, self.home)
            (directory / "before").mkdir(parents=True, mode=0o700)
            os.chmod(self.operations, 0o700)
            os.chmod(directory, 0o700)
            entries = []
            for i, key in enumerate(keys):
                entry = {"key": key, "before": before[key], "image": str(i)}
                if before[key]["kind"] == "file":
                    atomic_bytes(directory / "before" / str(i), self.path(key).read_bytes())
                    if fingerprint(self.path(key)) != before[key]:
                        raise Refused("File changed while saving recovery image: " + key)
                entries.append(entry)
            meta = {"schema": SCHEMA, "id": op_id, "kind": kind, "home": str(self.home),
                    "state": str(self.state), "revision": self.revision(), "modules": list(modules),
                    "started_ns": time.time_ns(), "status": "prepared", "activation": "not-requested", "files": entries}
            save_json(directory / "operation.json", meta)
            print("Operation: " + op_id, flush=True)
            failure = None
            try:
                action()
                meta["status"] = "files-applied"
            except BaseException as error:
                failure = error
                meta["status"] = "interrupted" if isinstance(error, KeyboardInterrupt) else "deploy-failed"
                meta["error"] = str(error)
            finally:
                for entry in entries:
                    try:
                        guard(self.path(entry["key"]), self.home)
                        entry["after"] = fingerprint(self.path(entry["key"]))
                    except (OSError, Refused):
                        entry["after"] = {"kind": "unknown"}
                    entry["outcome"] = "unknown" if entry["after"]["kind"] == "unknown" else (
                        "unchanged" if entry["after"] == entry["before"] else "changed")
                save_json(directory / "operation.json", meta)
            if failure:
                print("Incomplete; inspect operation %s before retrying or rolling back." % op_id, file=sys.stderr)
                raise failure
            if activate:
                meta["activation"] = "pending"
                save_json(directory / "operation.json", meta)
                try:
                    run_child(["/bin/bash", str(self.repo / "home/.config/aerospace/activate.sh"), "--apply"])
                    meta["activation"] = "success"
                except BaseException as error:
                    meta["status"], meta["activation"], meta["error"] = "activation-failed", "failed", str(error)
                    save_json(directory / "operation.json", meta)
                    raise
            meta["status"] = "complete"
            save_json(directory / "operation.json", meta)
            print("Completed: " + op_id + (" (files only; desktop runtime unverified)" if not activate else ""))
            return op_id

    def select(self, choices, apply=False, merge=False):
        current = None
        if self.selection_path.exists():
            guard(self.selection_path, self.home)
            saved = json.loads(self.selection_path.read_text())
            if saved.get("scope") == self.scope():
                current = self.selection()
        if not choices:
            if current:
                print("Selected: " + " ".join(current["modules"]))
            else:
                candidates = self.candidates()
                print("Candidate only: " + (" ".join(candidates) if candidates else "unknown/private profile; choose modules explicitly"))
                print("Confirm with setup.sh select MODULE... --apply; existing assets do not prove selection.")
            return
        modules = self.expand(choices)
        if merge and current:
            modules = self.expand(current["modules"] + modules)
        data = {"schema": SCHEMA, "scope": self.scope(), "modules": modules}
        print("Selected modules: " + " ".join(modules))
        self.operation("select", ["home:.config/ai-first/selection.json"], apply,
                       lambda: save_json(self.selection_path, data), modules)

    def record_selection(self, choices, replace=False):
        # Called only after setup succeeded. Scope switches require a new list.
        old = None
        if self.selection_path.exists():
            guard(self.selection_path, self.home)
            old = json.loads(self.selection_path.read_text())
        modules = self.expand(choices)
        if old and old.get("scope") == self.scope() and not replace:
            modules = self.expand(old.get("modules", []) + modules)
        data = {"schema": SCHEMA, "scope": self.scope(), "modules": modules}
        self.operation("select", ["home:.config/ai-first/selection.json"], True,
                       lambda: save_json(self.selection_path, data), modules)

    def render_env(self):
        # A maintenance run reproduces disk intent, not inherited one-off flags.
        env = {k: v for k, v in os.environ.items() if not k.startswith(("AI_FIRST_", "AEROSPACE_"))}
        env.update(HOME=str(self.home), AEROSPACE_CONFIG_DIR=str(self.home / ".config/aerospace"),
                   AI_FIRST_PROFILE_LIB=str(self.repo / "home/.config/ai-first/lib/profile.sh"),
                   AI_FIRST_CONFIG_DIR=str(self.config), AI_FIRST_PROFILE_PATH=str(self.config / "profile.conf"))
        return env

    def render_candidate(self):
        template = self.home / ".aerospace.toml"
        if not template.exists():
            template = self.repo / "home/.aerospace.toml"
        return run_child(["/bin/bash", str(self.repo / "home/.config/aerospace/render-layout.sh"),
                          "--stdout", str(template)], env=self.render_env(), capture=True).encode()

    def update(self, apply=False, activate=False):
        selection = self.selection()
        modules = self.expand(selection["modules"])
        if "shell" in modules and not (self.home / ".zshenv").exists() and (self.home / ".zshrc").exists():
            raise Refused("Existing .zshrc needs explicit ZDOTDIR takeover via setup.sh shell before update.")
        roots = self.assets(modules)
        files = self.source_files(roots)
        for rel in files:
            target = self.home / rel
            guard(target, self.home)
            if target.exists() and not target.is_file():
                raise Refused("Expected a regular configuration file; unchanged: " + str(target))
        keys = ["home:" + rel for rel in files] + self.manifest_keys(roots)
        if "workspace" in modules:
            keys += ["home:.aerospace.toml"]
        keys = sorted(set(keys))
        print("Update selected only: " + " ".join(modules))
        print("Existing preference files are preserved; no presets/overlays are reapplied.")
        env = dict(self.render_env(), DOTFILES_KEEP_INTENT="1", DOTFILES_FORCE="0")
        candidate = self.render_candidate() if "workspace" in modules else None
        if activate and candidate is None:
            raise Refused("Desktop activation requires the workspace module.")
        def deploy():
            # Validate again under the shared lock BEFORE the first copy.
            if candidate is not None and self.render_candidate() != candidate:
                raise Refused("Configuration changed after preview; review again.")
            env.update({key: os.environ[key] for key in ("AI_FIRST_WRITE_LOCK_DIR", "AI_FIRST_WRITE_LOCK_TOKEN")})
            program = 'source "$1"; shift; repo="$1"; shift; for rel in "$@"; do deploy_repo_path "$repo" "home/$rel" "$HOME/$rel" update; done'
            run_child(["/bin/bash", "-c", program, "_", str(self.repo / "bootstrap/lib/common.sh"), str(self.repo), *roots], env=env)
            if "workspace" in modules:
                run_child(["/bin/bash", str(self.repo / "home/.config/aerospace/render-layout.sh"), str(self.home / ".aerospace.toml")], env=env)
        return self.operation("update", keys, apply, deploy, modules, activate)

    def load_operation(self, op_id):
        if not ID_RE.fullmatch(op_id):
            raise Refused("Invalid operation ID.")
        directory = self.operations / op_id
        guard(directory / "operation.json", self.home)
        meta = json.loads((directory / "operation.json").read_text())
        if meta.get("schema") != SCHEMA or meta.get("home") != str(self.home) or meta.get("state") != str(self.state):
            raise Refused("Operation belongs to another HOME/state or unknown schema.")
        return directory, meta

    def history(self):
        entries = [self.load_operation(p.parent.name) for p in self.operations.glob("*/operation.json")]
        return sorted(entries, key=lambda entry: (entry[1].get("started_ns", 0), entry[0].name))

    def list_operations(self):
        for directory, meta in self.history():
            print("%s  %-12s %-18s activation=%s" % (directory.name, meta["kind"], meta["status"], meta["activation"]))

    def rollback(self, op_id, apply=False):
        directory, meta = self.load_operation(op_id)
        if meta["status"] == "rolled-back":
            print("Already rolled back: " + op_id)
            return
        changes = [entry for entry in meta["files"] if entry.get("after") != entry["before"]]
        changed_keys = {entry["key"] for entry in changes}
        seen = False
        for later_dir, later in self.history():
            if later_dir == directory:
                seen = True
            elif seen and later["status"] != "rolled-back":
                overlap = changed_keys & {e["key"] for e in later["files"] if e.get("after") != e["before"]}
                if overlap:
                    raise Refused("Rollback newer overlapping operation first: " + later_dir.name)
        # Refuse the entire plan on any conflict before changing a single file.
        def validate():
            for entry in changes:
                path = self.path(entry["key"])
                guard(path, self.home)
                current = fingerprint(path)
                if entry.get("restored") and current == entry["before"]:
                    continue
                if entry.get("after", {}).get("kind") == "unknown" or current != entry.get("after"):
                    raise Refused("Rollback conflict; unchanged: " + entry["key"])
                if entry["before"]["kind"] == "file":
                    image = directory / "before" / str(entry["image"])
                    if not str(entry["image"]).isdigit():
                        raise Refused("Invalid recovery image.")
                    guard(image, self.home)
                    if fingerprint(image).get("sha256") != entry["before"]["sha256"]:
                        raise Refused("Recovery image is missing or corrupt: " + entry["key"])
        validate()
        print("Rollback %s (files only, no service/system reversal):" % op_id)
        for entry in changes:
            print("  " + entry["key"])
        if not apply:
            print("Preview only; use --apply.")
            return
        with self.lock():
            validate()
            meta["status"] = "rollback-in-progress"
            save_json(directory / "operation.json", meta)
            for entry in sorted(changes, key=lambda e: (e["key"].count("/"), e["key"]), reverse=True):
                path, before = self.path(entry["key"]), entry["before"]
                if entry.get("restored") and fingerprint(path) == before:
                    continue
                guard(path, self.home)
                if fingerprint(path) != entry["after"]:
                    raise Refused("Target changed during rollback: " + entry["key"])
                if before["kind"] == "file":
                    atomic_bytes(path, (directory / "before" / entry["image"]).read_bytes(), before["mode"])
                elif before["kind"] == "absent":
                    if path.is_dir():
                        try:
                            path.rmdir()
                        except OSError:
                            print("Kept nonempty directory: " + str(path))
                    elif path.exists():
                        path.unlink()
                elif before["kind"] == "directory":
                    raise Refused("Cannot automatically restore a replaced directory: " + entry["key"])
                entry["restored"] = True
                save_json(directory / "operation.json", meta)
            meta["status"] = "rolled-back"
            save_json(directory / "operation.json", meta)
            print("Rolled back: " + op_id + "; running services were not reloaded.")

    def uninstall(self, apply=False, system_only=False, ledger=None):
        print("System ownership/original values are not recorded: no service, package, defaults or GUI PATH reversal.")
        legacy = Path(ledger) if ledger else self.state / "backups.tsv"
        if legacy.exists():
            print("Legacy ledger (read-only recovery reference): " + str(legacy))
            print("Inspect adjacent backups manually; entries alone cannot prove original ownership.")
        if system_only:
            if apply:
                raise Refused("No owned system changes can be safely reversed.")
            return
        history = [(d, m) for d, m in reversed(self.history()) if m["status"] != "rolled-back"]
        if not history:
            print("No recorded file operations; nothing is eligible for automatic uninstall.")
            if apply and legacy.exists():
                raise Refused("Legacy-only install: automatic recovery is deliberately disabled.")
            return
        def validate_all():
            virtual = {}
            for directory, meta in history:
                for entry in meta["files"]:
                    if entry.get("after") == entry["before"]:
                        continue
                    key = entry["key"]
                    if key not in virtual:
                        virtual[key] = self.observe([key])[key]
                    expected = entry["before"] if entry.get("restored") else entry.get("after")
                    if virtual[key] != expected or not expected or expected.get("kind") == "unknown":
                        raise Refused("Uninstall conflict; no files changed: " + key)
                    if entry["before"]["kind"] == "file":
                        if not str(entry["image"]).isdigit():
                            raise Refused("Invalid recovery image.")
                        image = directory / "before" / entry["image"]
                        guard(image, self.home)
                        if fingerprint(image).get("sha256") != entry["before"]["sha256"]:
                            raise Refused("Corrupt recovery image: " + key)
                    virtual[key] = entry["before"]
        validate_all()
        print("Uninstall recorded changes only, newest first: " + " ".join(d.name for d, _ in history))
        if not apply:
            print("Preview only; use --apply. Legacy installation files remain.")
            return
        with self.lock():
            validate_all()
            for directory, _ in history:
                self.rollback(directory.name, True)
        print("Recorded changes removed/restored; recovery images retained. No desktop reload performed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["select", "update", "operations", "rollback", "record-selection", "export", "import", "uninstall", "doctor"])
    parser.add_argument("choices", nargs="*")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--activate", action="store_true")
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--files-only", action="store_true")
    parser.add_argument("--system-only", action="store_true")
    parser.add_argument("--ledger")
    args = parser.parse_args()
    if args.apply and args.dry_run:
        parser.error("choose --apply or --dry-run")
    if (args.files_only or args.system_only or args.ledger) and args.command != "uninstall":
        parser.error("--files-only, --system-only and --ledger are uninstall options")
    if args.replace and args.command != "record-selection":
        parser.error("--replace is reserved for recording a successful preset choice")
    if args.command == "record-selection" and (args.apply or args.dry_run):
        parser.error("record-selection is an internal setup completion step, not a preview command")
    if args.command in ("operations", "doctor") and (args.apply or args.dry_run):
        parser.error(args.command + " is read-only and accepts no apply/dry-run flags")
    if args.activate and (args.command != "update" or not args.apply):
        parser.error("--activate requires update --apply; it addresses your real desktop")
    service = Maintenance()
    if args.command == "select":
        service.select(args.choices, args.apply)
    elif args.command == "record-selection":
        service.record_selection(args.choices, args.replace)
    elif args.command == "update":
        if args.choices:
            parser.error("update uses saved selection; use select to change it")
        service.update(args.apply, args.activate)
    elif args.command == "operations":
        if args.choices:
            parser.error("operations takes no arguments")
        service.list_operations()
    elif args.command == "rollback":
        if len(args.choices) != 1:
            parser.error("rollback requires one operation ID")
        service.rollback(args.choices[0], args.apply)
    elif args.command == "uninstall":
        if args.choices or (args.files_only and args.system_only):
            parser.error("uninstall accepts no target; choose files-only OR system-only")
        service.uninstall(args.apply, args.system_only, args.ledger)
    elif args.command in ("export", "import"):
        if len(args.choices) != 1:
            parser.error(args.command + " requires a directory")
        from intent import export_intent, import_intent
        (export_intent if args.command == "export" else import_intent)(service, Path(args.choices[0]).absolute(), args.apply)
    elif args.command == "doctor":
        from health import doctor
        if not doctor(service, args.choices):
            sys.exit(1)


if __name__ == "__main__":
    # intent/health import this module's exception and helpers. When launched
    # as a file, reuse __main__ rather than loading a second Refused class that
    # the CLI's handler cannot catch.
    sys.modules["maintenance"] = sys.modules[__name__]
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    try:
        main()
    except (Refused, OSError, ValueError, TypeError, KeyError) as error:
        print("Refused: " + str(error), file=sys.stderr)
        sys.exit(3)
    except KeyboardInterrupt:
        sys.exit(130)
