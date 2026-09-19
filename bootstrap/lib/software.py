#!/usr/bin/env python3
"""Read-only software inventory and update guidance, not a package installer.

No agent CLI is started, no credentials/chats/agent settings are read, and no
printed command is executed. Only its own ownership policy and explicitly
approved wrappers are read. Discovery is evidence, never install intent.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
MAS_FIELDS = ("adamID", "bundleID", "displayName", "name", "path", "version")
TOOLS = {
    "codex": ["@openai/codex"],
    "claude": ["@anthropic-ai/claude-code"],
    "kimi": ["@moonshot-ai/kimi-code"],
    "opencode": ["opencode-ai", "@opencode-ai/cli"],
    "pi": ["@earendil-works/pi-coding-agent", "@mariozechner/pi-coding-agent"],
    "openclaw": ["openclaw"],
    "hermes": [],
}


def load_policy(path):
    policy = {"schema": 1, "vendor_casks": [], "cli_wrappers": {}}
    if not path.exists():
        return policy
    if path.stat().st_size > 65536:
        raise ValueError("Software policy is too large")
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or type(value.get("schema")) is not int or value.get("schema") != 1 or set(value) - set(policy):
        raise ValueError("Invalid software policy schema")
    policy.update(value)
    casks = policy["vendor_casks"]
    if not isinstance(casks, list) or any(not isinstance(c, str) or
            not re.fullmatch(r"[a-z0-9][a-z0-9@+._-]*", c) for c in casks) or len(casks) != len(set(casks)):
        raise ValueError("vendor_casks must contain unique literal cask tokens")
    wrappers = policy["cli_wrappers"]
    if not isinstance(wrappers, dict) or set(wrappers) - set(TOOLS):
        raise ValueError("Unknown CLI wrapper")
    for rule in wrappers.values():
        if not isinstance(rule, dict) or set(rule) != {"path", "target", "sha256"} or not all(
                isinstance(v, str) for v in rule.values()):
            raise ValueError("Invalid CLI wrapper record")
        if not all(Path(rule[k]).is_absolute() for k in ("path", "target")) or not re.fullmatch(r"[0-9a-f]{64}", rule["sha256"]):
            raise ValueError("Wrapper paths must be absolute and hash must be SHA-256")
    return policy


def probe(argv, runner=subprocess.run):
    """Only callers' fixed list commands reach this function; no shell/eval."""
    binary = shutil.which(argv[0])
    if not binary:
        return {"status": "unavailable", "text": ""}
    env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_ANALYTICS="1",
               HOMEBREW_NO_INSTALL_CLEANUP="1", MAS_NO_AUTO_INDEX="1",
               npm_config_update_notifier="false", NO_COLOR="1")
    try:
        result = runner([binary, *argv[1:]], env=env, cwd="/", stdin=subprocess.DEVNULL,
                        capture_output=True, text=True, timeout=30)
        return {"status": "ok" if result.returncode == 0 else "failed",
                "text": result.stdout, "warning": bool(result.stderr.strip()), "returncode": result.returncode}
    except (OSError, subprocess.TimeoutExpired):
        return {"status": "failed", "text": "", "warning": True}


def package_lines(text):
    result = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            result[fields[0]] = " ".join(fields[1:])
    return result


def probe_json(argv):
    result = probe(argv)
    try:
        result["data"] = json.loads(result.pop("text"))
    except (ValueError, TypeError):
        result["data"] = None
        if result["status"] == "ok":
            result["status"] = "malformed"
    return result


def probe_mas(argv):
    # mas 7 emits a stream of JSON objects, NOT a JSON array/document. An empty
    # successful stream is allowed, but inventory cross-checks receipt evidence.
    result = probe(argv)
    raw = result.pop("text")
    decoder, records = json.JSONDecoder(), []
    try:
        while raw.strip():
            value, end = decoder.raw_decode(raw.lstrip())
            if not isinstance(value, dict):
                raise ValueError("expected mas object stream")
            # Spotlight output also contains purchase/usage history and owner
            # IDs. Only identity/version fields belong in this inventory.
            records.append({key: value[key] for key in MAS_FIELDS
                            if key in value and isinstance(value[key], (str, int, float))
                            and not isinstance(value[key], bool)})
            raw = raw.lstrip()[end:]
        result["data"] = records
    except (ValueError, TypeError):
        result["data"] = None
        if result["status"] == "ok":
            result["status"] = "malformed"
    return result


def check_mas_coverage(result, apps):
    if result["status"] != "ok":
        return
    indexed = {app.get("bundleID") for app in result["data"] if app.get("bundleID")}
    missing = [{"bundle_id": app["bundle_id"], "path": app["path"]} for app in apps
               if app["app_store_receipt"] and app["bundle_id"] not in indexed]
    if missing:
        result.update(status="incomplete", warning=True, receipt_apps_not_listed=missing)


def cli_candidates(name, home, search_path):
    # Include broken and non-PATH links without executing them. This is not a
    # recursive search of the home directory or a scan of login shell scripts.
    roots = [Path(p) for p in search_path.split(os.pathsep) if p and Path(p).is_absolute()]
    roots += [home / ".local/bin", home / ".kimi-code/bin", home / ".opencode/bin",
              home / ".bun/bin"]
    found, seen = [], set()
    for root in roots:
        path = root / name
        if str(path) in seen or not os.path.lexists(path):
            continue
        seen.add(str(path))
        try:
            target = path.resolve()
            usable = path.is_file() and os.access(path, os.X_OK)
        except (OSError, RuntimeError):
            target, usable = path, False
        found.append({"path": str(path), "target": str(target), "usable": usable})
    return found


def within(path, root):
    try:
        Path(path).relative_to(root)
        return True
    except ValueError:
        return False


def tool_record(name, home, packages, npm_root, formulae, casks, search_path, wrappers=None):
    candidates = cli_candidates(name, home, search_path)
    # Explicit private, hash-bound approval only. Do not parse/evaluate a shell
    # wrapper or assume every second executable is a duplicate installation.
    rule = (wrappers or {}).get(name)
    if rule:
        source, target = Path(rule["path"]), Path(rule["target"])
        try:
            verified = (source.is_file() and source.stat().st_size <= 65536 and
                        hashlib.sha256(source.read_bytes()).hexdigest() == rule["sha256"] and
                        target.is_file() and os.access(target, os.X_OK))
        except OSError:
            verified = False
        if verified:
            for candidate in candidates:
                if candidate["path"] == str(source):
                    candidate.update(target=str(target.resolve()), wrapper_verified=True)
    active = shutil.which(name, path=search_path)
    chosen = next((c for c in candidates if c["path"] == active), None)
    record = {"name": name, "active": active, "candidates": candidates,
              "owner": "unknown", "version": None, "advice": [], "command": None}
    if not chosen:
        record["owner"] = "broken" if candidates else "not-detected"
        record["advice"].append("Repair/retention decision required; do not auto-install or delete.")
        return record
    target = chosen["target"]
    parts = Path(target).parts
    token = {"claude": "claude-code", "openclaw": "openclaw-cli"}.get(name, name)
    # A similarly named installed package is not ownership evidence by itself.
    for kind, marker, installed in (("brew-cask", "Caskroom", casks), ("brew-formula", "Cellar", formulae)):
        if marker in parts and parts.index(marker) + 1 < len(parts):
            actual_token = parts[parts.index(marker) + 1]
            if actual_token in (token, token + "@latest") and actual_token in installed:
                record.update(owner=kind, version=installed[actual_token],
                              command=["brew", "upgrade", "--cask" if kind == "brew-cask" else "--formula", actual_token])
    for package in TOOLS[name]:
        if npm_root and package in packages and within(target, Path(npm_root) / package):
            record.update(owner="npm", version=packages[package].get("version"),
                          command=["npm", "install", "--global", package + "@latest"])
    native = {"claude": (home / ".local/share/claude/versions", "update"),
              "kimi": (home / ".kimi-code/bin", "upgrade"),
              "opencode": (home / ".opencode/bin", "upgrade")}
    if name in native and within(target, native[name][0]):
        record.update(owner="native-layout", command=[active, native[name][1]])
        record["advice"].append("Known vendor layout; version and updater settings not read.")
    hermes_root = home / ".hermes/hermes-agent"
    if name == "hermes" and within(target, hermes_root) and (hermes_root / ".git").is_dir():
        record.update(owner="vendor-git-layout", command=[active, "update"])
    if name == "openclaw" and record["owner"] == "npm":
        record["command"] = [active, "update"]
        record["advice"].append("Service window required: updater may migrate config/plugins and restart Gateway. Back up first.")
    if name == "pi" and "@mariozechner/pi-coding-agent" in target:
        record["command"] = None
        record["advice"].append("Legacy npm namespace: review official namespace migration; do not silently replace it.")
    if name == "hermes":
        if record["owner"] != "vendor-git-layout":
            record["command"] = None
        record["advice"].append("Confirm the actual install root and local source changes before vendor update; may restart gateways.")
    distinct = {c["target"] for c in candidates if c["usable"]}
    if len(distinct) > 1:
        record["advice"].append("Multiple executables: review PATH/ownership before updating.")
        record["command"] = None
    if record["owner"] == "unknown":
        record["advice"].append("Unverified installation source; no guessed update command.")
    return record


def app_inventory(roots):
    apps, errors = [], []
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.app")):
            try:
                info = path / "Contents/Info.plist"
                if info.stat().st_size > 2 * 1024 * 1024:
                    raise ValueError("oversize plist")
                with info.open("rb") as stream:
                    data = plistlib.load(stream)
                apps.append({"path": str(path), "name": data.get("CFBundleDisplayName", data.get("CFBundleName", path.stem)),
                             "bundle_id": data.get("CFBundleIdentifier"), "version": data.get("CFBundleShortVersionString"),
                             "app_store_receipt": (path / "Contents/_MASReceipt/receipt").is_file(),
                             "sparkle_feed_declared": bool(data.get("SUFeedURL"))})
            except (OSError, ValueError, plistlib.InvalidFileException, AttributeError):
                errors.append(str(path))
    return apps, errors


def collect(home=None, policy=None):
    home = home or Path.home()
    policy = policy or {"schema": 1, "vendor_casks": [], "cli_wrappers": {}}
    results = {}
    for key, argv in {
        "formulae": ["brew", "list", "--formula", "--versions"],
        "casks": ["brew", "list", "--cask", "--versions"],
        "leaves": ["brew", "leaves"],
        "cask_pins": ["brew", "list", "--cask", "--pinned"],
        "npm_root": ["npm", "root", "--global"],
        "uv": ["uv", "tool", "list"],
        "bun": ["bun", "pm", "ls", "--global"],
    }.items():
        results[key] = probe(argv)
    for key, argv in {
        "npm": ["npm", "ls", "--global", "--depth=0", "--json"],
        "pnpm": ["pnpm", "list", "--global", "--depth=0", "--json"],
    }.items():
        results[key] = probe_json(argv)
    results["mas"] = probe_mas(["mas", "list", "--json"])
    formulae = package_lines(results["formulae"]["text"]) if results["formulae"]["status"] == "ok" else {}
    casks = package_lines(results["casks"]["text"]) if results["casks"]["status"] == "ok" else {}
    npm = results["npm"].get("data")
    packages = npm.get("dependencies", {}) if isinstance(npm, dict) else {}
    if results["npm"]["status"] != "ok" or not isinstance(packages, dict):
        packages = {}
    packages = {k:v for k,v in packages.items() if isinstance(v, dict)}
    npm_root = results["npm_root"]["text"].strip() if results["npm_root"]["status"] == "ok" else ""
    tools = [tool_record(name, home, packages, npm_root, formulae, casks, os.environ.get("PATH", ""),
                         policy["cli_wrappers"]) for name in TOOLS]
    uv_text = results["uv"]["text"]
    if re.search(r"^kimi-cli\s+", uv_text, re.M):
        next(t for t in tools if t["name"] == "kimi")["advice"].append(
            "Legacy uv kimi-cli also registered. Review history/config migration before removing it; native update does not update legacy uv.")
    apps, app_errors = app_inventory([Path("/Applications"), home / "Applications"])
    check_mas_coverage(results["mas"], apps)
    config = home / ".config"
    names = sorted(p.name for p in config.iterdir() if not p.name.startswith(".")) if config.is_dir() else []
    pins = set(results["cask_pins"]["text"].splitlines()) if results["cask_pins"]["status"] == "ok" else set()
    ownership = {"vendor_casks": policy["vendor_casks"],
                 "unprotected_vendor_casks": sorted((set(policy["vendor_casks"]) & set(casks)) - pins),
                 "pins_verified": results["cask_pins"]["status"] == "ok"}
    return {"schema": 1, "observed_at": datetime.now(timezone.utc).isoformat(),
            "network_freshness": "not-checked", "probes": results, "formulae": formulae, "casks": casks,
            "npm_packages": {k:v.get("version") for k,v in packages.items()}, "tools": tools,
            "apps": apps, "app_scan_errors": app_errors, "ownership": ownership,
            "local_config_names": names,
            "repo_config_names": sorted(p.name for p in (REPO / "home/.config").iterdir())}


def check_updates(policy=None):
    # Explicit check only: native agent updaters are deliberately NOT called.
    # Some ostensibly diagnostic commands prompt, migrate or self-update.
    results = {
        "brew": probe_json(["brew", "outdated", "--json=v2"]),
        "npm": probe_json(["npm", "outdated", "--global", "--json"]),
        "mas": probe_mas(["mas", "outdated", "--json", "--inaccurate"]),
    }
    npm = results["npm"]
    # npm outdated returns 1 when it found updates, but also on genuine errors.
    data = npm.get("data")
    if npm.get("returncode") == 1 and isinstance(data, dict) and data and all(
            isinstance(v, dict) and isinstance(v.get("latest"), str) for v in data.values()):
        npm["status"] = "ok"
    brew = results["brew"]
    if brew["status"] == "ok" and not (isinstance(brew.get("data"), dict) and
            all(isinstance(brew["data"].get(k), list) and all(isinstance(v, dict) for v in brew["data"][k])
                for k in ("formulae", "casks"))):
        brew["status"] = "malformed"
    if npm["status"] == "ok" and not isinstance(npm.get("data"), dict):
        npm["status"] = "malformed"
    excluded = (policy or {}).get("vendor_casks", [])
    if brew["status"] == "ok":
        brew["data"]["casks"] = [c for c in brew["data"]["casks"]
                                  if c.get("name", c.get("token")) not in excluded]
    # Never report a package-manager registration version as the vendor app's
    # actual version. Omitted products are explicitly outside this queue.
    brew["vendor_managed_excluded"] = excluded
    return {"providers": results,
            "limitations": ["brew uses available metadata: brew update is NOT run; this is not proof of latest upstream versions.",
                            "Vendor-owned casks in private policy are excluded. No greedy checks or blind reinstall.",
                            "App Store uses the less accurate no-dialog mode; it does not start/cancel downloads.",
                            "Native CLIs, pnpm/bun/uv tools and vendor desktop updaters remain NOT CHECKED for freshness."]}


def safe(value):
    return "".join(c if c.isprintable() else "?" for c in str(value))


def render(data):
    print("Software inventory / update guidance — READ ONLY")
    if "update_checks" not in data:
        print("Freshness not checked. Use 'software check' for partial version checks.")
    print("Installed: %d formulae, %d casks, %d top-level app bundles" %
          (len(data["formulae"]), len(data["casks"]), len(data["apps"])))
    for name, result in data["probes"].items():
        if result["status"] != "ok" or result.get("warning"):
            print("NOTICE:", name, result["status"], "(warnings; inventory may be incomplete)" if result.get("warning") else "")
    for tool in data["tools"]:
        print("\n%s: %s; version=%s" % (tool["name"], tool["owner"], safe(tool["version"] or "not-read")))
        print("  active:", safe(tool["active"] or "not on PATH"))
        for candidate in tool["candidates"]:
            print("  candidate:", safe(candidate["path"]), "->", safe(candidate["target"]), "" if candidate["usable"] else "[BROKEN/NOT EXECUTABLE]")
        if tool["command"]:
            print("  suggested (NOT executed):", safe(shlex.join(tool["command"])))
        for note in tool["advice"]:
            print("  review:", note)
    print("\nDesktop apps: keep one updater per product (vendor OR brew OR App Store).")
    ownership = data["ownership"]
    print("Vendor-owned casks excluded from update queue:", ", ".join(ownership["vendor_casks"]) or "none selected")
    if ownership["unprotected_vendor_casks"]:
        print("REVIEW: vendor-owned casks not pinned against brew upgrades:", ", ".join(ownership["unprotected_vendor_casks"]))
    print("An app receipt/feed is evidence, not proof auto-updates are enabled. CLI and GUI are separate products.")
    print("Do not run broad brew/npm/uv/mas upgrades, cleanup, or delete unknown config based on this inventory.")
    print("JSON includes app/package evidence and ownership policy; keep it private. No credentials/chats/agent settings were read.")
    if "update_checks" in data:
        print("\nUpdate checks (metadata only; no upgrades):")
        for name, result in data["update_checks"]["providers"].items():
            print(name, result["status"], safe(json.dumps(result.get("data"), ensure_ascii=False)))
        for note in data["update_checks"]["limitations"]:
            print("LIMIT:", note)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("inventory", "plan", "check"), nargs="?", default="plan")
    parser.add_argument("--json", action="store_true", help="Print private machine evidence; do not commit it")
    parser.add_argument("--policy", type=Path, help="Private data-only ownership policy; explicit missing files are refused")
    args = parser.parse_args()
    if args.policy and not args.policy.is_file():
        parser.error("Explicit policy file does not exist")
    policy_path = args.policy or Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "ai-first/software/ownership.json"
    policy = load_policy(policy_path)
    data = collect(policy=policy)
    if args.command == "check":
        data["update_checks"] = check_updates(policy)
        data["network_freshness"] = "partial-see-update-checks"
    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        render(data)
    # A partial inventory is useful but never a successful clean bill of health.
    probes = [*data["probes"].values(), *data.get("update_checks", {}).get("providers", {}).values()]
    return 2 if (any(p["status"] in ("failed", "malformed", "incomplete") for p in probes)
                 or data["app_scan_errors"] or data["ownership"]["unprotected_vendor_casks"]) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print("Software inventory failed: " + str(error), file=sys.stderr)
        sys.exit(2)
