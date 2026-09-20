#!/bin/sh
# Purpose: prove that bounded.sh reaps, rather than that it sets a flag.
#   Every case here starts a child that spins at 100% and ignores SIGTERM,
#   kills the process that started it, and asks whether the child is still
#   burning a core a few seconds later. The ceiling is left at an hour on
#   purpose, so nothing but the owner link can explain a death.
#
#   Usage: sh tests/shell/test_bounded_reaping.sh [WRAPPER ...]
#
#   With no argument it checks bounded.sh. With one it checks whatever it is
#   given, which is how the deadline-only wrapper this repository used until
#   2026-09-05 is run as the negative control:
#
#     sh tests/shell/test_bounded_reaping.sh timeout --preserve-status -k 10 3600
#
#   That control must FAIL cases 1 to 3 and 5g, since a bare `timeout` neither
#   reaps nor normalises. A reaping check that passes with the
#   mechanism removed is checking nothing, and the two 122-CPU-hour orphans of
#   2026-09-01 are what a check like that would have missed.
#
# Assumes:
#   - /proc, and a `ps` that answers `-o pid=,args=`
#   - swipl on PATH for case 3, which is skipped without one
# Guarantees:
#   - case 1: a SIGTERM-ignoring child dies within 20s of its starter being
#     SIGKILLed, against a 3600s ceiling
#   - case 2: so does the grandchild it spawned
#   - case 3: so does a real `swipl` goal that has taken SIGTERM out of its own
#     dispositions, which is the shape of the 7,540-second spinner of
#     2026-09-05
#   - case 4: the ceiling still fires on a child nobody killed the starter of
#   - case 5: the command's own exit status survives the wrapper, both an
#     ordinary status and 128+n for a signalled command
#   - case 5c: a command allocating far past its memory bound does not finish,
#     which is the axis the deadline and the owner link both leave open
#   - case 5d: `--memory none` runs it unbounded, for a lane that needs to
#   - case 5e: the default is a number derived from this box rather than
#     `unlimited`, so a caller that passes nothing is still bounded
#   - case 5f: a rung that inherits a TIGHTER bound than it asked for says so,
#     rather than announcing that nothing bounds the command
#   - case 5g: the command starts in the normalised environment the wrapper
#     promises -- DISPLAY and WAYLAND_DISPLAY gone, DEBUGINFOD_URLS empty --
#     which is the one guarantee in bounded.sh that nothing used to pin
#   - case 6: a child OUTLIVES the thread that spawned it. The parent-death
#     signal is documented as firing when the spawning THREAD exits, which
#     would kill live children under any threaded runner; this is what says the
#     running kernel does not do that.
#   - case 7: with setpriv absent, the deadline still applies, the command
#     still runs, and a command that calls the wrapper AGAIN still runs. That
#     is the rung every macOS and BSD contributor lands on.
# Fails when: run on a kernel that delivers the parent-death signal on the
#   spawning thread's exit. Case 6 is the one that says so, and its remedy is
#   an owner link held by a supervisor watching a pidfd rather than by prctl.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/metta-bounded-reaping.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

if [ "$#" -gt 0 ]; then
    WRAPPER="$*"
else
    WRAPPER="sh $ROOT/bounded.sh"
fi
# An hour, so that a death inside the 20s window below is the owner link and
# cannot be the deadline.
METTA_CHILD_CEILING=3600
METTA_CHILD_GRACE=5
export METTA_CHILD_CEILING METTA_CHILD_GRACE

failures=0
skipped=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

alive() { kill -0 "$1" 2>/dev/null; }

# Wait up to $1 seconds for pid $2 to disappear. Answers 0 when it went.
gone_within() {
    _limit=$1; _pid=$2; _waited=0
    while [ "$_waited" -lt "$((_limit * 5))" ]; do
        alive "$_pid" || return 0
        sleep 0.2
        _waited=$((_waited + 1))
    done
    ! alive "$_pid"
}

# Read a pid a child wrote, giving it up to 20s to start.
read_pid() {
    _tries=0
    while [ ! -s "$1" ] && [ "$_tries" -lt 100 ]; do
        sleep 0.2
        _tries=$((_tries + 1))
    done
    cat "$1" 2>/dev/null
}

# A child that spins at 100% and refuses SIGTERM, in POSIX sh.
cat > "$WORK/stubborn.sh" <<'STUBBORN'
#!/bin/sh
trap '' TERM
echo "$$" > "$1"
while : ; do : ; done
STUBBORN

# The same, plus a grandchild the wrapper never sees the start of.
cat > "$WORK/stubborn_tree.sh" <<'TREE'
#!/bin/sh
# unbounded: the grandchild under test. Bounding it would give it the
# owner link this case exists to observe arriving from outside.
sh -c 'trap "" TERM; echo $$ > "'"$2"'"; while :; do :; done' &
trap '' TERM
echo "$$" > "$1"
while : ; do : ; done
TREE
chmod +x "$WORK/stubborn.sh" "$WORK/stubborn_tree.sh"

# Start COMMAND under the wrapper from a shell that then does nothing but wait,
# and SIGKILL that shell. SIGKILL, because a starter that could run a trap is a
# starter that could clean up, and the sessions killed here do not get to.
orphan_then_kill() {
    _pidfile=$1; shift
    rm -f "$_pidfile"
    # unbounded: the STARTER whose death is the stimulus. It is killed a
    # few lines below, which is the whole experiment.
    sh -c "$WRAPPER \"\$@\" & wait" bounded "$@" >/dev/null 2>&1 &
    _starter=$!
    _child=$(read_pid "$_pidfile")
    if [ -z "$_child" ]; then
        kill -KILL "$_starter" 2>/dev/null
        echo ''
        return 1
    fi
    kill -KILL "$_starter" 2>/dev/null
    echo "$_child"
}

printf 'wrapper under test: %s\n' "$WRAPPER"

# ---------------------------------------------------------------- case 1
child=$(orphan_then_kill "$WORK/one.pid" "$WORK/stubborn.sh" "$WORK/one.pid")
if [ -z "$child" ]; then
    fail "case 1: the wrapped command never started"
elif gone_within 20 "$child"; then
    printf 'ok  1  a SIGTERM-ignoring child died with its starter\n'
else
    fail "case 1: pid $child still runs 20s after its starter was SIGKILLed,
      against a ${METTA_CHILD_CEILING}s ceiling. Nothing links the command to
      the process that started it, so it will burn a core until the ceiling."
    kill -KILL "$child" 2>/dev/null
fi

# ---------------------------------------------------------------- case 2
child=$(orphan_then_kill "$WORK/two.pid" "$WORK/stubborn_tree.sh" \
        "$WORK/two.pid" "$WORK/two-grand.pid")
grand=$(read_pid "$WORK/two-grand.pid")
if [ -z "$child" ] || [ -z "$grand" ]; then
    fail "case 2: the wrapped tree never started"
else
    if gone_within 20 "$child" && gone_within 20 "$grand"; then
        printf 'ok  2  its grandchild died with it\n'
    else
        fail "case 2: child $child / grandchild $grand outlived their starter.
      A signal sent to one pid does not reach what that pid spawned; the
      escalation has to reach the process GROUP."
        kill -KILL "$child" "$grand" 2>/dev/null
    fi
fi

# ---------------------------------------------------------------- case 3
if command -v swipl >/dev/null 2>&1; then
    # `on_signal(term, _, ignore)` is how a swipl goal takes SIGTERM out of its
    # own dispositions. Measured 2026-09-05: this spins at 99.7% CPU and is
    # still there eight seconds after SIGTERM, while every ordinary goal tried
    # beside it died on the first one.
    goal="on_signal(term,_,ignore), \
          setup_call_cleanup(open('$WORK/three.pid',write,S), \
              (current_prolog_flag(pid,P), write(S,P), nl(S)), close(S)), \
          between(1,100000000000,_), fail"
    child=$(orphan_then_kill "$WORK/three.pid" swipl -g "$goal" -t halt)
    if [ -z "$child" ]; then
        fail "case 3: swipl never started"
    elif gone_within 20 "$child"; then
        printf 'ok  3  a swipl goal that ignores SIGTERM died with its starter\n'
    else
        fail "case 3: swipl $child outlived its starter. This is the shape of
      the 7,540-second spinner of 2026-09-05."
        kill -KILL "$child" 2>/dev/null
    fi
else
    printf 'skip 3  swipl is not on PATH\n'
    skipped=$((skipped + 1))
fi

# ---------------------------------------------------------------- case 4
# The deadline, which the owner link must not have replaced. The outer guard is
# the harness's, not the subject's: a wrapper that reads its ceiling from argv
# rather than from METTA_CHILD_CEILING would otherwise sit here for an hour,
# and the point is to REPORT that, not to wait for it.
rm -f "$WORK/four.pid"
start=$(date +%s)
METTA_CHILD_CEILING=3 METTA_CHILD_GRACE=2 \
    timeout -s KILL 30 $WRAPPER "$WORK/stubborn.sh" "$WORK/four.pid" \
    >/dev/null 2>&1
elapsed=$(( $(date +%s) - start ))
child=$(cat "$WORK/four.pid" 2>/dev/null || true)
if [ "$elapsed" -ge 3 ] && [ "$elapsed" -le 20 ]; then
    printf 'ok  4  the deadline still fires, after %ss\n' "$elapsed"
else
    fail "case 4: a 3s METTA_CHILD_CEILING took ${elapsed}s to fire"
fi
[ -n "$child" ] && kill -KILL "$child" 2>/dev/null

# ---------------------------------------------------------------- case 5
$WRAPPER /bin/sh -c 'exit 42' >/dev/null 2>&1
status=$?
if [ "$status" -eq 42 ]; then
    printf 'ok  5a the command exit status survives the wrapper\n'
else
    fail "case 5a: a command exiting 42 was reported as $status"
fi
$WRAPPER /bin/sh -c 'kill -TERM $$' >/dev/null 2>&1
status=$?
if [ "$status" -eq 143 ]; then
    printf 'ok  5b a signalled command still reports 128+n\n'
else
    fail "case 5b: a command killed by SIGTERM was reported as $status, not 143"
fi

# ---------------------------------------------------------------- case 5c
# The THIRD bound. A worker that reached 29.7 GB took 56 of a 60 GB box with
# 63 GB pushed into swap, and the two bounds above were both armed: its lane
# had finished so nothing watched it, and its deadline had 815 seconds still
# to run. Neither of them is a memory bound [measured 2026-09-20].
if $WRAPPER --memory 262144 /bin/sh -c '
        exec 2>/dev/null
        awk "BEGIN { for (i = 0; i < 40000000; i++) hold[i] = i }" ' \
        >/dev/null 2>&1; then
    fail "case 5c: a command allocating far past --memory 262144 was not bounded"
else
    printf 'ok  5c a command past its memory bound does not finish\n'
fi
if $WRAPPER --memory none /bin/echo bounded >/dev/null 2>&1; then
    printf 'ok  5d --memory none runs the command unbounded\n'
else
    fail "case 5d: --memory none refused to run a trivial command"
fi
default_limit=$($WRAPPER /bin/sh -c 'ulimit -d' 2>/dev/null)
case $default_limit in
    unlimited | '' | *[!0-9]*)
        fail "case 5e: the default memory bound read '$default_limit'" ;;
    *)  printf 'ok  5e the default is derived from the box, %s kB\n' "$default_limit" ;;
esac

# `ulimit -d` sets the soft limit AND the hard one, so the bound only ratchets
# down and the usual reason the call fails is not a shell that cannot meter
# memory but an outer rung that already metered TIGHTER. Announcing "no memory
# bound" over a bound that is in force is the same silent weakening the wrapper
# exists to prevent, pointed the other way, so the notice has to distinguish
# them and the command still has to run.
# Through the wrapper rather than exempted: the outer rung sets the box's own
# share, the shell then ratchets DOWN to 262144, and the inner rung asking for
# 524288 is the refusal under test. Bounding the setup costs the case nothing,
# so there is no reason to spend an `unbounded:` on it.
notice=$($WRAPPER /bin/sh -c \
    "ulimit -d 262144; exec $WRAPPER --memory 524288 /bin/echo ran" 2>&1)
case $notice in
    *"262144 kB is already in"*ran*)
        printf 'ok  5f an inherited tighter bound is reported, not overstated\n' ;;
    *)  fail "case 5f: the inherited-bound notice read '$notice'" ;;
esac

# ---------------------------------------------------------------- case 5g
# The normalised environment was a guarantee with nothing pinning it, and the
# gap has now cost a lane. DISPLAY has been cleared in bounded.sh since
# 2026-09-15, but DEBUGINFOD_URLS was cleared only inside
# extensions/cmetta/sanitize.sh on 2026-09-03, so when memray's limit_leaks
# plant symbolized a native frame on 2026-09-20 it still reached for
# https://debuginfod.ubuntu.com, which this box cannot connect to, and sat 37
# minutes at 0% CPU in poll_schedule_timeout against a 3600s ceiling.
#
# Asserted on what the COMMAND sees rather than on what bounded.sh writes, so
# anything re-setting a variable between here and exec is caught too:
# /etc/profile.d/debuginfod.sh re-derives DEBUGINFOD_URLS from
# /etc/debuginfod/*.urls whenever `[ -z ]` holds, so a rung that ever started a
# LOGIN shell would hand the server back with the clearing still in place.
#
# `${VAR-...}` rather than `${VAR}`, because empty-and-exported and unset are
# different answers and the guarantee names the first: an unset variable cannot
# be told in /proc/<pid>/environ from one this box never configured.
seen=$(DISPLAY=:9 WAYLAND_DISPLAY=wayland-9 \
       DEBUGINFOD_URLS=https://debuginfod.invalid \
       $WRAPPER /bin/sh -c \
       'printf "display=%s wayland=%s urls=[%s]" "${DISPLAY-cleared}" \
            "${WAYLAND_DISPLAY-cleared}" "${DEBUGINFOD_URLS-unset}"' 2>&1)
case $seen in
    'display=cleared wayland=cleared urls=[]')
        printf 'ok  5g the command starts headless and reaches no debuginfod server\n' ;;
    *)  fail "case 5g: the command saw '$seen'" ;;
esac

# ---------------------------------------------------------------- case 6
# The parent-death signal is documented as firing when the spawning THREAD
# exits. If it did, every threaded runner in this repository would kill live
# children: pytest-xdist workers, and the ThreadPoolExecutor in
# extensions/python/tools/example_parity.py. Measured 2026-09-05 on Linux
# 7.0.0-30-generic: it does not. This is what says so on the next kernel.
if command -v cc >/dev/null 2>&1; then
    cat > "$WORK/thread_owner.c" <<'THREADC'
#define _GNU_SOURCE
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <sys/prctl.h>
#include <sys/wait.h>
#include <unistd.h>
static pid_t forked = -1;
static void *body(void *ignored)
{
	(void)ignored;
	pid_t pid = fork();
	if (pid == 0) {
		prctl(PR_SET_PDEATHSIG, SIGKILL, 0, 0, 0);
		signal(SIGTERM, SIG_IGN);
		for (;;) {
		}
		_exit(0);
	}
	forked = pid;
	return NULL;
}
int main(void)
{
	pthread_t worker;
	pthread_create(&worker, NULL, body, NULL);
	pthread_join(worker, NULL);
	sleep(2);
	printf("%s\n", kill(forked, 0) == 0 ? "outlived" : "killed");
	kill(forked, SIGKILL);
	waitpid(forked, NULL, 0);
	return 0;
}
THREADC
    if cc -O0 -o "$WORK/thread_owner" "$WORK/thread_owner.c" -pthread 2>/dev/null
    then
        verdict=$("$WORK/thread_owner" 2>/dev/null)
        if [ "$verdict" = outlived ]; then
            printf 'ok  6  a child outlives the thread that spawned it\n'
        else
            fail "case 6: this kernel delivers the parent-death signal when the
      SPAWNING THREAD exits, not when the process does. Every child started
      from a pool worker in this repository will be killed the moment that
      worker finishes. bounded.sh's outer rung has to move from prctl to a
      supervisor watching the owner through a pidfd; see
      util-linux sys-utils/unshare.c."
        fi
    else
        printf 'skip 6  the probe did not compile\n'
        skipped=$((skipped + 1))
    fi
else
    printf 'skip 6  no C compiler\n'
    skipped=$((skipped + 1))
fi

# ---------------------------------------------------------------- case 7
# The degraded rung: no setpriv, so the deadline applies and the owner link does
# not. It must still RUN the command, and a command that calls the wrapper again
# must still run: an owner pid left in the environment there is compared against
# the wrong parent and refuses with 125. Reached by naming the ceiling program
# in METTA_TIMEOUT and emptying PATH, which is the one configuration
# `command -v setpriv` can find nothing in. Every program below is named
# absolutely for the same reason.
enforcer=$(sh "$ROOT/tools/bounded.sh" --enforcer)
# Not in a command substitution: bounded.sh has to be forked by THIS shell for
# `--owner $$` to name its real parent, and `$( )` would put a subshell between
# them.
METTA_TIMEOUT="$enforcer" PATH=/nonexistent \
    /bin/sh "$ROOT/tools/bounded.sh" --owner $$ \
    /bin/sh -c 'METTA_TIMEOUT="$1" PATH=/nonexistent /bin/sh "$2" /bin/echo nested-ran' \
    seven "$enforcer" "$ROOT/tools/bounded.sh" > "$WORK/seven.out" 2>"$WORK/seven.err"
nested=$(cat "$WORK/seven.out" 2>/dev/null || true)
if [ "$nested" = nested-ran ]; then
    printf 'ok  7  the no-setpriv rung still runs, and so does a nested call\n'
else
    fail "case 7: with setpriv absent a nested bounded call answered
      '$nested' rather than 'nested-ran'. An owner pid left in the environment
      is compared against the wrong parent and refuses with 125.
      stderr: $(head -3 "$WORK/seven.err" 2>/dev/null | tr '\n' ' ')"
fi

if [ "$failures" -gt 0 ]; then
    printf '\n%s reaping case(s) failed, %s skipped\n' "$failures" "$skipped" >&2
    exit 1
fi
printf '\nbounded reaping: every case passed, %s skipped\n' "$skipped"
