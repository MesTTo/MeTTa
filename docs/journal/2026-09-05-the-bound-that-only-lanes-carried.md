<!-- Purpose: record why the process bound moved out of check.sh, which mechanism holds the owner link, and what was measured against every alternative. -->
# The bound that only lanes carried
Goal: a process this repository starts cannot outlive both its deadline and the
process that started it, whether a gate lane, a runner script or a person
started it.
Constraint: `GATE_ONLY=1 sh tools/check.sh` measured 286s against a 300s ceiling on a
quiet box, so the mechanism has to be cheap enough to sit on every spawn.

## 2026-09-05

The incident. A `swipl -g "set_test_options([format(log)]), run_tests" -t halt
tests/prolog/suites/spaces/materialization.plt` ran 7,540 seconds at 97.8% CPU,
ignored SIGTERM and needed SIGKILL. It was typed by hand, so no lane function
and no `run()` wrapper was between it and the machine. The existing gate,
`tests/checks/check_process_bounds.py`, reads lane functions in the check
scripts and nothing else, and it was green while that process ran. Its own
header names the earlier incident it was written for: two swipl children spun
for 122 CPU-hours between 2026-09-01 and 2026-09-03 with only
`subprocess.run(timeout=)` on them.

Tried: reproducing "a tight resolution loop ignores SIGTERM", which is what the
incident report attributed the survival to. It does not reproduce on SWI
10.1.13. `X is 7**900000000`, a 400,000-term GMP fold, `msort` over 60M
elements, an infinite `p(X) :- p(s(X))` under `--stack_limit=8g`, an unbounded
tabled recursion and `between(1,inf,_), fail` each died on the FIRST SIGTERM,
within a second. The one shape that survives is a goal that has taken the
signal out of its own dispositions: `on_signal(term,_,ignore), between(...),
fail` spins at 99.7% and is still there eight seconds later. SWI registers
SIGTERM through `terminate_on_signal` and a C `terminate_handler` installed by
`PL_signal` without `PLSIG_SYNC` (src/pl-setup.c), so the default path is not a
Prolog handler waiting for an inference boundary at all. **I cannot confirm the
incident's stated cause.** What it does establish is that escalation to SIGKILL
must stay, and the ignoring-swipl recipe above is now case 3 of the reaping
suite.

Measured the mechanisms, per invocation, `--preserve-status -k 10 3600
/bin/true` where applicable, 60 calls, min of three, loadavg 19-26:

| mechanism | ms/call | ceiling | reaches a grandchild | reaches a setsid escapee | reaps on owner death |
|---|---|---|---|---|---|
| bare `/bin/true` | 0.25 | - | - | - | - |
| `setpriv --pdeathsig SIGKILL --` | 0.53 | no | no | no | yes, direct child |
| GNU `timeout` 9.7 | 0.65 | yes | yes | no | no |
| `systemd-run --user --scope` | 4.9 | yes | yes | yes | no |
| uutils `timeout` 0.8.0 | **102.78** | yes | **no** | no | no |

Two of those numbers are the day's real finding. Ubuntu 25.10 diverts
`/usr/bin/timeout` to `coreutils-from-uutils`, and that implementation (a)
costs a flat ~102ms because it waits for the command on a 50ms sleep tick
(`strace -c` attributes 100.1ms of 102.9ms to `clock_nanosleep`) and (b) does
not send its SIGKILL escalation to the process group: `src/uu/timeout/src/
platform/unix.rs` skips `send_signal_group` for KILL. Measured: a grandchild
that ignores SIGTERM survives `timeout --preserve-status -k 3 3` under uutils
and does not under GNU 9.7. Both `check.sh` and `extensions/python/tests/
conftest.py` carried a comment asserting the group behaviour as measured on
2026-09-03; on this box that guarantee was false. uutils also answers 15 rather
than 143 for a child killed by SIGTERM under `--preserve-status`, which three
tests here read.

Rejected: `systemd-run --user --scope` as the ceiling. It is the most complete
containment available and it is cheap, and three measurements still rule it
out. A scope does not stop when its launcher dies (`systemd.scope(5)`; the
controller-disappearance handler clears tracking and does not stop the unit),
so it answers the deadline half and not the owner half. Nesting ESCAPES it: a
scope started inside a scope becomes a SIBLING under `app.slice`
(`run-p3764536.scope` then `run-p3764566.scope`), and this tree nests bounds
three deep, so the tree guarantee it is chosen for is exactly the one its own
composition breaks. And it changes what a run observes: a command killed by
SIGTERM reports exit 2 instead of 143, and `perf stat -e instructions:u` reads
2,537,830 instructions for `systemd-run --scope /bin/true` against 164,260 for
`/bin/true`, which this repository's instruction pins cannot absorb. Revisit if
a setsid'd escapee is ever observed here, and then only around the ceiling, not
around a measured command.

Rejected: a PID namespace, `unshare --pid --fork --kill-child=KILL`. It works
unprivileged here and propagates the exit status, but the documented
`--kill-child` link is namespace-init to `unshare`, not `unshare` to the
harness, so the outer link is still needed; and unprivileged use generally
requires `--user --map-root-user`, which changes identity and `/proc`
semantics for every suite that reads a pid. Revisit if grandchild containment
becomes the binding constraint.

Rejected: a C supervisor of our own, the Bazel `linux-sandbox` shape. It is the
strongest answer and the closest prior art, and it is a new gitignored build
artifact in a repository where exactly that has already changed a benchmark
configuration invisibly, and it would be ABSENT in the worktrees where the
bound is most needed. Revisit if the pidfd owner watch below is ever required.

Rejected: `preexec_fn` for the parent-death signal, which is what
`conftest.py` and `tools/example_parity.py` had already rejected it as. Still
right, and no longer relevant: the arming happens inside `setpriv`, an
already-exec'd single-threaded process, so no Python runs between fork and
exec.

The other half of that recorded rejection was the per-THREAD hazard: prctl(2)
describes the signal as arriving when the thread that created the process
exits, which would kill live children under xdist and under the
`ThreadPoolExecutor` in `tools/example_parity.py`. Measured on Linux
7.0.0-30-generic, three ways, and it does not happen: a `subprocess.Popen` from
a `ThreadPoolExecutor` worker, a raw `os.fork` from a `threading.Thread`, and a
C `pthread_create` + `fork` all leave the child ALIVE after the spawning thread
exits and is joined, with `PR_GET_PDEATHSIG` read back as 9 in the child and
the process-death control dying in the same binary. `/proc/PID/task/TID/
children` shows the child moving from the worker thread's list to the main
thread's, so `forget_original_parent()` ran and reparented without delivering.
Upstream `kernel/exit.c` at master sends `t->pdeath_signal` on any reparent, so
this is a property of the running kernel rather than of the interface. Not
relied on: the property is pinned as case 6 of the reaping suite and as
`test_a_child_outlives_the_thread_that_spawned_it`, both GATE, so a kernel that
changes it says so by name. If either goes red the remedy is an owner link held
by a supervisor watching a pidfd, the shape util-linux `unshare(1)` uses.

Decided: one tracked executable, `bounded.sh`, composing two stock primitives
and adding nothing of its own. It execs all the way down, so it costs no
process, leaves the command's own argv in `ps`, and returns the command's exit
status:

    setpriv --pdeathsig SIGTERM -- sh tools/bounded.sh   (re-entry, then)
      timeout --preserve-status -k GRACE CEILING
        setpriv --pdeathsig SIGKILL -- COMMAND

The outer rung is SIGTERM because the ceiling program handles it by passing it
to the whole process group and escalating after the grace: measured, SIGTERM to
a GNU `timeout` wrapper leaves neither its child nor its grandchild alive. A
SIGKILL there would take the ceiling program out before it could pass anything
on. The inner rung is SIGKILL and its parent is the ceiling program, a
single-threaded process, so it cannot fire on a thread's exit whatever the
kernel does; it is what keeps the command from surviving a ceiling program that
is SIGKILLed rather than asked to stop.

The re-entry is the canonical race check. `prctl(PR_SET_PDEATHSIG)` cannot
deliver for a parent that had already exited when it was armed, so the parent
recorded before arming is compared with the parent after arming, and a mismatch
exits 125 rather than running with a signal that can never arrive. util-linux
`sys-utils/unshare.c` opens a pidfd for the parent before forking and polls it
after the prctl for the same reason; Go's `syscall/exec_linux.go` compares
getppid() with the saved pid. `setpriv(1)` itself does neither: its source is a
bare prctl. A caller that knows its own pid before it forks closes the earlier
window too, with `--owner $$`; `conftest.py` and `tools/example_parity.py` pass
it.

Decided: prefer a GNU-compatible `timeout` when the box has one, by reading
`--version` for "GNU coreutils" over `timeout`, `gnutimeout`, `gtimeout`.
Resolved once per run and exported as `METTA_TIMEOUT`, because the probe is an
exec and a gate makes hundreds of spawns.

Decided: the gate reads the RUNNERS, not only the lane functions. 35 of them,
found by discovery rather than by a list, plus the six check scripts: 107 spawn
sites against 41 before. Seven mutations, each removing one bound from a real
file in the tree, are each caught; the seventh needed `exec` added to the
command-position pattern, because `exec sh tools/bounded.sh "$PY" -m pytest` with the
wrapper deleted leaves `exec "$PY" -m pytest` and that read as clean.
`command -v` is deliberately not a command position: it asks PATH a question.

Decided: an in-place opt-out, `# unbounded: <reason>` on the line above, rather
than an exclusion list somewhere else. Two lines in the tree carry one and both
are the reaping suite's own fixtures, where bounding the subject would remove
the thing under test.

Tried: reading the harness scripts' spawns with the shell regex -> wrong tool.
`tests/checks/*.py` and `tests/conformance/*.py` hold 118 - 76 = 42 of the
tree's spawn sites in Python, and the two that matter most are
`tests/conformance/petta.py` and `petta_capture.py`: they start their engine
with `start_new_session=True` so their own handler can `killpg` it, which puts
that engine in a SESSION no group signal from the lane above can reach. The
only bound left on one is a `subprocess.TimeoutExpired` in the parent, which is
the mechanism that cost 122 CPU-hours. Decided: read them with `ast`. A call
whose argv is a CALL is bound, which is the shape `bounded_spawn.bounded`
produces; a call whose argv begins with a literal the pass does not recognise
is spared; anything else, including an argv it cannot read, is reported, because
a pass that spares what it cannot see reports a clean run over a gap.

Rejected: a `subprocess.Popen` patch in the harness scripts, the shape
conftest.py uses. `check_gate_scratch_selftest.py` sets `PATH=/nonexistent` on
purpose and asserts on the allocator's refusal; a wrapper installed there would
refuse first and change the subject. The argv-prefix form leaves that call
alone. Revisit if the harness ever grows a spawner the AST cannot name.

Tried: putting the `bounded()` helper wherever the diff was smallest ->
`extensions/mork/mork_ffi/build.sh` got it BELOW its first use, and a gate run
printed `mork_ffi/build.sh: not built, missing:
rust-nightly-toolchain(rustup toolchain install nightly)` for a nightly that
answers `cargo 1.98.0-nightly`. In POSIX sh a call to a function not yet
defined is a `not found` exiting 127, and the `if command -v cargo && ! bounded
cargo +nightly --version` above it reads that as the toolchain being absent.
Decided: the order is a finding class of its own in
`tests/checks/check_process_bounds.py`, with a planted case, because this
change made the defect the first time it was written.

Decided: `timeout-minutes` on all five CI jobs, 45 for `gate` and `versions`
and 20 for the rest. They had none, so GitHub's 360-minute default was the only
bound on a hung swipl there. Measured over the two runs before today, per job:
gate 18 and 19 minutes, versions 10 to 14, wheel 1 to 2, report 1, platforms 0
to 2. The values are two and a half to three times the observed cost.

Measured, gate cost: `GATE_ONLY=1 sh tools/check.sh`, same worktree, same
provisioning, on a box carrying five other agents' gates.

    before   at 5ec49f07  1281s  exit 1  loadavg 23.21 -> 28.75  seat unbuilt
    after    at cafa7cae  1494s  exit 1  loadavg 31.80 -> 61.02  seat unbuilt
    seatful  at 40a1bda7  1336s  exit 1  loadavg 81.55 -> 37.74  seat BUILDING
    final    at b6fd7179  1259s  exit 1  loadavg 26.07 -> 48.46  seat BUILDING

No duration is evidence and none is offered as any: the load average ran
between 21 and 87 on 32 cores throughout, from five other agents' gates and
four `codex-as-mcp` processes each pinned at 98 to 99% of their entire elapsed
time until they were killed mid-sequence; the third run is 158s FASTER than the
second while starting at 2.5 times the load; and the wrapper itself got 9 to 15
times CHEAPER over the same interval (0.35ms bare, 59.65ms for the `timeout`
this replaces, 6.67ms for bounded.sh, 4.07ms with METTA_TIMEOUT pre-resolved as
check.sh does it; 40 calls, min of five, loadavg 43-48). A quiet-box
measurement is the integrator's to schedule.

What the runs establish is the lane set. Three lanes changed state and each was
chased to a cause. `spec-status-selftest` and `evidence-selftest` were MINE and
are fixed: both plant a copy of engine/test.sh and anchor on its selection
line, which moved with the suite argument. `pytest` went red once at loadavg
81.55 with `worker 'gw2' crashed`, and is not: no OOM and no segfault in the
journal, the file passes alone, its directory passes under the gate's own xdist
configuration, and the lane passes in 136s at loadavg 30-43. `plunit` went red
once in the final run, on `lib_thread:a_saturated_timer_pool_does_not_block_
scheduler_deadlines`, whose helper polls a thread pool with `sleep(0.005)` for
a bounded number of attempts; the suite passes alone in 5s and the whole lane
passes in 37s at loadavg 37-44. `build` went red from the final run on and is
not either: `~/.cargo/config.toml` makes sccache
the rustc wrapper, sccache's server socket goes under `$TMPDIR`, and
gate_scratch.sh's repository-local TMPDIR is 115 characters inside an agent
worktree against `sun_path`'s 108. Isolated: the same `sccache rustc -vV` fails
with the gate's TMPDIR shape and answers `rustc 1.98.0-nightly` with the
default one. It appears only now because the MORK build reached rustc for the
first time here, and it is fixed on petta at 14fd2421, after this base, by
giving that one cargo invocation TMPDIR=${XDG_RUNTIME_DIR:-...} rather than by
shortening the gate's scratch: measured, sccache 0.15.0 answers at TMPDIR
lengths 60, 70 and 80 and refuses at 90, so a shortened scratch would have left
one character of margin.

Measured, the per-thread hazard, a second and stronger way: every spawn this
repository makes from Python comes from the MainThread, in the xdist controller
and in each worker alike, and a CPython main thread does not exit before its
process. Recorded `threading.current_thread()` at each Popen across a
four-worker run: 43 spawns over five processes, all MainThread, none exited at
session finish. The one ThreadPoolExecutor that spawns, in
tools/example_parity.py, calls blocking `subprocess.run`, so its worker cannot
exit before its child either. That argument does not depend on the kernel at
all, and it is the one the conftest header now leads with.

Tried: `git checkout -- <file>` to restore after a planted mutation, which is
the obvious move -> WRONG while the change under test is uncommitted. It
reverts to HEAD and takes the change out along with the mutation. It happened
twice; the second time it silently removed an unrelated fix and made three
later mutations report "caught" against a tree that was already unbounded for
another reason. Decided: restore from a copy taken before the mutation, under
this task's own ai-tmp, and never `git stash`, whose stack is one ref shared by
every worktree of this repository.

Open: the pre-startup half of the arming race stays open for a shell caller. A
wrapper that reads `getppid()` after it starts cannot tell its original caller
from a subreaper that adopted it, and comparing against 1 is wrong both ways.
Closing it needs the caller to hand over an identity or a pidfd before the
fork, which the Python callers now do and a `bounded()` shell function cannot,
because `$$` in a subshell still names the outer shell. The residual window is
one fork plus one `sh` startup, and a spawn that loses it degrades to the
deadline rather than to nothing.
