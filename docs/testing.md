# Test isolation

Run automated suites through the macOS entry point:

```bash
bash tests/run-all.sh
bash tests/run-all.sh tests/smoke/safety_boundary_smoke.sh
```

The runner creates a unique temporary directory, clears inherited environment
variables, supplies a fake HOME/state location and a restricted PATH, then runs
each selected suite with clean and author-full fixture homes. These are two
starting configurations on one machine, not two hardware validations.

`sandbox-exec` denies network access, writes outside the temporary boundary, and
known absolute desktop/system clients such as AeroSpace, Hammerspoon,
`defaults`, `open`, `osascript` and `launchctl`. PATH entries for external tools
refuse calls unless a test supplies its own fixture executable. GUI command
environment overrides point to refusal stubs as well. Missing or unusable OS
isolation stops the run; it never falls back to running unprotected.

If an outer agent sandbox prevents starting `sandbox-exec`, request permission
to run this exact isolated entry point. Do not solve it by running individual
suites outside the boundary. A fake HOME does not redirect a running desktop's
IPC endpoint.

## Allowed exceptions and limits

- System utilities and interpreters remain available. `rg` and `lua`, when
  installed, are carried into the restricted PATH.
- Shell tests need PTY device writes. macOS Bash 3.2 also creates heredoc scratch
  files in fixed temporary directories rather than always respecting TMPDIR;
  the policy allows the narrow `sh-thd` scratch-name pattern. Explicit `mktemp`
  calls in project scripts must still use a TMPDIR template.
- The policy is a regression boundary for this repository's trusted tests, not
  a hostile-code execution service. It allows filesystem reads; it does not
  certify that arbitrary third-party code cannot use every macOS API.
- No real provider requests, package installs, service reloads, permissions
  dialogs, physical monitor movement or recording output are validated here.
  They require separate, explicitly approved acceptance on a real desktop.

Add a refusal/failure fixture before changing a safety contract. Check the exit
status as well as the output: “expected file exists” does not prove the setup
completed. Never make tests pass by swallowing an unexpected command failure.

## Maintenance regression

`maintenance_smoke.sh` also runs `tests/maintenance_test.py` inside the same
boundary. It covers selected-only updates, private stage/quiet preferences,
route drift, ordered multi-operation rollback, failed/partial writes, interrupted
restore retry, user-edit/link/corrupt-image refusal, activation failure, asset
inventory parity, full TOML rejection, literal parser agreement and private
export/import into a fresh HOME. No real desktop activation is part of this drill.

## Desktop compatibility regression

`desktop_compatibility_smoke.sh` checks private diagnostics, literal monitor
patterns, duplicate/unknown identity, main-only refusal before writes, bar
failure status and saved shortcut conflicts. The Lua recording harness executes
the actual module with move/bar/float/resize/start/timeout failure injection.
The quiet-profile harness tests real JetBrains title classification and refuses
implicit CLI or login-setting changes. These are simulated checks, not real
keyboard delivery, hot-plug, sleep/wake, or captured-video acceptance.
