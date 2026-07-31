# Release Checklist

## Product gate

- [ ] Every dimension in [Product quality](product-quality.md) has current evidence and scores at least 8.5.
- [ ] `minimal`, `developer` and `author-full` previews match the catalog.
- [ ] Paid, closed-source, account and permission requirements are visible before install.
- [ ] The README screenshots represent the current UI; add a short keyboard-to-outcome demo when available.

## Verification

- [ ] All `tests/smoke/*.sh` pass under macOS Bash 3.2.
- [ ] AI router tests pass.
- [ ] Repository author preset preserves the 13-workspace display and app-routing constraints.
- [ ] `minimal --deploy-only` works in a throwaway HOME and creates no symlink.
- [ ] Uninstall dry-run is reviewed against the same throwaway HOME.
- [ ] Live config is inspected separately; no release test silently deploys repository config into it.

## Communication

- [ ] CHANGELOG explains user-visible choices and upgrade behavior.
- [ ] Getting started, choice architecture, troubleshooting and commands agree.
- [ ] Release notes lead with user outcomes, not file counts.
- [ ] No push, tag or GitHub release occurs without an explicit maintainer decision.

## Post-release learning

- [ ] Ask at least five non-author users which modules they declined and why.
- [ ] Record time to first useful outcome and seven-day retention, without shipping telemetry.
- [ ] Convert repeated confusion into a documentation/test issue; do not automatically add it to a larger default.
