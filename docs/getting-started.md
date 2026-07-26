# Getting Started

`AI-First macOS Dotfiles` is a public, reproducible macOS dotfiles setup focused on AI-assisted development workflows.
This page is the shortest practical path to bootstrap it on a clean machine.

## Installation flow

The recommended path is the setup entrypoint:

```bash
git clone https://github.com/aklmans/ai-first-dotfiles.git
cd ai-first-dotfiles
./bootstrap/setup.sh all --dry-run   # print every command first
./bootstrap/setup.sh all
```

For config-only updates on a machine that already has packages installed:

```bash
./bootstrap/setup.sh deploy
```

Other common profiles:

```bash
./bootstrap/setup.sh shell
./bootstrap/setup.sh desktop
./bootstrap/setup.sh ai
./bootstrap/setup.sh all --dry-run
```

The repository is split into bootstrap layers:

1. **Core packages**
2. **Shell and terminal**
3. **Desktop workspace**
4. **AI workflow**
5. **Optional tools**

> All manual commands below are intended to run from the repository root.

### 1) Core bootstrap

```bash
cd ai-first-dotfiles
./bootstrap/brew.sh base desktop fonts
./bootstrap/app-store.sh
```

### 2) Shell and terminal

```bash
./bootstrap/install/zsh.sh
./bootstrap/install/starship.sh
./bootstrap/install/kaku.sh
./bootstrap/install/yazi.sh
./bootstrap/install/warp.sh        # optional
./bootstrap/install/ideavim.sh      # optional
```

### 3) Desktop and workspace

```bash
./bootstrap/install/karabiner.sh
./bootstrap/install/aerospace.sh
./bootstrap/install/sketchybar.sh
./bootstrap/install/borders.sh
./bootstrap/install/hammerspoon.sh
./bootstrap/install/bettertouchtool.sh   # optional
```

### 4) AI workflow

```bash
./bootstrap/install/ai-router.sh
```

### 5) Media and optional assistants

```bash
./bootstrap/install/mpv.sh           # optional
./bootstrap/install/gbrain.sh         # optional (local-only template-based setup)
```

> Optional modules can be installed later. Re-run only the scripts you want.

## Module order and rationale

- Install **shell + terminal** first so you have a predictable CLI.
- Install **Karabiner/AeroSpace/SketchyBar/Borders** together so workspace keys and UI are coherent.
- Install **Hammerspoon + AI Router** after desktop modules so cross-module hotkeys and chooser flows are available.
- Keep optional tools (Warp, mpv, BetterTouchTool, GBrain) for phase 5 to avoid forcing private/local dependencies.

## Verify after install

```bash
bash tests/smoke/repository_structure_smoke.sh
bash tests/smoke/install_script_syntax_smoke.sh
bash tests/smoke/ai_router_exports_smoke.sh
```

## Notes for local paths

If you hit local-only files, create private overrides instead of editing tracked files:

- `home/.config/zsh/private.zsh` for machine-specific shell variables.
- `.env` and other secret-bearing files are intentionally excluded from this repository.

## Related docs

- `docs/tools/zsh-starship/README.md`
- `docs/tools/terminal/README.md`
- `docs/tools/sublime/README.md`
- `docs/tools/aerospace/README.md`
- `docs/tools/sketchybar/README.md`
- `docs/tools/karabiner/README.md`
- `docs/tools/hammerspoon/README.md`
- `docs/tools/ai-router/README.md`
- `docs/tools/gui-path/README.md`
- `docs/tools/yazi/README.md`
- `docs/tools/bettertouchtool/README.md`
- `docs/tools/mpv/README.md`
- `docs/privacy.md`
- `docs/screenshots.md`
