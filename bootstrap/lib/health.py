"""Read-only configuration health; never mistakes a file for a live service."""
import json
from pathlib import Path
import shutil

from maintenance import Refused, guard, run_child

FEATURES = {"notifications": "AI_FIRST_FEATURE_NOTIFICATIONS", "recording": "AI_FIRST_FEATURE_RECORDING",
            "automation": "AI_FIRST_FEATURE_WINDOW_AUTOMATION", "ai": "AI_FIRST_FEATURE_AI_HOTKEYS"}
COMMANDS = {"workspace": ["aerospace"], "bar": ["sketchybar"], "borders": ["borders"],
            "terminal": ["kaku"], "shell": ["starship", "yazi"], "media": ["mpv"]}
APPS = {"capslock": "Karabiner-Elements", "automation": "Hammerspoon", "gestures": "BetterTouchTool", "warp": "Warp"}


def doctor(service, choices):
    print("Active profile: " + service.scope())
    selected, valid = [], True
    try:
        selection = service.selection(required=False)
        selected = selection["modules"] if selection else []
    except (Refused, ValueError) as error:
        print("Selection invalid: " + str(error))
        valid = False
    modules = service.expand(choices or selected)
    for path in sorted((service.config / "modules").glob("*/*.conf")):
        if path.parent.name != service.scope():
            print('  MANUAL  not loaded under profile "%s": %s' % (service.scope(), path.parent))
    if not modules:
        print("No confirmed selection; unselected modules are not reported missing.")
        service.select([])
        return valid
    flags = {}
    try:
        keys = sorted(set(FEATURES.values()))
        output = run_child(["/bin/bash", "-c", 'source "$1"; shift; for key in "$@"; do printf "%s\\0" "${!key}"; done',
                            "_", str(service.repo / "home/.config/ai-first/lib/profile.sh"), *keys],
                           env=service.render_env(), capture=True)
        flags = dict(zip(keys, output.split("\0")))
    except Refused as error:
        print("Preference reader failed: " + str(error))
        valid = False
    for module in modules:
        print("\n%s — %s" % (module, service.modules[module][1]))
        files = service.source_files(service.assets([module]))
        missing = [rel for rel in files if not (service.home / rel).is_file()]
        tools = [name for name in COMMANDS.get(module, []) if not shutil.which(name)]
        app = APPS.get(module)
        if app and not any((base / (app + ".app")).is_dir() for base in (Path("/Applications"), service.home / "Applications")):
            tools.append(app + ".app")
        installed = "partial/missing" if missing or tools else "assets/tools-present"
        enabled = flags.get(FEATURES.get(module), "manual/unknown")
        if module == "borders":
            enabled = "manual; stopped by default"
        elif module == "ai":
            enabled = "chooser-hotkeys=" + flags.get(FEATURES[module], "unknown") + "; router independent"
        errors = []
        for rel in files:
            path = service.home / rel
            try:
                guard(path, service.home)
                if not path.is_file():
                    continue
                if path.suffix == ".json":
                    json.loads(path.read_text())
                elif path.suffix == ".sh":
                    run_child(["/bin/bash", "-n", str(path)], capture=True)
            except (OSError, ValueError, Refused) as error:
                errors.append(str(error))
        config = "missing" if missing else "partial (asset + Shell/JSON checks only)"
        if module == "workspace" and not missing:
            try:
                candidate = service.render_candidate()
                config = "valid (TOML + project invariants)" if candidate == (service.home / ".aerospace.toml").read_bytes() else "drift (layout/routes)"
                if config.startswith("drift"):
                    valid = False
            except (OSError, ValueError, Refused) as error:
                errors.append(str(error))
        if errors:
            config = "invalid: " + "; ".join(errors)
        print("  selected=%s | installed=%s | enabled=%s" % ("yes" if module in selected else "no (explicit inspection)", installed, enabled))
        print("  config-valid=%s | runtime=unverified" % config)
        if missing:
            print("  Missing assets: " + ", ".join(missing[:4]) + (" ..." if len(missing) > 4 else ""))
        if tools:
            print("  Missing applications/commands: " + ", ".join(tools))
        print("  MANUAL  permissions: " + service.modules[module][3])
        valid = valid and not (missing or tools or errors)
    print("\nRuntime unknown: no IPC, service, permission or live-desktop validation performed.")
    return valid
