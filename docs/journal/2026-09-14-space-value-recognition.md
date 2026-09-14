# Space value recognition preserves open terms

Goal: distinguish a known space value from an open expression without choosing
an instance for the caller.

## 2026-09-14

Tried: compare cached evaluation, native source execution and raw storage for
seven parametric sibling spaces. Cached evaluation returns no answer for
numeric names after a string name. Both this tree and pristine c75181adc
reproduce the split in `python ai-tmp/ai-classes-c49b-native-siblings.py`.
The source and raw storage answers agree for all seven names. Logs are
`ai-classes-c49b-native-siblings-verified.log` and
`ai-classes-c49b-native-siblings-control.log`.

Tried: retain the expression before and after recognition and translation.
`python ai-tmp/ai-classes-c49c-recognition.py` shows
`[recognition,_Field]` becoming `[recognition,"tenant"]` when passed to
`metta_space_operand/1`. Translating the abstracted get-atoms template binds
the same field and emits a call naming that instance. Each of the three
type-candidate readers and `metatype_of/2` makes the same binding. Log:
`ai-classes-c49c-recognition-qualified.log`. The first probe reached an
unexported reader without its owning module and raised
`once/1: Unknown procedure: get_type_candidate_in/3`; qualifying through
`metta_engine_module/1` corrects the probe.

Decided: the existing value-recognition door requires a ground parametric
name before consulting the registry. Type and metatype readers use that
same decision. The registry itself remains a relation, so reflection can
still enumerate instances. The atomic prefix rule remains upstream's rule.

Rejected: freezing all numeric or string leaves in translation cache keys.
The cache correctly asks for general code; the recognizer changes the source
term while answering a question about its kind. Keeping that mutation would
leave the same defect in typing, matching and ownership consumers.

The baseline command `sh engine/test.sh
tests/prolog/suites/spaces/value_recognition.plt` reports eight failed
instances and two passing instances across six tests and four additional
subtests. The passing controls preserve registry enumeration and reject a
wholly unbound operand. Log: `ai-classes-c49c-native-before.log`.

Verified: `sh ai-tmp/ai-classes-c49c-verify.sh` passes 755 native tests plus
317 subtests across 27 suites, 2,049 Python compiler and boundary cases,
594 space and lifetime cases, and layering, Ruff, mypy, evidence and
refusal-grounds. Each phase removes QLF artifacts before execution. Commands
and logs share the `ai-classes-c49c-` prefix; the four phase logs use
`verified-{native,python,spaces,checks}.log`.

The clone scan requires both the `.pl` extension mapping and a size ceiling
above `types.pl`'s 111,305 bytes. `jscpd --no-gitignore --noTips --max-lines
10000 --max-size 1mb --format prolog --formats-exts 'prolog:pl,plt'
--reporters console,json --output ai-tmp/ai-classes-c49c-clones
engine/spaces/bounded_matching.pl engine/metta/types.pl` reads both files:
3,336 lines, 22,250 tokens, two existing clones covering 17 lines. Their
intervals are outside the changed recognition clauses. No extraction is
warranted. Log: `ai-classes-c49c-clones-complete.log`.
