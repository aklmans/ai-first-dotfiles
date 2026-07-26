# AI Workflow Router Roadmap

Last updated: 2026-04-28

This document is for future work on the local AI Workflow Router at:

- `~/.config/ai-router/`
- `~/.hammerspoon/ai_hotkeys.lua`
- Karabiner profile: `CapsLock AI Lite`

The goal is not to make another AI launcher. The goal is an intent-first workflow layer:

```text
User intent / selected text
  -> stable CapsLock shortcut
  -> prompt / snippet / skill / plugin selection
  -> optional provider or coding agent
  -> clipboard / file / preview / terminal
```

## Current State

The MVP is usable.

Working behavior:

- `CapsLock + A/S/T/E/W/F/X/R/G/D/Y/=` renders a prompt and copies it to the clipboard.
- `CapsLock + C` opens the coding agent chooser.
- `CapsLock + Space` opens the AI Router palette, but the experience is still slower than direct hotkeys.
- Agent chooser can open Warp and paste Codex, Claude, Kimi, Gemini, Junie commands.
- Provider execution is available through `ai-router.sh run <prompt>`, through a pipe (`git diff | ai-router.sh run commit-message`), and through the explicit `Hyper + Shift` gesture. The plain `Hyper + letter` gesture still only renders.
- Prompt files live in `~/.config/ai-router/prompts/`.
- Providers live in `~/.config/ai-router/providers/`.
- Catalogs are generated under `${XDG_STATE_HOME:-~/.local/state}/ai-router/catalogs/`, including `hotkeys.json`, `palette.json`, `prompts.json`, and `agents.json`.
- `ai-router.sh palette` reads `catalogs/palette.json`; dynamic scanning is now only a cache-miss fallback.
- `ai-router.sh export-snippets all` exports static prompt/snippet packs for Raycast and future external UIs.
- Raycast snippet export uses short `;` + 2-3 letter keywords such as `;sm`, `;tr`, `;ex`, `;mt`.
- Hammerspoon chooser now presents grouped titles, recent/pinned status, wider rows, and condensed metadata preview.
- Logs and cache are under `${XDG_STATE_HOME:-~/.local/state}/ai-router/`. Only configuration lives in `~/.config/ai-router/`.

Important implementation facts:

- Hammerspoon currently owns the user-facing AI hotkeys.
- Karabiner only emits stable Hyper events and direct launch events.
- `config.json` is now the source of truth for agent labels, commands, and behaviors.
- Prompt metadata and direct prompt hotkeys now come from prompt frontmatter and generated catalogs.
- Hammerspoon reads `catalogs/hotkeys.json`, `catalogs/palette.json`, and `catalogs/agents.json`, with static fallbacks only for recovery.
- Remaining duplication: shell list commands still build dynamic TSV output for direct inspection, but the palette path is cached.

## Non-Negotiable Design Rules

Keep these invariants unless the user explicitly decides otherwise:

1. `CapsLock + letter` should be fast and should render a prompt to clipboard, not call a slow provider.
2. Provider execution is bound to an explicit second gesture, never to the default one. Decided in 2.4.0: holding a left-side modifier on top of Hyper (Karabiner emits Hyper on the right side, so `Hyper + left Shift` or `Hyper + left Cmd` is a signal Hyper cannot produce by itself) runs the prompt through a provider; `Shift + Enter` does the same from the palette. Both announce "Running ...", then show the answer or the failure. The original concern still stands - a provider call with no feedback is opaque - so a run that cannot say what it is doing does not ship, and any ambiguity in the modifier state must fall back to render. Do not make provider execution the default gesture, and do not add a third one without deciding it here first.
3. Karabiner must not call AI APIs or run complex logic.
4. Do not auto-replace selected text by default. Replacement must be explicit and guarded.
5. Do not log full selection, full prompt, full clipboard, or full output.
6. Do not auto-execute terminal agents from the chooser unless the shortcut explicitly says so.
7. Do not reintroduce skhd/yabai into this workflow.
8. Do not make `CapsLock + Space` the only path. Direct hotkeys must remain first-class.
9. Any change to `~/.config/karabiner/karabiner.json` must be backed up first.
10. Any Hammerspoon change must be followed by `hs -c 'hs.reload()'`.
11. Static prompt/snippet reuse should be delegated to Raycast/HapiGo or the future Mac App when possible.

## Review Follow-Up Status

The external review was directionally right: the core idea is valuable, but Hammerspoon chooser should not become the final product surface.

Resolved or mostly resolved:

- Single source of truth for prompt hotkeys: prompt frontmatter -> `catalogs/hotkeys.json` -> Hammerspoon.
- Single source of truth for agents: `config.json` -> `catalogs/agents.json` / `ai-router.sh agent-menu`.
- Selected-text read performance: adaptive clipboard polling plus `selection_ms`, `selection_source`, and `input_source` logs.
- Provider reliability: timeout wrapper, provider health checks, multi-provider fallback chain, explicit error logs.
- Prompt/snippet retrieval: aliases, keywords, favorites, recent usage, cached palette data.
- Static reuse path: Raycast snippet export with short `;` keywords.
- Backup hygiene: long-lived local backup piles under `~/.config` were removed.
- Terminal abstraction: agent launching reads `terminal.app` from `config.json`, with native paths for Terminal.app and iTerm2, a generic new-tab path for Warp/Ghostty/Kaku, and a clipboard fallback when no terminal can be driven.
- Usable without the desktop: piped stdin, `--from`, `doctor`, `show`, and conditional macOS dependencies, so the CLI runs over SSH and on Linux.
- Runtime data lives in the XDG state directory instead of `~/.config`.

Still worth improving:

- Template expressiveness: defaults, simple conditionals, and optional includes.
- Runtime context: browser URL/title, repo/project path, and active file path, with strict privacy limits.
- Modularization: split context/provider/terminal/export code once behavior stabilizes.
- External UI: evaluate Raycast snippets first; design a dedicated Mac App only after the data model is proven.

No longer recommended:

- Do not invest heavily in Hammerspoon chooser as a Raycast replacement.
- Do not restore *hidden* provider execution. The 2.4.0 `Hyper + Shift` gesture is the opposite: documented, announced while it runs, and it reports its result.
- Do not make provider output replace selected text by default.

## Roadmap

### P0 - Stabilize The Existing MVP

Do these before adding more features.

1. Create a small test suite.
   - Basic tests now live in `tests/`.
   - Covered: prompt rendering, catalog generation, provider fallback, usage/favorites state.
   - Run with `bash ~/.config/ai-router/tests/run.sh`.

2. Make `config.json` real or remove it.
   - Agent command definitions now come from `config.json`.
   - `ai-router.sh agent-menu` returns Hammerspoon-compatible agent rows.
   - Prompt hotkey metadata now comes from prompt frontmatter and `catalogs/hotkeys.json`.
   - `ai-router.sh palette` now reads `catalogs/palette.json` instead of rebuilding TSV dynamically.

3. Keep provider timeouts and fallback chains reliable.
   - Provider calls can hang.
   - Timeout is configurable with `AI_ROUTER_PROVIDER_TIMEOUT_SECONDS=60`.
   - A timeout should return exit code `71` and a clear notification.
   - Execution failure should continue to the next configured fallback provider.

4. Improve selection-read failure handling.
   - Adaptive clipboard polling is implemented for faster selected-text reads.
   - `logs/events.jsonl` records `input_source`, `selection_source`, `selection_ms`, and `selection_attempts`.
   - Clipboard fallback is now visible in notifications as `clipboard input`.
   - Opt-in strict mode is available with `AI_ROUTER_SELECTION_STRICT=1`.
   - Remaining work: tune per-app delays if specific apps still copy slowly.

5. Normalize backup management.
   - Historical backup files under `~/.config` were cleaned by request on 2026-04-28.
   - Future live edits should still create a temporary backup first when risk is meaningful.
   - After validation, remove temporary backups instead of keeping long-lived backup piles.

6. Keep the palette fast.
   - `CapsLock + Space` must not scan skills/plugins dynamically on every invocation.
   - Hammerspoon and CLI palette now read cached catalogs first.

Acceptance checks:

```bash
bash -n ~/.config/ai-router/ai-router.sh
python3 -m py_compile ~/.config/ai-router/lib/router_tools.py
AI_ROUTER_SELECTION='hello world' ~/.config/ai-router/ai-router.sh render summarize
AI_ROUTER_SELECTION='hello world' AI_ROUTER_DRY_RUN=1 ~/.config/ai-router/ai-router.sh run summarize
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh list providers
bash ~/.config/ai-router/tests/run.sh
hs -c 'return "hammerspoon ok"'
```

### P1 - Make Prompt / Snippet / Skill Retrieval Excellent

This is the main product opportunity. The system should help find the right prompt, skill, snippet, or plugin faster than manually searching files.

1. Promote prompt metadata quality.
   - Every prompt now has `id`, `title`, `description`, provider defaults, input/output behavior, aliases, keywords, and tags.
   - Tags and keywords now match real retrieval use: writing, coding, debugging, translation, research, prompt engineering, and common Chinese search terms.

2. Add prompt aliases and keywords.
   - Prompt and snippet catalogs now include `keywords`.
   - Chooser subText and searchText include aliases, keywords, and tags.
   - Existing prompts and snippets have been enriched with Chinese, English, abbreviation, and scenario aliases.

3. Build a better catalog index.
   - Catalogs now include `aliases`, `tags`, category, hotkey, provider metadata, and searchable text.
   - Hammerspoon palette now reads `catalogs/palette.json`.
   - Usage stats, favorites, and recent ranking are now backed by `state/usage.json` and `state/favorites.json`.
   - Hammerspoon chooser now shows grouped titles, pinned/recent status, and condensed metadata previews.
   - Remaining work: add `mtime`, richer preview UI outside Hammerspoon, and smarter context-aware ranking.

4. Add snippet and skill quick-copy workflow.
   - Direct prompt hotkeys already work.
   - Snippets now have searchable frontmatter metadata and appear in the cached palette.
   - Static prompts/snippets can be exported to Raycast snippets with short keywords.
   - Remaining work: import Raycast snippets and evaluate whether Hammerspoon snippet retrieval is still needed.

5. Add favorites/recent ranking.
   - `state/favorites.json` stores manually pinned items.
   - `state/usage.json` stores count and last-used metadata.
   - Hammerspoon shows favorites first, then recent/common items.
   - Hammerspoon displays `Pinned / ...` and `Recent / ...` in the chooser title, with relative last-used time in subText.
   - Keep direct hotkeys for the most frequent actions.

Acceptance checks:

```bash
~/.config/ai-router/ai-router.sh index
jq '.[] | {name,title,tags}' ~/.config/ai-router/catalogs/prompts.json
~/.config/ai-router/ai-router.sh palette | head
~/.config/ai-router/ai-router.sh favorite list
```

### P1.5 - Observability And Debugging

1. Keep error access one command away.
   - Provider failures write full diagnostics to `logs/errors/<request_id>.log`.
   - The latest failure is mirrored to `logs/errors/latest.log`.
   - `ai-router.sh tool last-error` opens the latest error file.

2. Keep lightweight tests green before larger refactors.
   - `tests/test_render.sh`
   - `tests/test_index.sh`
   - `tests/test_provider_fallback.sh`
   - `tests/test_state.sh`

Acceptance checks:

```bash
bash ~/.config/ai-router/tests/run.sh
~/.config/ai-router/ai-router.sh tool last-error
```

### P2 - Provider And Agent Layer

Providers should be predictable. Agents should be launched reliably without surprising execution.

1. Define provider contract.
   - `provider.sh --health-check`
   - stdin receives prompt
   - stdout returns model output
   - stderr returns diagnostics
   - exit `64` usage, `69` unavailable, `70` failed, `71` timeout

2. Support provider fallback chains.
   - Current frontmatter may use `fallback_provider` or `fallback_providers`.
   - Target: make provider chain fully driven by config/frontmatter.
   - Example: `gemini -> kimi -> claude`.

3. Add explicit provider UI only if it solves history and preview.
   - Removed hidden `CapsLock + Cmd + key` provider execution.
   - A future provider chooser must show what will run, where output went, and recent history.
   - This should be optional and must not slow down direct render hotkeys.

4. Improve Warp launch reliability.
   - Keep paste-only by default.
   - Keep execute mode only for explicit direct-launch shortcuts.
   - Consider reading terminal app from config:
     - `Warp`
     - future possible: `Kaku`, `iTerm2`

5. Treat coding agents differently from text providers.
   - Codex CLI, Claude Code, Junie, and Warp Agent are long-running agents.
   - They should normally open an interactive session, not be used as fast text providers.

Acceptance checks:

```bash
~/.config/ai-router/providers/kimi.sh --health-check
~/.config/ai-router/providers/gemini.sh --health-check
AI_ROUTER_SELECTION='summarize this' ~/.config/ai-router/ai-router.sh run summarize
~/.config/ai-router/ai-router.sh agent codex
~/.config/ai-router/ai-router.sh agent-run codex
```

### P3 - Context Capture

Better prompts need better context, but privacy must stay strict.

Potential context fields:

- selected text
- clipboard text
- frontmost app
- window title
- browser URL if frontmost app is a browser
- Warp current working directory if accessible
- JetBrains project path / active file if accessible
- Finder selected paths

Implementation rules:

- Add fields only when useful to prompts.
- Do not log full context.
- Make each context source independently optional.
- If a context source is slow, cache it or do not include it in direct hotkey paths.

Suggested template variables:

```text
{{selection}}
{{clipboard}}
{{frontmost_app}}
{{window_title}}
{{browser_url}}
{{terminal_cwd}}
{{project_path}}
{{file_path}}
{{date}}
```

### P4 - Template Engine

Current template rendering is simple string replacement. That is fine for MVP, but limited.

Add only when real prompt needs appear:

- default values
- conditional sections
- escaping literal braces
- optional include snippets

Preferred path:

- Keep `router_tools.py` as the renderer.
- Avoid adding heavy dependencies unless necessary.
- If a real template engine is added, choose one and test it.

Potential syntax:

```text
{{selection}}
{{clipboard}}
{{#if browser_url}}
Current URL: {{browser_url}}
{{/if}}
```

### P5 - Modularization

Do this after tests exist.

Potential split:

```text
~/.config/ai-router/
  ai-router.sh
  lib/
    router_tools.py
    config.py
    catalogs.py
    providers.py
    templates.py
    privacy.py
  providers/
  prompts/
  snippets/
  tests/
```

Keep the public CLI stable while refactoring:

```bash
ai-router.sh render <prompt>
ai-router.sh run <prompt>
ai-router.sh agent <name>
ai-router.sh agent-run <name>
ai-router.sh list prompts|providers|agents
ai-router.sh index
ai-router.sh tool <name>
```

## Open Decisions

These need user decisions before implementation:

1. After importing Raycast snippets, should `CapsLock + Space` remain in Hammerspoon or be reduced to a fallback/debug palette?
2. Should provider output ever auto-replace selected text?
3. Should Kaku become the default terminal target for agent launching, or should Warp remain the launcher for agent sessions?
4. Should generated catalogs/exports be tracked in the dotfile repository or generated during install?
5. Should text providers include Claude/Codex, or should those remain interactive coding agents only?
6. How much browser / IDE context is acceptable from a privacy standpoint?
7. What should the future Mac App own: catalog browsing only, snippet expansion, provider execution, or full history?

## Suggested Next Sprint

Recommended sequence for the next Agent:

1. Import `exports/raycast-snippets.json` into Raycast and evaluate daily use.
2. Get a sample HapiGo `.hasnp` export if HapiGo import support is still desired.
3. Design the future Mac App data model around the generic `exports/ai-router-snippets.json`.
4. Add a minimal template upgrade: default values and simple conditionals before any larger engine.
5. Decide whether to reduce or remove Hammerspoon chooser scope after Raycast snippet import.
6. Move terminal agent launching behind a config-driven `terminal` setting.
7. Tune selected-text copy behavior for any app-specific failures discovered in daily use.
8. Add context-aware ranking after enough usage data exists.
9. Update README after each behavior change.

Do not start with a rewrite. The current MVP works; preserve the user experience while reducing duplication.

## Prompt For The Next Agent

Use this as a handoff prompt:

```text
You are continuing work on the local AI Workflow Router.

Important paths:
- ~/.config/ai-router/
- ~/.config/ai-router/README.md
- ~/.config/ai-router/ROADMAP.md
- ~/.hammerspoon/ai_hotkeys.lua
- ~/.config/karabiner/karabiner.json

Read README.md and ROADMAP.md first. Verify current code before acting; older review notes were removed because they were partly stale.

Rules:
- Preserve the current user-facing shortcuts.
- CapsLock + letter renders prompt to clipboard and must stay fast.
- Provider calls are explicit commands or future external UI actions; do not reintroduce CapsLock + Cmd + letter provider hotkeys.
- Karabiner should remain a stable key emitter, not a business-logic layer.
- Back up karabiner.json before changing it.
- Do not log full selection, prompt, clipboard, or output.
- Do not auto-execute agent commands unless the specific command is explicitly designed to do so.
- Do not reintroduce skhd/yabai.

Start with one roadmap item only. Prefer P0 tasks:
1. Import `~/.config/ai-router/exports/raycast-snippets.json` into Raycast and validate the short-keyword workflow.
2. Add a minimal template upgrade: default values and simple conditionals.
3. Move agent terminal launching behind config, preserving paste-only behavior by default.
4. Reduce Hammerspoon chooser scope if Raycast snippets cover static prompt/snippet use.
5. Tune selected-text read behavior for specific apps if failures are reported.

Before editing, inspect the current files and run baseline validation:

bash -n ~/.config/ai-router/ai-router.sh
python3 -m py_compile ~/.config/ai-router/lib/router_tools.py
AI_ROUTER_SELECTION='hello world' ~/.config/ai-router/ai-router.sh render summarize
AI_ROUTER_SELECTION='hello world' AI_ROUTER_DRY_RUN=1 ~/.config/ai-router/ai-router.sh run summarize
~/.config/ai-router/ai-router.sh index
hs -c 'return "hammerspoon ok"'

After editing, rerun relevant validation. If Hammerspoon changes, reload it with:

hs -c 'hs.reload()'

Report:
- files changed
- behavior changed
- validation commands run
- remaining risks
```
