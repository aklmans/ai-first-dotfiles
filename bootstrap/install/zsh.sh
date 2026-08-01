#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"
repo_root="$(repo_root_dir)"
stamp="$(date +%Y%m%d_%H%M%S)"
parse_install_args "$@"

zdotdir="$HOME/.config/zsh"
rescue_copy="$zdotdir/.zshrc.pre-dotfiles"
takeover_declined=0

# ---------------------------------------------------------------------------
# Handing zsh startup over to $ZDOTDIR
#
# home/.zshenv holds one line: export ZDOTDIR="$HOME/.config/zsh". Deploying it
# is the most invasive thing in this repository. From the next shell on, zsh
# reads .zshrc, .zprofile and .zlogin out of that directory and never opens
# ~/.zshrc again. The old file is not deleted, not moved, not mentioned: it
# simply stops running. From the outside that is indistinguishable from a shell
# configuration that vanished, and there is nothing left to search for.
#
# So this is not done silently. The takeover is explained, a copy of the file
# that is about to go quiet is left inside the directory taking over, and a yes
# is required first. Runs without a terminal get the explanation and keep their
# ~/.zshrc; --force (DOTFILES_FORCE=1) is how automation says yes in advance.
# ---------------------------------------------------------------------------

# True when zsh already reads its startup files from somewhere other than ~,
# because this repo deployed before or the user set ZDOTDIR themselves. The
# takeover has already happened, so there is no new consequence to warn about
# and asking again on every redeploy would only teach people to skip the text.
zshenv_redirects_zdotdir() {
  [[ -f "$HOME/.zshenv" ]] || return 1
  # An assignment, not the word in a comment: a commented-out ZDOTDIR line
  # leaves ~/.zshrc alive, and that case still deserves the warning.
  grep -Eq '^[^#]*ZDOTDIR[[:space:]]*=' "$HOME/.zshenv" 2>/dev/null
}

# Both ends must be a terminal. `zsh.sh | grep` leaves stdin on the tty while
# nobody can see the question, and CI hands over /dev/null or a closed pipe;
# waiting for an answer in either case is a hang, not a confirmation.
can_prompt() {
  [[ -t 0 ]] && [[ -t 1 ]]
}

# A copy, never a move: ~/.zshrc has to keep working the moment ZDOTDIR goes
# away again. Written once, so a later run cannot replace the original rescue
# copy. Returns 0 only when this run created it, so the note is printed once.
create_rescue_copy() {
  [[ -e "$rescue_copy" || -L "$rescue_copy" ]] && return 1
  ensure_deploy_dir "$zdotdir" 'home/.config/zsh' || return 1
  cp "$HOME/.zshrc" "$rescue_copy" 2>/dev/null || return 1
  return 0
}

warn_zshrc_takeover() {
  printf '\n' >&2
  printf 'WARNING: deploying ~/.zshenv stops your existing ~/.zshrc from loading.\n' >&2
  printf '\n' >&2
  printf '  ~/.zshenv from this repo contains one line:\n' >&2
  printf '      export ZDOTDIR="%s"\n' "$zdotdir" >&2
  printf '  From your next shell on, zsh reads .zshrc, .zprofile and .zlogin from\n' >&2
  printf '  %s and never opens ~/.zshrc again.\n' "$zdotdir" >&2
  printf '\n' >&2
  printf '  Your ~/.zshrc is not deleted and not edited. It stops running, silently.\n' >&2

  if [[ -f "$rescue_copy" ]]; then
    printf '  A copy of it has been saved as:\n' >&2
    printf '      %s\n' "$rescue_copy" >&2
    printf '  Move what you want to keep from it into %s/private.zsh,\n' "$zdotdir" >&2
    printf '  which this repo never overwrites.\n' >&2
  else
    printf '  A copy of it could not be saved to %s.\n' "$rescue_copy" >&2
    printf '  Back ~/.zshrc up yourself before continuing.\n' >&2
  fi
  printf '\n' >&2
}

# Returns non-zero when ~/.zshenv must not be deployed on this run.
guard_zshrc_takeover() {
  local reply=''

  [[ -s "$HOME/.zshrc" ]] || return 0

  if zshenv_redirects_zdotdir; then
    if create_rescue_copy; then
      printf 'Note: ~/.zshrc is already out of the loop here - ~/.zshenv points ZDOTDIR at %s.\n' "$zdotdir"
      printf '      Copied it to %s so it can be found again.\n' "$rescue_copy"
    fi
    return 0
  fi

  create_rescue_copy || true
  warn_zshrc_takeover

  if deploy_force_enabled; then
    printf '  --force given: handing zsh startup over.\n\n' >&2
    return 0
  fi

  if ! can_prompt; then
    printf '  Nothing is being asked because this is not an interactive terminal, so\n' >&2
    printf '  ~/.zshenv was left alone and your ~/.zshrc still runs. Re-run with\n' >&2
    printf '  --force (or DOTFILES_FORCE=1) to hand zsh startup over.\n\n' >&2
    takeover_declined=1
    return 1
  fi

  printf '  Hand zsh startup over to %s? [y/N] ' "$zdotdir" >&2
  IFS= read -r reply || reply=''
  printf '\n' >&2

  # A terminal that sends CRLF, and closed stdin, both have to end up as "no"
  # rather than as an accidental yes.
  reply="${reply%$'\r'}"
  case "$reply" in
    [yY]|[yY][eE][sS])
      return 0
      ;;
  esac

  printf '  Left ~/.zshenv alone; your ~/.zshrc still runs. Re-run with --force\n' >&2
  printf '  (or DOTFILES_FORCE=1) when you want the takeover.\n\n' >&2
  takeover_declined=1
  return 1
}

if should_deploy; then
  deploy_zshenv=1
  if ! guard_zshrc_takeover; then
    deploy_zshenv=0
  fi

  if [[ "$deploy_zshenv" -eq 1 ]]; then
    deploy_repo_path "$repo_root" "home/.zshenv" "$HOME/.zshenv" "$stamp"
  fi

  deploy_repo_path "$repo_root" "home/.config/zsh/.zprofile" "$HOME/.config/zsh/.zprofile" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/.zshrc" "$HOME/.config/zsh/.zshrc" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/env.zsh" "$HOME/.config/zsh/env.zsh" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/plugins.zsh" "$HOME/.config/zsh/plugins.zsh" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/codex-widget.zsh" "$HOME/.config/zsh/codex-widget.zsh" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/aliases.zsh" "$HOME/.config/zsh/aliases.zsh" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/functions.zsh" "$HOME/.config/zsh/functions.zsh" "$stamp"
  # Template only. private.zsh itself is never tracked and never deployed, so
  # whatever the user puts in it survives every update of this repo.
  deploy_repo_path "$repo_root" "home/.config/zsh/private.zsh.example" "$HOME/.config/zsh/private.zsh.example" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/aliases.local.zsh.example" "$HOME/.config/zsh/aliases.local.zsh.example" "$stamp"
  deploy_repo_path "$repo_root" "home/.config/zsh/completions/_openclaw" "$HOME/.config/zsh/completions/_openclaw" "$stamp"
fi

if [[ "$takeover_declined" -eq 1 ]]; then
  printf '\n' >&2
  printf '~/.zshenv was not deployed, so nothing in %s is read yet.\n' "$zdotdir" >&2
  printf 'The rest of the config was written there and stays inert until ZDOTDIR\n' >&2
  printf 'points at it. Re-run with --force to finish the switch.\n' >&2
  exit 3
fi
