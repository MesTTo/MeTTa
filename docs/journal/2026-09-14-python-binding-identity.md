# Python binding identity

Goal: preserve the identity of a Python binding across native equation scopes.

## 2026-09-14

The problem is name capture at a language boundary. Existing analogies are
macro alpha conversion, lambda lifting, compiler SSA names, database identifier
quoting and serialization escapes. Each retains an identity while translating
its representation. The Python compiler already has source-to-native scope
maps and a shared set of allocated SSA names. No additional binder model is
needed.

Source: CPython 3.14 lexical analysis, section 2.3.3, specifies `_` as an
ordinary identifier except in a case pattern. The native parser deliberately
makes `$_` fresh at each occurrence; e420a2d065647db8365085654c04d4cb582604d1
introduced that rule. Both shared decoders in
`extensions/python/metta/_binding/wire.pl:metta_py_decode_shared_tagged/5`
preserve it. Reference:
https://docs.python.org/3.14/reference/lexical_analysis.html#reserved-classes-of-identifiers .

Decided: map a Python binding named `_` to `_-`, a named native variable
outside Python's identifier grammar. Source scopes, declaration heads and
signature images share that map. SSA allocation applies it before checking
the existing set of used names. Python argument labels retain their source
spelling; explicit native atoms and pattern wildcards keep their native role.

Rejected: change Variable or the wire decoder, because either would change
the meaning of explicit V._ and native patterns. Rejected: repair local
assignment alone, because parameter heads, lifted helpers, class receivers,
rule parameters and type parameters reach the same boundary independently.

Tried: the initial regression suite reported 22 failed and one passed in
`ai-tmp/ai-classes-c45-hygiene-before-final.log`. At c75181adc, 16 of the same
binding failures reproduce and two immediate-lambda calls instead hit that
cut's known computed-call refusal. Its already-supported unpacking case
passes; four cases requiring the new class and callable layers are deselected.
The control log is `ai-tmp/ai-classes-c45-hygiene-control.log`.

Tried: shared name escaping fixed 21 cases. The remaining result comparison
for a mismatched named rule assumed an unreduced term; native evaluation
correctly returns no answers. The other failure was lambda capture: a nested
parameter reused its outer binding. An ordinary `item` parameter reproduced
the capture on this branch while passing at c75181adc. Stored lambda and fold
forms named `_` fail at both cuts. Logs are `ai-classes-c45-shadow-before.log`
and `ai-classes-c45-shadow-control.log` under `ai-tmp/`.

Decided: every nested binder uses the existing SSA allocator, and each lambda,
comprehension and fold records its binders before compiling its body. A new
parameter also discards the outer value's number, container, dictionary,
space and record proofs. Two discriminating shadow tests failed before the
proof reset: indexing returned no answer, and addition raised
`'py-list'/2: Type error: \`expression' expected, found \`0' (an integer)`.
The full trace is `ai-tmp/ai-classes-c45-shadow-proofs-before.log`.

The nested walrus test retains its existing explicit scope refusal. The
repair changes native binding identity and does not invent new walrus scope
semantics. Explicit native wildcards remain separate occurrences.

Verified: `python -m pytest -q -n 0 --benchmark-disable
extensions/python/tests/ch11_python_as_a_notation/test_binding_identity.py`
passes 33 cases, including Hypothesis comparisons over source binders and
the six grain/constructor combinations. Log:
`ai-tmp/ai-classes-c45-hygiene-all.log`. The two representation-proof failures
also reproduce at c75181adc in `ai-classes-c45-shadow-proofs-control.log`.
`python ai-tmp/ai-classes-c45-control-tree.py` compares every archived
production file under `engine`, `lib` and `extensions/python/metta` against
Git: 344 files, zero mismatches, cut
c75181adc999adf0028616ee69565e2bbfbf739f.

Verified: `sh ai-tmp/ai-classes-c45-verify.sh` passes all three phases. The
exact commands are in the adjacent `ai-classes-c45-{python,native,checks}.command`
files, and each corresponding `.status` is 0. Python passes 1,944 cases at
`-n 6 --randomly-seed=1125382488`; the thirteen native suite processes pass
265 tests plus 63 subtests. Layering, Ruff, mypy, refusal grounds and evidence
pass. Evidence has zero unbacked claims among 7,748 claims before pinning.

Reviewed: `jscpd --format python --max-lines 10000 --max-size 1mb --noTips
--reporters console,json --output ai-tmp/ai-classes-c45-clones` over all eleven
changed production files examines 9,238 lines and 83,450 tokens. Its two
clones are ten unchanged lines of declarative door metadata in
`definitions.py`. Those per-door contracts remain local; extracting them
would hide the metadata from its consumers. No changed binder logic is
duplicated. The console and JSON reports are under `ai-tmp/ai-classes-c45-clones`.
