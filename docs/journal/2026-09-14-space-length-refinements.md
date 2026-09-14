# Space length refinements read their owners

Goal: admit or refuse a space length constraint by the visible store's
cardinality while preserving the owner's cost and consumption promises.

## 2026-09-14

Tried: `python ai-tmp/ai-classes-c49-space-length.py` passes spaces with
zero, one and two rows to `(Annotated SpaceType (MinLen 1))`. All three
are refused both here and at pristine c75181adc. Logs:
`ai-classes-c49-space-length-{main,c751}.log`. Atomic names have no length
owner. Parametric names reach the ordinary list case, counting name fields.

Decided: use the existing `grounded_length/2` ownership seam. Native spaces
combine each store's `space_atom_count/2` along `space_read_chain/2`.
Foreign stores require their own length query. The Python owner uses its
existing `_provider_length` and `Sized` contract. A recognized space cannot
fall back to its name's list arity when the owner declines. Ordinary
expressions retain their child count.

The native bound is the number of storage predicates across the inherited
chain, independent of the number of rows sharing a predicate. This reuses
the engine's existing clause bookkeeping and capacity counters. Every link
must answer; collecting only successful counts would silently omit an
unsized parent. The metadata read does not consume a linear source.

Rejected: enumerate a foreign provider when it has no length promise. The
existing Python container contract refuses that hidden remote scan.
Rejected: use only the front store's capacity count. Length describes the
visible value, including inherited rows and duplicate occurrences.
Rejected: add a new counter or space-specific extension point. The engine
already supplies the required ownership and counting interfaces.

Tried: the new native fixture first used a nonexistent named-space helper,
raising `Unknown procedure: plunit_space_length_refinements:metta_declare_named_space/1`.
It now uses `new-space/1`. A synthetic parametric foreign owner also refused
cleanup because it supplied no clear operation; that fixture mixed native
and foreign ownership and was removed. The corrected native baseline has
four failed instances and five passing controls. Log:
`ai-classes-c49d-native-baseline.log`. Exact counts use `(Len n n)`;
the one-bound `(Len n)` means a minimum.

Tried: binding generation refused
`undeclared Python service metta.foreign:_provider_length/1`. Naming the
existing direct import in `interface.py:PYTHON_SERVICES` supplies its
signature to the crossing checker. Generation then passes in
`ai-classes-c49d-binding-complete.log`.

Tried: the first Python fixture wrote repeated equations into the session's
`&self`, producing duplicate answers in three cases. The provided
`scratch_space` fixture gives each parameterized case its own declaration
home. All 56 length and container cases then pass in
`ai-classes-c49d-python-isolated.log`; the provider implementation is unchanged.

Measured: after removing QLF files, `swipl -q -s
ai-tmp/ai-classes-c49d-count-costs.pl -- extensions` compares 100 reads of
the same visible bag through owner metadata and enumeration. Five samples
agree exactly for every row count:

| Rows | Owner inferences | Enumeration inferences |
| ---: | ---: | ---: |
| 0 | 7,002 | 2,002 |
| 100 | 8,002 | 32,202 |
| 1,000 | 8,002 | 302,202 |
| 10,000 | 8,002 | 3,002,202 |

The fixture holds one predicate's rows; the metadata bound is per storage
predicate, not constant across unrelated predicate counts. Log:
`ai-classes-c49d-count-costs.log`.

The Prolog clone scan reads all three changed provider units: 1,707 lines,
11,909 tokens, zero clones. Command: `jscpd --no-gitignore --noTips
--max-lines 10000 --max-size 1mb --format prolog --formats-exts
'prolog:pl,plt' --reporters json --output ai-tmp/ai-classes-c49d-clones
engine/metta/refinements.pl engine/spaces/native_matching.pl
extensions/python/metta/_binding/provides/ownership.pl`. Log:
`ai-classes-c49d-clones.log`.

## 2026-09-14: owner guards

The foreign owner must recognize a supplied atomic identity before querying
Python. An open value otherwise chooses a registered provider during type
reasoning. `test_foreign_space_length_does_not_choose_a_value_for_a_variable`
checks that it leaves the value open, claims no owner and performs no Python
length read. `atom/1` guards the existing ownership query.

Remeasured: `swipl -q -s ai-tmp/ai-classes-c49d-count-costs.pl -- extensions`
after deleting QLF files reproduces all four rows above, five times each.
Log: `ai-classes-c49d-count-costs-verified.log`. The final three provider
files have 1,710 lines and 11,920 tokens with no clones. The same jscpd
command uses `--reporters console,json --output
ai-tmp/ai-classes-c49d-clones-verified`; its log is
`ai-classes-c49d-clones-verified.log`.

Tested: `sh ai-tmp/ai-classes-c49d-verify.sh ai-classes-c49d-verified`
passes 763 native tests plus 319 subtests across 28 suite reports, 2,057
Python cases and 594 space cases. All selected checks pass: binding and its
85 selftests, layering, ruff, mypy, evidence and refusal-grounds. Logs:
`ai-classes-c49d-verified-{native,python,spaces,checks}.log`.
`python extensions/python/tools/bindinggen.py --write` also passes in
`ai-classes-c49d-binding-verified.log`; it regenerates the ownership crossing
from the declared existing Python length service.
