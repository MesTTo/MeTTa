% Purpose: compare projected function metadata with its complete source rows.
% Guarantees: head aliases, duplicate occurrences, source ownership and runtime
%   answer bags agree through insertion, removal and rollback
%   [tested: run_tests(translator_metadata_projection); commit=e246959279271d22f166a1c8fb1840896295a020].
% Assumes: private metadata access is needed to compare the indexed read with
%   its source relation and to inspect the exact occurrence references.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(translator_metadata_projection).

function('$plunit_metadata_projection').

clean_metadata :-
    function(F),
    clear_fun_meta(_, F).

record(Args, Body) :-
    function(F),
    translator:record_fun_meta(F, Args, Body).

canonical(Term, Canonical) :-
    copy_term(Term, Canonical),
    numbervars(Canonical, 0, _).

head_rows(Kind, Probe, Rows) :-
    current_metta_module(Module),
    function(F),
    findall(Probe,
            ( Kind == source
            -> translator:fun_meta_clause(Module, F, Probe, _)
            ;  translator:fun_meta_head(Module, F, Probe)
            ), Raw),
    maplist(canonical, Raw, Rows).

consistent_projection :-
    current_metta_module(Module),
    function(F),
    findall(Ref,
            clause(translator:fun_meta_clause(Module, F, _, _), true, Ref),
            SourceRefs),
    findall(Ref,
            translator:fun_meta_projection(Module, F, Ref, _), ProjectedRefs),
    assertion(ProjectedRefs == SourceRefs),
    forall(translator:fun_meta_projection(Module, F, Ref, HeadRef),
           ( clause(translator:fun_meta_clause(Module, F, Args, _), true, Ref),
             clause(translator:fun_meta_head(Module, F, Head), true, HeadRef),
             assertion(Args =@= Head) )),
    head_rows(source, _, Expected),
    head_rows(projected, _, Actual),
    assertion(Actual == Expected).

probe([]).
probe([a]).
probe([_]).
probe([X, X]).
probe([_, _]).
probe([[tag, X], X]).
probe([[tag, 1], 2]).
probe([[row, [':seg', _]]]).

record_adversarial_heads :-
    record([], zero),
    record([a], first),
    record([a], duplicate),
    record([X, X], [same, X]),
    record([Y, Z], [different, Y, Z]),
    record([[tag, U], U], [nested, U]),
    record([[row, [':seg', V]]], [segment, V]).

test(projected_head_bags_and_bindings_equal_the_source,
     [ setup((clean_metadata, record_adversarial_heads)),
       cleanup(clean_metadata), forall(probe(Probe)) ]) :-
    head_rows(source, Probe, Expected),
    head_rows(projected, Probe, Actual),
    assertion(Actual == Expected),
    consistent_projection.

test(removing_an_occurrence_retires_its_exact_projection,
     [setup(clean_metadata), cleanup(clean_metadata)]) :-
    record([X], [left, X]),
    record([Y], [right, Y]),
    record([Z], [left, Z]),
    current_metta_module(Module), function(F),
    once(clause(translator:fun_meta_clause(Module, F, _, [left, _]),
                true, RemovedRef)),
    once(translator:fun_meta_projection(Module, F, RemovedRef, RemovedHeadRef)),
    drop_fun_meta(Module, F, [P], [left, P]),
    assertion(var(P)),
    assertion(\+ translator:fun_meta_projection(_, _, RemovedRef, _)),
    assertion(clause_property(RemovedHeadRef, erased)),
    consistent_projection,
    aggregate_all(count, translator:fun_meta_head(Module, F, _), 2).

mutation(insert) :- record([new], added).
mutation(remove) :-
    current_metta_module(Module), function(F),
    drop_fun_meta(Module, F, [X], [kept, X]).
mutation(clear) :- clean_metadata.

test(transaction_rollback_restores_every_indexed_occurrence,
     [setup(clean_metadata), cleanup(clean_metadata),
      forall(member(Action, [insert, remove, clear]))]) :-
    record([X], [kept, X]),
    record([Y], [kept, Y]),
    catch(transaction((mutation(Action), throw(projection_rollback))),
          projection_rollback, true),
    consistent_projection,
    current_metta_module(Module), function(F),
    aggregate_all(count, translator:fun_meta_head(Module, F, _), 2).

clean_source_journal :-
    forall(retract(filereader:source_load_assertion(
                        '$plunit_projection_source_owner', artifact, Ref)),
           erase(Ref)).

test(source_journal_retires_the_primary_and_both_projections,
     [setup(clean_metadata),
      cleanup((clean_source_journal, clean_metadata))]) :-
    Load = '$plunit_projection_source_owner',
    filereader:with_owning_source_load(
        Load, plunit_translator_metadata_projection:record([X], [owned, X])),
    consistent_projection,
    findall(Ref, filereader:source_load_assertion(Load, artifact, Ref), Refs),
    assertion(Refs \== []),
    forall(member(Ref, Refs), erase(Ref)),
    retractall(filereader:source_load_assertion(Load, _, _)),
    current_metta_module(Module), function(F),
    assertion(\+ translator:fun_meta_clause(Module, F, _, _)),
    assertion(\+ translator:fun_meta_projection(Module, F, _, _)),
    assertion(\+ translator:fun_meta_head(Module, F, _)).

test(concurrent_writers_preserve_the_source_occurrence_order,
     [setup(clean_metadata), cleanup(clean_metadata)]) :-
    current_metta_module(Module), function(F),
    numlist(1, 80, Indices),
    concurrent_maplist(
        [Index]>>(with_metta_module(Module,
                     translator:record_fun_meta(F, [Index], [body, Index]))),
        Indices),
    consistent_projection,
    aggregate_all(count, translator:fun_meta_head(Module, F, _), 80).

% The oracle reads all the old source rows. snapshot/1 restores the production
% facts and any translation artifacts even when a differential assertion fails.
source_metadata_view :-
    retractall(translator:fun_meta_head(_, _, _)),
    assertz(translator:(fun_meta_head(M, F, Args) :-
                           fun_meta_clause(M, F, Args, _))),
    retractall(translator:fun_meta_projection(_, _, _, _)),
    assertz(translator:(fun_meta_projection(M, F, Ref, _) :-
                           clause(fun_meta_clause(M, F, _, _), true, Ref))).

runtime_fixture(Space, Module) :-
    Space = '&plunit-metadata-projection-runtime',
    metta_host_clear_space(Space),
    space_module(Space, Module),
    filereader:metta_host_run_source(
        "(= (metadata-bag $x) (superpose ($x $x)))\n\c
         (= (metadata-bag 1) 7)\n\c
         (= (metadata-pair $x $x) same)\n\c
         (= (metadata-pair $x $y) different)\n\c
         (= (metadata-match (tag $x)) $x)\n\c
         (= (metadata-empty 0) (superpose ()))\n\c
         (= (metadata-call $x) (metadata-bag $x))\n\c
         (: metadata-segment (-> Atom Atom))\n\c
         (= (metadata-segment (row (:seg $xs))) $xs)", Space, [], _).

runtime_probe("(metadata-bag 1)").
runtime_probe("(metadata-bag $x)").
runtime_probe("(metadata-pair 1 1)").
runtime_probe("(metadata-pair 1 2)").
runtime_probe("(metadata-pair $x $x)").
runtime_probe("(metadata-match (tag 3))").
runtime_probe("(metadata-match (miss 3))").
runtime_probe("(metadata-empty 0)").
runtime_probe("(metadata-empty 1)").
runtime_probe("(metadata-call 1)").
runtime_probe("(let $f metadata-bag ($f 1))").
runtime_probe("(metadata-segment (row a b))").
runtime_probe("(metadata-segment (row))").
runtime_probe("(superpose ((metadata-bag 1) (metadata-bag 1)))").

runtime_bag(Text, Bag) :-
    sread(Text, Term),
    term_variables(Term, Variables),
    translate_runnable_expr(Term, Goals, Value),
    current_metta_module(Module),
    findall(Variables-Value, call_goals_in(Module, Goals), Rows),
    maplist(canonical, Rows, Canonical),
    msort(Canonical, Bag).

test(public_lowering_preserves_ground_and_adversarial_bags,
     [ setup(runtime_fixture(Space, Module)),
       cleanup(metta_host_clear_space(Space)),
       forall(runtime_probe(Text)) ]) :-
    with_metta_module(Module,
                      plunit_translator_metadata_projection:runtime_bag(Text,
                                                                        Actual)),
    snapshot(( source_metadata_view,
               with_metta_module(Module,
                   plunit_translator_metadata_projection:runtime_bag(Text,
                                                                     Expected)) )),
    assertion(Actual == Expected).

:- end_tests(translator_metadata_projection).
