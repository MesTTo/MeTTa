# FROM source origins and constructor elaboration

Goal: a declaration-only `(from &home (rename ((Canonical Alias))))` gives source
uses of `Alias` at the receiving home the provider's canonical head, while
explicitly supplied values, `bind!` token values and callable references keep
their meaning.
Constraint: no wrapper enters a stored atom, compiled equation, export or fast
image; map derivation stays outside publication locks; both data doors keep
their token behaviour; the form-rewriter seam stays install-on-demand.

## 2026-09-15

Decided: a parallel origin tree, `source` | `value` | `children(Origins)`,
beside each parsed form, carried as `bound_source(Origins, Parsed)` only on the
explicit-binding branch of `metta_host_run_source/4`; `seam:form_rewriter/1`
callables take four arguments and `filereader:rewrite_source_form/5` validates
the returned tree. Rejected: opaque wrappers inside terms, because extension
pattern matching sees them. Rejected: selecting the FROM map at reader entry,
because a rewriter can add or withdraw a FROM row inside the same form;
`metta_reference_resolve_source/5` selects after the rewriter returns.
Decided: the map derives from the standing reference face
(`metta_reference_source_plan/3`: declaration roots minus names with an
integer-arity root or a local original, equal canonical heads coalesced,
distinct heads kept as `ambiguous/1` and refused only on use). Invalidation
installs a pending home-indexed reader; refresh publishes ready readers
projected from the ordinary processor bodies, or none for an empty map, so a
home without declaration origins keeps the bulk paths. Source for reading
clauses behind a wrapper: SWI fc7ef84b949378b729052c3ade79c90ce5416abb,
`src/pl-wrap.c:315-377`, `src/pl-comp.c:7282-7446`.
Tried: `ai-tmp/ai-from-mapper-mutation-probe.py` before FROM -> both cases match
(remove: 0/0/0 physical, cached and published rows and no alias answer; add:
1/1/1 and answer 19).
Open: every native control of this unit was unrun in the authoring seat.

## 2026-09-16

Tried: `git apply ai-tmp/ai-from-origin.patch` on 25cac1ef5 -> clean.
`sh engine/test.sh suites/spaces/reference_source_origins.plt` -> 14/16; both
observation controls raised `Domain error: most_general_term expected, found
rewrite_parsed_form(_, origin(_,_), _, _, _)` from `wrap_predicate/4`. Fixed by
wrapping the general head and reading the kind inside `observe_rewritten/3`.
Tried: 19 related Python files -> 5 reds in
`ch14_seeing_your_program/test_source_observation.py` that pass alone and pass
at 25cac1ef5 without the patch. Cause (`ai-tmp/ai-from-origin-observe-probe.py`):
a `.py` import registers `seam:form_rewriter(bind_python_calls)` process-wide,
the rewriter rebuilds every list through `maplist`, and the patch's
`observe_rewriter/3` treated any output that was not the same term as a
rewritten form, replacing the positioned tree with `generated('form-rewriter')`
and dropping every inner coverage row and frame.
Rejected: `==` at the root only, because one resolved leaf still drops every
sibling's coordinates. Rejected: shape-only alignment, because the patch's own
`origin_swap` control shows equal shape proving nothing.
Decided: recast's reprint rule (github.com/benjamn/recast v0.23.9
`lib/patcher.ts`, `findChildReprints`): walk the written tree, the rewriter's
input and its output in parallel; a subtree that is `==` at its position keeps
its node; a node above a change becomes
`node(Span, generated('form-rewriter', AlignedChildren))`; a length or kind
mismatch becomes `generated('form-rewriter')` with no children. Generated goals
are located at the whole form with attribution `['generated-by','form-rewriter']`
and the displaced span reports `source-coverage-unavailable`; the unavailable
filter ignores locations at the same span with that attribution. SWI's
`library(apply)` stops at `maplist/5`, so the child walk is explicit. Controls:
`a_rebuilding_rewriter_keeps_every_unchanged_coordinate`,
`a_rewritten_leaf_marks_its_own_path_and_keeps_its_siblings`,
`test_coverage_survives_a_registered_python_import_rewriter`.
Tried: layering lane -> six unexported cross-module reaches (three filereader
predicates, `metta_engine:metta_token/2` and `substitute_bound_tokens_/2`,
`seam:observation_frames/1` from the completion coordinator of 37d417bd0).
Exported the filereader three, `metta_token/2` and `observation_frames/1`;
the data door calls the public `substitute_bound_tokens/2`. policy-inventory
flagged the `[committed, discarded]` outcome list in
`metta_transaction_scope_results/5` (37d417bd0); exempted as the host's verdicts.
Measured: `ai-tmp/ai-from-origin-probe-v2.py --case costs`, 1000 `(unrelated-fact I)`
forms, three fresh processes per arm with `.qlf` cleared, min of three; control
is 25cac1ef5 with `engine/*.so` and both MORK artefacts built.

| arm | door | HEAD control | after | per form |
|---|---|---|---|---|
| no FROM | host | 44046 | 45046 | +1 |
| no FROM | native | 21081 | 21081 | 0 |
| callable-only FROM | host | 83046 | 84054 | +1 |
| callable-only FROM | native | 79084 | 79084 | 0 |
| renamed constructor | host | 88046 | 114054 | +26 |
| renamed constructor | native | 84084 | 118058 | +34 |

Profile call counts over 10000 forms attribute the +1 to
`filereader:rewrite_source_data/4`, the home-indexed door a ready reader
replaces. The first control worktree lacked `engine/*.so`, so the Prolog
reader and storage fallbacks ran (328 inferences per form), and after
`sh engine/build.sh` it still lacked the MORK artefacts, which cost
`mork_owns_space/1` plus `sub_atom/5` per write (+2 per form); both are
gitignored build outputs a detached worktree omits. The seat's single-process
before receipt (29 per form) predates the owned-record and coordinator commits
and is not a control for this patch.
Verified: reference_source_origins 18; source_observation,
source_observation_artifacts, source_positions 15, filereader, program_source 2,
reference_loading, reference_effects, reference_patterns, reference_providers,
reference_publication, reference_scopes, structural_aliases, parameter_aliases 6,
completion_results; references passes with its pre-existing
`visibility_is_a_checked_two_element_lattice` choicepoint; 604 Python tests
across 19 source, reference, import, observation and fast-image files; all
eight FROM V2 scenarios hold in fresh processes (119 checks, 54 cost samples;
the before receipts held 65 mismatched checks and one setup error); the mapper
mutation probe still matches; prolog-static, layering, policy-inventory, ruff,
host-workarounds, refusal-grounds, jscpd and jscpd-prolog pass.
Open: `python_import_alias/2` and `seam:form_rewriter(bind_python_calls)` are
never retracted (`surface.pl:load_python_source/1`, since cd62330ce); they
outlive the importing `MeTTa()` context and any withdrawal of the importing
source. Open: an active alias map costs 26 (host) and 34 (native) inferences per
unrelated two-atom form; `source_children/3` materialises an origins list per
list node on the `source` path, the constant to remove if a budget names it.
