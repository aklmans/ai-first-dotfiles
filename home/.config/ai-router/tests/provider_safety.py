"""Offline fake adapters only. Run inside tests/run-all.sh's OS boundary."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root, source, router = map(Path, sys.argv[1:])
# Probe exec denial with documented help flags, never clipboard contents.
# A policy regression must fail even though PATH contains refusal mocks.
for client in ("/usr/bin/pbcopy", "/usr/bin/pbpaste"):
    try:
        subprocess.run([client, "-help"], stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=False, timeout=2)
    except PermissionError:
        pass
    else:
        raise AssertionError(f"OS clipboard execution boundary missing: {client}")

config = root / "config"
tools = config / "lib/router_tools.py"
provider = config / "providers/stub.sh"
provider.write_text(f'#!{sys.executable}\n' + '''
import json, os, signal, subprocess, sys, time
from pathlib import Path
mode = os.environ.get("FIXTURE_MODE", "echo")
if sys.argv[1:] == ["--text-contract"]:
    if mode == "probe-hang": time.sleep(30)
    print("text-v1")
    sys.exit(0)
if sys.argv[1:] == ["--health-check"]:
    if mode == "health-hang": time.sleep(30)
    sys.exit(0)
if mode in ("slow", "background"):
    child = subprocess.Popen([sys.executable, "-c",
        "import pathlib,sys,time; time.sleep(4); pathlib.Path(sys.argv[1]).write_text('leaked')",
        os.environ["FIXTURE_MARKER"]], stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    Path(os.environ["FIXTURE_READY"]).write_text(str(os.getpgrp()))
    if mode == "slow":
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        time.sleep(30)
elif mode == "overflow":
    sys.stdout.write("x" * (5 * 1024 * 1024))
elif mode == "uncertain":
    sys.exit(75)
else:
    text = sys.stdin.read()
    print(json.dumps({"text": text, "cwd": os.getcwd(),
                      "input_env": os.environ.get("AI_ROUTER_INPUT"),
                      "selection_env": os.environ.get("AI_ROUTER_SELECTION")}))
    print("STDERR_MUST_NOT_BECOME_OUTPUT", file=sys.stderr)
''')
provider.chmod(0o700)
(config / "prompts/safe.md").write_text("""---
id: safe
default_provider: stub
fallback_provider: other
output: preview
---
{{selection}}|{{clipboard}}|{{frontmost_app}}|{{window_title}}
""")
other = config / "providers/other.sh"
other.write_text('''#!/bin/sh
if [ "${1:-}" = --text-contract ]; then printf 'text-v1\n'; exit 0; fi
printf 'used' > "$FIXTURE_FALLBACK"
printf 'approved fallback'
''')
other.chmod(0o700)
env = dict(os.environ, AI_ROUTER_HOME=str(config), AI_ROUTER_NOTIFY="0",
           FIXTURE_MARKER=str(root / "leaked"), FIXTURE_READY=str(root / "ready"),
           FIXTURE_FALLBACK=str(root / "fallback"))


def helper(timeout="5", mode="echo", flag=None, payload="你好\nexplicit input"):
    return subprocess.run([sys.executable, str(tools), "run-provider", str(provider),
                           timeout] + ([flag] if flag else []), input=payload, text=True,
                          capture_output=True, env=dict(env, FIXTURE_MODE=mode), timeout=12)


def invoke(*flags, mode="echo", payload="explicit input", extra=None):
    return subprocess.run(["/bin/bash", str(router), "run", "safe", *flags],
                          input=payload, text=True, capture_output=True,
                          env=dict(env, FIXTURE_MODE=mode, **(extra or {})), timeout=20)


def group_gone(pid):
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return True
    except PermissionError:
        result = subprocess.run(["/bin/ps", "-axo", "pgid=,stat="],
                                text=True, capture_output=True, check=True)
        return not any(line.split()[0] == str(pid) and not line.split()[1].startswith("Z")
                       for line in result.stdout.splitlines() if len(line.split()) == 2)
    return False


def reset_markers():
    for key in ("FIXTURE_MARKER", "FIXTURE_READY", "FIXTURE_FALLBACK"):
        Path(env[key]).unlink(missing_ok=True)


result = helper()
assert result.returncode == 0, result.stderr
payload = json.loads(result.stdout)
assert payload["text"] == "你好\nexplicit input"
assert payload["cwd"] != str(Path.cwd()) and not Path(payload["cwd"]).exists()
assert "STDERR_MUST_NOT" not in result.stdout + result.stderr
for invalid in ("nan", "inf", "0", "-1", "3601", "oops"):
    assert helper(timeout=invalid).returncode == 64
result = helper(mode="overflow")
assert result.returncode == 65, (result.returncode, result.stderr)
assert helper(payload="x" * (4 * 1024 * 1024 + 1)).returncode == 65
for mode, flag in (("probe-hang", None), ("health-hang", "--health-check")):
    result = helper(timeout="0.3", mode=mode, flag=flag)
    assert result.returncode == 71, (mode, result.returncode, result.stderr)

# Stop descendants on timeout AND on apparently successful early parent exit.
for mode, timeout, expected in (("slow", "2", 71), ("background", "5", 0)):
    reset_markers()
    result = helper(timeout=timeout, mode=mode)
    assert result.returncode == expected, (result.returncode, result.stderr)
    assert group_gone(int(Path(env["FIXTURE_READY"]).read_text()))
    time.sleep(4.1)  # detect delayed writes, not just an instantaneous absence
    assert not Path(env["FIXTURE_MARKER"]).exists()

# No per-request recipient means no provider or GUI input capture.
assert invoke().returncode == 64
assert invoke("--provider", "stub", "--fallback", "other,bad/path").returncode == 64
assert invoke("--provider", "stub", "--provder", "other").returncode == 64
assert invoke("--provider", "stub", "--provider", "other").returncode == 64
assert invoke("--provider", "stub", "--from", "stdin", payload="").returncode == 66

# Exercise the actual input/context functions with injected GUI readers. No
# system clipboard or application title is used, even inside the OS sandbox.
definitions = router.read_text().split("\ncheck_dependencies\nmigrate_legacy_runtime\n", 1)[0]
for preference, selection, expected in (("selection", "", "empty||||"),
                                        ("selection", "chosen", "selection|chosen|||"),
                                        ("clipboard", "", "clipboard|chosen clipboard|||")):
    harness = definitions + '''
read_selection() { printf '%s' "$FIXTURE_SELECTION"; }
clipboard_paste() { printf 'chosen clipboard'; }
frontmost_app() { printf 'MUST_NOT_COLLECT_APP'; }
window_title() { printf 'MUST_NOT_COLLECT_TITLE'; }
macos_gui_ready=1
text_request=1
input_pref="$FIXTURE_INPUT_PREF"
resolve_prompt_input
printf '%s|%s|%s|%s|%s' "$input_source" "$input_text" "$clipboard_text" "$app_name" "$title"
'''
    harness_path = root / "input-context.sh"
    harness_path.write_text(harness)
    result = subprocess.run(["/bin/bash", str(harness_path)], stdin=subprocess.DEVNULL,
                            text=True, capture_output=True, timeout=10,
                            env=dict(env, FIXTURE_SELECTION=selection,
                                     FIXTURE_INPUT_PREF=preference))
    assert result.returncode == 0 and result.stdout == expected, (result.stdout, result.stderr)

# Existing/malformed configs never silently add recipients.
for content in ('{"providers":{"default":["other"]}}', '{broken'):
    (config / "config.json").write_text(content)
    reset_markers()
    result = invoke("--provider", "stub", mode="uncertain")
    assert result.returncode == 75, result.stderr
    assert not Path(env["FIXTURE_FALLBACK"]).exists()
(config / "config.json").write_text('{}')
result = invoke("--provider", "stub", extra={"AI_ROUTER_INPUT": "env explicit",
                                            "AI_ROUTER_SELECTION": "not for child"})
assert result.returncode == 0, result.stderr
payload = json.loads(result.stdout)
assert "env explicit|||" in payload["text"]
assert payload["input_env"] is None and payload["selection_env"] is None

# A confirmed timeout can retry only the explicitly named fallback.
reset_markers()
result = invoke("--provider", "stub", "--fallback", "other", mode="slow",
                extra={"AI_ROUTER_PROVIDER_TIMEOUT_SECONDS": "2"})
assert result.returncode == 0 and "approved fallback" in result.stdout, result.stderr
assert group_gone(int(Path(env["FIXTURE_READY"]).read_text()))
assert Path(env["FIXTURE_FALLBACK"]).exists()
reset_markers()
result = invoke("--provider", "stub", "--fallback", "other", mode="uncertain")
assert result.returncode == 75 and not Path(env["FIXTURE_FALLBACK"]).exists()

# SIGTERM to the actual top-level shell (as hs.task:terminate does), not merely
# directly to its Python helper. It must reap the supervisor before returning.
for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    reset_markers()
    proc = subprocess.Popen(["/bin/bash", str(router), "run", "safe", "--provider", "stub",
                             "--fallback", "other"], stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            env=dict(env, FIXTURE_MODE="slow", AI_ROUTER_INPUT="cancel me"),
                            # run-all backgrounds suites; Bash cannot trap a
                            # signal inherited as ignored. Simulate a foreground
                            # CLI's SIGINT disposition, not that test-runner quirk.
                            preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    try:
        deadline = time.monotonic() + 10
        while not Path(env["FIXTURE_READY"]).exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        assert Path(env["FIXTURE_READY"]).exists(), "provider did not start"
        proc.send_signal(sig)
        try:
            out, err = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            raise AssertionError(f"top-level cancellation did not finish: {sig}")
        assert proc.returncode == 128 + sig, (proc.returncode, out, err)
        assert group_gone(int(Path(env["FIXTURE_READY"]).read_text()))
        assert not Path(env["FIXTURE_FALLBACK"]).exists()
        assert not list((config / "cache").glob("request-output.*"))
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.communicate(timeout=5)
time.sleep(4.1)
assert not Path(env["FIXTURE_MARKER"]).exists()

# Stock coding clients are not contacted just because they're installed. No
# real CLI is invoked by this test (or by these quarantined adapter paths).
for name in ("codex", "claude", "gemini", "kimi", "junie", "ollama", "app-opener", "_template"):
    result = subprocess.run([sys.executable, str(tools), "run-provider",
                             str(source / "providers" / (name + ".sh")), "2"],
                            input="private fixture input", text=True,
                            capture_output=True, env=env, timeout=5)
    assert result.returncode == 78, (name, result.returncode, result.stderr)
print("ok - text recipient, bounded process groups, cancellation and privacy")
