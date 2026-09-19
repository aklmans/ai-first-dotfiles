"""Private, local-only intent bundles; no implementation, credentials or HOME archive."""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from maintenance import (Maintenance, Refused, PROFILE_RE, SAFE_NAME, atomic_bytes,
                         checked_relative, guard, read_profile, run_child, save_json)

PROFILE_KEYS = set("""AI_FIRST_PRESET AI_FIRST_ADVISOR_SCENES AI_FIRST_ADVISOR_WORKSPACE_MODE
AI_FIRST_ADVISOR_DESK_MODE AI_FIRST_ADVISOR_PLACEMENT AI_FIRST_APP_ROUTING AI_FIRST_ROUTING_PACK
AI_FIRST_FEATURE_AI_HOTKEYS AI_FIRST_FEATURE_NOTIFICATIONS AI_FIRST_FEATURE_RECORDING
AI_FIRST_FEATURE_WINDOW_AUTOMATION AI_FIRST_CLOCK_SECONDS AI_FIRST_BAR_LEFT_ITEMS
AI_FIRST_BAR_CENTER_ITEMS AI_FIRST_BAR_RIGHT_ITEMS AI_FIRST_NOTIFICATION_APPS
AI_FIRST_TERMINAL_APP AI_FIRST_ADD_BAR_RIGHT_ITEMS AEROSPACE_MAIN_MONITOR_NAME
AEROSPACE_SIDE_MONITOR_NAME AEROSPACE_STAGE_MONITOR_NAME AEROSPACE_MAIN_WORKSPACES
AEROSPACE_SIDE_WORKSPACES AEROSPACE_STAGE_WORKSPACES AEROSPACE_WORKSPACE_ROLE_MAP""".split())
LAYOUT_KEYS = {k for k in PROFILE_KEYS if k.startswith("AEROSPACE_")}
ROUTES = {".config/aerospace/app-routes.conf", ".config/ai-first/captured-routes.conf",
          ".config/ai-first/advisor-routes.conf"}
FIXED = ROUTES | {".config/ai-first/profile.conf", ".config/ai-first/selection.json",
                  ".config/aerospace/displays.conf", ".config/aerospace/workspaces.conf"}
MAX_FILE = 1024 * 1024


def implementation(service):
    paths = run_child(["git", "-C", str(service.repo), "ls-files", "--cached", "--others",
                       "--exclude-standard", "-z", "--", "bootstrap", "home"], capture=True)
    digest = hashlib.sha256()
    for rel in sorted(set(paths.rstrip("\0").split("\0"))):
        path = service.repo / checked_relative(rel)
        if path.is_file():
            digest.update(rel.encode() + b"\0" + path.read_bytes() + b"\0")
    return {"revision": service.revision(), "implementation_sha256": digest.hexdigest()}


def allowed(rel, scope):
    checked_relative(rel)
    if rel in FIXED:
        return True
    parent, name = str(Path(rel).parent), Path(rel).name
    return (parent == ".config/ai-first/modules/" + scope or parent == ".config/aerospace/routing-packs") and bool(re.fullmatch(r"[A-Za-z0-9_-]+\.conf", name))


def canonical(path, rel):
    guard(path)
    if path.stat().st_size > MAX_FILE:
        raise Refused("Intent file too large: " + rel)
    if rel.endswith("selection.json"):
        data = json.loads(path.read_text())
        return (json.dumps({k: data[k] for k in ("schema", "scope", "modules")}, indent=2) + "\n").encode()
    layout = rel in (".config/aerospace/displays.conf", ".config/aerospace/workspaces.conf")
    route = rel in ROUTES or "/routing-packs/" in rel
    values, rows = {}, []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if route:
            fields = line.split("|")
            if len(fields) not in (3, 4, 5) or fields[0] not in ("id", "name") or not fields[1] or "'" in line or any(ord(c) < 32 for c in line):
                raise Refused("Invalid route %s:%s" % (rel, number))
            rows.append(line)
            continue
        match = PROFILE_RE.fullmatch(line)
        if layout:
            match = re.fullmatch(r'''\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([A-Za-z0-9_.:/+-]*))\s*(?:#.*)?''', line)
        if not match:
            raise Refused("Non-literal preference %s:%s; resolve before export/import." % (rel, number))
        key = match[1]
        value = next(v for v in match.groups()[1:] if v is not None) if layout else match[2]
        if key in (LAYOUT_KEYS if layout else PROFILE_KEYS):
            values[key] = value
    for key, value in sorted(values.items()):
        quote = "'" if layout and '"' in value else '"'
        if quote in value or any(ord(c) < 32 for c in value):
            raise Refused("Unrepresentable preference: " + key)
        rows.append(key + "=" + quote + value + quote)
    return ("\n".join(rows) + "\n").encode()


def collect(service):
    selection = service.selection()
    scope = selection["scope"]
    paths = set(FIXED)
    overlay_dir = service.config / "modules" / scope
    guard(overlay_dir, service.home)
    paths.update(str(p.relative_to(service.home)) for p in overlay_dir.glob("*.conf"))
    effective = read_profile(service.config / "profile.conf")
    for path in sorted(overlay_dir.glob("*.conf")):
        effective.update(read_profile(path))
    pack = effective.get("AI_FIRST_ROUTING_PACK", "author")
    if not SAFE_NAME.fullmatch(pack):
        raise Refused("Invalid referenced routing pack.")
    if pack != "none":
        paths.add(".config/aerospace/routing-packs/" + pack + ".conf")
    payload = {}
    for rel in sorted(paths):
        if not allowed(rel, scope):
            raise Refused("Unsupported intent path: " + rel)
        path = service.home / rel
        guard(path, service.home)
        if not path.exists() and "/routing-packs/" in rel:
            path = service.repo / "home" / rel
        if path.exists():
            payload[rel] = canonical(path, rel)
        elif "/routing-packs/" in rel:
            raise Refused("Missing referenced pack: " + pack)
    return scope, payload


def validate_payload(service, scope, payload):
    if not SAFE_NAME.fullmatch(scope) or not {".config/ai-first/selection.json"} <= set(payload):
        raise Refused("Bundle lacks a safe scope/selection.")
    with tempfile.TemporaryDirectory(prefix="ai-first-intent-") as temporary:
        home = Path(temporary)
        for rel, data in payload.items():
            if not allowed(rel, scope):
                raise Refused("Unsupported intent path: " + rel)
            atomic_bytes(home / rel, data)
            if canonical(home / rel, rel) != data:
                raise Refused("Noncanonical/unrecognized bundle data: " + rel)
        staged = Maintenance(home=home, repo=service.repo)
        selection = staged.selection()
        if selection["scope"] != scope:
            raise Refused("Bundle scope disagrees with profile/selection.")
        # Route/schema validation also applies when workspace is not selected.
        staged.render_candidate()


def export_intent(service, directory, apply=False):
    guard(directory, service.home)
    if directory.exists():
        raise Refused("Export needs a new directory; never overwrites a backup.")
    with service.lock() if apply else contextlib.nullcontext():
        scope, payload = collect(service)
        validate_payload(service, scope, payload)
        manifest = dict(schema=1, scope=scope, **implementation(service),
                        files={rel: hashlib.sha256(data).hexdigest() for rel, data in payload.items()})
        print("Private intent export: " + str(directory))
        for rel in sorted(payload):
            print("  " + rel)
        print("Includes private app/display preferences. Excludes secrets, comments, caches, chat and process-only overrides.")
        if not apply:
            print("Preview only; use --apply. Choose your own secure off-device destination afterwards.")
            return
        directory.mkdir(mode=0o700)  # Parent must already exist; exclusive creation.
        for rel, data in payload.items():
            atomic_bytes(directory / "files" / rel, data)
        save_json(directory / "manifest.json", manifest)  # Completion marker written last.
        print("Local export complete, not yet an off-device backup. Test import in an empty temporary HOME.")


def import_intent(service, directory, apply=False):
    guard(directory / "manifest.json", service.home)
    if (directory / "manifest.json").stat().st_size > MAX_FILE:
        raise Refused("Bundle manifest too large.")
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest.get("schema") != 1 or not isinstance(manifest.get("files"), dict) or len(manifest["files"]) > 100:
        raise Refused("Unsupported bundle schema/size.")
    if any(manifest.get(k) != v for k, v in implementation(service).items()):
        raise Refused("Implementation differs from export. Restore the recorded revision/content before import.")
    scope = manifest.get("scope", "")
    payload = {}
    for rel, expected in manifest["files"].items():
        if not allowed(rel, scope):
            raise Refused("Unsupported bundle path: " + rel)
        source = directory / "files" / rel
        guard(source, service.home)
        if source.stat().st_size > MAX_FILE:
            raise Refused("Bundle file too large.")
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise Refused("Bundle checksum mismatch: " + rel)
        payload[rel] = data
    if sum(map(len, payload.values())) > 8 * MAX_FILE:
        raise Refused("Bundle too large.")
    validate_payload(service, scope, payload)
    overlay_dir = service.config / "modules" / scope
    guard(overlay_dir, service.home)
    if any(str(p.relative_to(service.home)) not in payload for p in overlay_dir.glob("*.conf")):
        raise Refused("Extra active overlays exist; import into a clean HOME or resolve them explicitly.")
    for rel, data in payload.items():
        path = service.home / rel
        guard(path, service.home)
        if path.exists() and (not path.is_file() or path.read_bytes() != data):
            raise Refused("Import conflict; unchanged: " + rel)
    def restore():
        for rel, data in payload.items():
            path = service.home / rel
            guard(path, service.home)
            if path.exists() and (not path.is_file() or path.read_bytes() != data):
                raise Refused("Import target changed before write; kept: " + rel)
            atomic_bytes(path, data)
    service.operation("import", ["home:" + rel for rel in payload], apply, restore)
    print("Next: setup.sh update (preview), then update --apply. Install missing apps separately; no activation implied.")
