# AI Workflow Router - Design Notes

Last updated: 2026-07-26

This is the "why it is built this way" document for the AI Workflow Router. The
short forward-looking list lives in `home/.config/ai-router/ROADMAP.md`; usage
lives in `home/.config/ai-router/README.md`.

Files this covers:

- `home/.config/ai-router/`
- `home/.hammerspoon/ai_hotkeys.lua`
- Karabiner profile: `CapsLock AI Lite`

The goal is not another AI launcher. The goal is an intent-first workflow layer:

```text
User intent / selected text
  -> stable CapsLock shortcut
  -> prompt / snippet / skill / plugin selection
  -> optional provider or coding agent
  -> clipboard / file / preview / terminal
```

## Current state

Working behavior:

- `CapsLock + A/S/T/E/W/F/X/R/G/D/Y/=` renders a prompt and copies it to the clipboard.
- `CapsLock + C` opens the coding agent chooser.
- `CapsLock + Space` opens the router palette, though it is still slower than a direct hotkey.
- The agent chooser can open a terminal and paste Codex, Claude, Kimi, Gemini or Junie commands.
- Provider execution is available through `ai-router.sh run <prompt>`, through a pipe (`git diff | ai-router.sh run commit-message`), and through the explicit `Hyper + Shift` gesture. Plain `Hyper + letter` still only renders.
- Prompts live in `prompts/`, with an optional second language set in `prompts/zh/`. The router globs the top level only, so a language subdirectory is inert until its files are copied up.
- Providers live in `providers/`.
- Catalogs are generated under `${XDG_STATE_HOME:-~/.local/state}/ai-router/catalogs/`: `hotkeys.json`, `palette.json`, `prompts.json`, `agents.json`.
- `ai-router.sh palette` reads `catalogs/palette.json`; dynamic scanning is only a cache-miss fallback.
- `ai-router.sh export-snippets all` exports static prompt and snippet packs for Raycast and future external UIs.
- The Raycast export uses short `;` + 2-3 letter keywords such as `;sm`, `;tr`, `;ex`, `;mt`.
- The Hammerspoon chooser shows grouped titles, recent/pinned status, wider rows and condensed metadata previews.
- Logs and cache live under `${XDG_STATE_HOME:-~/.local/state}/ai-router/`. Only configuration lives in `~/.config/ai-router/`.

Implementation facts worth knowing before changing anything:

- Hammerspoon owns the user-facing AI hotkeys.
- Karabiner only emits stable Hyper events and direct launch events.
- `config.json` is the source of truth for agent labels, commands and behaviors.
- Prompt metadata and direct prompt hotkeys come from prompt frontmatter and the generated catalogs.
- Hammerspoon reads `catalogs/hotkeys.json`, `catalogs/palette.json` and `catalogs/agents.json`, with static fallbacks only for recovery.
- Remaining duplication: the shell list commands still build TSV dynamically for direct inspection, while the palette path is cached.

## Non-negotiable design rules

Keep these invariants unless there is an explicit decision to change one.

1. `CapsLock + letter` must be fast and must render a prompt to the clipboard, not call a slow provider.
2. Provider execution is bound to an explicit second gesture, never to the default one. Decided in 2.4.0: holding a left-side modifier on top of Hyper (Karabiner emits Hyper on the right side, so `Hyper + left Shift` or `Hyper + left Cmd` is a signal Hyper cannot produce by itself) runs the prompt through a provider; `Shift + Enter` does the same from the palette. Both announce "Running ...", then show the answer or the failure. The original concern still stands - a provider call with no feedback is opaque - so a run that cannot say what it is doing does not ship, and any ambiguity in the modifier state must fall back to render. Do not make provider execution the default gesture, and do not add a third one without deciding it here first.
3. Karabiner must not call AI APIs or run complex logic.
4. Do not auto-replace selected text by default. Replacement must be explicit and guarded.
5. Do not log the full selection, prompt, clipboard or output.
6. Do not auto-execute terminal agents from the chooser unless the shortcut explicitly says so.
7. Do not reintroduce skhd/yabai into this workflow.
8. Do not make `CapsLock + Space` the only path. Direct hotkeys stay first-class.
9. Any change to `karabiner.json` is backed up first.
10. Any Hammerspoon change is followed by `hs -c 'hs.reload()'`.
11. Static prompt and snippet reuse should be delegated to Raycast, HapiGo or a future Mac app where possible.

## What the design deliberately rejects

- Do not invest heavily in the Hammerspoon chooser as a Raycast replacement. It is a fallback surface, not the product.
- Do not restore *hidden* provider execution. The 2.4.0 `Hyper + Shift` gesture is the opposite of hidden: documented, announced while it runs, and it reports its result.
- Do not make provider output replace the selection by default.

## Review follow-up

An external review landed on the right conclusion: the core idea is valuable, but
the Hammerspoon chooser should not become the final product surface.

Resolved or mostly resolved:

- Single source of truth for prompt hotkeys: prompt frontmatter -> `catalogs/hotkeys.json` -> Hammerspoon.
- Single source of truth for agents: `config.json` -> `catalogs/agents.json` / `ai-router.sh agent-menu`.
- Selection read performance: adaptive clipboard polling plus `selection_ms`, `selection_source` and `input_source` logging.
- Provider reliability: timeout wrapper, health checks, multi-provider fallback chain, explicit error logs.
- Prompt and snippet retrieval: aliases, keywords, favorites, recent usage, cached palette data.
- Static reuse path: Raycast snippet export with short `;` keywords.
- Terminal abstraction: agent launching reads `terminal.app` from `config.json`, with native paths for Terminal.app and iTerm2, a generic new-tab path for Warp/Ghostty/Kaku, and a clipboard fallback when no terminal can be driven.
- Usable without the desktop: piped stdin, `--from`, `doctor`, `show` and conditional macOS dependencies, so the CLI runs over SSH and on Linux.
- Runtime data lives in the XDG state directory instead of `~/.config`.

Still rough:

- Template expressiveness: defaults, simple conditionals, optional includes.
- Runtime context: browser URL/title, repo or project path, active file path - all under strict privacy limits.
- Modularization: split the context/provider/terminal/export code once behavior stabilizes.
- External UI: evaluate Raycast snippets first; design a dedicated Mac app only after the data model is proven.
- Generated exports (`exports/*.json`) are checked in and diffed by a smoke test, so editing a snippet without re-exporting turns the test red. Generating them at install time instead would remove the trap.

## Design areas and status

### Stabilize the MVP

1. A small test suite exists.
   - Tests live in `tests/`.
   - Covered: prompt rendering, catalog generation, provider fallback, usage/favorites state.
   - Run with `bash ~/.config/ai-router/tests/run.sh`.

2. `config.json` is real, not decoration.
   - Agent command definitions come from it.
   - `ai-router.sh agent-menu` returns Hammerspoon-compatible agent rows.
   - Prompt hotkey metadata comes from prompt frontmatter and `catalogs/hotkeys.json`.
   - `ai-router.sh palette` reads `catalogs/palette.json` instead of rebuilding TSV on every call.

3. Provider timeouts and fallback chains stay reliable.
   - Provider calls can hang; the timeout is configurable with `AI_ROUTER_PROVIDER_TIMEOUT_SECONDS=60`.
   - A timeout returns exit code `71` with a clear notification.
   - An execution failure continues to the next configured fallback provider.

4. Selection-read failures degrade gracefully.
   - Adaptive clipboard polling makes selection reads faster.
   - `logs/events.jsonl` records `input_source`, `selection_source`, `selection_ms` and `selection_attempts`.
   - Clipboard fallback is visible in the notification as `clipboard input`.
   - Strict mode is opt-in with `AI_ROUTER_SELECTION_STRICT=1`.
   - Open: per-app delay tuning for apps that still copy slowly.

5. The palette stays fast.
   - `CapsLock + Space` must not scan skills and plugins on every invocation.
   - Both Hammerspoon and the CLI read cached catalogs first.

Validation:

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

### Retrieval

Finding the right prompt, snippet, skill or plugin faster than searching files by
hand is the main product opportunity.

1. Prompt metadata quality.
   - Every prompt carries `id`, `title`, `description`, provider defaults, input/output behavior, aliases, keywords and tags.
   - Tags and keywords are chosen for retrieval, not decoration: writing, coding, debugging, translation, research, prompt engineering.

2. Aliases and keywords.
   - Prompt and snippet catalogs include `keywords`.
   - Chooser subText and searchText include aliases, keywords and tags.

3. The catalog index.
   - Catalogs include aliases, tags, category, hotkey, provider metadata and searchable text.
   - Usage stats, favorites and recent ranking are backed by `state/usage.json` and `state/favorites.json`.
   - Open: `mtime`, a richer preview UI outside Hammerspoon, context-aware ranking.

4. Snippet and skill quick-copy.
   - Direct prompt hotkeys work.
   - Snippets have searchable frontmatter and appear in the cached palette.
   - Static prompts and snippets export to Raycast with short keywords.
   - Open: importing Raycast snippets, and deciding whether Hammerspoon snippet retrieval is still needed afterwards.

5. Favorites and recent ranking.
   - `state/favorites.json` stores pinned items, `state/usage.json` stores count and last-used metadata.
   - Hammerspoon shows favorites first, then recent and frequent items, with relative last-used time in subText.
   - Direct hotkeys stay for the most frequent actions.

Validation:

```bash
~/.config/ai-router/ai-router.sh index
jq '.[] | {name,title,tags}' "${XDG_STATE_HOME:-$HOME/.local/state}/ai-router/catalogs/prompts.json"
~/.config/ai-router/ai-router.sh palette | head
~/.config/ai-router/ai-router.sh favorite list
```

### Observability

1. Errors stay one command away.
   - Provider failures write full diagnostics to `logs/errors/<request_id>.log`.
   - The latest failure is mirrored to `logs/errors/latest.log`.
   - `ai-router.sh tool last-error` opens it.

2. The lightweight tests stay green before any larger refactor.
   - `tests/test_render.sh`, `tests/test_index.sh`, `tests/test_provider_fallback.sh`, `tests/test_state.sh`.

### Providers and agents

Providers should be predictable. Agents should launch reliably without surprising
execution.

1. Provider contract.
   - `provider.sh --health-check`
   - stdin receives the prompt
   - stdout returns model output
   - stderr returns diagnostics
   - exit `64` usage, `69` unavailable, `70` failed, `71` timeout

2. Provider fallback chains.
   - Frontmatter may use `fallback_provider` or `fallback_providers`.
   - Target: a chain fully driven by config and frontmatter, e.g. `gemini -> kimi -> claude`.

3. An explicit provider UI only if it solves history and preview.
   - The hidden `CapsLock + Cmd + key` provider execution was removed.
   - A future provider chooser must show what will run, where the output went, and recent history.
   - It must be optional and must not slow the direct render hotkeys.

4. Terminal launch reliability.
   - Paste-only by default.
   - Execute mode only for explicit direct-launch shortcuts.
   - The terminal is read from `terminal.app` in `config.json`.

5. Coding agents are not text providers.
   - Codex CLI, Claude Code, Junie and Warp Agent are long-running agents.
   - They should open an interactive session, not be used as fast text providers.

Validation:

```bash
~/.config/ai-router/providers/claude.sh --health-check
~/.config/ai-router/providers/codex.sh --health-check
AI_ROUTER_SELECTION='summarize this' ~/.config/ai-router/ai-router.sh run summarize
~/.config/ai-router/ai-router.sh agent codex
~/.config/ai-router/ai-router.sh agent-run codex
```

### Context capture

Better prompts need better context, but privacy stays strict.

Candidate context fields:

- selected text
- clipboard text
- frontmost app
- window title
- browser URL when the frontmost app is a browser
- terminal working directory when accessible
- IDE project path or active file when accessible
- Finder selection

Rules for adding one:

- Add a field only when a prompt actually needs it.
- Never log the full context.
- Every context source is independently optional.
- A slow context source is cached, or kept out of the direct hotkey path.

Template variables, current and proposed:

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

### Template engine

Rendering is plain string replacement today. That is fine for the current prompts
and limited beyond them.

Add only when a real prompt needs it:

- default values
- conditional sections
- escaping literal braces
- optional included snippets

Preferred path: keep `router_tools.py` as the renderer and avoid heavy
dependencies. If a real template engine is ever added, pick one and test it.

Possible syntax:

```text
{{selection}}
{{clipboard}}
{{#if browser_url}}
Current URL: {{browser_url}}
{{/if}}
```

### Modularization

Only after the tests exist and behavior has settled.

Possible split:

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

The public CLI stays stable through any refactor:

```bash
ai-router.sh render <prompt>
ai-router.sh run <prompt>
ai-router.sh agent <name>
ai-router.sh agent-run <name>
ai-router.sh list prompts|providers|agents
ai-router.sh index
ai-router.sh tool <name>
```

A rewrite is not the starting point. The current implementation works; the job is
to reduce duplication without changing the experience.
