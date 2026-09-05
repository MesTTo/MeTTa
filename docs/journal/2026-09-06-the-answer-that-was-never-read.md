# The answer that was never read
Goal: the `parity` lane's verdict must not depend on how loaded the box is.
It reported "engine 0 verdicts" for a different example on each run above
loadavg 46 and 253/253 below it.
Constraint: the lane is a GATE, so a run that did not happen has to be told
apart from a disagreement in the OUTPUT, not by a reader's judgement.

## 2026-09-06

Reproduced. Six whole-corpus runs under a 30-worker busy-loop pool
(`stress-ng` is not installed here) gave two failures at loadavg 26 to 66; ten
more with the capture instrumented gave three at loadavg 53 to 91. Sixteen
runs, five bare zeros, a different example each time and either door.

Measured, per failing capture, with the read loop instrumented to record its
exit path and to drain the pipes after it:

    example                          door     bytes  recovered  path
    04-02/08-unify_eval_branches     engine       0      5,564  poll-break
    ch03/03-string_comments          library      0        567  poll-break
    ch02/02-a-query                  library      0        358  poll-break

Every one: `returncode` 0, `stopped` None, ONE loop iteration, both pipes
still registered, and the child's whole output still readable from them after
the loop. Re-running the identical command in the same process reproduced each
byte for byte. 505 of the other 506 captures per run exited through EOF.

Found: the loop's

    ready = selector.select(timeout=min(0.25, remaining))
    if not ready and process.poll() is not None:
        break

is check-then-act over two clocks. `ready` is what epoll saw when
`epoll_wait` returned; `process.poll()` is what `waitpid` saw when the thread
next ran. On a box at loadavg 59 to 108 those are 1.6 seconds apart, and a
whole child fits in the gap: nothing was written at 0.25s, everything was
written and the child was gone by the time `poll()` was asked, and the loop
concluded that a finished child with nothing ready had nothing to say.

Rejected: re-selecting with a zero timeout after the poll and breaking only if
THAT sees nothing. It narrows the window without closing it, and it keeps a
rule that is wrong in principle. A pipe is finished when it reports EOF. The
writer's process exiting says nothing about the pipe, which its children may
still hold; CPython's own `subprocess.Popen._communicate` reads both pipes to
EOF and only then waits for the status, and that is the shape adopted.

Decided: the deadline is the only bound on a child that leaks a pipe to
something that outlives it. Removing the early break costs that case the full
ceiling instead of an immediate return, and the outcome it produces then is
"timed out", which is the honest answer; the corpus has no such case, and the
three existing capture tests (a child that closes its output before exiting, a
child still running after EOF, a bounded run that times out) hold unchanged.

Then the reporting, which is a second defect the first one only exposed. An
Outcome with no groups, no verdicts, no error and a matching status fell
through every check in `compare` to `len(engine.verdicts) != len(library
.verdicts)` and printed "engine 0 verdicts, library 5". A stopped Outcome fell
into "the configurations exited differently, engine None against library 0",
which says the two disagree when one of them was killed. And TWO stopped
Outcomes compared EQUAL at every step and passed silently.

Decided: a configuration that made no observation is its own result. It is
re-run, both doors, once; if it still answers nothing it is reported as "no
verdict: the <door> configuration answered nothing, twice", with the stop
reason, the cost, the ceiling and the loadavg, and counted apart from the
disagreements. The retry is the discipline every test runner draws in the same
place, retry the environmental class and never the assertion, and the class
here is exact: an answer that never arrived, never an answer that disagreed.

Decided: the SIGNAL is the asymmetry, not the emptiness, except for a stop.
`20-06-files-and-processes/02-standard-streams.metta` prints verdicts and no
answer group at all through either door, so "produced nothing" cannot mean
"failed to run" on its own. A stop is unconditional because two killed
configurations agree about nothing.

Measured, the ceiling, which read `[assumed 2026-08-18]`. The corpus has ONE
worst case and it is the same file on either door at every load,
`22-01-logic-programs/04-nilbc.metta`. Over six whole-corpus runs, 506
captures each:

    median loadavg   23.3   37.5   64.0   65.7   77.3  101.7
    slowest capture  26.7s  57.5s  69.3s  90.3s  61.3s  63.7s

Decided: 300s stands, now as a derivation rather than an assumption: 3.3 times
the worst cost this lane has ever been measured under and 11 times the quiet
one, which is the cost class above the slowest member that the per-item wall
ceiling rule asks for. `main` prints the slowest child it saw against that
number every run, because a ceiling derived once from a measurement nothing
repeats goes stale silently.

Falsified against the pre-change tool, each of the four regressions
[probe=ai-tmp/parity_falsify.py over `git show petta:extensions/python/tools/
example_parity.py`]:

    a child that writes late          OLD 0 bytes captured   NEW 36
    both configurations stopped       OLD compare -> None    NEW unanswered
    one stopped, one answering        OLD "exited differently, engine None
                                          against library 0"
    silent on the first run only      OLD 1 run, reports     NEW 2 runs, none

Open: the ceiling is one number for every example rather than one per example.
A per-example ceiling derived from each file's own measured cost would catch a
cost-class change in a cheap example, which this one cannot: nilbc sets the
ceiling and a 30x regression in a 0.2s example still passes. The corpus
baseline carries `our_instructions` per example, which is load-independent and
is the right input for that, but converting instructions to a wall bound needs
an assumed rate and the rate is exactly what load moves. Revisit if a cheap
example's cost class changes without a lane noticing.
