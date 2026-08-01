#!/usr/bin/env bash
set -euo pipefail

repo_root_dir() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$script_dir"
}

# Apple Silicon, including a shell running under Rosetta. `uname -m` alone reports
# x86_64 there, which would reject a supported machine for the sake of how one
# terminal happens to be launched, so the hardware flag is asked first.
is_apple_silicon() {
  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
    return 0
  fi

  [[ "$(uname -m 2>/dev/null || true)" == "arm64" ]]
}

# Fail fast on a missing toolchain. Without this the first module script to need
# Homebrew dies with a bare `command not found`, several screens into an install
# the user cannot tell apart from a real bug.
# Pass "warn" to report problems without failing. --dry-run uses that: previewing
# is the one thing a stranger should be able to do before installing anything,
# including Homebrew itself.
require_prerequisites() {
  local mode="${1:-fail}"

  if [[ "${DOTFILES_SKIP_PREFLIGHT:-0}" == "1" ]]; then
    return 0
  fi

  local -a problems
  local problem
  problems=()

  # First, because it is the one problem on this list that cannot be fixed by
  # installing something. 48 paths across the desktop layer - AeroSpace's
  # exec-and-forget, Hammerspoon's module search path, the SketchyBar plugins -
  # name /opt/homebrew directly, and Intel Homebrew lives at /usr/local. On an
  # Intel Mac the install therefore succeeds, reports nothing, and leaves a
  # desktop layer where nothing is wired to anything. Refusing up front is the
  # honest version of that.
  if ! is_apple_silicon; then
    problems+=('This setup supports Apple Silicon only. It hard-codes the /opt/homebrew prefix in the AeroSpace, Hammerspoon and SketchyBar layers, which would silently do nothing on an Intel Mac.')
  fi

  if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
    problems+=('Xcode Command Line Tools are missing. Install them: xcode-select --install')
  fi

  if ! command -v git >/dev/null 2>&1; then
    problems+=('git is missing. It ships with the Xcode Command Line Tools, or: brew install git')
  fi

  if ! command -v brew >/dev/null 2>&1; then
    problems+=('Homebrew is missing. Install it from https://brew.sh, then open a new shell so brew is on PATH.')
  fi

  if [[ "${#problems[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ "$mode" == "warn" ]]; then
    printf 'Note: this machine does not meet the prerequisites. This preview still works, but installing will not.\n\n' >&2
  else
    printf 'Cannot bootstrap: this machine does not meet the prerequisites.\n\n' >&2
  fi

  for problem in ${problems[@]+"${problems[@]}"}; do
    printf '  - %s\n' "$problem" >&2
  done
  printf '\nSee the Prerequisites section of README.md.\n' >&2

  if [[ "$mode" == "warn" ]]; then
    printf '\n' >&2
    return 0
  fi

  printf 'Set DOTFILES_SKIP_PREFLIGHT=1 to bypass this check.\n' >&2
  return 1
}

DOTFILES_INSTALL=1
DOTFILES_DEPLOY=1
DOTFILES_BREW=1

# --force is also readable from the environment so it survives every wrapper
# between the user and this library: `DOTFILES_FORCE=1 ./bootstrap/setup.sh deploy`
# works without setup.sh having to learn a new flag to forward.
if [[ "${DOTFILES_FORCE:-0}" == "1" ]]; then
  DOTFILES_FORCE=1
else
  DOTFILES_FORCE=0
fi

install_flag_usage() {
  cat <<'EOF'
Common install flags:
  --install-only   Install packages/external dependencies only; do not deploy config.
  --deploy-only    Deploy config only; skip Homebrew/package installation.
  --no-brew        Skip Homebrew commands but still run non-brew setup steps.
  --no-deploy      Skip config deployment.
  --force          Make every target match this repo: replace symlinked targets
                   and overwrite changes made on this machine. Whatever is
                   replaced is backed up first. Same as DOTFILES_FORCE=1.
  -h, --help       Show this help.
EOF
}

parse_install_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --install-only)
        DOTFILES_INSTALL=1
        DOTFILES_DEPLOY=0
        ;;
      --deploy-only)
        DOTFILES_INSTALL=0
        DOTFILES_DEPLOY=1
        DOTFILES_BREW=0
        ;;
      --no-brew)
        DOTFILES_BREW=0
        ;;
      --no-deploy)
        DOTFILES_DEPLOY=0
        ;;
      --force)
        DOTFILES_FORCE=1
        ;;
      -h|--help)
        install_flag_usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        install_flag_usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

should_install() {
  [[ "$DOTFILES_INSTALL" -eq 1 ]]
}

should_deploy() {
  [[ "$DOTFILES_DEPLOY" -eq 1 ]]
}

should_brew() {
  [[ "$DOTFILES_BREW" -eq 1 ]]
}

# Homebrew 6 refuses to install from a third-party tap until that tap is
# trusted, and trusting one decides whose code may run on this machine. This
# repo taps three: sketchybar and borders from felixkratz, kaku from tw93.
#
# It refuses even when the formula is already installed - `brew info` on one
# still works, `brew install` on the same formula does not - so this is not only
# a new-machine problem. It went unnoticed because nobody had re-run an install
# since Homebrew added the gate. A fresh Mac just meets it immediately:
# `minimal` is workspace + bar, so half of the smallest preset died with brew's
# own error a screen above the summary.
#
# Trust state alone is still the wrong thing to refuse on, because whether it
# actually blocks anything depends on what brew is being asked to do. So the
# taps are remembered, brew is allowed to speak first, and the guidance is
# printed only after an install has really failed.
DOTFILES_BREW_TAPS=""

# 0 = trusted, or unknowable, or official. A check that cannot read the state
# must never invent a refusal.
#
# Trust in Homebrew 6 is granular, and the first version of this only read the
# tap list. `brew trust felixkratz/formulae/sketchybar` - which is the command
# brew's own error suggests, and so the one people actually run - records a
# formula, not a tap. On the machine this was written for, `brew trust --json`
# reported no trusted taps at all while sketchybar and aerospace were both
# trusted and installing fine, so every check said "not trusted" forever: a
# false warning in `--dry-run`, and a paragraph of remediation after every
# install that had not failed. Whichever list the answer is in, it is an answer.
brew_trust_lists_contain() {
  local needle="$1" trusted
  shift

  command -v python3 >/dev/null 2>&1 || return 0
  trusted="$(brew trust --json v1 2>/dev/null)" || return 0
  [[ -n "$trusted" ]] || return 0

  printf '%s' "$trusted" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
needle = sys.argv[1]
for key in sys.argv[2:]:
    if needle in (data.get(key) or []):
        raise SystemExit(0)
raise SystemExit(1)
' "$needle" "$@"
}

brew_tap_is_trusted() {
  local tap="$1"

  case "$tap" in
    homebrew/*) return 0 ;;
  esac

  brew_trust_lists_contain "$tap" taps
}

# Whether Homebrew would load this specific formula or cask: either its whole
# tap is trusted, or it is trusted by name. `$1` is a fully qualified name such
# as felixkratz/formulae/sketchybar; a bare name is from an official tap and
# never gated.
brew_item_is_trusted() {
  local item="$1" tap

  case "$item" in
    */*/*) tap="${item%/*}" ;;
    *) return 0 ;;
  esac

  brew_tap_is_trusted "$tap" && return 0
  brew_trust_lists_contain "$item" formulae casks
}

# One line in a plan, for a formula or cask Homebrew would refuse today. It goes
# beside the item rather than beside the tap because that is where the answer
# is: at the point a tap is declared nothing has said yet what will be installed
# from it, and warning there marked taps this repo only ever takes a cask from.
#
# Only fully qualified names get a verdict. The install scripts name a
# third-party formula the way brew resolves it - `brew_install sketchybar`, not
# `felixkratz/formulae/sketchybar` - and guessing the tap for a bare name would
# accuse `lua`, `jq` and `gh` of coming from somewhere they do not. Those are
# covered by the note below instead.
brew_plan_report_untrusted() {
  local item="$1"

  case "$item" in
    */*/*) ;;
    *) return 0 ;;
  esac

  brew_item_is_trusted "$item" && return 0
  printf '    %-8s %s is not trusted yet; Homebrew refuses to install it until\n' 'trust' "$item"
  printf '    %-8s you run "brew trust %s"\n' '' "$item"
}

# Set the moment a plan names something brew has to resolve on its own, so the
# closing note is printed for those runs and stays out of the way of the ones
# that were answered exactly.
DOTFILES_BREW_UNQUALIFIED=0

brew_plan_note_item() {
  case "$1" in
    */*/*) ;;
    *) DOTFILES_BREW_UNQUALIFIED=1 ;;
  esac
}

# The part a plan can be sure of: which third-party taps are in play, and which
# of those the machine has not trusted wholesale. On a Mac that has never seen
# them the tap is not on disk, so nothing can say in advance which formula will
# be refused - only that something from here will be, and what to type when
# brew names it. Silence is how `minimal` got to install everything before
# sketchybar and then stop.
brew_plan_note_untrusted_taps() {
  local tap first=1

  for tap in "$@"; do
    [[ -n "$tap" ]] || continue
    brew_tap_is_trusted "$tap" && continue
    if [[ "$first" -eq 1 ]]; then
      printf '    %-8s not trusted wholesale: %s\n' 'trust' "$tap"
      first=0
    else
      printf '    %-8s %s\n' '' "$tap"
    fi
  done
  [[ "$first" -eq 0 ]] || return 0
  printf '    %-8s Homebrew refuses what it has not been told to trust and names it;\n' ''
  printf '    %-8s run "brew trust <what it named>" and start again.\n' ''
}

# Printed after a failed brew install, for whichever taps this run added that
# Homebrew would still refuse to load from.
brew_report_untrusted_taps() {
  local tap reported=0

  for tap in $DOTFILES_BREW_TAPS; do
    brew_tap_is_trusted "$tap" && continue
    if [[ "$reported" -eq 0 ]]; then
      printf '\nHomebrew will not install from a third-party tap until you trust it, and\n' >&2
      printf 'trusting one lets its code run on this machine. That is your call, so this\n' >&2
      printf 'installer does not make it for you:\n\n' >&2
      reported=1
    fi
    printf '    brew trust %s\n' "$tap" >&2
  done

  [[ "$reported" -eq 1 ]] || return 0
  printf '\nThen re-run the same command; every step here is safe to run again.\n' >&2
}

ensure_brew_tap() {
  local tap="$1"
  should_brew || return 0

  case " $DOTFILES_BREW_TAPS " in
    *" $tap "*) ;;
    *) DOTFILES_BREW_TAPS="$DOTFILES_BREW_TAPS $tap" ;;
  esac

  if [[ "${DOTFILES_BREW_PLAN:-0}" == "1" ]]; then
    printf '    tap      %s\n' "$tap"
    return 0
  fi
  if ! brew tap | grep -Fx "$tap" >/dev/null 2>&1; then
    brew tap "$tap"
  fi
}

brew_install() {
  local formula
  should_brew || return 0
  if [[ "${DOTFILES_BREW_PLAN:-0}" == "1" ]]; then
    for formula in "$@"; do
      printf '    formula  %s\n' "$formula"
      brew_plan_report_untrusted "$formula"
      brew_plan_note_item "$formula"
    done
    return 0
  fi
  # The exit status is passed through rather than collapsed to 1: setup.sh tells
  # a killed run apart from a failed one by looking for 130/131/143, and an `if`
  # around this would have turned every Ctrl-C into an ordinary step failure.
  local status=0
  brew install "$@" || status=$?
  case "$status" in
    0|130|131|143) return "$status" ;;
  esac
  brew_report_untrusted_taps
  return "$status"
}

cask_app_paths() {
  local cask="$1"
  local token="${cask##*/}"
  local info

  info="$(brew info --cask "$cask" 2>/dev/null || true)"
  printf '%s\n' "$info" | awk '
    /^==> Artifacts/ { in_artifacts = 1; next }
    /^==>/ { in_artifacts = 0 }
    in_artifacts && /\.app \(App\)/ {
      sub(/^[[:space:]]*/, "")
      sub(/ \(App\).*/, "")
      print
    }
  '

  case "$token" in
    aerospace)
      printf '%s\n' "AeroSpace.app"
      ;;
    bettertouchtool)
      printf '%s\n' "BetterTouchTool.app"
      ;;
    hammerspoon)
      printf '%s\n' "Hammerspoon.app"
      ;;
    karabiner-elements)
      printf '%s\n' "Karabiner-Elements.app"
      ;;
    mpv)
      printf '%s\n' "mpv.app"
      ;;
    warp)
      printf '%s\n' "Warp.app"
      ;;
  esac
}

cask_app_exists() {
  local cask="$1"
  local app

  while IFS= read -r app; do
    [[ -n "$app" ]] || continue
    if [[ -d "/Applications/$app" || -d "$HOME/Applications/$app" || -d "/Applications/Utilities/$app" ]]; then
      return 0
    fi
  done < <(cask_app_paths "$cask" | sort -u)

  return 1
}

brew_install_cask() {
  should_brew || return 0

  local cask token
  if [[ "${DOTFILES_BREW_PLAN:-0}" == "1" ]]; then
    for cask in "$@"; do
      printf '    cask     %s\n' "$cask"
      brew_plan_report_untrusted "$cask"
      brew_plan_note_item "$cask"
    done
    return 0
  fi

  for cask in "$@"; do
    token="${cask##*/}"

    if brew list --cask --versions "$cask" >/dev/null 2>&1 || brew list --cask --versions "$token" >/dev/null 2>&1; then
      printf 'Cask already managed by Homebrew: %s\n' "$cask"
      continue
    fi

    if cask_app_exists "$cask"; then
      printf 'Cask app already exists outside Homebrew; skipping install: %s\n' "$cask"
      continue
    fi

    local status=0
    brew install --cask "$cask" || status=$?
    case "$status" in
      0|130|131|143) ;;
      *)
        brew_report_untrusted_taps
        return "$status"
        ;;
    esac
    [[ "$status" -eq 0 ]] || return "$status"
  done
}

require_repo_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'Missing required path: %s\n' "$path" >&2
    exit 1
  fi
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

# ---------------------------------------------------------------------------
# Config deployment
#
# deploy_repo_path is the only code in this repository that writes into the
# user's $HOME, and all install scripts funnel through it. Four rules it must
# never break:
#
#   1. A directory is deployed file by file. Files the repo does not ship are
#      left exactly where they are, so a user's own prompts, SketchyBar items
#      and router state survive every redeploy.
#   2. Only what this repo actually changed is written. A target that differs
#      while the repo copy has not moved since the last deploy was changed on
#      this machine, and stays.
#   3. Anything that is replaced is moved aside first and written to the
#      backup ledger, so bootstrap/uninstall.sh can put it back.
#   4. Symbolic links are never followed or replaced. A symlink means another
#      tool (GNU Stow, chezmoi, a hand-rolled setup) owns that path; deploying
#      over it would silently cut the link.
#
# --force opts out of 2 and 4 - "make this machine match the repo" - and even
# then everything it replaces is backed up rather than deleted.
# ---------------------------------------------------------------------------

# Set by backup_target so its caller can hand the chosen path to the ledger.
DOTFILES_BACKUP_PATH=""
# Set by deploy_single_file: created | updated | unchanged | kept | skipped.
DOTFILES_LAST_ACTION=""
# Paths this run refused to touch, reported once at exit.
DOTFILES_SKIPPED_COUNT=0
DOTFILES_SKIPPED_REPORT=""
DOTFILES_SKIP_TRAP_INSTALLED=0
# 0 unknown, 1 usable, 2 unusable.
DOTFILES_STATE_READY=0

deploy_force_enabled() {
  [[ "$DOTFILES_FORCE" == "1" ]]
}

dotfiles_state_dir() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/ai-first-dotfiles"
}

dotfiles_ledger_path() {
  printf '%s\n' "$(dotfiles_state_dir)/backups.tsv"
}

# The ledger is bookkeeping, not the deploy itself: a machine where the state
# directory cannot be written must still deploy, with one warning.
dotfiles_state_ready() {
  local state_dir

  case "$DOTFILES_STATE_READY" in
    1)
      return 0
      ;;
    2)
      return 1
      ;;
  esac

  state_dir="$(dotfiles_state_dir)"
  if mkdir -p "$state_dir" 2>/dev/null; then
    DOTFILES_STATE_READY=1
    return 0
  fi

  DOTFILES_STATE_READY=2
  printf 'Warning: cannot write %s. Backups are still made but not recorded, so uninstall.sh will not see them.\n' \
    "$state_dir" >&2
  return 1
}

# The ledger is tab separated and one line per record, so the three characters
# that would break that are percent-encoded. Everything else - spaces, quotes,
# non-ASCII - is written through untouched and stays readable.
ledger_encode() {
  local value="$1"

  value="${value//%/%25}"
  value="${value//$'\t'/%09}"
  value="${value//$'\n'/%0A}"
  printf '%s' "$value"
}

ledger_decode() {
  local value="$1"

  value="${value//%0A/$'\n'}"
  value="${value//%09/$'\t'}"
  value="${value//%25/%}"
  printf '%s' "$value"
}

# One line per path this repo replaced or created. A "-" backup_path means the
# target did not exist beforehand, which is what lets uninstall.sh tell "put the
# old file back" apart from "remove the file we added".
ledger_record() {
  local source_rel="$1"
  local target="$2"
  local backup_path="${3:-}"
  local ledger_file

  dotfiles_state_ready || return 0
  ledger_file="$(dotfiles_ledger_path)"

  if [[ ! -f "$ledger_file" ]]; then
    {
      printf '# ai-first-dotfiles backup ledger\n'
      printf '# fields: timestamp\tsource_rel\ttarget\tbackup_path\n'
      printf '# backup_path "-" means the target did not exist and this repo created it\n'
      printf '# %%, tab and newline inside a field are percent-encoded as %%25, %%09, %%0A\n'
    } >"$ledger_file" 2>/dev/null || true
  fi

  printf '%s\t%s\t%s\t%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$(ledger_encode "$source_rel")" \
    "$(ledger_encode "$target")" \
    "$(ledger_encode "${backup_path:--}")" \
    >>"$ledger_file" 2>/dev/null || true
}

backup_target() {
  local target="$1"
  local stamp="$2"
  local backup_path suffix

  DOTFILES_BACKUP_PATH=""
  [[ -e "$target" || -L "$target" ]] || return 0

  backup_path="${target}.backup_${stamp}"
  suffix=1
  while [[ -e "$backup_path" || -L "$backup_path" ]]; do
    backup_path="${target}.backup_${stamp}_${suffix}"
    suffix=$((suffix + 1))
  done

  # Returns non-zero when the file could not be moved aside, and every caller
  # must then leave the target alone.
  #
  # This used to run `mv` bare and announce success regardless. `set -e` did not
  # save it: a deploy reached from `deploy_repo_path ... || status=$?` runs with
  # errexit suspended for the whole call tree, so a failed mv carried straight
  # on to the `cp` below it. The result was the exact thing this engine exists to
  # prevent - the user's file overwritten, no backup on disk, "Backed up ..."
  # printed, exit status 0, and a ledger row pointing at a path that was never
  # created, so uninstall could not put it back either.
  if ! mv "$target" "$backup_path" 2>/dev/null; then
    DOTFILES_BACKUP_PATH=""
    printf 'Could not move %s aside (check permissions on its directory).\n' "$target" >&2
    return 1
  fi
  DOTFILES_BACKUP_PATH="$backup_path"
  printf 'Backed up %s -> %s\n' "$target" "$backup_path"
}

files_match() {
  local source_file="$1"
  local target_file="$2"

  # A symlink never "matches": whether to touch it is a policy decision the
  # caller makes, not something a content comparison may decide silently.
  if [[ -L "$target_file" ]]; then
    return 1
  fi
  if [[ ! -f "$source_file" || ! -f "$target_file" ]]; then
    return 1
  fi

  cmp -s "$source_file" "$target_file"
}

# Kept for callers written against the old engine. Directory comparison is no
# longer a single answer - deploy_repo_path decides per file - so a directory
# argument returns the conservative "not identical".
paths_match() {
  files_match "$1" "$2"
}

# Refusing to deploy is not an error the current script can recover from, but it
# must not stop the remaining targets either: a machine that manages one path
# with Stow still wants the other sixteen deployed. So every refusal is
# collected, printed as one block at the end, and turned into a non-zero exit so
# nothing automated mistakes a partial deploy for a complete one.
#
# The summary is delivered by an EXIT trap installed on the first refusal. No
# install script sets an EXIT trap of its own; a caller that sources this
# library and needs one must install it after its last deploy call.
deploy_skip() {
  local target="$1"
  local reason="$2"

  DOTFILES_SKIPPED_COUNT=$((DOTFILES_SKIPPED_COUNT + 1))
  DOTFILES_SKIPPED_REPORT="${DOTFILES_SKIPPED_REPORT}  ${target}
      ${reason}
"
  printf 'Skipped %s: %s\n' "$target" "$reason" >&2

  if [[ "$DOTFILES_SKIP_TRAP_INSTALLED" -eq 0 ]]; then
    DOTFILES_SKIP_TRAP_INSTALLED=1
    trap 'deploy_report_skips "$?"' EXIT
  fi
}

deploy_report_skips() {
  local status="${1:-0}"

  if [[ "$DOTFILES_SKIPPED_COUNT" -eq 0 ]]; then
    exit "$status"
  fi

  printf '\n%s path(s) were left untouched:\n\n' "$DOTFILES_SKIPPED_COUNT" >&2
  printf '%s' "$DOTFILES_SKIPPED_REPORT" >&2
  printf '\nNothing there was overwritten, moved or deleted. A symlink usually means\n' >&2
  printf 'another dotfiles manager owns that path. To hand it to this repo, either\n' >&2
  printf 'move it aside yourself, or re-run with --force (DOTFILES_FORCE=1), which\n' >&2
  printf 'backs the link up before replacing it.\n' >&2

  if [[ "$status" -eq 0 ]]; then
    exit 3
  fi
  exit "$status"
}

# cp gives a new file the source mode masked by the umask. Copying the mode
# explicitly keeps executables executable (SketchyBar plugins, router providers)
# regardless of the umask the installer inherited. macOS stat only; anywhere
# else this is a no-op rather than a failure.
sync_file_mode() {
  local source_file="$1"
  local target_file="$2"
  local mode

  mode="$(stat -f '%OLp' "$source_file" 2>/dev/null || true)"
  [[ -n "$mode" ]] || return 0
  chmod "$mode" "$target_file" 2>/dev/null || true
}

# True only for paths strictly below $HOME. Everything at or above $HOME (a
# symlinked home directory, /var on macOS, a sandbox under TMPDIR) is not
# something this repo deploys into, so its being a symlink must not make a
# deploy refuse to run.
deploy_path_is_managed() {
  local path="$1"

  case "$path" in
    "$HOME"/*)
      return 0
      ;;
  esac
  return 1
}

# Creates $1 and any missing ancestor, recording each directory it had to create
# so uninstall.sh can rmdir them again. Only the deepest existing ancestor can be
# a symlink this would write through, so that is the one that gets checked.
ensure_deploy_dir() {
  local dir="$1"
  local source_rel="$2"
  local current index candidate
  local -a missing

  missing=()
  current="$dir"
  while [[ -n "$current" && "$current" != "/" && "$current" != "." && ! -d "$current" ]]; do
    missing+=("$current")
    current="$(dirname "$current")"
  done

  if [[ -L "$current" ]] && deploy_path_is_managed "$current" && ! deploy_force_enabled; then
    deploy_skip "$current" 'parent directory is a symlink; refusing to write through it'
    return 1
  fi

  index=$(( ${#missing[@]} - 1 ))
  while [[ "$index" -ge 0 ]]; do
    candidate="${missing[$index]}"

    if [[ -L "$candidate" || -e "$candidate" ]]; then
      deploy_skip "$candidate" 'expected a directory here, found something else'
      return 1
    fi
    if ! mkdir "$candidate" 2>/dev/null; then
      deploy_skip "$candidate" 'could not create this directory'
      return 1
    fi

    ledger_record "$source_rel" "$candidate" ""
    index=$((index - 1))
  done

  return 0
}

# --- deploy manifest -------------------------------------------------------
#
# One file per deploy target under the state directory, holding a line per file
# the last deploy shipped: "<relative path>\t<fingerprint of the repo copy>".
# It answers the two questions a file-by-file deploy cannot answer on its own:
#
#   - Did the repo change this file since we deployed it? If not, a target that
#     differs was changed on this machine and overwriting it would destroy a
#     local change for no gain (see deploy_single_file).
#   - Did the repo stop shipping a file we once deployed? That orphan is
#     otherwise indistinguishable from a file the user wrote (see the report at
#     the bottom of deploy_save_manifest).

DEPLOY_PREV_MANIFEST=""
DEPLOY_NEW_MANIFEST=""

deploy_manifest_path() {
  local target="$1"
  local encoded

  encoded="$(ledger_encode "$target")"
  encoded="${encoded//\//%2F}"
  printf '%s\n' "$(dotfiles_state_dir)/manifests/$encoded"
}

file_fingerprint() {
  local path="$1"

  # Read from stdin so the output is the checksum alone, without the filename.
  printf '%s' "$(cksum <"$path" 2>/dev/null || true)"
}

deploy_load_manifest() {
  local target="$1"
  local manifest content

  DEPLOY_PREV_MANIFEST=""
  DEPLOY_NEW_MANIFEST=""

  dotfiles_state_ready || return 0
  manifest="$(deploy_manifest_path "$target")"
  [[ -f "$manifest" ]] || return 0

  content="$(cat "$manifest" 2>/dev/null || true)"
  [[ -n "$content" ]] || return 0
  # Framed in newlines so a lookup can anchor on whole lines without forking.
  DEPLOY_PREV_MANIFEST=$'\n'"$content"$'\n'
}

deploy_prev_fingerprint() {
  local rel="$1"
  local rest

  [[ -n "$DEPLOY_PREV_MANIFEST" ]] || return 1

  rest="${DEPLOY_PREV_MANIFEST#*$'\n'"$rel"$'\t'}"
  [[ "$rest" != "$DEPLOY_PREV_MANIFEST" ]] || return 1

  printf '%s' "${rest%%$'\n'*}"
}

deploy_record_manifest_entry() {
  local rel="$1"
  local fingerprint="$2"

  # A tab or newline in a filename cannot be represented here. Leaving the entry
  # out only costs this file the two protections above, and never writes a line
  # that would be misparsed on the next deploy.
  case "$rel" in
    *$'\t'*|*$'\n'*)
      return 0
      ;;
  esac

  DEPLOY_NEW_MANIFEST="${DEPLOY_NEW_MANIFEST}${rel}"$'\t'"${fingerprint}"$'\n'
}

deploy_save_manifest() {
  local target="$1"
  local manifest manifest_new rel stale_list="" total=0

  dotfiles_state_ready || return 0

  manifest="$(deploy_manifest_path "$target")"
  mkdir -p "$(dirname "$manifest")" 2>/dev/null || return 0
  manifest_new="${manifest}.new"

  printf '%s' "$DEPLOY_NEW_MANIFEST" | LC_ALL=C sort >"$manifest_new" 2>/dev/null || return 0

  if [[ -f "$manifest" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" && "$rel" != "." ]] || continue
      [[ -e "$target/$rel" || -L "$target/$rel" ]] || continue

      total=$((total + 1))
      if [[ "$total" -le 10 ]]; then
        stale_list="${stale_list}  ${target}/${rel}
"
      fi
    done < <(LC_ALL=C comm -23 <(cut -f1 "$manifest") <(cut -f1 "$manifest_new") 2>/dev/null || true)
  fi

  mv "$manifest_new" "$manifest" 2>/dev/null || rm -f "$manifest_new" 2>/dev/null || true

  [[ "$total" -gt 0 ]] || return 0

  printf 'Note: %s file(s) under %s came from an older version of this repo and are no longer shipped.\n' \
    "$total" "$target"
  printf '%s' "$stale_list"
  if [[ "$total" -gt 10 ]]; then
    printf '  ... and %s more\n' "$((total - 10))"
  fi
  printf 'Nothing was removed. Delete them yourself if you no longer want them.\n'
}

deploy_single_file() {
  local source_file="$1"
  local target_file="$2"
  local source_rel="$3"
  local stamp="$4"
  local rel="${5:-.}"
  local fingerprint previous

  DOTFILES_LAST_ACTION="unchanged"
  fingerprint="$(file_fingerprint "$source_file")"

  if [[ -L "$target_file" ]] && ! deploy_force_enabled; then
    deploy_skip "$target_file" 'target is a symlink; another tool manages this path'
    # The repo still ships this file, so the manifest needs the entry for the
    # stale-file check. The "-" fingerprint keeps the rule below from ever
    # treating a file we refused to touch as one we deployed.
    deploy_record_manifest_entry "$rel" '-'
    DOTFILES_LAST_ACTION="skipped"
    return 0
  fi

  deploy_record_manifest_entry "$rel" "$fingerprint"

  if files_match "$source_file" "$target_file"; then
    return 0
  fi

  # The target differs, but if the repo copy is the same one the last deploy
  # wrote, the difference came from this machine - a hand edit, or a tool like
  # the AI router rewriting its own exports. Overwriting it would throw that
  # away and hand it straight back on the next run, one backup at a time. The
  # repo has nothing new to offer here, so the local version stays.
  if [[ -e "$target_file" ]] && ! deploy_force_enabled; then
    previous="$(deploy_prev_fingerprint "$rel" || true)"
    if [[ -n "$previous" && "$previous" == "$fingerprint" ]]; then
      printf 'Kept local change: %s (this repo has not changed it since deploying it; --force overwrites)\n' \
        "$target_file"
      DOTFILES_LAST_ACTION="kept"
      return 0
    fi
  fi

  if ! backup_target "$target_file" "$stamp"; then
    deploy_skip "$target_file" 'could not be moved aside, so it was not replaced'
    DOTFILES_LAST_ACTION="skipped"
    return 0
  fi
  if ! cp "$source_file" "$target_file"; then
    # The original is already at DOTFILES_BACKUP_PATH. Record it so uninstall
    # can put it back, and say so rather than leaving a hole with no history.
    ledger_record "$source_rel" "$target_file" "$DOTFILES_BACKUP_PATH"
    deploy_skip "$target_file" "could not be written; the previous file is at ${DOTFILES_BACKUP_PATH:-none}"
    DOTFILES_LAST_ACTION="skipped"
    return 0
  fi
  sync_file_mode "$source_file" "$target_file"
  ledger_record "$source_rel" "$target_file" "$DOTFILES_BACKUP_PATH"

  if [[ -n "$DOTFILES_BACKUP_PATH" ]]; then
    DOTFILES_LAST_ACTION="updated"
  else
    DOTFILES_LAST_ACTION="created"
  fi
}

deploy_directory() {
  local source_dir="$1"
  local target_dir="$2"
  local source_rel="$3"
  local stamp="$4"
  local dir_backup="" entry rel target_entry prefix prune_hit entry_recorded
  local created=0 updated=0 unchanged=0 kept=0 skipped=0
  local -a pruned

  pruned=()
  deploy_load_manifest "$target_dir"

  if [[ -L "$target_dir" ]]; then
    if ! deploy_force_enabled; then
      deploy_skip "$target_dir" 'target is a symlink; another tool manages this path'
      return 0
    fi
    if ! backup_target "$target_dir" "$stamp"; then
      deploy_skip "$target_dir" 'could not be moved aside, so it was not replaced'
      return 0
    fi
    dir_backup="$DOTFILES_BACKUP_PATH"
  elif [[ -e "$target_dir" && ! -d "$target_dir" ]]; then
    if ! backup_target "$target_dir" "$stamp"; then
      deploy_skip "$target_dir" 'could not be moved aside, so it was not replaced'
      return 0
    fi
    dir_backup="$DOTFILES_BACKUP_PATH"
  fi

  if [[ ! -d "$target_dir" ]]; then
    if ! mkdir "$target_dir" 2>/dev/null; then
      deploy_skip "$target_dir" 'could not create this directory'
      return 0
    fi
    ledger_record "$source_rel" "$target_dir" "$dir_backup"
  fi

  while IFS= read -r entry; do
    rel="${entry#"$source_dir/"}"
    target_entry="$target_dir/$rel"

    prune_hit=0
    for prefix in ${pruned[@]+"${pruned[@]}"}; do
      case "$rel" in
        "$prefix"*)
          prune_hit=1
          break
          ;;
      esac
    done
    [[ "$prune_hit" -eq 0 ]] || continue

    if [[ -L "$entry" ]]; then
      # This repo ships plain files only. Copying a symlink's target under its
      # name, or recreating the link, are both guesses; refuse instead.
      deploy_skip "$entry" 'source is a symlink; this repo only deploys plain files'
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -d "$entry" ]]; then
      entry_recorded=0

      if [[ -L "$target_entry" ]]; then
        if ! deploy_force_enabled; then
          deploy_skip "$target_entry" 'target is a symlink; another tool manages this path'
          pruned+=("$rel/")
          skipped=$((skipped + 1))
          continue
        fi
        if ! backup_target "$target_entry" "$stamp"; then
          deploy_skip "$target_entry" 'could not be moved aside, so it was not replaced'
          pruned+=("$rel/")
          skipped=$((skipped + 1))
          continue
        fi
        ledger_record "$source_rel/$rel" "$target_entry" "$DOTFILES_BACKUP_PATH"
        entry_recorded=1
      elif [[ -e "$target_entry" && ! -d "$target_entry" ]]; then
        if ! backup_target "$target_entry" "$stamp"; then
          deploy_skip "$target_entry" 'could not be moved aside, so it was not replaced'
          pruned+=("$rel/")
          skipped=$((skipped + 1))
          continue
        fi
        ledger_record "$source_rel/$rel" "$target_entry" "$DOTFILES_BACKUP_PATH"
        entry_recorded=1
      fi

      if [[ ! -d "$target_entry" ]]; then
        if ! mkdir "$target_entry" 2>/dev/null; then
          deploy_skip "$target_entry" 'could not create this directory'
          pruned+=("$rel/")
          skipped=$((skipped + 1))
          continue
        fi
        [[ "$entry_recorded" -eq 1 ]] || ledger_record "$source_rel/$rel" "$target_entry" ""
      fi

      continue
    fi

    deploy_single_file "$entry" "$target_entry" "$source_rel/$rel" "$stamp" "$rel"
    case "$DOTFILES_LAST_ACTION" in
      created)
        created=$((created + 1))
        ;;
      updated)
        updated=$((updated + 1))
        ;;
      kept)
        kept=$((kept + 1))
        ;;
      skipped)
        skipped=$((skipped + 1))
        ;;
      *)
        unchanged=$((unchanged + 1))
        ;;
    esac
  done < <(find "$source_dir" -mindepth 1 | LC_ALL=C sort)

  if [[ "$created" -eq 0 && "$updated" -eq 0 && "$skipped" -eq 0 ]]; then
    printf 'Unchanged: %s (%s files' "$target_dir" "$unchanged"
    if [[ "$kept" -gt 0 ]]; then
      printf ', %s kept as changed here' "$kept"
    fi
    printf ')\n'
  else
    printf 'Deployed: %s -> %s (%s new, %s updated, %s unchanged' \
      "$source_rel" "$target_dir" "$created" "$updated" "$unchanged"
    if [[ "$kept" -gt 0 ]]; then
      printf ', %s kept' "$kept"
    fi
    if [[ "$skipped" -gt 0 ]]; then
      printf ', %s skipped' "$skipped"
    fi
    printf ')\n'
  fi

  deploy_save_manifest "$target_dir"
}

# Deliberate asymmetry: a file the repo ships is written to the target, but a
# file in the target the repo does not ship is never removed. The cost is an
# orphan left behind when this repo drops a file upstream, which
# deploy_save_manifest names explicitly. The alternative - deleting what the
# source does not contain - cannot tell an upstream deletion from a file the
# user wrote next to ours, and that is exactly the data loss this engine exists
# to stop.
deploy_repo_path() {
  local repo_root="$1"
  local source_rel="$2"
  local target="$3"
  local stamp="$4"
  local source_path="$repo_root/$source_rel"

  require_repo_path "$source_path"

  if ! ensure_deploy_dir "$(dirname "$target")" "$source_rel"; then
    return 0
  fi

  if [[ -d "$source_path" && ! -L "$source_path" ]]; then
    deploy_directory "$source_path" "$target" "$source_rel" "$stamp"
    return 0
  fi

  deploy_load_manifest "$target"
  deploy_single_file "$source_path" "$target" "$source_rel" "$stamp" '.'
  case "$DOTFILES_LAST_ACTION" in
    unchanged)
      printf 'Unchanged: %s\n' "$target"
      ;;
    kept|skipped)
      ;;
    *)
      printf 'Deployed: %s -> %s\n' "$source_rel" "$target"
      ;;
  esac
  deploy_save_manifest "$target"
}
