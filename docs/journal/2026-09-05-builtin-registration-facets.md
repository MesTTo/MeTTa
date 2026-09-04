# Builtin registration facets
Goal: make the existing builtin name registry and its implementation descriptions mutually complete.
Constraint: `builtin_fun/1` remains the only name authority; implementation clauses stay in their owning files; `engine/translator_rules.pl` and `engine/translator/lowering.pl` remain untouched.

## 2026-09-05
Tried: scan every predicate in the 20 project files that currently own core builtin hooks -> 1,435 indicators, most of them internal helpers rather than language entries. The monolithic upstream scan does not transfer to this modular engine. [measured: 1435 indicators; command=swipl -q -g "consult('engine/metta.pl'),findall(F,(builtin_implementation(N/A,D),builtin_callable_descriptor(D,R),builtin_reference_module(R,M),PA is A+1,functor(H,N,PA),source_file(M:H,F),builtin_project_implementation_file(F)),F0),sort(F0,Fs),findall(M:N/A,(member(F,Fs),source_file(M:H,F),functor(H,N,A),predicate_property(M:H,implementation_module(M))),P0),sort(P0,Ps),length(Ps,C),writeln(C),halt"; fixture=plain engine; commit=WORKTREE]
Rejected: treat every predicate in every implementation-owning file as a builtin candidate, because it would replace coverage with a four-digit helper exemption list. Revisit if implementation entry points move into dedicated modules.
Tried: project-owned predicates whose names occur in an independent surface row, combined with the existing registered names -> five unregistered predicates: `user:'=@='/3`, `spaces:metta_prune_empty/2`, `spaces:metta_require_current_capability/2`, `spaces:metta_require_safe_goal/1`, and `spaces:metta_require_space_update_capability/2`. [measured: 5 predicates; command=swipl -q -g "consult('engine/metta.pl'),builtin_implementation_coverage_inventory(I),writeln(I),halt" -- extensions; fixture=736d816a291b0253714766b085115c853fc4f077 plus Stage 1 declarations; commit=WORKTREE]
Decided: store exact implementation facets through the same declaration that registers each core name. Prelude and extension facets are derived from their existing source-owned declarations after boot. The reverse audit also scans project predicates named by the independent type, grounded-token, effect, semantic-operation, and special-form surfaces.
Decided: exempt the four `metta_*` predicates beside their implementations because the effect planner names them as compiled Prolog primitives, not language operations. Exempt `user:'=@='/3` beside `=alpha/3` because it is a legacy spelling with no registered MeTTa surface.
Open: Stage 2 cannot assign truthful typing and cardinality facets yet. The current typing table omits 42 described arity keys, and there is no complete cardinality table to migrate. [measured: 42 described arity keys; command=swipl -q -g "consult('engine/metta.pl'),findall(N/A,(builtin_implementation(N/A,_),\\+seam:builtin_type_declaration(N,_)),G0),sort(G0,Gs),length(Gs,C),writeln(C),halt" -- extensions; fixture=Stage 1 implementation facets and current builtin type surface; commit=WORKTREE]
Tried: run copy-paste detection across the touched Prolog areas -> one 9-line pre-existing clone between `remove_sexp/3` and `metta_capacity_remove_sexp/3`, outside the changed spans. [measured: 1 clone and 9 duplicated lines; command=jscpd --reporters console --format prolog --formats-exts prolog:pl,plt --pattern **/*.{pl,plt} --min-lines 8 --min-tokens 60 --max-lines 2500 --max-size 500kb --noTips engine/metta engine/spaces tests/prolog/suites/evaluation; fixture=27 Prolog files; commit=WORKTREE]
Rejected: extract the pre-existing removal clone, because its second copy adds capacity accounting on a hot storage path and no changed line depends on it. Revisit as a measured storage refactor.
Tried: the first locked inference run -> `boot` moved from 539,606 to 584,873, `evaluate` from 559,327 to 559,319, and `translate` from 380,634 to 380,550; the other four rows were identical. [measured: boot 584873, evaluate 559319, translate 380550; command=sh ../ai-gate-lock.sh builtin-facets env CHECK_PY=<the janus venv python> sh engine/bench.sh --counter-only; fixture=C reader, writer, JSON codec, and chapter 19 extension built; commit=WORKTREE]
Open: attribute each moved row by reverting one suspect engine file at a time with the QLF rebuilt in each arm, then re-pin only proven predicate-table movement.

Tried: purge and rebuild every QLF before repeating the first locked inference run -> the Stage 1 state was stable at 575,817 boot inferences; the earlier 584,873 count was not a clean rebuilt sample and is superseded. Restoring only `engine/metta/registration.pl` reduced boot to 539,591 while retaining the three exemption files. Restoring all four changed engine files reduced it to 539,531. [measured: 575817 final, 539591 registration control, 539531 base control; command=sh ../ai-gate-lock.sh builtin-facets sh ai-tmp/positive-control-registration.sh; fixture=QLF purged and rebuilt for each arm, three identical samples per arm; commit=3f949ee372c470bc3abe636133bc70cf69b45936]
Rejected: dynamically assert every static core facet from one list at each boot, because the declaration setup and validation cost 36,226 boot inferences against the registration control. Revisit if core facets become runtime-mutable rather than source declarations.
Decided: express the same exact keys as source clauses and use one directive to register their names. Runtime assertion remains only for prelude and extension facets, whose contents depend on the completed boot image.

Tried: repeat the positive control after replacing boot-time assertions with source clauses -> final boot fell to 574,713; registration at the base revision with the three local exemption files present remained 539,591; each exemption-file reversal remained 539,571; and all four affected engine files at the base revision remained 539,531. `evaluate` was 559,319 and `translate` 380,550 in every arm. Each arm purged and rebuilt the QLF set and produced three identical samples. [measured: final 574713, registration control 539591, each single-file control 539571, base control 539531; command=sh ../ai-gate-lock.sh builtin-facets sh ai-tmp/positive-control-exemptions.sh; fixture=C reader, writer, JSON codec, and chapter 19 extension built; commit=ad27d563332e61cd026d51bf8df8ffb655cc9b8a]
Decided: re-pin `boot` to 574,713. The registration declarations and validators account for +35,122 over their control, and the three implementation-local exemption files account for +20 each. Re-pin `evaluate` to 559,319 and `translate` to 380,550 because the inference gate rejects their stale improvements; the all-base control proves their -8 and -84 movements predate this work. The other four inference rows remain exact. Superseded 2026-09-06 by the landing section below: the base moved from 736d816a291b0253714766b085115c853fc4f077 to 653922f1c9692f0b93e4e615307640945eac446b and this lineage applies no pin.
## 2026-09-06
The section above was measured on the pre-rebase lineage, whose base was
736d816a291b0253714766b085115c853fc4f077 and whose commits are kept on the
backup branch `builtin-facets`. Landing rebased the work onto `petta` at
653922f1c9692f0b93e4e615307640945eac446b, 278 commits later, and every number
in that section is superseded by the arms below: the base itself moved, the
autoload-trap merge took `boot` from 543,929 to 245,276, and this tree gained
one facet, one seam home change and two scan fixes the older tree did not have.
`engine/bench-baseline.json` is UNTOUCHED here; the pin is the integrator's on
the merged tree, the way 2026-09-06-the-price-of-asking-whether-a-predicate-exists.md
left its own -303,288.

Tried: replay the three commits on trunk -> three conflicts. `CHANGELOG.md`
keeps both narratives. `engine/metta/registration.pl` conflicts because trunk
added `'if-decons-expr'` to the name list the facets replace, so the facet
`builtin_implementation('if-decons-expr'/5, prolog(engine))` is what carries it
across; its Prolog hook is `engine/metta/control.pl`'s `'if-decons-expr'/6`, so
the MeTTa arity is 5. `engine/spaces/bounded_matching.pl` conflicts on a header
line only.
Tried: `sh engine/test.sh` on the replayed tree -> two failures, both this
work against contracts trunk holds and both green on `petta`.
`seam_module:test_every_seam_is_reached_under_its_module` read
`[control_exception/1-user, builtin_implementation_exemption/2-user]`: the
exemption was declared unqualified in a plain file consulted into the engine
module, so `seam_home/2` homed it in the engine core, where that test allows
`control_exception/1` and nothing else.
`engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named`
read `metta reaches translator:embedded_operation_head/1, which translator's
module does not export`.
Decided: declare the exemption as `seam:builtin_implementation_exemption/2`, in
the module every handler seam lives in, and write the three implementation-local
clauses under that module. That is the spelling `seam:builtin_type_declaration/2`
and `seam:extension_builtin/2` already use.
Decided: stop reading `translator:embedded_operation_head/1`. It contributes no
name the other seven sources do not already carry, measured rather than assumed:
all 47 of its heads are in the 385-name union without it, and the set of 198
project-owned surface predicates is identical either way. The claim is asked of
the engine in `builtin_facets:the_translators_embedded_operations_add_no_surface_name`
rather than left in a comment, so a head that stops being covered fails a test
and the decision is made again then.
Found while running the suite against `petta`: one of its own tests could not
fail. `the_effect_planner_helpers_are_exempt_in_place` matched each expected
row with `member(Subject-Reason-Suffix, Expected)` over rows written
`spaces:metta_prune_empty/2-Reason-Suffix`, and SWI gives `:` priority 600
against `-`'s 500, so every row parses as
`spaces:((metta_prune_empty/2-Reason)-Suffix)` and the pattern matched nothing.
The forall/2 was vacuously true and the test passed against a tree with no
exemption seam at all. Parenthesising each subject and destructuring the row in
the ACTION rather than the condition makes a row that does not match fail, and
the length is pinned so an empty list cannot pass either. With that, all 20
tests fail on `petta` and all 20 pass here; before it, 19 failed and this one
passed.

Rejected: adding `embedded_operation_head/1` to the translator's export list.
It is the translator's own classification of which heads may hold a redex, and
putting a private table on a module's public surface to satisfy a reader that
gains nothing from it is the wrong half of the contract to change. Revisit if
the table ever names a head no other surface does.
