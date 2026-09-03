#!/usr/bin/env bash
# Print the FULL 32-character change id of a revision, and verify it resolves.
#
# Usage: jj-change-id.sh --repo DIR REVSET
#        jj-change-id.sh --repo DIR --check ID [ID...]
#
# A short change-id prefix is fine — `jj log` prints 8 characters by default and
# guarantees the displayed prefix is unique, so producers legitimately emit them
# and rejecting them fails healthy runs. What is NOT fine is an id that was
# reconstructed rather than read: a prefix padded out with invented characters
# resolves to nothing, and a reviewer handed an unresolvable `base_change` does
# not error — it quietly reviews the wrong range.
#
# So the test is resolution, not length. --check resolves every id and prints
# the full 32-character form, which is what belongs in task-record.json.
#
# --check also rejects a bare COMMIT id. `jj log -r` accepts one as a revset, so
# an earlier version of this script resolved it and printed `ok` — positively
# confirming the one id class the skill forbids. That matters because §4.6's
# `jj describe` rewrites the commit id of every earlier change in the task: a
# commit id resolves cleanly now and to nothing afterwards, leaving a task
# record that is valid until finalisation and silently dangling after it. A
# commit id is the dangerous malformation precisely because it does resolve.

. "$(dirname "$0")/_common.sh"

REPO= MODE=print
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --check) MODE=check; shift;;
    *) break;;
  esac
done
[ -n "$REPO" ] && [ $# -gt 0 ] || die "usage: $0 --repo DIR REVSET | $0 --repo DIR --check ID..."
need jj
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"

if [ "$MODE" = check ]; then
  rc=0
  for id in "$@"; do
    mapfile -t rows < <(jj -R "$REPO" log --no-graph -r "$id" \
                          -T 'change_id ++ " " ++ commit_id ++ "\n"' 2>/dev/null | grep .)
    case "${#rows[@]}" in
      1) full=${rows[0]% *}; commit=${rows[0]#* }
         # An id that prefixes the commit id but not the change id is a commit
         # id. Loud, not `ok` — see the header.
         if [ "${full#"$id"}" = "$full" ] && [ "${commit#"$id"}" != "$commit" ]; then
           printf 'COMMIT-ID  %s is a COMMIT id of change %s — do not use it\n' "$id" "$full"
           rc=1
         elif [ "$id" = "$full" ]; then
           printf 'ok         %s\n' "$id"
         else
           printf 'ok         %s -> %s\n' "$id" "$full"
         fi;;
      0) printf 'UNRESOLVED %s\n' "$id"; rc=1;;
      *) printf 'AMBIGUOUS  %s (%s matches)\n' "$id" "${#rows[@]}"; rc=1;;
    esac
  done
  exit $rc
fi

out=$(jj -R "$REPO" log --no-graph -r "$1" -T 'change_id ++ "\n"' 2>&1) \
  || die "revset did not resolve: $1: $out"
n=$(printf '%s\n' "$out" | grep -c .)
[ "$n" = 1 ] || die "revset '$1' resolved to $n changes; expected exactly one"
printf '%s\n' "$out"
