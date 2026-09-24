#!/bin/sh
# Purpose: answer whether SWI-Prolog's trie_gen/2 still dies on a trie whose
#   root trie_delete/3 emptied after it had grown a hashed children table. A
#   child inserts two keys, deletes both and collects trie_gen/2. Prints
#   `present` when that child dies of SIGSEGV and `absent` when it answers the
#   empty list.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter
# Guarantees:
#   - exit 139 answers present and a clean exit that printed `[]` answers
#     absent; anything else is a broken reproduction, a trie that still
#     answers a deleted key included, so the condition cannot pass unexercised
#     [measured 2026-09-24: present on SWI-Prolog 10.1.14 built with the
#     ledger's patches, both the 09-16 and the 09-24 builds, while one key
#     inserted and deleted answers `[]` and two keys with one deleted answer
#     `[a]`; commit=WORKTREE]
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
    139) printf 'present\n' ;;
    *) cat "$scratch/stderr" >&2; exit "$status" ;;
esac
