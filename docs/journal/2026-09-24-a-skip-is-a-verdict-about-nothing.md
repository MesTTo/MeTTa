# A skip is a verdict about nothing

Goal: `parity-perf` compares the two engines in every tree the gate runs in,
and cannot pass having compared nothing.

## 2026-09-24

Measured: with `METTA_UPSTREAM` unset, the lane skipped in every battery run
that reached it. Battery 2 at 19:57 printed `note: upstream checkout not found
at .../wt-merge/ai-tmp/PeTTa-upstream; nothing to compare`, battery 119 at
19:42 the same, and both summaries read `parity-perf skipped`. The lane looked
for the checkout only as `PeTTa-upstream` beside the tree it ran in.
`tools/battery.sh` makes a battery at `ai-tmp/wt-battery-<n>` of the tree that
provisions it, so a battery's parent is that tree's `ai-tmp/`, and all 127
batteries here sit in `ai-tmp/wt-merge/ai-tmp/`, which holds no checkout. Off
CI a missing checkout exited 125, which `check.sh` reports under MEASURED
NOTHING, and a skip does not fail the gate, so every battery verdict carried
the lane green without it having run.

Decided: the lane derives where upstream is from git. After the sibling of the
tree it runs in, it looks beside the repository's main checkout, whose `.git`
`git rev-parse --git-common-dir` names from any linked worktree, and a
battery's git is one (`battery_git_identity` in `tools/battery.sh`).
`extensions/python/tools/example_origins.py`'s `upstream_root()` answered the
same failure for `PeTTa-base` this way on 2026-09-22 (b9890d7e9 in
`extensions/python`). `METTA_UPSTREAM` still names a checkout outright and
outranks both. `tests/checks/check_jupyter_kernel.py` now takes the lane's
`UPSTREAM` instead of keeping its own copy of the old default, which had the
same blind spot.

Rejected: linking the checkout into each battery's parent while provisioning,
the way `battery_link_sibling_sources` links the Rust siblings. Cargo needs
those links because it resolves the `path =` entries of a manifest itself, and
the repository cannot tell it to look elsewhere without editing the manifest.
This lane is repository code and resolves its own path where it runs. A link
reaches only trees `battery.sh` provisions and not a worktree made any other
way, and `battery.sh`, which runs no Python, would need the lane's path as
shell data: a second copy of the rule, which drifts from the first on the next
change.

Decided: an absent checkout refuses, exit 1, wherever the lane runs, naming
every place it looked. This reverses the 2026-09-06 decision in
`the-parity-floor.md` that it refuses only where `CI=true` and prints a skip
elsewhere: a gate lane that exits green without running is a verdict about
nothing. `METTA_UPSTREAM_OPTIONAL=1` is the operator's explicit opt-out and
restores the skip, 125, off CI only, since an opt-out that reached CI would let
the gate pass there having measured nothing. The rule lives in
`upstream_prerequisite()`, which `tests/checks/check_upstream_fuzz.py` calls
too, so the `parity-fuzz` report lane refuses the same way.

Tried: two selftest cases. `upstream_derivation_failures` builds a repository
with a linked worktree two directories inside it and holds the order: the main
checkout's sibling is found from the worktree, the worktree's own sibling wins
over it, and `METTA_UPSTREAM` wins over both even when it names nothing.
`upstream_prerequisite_failures` holds the refusal off CI and under it, the
refusal's text naming the pin, the opt-out and the path, the opt-out's 125 and
its note naming the pin, and the opt-out refused under `CI=true`. With the old
lookup put back the derivation case fails, and with the old policy put back
four prerequisite checks fail.

Verified: in battery 119 with the six changed files kept on the committed tree
961379005 and `METTA_UPSTREAM` unset, `parity-perf` ran and passed in 166s:
14 examples compared, 155 rows not measured at loadavg 71.78, and
`parity-perf-selftest` passed. With `METTA_UPSTREAM` naming a directory that
does not exist the lane printed the refusal and the run ended `GATE FAILED:
parity-perf`, exit 1; adding `METTA_UPSTREAM_OPTIONAL=1` turned it into
`parity-perf skipped` under MEASURED NOTHING, exit 0. Logs are
`ai-tmp/battery-logs/battery-119-20260924T20{4332,4649,4659}-*.log`.

Open: the 155. 140 of them are rows the baseline has stored as
`unmeasurable-null` (133) or `upstream-unmeasurable-null` (7) since the
2026-09-19 freeze, e81e5369e, and the lane lists those without measuring them
whatever the load; the other 15 were this run's own nulls, too wide at that
load. Of the baseline's 357 rows the lane can compare at most the 29 stored as
measured, and it passes over 188 more without a line, 186 of them upstream's
own failures (178 `upstream-error`). Under `CI=true` a listed row is fatal, so
the stored 140 fail the lane there on every run:
`CI=true python tests/checks/check_upstream_parity.py --frozen` exits 1 with
29 checked and 140 listed.
