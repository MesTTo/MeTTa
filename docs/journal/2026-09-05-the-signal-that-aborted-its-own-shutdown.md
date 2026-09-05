# The signal that aborted its own shutdown
Goal: `test_serve_and_boot_expose_spaces_until_interrupted` fails intermittently
under load; find out why.
Constraint: a shutdown must not be abortable by the signal that asked for it.

## 2026-09-05

Tried: reproducing it. One SIGINT, twelve attempts, all exit 0. So the failure
needs something the plain case does not have.

Tried: making the condition rather than waiting for it. Two signals 20ms apart,
after serving one request, reproduces it 10 times out of 10:

    __main__.py _serve -> server.close()
    remote.py close -> _raise_failures("remote server close failed", failures)
    remote.py _stop_http -> self._httpd.shutdown()
    socketserver.py shutdown -> self.__is_shut_down.wait()
    KeyboardInterrupt

So the second signal lands in `socketserver.shutdown`'s wait,
`RemoteServer._stop_http` catches it as a close FAILURE, and `close()` re-raises
it out of `_serve`'s `finally`. The graceful shutdown the first signal asked for
is aborted by a repeat of the same signal, and the process exits nonzero having
half torn down.

Decided: hold SIGINT off for the duration of the close, restoring the previous
handler afterwards. The shape is `asyncio.Runner`'s, which installs its own
handler for a run and restores it in `finally`, treating the first signal as the
graceful request and only a later one as `KeyboardInterrupt`. Its guards are
copied too, main thread only and tolerating a `ValueError`, because
`signal.signal` raises where signals are not registered
[source: /usr/lib/python3.14/asyncio/runners.py:111-138,159-166]. The close is
bounded by its own timeout, so holding the signal cannot hang a shutdown.

Measured: unguarded 10 of 10 exit -2, guarded 10 of 10 exit 0.

Rejected: an end-to-end pytest regression, after four attempts. Serving a
request first to widen the window, exactly two signals rather than a burst, and
looping five attempts each left the test GREEN against the unguarded code, while
the identical body in a standalone script failed every time. Every one of those
attempts was checked with the guard removed, and one of the checks was itself
faulty: two plant scripts called `str.replace` without asserting the match
count, so a no-op looked like a passing control. Revisit if the difference
between the pytest host and a plain subprocess is ever isolated; this repository
proves overlap with a barrier elsewhere, and a barrier cannot be threaded into a
subprocess's shutdown without changing what is measured.

Decided instead: assert the guard's contract directly, which is deterministic.
SIGINT is `SIG_IGN` inside the block, the previous handler is back outside it,
and it is restored even when the close raises. Proven to discriminate by
replacing the mask with a read: `assert <built-in function default_int_handler>
is <Handlers.SIG_IGN: 1>`.

Open: this is NOT what made the Node agent's harness run red. That was
`/usr/bin/timeout` being uutils 0.8.0 where the harness wanted GNU, plus a
`ps -o args` truncation needing `COLUMNS=512`. Two causes, one symptom; the race
here is real and reproduces from a script with no harness involved.

Evidence: 3,045 Python tests pass, against 3,042 before.
