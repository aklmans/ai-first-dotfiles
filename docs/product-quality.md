# Product quality evidence

“Useful for the author”, “passes fixtures” and “ready for other people's Macs”
are different claims. Readiness is a set of evidence gates, not a weighted score.
A strong result in one area cannot compensate for a known data-loss or privacy
problem elsewhere.

For each selected capability, record: revision, starting state, actual command
or observation, expected/actual result, recovery path and remaining limitation.
Label evidence as **fixture**, **maintainer hardware**, **non-author user**, or
**not verified**. A repository review alone is not a usability test.

## Current boundaries — 2026-09-19

| Dimension | Repository evidence / implemented gate | Still not established |
|---|---|---|
| Clear value and choice | README module outcomes; minimal/developer/author-full are choices, not a mandatory stack | Whether new users understand the first useful outcome |
| Onboarding and customization | Preview-first selection/advisor; workspace/display/app preferences are data | Representative clean-Mac and existing-dotfiles journeys on this revision |
| Deployment safety | Copy deploy, linked-ancestor guards, conflict preservation, private operation records and negative-path fixtures | Full legacy ownership reconstruction; guaranteed recovery from abrupt power loss |
| Maintenance and recovery | Selected-only updates, staged TOML checks, guarded rollback, private intent restore rehearsal | User-selected off-device backup and retrieval drill |
| Quiet desktop behavior | Optional automation/diagnostics; no implicit OSD/CLI/login mutations; recording steps stop on failure | Physical dual/single-display transitions, sleep/wake, focus behavior and finished recording quality |
| AI privacy and execution | Local render path; explicit-only text recipients; bounded process groups; failed raw output discarded; unverified stock adapters refuse | Safe stock text-provider integration, deliberately detached children, remote cancellation/billing |
| Compatibility and tests | Bash 3.2 and kernel-isolated clean/author-full fixture suites | More hardware/macOS versions, permission prompts and real service IPC |
| Documentation and support | Start/customize/diagnose/recover paths, issue templates and release checklist | Independent walkthroughs; some screenshots remain stale |
| Adoption and maintenance | Opt-in feedback path; no shipped behavior telemetry | Multi-user retention and contributor sustainability |

These are implementation/evidence locations, not blanket certifications. See
[testing](testing.md), [maintenance coverage](maintenance.md),
[recovery limits](coexisting.md), [AI boundaries](tools/ai-router/safety.md) and
[release checklist](release-checklist.md). Tests use two fixture HOME states on
one machine; they do not become two independent installations.

A release must fix, disable or explicitly exclude unresolved high-risk behavior
in the capabilities it recommends. Optional experimental AI integration should
not hold basic keyboard/window-management improvements hostage, nor inherit
their safety claims.

## Worthwhile remaining work, in order

1. **Saved-work hardware acceptance.** With the maintainer's explicit window:
   dual external → single portable → dual external, sleep/wake, main-only bar/gaps,
   context-local Finder/Preview, IDE dialogs and actual recording output.
   Do not change topology, permissions or recording state during a normal test.
2. **Recoverable private backup.** Pick an off-device destination, preserve the
   private intent bundle there, retrieve it and rehearse restore with the matching
   implementation. An export in the same laptop is not disaster recovery.
3. **Three small external-user journeys.** Include one single-screen user, one
   existing-dotfiles user, and one using different terminal/AI choices. Each:
   understand one outcome → preview → select one module → customize → update →
   leave/uninstall. Record friction with permission; no background recording.
4. **Fresh, narrowly scoped demo.** Replace stale screenshots only after the
   corresponding workflow is verified. Show one small benefit and an exit path,
   not a tour of every app.
5. **Optional AI work only on demand.** If text execution is actually needed,
   validate one text-only adapter and its versions/recipient boundary before
   reopening it. No new chooser, context collector, framework migration or
   provider expansion just to make a roadmap longer.

Notifications database compatibility and energy work likewise need a reproduced
problem or measured use. More configuration switches are not automatically more
choice; an understandable default plus a clear opt-out often suffices.

## Acceptance record

One row per observed environment, linked to the command output or permitted
notes. Keep personal screen names, application inventories and private logs out
of public evidence.

| Date / revision | Evidence class | Starting state / selected modules | Task + observed result | Recovery result | Unresolved / next action |
|---|---|---|---|---|---|
| Fill after observation | fixture / hardware / user | clean, existing or conflict | expected and actual, not just “passed” | tested, refused or not tested | explicit owner/decision |

Earlier documentation reported a 2026-08-01 Parallels single-display installation
with one Homebrew tap-trust interruption. It is historical evidence, not a fresh
acceptance of this revision or of multiple displays. Historical numeric scores
are retained in Git history, not carried forward as current gates.

That history also records failed backup handling, shell-evaluated preferences,
portability errors and tests reaching the live desktop despite green results.
The lesson is to add adversarial behavior tests and independent observations,
not to adjust the score upward after another code review.

## Adoption is separate from correctness

| Stage | Opt-in observation | Question |
|---|---|---|
| Discovery | Aggregate visits/referrals, demo views | Did anyone see the project? |
| Understanding | Ask a new user to explain one outcome | Do they know what it solves? |
| Installation intent | Preview feedback | Do they understand the changes and trust the exit path? |
| Activation | First successful chosen module | How long until something useful happens? |
| Retention | Seven-/thirty-day voluntary feedback | Does it still fit their own habits? |
| Contribution | Issues/PRs and customization attempts | Can they change it without maintaining a full fork? |

No telemetry is installed. Stars/clones do not prove usability, and adding more
features does not solve a discovery problem. Do not infer rejection of the
author's preferences when the evidence may simply be that nobody reached the
first useful outcome.
