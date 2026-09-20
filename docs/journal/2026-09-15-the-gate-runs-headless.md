# The gate runs headless
Goal: a gate lane answers the same on a desktop box as in CI, whatever display the shell inherited.
Constraint: no lane may depend on an X session; the fix lives at the one point every gate process passes through.

## 2026-09-15
Tried: `GATE_ONLY=1 sh tools/check.sh` on unchanged trunk efac42a31 from a shell with `DISPLAY=:0` -> prolog-static, host-workarounds, host-workarounds-selftest and pytest's `test_example_runs_and_verifies_itself[operations/concurrency_handles]` all ended in `X Error of failed request: BadValue ... Major opcode 152 (GLX), Minor opcode 3 (X_GLXCreateContext)`; log `ai-tmp/next-work/trunk-gate-efac42a31.log`. The same class had been recorded on 2026-09-14 against prolog-static and memo-advisor-selftest from a Codex job's shell.
Tried: `DISPLAY=:0 swipl -q -f none -g 'catch(with_output_to(string(_), profile(true,[top(0)])),E,print_message(error,E)), (current_module(pce) -> writeln(pce_loaded) ; writeln(pce_not_loaded))' -t halt` -> exit 1 on the GLX error before the goal answers. `env -u DISPLAY` the same -> exit 0, the profiler's own `zero_divisor` error (the host workaround's subject), `pce_not_loaded`. `DISPLAY=:0 swipl --no-pce` the same -> exit 0, `pce_not_loaded`. SWI-Prolog 10.1.13.
Rejected: `--no-pce` at each swipl call site, because the Python examples lane fails inside a janus-embedded engine that no command line reaches, and because there are many call sites and one runner.
Rejected: a `docs/host-workarounds.md` entry with a tracked reproduction, because the reproduction would have to load xpce against a failing display, and an X error exits the process, so it cannot print `present` on the one box where the answer matters; the lane already reports such a reproduction as broken.
Decided: `bounded.sh` unsets `DISPLAY` and `WAYLAND_DISPLAY` before it starts anything, so every swipl, node and Python the gate spawns is headless, and a desktop run behaves as the CI run, which has no display. No lane needs one: no runner or check names `DISPLAY`.
Open: whether this box's GLX failure under `:0` is the session's environment or the driver; it does not matter to the gate any more.
