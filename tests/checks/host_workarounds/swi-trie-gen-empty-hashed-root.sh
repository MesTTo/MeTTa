#!/bin/sh
# Purpose: answer whether SWI-Prolog's trie_gen/2 still dies on a trie whose
#   root trie_delete/3 emptied after it had grown a hashed children table. A
#   child inserts two keys, deletes both and collects trie_gen/2. Prints
#   `present` when that child dies in trie_gen_raw() and `absent` when it
#   answers the empty list.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter
# Guarantees:
#   - a child killed by a signal answers present only when its stderr carries
#     SWI's own report of that crash, `Received fatal signal 11 (segv)` with
#     `trie_gen_raw()` in the C-stack trace; a clean exit that printed `[]`
#     answers absent; anything else is a broken reproduction, a trie that
#     still answers a deleted key included, so the condition cannot pass
#     unexercised. SWI's crash handler prints that report and then either dies
#     of the fault again while printing the Prolog stack, exit 139, or
#     finishes printing it and aborts, exit 134, so the exit status alone does
#     not tell the defect from another crash; this is a death test in
#     GoogleTest's sense, the death and the message both asserted [measured
#     2026-09-24: present on SWI-Prolog 10.1.14 built with the ledger's
#     patches, the 09-16 and the 09-24 builds, exiting 139 run by hand and
#     134 under tools/check.sh host-workarounds, both after SWI's report
#     naming trie_gen_raw(), while one key inserted and deleted answers `[]`
#     and two keys with one deleted answer `[a]`;
#     commit=62bcb06e607abcd689780d693c304953e807213e]
#   [source: https://google.github.io/googletest/advanced.html#death-tests]
# Owns resources: bounded.sh joins the child; the lane removes the scratch files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

emptied='trie_new(T), trie_insert(T, a), trie_insert(T, b), trie_delete(T, a, _), trie_delete(T, b, _), findall(K, trie_gen(T, K), Ks), print(Ks), nl'
if sh "$root/tools/bounded.sh" "$swipl" -q -f none -g "$emptied" -t halt \
        < /dev/null > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
case $status in
    0)
        if [ "$(cat "$scratch/stdout")" = "[]" ]; then
            printf 'absent\n'
        else
            cat "$scratch/stdout" "$scratch/stderr" >&2
            exit 1
        fi ;;
    134|139)
        if grep -Fq 'Received fatal signal 11 (segv)' "$scratch/stderr" &&
            grep -Fq 'trie_gen_raw()' "$scratch/stderr"; then
            printf 'present\n'
        else
            cat "$scratch/stderr" >&2
            exit "$status"
        fi ;;
    *) cat "$scratch/stderr" >&2; exit "$status" ;;
esac
