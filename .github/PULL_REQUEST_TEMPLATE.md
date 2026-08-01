<!--
The bar here is less "is this a good idea" and more "does this stay true on a
machine that is not the author's". CONTRIBUTING.md has the rules that are not
negotiable; this is the short version of proving you met them.
-->

## What breaks without this

<!-- Not what the change does - the diff says that. What goes wrong today. -->

## How you know it works

<!--
Paste the commands and their output. "Tests pass" is not evidence; the suite
passing before and after a change proves nothing about the change.

If you fixed something, show it failing first:

    git stash                      # or revert your fix
    bash tests/smoke/<suite>.sh    # must go red, and for your reason
    git stash pop
    bash tests/smoke/<suite>.sh    # green
-->

## Checklist

- [ ] `bash tests/run-all.sh` passes. It runs every suite twice — once against a
      `$HOME` with nothing installed, once against one where `author-full` is
      deployed — because a suite that reads the machine instead of its fixtures
      is green on one and red on the other.
- [ ] There is a test for what changed, and it fails without the change.
- [ ] Nothing writes to `$HOME` except `deploy_repo_path`.
- [ ] No `/Users/<name>` and no new `/opt/homebrew`-shaped absolute path.
      `privacy_scan_smoke.sh` fails the build on both.
- [ ] Runs on bash 3.2. No `declare -A`, no `mapfile`, no `${var,,}`, no
      negative array indices.
- [ ] If a public module changed: `bootstrap/catalog.sh`, the choice docs and
      `choice_architecture_smoke.sh` agree with it, and `--dry-run` says the
      truth about which packages and paths it touches.

## Machine you ran it on

<!--
macOS version, Apple Silicon or Intel, how many displays, and whether this
repository was already installed. Two of the bugs in this history only appeared
on a machine that had it deployed, and one only on a desk whose main display is
not the window manager's monitor 1.
-->
