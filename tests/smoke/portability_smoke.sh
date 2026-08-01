#!/usr/bin/env bash
set -euo pipefail

# Pins the two awk portability bugs that shipped past a fully green test suite.
#
# 1. `awk -v index=...` parses, but referencing `index` in the program body is a
#    syntax error on the awk macOS ships, because `index` is a built-in function
#    name. bootstrap/lib/advisor.sh carried that for the whole life of the
#    advisor: every call returned nothing and printed a raw awk error, so the
#    interactive fixed-display chooser rejected every number a user typed.
#
# 2. `printf "...%s\\n"` inside a single-quoted awk program emits a literal
#    backslash followed by n, not a newline. app-defaults.sh appended those two
#    characters to a workspace name, which then failed every comparison
#    downstream and silently placed the window on the last workspace instead.
#
# Both are invisible to `bash -n` and to any test that only asserts on happy
# paths, so they get a scanner of their own.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/assert.sh
. "$repo_root/tests/smoke/lib/assert.sh"

# POSIX awk built-in functions and special variables. Using any of these as a
# -v assignment name is a syntax error the moment the program body reads it.
awk_reserved='index length substr split sub gsub match sprintf printf int sqrt
exp log sin cos atan2 rand srand tolower toupper system close getline
NR NF FS OFS ORS RS FILENAME SUBSEP RSTART RLENGTH ENVIRON'

sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/portability-smoke.XXXXXX")"
trap 'rm -rf "$sandbox_root"' EXIT

# Whole-line comments are stripped before scanning: this file and advisor.sh
# both *describe* the bad pattern in prose, and a scanner that flags its own
# documentation is a scanner people turn off.
strip_comments() {
  /usr/bin/sed 's/^[[:space:]]*#.*$//' "$1"
}

# --- 1. no awk -v assignment shadows a built-in name ------------------------

collisions="$sandbox_root/collisions"
: >"$collisions"

while IFS= read -r script; do
  [ -n "$script" ] || continue
  # This file carries both bad shapes on purpose, as the fixtures the negative
  # controls at the bottom run against. Scanning itself would report them as
  # findings forever.
  [ "$script" != 'tests/smoke/portability_smoke.sh' ] || continue
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    for reserved in $awk_reserved; do
      if [ "$name" = "$reserved" ]; then
        printf '%s: -v %s=\n' "$script" "$name" >>"$collisions"
      fi
    done
  done <<EOF
$(strip_comments "$repo_root/$script" \
  | /usr/bin/grep -oE '\-v[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=' \
  | /usr/bin/sed 's/-v[[:space:]]*//; s/=$//' || true)
EOF
done <<EOF
$(cd "$repo_root" && git ls-files '*.sh' 2>/dev/null || true)
EOF

assert_equal "" "$(cat "$collisions")" 'no awk -v assignment may shadow an awk built-in name'

# --- 2. no doubled escape inside an awk format string -----------------------

doubled="$sandbox_root/doubled"
: >"$doubled"

while IFS= read -r script; do
  [ -n "$script" ] || continue
  # This file carries both bad shapes on purpose, as the fixtures the negative
  # controls at the bottom run against. Scanning itself would report them as
  # findings forever.
  [ "$script" != 'tests/smoke/portability_smoke.sh' ] || continue
  strip_comments "$repo_root/$script" \
    | /usr/bin/grep -nE 'awk' >/dev/null 2>&1 || continue
  # A backslash-escaped backslash followed by n or t, anywhere in a file that
  # also calls awk. In a single-quoted awk program that is a literal \n.
  strip_comments "$repo_root/$script" \
    | /usr/bin/grep -nE '\\\\[nt]' \
    | /usr/bin/sed "s|^|$script:|" >>"$doubled" 2>/dev/null || true
done <<EOF
$(cd "$repo_root" && git ls-files '*.sh' 2>/dev/null || true)
EOF

assert_equal "" "$(cat "$doubled")" 'no awk program may contain a doubled \\n or \\t escape'

# --- 3. single-line inline awk programs parse under the macOS awk -----------
#
# Best effort by design: only programs written entirely inside one pair of
# single quotes on one line are extracted. Multi-line programs are common here
# and are left to the suites that execute them.

unparseable="$sandbox_root/unparseable"
: >"$unparseable"
program_count=0

while IFS= read -r script; do
  [ -n "$script" ] || continue
  # This file carries both bad shapes on purpose, as the fixtures the negative
  # controls at the bottom run against. Scanning itself would report them as
  # findings forever.
  [ "$script" != 'tests/smoke/portability_smoke.sh' ] || continue
  while IFS= read -r program; do
    [ -n "$program" ] || continue
    case "$program" in
      *'{'*|*'}'*) ;;
      *) continue ;;
    esac
    program_count=$((program_count + 1))
    if ! printf '' | /usr/bin/awk "$program" >/dev/null 2>"$sandbox_root/awk.err"; then
      if [ -s "$sandbox_root/awk.err" ]; then
        printf '%s: %s\n  %s\n' "$script" "$program" \
          "$(/usr/bin/head -n 1 "$sandbox_root/awk.err")" >>"$unparseable"
      fi
    fi
  done <<EOF
$(strip_comments "$repo_root/$script" \
  | /usr/bin/grep -oE "awk[^']*'[^']*'" \
  | /usr/bin/sed "s/^awk[^']*'//; s/'$//" || true)
EOF
done <<EOF
$(cd "$repo_root" && git ls-files '*.sh' 2>/dev/null || true)
EOF

assert_equal "" "$(cat "$unparseable")" 'every single-line inline awk program must parse under /usr/bin/awk'
assert_nonzero "$program_count" 'the awk program scanner must actually find programs to check'

# --- 4. the scanner itself catches the two known-bad shapes -----------------
#
# A scanner nobody has seen fail is indistinguishable from a scanner that
# matches nothing, so both patterns are exercised against a synthetic file.

bad="$sandbox_root/bad_sample.sh"
cat >"$bad" <<'SAMPLE'
#!/usr/bin/env bash
lookup() {
  /usr/bin/awk -F '|' -v index="$2" '{ if (NR == index) print $1 }' "$1"
}
merge() {
  /usr/bin/awk -F '|' '{ printf "%s|%s\\n", $1, $2 }'
}
SAMPLE

sample_names="$(strip_comments "$bad" \
  | /usr/bin/grep -oE '\-v[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=' \
  | /usr/bin/sed 's/-v[[:space:]]*//; s/=$//')"
assert_contains "$sample_names" 'index' 'the -v scanner must see a shadowing assignment'

sample_doubled="$(strip_comments "$bad" | /usr/bin/grep -cE '\\\\[nt]' || true)"
assert_equal "1" "$sample_doubled" 'the escape scanner must see a doubled \\n'

if printf '' | /usr/bin/awk '{ if (NR == index) print $1 }' >/dev/null 2>&1; then
  fail 'macOS awk must reject index used as a variable' 'it parsed, so check 1 is not load-bearing'
else
  pass
fi

smoke_summary "$(basename "$0")"
