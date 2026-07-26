#!/usr/bin/env python3
import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
import time
import uuid

MAX_FILE_SIZE = 1024 * 1024  # 1MB
MAX_ERROR_LENGTH = 2000
MAX_USAGE_ITEMS = 500

def sanitize_error(error: str) -> str:
    """Remove sensitive information from error messages."""
    patterns = [
        (r'(api[_-]?key|token|password|secret|bearer)["\s:=]+[\w\-./]+', r'\1=***'),
        (r'Bearer\s+[\w\-./]+', r'Bearer ***'),
        (r'(https?://[^/]+/)[\w\-./]+@', r'\1***@'),
        (r'/Users/[^/\s]+', r'/Users/***'),
    ]
    for pattern, replacement in patterns:
        error = re.sub(pattern, replacement, error, flags=re.IGNORECASE)
    return error[:MAX_ERROR_LENGTH]


def parse_frontmatter(path: pathlib.Path):
    stat = path.stat()
    if stat.st_size > MAX_FILE_SIZE:
        raise ValueError(f"File too large: {stat.st_size} bytes (max {MAX_FILE_SIZE})")

    text = path.read_text(encoding="utf-8")
    meta = {}
    body = text
    if text.startswith("---\n"):
        try:
            _, raw, body = text.split("---\n", 2)
        except ValueError:
            raw = ""
            body = text
        current = None
        for line in raw.splitlines():
            if not line.strip():
                continue
            if line.startswith("  - ") and current:
                meta.setdefault(current, []).append(line[4:].strip())
                continue
            if ":" in line:
                key, value = line.split(":", 1)
                key = key.strip()
                value = value.strip().strip('"')
                current = key
                meta[key] = value if value else []
    return meta, body


def field(args):
    meta, _ = parse_frontmatter(pathlib.Path(args[0]))
    value = meta.get(args[1], "")
    if isinstance(value, list):
        print(",".join(value))
    else:
        print(value)


def body(args):
    _, content = parse_frontmatter(pathlib.Path(args[0]))
    print(content, end="")


def as_list(value):
    if not value:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item)]
    return [str(value)]


def as_int(value, default=1000):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def render(args):
    _, content = parse_frontmatter(pathlib.Path(args[0]))
    values = {
        "selection": os.environ.get("AI_ROUTER_SELECTION_TEXT", ""),
        "clipboard": os.environ.get("AI_ROUTER_CLIPBOARD_TEXT", ""),
        "frontmost_app": os.environ.get("AI_ROUTER_FRONTMOST_APP", ""),
        "window_title": os.environ.get("AI_ROUTER_WINDOW_TITLE", ""),
        "action": os.environ.get("AI_ROUTER_ACTION", ""),
        "date": os.environ.get("AI_ROUTER_DATE", ""),
    }
    for key, value in values.items():
        content = content.replace("{{" + key + "}}", value)
    print(content, end="")


def log_event(args):
    path = pathlib.Path(args[0])
    path.parent.mkdir(parents=True, exist_ok=True)
    event = {
        "request_id": os.environ.get("AI_ROUTER_REQUEST_ID") or str(uuid.uuid4()),
        "time": datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(timespec="seconds"),
        "action": os.environ.get("AI_ROUTER_EVENT_ACTION", ""),
        "provider": os.environ.get("AI_ROUTER_EVENT_PROVIDER", ""),
        "input_chars": int(os.environ.get("AI_ROUTER_EVENT_INPUT_CHARS") or 0),
        "output_chars": int(os.environ.get("AI_ROUTER_EVENT_OUTPUT_CHARS") or 0),
        "duration_ms": int(os.environ.get("AI_ROUTER_EVENT_DURATION_MS") or 0),
        "status": os.environ.get("AI_ROUTER_EVENT_STATUS", ""),
    }
    parent = os.environ.get("AI_ROUTER_PARENT_REQUEST_ID", "")
    if parent:
        event["parent_request_id"] = parent
    error = os.environ.get("AI_ROUTER_EVENT_ERROR", "")
    if error:
        event["error"] = sanitize_error(error)
    input_source = os.environ.get("AI_ROUTER_EVENT_INPUT_SOURCE", "")
    if input_source:
        event["input_source"] = input_source
    selection_source = os.environ.get("AI_ROUTER_EVENT_SELECTION_SOURCE", "")
    if selection_source:
        event["selection_source"] = selection_source
    selection_ms = os.environ.get("AI_ROUTER_EVENT_SELECTION_MS", "")
    if selection_ms:
        try:
            event["selection_ms"] = int(selection_ms)
        except ValueError:
            pass
    selection_attempts = os.environ.get("AI_ROUTER_EVENT_SELECTION_ATTEMPTS", "")
    if selection_attempts:
        try:
            event["selection_attempts"] = int(selection_attempts)
        except ValueError:
            pass
    with path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(event, ensure_ascii=False) + "\n")


def plugin_row(args):
    path = pathlib.Path(args[0])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    interface = data.get("interface") or {}
    name = interface.get("displayName") or data.get("name") or path.parent.parent.name
    desc = interface.get("shortDescription") or data.get("description") or ""
    desc = " ".join(str(desc).split())
    print(f"{name}\t{desc}\t{path}")


def md_catalog(root: pathlib.Path, kind: str):
    result = []
    for path in sorted(root.glob("*.md")) if root.exists() else []:
        meta, body_text = parse_frontmatter(path)
        name = meta.get("id") or path.stem
        title = meta.get("title") or path.stem
        desc = meta.get("description") or ""
        aliases = as_list(meta.get("aliases"))
        keywords = as_list(meta.get("keywords"))
        tags = as_list(meta.get("tags"))
        category = meta.get("category") or ""
        hotkey = meta.get("hotkey") or ""
        priority = as_int(meta.get("priority"))
        searchable = " ".join(
            part
            for part in [
                str(name),
                str(title),
                str(desc),
                str(category),
                " ".join(tags),
                " ".join(aliases),
                " ".join(keywords),
                " ".join(body_text.split()[:80]),
            ]
            if part
        )
        result.append(
            {
                "name": name,
                "type": kind,
                "title": title,
                "description": desc,
                "path": str(path),
                "tags": tags,
                "aliases": aliases,
                "keywords": keywords,
                "category": category,
                "hotkey": hotkey,
                "priority": priority,
                "default_provider": meta.get("default_provider") or "",
                "fallback_provider": meta.get("fallback_provider") or "",
                "fallback_providers": as_list(meta.get("fallback_providers")),
                "input": meta.get("input") or "",
                "output": meta.get("output") or "",
                "allow_replace": str(meta.get("allow_replace") or "").lower() == "true",
                "searchable": searchable,
            }
        )
    return sorted(result, key=lambda item: (item["priority"], item["title"].lower()))


def snippet_catalog(root: pathlib.Path):
    result = []
    for path in sorted(root.glob("*.md")) if root.exists() else []:
        meta, body_text = parse_frontmatter(path)
        lines = [line.strip() for line in body_text.splitlines()]
        heading = ""
        first_body = ""
        for line in lines:
            if not line:
                continue
            if line.startswith("# ") and not heading:
                heading = line[2:].strip()
                continue
            if not first_body:
                first_body = line.strip("# ").strip()
                break
        name = meta.get("id") or path.stem
        title = meta.get("title") or heading or path.stem
        desc = meta.get("description") or first_body
        aliases = as_list(meta.get("aliases"))
        keywords = as_list(meta.get("keywords"))
        tags = as_list(meta.get("tags")) or ["snippet"]
        category = meta.get("category") or "snippet"
        priority = as_int(meta.get("priority"), 1000)
        searchable = " ".join(
            part
            for part in [
                str(name),
                str(title),
                str(desc),
                str(category),
                " ".join(tags),
                " ".join(aliases),
                " ".join(keywords),
                " ".join(body_text.split()[:80]),
            ]
            if part
        )
        result.append(
            {
                "name": name,
                "type": "snippet",
                "title": title,
                "description": desc,
                "path": str(path),
                "tags": tags,
                "aliases": aliases,
                "keywords": keywords,
                "category": category,
                "hotkey": meta.get("hotkey") or "",
                "priority": priority,
                "searchable": searchable,
            }
        )
    return sorted(result, key=lambda item: (item["priority"], item["title"].lower()))


def skill_catalog(home: pathlib.Path):
    roots = [home / ".codex/skills", home / ".agents/skills"]
    result = []
    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.glob("**/SKILL.md")):
            meta, _ = parse_frontmatter(path)
            name = meta.get("name") or path.parent.name
            desc = meta.get("description") or ""
            result.append(
                {
                    "name": name,
                    "type": "skill",
                    "title": name,
                    "description": desc,
                    "path": str(path),
                    "tags": ["skill"],
                }
            )
    return result


def plugin_catalog(home: pathlib.Path):
    roots = [home / ".codex/plugins", home / ".codex/plugins/cache", home / ".agents/plugins"]
    seen = set()
    result = []
    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.glob("**/plugin.json")):
            if path in seen:
                continue
            seen.add(path)
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                data = {}
            interface = data.get("interface") or {}
            name = interface.get("displayName") or data.get("name") or path.parent.parent.name
            desc = interface.get("shortDescription") or data.get("description") or ""
            result.append(
                {
                    "name": name,
                    "type": "plugin",
                    "title": name,
                    "description": " ".join(str(desc).split()),
                    "path": str(path),
                    "tags": data.get("keywords") or ["plugin"],
                }
            )
    return result


def terminal_app(config: dict) -> str:
    value = config_lookup(config, "terminal.app")
    return str(value).strip() if value else "Warp"


# "paste_in_new_warp_tab" is the pre-2.4.0 spelling and still works: an
# existing config.json is not rewritten by a deploy.
PASTE_BEHAVIORS = {"paste_in_terminal", "paste_in_new_warp_tab"}


def agent_description(config: dict, agent: dict) -> str:
    label = agent.get("label") or ""
    behavior = agent.get("behavior") or ""
    command = agent.get("command") or ""
    if behavior == "open_app":
        return f"打开 {label}"
    if behavior in PASTE_BEHAVIORS:
        return f"在 {terminal_app(config)} 新开标签页并粘贴 {command}"
    return command


def agent_catalog(config: dict):
    result = []
    for index, (name, agent) in enumerate((config.get("agents") or {}).items()):
        label = agent.get("label") or name
        behavior = agent.get("behavior") or ""
        command = agent.get("command") or ""
        desc = agent_description(config, agent)
        result.append(
            {
                "name": name,
                "type": "agent",
                "title": label,
                "description": desc,
                "command": command,
                "behavior": behavior,
                "priority": as_int(agent.get("priority"), 500 + index),
                "tags": as_list(agent.get("tags")) or ["agent"],
                "aliases": as_list(agent.get("aliases")),
                "searchable": " ".join([name, label, desc, command]),
            }
        )
    return sorted(result, key=lambda item: (item["priority"], item["title"].lower()))


def tool_catalog():
    tools = [
        ("last-output", "Open Last Output", "打开 cache/last-output.md"),
        ("last-error", "Open Last Error", "打开最近一次错误日志"),
        ("provider-status", "Provider Status", "查看 providers/ 下每个 provider 的状态"),
        ("config", "Open AI Router Config", "打开 ~/.config/ai-router"),
        ("prompts", "Open Prompt Folder", "打开 prompts 目录"),
        ("snippets", "Open Snippet Folder", "打开 snippets 目录"),
        ("logs", "Open Logs", "打开 logs 目录"),
        ("index", "Rebuild Catalog Index", "重新生成 catalogs/*.json"),
    ]
    return [
        {
            "name": name,
            "type": "tool",
            "title": title,
            "description": desc,
            "priority": 900 + index,
            "tags": ["tool"],
            "aliases": [],
            "searchable": " ".join([name, title, desc]),
        }
        for index, (name, title, desc) in enumerate(tools)
    ]


def hammerspoon_choice(item):
    item_type = item["type"]
    prefix = {
        "prompt": "Prompt",
        "snippet": "Snippet",
        "skill": "Skill",
        "plugin": "Plugin",
        "agent": "Agent",
        "tool": "Tool",
    }.get(item_type, item_type.title())
    meta = []
    if item.get("hotkey"):
        meta.append(f"CapsLock+{item['hotkey']}")
    aliases = item.get("aliases") or []
    if aliases:
        meta.append(" ".join(str(alias) for alias in aliases[:8]))
    keywords = item.get("keywords") or []
    if keywords:
        meta.append(" ".join(str(keyword) for keyword in keywords[:8]))
    tags = item.get("tags") or []
    if tags:
        meta.append(" ".join(str(tag) for tag in tags[:5]))
    sub_text = item.get("description") or ""
    if meta:
        sub_text = f"{sub_text} · {' · '.join(meta)}" if sub_text else " · ".join(meta)

    return {
        "text": f"{prefix}: {item.get('title') or item['name']}",
        "subText": sub_text,
        "kind": item_type,
        "value": item["name"] if item_type not in {"skill", "plugin"} else item.get("path") or item["name"],
        "title": item.get("title") or item["name"],
        "searchText": item.get("searchable") or "",
        "category": item.get("category") or "",
        "hotkey": item.get("hotkey") or "",
    }


def index(args):
    config = pathlib.Path(args[0])
    config_data = load_config(config / "config.json")
    home = pathlib.Path.home()
    # The caller passes the runtime state directory. Without it this wrote the
    # catalogs back into ~/.config on every run, undoing the migration that had
    # just moved them out and leaving two copies that drifted apart.
    catalogs = pathlib.Path(args[1]) if len(args) > 1 else config / "catalogs"
    catalogs.mkdir(parents=True, exist_ok=True)
    prompts = md_catalog(config / "prompts", "prompt")
    snippets = snippet_catalog(config / "snippets")
    skills = skill_catalog(home)
    plugins = plugin_catalog(home)
    agents = agent_catalog(config_data)
    tools = tool_catalog()
    hotkeys = [
        {
            "key": item["hotkey"],
            "prompt": item["name"],
            "title": item["title"],
            "desc": item["description"],
        }
        for item in prompts
        if item.get("hotkey")
    ]
    palette = [hammerspoon_choice(item) for item in prompts + snippets + agents + skills + plugins + tools]
    payloads = {
        "prompts.json": prompts,
        "snippets.json": snippets,
        "skills.json": skills,
        "plugins.json": plugins,
        "agents.json": agents,
        "tools.json": tools,
        "hotkeys.json": hotkeys,
        "palette.json": palette,
    }
    for name, payload in payloads.items():
        (catalogs / name).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def clean_tsv(value) -> str:
    return " ".join(str(value or "").replace("\t", " ").splitlines()).strip()


def palette_tsv(args):
    if len(args) != 1:
        print("Usage: router_tools.py palette-tsv <palette.json>", file=sys.stderr)
        return 64

    path = pathlib.Path(args[0])
    try:
        items = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return 66
    except json.JSONDecodeError as exc:
        print(f"invalid palette catalog: {path}: {exc}", file=sys.stderr)
        return 65

    if not isinstance(items, list):
        print(f"invalid palette catalog: {path}: expected array", file=sys.stderr)
        return 65

    for item in items:
        if not isinstance(item, dict):
            continue
        kind = clean_tsv(item.get("kind") or item.get("type"))
        value = clean_tsv(item.get("value") or item.get("name") or item.get("path"))
        if not kind or not value:
            continue
        text = clean_tsv(item.get("text") or item.get("title") or item.get("name") or value)
        sub_text = clean_tsv(item.get("subText") or item.get("description") or item.get("searchText"))
        print(f"{kind}:{value}\t{text}\t{sub_text}\t{kind}\t{value}")


def raycast_snippet_text(text: str) -> str:
    replacements = {
        "{{selection}}": "{clipboard}",
        "{{clipboard}}": "{clipboard}",
        "{{date}}": "{date}",
        "{{frontmost_app}}": "",
        "{{window_title}}": "",
        "{{action}}": "",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    return text


SHORT_KEYWORDS = {
    ("prompt", "ask"): "qa",
    ("prompt", "summarize"): "sm",
    ("prompt", "translate"): "tr",
    ("prompt", "explain"): "ex",
    ("prompt", "rewrite"): "rw",
    ("prompt", "fix"): "fx",
    ("prompt", "extract"): "xt",
    ("prompt", "research"): "rs",
    ("prompt", "generate"): "gn",
    ("prompt", "draft"): "df",
    ("prompt", "translate-to-en"): "en",
    ("prompt", "optimize-prompt"): "op",
    ("prompt", "code-review"): "cr",
    ("prompt", "commit-message"): "cm",
    ("prompt", "debug"): "db",
    ("prompt", "pr-description"): "pr",
    ("prompt", "refactor"): "rf",
    ("prompt", "terminal-error"): "te",
    ("snippet", "architecture-review"): "ar",
    ("snippet", "bug-report"): "br",
    ("snippet", "commit-message"): "gc",
    ("snippet", "incident-report"): "ir",
    ("snippet", "meeting-notes"): "mt",
    ("snippet", "pr-review"): "rv",
    ("snippet", "refactor-request"): "rr",
    ("snippet", "sql-debug"): "sq",
    ("snippet", "terminal-error"): "er",
}


def export_keyword(kind: str, name: str) -> str:
    short = SHORT_KEYWORDS.get((kind, name))
    if not short:
        safe = re.sub(r"[^a-z0-9]+", "", str(name).lower())
        short = (safe[:3] or "ai") if kind == "prompt" else ("s" + safe[:2] or "sn")
    return f";{short}"


def catalog_item_body(item: dict) -> str:
    path = pathlib.Path(item["path"])
    _, body_text = parse_frontmatter(path)
    return body_text.strip()


def export_items(config: pathlib.Path):
    prompts = md_catalog(config / "prompts", "prompt")
    snippets = snippet_catalog(config / "snippets")
    return prompts + snippets


def export_raycast_snippets(args):
    if len(args) != 2:
        print("Usage: router_tools.py export-raycast-snippets <config-dir> <output-json>", file=sys.stderr)
        return 64

    config = pathlib.Path(args[0])
    output = pathlib.Path(args[1])
    output.parent.mkdir(parents=True, exist_ok=True)

    snippets = []
    for item in export_items(config):
        item_type = item["type"]
        label = "AI Prompt" if item_type == "prompt" else "AI Snippet"
        text = raycast_snippet_text(catalog_item_body(item))
        if len(text) > 65536:
            text = text[:65520] + "\n\n[truncated]"
        snippets.append(
            {
                "name": f"{label} / {item.get('title') or item['name']}",
                "text": text,
                "keyword": export_keyword(item_type, item["name"]),
            }
        )

    output.write_text(json.dumps(snippets, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(str(output))


def template_variables(text: str):
    return sorted(set(re.findall(r"{{\s*([a-zA-Z0-9_-]+)\s*}}", text)))


def export_source_path(config: pathlib.Path, item: dict) -> str:
    raw_path = item.get("path") or ""
    if not raw_path:
        return ""

    path = pathlib.Path(raw_path)
    try:
        return path.resolve().relative_to(config.resolve()).as_posix()
    except ValueError:
        return str(path)


def export_generic_snippets(args):
    if len(args) != 2:
        print("Usage: router_tools.py export-generic-snippets <config-dir> <output-json>", file=sys.stderr)
        return 64

    config = pathlib.Path(args[0])
    output = pathlib.Path(args[1])
    output.parent.mkdir(parents=True, exist_ok=True)

    exported = []
    for item in export_items(config):
        raw = catalog_item_body(item)
        item_type = item["type"]
        exported.append(
            {
                "id": item["name"],
                "type": item_type,
                "title": item.get("title") or item["name"],
                "description": item.get("description") or "",
                "category": item.get("category") or "",
                "tags": item.get("tags") or [],
                "aliases": item.get("aliases") or [],
                "keywords": item.get("keywords") or [],
                "keyword": export_keyword(item_type, item["name"]),
                "text": raw,
                "raycast_text": raycast_snippet_text(raw),
                "variables": template_variables(raw),
                "source_path": export_source_path(config, item),
            }
        )

    payload = {
        "version": 1,
        "source": "AI Workflow Router",
        "items": exported,
    }
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(str(output))


def now_ms(_args):
    print(int(time.time() * 1000))


def sanitize_text(args):
    """Sanitize text by removing sensitive information."""
    text = sys.stdin.read() if not args else " ".join(args)
    print(sanitize_error(text), end="")


def run_provider(args):
    if len(args) != 2:
        print("Usage: router_tools.py run-provider <script> <timeout-seconds>", file=sys.stderr)
        return 64

    script = pathlib.Path(args[0])
    try:
        timeout = float(args[1])
    except ValueError:
        print(f"invalid provider timeout: {args[1]}", file=sys.stderr)
        return 64

    prompt = sys.stdin.read()
    try:
        completed = subprocess.run(
            [str(script)],
            input=prompt,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = error.output or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        if output:
            print(output, end="")
            if not output.endswith("\n"):
                print()
        print(f"provider timed out after {timeout:g}s", file=sys.stderr)
        return 71
    except OSError as error:
        print(str(error), file=sys.stderr)
        return 69

    print(completed.stdout or "", end="")
    return completed.returncode


def load_config(path: pathlib.Path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        # A broken config.json must not take the whole router down: every
        # caller has a documented default to fall back to.
        print(f"ai-router: ignoring unreadable config: {path}", file=sys.stderr)
        return {}


def ensure_dirs(args):
    """mkdir -p + chmod for callers that cannot rely on coreutils being on PATH.

    The shell fast path is still `mkdir -p`; this exists so the router keeps
    working with a minimal PATH (containers, CI, `env PATH=...` sandboxes),
    where python3 is the only dependency the router actually requires.
    """
    if not args:
        print("Usage: router_tools.py ensure-dirs <octal-mode|-> <dir>...", file=sys.stderr)
        return 64

    mode = None
    if args[0] != "-":
        try:
            mode = int(args[0], 8)
        except ValueError:
            print(f"invalid mode: {args[0]}", file=sys.stderr)
            return 64

    for raw in args[1:]:
        path = pathlib.Path(raw)
        try:
            path.mkdir(parents=True, exist_ok=True)
            if mode is not None:
                path.chmod(mode)
        except OSError as error:
            print(str(error), file=sys.stderr)
            return 73
    return 0


def config_lookup(config: dict, dotted: str):
    node = config
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


def config_value(args):
    """config-value <config.json> <dotted.key> [default] -> one line on stdout."""
    if len(args) < 2:
        print("Usage: router_tools.py config-value <config.json> <dotted.key> [default]", file=sys.stderr)
        return 64

    value = config_lookup(load_config(pathlib.Path(args[0])), args[1])
    default = args[2] if len(args) > 2 else ""

    if value is None or value == "":
        print(default)
        return 0
    if isinstance(value, bool):
        print("true" if value else "false")
        return 0
    if isinstance(value, list):
        print(",".join(str(item) for item in value if str(item)))
        return 0
    if isinstance(value, dict):
        print(json.dumps(value, ensure_ascii=False))
        return 0
    print(value)
    return 0


# Shipped fallback chain. Both CLIs are installable today and both are covered
# by an adapter in providers/. Changing this list is a product decision, so it
# lives in exactly one place.
DEFAULT_PROVIDER_CHAIN = ["claude", "codex"]


def provider_chain(config: dict):
    value = config_lookup(config, "providers.default")
    if isinstance(value, str):
        chain = [part.strip() for part in re.split(r"[,;]", value)]
    elif isinstance(value, list):
        chain = [str(part).strip() for part in value]
    else:
        chain = []
    return [part for part in chain if part] or list(DEFAULT_PROVIDER_CHAIN)


def config_providers(args):
    """config-providers <config.json> -> comma separated default chain."""
    if len(args) != 1:
        print("Usage: router_tools.py config-providers <config.json>", file=sys.stderr)
        return 64

    print(",".join(provider_chain(load_config(pathlib.Path(args[0])))))
    return 0


def config_bool(config: dict, dotted: str, default: bool) -> str:
    value = config_lookup(config, dotted)
    if value is None:
        return "1" if default else "0"
    if isinstance(value, bool):
        return "1" if value else "0"
    return "0" if str(value).strip().lower() in {"0", "false", "no", "off", ""} else "1"


def config_runtime(args):
    """Every config-driven runtime setting in one call.

    The shell reads this once per invocation instead of spawning python3 per
    field, which keeps the render hot path (the one bound to a hotkey) cheap.
    """
    if len(args) != 1:
        print("Usage: router_tools.py config-runtime <config.json>", file=sys.stderr)
        return 64

    config = load_config(pathlib.Path(args[0]))
    terminal = config_lookup(config, "terminal.app")
    print(f"terminal_app={str(terminal).strip() if terminal else 'Warp'}")
    print(f"provider_chain={','.join(provider_chain(config))}")
    print(f"log_events={config_bool(config, 'privacy.log_events', True)}")
    print(f"debug_full_error_log={config_bool(config, 'privacy.debug_full_error_log', False)}")
    return 0


def load_json(path: pathlib.Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json_atomic(path: pathlib.Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def state_key(kind: str, value: str):
    return f"{kind}:{value}"


def now_state_time():
    now = datetime.datetime.now(datetime.timezone.utc).astimezone()
    return now.isoformat(timespec="seconds"), time.time()


def state_record_usage(args):
    if len(args) < 4:
        print("Usage: router_tools.py state-record <usage.json> <kind> <value> <title>", file=sys.stderr)
        return 64

    path = pathlib.Path(args[0])
    kind, value, title = args[1], args[2], args[3]
    data = load_json(path, {"version": 1, "items": {}})
    data.setdefault("version", 1)
    items = data.setdefault("items", {})
    key = state_key(kind, value)
    now_iso, now_ts = now_state_time()
    entry = items.get(key) or {
        "kind": kind,
        "value": value,
        "title": title,
        "count": 0,
        "first_used": now_iso,
        "first_used_ts": now_ts,
    }
    entry["kind"] = kind
    entry["value"] = value
    entry["title"] = title or entry.get("title") or value
    entry["count"] = int(entry.get("count") or 0) + 1
    entry["last_used"] = now_iso
    entry["last_used_ts"] = now_ts
    items[key] = entry

    if len(items) > MAX_USAGE_ITEMS:
        sorted_items = sorted(items.items(), key=lambda pair: pair[1].get("last_used_ts", 0), reverse=True)
        data["items"] = dict(sorted_items[:MAX_USAGE_ITEMS])

    write_json_atomic(path, data)


def favorite_items(data):
    items = data.get("items") if isinstance(data, dict) else None
    return items if isinstance(items, list) else []


def state_favorite(args):
    if len(args) < 2:
        print("Usage: router_tools.py state-favorite <favorites.json> <list|add|remove|toggle> [kind value title]", file=sys.stderr)
        return 64

    path = pathlib.Path(args[0])
    action = args[1]
    data = load_json(path, {"version": 1, "items": []})
    data.setdefault("version", 1)
    items = favorite_items(data)
    data["items"] = items

    if action == "list":
        for item in items:
            print(f"{item.get('kind','')}\t{item.get('value','')}\t{item.get('title','')}")
        return 0

    if len(args) < 5:
        print("Usage: router_tools.py state-favorite <favorites.json> <add|remove|toggle> <kind> <value> <title>", file=sys.stderr)
        return 64

    kind, value, title = args[2], args[3], args[4]
    key = state_key(kind, value)
    existing_index = None
    for index, item in enumerate(items):
        if state_key(item.get("kind", ""), item.get("value", "")) == key:
            existing_index = index
            break

    if action == "add":
        if existing_index is None:
            now_iso, now_ts = now_state_time()
            items.insert(0, {
                "kind": kind,
                "value": value,
                "title": title or value,
                "created_at": now_iso,
                "created_at_ts": now_ts,
            })
            print("added")
        else:
            items[existing_index]["title"] = title or items[existing_index].get("title") or value
            print("already-added")
    elif action == "remove":
        if existing_index is not None:
            items.pop(existing_index)
            print("removed")
        else:
            print("not-found")
    elif action == "toggle":
        if existing_index is not None:
            items.pop(existing_index)
            print("removed")
        else:
            now_iso, now_ts = now_state_time()
            items.insert(0, {
                "kind": kind,
                "value": value,
                "title": title or value,
                "created_at": now_iso,
                "created_at_ts": now_ts,
            })
            print("added")
    else:
        print(f"unknown favorite action: {action}", file=sys.stderr)
        return 64

    write_json_atomic(path, data)


def config_agent_field(args):
    if len(args) != 3:
        print("Usage: router_tools.py config-agent-field <config.json> <agent> <field>", file=sys.stderr)
        return 64
    config = load_config(pathlib.Path(args[0]))
    agent = (config.get("agents") or {}).get(args[1]) or {}
    value = agent.get(args[2], "")
    if isinstance(value, (dict, list)):
        print(json.dumps(value, ensure_ascii=False))
    else:
        print(value)


def config_agent_menu(args):
    if len(args) != 1:
        print("Usage: router_tools.py config-agent-menu <config.json>", file=sys.stderr)
        return 64
    config = load_config(pathlib.Path(args[0]))
    agents = config.get("agents") or {}
    for name, agent in agents.items():
        label = agent.get("label") or name
        print(f"agent:{name}\t{label}\t{agent_description(config, agent)}\tagent\t{name}")


COMMANDS = {
    "field": field,
    "body": body,
    "render": render,
    "log-event": log_event,
    "plugin-row": plugin_row,
    "index": index,
    "palette-tsv": palette_tsv,
    "export-raycast-snippets": export_raycast_snippets,
    "export-generic-snippets": export_generic_snippets,
    "now-ms": now_ms,
    "sanitize": sanitize_text,
    "run-provider": run_provider,
    "config-agent-field": config_agent_field,
    "config-agent-menu": config_agent_menu,
    "config-value": config_value,
    "config-providers": config_providers,
    "config-runtime": config_runtime,
    "ensure-dirs": ensure_dirs,
    "state-record": state_record_usage,
    "state-favorite": state_favorite,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(f"Usage: router_tools.py <{'|'.join(sorted(COMMANDS))}> ...", file=sys.stderr)
        return 64
    result = COMMANDS[sys.argv[1]](sys.argv[2:])
    return int(result or 0)


if __name__ == "__main__":
    raise SystemExit(main())
