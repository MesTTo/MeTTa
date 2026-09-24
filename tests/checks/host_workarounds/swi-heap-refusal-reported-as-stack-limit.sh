#!/bin/sh
# Purpose: answer whether SWI-Prolog still reports a stack the HEAP refused to
#   grow as a stack over its limit. grow_stacks() in src/pl-gc.c returns the
#   stack's overflow code when stack_realloc() fails, the code a stack at its
#   limit returns, so the process reads "Stack limit (...) exceeded" while the
#   stack is far inside its limit and the resource that ran out is memory. A
#   process whose address space is capped at 1 GB builds a list with its stack
#   limit at 8 GB, so the limit cannot be what stops it. Prints `present` when
#   the refusal arrives as resource_error(stack), and `absent` when it arrives
#   as resource_error(no_memory), SWI's name for memory that is not there.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter
#   - ulimit -v caps the address space, which glibc's and tcmalloc's malloc
#     both answer with NULL rather than a kill
# Guarantees:
#   - a list that is built, or any other error, is a broken reproduction
#     (exit 1), so a cap that stopped binding cannot read as either answer
#     [measured 2026-09-24: present on SWI-Prolog 10.1.14 built with the
#     ledger's other patches, globalused 524,287 KB against a stack_limit of
#     7,812,500 KB]
# Owns resources: bounded.sh joins the child; the lane removes the scratch
#   files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

if ( ulimit -v 1000000
     exec sh "$root/tools/bounded.sh" --memory none "$swipl" -q -f none \
         -g "set_prolog_flag(stack_limit, 8000000000), catch((numlist(1, 200000000, L), length(L, N), format('built ~w~n', [N])), error(Formal, _), format('refused ~q~n', [Formal]))" \
         -t halt ) < /dev/null > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
if [ "$status" -ne 0 ]; then
    cat "$scratch/stdout" "$scratch/stderr" >&2
    exit "$status"
fi
if grep -qx 'refused resource_error(no_memory)' "$scratch/stdout"; then
    printf 'absent\n'
elif grep -qx 'refused resource_error(stack)' "$scratch/stdout"; then
    printf 'present\n'
else
    cat "$scratch/stdout" "$scratch/stderr" >&2
    exit 1
fi
