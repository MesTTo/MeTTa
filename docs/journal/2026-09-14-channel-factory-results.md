# Channel creation validates the native result species

Goal: expose an invalid native channel result before a Python handle can
turn its call syntax into a new space.

## 2026-09-14

The source-registration failure recorded in
`2026-09-14-source-registry-retirement.md` returned `(channel 3)` and then
`(channel_new 3)`. The general Space constructor correctly accepts expression
names, so the channel factory opened those unreduced calls as new stores.
The native lifetime repair restores evaluation; this separate boundary
check makes an invalid factory answer visible.

Tried: `python -m pytest -q --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch17_concurrency_and_the_loop/test_channel_creation.py`
reports 12 failures and two passes before implementation. Six invalid answer
shapes run through both factory arities. The factory accepts unreduced calls
or leaks Space construction errors; a repeated invalid name can instead hit
the scope's permanent revocation after the first bad call created it.
Registered named and parametric identities already pass. Log:
`ai-classes-c51-baseline-native-name.log`.

The first fixture spelled `S.channel_new`, which this Python notation maps
to `channel-new`. The explicit `S["channel_new"]` form tests the actual native
name; both runs report 12 failures and two passes. Each fixture owns a native
scope so a failed assertion still releases any incorrectly created space.

Decided: validate the result before calling Channel. Decoded Space handles
already carry the native species; expression answers use the existing
`call_values.is_parametric_space` relation. That ground query neither declares
a name nor binds an open template. This follows the result checks already
used by `_future` and `par_map`, while retaining registered expression names.

Rejected: checking a channel-name prefix or rejecting every expression. Space
identity is a native relation, and expression names are valid registered values.
No new host service or registry is needed.

Verified: the same focused command passes all 14 cases after implementation
in `ai-classes-c51-after.log`. Invalid answers leave the space registry
unchanged, and registered named and parametric results preserve their atoms.

Open: verify refusal, existing FIFO traffic, scope cleanup and release evidence.

Verified: `sh ai-tmp/ai-classes-c51-native.command` passes 102 native tests
plus four subtests across the thread, scope and space-recognition suites.
`sh ai-tmp/ai-classes-c51-python.command` passes 104 cases, including FIFO
traffic, finalization, parallel evaluation, callable space values and import
without Janus. Logs: `ai-classes-c51-verified-native.log` and
`ai-classes-c51-final-python.log`.

The first static run rejects the fixture's import order, redundant import
alias and unmarked regex. Correcting those three spellings preserves all
104 Python results. `sh ai-tmp/ai-classes-c51-checks.command` then passes
layering, policy inventory, Ruff, mypy, evidence and refusal grounds in
`ai-classes-c51-final-checks.log`.

The clone scan reads 1,560 lines and 9,521 tokens across the provider and
fixture, with no clones. Command: `jscpd --format python --min-lines 8
--min-tokens 80 --max-lines 10000 --max-size 1mb --no-gitignore --noTips
--reporters console,json --output ai-tmp/ai-classes-c51-clones-final
extensions/python/metta/parallel.py
extensions/python/tests/ch17_concurrency_and_the_loop/test_channel_creation.py`.
Log: `ai-classes-c51-clones-final.log`.
