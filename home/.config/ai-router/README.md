# AI Workflow Router

**2.5 safety gate:** the default workflow is render → review → use your chosen
client. Text execution requires an explicit per-request recipient and a reviewed
adapter. All prebuilt text adapters are currently quarantined; installing a CLI
does not enable them. See `docs/tools/ai-router/safety.md` in the repository for
the complete contract, limits and migration notes.

AI Workflow Router is the layer above CapsLock AI Lite. It is not organized around
"which AI tool do I open" but around "which piece of work am I trying to finish".

Call chain:

```text
CapsLock Hyper
  -> Karabiner emits a stable global shortcut
  -> Hammerspoon receives the shortcut and shows the menu
  -> ai-router.sh collects context, renders the prompt, picks a provider
  -> Provider / Agent / Clipboard / Output file
```

Karabiner is not modified by this layer.

## Shortcuts

| Shortcut | Behavior |
|---|---|
| CapsLock + Space | AI command palette, served from a cached catalog |
| CapsLock + A/S/T/E/W/F/X/R/G/D | Render that prompt with the selection embedded, copy it to the clipboard |
| CapsLock + Y | Render `translate-to-en` and translate the selection into English |
| CapsLock + = | Render `optimize-prompt` and sharpen the selected prompt |
| CapsLock + C | Coding agent menu |
| CapsLock + Shift + the same letter | Legacy run gesture; currently refuses without per-request recipient selection |

The agent menu opens a new tab in whichever terminal `terminal.app` names in
`config.json` and pastes the command. It does not run it.

Calling a provider is an explicit second gesture, never the default:

- `CapsLock + letter` only ever renders the prompt to the clipboard. Fast, predictable, free.
- `CapsLock + Shift + letter` requests execution but currently refuses: the GUI has no per-request recipient selection yet.
- In the palette, `Enter` copies; `Shift + Enter` has the same execution gate.

How the two are told apart: Karabiner emits Hyper as the four **right-side**
modifiers, so holding any **left-side** modifier on top of it is a signal Hyper
cannot produce by itself. Left Shift and left Cmd both work (left thumb on left
Cmd is usually the easiest reach). If the modifier state cannot be read, the
router falls back to `render` - it will never spend a model call because it could
not decide.

## Direct launch layer

`CapsLock + Ctrl + initial` is a Karabiner direct-launch layer. It does not go
through the Hammerspoon menu.

| Shortcut | Behavior |
|---|---|
| CapsLock + Ctrl + W | Open Warp |
| CapsLock + Ctrl + I | Open IntelliJ IDEA |
| CapsLock + Ctrl + G | Open GoLand |
| CapsLock + Ctrl + X | Open Codex App |
| CapsLock + Ctrl + H | Open ChatGPT |
| CapsLock + Ctrl + C | New Warp tab running Codex CLI |
| CapsLock + Ctrl + L | New Warp tab running Claude Code |

## Concepts

| Type | Meaning |
|---|---|
| Prompt | A Markdown template that tells the model how to handle the current input |
| Snippet | Fixed text or a template to copy or insert |
| Skill | An agent capability description or calling convention |
| Plugin | A tool extension, integration or plugin config |
| Agent | A long-running executor such as Codex CLI, Claude Code or Junie |
| Provider | A reviewed text-only adapter with known input and recipient boundaries, separate from coding agents |

## Directory layout

Configuration and runtime data are separate. Configuration belongs in version
control; runtime data does not.

```text
~/.config/ai-router/            # configuration, safe to commit
  config.json
  ai-router.sh
  lib/router_tools.py
  prompts/
    zh/                         # optional Chinese prompt set, see below
  snippets/
    zh/
  providers/
  exports/
  tests/

${XDG_STATE_HOME:-~/.local/state}/ai-router/   # runtime data, deletable at any time
  catalogs/
    prompts.json  hotkeys.json  palette.json  agents.json
  cache/
    selection.txt  selection-meta.env  last-output.md
  state/
    usage.json  favorites.json
  logs/
    events.jsonl  errors/
```

Before 2.4.0 those four directories lived under `~/.config/ai-router/`. The first
run after upgrading moves them, so favorites and usage history survive.

When `AI_ROUTER_HOME` is set (tests, sandboxes) runtime data stays inside that
same tree, so a test copy never writes into the real one.

## Prompt language

The shipped prompts and snippets are English. The router only reads the top level
of `prompts/` and `snippets/` - both the shell and the indexer glob `*.md`
non-recursively - so a subdirectory is an inert place to park a second language.

`prompts/zh/` and `snippets/zh/` hold the Chinese set: same ids, same filenames,
same frontmatter keys, Chinese descriptions and bodies. Switching language means
swapping which set sits at the top level.

```bash
# Switch the active set to Chinese
cp ~/.config/ai-router/prompts/zh/*.md ~/.config/ai-router/prompts/
cp ~/.config/ai-router/snippets/zh/*.md ~/.config/ai-router/snippets/
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh export-snippets all

# Switch back to English (redeploy the repo copy over local edits)
./bootstrap/install/ai-router.sh --deploy-only --force
```

Hotkeys, ids and provider settings are identical across the two sets, so nothing
downstream has to change: `index` regenerates the catalogs and Hammerspoon picks
up the new descriptions on its next read.

To add a third language, create a sibling directory (`prompts/de/`, say) with the
same ids and use the same swap.

## Common commands

```bash
# Piped input: no macOS permissions and no GUI required
git diff --staged | ~/.config/ai-router/ai-router.sh render commit-message

# Run this first after installing: what works, and how to install the rest
~/.config/ai-router/ai-router.sh doctor

# See exactly what would be sent to the model
~/.config/ai-router/ai-router.sh show summarize

~/.config/ai-router/ai-router.sh render summarize
# After reviewing your own text adapter (no enabled stock adapter is supplied):
~/.config/ai-router/ai-router.sh run summarize --provider my-text-api --from selection
~/.config/ai-router/ai-router.sh palette
~/.config/ai-router/ai-router.sh agent-menu
~/.config/ai-router/ai-router.sh favorite list
~/.config/ai-router/ai-router.sh favorite toggle prompt summarize "Summarize Selection"
~/.config/ai-router/ai-router.sh tool last-error
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh export-snippets all
~/.config/ai-router/ai-router.sh list providers
# From the repository, within its OS isolation boundary:
bash tests/run-all.sh home/.config/ai-router/tests/run.sh
```

## Adding a prompt

Add a Markdown file under `prompts/` with YAML frontmatter:

```markdown
---
id: my-action
title: My Action
description: What this prompt is for
category: writing
hotkey: z
priority: 300
input: selection
output: clipboard
allow_replace: false
aliases:
  - alias-a
  - alias-b
keywords:
  - search-word
  - scenario-word
tags:
  - writing
---

Handle the content below:

{{selection}}
```

Then run:

```bash
~/.config/ai-router/ai-router.sh index
```

`index` generates:

- `catalogs/` under the state directory (see the layout above).
- `catalogs/prompts.json`: prompt metadata, aliases, keywords, tags, provider settings.
- `catalogs/hotkeys.json`: the direct hotkey bindings Hammerspoon reads.
- `catalogs/palette.json`: search data for the Hammerspoon chooser and any future external app.
- `catalogs/agents.json`: the agent menu, generated from `config.json`.

Hammerspoon reads those caches first and only falls back to its built-in static
lists when they are missing.

`ai-router.sh palette` reads `catalogs/palette.json` too, rebuilding the index or
scanning dynamically only on a cache miss. Raycast, a future Mac app or any other
UI should consume the same cache.

## Favorites, recent and ranking

Chooser ordering comes from two local state files:

- `state/usage.json`: use count and last-used time, recorded automatically. It stores only `kind/value/title/count/time` - never the selection, prompt or output.
- `state/favorites.json`: manually pinned items, shown at the top of the chooser.

How it works:

- Anything picked from `CapsLock + Space` updates recent and usage count.
- Right-click an entry in the chooser to toggle its favorite state.
- Chooser titles group as `Pinned / Recent / Prompt / Snippet / Agent / Skill / Plugin / Tool`.
- Subtitles show the category, use count, last-used time and a condensed preview built from aliases, keywords and tags.
- Favorites can also be managed from the command line:

```bash
~/.config/ai-router/ai-router.sh favorite list
~/.config/ai-router/ai-router.sh favorite add prompt summarize "Summarize Selection"
~/.config/ai-router/ai-router.sh favorite remove prompt summarize "Summarize Selection"
```

## Adding a snippet

Add a Markdown file under `snippets/`. Snippets can use `{{selection}}`,
`{{clipboard}}`, `{{frontmost_app}}` and `{{window_title}}`.

Snippets take the same kind of frontmatter as prompts so they are searchable in
the palette:

```markdown
---
id: my-snippet
title: My Snippet
description: What this snippet is for
category: writing
priority: 300
aliases:
  - alias-a
  - alias-b
keywords:
  - search-word
  - scenario-word
tags:
  - snippet
  - writing
---

# My Snippet

{{selection}}
```

## Exporting to snippet tools

Static prompts and snippets can be exported to external snippet tools. The
dynamic parts - reading the selection, the frontmost app, the window title - stay
behind the `CapsLock + letter` shortcuts.

```bash
~/.config/ai-router/ai-router.sh export-snippets all
```

Generated files:

- `exports/raycast-snippets.json`: importable by Raycast Snippets. Fields are `name`, `text`, `keyword`.
- `exports/ai-router-snippets.json`: neutral JSON that keeps metadata, aliases, keywords, the raw template, the Raycast-flavored text and the variable list, so another tool can convert from it.

Export rules:

- Keywords are `;` plus 2-3 letters, short enough to trigger quickly in Raycast.
- Prompt examples: `;sm` summarize, `;tr` translate, `;ex` explain, `;rw` rewrite, `;fx` fix, `;qa` ask.
- Snippet examples: `;mt` meeting notes, `;rv` PR review, `;sq` SQL debug, `;er` terminal error.
- The Raycast export rewrites `{{selection}}` and `{{clipboard}}` to `{clipboard}`, and `{{date}}` to `{date}`.

Both files are checked into the repository and a smoke test diffs them against a
fresh export, so **re-run `export-snippets all` after editing any prompt or
snippet**.

## Adding a provider

A provider is trusted executable code under `providers/`, not a sandboxed plugin.
Copy the template, then review and implement the contract before enabling it:

```bash
cp ~/.config/ai-router/providers/_template.sh ~/.config/ai-router/providers/my-provider.sh
chmod +x ~/.config/ai-router/providers/my-provider.sh
~/.config/ai-router/ai-router.sh doctor
```

The contract:

- Read only the explicit prompt from stdin; write the result to stdout. No tools, MCP, hooks, project discovery, hidden recipient fallback or daemonization.
- `--text-contract`: print exactly `text-v1` only after verifying those properties. The copied template refuses by default; this marker is an assertion, not proof.
- `--health-check`: exit 0 when usable, nonzero otherwise. A successful check is not permission to send input.
- `--install-hint`: one line of install instructions. A line starting with `install:` means "installing this makes it work", and `doctor` prints it verbatim.
- Filenames starting with `_` are never treated as providers, so the template itself is not a routing target.

Adapters shipped with the repository:

- `claude`, `codex`, `gemini`, `kimi`, `junie`, `ollama`: text execution quarantined until version-scoped isolation/recipient checks exist. Agent-menu launch remains separate.
- `warp-agent` / `app-opener`: not text providers, shown as `[helper]` in `doctor`

Legacy provider preferences may still exist in old `config.json` or prompt files:

```json
"providers": { "default": [] }
```

They are metadata only, never used to authorize routing. `--provider NAME`
selects this request's recipient; `--fallback NAME,NAME` explicitly approves
additional recipients in order. Nothing else is appended. A failed selection
does not substitute clipboard input; use `--from clipboard` explicitly.

## Output and logs

- Every run writes its result to `cache/last-output.md` in the state directory.
- `output: clipboard` prompts also copy the result to the clipboard.
- `output: preview` prompts save and notify only; open the result from the palette with `Tool: Open Last Output`.
- Events go to `logs/events.jsonl` with `request_id`, `input_source`, `selection_source`, `selection_ms` and related metadata.
- Failures write router-generated status metadata to `logs/errors/<request_id>.log`; the clipboard is left unchanged.
- Provider stderr and failed stdout are discarded. Legacy `AI_ROUTER_DEBUG_FULL_LOG` / `privacy.debug_full_error_log` cannot enable raw retention. Old logs are not automatically erased.
- The most recent failure is mirrored to `logs/errors/latest.log`, reachable from the palette as `Tool: Open Last Error`.
- Logs record metadata only - never the full selection, prompt or output.
- `privacy.log_events: false` disables event logs, not output caches or external-client histories.

The agent menu is built from the `agents` block in `config.json`. The Hammerspoon
chooser reads `ai-router.sh agent-menu` first and only uses its built-in fallback
when that fails.

## Reliability settings

Reading the selection saves the clipboard, writes a sentinel, sends `Cmd+C`, then
polls the clipboard at a short interval - as soon as new content appears it moves
on instead of waiting out a fixed delay. The original clipboard is restored, and
the source and duration are written to `cache/selection-meta.env` and
`logs/events.jsonl`.

Environment variables for tuning:

```bash
AI_ROUTER_SELECTION_COPY_DELAY=0.28
AI_ROUTER_SELECTION_ATTEMPTS=2
AI_ROUTER_SELECTION_POLLING=1
AI_ROUTER_SELECTION_POLL_INTERVAL=0.03
AI_ROUTER_SELECTION_POLL_COUNT=10
AI_ROUTER_SELECTION_STRICT=0
AI_ROUTER_PROVIDER_TIMEOUT_SECONDS=60
```

The input source can be set explicitly:

```bash
AI_ROUTER_INPUT='text to process' ~/.config/ai-router/ai-router.sh render summarize
printf 'text' | ~/.config/ai-router/ai-router.sh run summarize --provider my-text-api
~/.config/ai-router/ai-router.sh run summarize --provider my-text-api --from selection
~/.config/ai-router/ai-router.sh run summarize --provider my-text-api --quiet
```

Render priority: `AI_ROUTER_INPUT` > piped stdin > selection > clipboard. Hammerspoon
always passes `--from selection`, so a hotkey never reads a pipe that is not its
own.

The default is at most 2 attempts, each polling 10 times at `0.03s`. With polling
off it falls back to the fixed `AI_ROUTER_SELECTION_COPY_DELAY=0.28` wait. With
`AI_ROUTER_SELECTION_STRICT=1`, failing to read a selection fails loudly instead
of silently using the clipboard.

Render-only can fall back to the clipboard; execution cannot. Provider probes
and execution share a 60-second deadline by default. Each runs in a neutral
temporary directory and an owned process group; ordinary children are stopped
on completion, timeout or handled cancellation. Fallback requires explicit
recipients and confirmed cleanup; cancellation stops the chain. This does not
stop intentionally detached daemons or guarantee remote billing cancellation.
Custom adapters remain trusted code with access to the user environment.

## Tests

Core tests live under `tests/`:

```bash
bash tests/run-all.sh home/.config/ai-router/tests/run.sh
```

They cover:

- prompt rendering and UTF-8 text
- selection read metadata
- catalog, hotkey and cached palette generation
- explicit-only fallback, process-group cleanup, handled cancellation and failure privacy
- usage and favorites state files

## Reloading Hammerspoon

```bash
hs -c 'hs.reload()'
```

## Roadmap and design notes

- `~/.config/ai-router/ROADMAP.md` - what is planned next.
- `docs/tools/ai-router/design-notes.md` in the repository - the design rules, the
  history behind them, and the parts that are deliberately unfinished.
