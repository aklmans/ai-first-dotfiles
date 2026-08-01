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

## Guided recommendation

Users who do not yet know which preset or workspace count they want can start
with the local advisor:

```bash
./bootstrap/setup.sh recommend
```

It separates facts from preferences:

- Facts detected locally: connected display count/names, built-in display,
  suggested current main display, recognized installed applications and an
  existing advisor profile.
- Preferences asked explicitly: coding/AI/web/communication/writing/recording/
  media scenes, flexible versus fixed displays, terminal choice, and
  `follow`/`prefer`/`fixed` placement strength.

The result is a preview, not an install. Workspace count is derived from task
load rather than multiplying displays, and the rule is small enough to predict
before you run it — count the scenes you selected:

| Scenes selected | Mode | Workspaces |
|---:|---|---:|
| 1–2 | `focus` | 4 |
| 3–4 | `balanced` | 6 |
| 5–6 | `multitask` | 8 |
| 7, or 6 including recording | `advanced` | 10 |

Display count does not appear in that table on purpose. Plugging in a second
screen does not give you more workspaces; it changes how the same ones are
grouped across `main`, `side` and `stage`, and unplugged roles still collapse by
the normal display resolver. `--workspace-mode` overrides the table outright,
and `tune --workspace-feedback fewer|more` steps one row at a time.
If macOS exposes only a display count and not stable names, flexible planning
still works; fixed-name mode is deferred until AeroSpace or Hammerspoon can
report the names rather than writing placeholders that will never match.

```bash
./bootstrap/setup.sh recommend --apply
./bootstrap/setup.sh recommend --apply --config-only
./bootstrap/setup.sh tune
./bootstrap/setup.sh tune --workspace-feedback fewer --apply
```

Non-interactive mutation requires both `--apply` and `--yes`. Generated profile
and route files are backed up and recorded in the uninstall ledger; a symlink is
refused unless `--force` is explicit. Notifications, Full Disk Access,
BetterTouchTool and Warp installation are never inferred. Hardware/application
detection is not stored or sent anywhere.

## Profile settings

`~/.config/ai-first/profile.conf` contains literal `KEY="value"` assignments.
It is deliberately not a general shell hook.

| Setting | Meaning |
|---|---|
| `AI_FIRST_APP_ROUTING` | enable/disable app layout rules, user routes and the selected pack |
| `AI_FIRST_ROUTING_PACK` | `none`, `suggested`, `creator`, or `author` |
| `AI_FIRST_ADVISOR_SCENES` | advisor metadata used by `tune` and doctor |
| `AI_FIRST_ADVISOR_WORKSPACE_MODE` | `focus`, `balanced`, `multitask`, or `advanced` |
| `AI_FIRST_ADVISOR_DESK_MODE` | `flexible` or explicitly named `fixed` displays |
| `AI_FIRST_ADVISOR_PLACEMENT` | generated route strength: `follow`, `prefer`, or `fixed` |
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
| `AEROSPACE_WORKSPACE_ROLE_MAP` | semantic task role to configured workspace mapping |

Unknown bar item names and unsupported notification applications are ignored;
they are not executed as shell. With no profile present, legacy full behavior
is preserved for existing users.

When a module is added to a preset, its small data overlay is stored under
`~/.config/ai-first/modules/<preset>/`. The preset loads first and these explicit
additions load second. Module-only composition uses the `custom` scope and a
neutral base, so `automation` alone does not silently activate AI,
notifications or recording. Switching presets ignores overlays from other
scopes; returning to a preset restores the choices previously added to it.

The scope is taken from the profile already installed, not from the command
line, so adding a module later is one word:

```bash
./bootstrap/setup.sh minimal          # profile.conf records "minimal"
./bootstrap/setup.sh notifications    # overlay is stored in modules/minimal/
```

A generated advisor profile behaves the same way under its own `advisor` scope.
Two rules keep an addition from fighting the profile it joins: a module already
part of the active preset writes no overlay at all, and the neutral base is only
written for `custom`. `doctor` reports any overlay directory the active profile
does not read, because an overlay nothing loads looks exactly like a module that
is installed but broken.

## Workspace roles and routing packs

Display roles and task roles are separate. `main`, `side` and `stage` resolve
against however many displays are connected.

`stage` is a made-up word for “the screen you point at other people” — the one
carrying a call, a recording or a presentation. **If you never do any of those,
it is not a thing you need.** On one display it collapses into `main` on its own,
and on two it collapses into `side`; leaving `AEROSPACE_STAGE_WORKSPACES` empty
removes it altogether. It exists so that recording presets have somewhere to
send a window without hard-coding a screen, not because every desk has three
jobs. Semantic task targets such as
`focus`, `communication`, `notes` and `stage` resolve through
`AEROSPACE_WORKSPACE_ROLE_MAP`; app rules therefore do not need to know whether
the chosen profile uses six, eight or thirteen workspaces.

Shipped placements are explicit packs:

- `none`: no shipped placement; exact user routes still work. This is the
  public default.
- `suggested`: optional low-intervention communication, media and notes
  preferences.
- `creator`: recording applications target the selected profile's `stage`.
- `author`: the complete maintained reference map, selected only by
  `author-full` and legacy no-profile installs.

Run `~/.config/aerospace/plan.sh` to preview the resolved result and
`~/.config/aerospace/plan.sh --check` to reject missing role targets or invalid
route data.

## App route overrides

Use `~/.config/aerospace/app-routes.conf` instead of editing the large shipped
rule implementation:

```text
# match|value|target|policy|layout
id|com.microsoft.VSCode|focus|prefer|tiling
name|Safari|current|follow|tiling
id|com.example.Utility|utility|fixed|floating
id|com.apple.finder|current|follow|floating
```

Only exact `id` or `name` matches are accepted. Targets may be semantic roles,
configured workspace names, or `current`. Policies have deliberately different
strengths:

- `follow`: stay where opened.
- `prefer`: place new windows on the target, but the reset command does not
  move existing windows back after the user rearranges them.
- `fixed`: place new windows on the target and include them in explicit reset.

Pick by answering one question — *if I drag this app somewhere else, what should
happen next time?*

| You want | Policy | New window opens | After you move it by hand |
|---|---|---|---|
| “I decide every time” | `follow` | wherever you are | stays where you put it |
| “usually here, but don’t fight me” | `prefer` | on the target | stays where you put it |
| “always here, put it back” | `fixed` | on the target | `Alt+Shift+R` returns it |

`follow` and `prefer` look identical on the day you set them. The only moment
they differ is the *second* time you open the app after moving it: `prefer`
sends the new window back to the target, `follow` opens it where you are. If
that distinction does not matter to you yet, choose `follow` — it is the one
that never surprises you, and `app-route.sh prefer <role>` upgrades it later
without touching anything else.

`fixed` is the only one that gives a reset command anything to do. Use it for
the two or three apps you genuinely always want in one place, not as the
default.

Layout remains independent: `tiling`, `floating`, or `-`. Existing four-column
records are read as legacy data. Overrides win over the selected pack; invalid
targets are ignored by the renderer and reported by `plan.sh`/`doctor.sh`.

The complete priority order is:

1. handwritten `~/.config/aerospace/app-routes.conf`;
2. one-shot `captured-routes.conf` from a desktop the user arranged;
3. install-time `advisor-routes.conf` for detected apps and selected scenes;
4. the optional shipped routing pack.

The two generated files live under `~/.config/ai-first/`, so updating advice
never rewrites the handwritten file.

For the focused app, use the quick editor instead of looking up its bundle id:

```bash
~/.config/aerospace/app-route.sh bind-here
~/.config/aerospace/app-route.sh follow
~/.config/aerospace/app-route.sh prefer notes
~/.config/aerospace/app-route.sh capture-current
~/.config/aerospace/app-route.sh forget
```

`Option + Shift + B` runs `bind-here`; `Option + Shift + U` runs `follow`.
Each change backs up the route file, renders and validates the AeroSpace config,
then reloads it. Finder and Preview ship as `current|follow|floating`: they stay where
they are opened without taking over the tiled layout.

`capture-current` is read-only by default. It reads current AeroSpace windows
once: an app seen across several workspaces is proposed as `follow`, while an
app concentrated in one configured workspace is proposed as semantic
`prefer` when its task role matches, or that exact workspace otherwise.
`--policy fixed` is available only when the user explicitly wants a
strong constraint. `--apply` writes the reviewed snapshot; there is no daemon,
history database or background behavior tracking.

## Preset behavior

- `minimal`: six main workspaces, no pinned monitor, Terminal, neutral bar,
  portable dialog/layout behavior and user routes on, shipped pack `none`, and
  AI/notifications/recording off.
- `developer`: workspaces 1–6 main and 7–8 side when present, Terminal, AI
  hotkeys and routing support on, but routing pack `none`; every application
  follows the current workspace until the user chooses otherwise.
- `author-full`: workspaces 1–6 on PHL 279C9, 7–12 on 24V5C2, 13 on Built-in
  Retina Display; full bar; Warp terminal; notifications limited to Warp,
  Codex, IntelliJ IDEA and GoLand.

The author routing pack preserves OBS → 11, Bilibili → 10, and Shadow → 2 tiled.
Finder and Preview deliberately follow the workspace that opened them instead
of joining the workspace 11 system-app group.
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
