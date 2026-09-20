# Verifying the type checks the compiler decided not to emit
Goal: stop trusting four static discharges on the strength of batteries chosen
by whoever wrote them, and let a program prove them over its own data.
Constraint: the audited program must answer exactly what it answered, and the
mode must cost nothing when it is off.

## 2026-09-05
This engine discharges type checks in four places, and until today nothing
re-verified any of them: a literal whose type is settled at compile time
(`statically_typed_literal/2`), an argument a caller's declaration proved
(`static_parameter_proof_goal/3`), a registry walk replaced by a VM test
(`intrinsic_type_shortcut_goal/3`), and a registry walk replaced by the
metatype ladder (added the previous day). Each is a claim that the removed
check could not have failed.

Taken from `trueagi-io/PeTTa@e038e4db src/typecheck/oracles.pl`, whose
`--oracle` re-emits every statically discharged certification as a runtime
check. Three things came whole: an oracle must not mutate the program it
audits, a `det` claim is about the answering mode, and their own recorded
limitation, that an oracle adjudicating with the checker's own value relation
"can only ever re-ask the same question".

Decided: this engine can do the thing they called out of scope, because
`engine/specializer.pl` already runs translation validation over two
INDEPENDENT computations [source: Pnueli, Siegel and Singerman, Translation
Validation, TACAS 1998]. Every discharge here has an independent slow side by
construction: the check that was removed. So `verified_discharge/3` lets the
fast side decide and runs the slow side beside it, raising a disagreement.

Decided: read the mode at TRANSLATION time for the three emitted sites, so an
ordinary compile carries no trace and the mode costs nothing when off, which is
`verify-specializations`' own bargain. The metatype discharge is the exception:
it is not emitted, so it reads a runtime marker and audits code already
compiled. The pragma write materialises that marker rather than the per-call
path reading the pragma, because reading it costs a dynamic probe plus a
`getenv` on the path a `Symbol` parameter takes per call.

Found, by the test written for it: **a user metatype rule was bypassed.**
`typing_policy_fast_path_family/1` listed only `ordinary` and `widening`, so an
`add-typing-rule!` in the `metatype` family left `typing_policy_is_default/1`
true and the shape test decided the call without the registry. Before the shape
test existed a metatype check always walked the registry and the rule was
honoured whatever that list said. Fixed by adding `metatype` to the list, which
is not a preference but a completion: a fast path that reads a family, and a
family missing from that list, is an unsoundness.
[tested: metta_metatype_guards:a_user_metatype_rule_is_not_bypassed]

Found, also by a test: the coverage counters were ONE counter wearing three
names. `flag/3` does not distinguish the arguments of a compound key, so
`metta_discharge_tally(agreed)` and its two siblings shared a counter and a
single agreeing discharge read back as `agreed-1, disagreed-1, unverified-1`.
Each outcome has its own atom now.
[tested: discharge_audit:an_agreeing_discharge_is_silent_and_counted]

Found, in the test rather than the engine: `sub_term(Pattern, Term)` UNIFIES its
pattern with each subterm, and a compiled goal is full of unbound variables, so
`\+ sub_term(verified_discharge(_,_,_), Conj)` was true whatever the emitter
did. Bind the subterm and require it nonvar. Same trap as calling
`metatype_of/2` with its second argument bound, met in a different place.

Evidence the instrument works, which is a wrong-fix control rather than a
green test: planting `intrinsic_type_test('Number', _V, true)`, so the fast
side accepts everything, makes `!(n-id "not a number")` raise "the intrinsic
discharge for Number accepted "not a number", and the check it replaced refuses
it" with the mode on, and silently answer `"not a number"` with the mode off.
The hole is real either way; the mode is the difference between naming it and
not.

`examples/ch09-types/17-verify-discharges.metta` sets the pragma in the corpus,
which is not decoration: nothing in `examples/` set `verify-specializations`,
so the corpus half of the emitted-goal check never compiled a body holding its
goal and that mode was broken from the cut until the source half found it
[measured 2026-08-22].

Found while wiring the coverage: the tally had no reader. It was a shipped
capability with no visible door, which is exactly the class the llms.txt
editorial rule names as the one a gate cannot catch the way it catches roster
and count drift. Turning the mode off now reports the three counts. The first
version reported through `print_message/2` at `informational`, which `sh tools/run.sh`
suppresses with -q, so the door existed and was still invisible; it writes to
user_error now, because this is the deliberate output of a mode someone opted
into rather than a log line a quiet run is right to drop.

The same gap is OPEN in the neighbour this borrowed from.
`engine/specializer.pl` records `ho_specialization_unverified/2` and nothing
anywhere reads it, so its coverage is a number the verifier keeps to itself.
Recorded rather than fixed here: that is the specializer's track and its
docstring already promises the number is reported.

Open: the bound is 200,000 inferences per verification, chosen and not
measured. Nothing in the corpus reaches it, so it has never recorded an
`unverified`; a workload that does would be the evidence for or against that
number.
