# Policy inventory distinguishes bindings from explicit alternatives

Goal: keep the policy inventory's vocabulary check valid for reflected call
annotations and the classes package's host mechanisms.

## 2026-09-14

Tried: `sh tools/check.sh policy-inventory` reports five findings in
`ai-classes-c50-verified-checks.log`. Pristine c75181adc reports none in
`ai-classes-c50-policy-control.log`; its checker, selftest and runner match
the cut's Git blobs. The affected branch lines are authored by MesTTo.

The annotation inverse constructs `typing.Literal[values]` from native
annotation records. The scanner reports the Python variable as a closed
vocabulary. The 2026-09-07 gate journal already records the corresponding
Prolog rule: bare variables carry values supplied by another binding site.

Decided: apply that same structural rule to Python Literal subscriptions and
list/set membership. Bare name references and empty alternatives name no
closed values. Mixed literals and enum attribute selections remain findings.
Both syntax consumers use one candidate constructor. No file exemption or
annotation-converter special case is needed.

Tried: `python tests/checks/check_policy_inventory_selftest.py` with the new
positive and negative fixture reports 11 planted cases and one failure,
`test_python_references_carry_no_closed_policy_values`, before the repair.
Log: `ai-classes-c52-selftest-before.log`. The explicit selftest runner now
also executes its previously omitted Prolog-variable witness.

The other findings are an ownership annotation separated from its dispatch
list and two unannotated host language mechanisms. The existing dispatch
annotation moves beside its list. SWI's assertion families and Python's two
special slots receive adjacent mechanism/language-law evidence. Neither list
selects a configurable runtime policy, and no runtime code changes there.

Rejected: exempting the reflected annotation converter from the scan. That
would hide a later explicit vocabulary in the same file. Also rejected
changing runtime slot discovery or assertion wrappers to silence this check;
their existing behavior is the language mechanism the annotations describe.

Tried: the first broader run passes 232 native tests plus101subtests and
84 Python cases. The inventory rejects three newly orphaned exemptions on
`{int, float}` in numeric lowering. Logs:
`ai-classes-c52-verified-{native,python,checks}.log`.

Rejected: the blanket Python-name rule above. A Python name can designate a
builtin, and an explicit collection of those names still chooses fixed
alternatives. The Prolog variable analogy does not preserve that distinction.

Decided: skip a bare variable supplied as Literal's complete argument bundle,
as in `typing.Literal[values]`. Its tuple contents determine zero, one or any
number of alternatives at runtime. Explicit Literal tuples and list/set
membership keep their existing ownership checks, including names of builtins.
The revised fixture preserves these negative controls and the empty explicit
membership list. No existing numeric-lowering annotation is removed.

Verified: `sh ai-tmp/ai-classes-c52-checks.command` passes policy inventory,
its 11 planted selftests, Ruff, mypy, evidence and host workarounds. The
inventory reports 20 runtime rows and no findings. The corrected standalone
selftest also passes all 11 cases. Logs: `ai-classes-c52-final-checks.log`
and `ai-classes-c52-selftest-final.log`. The runtime consumers remain the
232 native tests plus101subtests and 84 Python cases recorded above.

The final clone scan reads 989 lines and 7,081 tokens across the checker and
selftest, with no clones. Command: `jscpd --format python --min-lines 8
--min-tokens 80 --max-lines 10000 --max-size 1mb --no-gitignore --noTips
--reporters console,json --output ai-tmp/ai-classes-c52-clones-final
tests/checks/check_policy_inventory.py
tests/checks/check_policy_inventory_selftest.py`. Log:
`ai-classes-c52-clones-final.log`.
