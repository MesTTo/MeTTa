#!/bin/sh
# Purpose: start a process that cannot outlive both its deadline and the
#   process that started it. Every swipl, node and Python this repository
#   spawns goes through here, and so does a command typed by hand.
#
#   Usage: sh bounded.sh [--ceiling SECONDS] [--grace SECONDS] [--owner PID]
#                        [--memory KILOBYTES|none] COMMAND [ARG ...]
#          sh bounded.sh --enforcer      print the ceiling program and exit
#          sh bounded.sh --memory-scope  print yes if a memory scope can be
#                                        made here and no if not, and exit
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
#     METTA_CHILD_MEMORY    kilobytes of memory the command may take, or
#                           `none` for no bound (default: half of the box as
#                           resident memory where a scope can be made, a
#                           quarter of it as data segment where it cannot)
#     METTA_BOUNDED_SCOPE   `yes` or `no`, whether a scope can be made here,
#                           for a caller that resolves it once for many spawns
#
#   The ceiling and the grace are EXPORTED, so a command that bounds children
#   of its own inherits them: `bounded --ceiling 290 sh run.sh f.metta` gives
#   run.sh's swipl the same 290 rather than the default hour, which is the
#   tighter of the two and the one the caller asked for [measured 2026-09-05:
#   an inner call under `--ceiling 77` reads 77].
#
#   Three independent bounds, because each alone has a hole this repository has
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
#   The MEMORY BOUND is the command's RESIDENT memory, held by a user cgroup
#   scope with swap closed wherever the kernel delegates a memory controller
#   to this user, and RLIMIT_DATA at a quarter of the box where it does not.
#   Neither of the other two is a bound on size, so both were armed and
#   neither helped when one pytest-xdist worker reached 29.7 GB RSS on
#   2026-09-20 and took 56 of this box's 60 GB with 63 GB pushed into swap,
#   leaving 672 MB free. The lane it belonged to had already finished, so
#   nothing was watching it, and its deadline had 815 seconds still to run. A
#   command that asks for more than its share is now stopped instead of the
#   box failing everyone else's.
#
#   Resident wherever it can be, because RLIMIT_DATA charges a writable
#   reservation whether or not a page of it is ever touched. The MORK
#   backend's first exec reserves 11 GiB and touches 32 kB [measured
#   2026-09-24: VmData 0.09 GB to 11.64 GB with VmRSS at 0.09 GB throughout],
#   so under a data bound a pytest worker already holding 4.3 GB aborted on
#   it, and the same worker then failed to start threads and to grow SWI's
#   stacks in the tests that followed. A scope charges the 32 kB.
#
# Assumes:
#   - a `timeout` on PATH, or one named by METTA_TIMEOUT. Without one this
#     refuses rather than running unbounded.
#   - setpriv(1) from util-linux for the owner link. Without it the deadline
#     still applies and the refusal to start is announced once, because a
#     silently weaker bound is the failure this file exists to prevent.
#   - for the resident bound, systemd-run(1) and a user manager whose cgroup
#     delegates the memory controller, both read without starting anything
#     from /proc/self/cgroup, the manager's private socket and its
#     cgroup.subtree_control, then confirmed by starting one scope. Without
#     them the bound is RLIMIT_DATA: a shell whose `ulimit -d` sets it, on a
#     kernel at 4.7 or newer so that it covers anonymous mmap. Without either
#     the other two bounds still apply and the gap is announced once, for the
#     same reason.
#   - /proc/meminfo, to derive the default share. Without it the default is no
#     memory bound, which `--memory KILOBYTES` overrides.
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
#   - a command whose memory passes its share is stopped, rather than the box
#     failing everyone else's. In a scope the kernel kills the tree's largest
#     process once the tree's resident memory passes the share, and a
#     reservation nothing touches is not charged; under RLIMIT_DATA the
#     allocation fails, and every descendant inherits the limit
#     [tested: tests/shell/test_bounded_reaping.sh cases 5c and 5h, whose
#     negative controls are the same allocations under `--memory none`]
#   - only the OUTERMOST rung makes a scope, and every rung beneath it is
#     charged to that one. A scope started inside a scope becomes a SIBLING
#     under the user manager, so the inner tree would escape the budget
#     [source: docs/journal/2026-09-05-the-bound-that-only-lanes-carried.md];
#     a nested rung therefore adds none, and one given an explicit `--memory`
#     ratchets its own process down as a data-segment limit instead
#     [tested: tests/shell/test_bounded_reaping.sh cases 5f and 5i]
#   - `--memory-scope` answers whether a scope can be made, so a caller that
#     spawns many children resolves it once, as it does the ceiling program
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
#   - the command reaches no debuginfod server: DEBUGINFOD_URLS is emptied
#     before anything starts, so a command that symbolizes a native frame
#     answers from debug info built here instead of fetching it. Ubuntu's
#     /etc/profile.d/debuginfod.sh points every login shell at
#     https://debuginfod.ubuntu.com, which this box cannot reach at all, so
#     elfutils' libdebuginfod waits out its own timeout for every build-id it
#     cannot resolve locally [measured 2026-09-20: the memray lane's
#     limit_leaks plant sat 37 minutes at 0% CPU in poll_schedule_timeout
#     holding a SYN-SENT socket to 91.189.92.195:443, and would have burned
#     its whole 3600s ceiling; `curl https://debuginfod.ubuntu.com/` never
#     completes a connection. llvm-symbolizer hung the same way under the C
#     seat's sanitizer on 2026-09-03 and was cleared in that one script rather
#     than here, which is what left this instance free to happen].
#     Nothing is lost: the symbols a server would add are the host's, and every
#     frame these lanes read belongs to a source built in this tree.
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
# Normalised by construction: see the Guarantees above. Both are cleared here,
# before either exec path, so the deadline-only rung and the owner-linked rung
# start the command in the same environment.
#
# DEBUGINFOD_URLS is EMPTIED and exported rather than unset. Either stops
# libdebuginfod, which reads the variable and nothing else, and neither
# survives a login shell, since /etc/profile.d/debuginfod.sh re-derives the
# value from /etc/debuginfod/*.urls whenever `[ -z ]` holds. What an exported
# empty buys is that the decision is READABLE: it shows in the command's own
# /proc/<pid>/environ, where an unset variable cannot be told from one this
# box never configured, and reading that file is how the 2026-09-20 hang was
# attributed in the first place. It is also the spelling the C seat's
# sanitizer already used, so the tree says this one way.
unset DISPLAY WAYLAND_DISPLAY
DEBUGINFOD_URLS=
export DEBUGINFOD_URLS

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

# The third bound: how much memory one command may take. RLIMIT_DATA rather
# than RLIMIT_AS, because a Python or a JIT reserves address space it never
# touches and a limit that fits the one would refuse the other; since Linux
# 4.7 RLIMIT_DATA covers anonymous mmap, which is where a runaway heap lives
# [measured 2026-09-20: a 600 MB bytearray under `ulimit -d 262144` raises
# MemoryError, and the same allocation under `systemd-run --user --scope -p
# MemoryMax=256M` succeeds, so the cgroup route does not bound a user scope
# here and this one does].
#
# Derived from the box rather than frozen: a QUARTER of what the machine has.
# The number has to sit above the largest demand this tree DECLARES and below
# the runaway it exists to stop, and those two are what set it:
#
#   - declared: run.sh passes SWI `--stack_limit=8g`, and the MORK backend asks
#     its allocator for a 4 GiB arena, so a single lane legitimately reaches
#     about 12 GB;
#   - runaway: one pytest-xdist worker reached 29.7 GB RSS on 2026-09-20 and
#     took 56 of this box's 60 GB with 63 GB pushed into swap.
#
# An EIGHTH was the first choice and it is refuted: 7.56 GiB on this box, below
# the declared 12 GB, so `01-mm2-operators.metta` aborted on `memory allocation
# of 4294967296 bytes failed` and took the shell, examples and no-autoload
# lanes with it. The reason given for an eighth was that the heaviest
# legitimate worker measured 0.72 GB, which measured pytest workers and never
# saw the MORK lane [measured 2026-09-20: the same example exits 0 under
# `--memory none` and under a quarter, and aborts under an eighth].
#
# A quarter does not partition the box four ways: RLIMIT_DATA is a per-process
# CEILING rather than a reservation, so four workers allowed 15 GiB each still
# consume what they allocate, which was measured at 0.72 GB. What changes is
# only where a runaway is caught, and 29.7 GB is still refused.
#
# The RESIDENT share is HALF, for a different unit: a scope bounds a whole
# TREE, so its number has to sit above the heaviest tree this repository runs
# as one rung and below the box. The gate's pytest lane at sixteen workers is
# that tree, and it peaked at 15.2 GB resident with 2.07 GB of swap as one
# scope [measured 2026-09-24, battery 7, `sh tools/check.sh pytest` in a
# measuring scope: memory.peak 15209196 kB], so a quarter would sit at its edge
# while half leaves it twice its peak. A runaway worker inside it is still
# stopped once the tree reaches half the box, which is before the 29.7 GB
# worker of 2026-09-20 took the box. Swap is CLOSED in the scope, because
# MemoryMax alone bounds only RAM: a touched 600 MB allocation under
# MemoryMax=256M succeeded by swapping and was killed once MemorySwapMax=0
# was added [measured 2026-09-24], which is also why the 2026-09-20
# measurement that ruled the cgroup route out, with swap left open, saw
# nothing bounded.
#
# $1 divides MemTotal: 2 for the resident share, 4 for the data segment.
metta_bounded_share() {
    metta_bounded_total=$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null) ||
        metta_bounded_total=''
    case $metta_bounded_total in
        '' | *[!0-9]*) printf 'none\n' ;;
        *) printf '%s\n' "$((metta_bounded_total / $1))" ;;
    esac
}

# Whether this process already lives in a scope a bounded.sh rung made, read
# from the kernel rather than from the environment, which a process that has
# left the scope would still carry. Pure builtins: every rung asks.
metta_bounded_in_scope() {
    read -r metta_bounded_cgroup < /proc/self/cgroup 2>/dev/null || return 1
    case $metta_bounded_cgroup in
        */metta-bounded.slice/*) return 0 ;;
    esac
    return 1
}

# Whether a scope can be made here. What can be read is read first, without
# starting anything: systemd-run on PATH, the user manager's private socket,
# and this process sitting under a user manager whose cgroup delegates the
# memory controller. Then one scope is started, because only the manager knows
# whether it will make one, and a manager that refused the real command would
# fail it before it ran. A caller that resolved the answer passes it in
# METTA_BOUNDED_SCOPE, and the answer is exported for every rung beneath.
metta_bounded_scope_available() {
    case ${METTA_BOUNDED_SCOPE:-} in
        yes) return 0 ;;
        no) return 1 ;;
    esac
    METTA_BOUNDED_SCOPE=no
    export METTA_BOUNDED_SCOPE
    command -v systemd-run >/dev/null 2>&1 || return 1
    [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/systemd/private" ] || return 1
    read -r metta_bounded_cgroup < /proc/self/cgroup 2>/dev/null || return 1
    metta_bounded_cgroup=${metta_bounded_cgroup#0::}
    case $metta_bounded_cgroup in
        */user@*.service/* | */user@*.service) ;;
        *) return 1 ;;
    esac
    metta_bounded_manager=${metta_bounded_cgroup%%.service/*}
    metta_bounded_manager=${metta_bounded_manager%.service}.service
    read -r metta_bounded_delegated < "/sys/fs/cgroup$metta_bounded_manager/cgroup.subtree_control" \
        2>/dev/null || return 1
    case " $metta_bounded_delegated " in
        *" memory "*) ;;
        *) return 1 ;;
    esac
    systemd-run --user --scope --quiet --expand-environment=no --slice=metta-bounded.slice \
        -p MemoryMax=64M -p MemorySwapMax=0 -- true >/dev/null 2>&1 || return 1
    METTA_BOUNDED_SCOPE=yes
    return 0
}

# Said out loud ONCE PER TREE, for the reason the setpriv notice below is: a
# bound that silently became the weaker one is the failure this file exists to
# prevent.
#
# What it reports has to be READ rather than assumed, because `ulimit -d` sets
# the soft and the hard limit together [measured 2026-09-20: after
# `ulimit -d 262144`, `ulimit -Hd` reads 262144 and raising it is refused with
# EPERM]. So the limit only ever ratchets down, and the usual reason the call
# fails is not that this shell cannot meter memory but that an outer rung
# already metered it TIGHTER. Announcing "no memory bound" there would be its
# own false claim, of exactly the kind this notice exists to stop.
#
# Both limits, not the soft one alone: a command that could raise its own soft
# limit is not bounded, and Python spells that `resource.setrlimit`.
metta_bounded_memory_unchanged() {
    metta_bounded_inforce=$(ulimit -Sd 2>/dev/null) || metta_bounded_inforce=unknown
    [ -n "$metta_bounded_inforce" ] || metta_bounded_inforce=unknown
    if [ -z "${METTA_BOUNDED_UNMETERED:-}" ]; then
        case $metta_bounded_inforce in
            unlimited | unknown)
                echo "bounded.sh: this shell cannot set a data limit, so the command" >&2
                echo "  carries its deadline and its owner link but no memory bound." >&2
                echo "  A worker that reached 29.7 GB is why that is said out loud." >&2
                ;;
            *)
                echo "bounded.sh: a data limit of $metta_bounded_inforce kB is already in" >&2
                echo "  force and will not rise to the $1 kB asked for, so the command" >&2
                echo "  carries the tighter bound it inherited." >&2
                ;;
        esac
        METTA_BOUNDED_UNMETERED=1
        export METTA_BOUNDED_UNMETERED
    fi
}

if [ "${1:-}" = "--enforcer" ]; then
    metta_bounded_enforcer
    exit $?
fi

if [ "${1:-}" = "--memory-scope" ]; then
    if metta_bounded_scope_available; then echo yes; else echo no; fi
    exit 0
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
        --memory)  [ "$#" -ge 2 ] || { echo "bounded.sh: --memory needs kilobytes or none" >&2; exit 2; }
                   METTA_CHILD_MEMORY=$2; export METTA_CHILD_MEMORY; shift 2 ;;
        --)        shift; break ;;
        *)         break ;;
    esac
done

if [ "$#" -eq 0 ]; then
    echo "usage: sh bounded.sh [--ceiling SECONDS] [--grace SECONDS]" >&2
    echo "                     [--owner PID] [--memory KILOBYTES|none]" >&2
    echo "                     COMMAND [ARGUMENT ...]" >&2
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
    set -- "$metta_bounded_timeout" --preserve-status \
        -k "$metta_bounded_grace" "$metta_bounded_ceiling" \
        "$metta_bounded_setpriv" --pdeathsig SIGKILL -- "$@"
    # The memory bound, set HERE, in the rung that execs. Both forms need no
    # process of their own: systemd-run --scope moves this pid into the scope
    # and execs the ceiling program in place, and a resource limit is
    # inherited across exec and by every child.
    if [ "${METTA_CHILD_MEMORY:-}" = none ]; then
        :
    elif metta_bounded_in_scope; then
        # An outer rung's scope already charges this tree. An explicit share
        # ratchets this process down as a data-segment limit, the one
        # per-process bound that does not leave the scope.
        if [ -n "${METTA_CHILD_MEMORY:-}" ]; then
            ulimit -d "$METTA_CHILD_MEMORY" 2>/dev/null ||
                metta_bounded_memory_unchanged "$METTA_CHILD_MEMORY"
        fi
    elif metta_bounded_scope_available; then
        metta_bounded_memory=${METTA_CHILD_MEMORY:-$(metta_bounded_share 2)}
        if [ "$metta_bounded_memory" != none ]; then
            # The share this rung was given is the scope's, so no rung beneath
            # applies it again as a data-segment limit on each process.
            unset METTA_CHILD_MEMORY
            # --expand-environment=no, or the command is not the one it was
            # given: systemd-run rewrites `${USER}` to its value and `$$` to `$`
            # in every argument by default [measured 2026-09-24, systemd 259:
            # `$$ ${USER}` arrived as `$ user`, where MeTTa's own `$x` is one
            # substitution away], and a systemd without the option fails the
            # probe above instead.
            #
            # A unit name of its own, because the default is `run-p<pid>-i<n>`
            # and a caller that already put this pid in a systemd-run scope
            # owns that name: the second start is refused with "was already
            # loaded" [measured 2026-09-24] and the command never runs.
            read -r metta_bounded_unit < /proc/sys/kernel/random/uuid 2>/dev/null ||
                metta_bounded_unit=$$
            set -- systemd-run --user --scope --quiet --expand-environment=no \
                --unit="metta-bounded-$metta_bounded_unit" --slice=metta-bounded.slice \
                -p "MemoryMax=${metta_bounded_memory}K" -p MemorySwapMax=0 -- "$@"
        fi
    else
        metta_bounded_memory=${METTA_CHILD_MEMORY:-$(metta_bounded_share 4)}
        if [ "$metta_bounded_memory" != none ]; then
            ulimit -d "$metta_bounded_memory" 2>/dev/null ||
                metta_bounded_memory_unchanged "$metta_bounded_memory"
        fi
    fi
    exec "$@"
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
