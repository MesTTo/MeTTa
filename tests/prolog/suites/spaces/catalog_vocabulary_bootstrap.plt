/* Purpose: compare compiled vocabulary storage with ordinary publication and
   exercise the states that require admission or observable row arrival.
   Owns resources: cb_cold/1 rolls back catalog and cache mutations and its
   assertion-failure hook after success, failure or exception.
   Guarantees: the compiled seed preserves the ordered ordinary type atoms;
   changed metadata, schemas and watchers retain their observable behavior
   [tested: sh engine/test.sh suites/spaces/catalog_vocabulary_bootstrap.plt;
   commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(catalog_vocabulary_bootstrap).
:- meta_predicate cb_cold(0).
:- dynamic cb_seen/1.
:- dynamic cb_initial_indexes/1.
:- ( predicate_property('$metta_atoms:&metta':'&metta'(_,_,_), indexed(Indexes))
   -> true ; Indexes=[] ),
   assertz(cb_initial_indexes(Indexes)).

test(initial_publication_prepares_type_subject_lookup) :-
    cb_initial_indexes(Indexes),
    assertion((member(Index, Indexes), get_dict(arguments, Index, Arguments),
               memberchk(2, Arguments))).

cb_rows(Rows, Refs) :-
    findall([Head,Subject,Type]-Ref,
            ( clause('$metta_atoms:&metta':'&metta'(Head,Subject,Type), true, Ref),
              memberchk(Head, [':', ':<']) ), Pairs),
    pairs_keys_values(Pairs, Rows, Refs).

cb_cold(Goal) :-
    snapshot((
        asserta((prolog:assertion_failed(Reason, Failed) :-
                    throw(error(assertion_error(Reason, Failed), _)))),
        cb_rows(_, Refs), maplist(erase, Refs),
        retractall(spaces:metta_vocabulary_types_published),
        call(Goal)
    )).

test(the_compiled_physical_rows_equal_ordinary_publication_in_order) :-
    cb_rows(Compiled, Refs),
    assertion(Compiled = [_|_]),
    source_file(catalog_vocabulary_seed:seed_rows(_), Seed),
    forall(member(Ref, Refs), assertion(clause_property(Ref, file(Seed)))),
    catalog_vocabulary_seed:seed_rows(Recipe),
    assertion(Recipe == Compiled),
    cb_cold((
        spaces:metta_publish_every_vocabulary_type,
        cb_rows(Ordinary, _), assertion(Ordinary == Compiled)
    )).

test(a_later_publication_restores_removed_rows_without_reloading_the_seed) :-
    cb_rows(Expected, _),
    spaces:metta_publish_every_vocabulary_type,
    cb_rows(Repeated, _), assertion(Repeated == Expected),
    cb_cold((
        assertion(spaces:metta_vocabulary_seed_context),
        spaces:metta_publish_every_vocabulary_type,
        cb_rows(Actual, _), assertion(Actual == Expected)
    )).

test(each_changed_metadata_head_excludes_the_seed,
     [forall(member(Row, [[vocabulary, cb_extra, word],
                         ['vocabulary-member','provider-capability',cb_extra],
                         ['vocabulary-type',fidelity,'ChangedFidelity'],
                         ['vocabulary-order',world,'closed-world','open-world']]))]) :-
    cb_cold((
        add_sexp('&metta', Row, _),
        assertion(\+ spaces:metta_vocabulary_seed_context),
        spaces:metta_publish_every_vocabulary_type,
        assertion(metta_catalog_row(Row)),
        forall(metta_catalog_row([vocabulary,Vocab|_]),
               ( spaces:metta_vocabulary_type(Vocab, Type),
                 spaces:metta_vocabulary_values(Vocab, Members),
                 forall(member(Member, Members),
                        assertion(metta_catalog_row([':',Member,Type]))) ))
    )).

test(an_existing_type_atom_is_not_duplicated,
     [forall(member(Row, [[':','Fidelity','Type'], [':<','Exact','Partial']]))]) :-
    cb_cold((
        add_sexp('&metta', Row, _),
        assertion(\+ spaces:metta_vocabulary_seed_context),
        spaces:metta_publish_every_vocabulary_type,
        findall(yes, metta_catalog_row(Row), Found),
        assertion(Found == [yes])
    )).

test(a_watcher_sees_each_type_arrive_in_its_own_prefix,
     [forall(member(Head, [':', ':<']))]) :-
    cb_cold((
        spaces:watch_catalog_rows(Head),
        assertz((seam:catalog_row_changed(added, [Head,_,_]) :-
                    aggregate_all(count, spaces:metta_catalog_row([Head,_,_]), Count),
                    assertz(plunit_catalog_vocabulary_bootstrap:cb_seen(Count)))),
        assertion(\+ spaces:metta_vocabulary_seed_context),
        spaces:metta_publish_every_vocabulary_type,
        findall(Count, cb_seen(Count), Seen),
        aggregate_all(count, spaces:metta_catalog_row([Head,_,_]), Total),
        numlist(1, Total, Expected), assertion(Seen == Expected)
    )).

test(a_declared_type_schema_still_refuses_the_first_invalid_atom,
     [forall(member(Head, [':', ':<']))]) :-
    cb_cold((
        add_sexp('&metta', [kind,Head,symbol,integer], _),
        assertion(\+ spaces:metta_vocabulary_seed_context),
        catch((spaces:metta_publish_every_vocabulary_type, Outcome=succeeded),
              Error, Outcome=raised(Error)),
        assertion(Outcome = raised(error(metta_declaration_malformed(_,2,_),_))),
        assertion(\+ metta_catalog_row([Head,_,_]))
    )).

test(an_existing_execution_module_excludes_the_seed) :-
    cb_cold((
        assertz(spaces:metta_exec_module_known('&metta', cb_execution_module)),
        assertion(\+ spaces:metta_vocabulary_seed_context)
    )).

:- end_tests(catalog_vocabulary_bootstrap).
