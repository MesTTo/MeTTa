# The checker that read the wrong word
Goal: a spawn is judged by the command that WRAPS it, at every command
position a shell line can hold, so nothing in this tree is reworded around
`tests/checks/check_process_bounds.py` again.
Constraint: the gate scripts have no dependency beyond the standard library,
and `tests/checks/*.py` run under whatever interpreter `select-python.sh`
picks, so a shell parser has to be part of the check rather than a package.

## 2026-09-06

Found: `tests/shell/test_boot_inference_determinism.sh` carried a comment
saying its `boot_sample()` helper existed "so that `bounded` is the command
word", because `reading=$(bounded swipl ...)` was reported as an unbounded
swipl. The pattern's assignment prefix, `(?:[A-Za-z_][A-Za-z_0-9]*=\S*\s+)*`,
consumed `reading=$(bounded ` and then matched `swipl`, the next word.

Tried: widening the prefix pattern to stop before a `$(` -> rejected. It fixes
one spelling of one shape. The same pass also spared ``bad=`swipl ...` ``
(a backtick is not in its position alternation), every unbounded spawn in an
`if`/`while` condition, a `for` body and a `case` arm (a reserved word and a
pattern's `)` are not in it either), and
`RUSTFLAGS="-C target-cpu=native" ... cargo build` (the prefix's `\S*` ends at
the space inside the quotes). Five of those are SILENT holes rather than false
findings, which is the direction that costs something.

Measured, the two passes over the same nine planted command positions, each
planted once bounded and once unbounded
[fixture=tests/checks/check_process_bounds_selftest.py POSITIONS; probe=
ai-tmp/positions_against_old.py]:

    pattern   6 findings over 8 spawns   7 of 9 shapes wrong, 5 by sparing
    grammar   9 findings over 18 spawns  9 of 9 right

Decided: read the line as POSIX sh reads it. A word-level scanner that
respects quoting and nests `$( )`, backticks and `${ }`; a split into simple
commands at the operators and at `{`/`}`; and a head that steps over
assignments, redirections and the reserved words that stand in front of a
command. A command substitution's source is read as a command list of its
own, which is what makes `reading=$(bounded swipl ...)` bounded and
``bad=`swipl ...` `` not: the first names `bounded`, the second names `swipl`.

Rejected: `bashlex`, and `tree-sitter-bash`. Neither is installed here and
neither is in the check dependencies; a GATE lane that needs a package the
box may not have is a lane that stops gating. Every other file in
`tests/checks` imports the standard library and nothing else.

Rejected: treating `./foo.sh` as a spawner because it is a script that starts
more. The pattern never did, the change is a policy change rather than a
defect fix, and it would land findings unrelated to this thread.

Decided: `command` is read the way POSIX defines it. `command -v swipl` asks
PATH a question and starts nothing, and the check scripts hold fourteen of
those; `command grep -v ...` in test.sh runs a grep. Only `-v` and `-V`
describe, so the presence of one of those is the whole distinction, and
`command swipl` is no longer spared.

Found while measuring: the one unbounded spawn in the tree,
`RUSTFLAGS="-C target-cpu=native" TMPDIR="..." cargo +nightly build -p
mork_ffi --release` in `extensions/mork/mork_ffi/build.sh`. It carries
`bounded` now, in front of the assignments rather than behind them: a variable
assigned in front of a shell FUNCTION is exported for the whole of that
function's execution, so it reaches the `sh tools/bounded.sh` the function starts
[measured 2026-09-06: dash, /bin/sh and bash each print the assigned value
from a grandchild and leave the calling shell's own variable unset afterwards;
fixture=ai-tmp/env_through_function.sh].

Found: `tests/shell/test_example_runner_surfaces_failures.sh` carried a
`# unbounded:` opt-out over `sed 's|sh tools/run.sh "$f" 2>&1|...|'`, whose reason
was that the expression names a command and is not one. That was a workaround
for the same pass. The opt-out is gone and the line is a negative in the
selftest instead, because an opt-out that excuses nothing is a door left open
next to a wall that was never there.

Open: two `# unbounded: git over a temporary directory, which returns.`
comments, in `tests/checks/check_pin_provenance_selftest.py` and
`check_evidence_selftest.py`, excuse nothing either: `git` is not in
`PY_SPAWNERS`, so those calls are spared before any opt-out is consulted.
They are true statements rather than workarounds, so they stand; a rule that
made a dead opt-out a finding of its own would take them with it, and whether
that is wanted is not this thread's to decide.

Rejected: skipping heredoc bodies. Three files in the scanned set open one
(`tests/shell/test_bounded_reaping.sh`, `tests/shell/test_packaged_cli.sh`,
`extensions/mork/tests/test_missing_artefacts.sh`) and the bodies are read as
shell, which looked like a reading defect until the bodies were read: the
`# unbounded:` opt-out at test_bounded_reaping.sh:106 sits INSIDE the
`<<'TREE'` body, excusing a `sh -c '...' &` in a fixture script the suite then
runs. A heredoc that writes a script is a script, and the check covers it
today. Revisit if a body in another language produces a false finding; the
exposure is `<<'PY'` in test_packaged_cli.sh and `<<'THREADC'` in
test_bounded_reaping.sh, which are Python and C read as shell.

Open: `_uncommented` tracks an unterminated DOUBLE quote across lines and not
a single one, so the body of a multi-line `awk '...'` or `sed '...'` program
is read as shell. Fifteen lines in the scanned set hold an odd number of
single quotes. Nothing in the tree trips it today; a program whose text holds
`swipl` at what looks like a command position would produce a false finding.
