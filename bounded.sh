#!/bin/sh
# Purpose: start a process that cannot outlive both its deadline and the
#   process that started it. Every swipl, node and Python this repository
#   spawns goes through here, and so does a command typed by hand.
#
#   Usage: sh bounded.sh [--ceiling SECONDS] [--grace SECONDS] [--owner PID]
#                        COMMAND [ARG ...]
#          sh bounded.sh --enforcer      print the ceiling program and exit
#
#   Environment (the options above set these; either spelling works):
#     METTA_CHILD_CEILING   seconds before the ceiling fires (default 3600)
#     METTA_CHILD_GRACE     seconds between its TERM and its KILL (default 10)
#     METTA_TIMEOUT         the ceiling program, when it should not be chosen
#     METTA_BOUNDED_OWNER   the pid of the process whose death should reap this,
#                           read BEFORE the caller forked. A caller that knows
#                           its own pid closes the whole startup race with
#                           `--owner $$`; without it only the arming window is
#                           closed.
#
#   The ceiling and the grace are EXPORTED, so a command that bounds children
#   of its own inherits them: `bounded --ceiling 290 sh run.sh f.metta` gives
#   run.sh's swipl the same 290 rather than the default hour, which is the
#   tighter of the two and the one the caller asked for [measured 2026-09-05:
#   an inner call under `--ceiling 77` reads 77].
#
#   Two independent bounds, because either alone has a hole this repository has
#   already paid for.
#
#   The DEADLINE lives in a process that shares the command's fate rather than
#   the caller's. `subprocess.run(timeout=)` and a shell's own wait loop stop
#   enforcing the moment the waiter is killed, and sessions here are killed
#   routinely: two swipl children spawned by a repository runner ran from
#   2026-09-01 to 2026-09-03, spinning at 100% for 122 CPU-hours between them,
#   because the only bound on them lived in a process that was gone.
#
#   The OWNER LINK is `prctl(PR_SET_PDEATHSIG)`, set by setpriv(1), so a
#   command whose starter dies is reaped in milliseconds instead of burning
#   until the deadline. A deadline alone is what let a hand-started
#   `swipl ... materialization.plt` run 7,540 seconds at 97.8% CPU on
#   2026-09-05: it was outside every lane, so nothing bounded it at all.
#
# Assumes:
#   - a `timeout` on PATH, or one named by METTA_TIMEOUT. Without one this
#     refuses rather than running unbounded.
#   - setpriv(1) from util-linux for the owner link. Without it the deadline
#     still applies and the refusal to start is announced once, because a
#     silently weaker bound is the failure this file exists to prevent.
#   - it is EXEC'd into, never sourced. It adds no process of its own: every
#     rung replaces this one, so `ps` shows the command's own argv and the exit
#     status is the command's.
# Guarantees:
#   - the command's exit status, unchanged, including 128+n for a signalled
#     command [tested: tests/shell/test_bounded_reaping.sh]
#   - a command whose starter is SIGKILLed is gone within seconds rather than
#     at the deadline, and so is one that ignores SIGTERM
#     [tested: tests/shell/test_bounded_reaping.sh, which runs the same
#     scenario through the deadline-only wrapper as its negative control]
#   - the arming race is closed the way util-linux unshare(1) and Go's
#     syscall.StartProcess close it: the parent recorded before arming is
#     compared with the parent after arming, and a mismatch refuses to start
#     the command rather than running it with a signal that can never arrive
#   - `--enforcer` names the ceiling program, so a caller that spawns many
#     children resolves it once instead of per spawn
#   - the command runs headless: DISPLAY and WAYLAND_DISPLAY are unset before
#     anything starts, so a desktop run answers as the CI run does and no
#     lane can depend on the box's X session. With a display set, SWI-Prolog
#     loads xpce for a text profile/2 and a display whose GLX context
#     creation fails kills the process [measured 2026-09-15: `DISPLAY=:0 swipl
#     -g 'profile(true,[top(0)])'` exits 1 on X_GLXCreateContext BadValue and
#     the same call with DISPLAY unset runs; prolog-static, host-workarounds,
#     host-workarounds-selftest and the Python examples lane failed that way
#     on an unchanged tree and pass headless; SWI-Prolog 10.1.13;
#     commit=c4e75b3206191b8fd969a1449e75e928227883b8]
# Fails when:
#   - no `timeout` is reachable: exit 2, naming the package that ships one.
#   - the caller died before the signal was armed: exit 125, the same status
#     timeout(1) uses for a failure in the wrapper rather than the command.
#   - the caller is multi-threaded AND the running kernel delivers the
#     parent-death signal on the exit of the spawning THREAD rather than of the
#     process. Measured 2026-09-05 on Linux 7.0.0-30-generic: it does not, over
#     a pthread fork, a Python threading.Thread fork and a ThreadPoolExecutor
#     spawn, with PR_GET_PDEATHSIG read back as SIGKILL in the child and the
#     process-death control dying in the same binary. The property is pinned by
#     test_a_child_outlives_the_thread_that_spawned_it, so a kernel that
#     changes it says so by name instead of killing live children quietly.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -u
# Headless by construction: see the Guarantees above. The variables are
# unset here, before either exec path, so the deadline-only rung and the
# owner-linked rung start the command in the same environment.
unset DISPLAY WAYLAND_DISPLAY

# An absolute path to this file, because the arming rung re-enters it through
# setpriv's execvp, which does a PATH lookup on a name with no slash in it. The
# re-entry names /bin/sh explicitly rather than relying on the execute bit, so
# `sh bounded.sh ...` behaves the same as `./bounded.sh ...` and neither needs
# the file to be executable or its filesystem to allow exec.
case $0 in
    /*) metta_bounded_self=$0 ;;
    *)  metta_bounded_self=$PWD/$0 ;;
esac

# The ceiling program. `timeout` is not one implementation: GNU coreutils puts
# itself and the command in a fresh process group and signals the GROUP, so the
# escalation reaches what the command spawned, while the uutils reimplementation
# Ubuntu 25.10 installs over /usr/bin/timeout sends its SIGKILL to the command's
# pid alone [measured 2026-09-05: a grandchild that ignores SIGTERM survives
# `timeout --preserve-status -k 3 3` under uutils 0.8.0 and does not under GNU
# 9.7; the uutils source skips send_signal_group for KILL, src/uu/timeout/src/
# platform/unix.rs]. It is also 158 times more expensive per call, 102.78ms
# against 0.65ms, because it waits for the command on a 50ms sleep tick
# [measured 2026-09-05, 60 calls of `--preserve-status -k 10 3600 /bin/true`,
# min of three; strace -c attributes 100.1ms of 102.9ms to clock_nanosleep].
# So the GNU one is PREFERRED where the box has both, and any `timeout` is
# accepted where it does not.
metta_bounded_enforcer() {
    if [ -n "${METTA_TIMEOUT:-}" ]; then
        printf '%s\n' "$METTA_TIMEOUT"
        return 0
    fi
    metta_bounded_fallback=''
    for metta_bounded_candidate in timeout gnutimeout gtimeout; do
        metta_bounded_found=$(command -v "$metta_bounded_candidate" 2>/dev/null) ||
            continue
        [ -n "$metta_bounded_found" ] || continue
        [ -n "$metta_bounded_fallback" ] || metta_bounded_fallback=$metta_bounded_found
        case $("$metta_bounded_found" --version 2>/dev/null | head -1) in
            *"GNU coreutils"*) printf '%s\n' "$metta_bounded_found"; return 0 ;;
        esac
    done
    [ -n "$metta_bounded_fallback" ] || return 1
    printf '%s\n' "$metta_bounded_fallback"
}

if [ "${1:-}" = "--enforcer" ]; then
    metta_bounded_enforcer
    exit $?
fi

# --ceiling and --grace rather than only the environment variables, because
# most callers reach this through a one-line `bounded()` shell function and
# POSIX leaves it UNSPECIFIED whether `VAR=x somefunction` keeps VAR set after
# the call; dash keeps it, so one example's tighter ceiling would silently
# become every later example's.
while [ "$#" -gt 0 ]; do
    case $1 in
        --ceiling) [ "$#" -ge 2 ] || { echo "bounded.sh: --ceiling needs a value" >&2; exit 2; }
                   METTA_CHILD_CEILING=$2; export METTA_CHILD_CEILING; shift 2 ;;
        --grace)   [ "$#" -ge 2 ] || { echo "bounded.sh: --grace needs a value" >&2; exit 2; }
                   METTA_CHILD_GRACE=$2; export METTA_CHILD_GRACE; shift 2 ;;
        --owner)   [ "$#" -ge 2 ] || { echo "bounded.sh: --owner needs a pid" >&2; exit 2; }
                   METTA_BOUNDED_OWNER=$2; export METTA_BOUNDED_OWNER; shift 2 ;;
        --)        shift; break ;;
        *)         break ;;
    esac
done

if [ "$#" -eq 0 ]; then
    echo "usage: sh bounded.sh [--ceiling SECONDS] [--grace SECONDS]" >&2
    echo "                     [--owner PID] COMMAND [ARGUMENT ...]" >&2
    echo "       sh bounded.sh --enforcer" >&2
    exit 2
fi

# ---------------------------------------------------------------- second pass
# The same process, after setpriv armed the parent-death signal on it. The
# comparison below is the whole point of re-entering: prctl(PR_SET_PDEATHSIG)
# cannot deliver a signal for a parent that had already exited when it was
# armed, so the canonical implementations record the parent before arming and
# compare it after [util-linux sys-utils/unshare.c, which opens a pidfd for the
# parent before forking and polls it after the prctl; Go syscall/exec_linux.go,
# which compares getppid() with the saved pid and signals itself on mismatch].
if [ -n "${METTA_BOUNDED_ARMED:-}" ]; then
    if [ "$PPID" != "$METTA_BOUNDED_ARMED" ]; then
        echo "bounded.sh: the process that started this exited while the" >&2
        echo "  parent-death signal was being armed, so the signal can never" >&2
        echo "  arrive. Refusing to start: $1" >&2
        exit 125
    fi
    metta_bounded_ceiling=${METTA_CHILD_CEILING:-3600}
    metta_bounded_grace=${METTA_CHILD_GRACE:-10}
    metta_bounded_timeout=${METTA_TIMEOUT:?bounded.sh: no ceiling program}
    metta_bounded_setpriv=${METTA_BOUNDED_SETPRIV:?bounded.sh: no setpriv}
    unset METTA_BOUNDED_ARMED METTA_BOUNDED_OWNER METTA_BOUNDED_SETPRIV
    # The inner rung. Its parent is the ceiling program, a single-threaded
    # process, so this one cannot fire on a thread's exit whatever the kernel
    # does; it is what keeps the command from surviving a ceiling program that
    # is SIGKILLed rather than asked to stop.
    exec "$metta_bounded_timeout" --preserve-status \
        -k "$metta_bounded_grace" "$metta_bounded_ceiling" \
        "$metta_bounded_setpriv" --pdeathsig SIGKILL -- "$@"
fi

# ----------------------------------------------------------------- first pass
metta_bounded_timeout=$(metta_bounded_enforcer) || {
    echo "bounded.sh: no \`timeout\` on PATH, so nothing here can hold a" >&2
    echo "  deadline that survives the process holding it. Install coreutils," >&2
    echo "  or name one in METTA_TIMEOUT. Removing this refusal is how two" >&2
    echo "  swipl children once spun for 122 CPU-hours." >&2
    exit 2
}
METTA_TIMEOUT=$metta_bounded_timeout
export METTA_TIMEOUT

# A caller that knew its own pid before it forked has closed the window this
# file cannot see into: a caller that died before this script's first line
# leaves a $PPID that names a subreaper, and "is my parent pid 1" does not tell
# those apart because a subreaper is not pid 1 and pid 1 can be a legitimate
# parent.
if [ -n "${METTA_BOUNDED_OWNER:-}" ] && [ "$METTA_BOUNDED_OWNER" != "$PPID" ]; then
    echo "bounded.sh: the process that started this ($METTA_BOUNDED_OWNER) had" >&2
    echo "  already exited; $PPID adopted it. Refusing to start: $1" >&2
    exit 125
fi

metta_bounded_setpriv=$(command -v setpriv 2>/dev/null) || metta_bounded_setpriv=''
if [ -z "$metta_bounded_setpriv" ]; then
    # The deadline still applies. Said out loud ONCE PER TREE, because the
    # difference between "reaped in milliseconds" and "reaped at the ceiling"
    # is an hour of a core and a bound that silently became the weaker one is
    # what this file exists to make impossible -- and because `sh test.sh`
    # starts 200 runners, which is 200 copies of it on any box without
    # util-linux.
    if [ -z "${METTA_BOUNDED_UNLINKED:-}" ]; then
        echo "bounded.sh: setpriv(1) is not on PATH, so this command carries its" >&2
        echo "  deadline but not the link to the process that started it: an" >&2
        echo "  orphan will burn until ${METTA_CHILD_CEILING:-3600}s. Install util-linux." >&2
        METTA_BOUNDED_UNLINKED=1
        export METTA_BOUNDED_UNLINKED
    fi
    # Unset, or a command that calls bounded.sh again inherits an owner pid
    # that is not ITS parent, sees the mismatch, and refuses with 125.
    unset METTA_BOUNDED_OWNER
    exec "$metta_bounded_timeout" --preserve-status \
        -k "${METTA_CHILD_GRACE:-10}" "${METTA_CHILD_CEILING:-3600}" "$@"
fi

# The outer rung, and the only rung that has to be a SIGNAL rather than a kill:
# SIGTERM because the ceiling program handles it by passing it on to the whole
# process group and escalating to SIGKILL after the grace, which reaches what
# the command spawned [measured 2026-09-05: SIGTERM to a GNU timeout wrapper
# leaves neither its child nor its grandchild alive]. A SIGKILL here would take
# the ceiling program out before it could pass anything on.
METTA_BOUNDED_ARMED=$PPID
METTA_BOUNDED_SETPRIV=$metta_bounded_setpriv
export METTA_BOUNDED_ARMED METTA_BOUNDED_SETPRIV
exec "$metta_bounded_setpriv" --pdeathsig SIGTERM -- \
    /bin/sh "$metta_bounded_self" "$@"
