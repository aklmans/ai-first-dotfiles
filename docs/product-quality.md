# Product Quality Scorecard

“Works beautifully for the author” and “is a good public product” are different
claims. This scorecard makes the second claim testable. A release-quality change
needs **8.5/10 or higher in every product-controlled dimension**, not merely a
high weighted average that hides one serious weakness.

## Scoring method

Each dimension has five evidence levels:

- **0–2:** absent or harmful
- **3–4:** exists only for the author / undocumented
- **5–6:** usable with expert intervention
- **7–8:** good public path with known friction
- **8.5–9.4:** strong, documented, tested and recoverable
- **9.5–10:** exceptional evidence across multiple machines and users

Scores require links to evidence. “I think this is good” is not evidence. Tests,
dry-run output, task completion observations, issue response time and user
interviews are.

**A score may not be read off the source.** Every number below that later turned
out to be wrong was wrong for the same reason: it was assigned by reading the
repository, by the person who wrote it, on the machine where it already worked.
A dimension is scored from what happened on a machine that was not that one.

## Release gate

| Dimension | Weight | 8.5 evidence gate | Repository evidence |
|---|---:|---|---|
| Value clarity | 8% | one-screen explanation of outcome, audience and non-goals | README outcome/module tables |
| First-run experience | 12% | no-arg safe, list, exact preview, small default, doctor | `setup.sh`, `doctor.sh`, orchestration tests |
| Modularity | 12% | independent outcomes, explicit deps, no hidden paid/closed install | `catalog.sh`, three presets, choice tests |
| Customizability | 10% | common preferences are data; author defaults are optional | `profile.conf`, app routes, theme/display/workspace configs |
| Transparency | 10% | exact packages, writes, costs and permissions before action | package plan + dry-run output |
| Safety / reversibility | 12% | copy deployment, local-edit protection, backups, dry-run uninstall | deploy engine, ledger, uninstaller tests |
| Reliability | 12% | Bash 3.2, idempotence, failure isolation, behavior regression suite | macOS CI and smoke tests |
| Privacy / security | 8% | no private identifiers/secrets; permissions cannot be silently granted | privacy scan and permissions table |
| Documentation / support | 8% | start, customize, diagnose, undo and troubleshoot paths agree | docs index, getting started, troubleshooting |
| Maintenance / community | 8% | contribution contract, changelog, issue template, release checklist | CONTRIBUTING, CHANGELOG, GitHub templates |

The weighted score is useful for trend reporting, but the release gate is the
minimum column: a 9.5 in reliability cannot compensate for a 5 in onboarding.

## Current assessment

Scored 2026-08-01, after a review that ran the whole system against adversarial
inputs and after a first install on a genuinely clean macOS.

**Several of these are lower than the previous version of this table while the
software is better than it was.** The earlier numbers were estimates; these are
what the evidence supports.

| Dimension | Score | Evidence | Why it is not higher |
|---|---:|---|---|
| Value clarity | 7.0 | README module/cost tables | the first screen sells safety and cost, which answers a question nobody has yet; no motion demo |
| First-run experience | 8.0 | clean-VM install, 2026-08-01 | works end to end now, but only after a manual `brew trust`; that step is documented, not automated |
| Modularity | 8.5 | `overlay_scope_smoke.sh`, clean-VM run | adding a module to an installed preset now reaches the runtime, verified on hardware; shared runtime dirs still cannot be removed file-by-file |
| Customizability | 8.0 | `config_injection_smoke.sh` | `displays.conf`/`workspaces.conf` are parsed data; `theme.conf` is still executed as shell |
| Transparency | 8.5 | `--dry-run` output | preview now names the tap-trust requirement it used to omit; it still cannot show macOS permission prompts |
| Safety / reversibility | 8.5 | `deploy_engine_smoke.sh` (103 checks) | the guarantees hold and are tested, including a failed backup; the previous 9.4 was assigned while a silent data-loss path was reachable, so this number needs more machines before it climbs again |
| Reliability | 8.0 | 20 smoke suites, `portability_smoke.sh` | two awk portability bugs and one load-dependent flake shipped past a fully green suite; the suite now scans for both, but "green" has been proven not to mean "correct" |
| Privacy / security | 8.0 | `privacy_scan_smoke.sh`, [privacy](privacy.md) | no telemetry and no secrets, now with the notification module's polling and on-disk titles disclosed; that disclosure was missing while this scored 9.1 |
| Documentation / support | 7.5 | this round's doc corrections | three claims contradicted the code and one contradicted itself; corrected, but the docs have not yet been read by anyone who did not write them |
| Maintenance / community | 8.6 | CONTRIBUTING, CHANGELOG, templates | contracts and checklists exist; contributor volume is still zero |

Weighted readiness: **8.06/10**. Minimum dimension: **7.0/10**.

**This is below the release gate.** Value clarity, Documentation and the three
8.0s are what stand between here and a public recommendation.

### What the previous scores got wrong

Kept deliberately, because the pattern matters more than the numbers.

| Dimension | Was | What was true at the time |
|---|---:|---|
| Safety / reversibility | 9.4 | `backup_target` reported success after a failed `mv`, so a deploy could overwrite a file, leave no backup, exit 0, and write a ledger row pointing at a path that never existed |
| First-run experience | 8.8 | `minimal` could not finish on any clean Mac: Homebrew refuses third-party tap formulae until trusted, and `bar` is half of that preset |
| Customizability | 8.7 | “common preferences are data” — `displays.conf`, `workspaces.conf` and `theme.conf` were sourced as shell, so a monitor name of `$(...)` executed |
| Reliability | 9.1 | `awk -v index=` is a syntax error on macOS awk, and an awk format string said `\\n` where it meant `\n`; both shipped past a green suite |

Every one was wrong in the same direction, and none of them was found by reading
the code more carefully. Three were found by running the system on a machine
that was not the author's; one was found by an adversarial review deliberately
looking for the case the tests did not cover.

## Evidence collected for each release

One row per tested environment.

| Date | macOS / hardware | Starting state | Selected modules | Preview understood? | Time to first outcome | Doctor result | Undo result | Friction / issue |
|---|---|---|---|---|---:|---|---|---|
| 2026-08-01 | macOS guest in Parallels, Apple Silicon, single virtual display | clean install, Homebrew + CLT only | `minimal`, then `notifications`, `terminal` | `list` and `--dry-run` ran with no Homebrew questions asked | 1m03s to a tiled desktop, plus one manual `brew trust` | 6 OK, 2 manual, 0 missing | not yet run | `bar` failed until `brew trust felixkratz/formulae`; the advisor asked its scene question only on a real terminal, not through a pipe |

Still to cover:

1. existing dotfiles with conflicting files and symlinks;
2. `developer` without Warp, BetterTouchTool or notification permission;
3. `author-full` on the maintained three-display desk;
4. uninstall dry-run and apply against a throwaway home;
5. anything with more than one display — the Parallels macOS guest only ever
   offers one, so every multi-display claim still rests on fixtures.

## Adoption is measured separately

Stars and clones do not prove usability, and excellent usability does not
guarantee discovery. Track the funnel without using it to distort the product:

| Funnel stage | Measure | Diagnostic question |
|---|---|---|
| impression | README visits / social views | did anyone see it? |
| understanding | screenshot/demo completion, `list` views | can they explain the outcome? |
| intent | clones / preview runs | did the cost feel acceptable? |
| activation | first successful module/preset | did installation produce value? |
| retention | still used after 7/30 days | did it fit their preferences? |
| contribution | issues, discussions, PRs | could they extend it without forking everything? |

No telemetry is installed by this repository. Collect these only from opt-in
feedback, GitHub's aggregate public signals, or structured user tests.

Measured 2026-07-25: fourteen days of `traffic/views` at zero, `referrers`
empty. Every quality number on this page was, at that point, about software
nobody had seen. Fixing the product does not move that; only distribution does,
and the two are worth tracking apart so neither hides behind the other.

## Current honest boundary

The repository can provide strong evidence for the ten product-controlled gates.
It cannot prove 9.5-level multi-user fit from its own test suite. Before claiming
that level, recruit at least five people who are not using the author's display,
terminal and paid-app choices; record activation time, what they declined, what
they customized and whether they kept it after a week.

The goal is not to persuade them that the author's preferences are best. The
goal is for each person to reach the same useful outcome through choices they
understand and own.
