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

## Provisional repository assessment

This is a code-and-documentation readiness score, pending the complete local/CI
test run. It is not evidence of adoption or multi-user retention.

| Dimension | Score | Why it is not 10 |
|---|---:|---|
| Value clarity | 8.6 | outcome is clear; a short motion demo is still missing |
| First-run experience | 8.8 | safe list/preview/doctor; permissions still require macOS UI work |
| Modularity | 8.7 | public capabilities compose; shared runtime directories cannot be removed file-by-file |
| Customizability | 8.7 | common choices are data; advanced built-in routing still needs code changes |
| Transparency | 9.3 | exact packages, paths, costs and permissions are previewed |
| Safety / reversibility | 9.4 | strong copy/ledger guarantees; Homebrew package removal stays manual by design |
| Reliability | 9.1 | broad Bash 3.2 regression suite; hardware/UI permissions cannot be fully simulated |
| Privacy / security | 9.1 | automated scan and no telemetry; notification metadata access still needs broad FDA |
| Documentation / support | 8.8 | full decision-to-undo path; limited real-user support evidence |
| Maintenance / community | 8.6 | contracts/checklists exist; contributor volume is not yet proven |

Weighted readiness: **8.98/10**. Minimum dimension: **8.6/10**. These numbers
must be lowered if the stated evidence fails; they should rise above 9.5 only
after repeatable external-user evidence exists.

## Evidence collected for each release

Create one row per tested environment:

| Date | macOS / hardware | Starting state | Selected modules | Preview understood? | Time to first outcome | Doctor result | Undo result | Friction / issue |
|---|---|---|---|---|---:|---|---|---|
| — | — | clean / existing dotfiles | — | — | — | — | — | — |

At minimum, test:

1. clean Apple Silicon laptop with one display and `minimal`;
2. existing dotfiles with conflicting files/symlinks;
3. `developer` without Warp, BetterTouchTool or notification permission;
4. `author-full` on the maintained three-display desk;
5. uninstall dry-run and apply against a throwaway home.

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

## Current honest boundary

The repository can provide strong evidence for the ten product-controlled gates.
It cannot prove 9.5-level multi-user fit from its own test suite. Before claiming
that level, recruit at least five people who are not using the author's display,
terminal and paid-app choices; record activation time, what they declined, what
they customized and whether they kept it after a week.

The goal is not to persuade them that the author's preferences are best. The
goal is for each person to reach the same useful outcome through choices they
understand and own.
