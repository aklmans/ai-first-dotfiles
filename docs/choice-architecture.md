# Choice Architecture

The maintained setup is a reference implementation, not a mandatory taste.
Users choose capabilities; tools are implementation details, and preferences
remain data rather than patches to program logic.

## The three layers

1. **Modules** are independent outcomes such as `workspace`, `capslock` or
   `ai`. Dependencies are explicit and de-duplicated.
2. **Presets** are named starting points. They install modules and deploy a
   small `profile.conf`; they are not editions or upgrade tiers.
3. **Preferences** change behavior after installation: enabled features, bar
   composition, notifications, terminal, displays, workspaces and app routes.

The catalog in `bootstrap/catalog.sh` is the source of truth used by the CLI and
tests. Inspect it through `./bootstrap/setup.sh list`.

## Composition examples

| Desired result | Command | What is not implied |
|---|---|---|
| tiling only | `./bootstrap/setup.sh workspace` | no bar, keyboard remap, AI or shell |
| tiling + visual status | `./bootstrap/setup.sh minimal` | no author app map or paid software |
| CapsLock AI without shell takeover | `./bootstrap/setup.sh capslock automation ai` | no zsh, Warp or notifications |
| bar attention for supported apps | `./bootstrap/setup.sh notifications` | adds its `bar` and `workspace` dependencies only |
| free terminal workflow | `./bootstrap/setup.sh terminal` | Kaku, not Warp |
| reference desk | `./bootstrap/setup.sh author-full` | nothing hidden; paid/closed choices are named in preview |

Different preferences can reach the same workflow. AI prompts can target the
macOS Terminal, Kaku or Warp; the prompt/router behavior does not depend on a
specific terminal brand. A workspace can be useful with or without SketchyBar,
notifications, gestures or the author's app placement.

## Profile settings

`~/.config/ai-first/profile.conf` contains literal `KEY="value"` assignments.
It is deliberately not a general shell hook.

| Setting | Meaning |
|---|---|
| `AI_FIRST_APP_ROUTING` | enable/disable shipped app workspace rules |
| `AI_FIRST_FEATURE_AI_HOTKEYS` | load Hammerspoon AI chooser/hotkeys |
| `AI_FIRST_FEATURE_NOTIFICATIONS` | run notification watchers |
| `AI_FIRST_FEATURE_RECORDING` | load recording window presets |
| `AI_FIRST_BAR_LEFT_ITEMS` | left item scripts in order |
| `AI_FIRST_BAR_CENTER_ITEMS` | center item scripts in order |
| `AI_FIRST_BAR_RIGHT_ITEMS` | right item scripts in order |
| `AI_FIRST_NOTIFICATION_APPS` | any subset of `warp codex idea goland` |
| `AI_FIRST_TERMINAL_APP` | terminal used by the AI router/app opener |
| `AEROSPACE_*_MONITOR_NAME` | optional main/side/stage display names |
| `AEROSPACE_*_WORKSPACES` | workspace lists for each role |

Unknown bar item names and unsupported notification applications are ignored;
they are not executed as shell. With no profile present, legacy full behavior
is preserved for existing users.

When a module is added to a preset, its small data overlay is stored under
`~/.config/ai-first/modules/<preset>/`. The preset loads first and these explicit
additions load second. Module-only composition uses the `custom` scope and a
neutral base, so `automation` alone does not silently activate AI,
notifications or recording. Switching presets ignores overlays from other
scopes; returning to a preset restores the choices previously added to it.

## App route overrides

Use `~/.config/aerospace/app-routes.conf` instead of editing the large shipped
rule implementation:

```text
# match|value|workspace|layout
id|com.microsoft.VSCode|3|tiling
name|Safari|6|tiling
id|com.example.Utility|-|floating
```

Only exact `id` or `name` matches, numeric workspaces, and `tiling`/`floating`
layouts are accepted. Overrides win over built-ins and are rendered into the
AeroSpace TOML. Invalid records are ignored.

## Preset behavior

- `minimal`: six main workspaces, no pinned monitor, Terminal, neutral bar,
  app routing/AI/notifications/recording off.
- `developer`: workspaces 1–6 main and 7–8 side when present, Terminal, AI
  hotkeys and routing on, notification/recording surfaces off.
- `author-full`: workspaces 1–6 on PHL 279C9, 7–12 on 24V5C2, 13 on Built-in
  Retina Display; full bar; Warp terminal; notifications limited to Warp,
  Codex, IntelliJ IDEA and GoLand.

The author preset also preserves OBS → 11, Bilibili → 10, and Shadow → 2 tiled.
Borders installs stopped by default in every path. Option+Shift+Space retains
the main-display bar/gap toggle, and the bar retains `shadow=off` and
`blur_radius=0`.

## Switching and local edits

Preview another preset first, then deploy it:

```bash
./bootstrap/setup.sh developer --dry-run
./bootstrap/setup.sh developer --deploy-only
```

Re-running the same preset keeps local edits and reports the conflict. Choosing
a different named preset is an intentional source change: it backs up the old
`profile.conf`, records it in the ledger, and installs the new one. Use
`DOTFILES_FORCE=1` only when you want to discard edits while returning to the
same preset.

To remove one explicitly added capability without uninstalling shared runtime
files, remove or move aside its matching file under
`~/.config/ai-first/modules/<preset>/`, then reload the affected app.

File removal is repository-wide because some capabilities share one runtime
directory (notifications live inside SketchyBar; recording lives inside
Hammerspoon). To stop one shared capability, turn its feature flag off. Use the
ledger-based uninstaller when removing the whole deployed configuration.
