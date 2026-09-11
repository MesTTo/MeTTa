#!/bin/sh
# Purpose: reproduce the QLF loader's failed-include source-module corruption
#   in plain SWI, with no engine or Janus loaded.
# Assumes: HOST_WORKAROUND_SCRATCH is a private writable directory; SWIPL names
#   the host interpreter.
# Guarantees: present means the QLF that loads with its optional entry disabled
#   dies with signal 11 when replay loads that entry's missing include
#   [tested: sh check.sh host-workarounds; commit=WORKTREE].
# Owns resources: only the supplied scratch tree is written; bounded.sh reaps
#   children, and core files are disabled for the deliberate crash.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
bounded() { sh "$root/bounded.sh" "$@"; }
ulimit -c 0

cat > "$scratch/unit.pl" <<'PL'
:- module(qlf_failed_include_probe, [after_entry/1]).
:- user:import(qlf_failed_include_probe:after_entry/1).
:- current_prolog_flag(argv, Args),
   ( memberchk(load_entry, Args) -> user:ensure_loaded('entry.pl'); true ).
after_entry(hello).
PL
cat > "$scratch/entry.pl" <<'PL'
:- include('missing-qlf-include.pl').
PL
cd "$scratch"
bounded "$swipl" -q -f none --no-packs -g 'qcompile(unit)' -t halt
bounded "$swipl" -q -f none --no-packs \
    -g 'set_prolog_flag(qcompile,auto),ensure_loaded(unit),qlf_failed_include_probe:after_entry(hello),halt' \
    > control.log 2>&1

status=0
{ bounded "$swipl" -q -f none --no-packs \
    -g "set_prolog_flag(qcompile,auto),catch(ensure_loaded(unit),E,(writeq(E),nl,write('safe-refusal'),nl,halt)),qlf_failed_include_probe:after_entry(hello),write('safe-replay'),nl,halt" \
    -- load_entry > replay.log 2>&1 || status=$?; } 2> shell.log
# The reporter can itself abort while reading the corrupted stack. Accept that
# status only with its specific assertion and the original signal-11 report.
if { [ "$status" -eq 139 ] ||
     { [ "$status" -eq 134 ] &&
       grep -Fq 'stack_avail___LD: Assertion failed: avail > 0' replay.log; }; } &&
   grep -Fq 'Received fatal signal 11 (segv)' replay.log &&
   grep -Fq 'missing-qlf-include.pl' replay.log; then
    printf 'present\n'
elif [ "$status" -eq 0 ] && grep -Eq '^safe-(refusal|replay)$' replay.log; then
    printf 'absent\n'
else
    cat control.log replay.log shell.log >&2
    printf 'undecided: QLF replay exited %s\n' "$status"
    exit 1
fi
