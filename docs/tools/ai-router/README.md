# AI Workflow Router

`AI Router` standardizes prompt rendering, snippet generation, agent selection, and provider execution.
It is the central automation service used by the CapsLock AI workflow.

![AI Router CapsLock chooser](../../../assets/screenshots/capslock-chooser.png)

## Installed files

- `home/.config/ai-router/ai-router.sh`
- `home/.config/ai-router/config.json`
- `home/.config/ai-router/lib/router_tools.py`
- `home/.config/ai-router/prompts/` (English set; `prompts/zh/` holds the Chinese one)
- `home/.config/ai-router/snippets/` (English set; `snippets/zh/` holds the Chinese one)
- `home/.config/ai-router/providers/`
- `home/.config/ai-router/README.md` (full reference)
- `home/.config/ai-router/ROADMAP.md` (what is planned next)
- `bootstrap/install/ai-router.sh`

## Install

```bash
./bootstrap/install/ai-router.sh
```

This will deploy files, make scripts executable, build indices, and export snippets.

## Core concepts

- **Prompt**: Markdown template with frontmatter + variables (e.g. `{{selection}}`).
- **Snippet**: Small reusable text blocks for repeated insertion patterns.
- **Provider**: Back-end executor (`claude`, `codex`, `ollama`, `gemini`, `kimi`).
- **Agent**: Long-running command executors (`codex`, `claude`, `junie`, etc.).
- **Skill/Tool/Plugin**: Optional UI or operational entries shown in chooser modes.

## Prompt language

Prompts and snippets ship in English. A second language set lives in a
subdirectory (`prompts/zh/`, `snippets/zh/`) with identical ids, filenames and
frontmatter keys. The router globs the top level of `prompts/` and `snippets/`
non-recursively, so a language subdirectory is inert until its files are copied
up one level.

```bash
# Switch the active set to Chinese
cp ~/.config/ai-router/prompts/zh/*.md ~/.config/ai-router/prompts/
cp ~/.config/ai-router/snippets/zh/*.md ~/.config/ai-router/snippets/
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh export-snippets all

# Switch back to English
./bootstrap/install/ai-router.sh --deploy-only --force
```

Hotkeys, ids and provider settings are identical across the sets, so nothing
downstream changes. Adding a language means adding a sibling directory with the
same ids.

## How to use

### Render a prompt

```bash
~/.config/ai-router/ai-router.sh render summarize
```

### Run a prompt directly

```bash
~/.config/ai-router/ai-router.sh run summarize
```

### Open chooser

```bash
~/.config/ai-router/ai-router.sh palette
~/.config/ai-router/ai-router.sh agent-menu
```

### Manage favorites

```bash
~/.config/ai-router/ai-router.sh favorite list
~/.config/ai-router/ai-router.sh favorite add prompt summarize "Summarize Selection"
```

## How AI Router + Hammerspoon connect

1. Karabiner sends CapsLock-based chords.
2. Hammerspoon receives the chord and dispatches router actions.
3. Router reads catalog/config and renders/executes the matching item.
4. Output is copied, launched, or opened according to command action.

## Why no hidden provider hotkeys?

Provider execution is kept explicit to avoid accidental external calls and tokenless surprise actions.
The default flow favors explicit invocation:

- choose intent (prompt/agent)
- review generated output/command
- execute intentionally

## Adding content

### New prompt

1. Add file to `home/.config/ai-router/prompts/` with YAML frontmatter.
2. Rebuild index:

```bash
~/.config/ai-router/ai-router.sh index
```

### New snippet

1. Add file to `home/.config/ai-router/snippets/`.
2. Add any aliases/keywords metadata.
3. Re-export:

```bash
~/.config/ai-router/ai-router.sh export-snippets all
```

`exports/*.json` are tracked in the repository and `tests/smoke/ai_router_exports_smoke.sh`
diffs them against a fresh export, so committing a prompt or snippet edit without
re-exporting turns that test red.

### New provider

1. Add executable in `home/.config/ai-router/providers/`.
2. Update `home/.config/ai-router/config.json`.
3. Rebuild index and verify chooser inputs:

```bash
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh list providers
```

## Export and external tools

```bash
~/.config/ai-router/ai-router.sh export-snippets all
```

Expected export artifacts:

- `exports/raycast-snippets.json`
- `exports/ai-router-snippets.json`

Use Raycast import/imported JSON as a runtime workflow bridge.

![Raycast snippet import](../../../assets/screenshots/raycast-import.png)

## Safety and privacy

- Keep provider binary names explicit and local.
- `catalogs/`, `cache/`, `state/`, and `logs/` are runtime outputs and excluded from tracked repo state.
- Real API keys stay outside the repo and loaded from private local files only.

## Further reading

- [`home/.config/ai-router/README.md`](../../../home/.config/ai-router/README.md) - full reference: every command, every setting, the provider contract.
- [`home/.config/ai-router/ROADMAP.md`](../../../home/.config/ai-router/ROADMAP.md) - what is planned next.
- [`design-notes.md`](design-notes.md) - design rules, the reasoning behind them, and the known rough edges.
