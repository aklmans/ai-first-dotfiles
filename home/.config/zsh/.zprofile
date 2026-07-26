# Login-shell setup.
#
# This repo puts everything it needs in .zshrc and env.zsh, which every
# interactive shell reads, so there is nothing here of its own.
#
# Vendor CLIs that offer to "add themselves to your shell" write pre/post blocks
# into this file once ZDOTDIR points at this directory. This file is deployed by
# this repo, so a later update can replace it and take those blocks with it -
# their tools then break with no visible cause. Put such blocks in
# private.zprofile instead: never tracked, never deployed, never overwritten.
if [[ -f "$ZDOTDIR/private.zprofile" ]]; then
  source "$ZDOTDIR/private.zprofile"
fi
