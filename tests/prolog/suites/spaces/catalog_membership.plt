/* Purpose: verify vocabulary membership against the catalog's ordered values
   through mutation, erasure and transaction rollback, and bound the cost of
   reading one member as unrelated members grow and first reads of every member.
   Owns resources: cm_snapshot/1 discards catalog and cache writes and its
   assertion-failure hook on return or exception.
   Guarantees: the membership and list readers agree on every tested word
   [tested: sh engine/test.sh suites/spaces/catalog_membership.plt;
   commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(catalog_membership).

:- meta_predicate cm_snapshot(0).

%Plunit records failed assertions in dynamic clauses, which snapshot/1 would
%discard with the fixture. Throw inside the snapshot so plunit records the
%failure outside it. The local hook is discarded with the snapshot too.
cm_snapshot(Goal) :-
    snapshot((
        asserta((prolog:assertion_failed(Reason, Failed) :-
                    throw(error(assertion_error(Reason, Failed), _)))),
        call(Goal)
    )).

cm_vocab(Name, Words) :-
    add_sexp('&metta', [vocabulary, Name|Words], _),
    add_sexp('&metta', ['vocabulary-open', Name, "membership test"], _).

cm_member(Name, Word) :-
    add_sexp('&metta', ['vocabulary-member', Name, Word], _).

test(snapshot_surfaces_assertions_and_discards_the_fixture) :-
    catch(cm_snapshot((cm_vocab(cm_failed_fixture, [word]), assertion(fail))),
          Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(assertion_error(fail, _), _)),
    assertion(\+ spaces:metta_vocabulary_value(cm_failed_fixture, word)).

cm_agrees(Name, Word) :-
    (   spaces:metta_vocabulary_value(Name, Word)
    ->  Actual = true
    ;   Actual = false
    ),
    (   spaces:metta_vocabulary_values(Name, Values), memberchk(Word, Values)
    ->  Expected = true
    ;   Expected = false
    ),
    assertion(Actual == Expected).

test(base_and_registered_members_preserve_order) :-
    cm_snapshot((
        cm_vocab(cm_order, [z, a, z]),
        cm_member(cm_order, b),
        forall(member(Word, [z,a,b,absent]), cm_agrees(cm_order, Word)),
        spaces:metta_vocabulary_values(cm_order, Values),
        assertion(Values == [z,a,z,b]),
        findall(Word, spaces:metta_vocabulary_value(cm_order, Word), First),
        assertion(First == [z])
    )).

test(empty_and_absent_vocabularies_have_no_member) :-
    cm_snapshot((
        cm_vocab(cm_empty, []),
        forall(member(Name, [cm_empty, cm_absent]),
               forall(member(Word, [a,absent]), cm_agrees(Name, Word)))
    )).

test(a_rejected_word_does_not_leave_a_point_entry) :-
    cm_snapshot((
        cm_vocab(cm_rejected, [present]),
        cm_agrees(cm_rejected, absent),
        assertion(\+ spaces:metta_vocab_cache(cm_rejected, member(absent), _)),
        cm_member(cm_rejected, absent),
        cm_agrees(cm_rejected, absent)
    )).

test(erasing_a_member_ref_invalidates_only_its_evidence) :-
    cm_snapshot((
        cm_vocab(cm_erased, [base]),
        cm_member(cm_erased, one), cm_member(cm_erased, two),
        forall(member(Word, [base,one,two]), cm_agrees(cm_erased, Word)),
        spaces:metta_catalog_clause(['vocabulary-member', cm_erased, one], Ref),
        erase(Ref),
        forall(member(Word, [base,one,two]), cm_agrees(cm_erased, Word))
    )).

test(erasing_the_base_ref_invalidates_registered_members) :-
    cm_snapshot((
        cm_vocab(cm_base, [base]), cm_member(cm_base, extra),
        cm_agrees(cm_base, extra),
        spaces:metta_catalog_clause([vocabulary, cm_base|_], Ref),
        erase(Ref),
        cm_agrees(cm_base, extra), cm_agrees(cm_base, base)
    )).

test(withdrawal_and_replacement_refresh_memberships) :-
    cm_snapshot((
        cm_vocab(cm_replace, [old]), cm_member(cm_replace, extra),
        cm_agrees(cm_replace, old), cm_agrees(cm_replace, extra),
        metta_remove_atom('&metta', ['vocabulary-member', cm_replace, extra], true),
        metta_remove_atom('&metta', [vocabulary, cm_replace, old], true),
        add_sexp('&metta', [vocabulary, cm_replace, new], _),
        forall(member(Word, [old,new,extra]), cm_agrees(cm_replace, Word))
    )).

test(transaction_rollback_restores_the_previous_membership) :-
    cm_snapshot((
        cm_vocab(cm_rollback, [base]), cm_member(cm_rollback, old),
        cm_agrees(cm_rollback, old),
        \+ transaction((
            metta_remove_atom('&metta', ['vocabulary-member', cm_rollback, old], true),
            cm_member(cm_rollback, new),
            cm_agrees(cm_rollback, old), cm_agrees(cm_rollback, new),
            fail)),
        cm_agrees(cm_rollback, old), cm_agrees(cm_rollback, new)
    )).

test(transaction_erasure_of_a_committed_reference_is_visible) :-
    setup_call_cleanup(
        assertz('$metta_atoms:&metta':'&metta'(vocabulary, cm_committed, word), Ref),
        ( spaces:metta_vocabulary_value(cm_committed, word),
          cm_snapshot((
              transaction(erase(Ref)),
              assertion(\+ spaces:metta_vocabulary_value(cm_committed, word)),
              assertion(\+ spaces:metta_vocabulary_values(cm_committed, _)) )),
          assertion(spaces:metta_vocabulary_value(cm_committed, word)) ),
        ( erase(Ref), retractall(spaces:metta_vocab_cache(cm_committed, _, _)) )).

test(a_warm_point_does_not_choose_another_relational_vocabulary) :-
    cm_snapshot((
        cm_vocab(cm_first, [first]), cm_vocab(cm_second, [second]),
        retractall(spaces:metta_vocab_cache(_, _, _)),
        spaces:metta_vocabulary_value(cm_second, second),
        spaces:metta_vocabulary_values(cm_first, _),
        spaces:metta_vocabulary_value(Name, Word),
        assertion(Name-Word == cm_second-second)
    )).

test(mutation_sequences_agree_with_the_list_reader) :-
    cm_snapshot((
        cm_vocab(cm_sequence, [base]),
        forall(between(1, 100, Step),
               ( Index is (Step*37) mod 13, atom_concat(word_, Index, Word),
                 ( spaces:metta_vocabulary_value(cm_sequence, Word)
                 -> metta_remove_atom('&metta',
                                      ['vocabulary-member', cm_sequence, Word], true)
                 ;  cm_member(cm_sequence, Word) ),
                 forall(between(0, 13, I),
                        ( atom_concat(word_, I, Candidate),
                          cm_agrees(cm_sequence, Candidate) )) ))
    )).

cm_cost_fixture(Size, Words, [Base|Refs]) :-
    %The measured question is membership, so setup installs the ordinary
    %storage facts directly and leaves parsing and admission outside the count.
    assertz('$metta_atoms:&metta':'&metta'(vocabulary, cm_size), Base),
    findall(Word-Ref,
            ( between(1, Size, I), atom_concat(word_, I, Word),
              assertz('$metta_atoms:&metta':'&metta'('vocabulary-member',
                                                   cm_size, Word), Ref) ), Pairs),
    pairs_keys_values(Pairs, Words, Refs).

cm_warm_cost(Size, Cost) :-
    cm_cost_fixture(Size, Words, Refs),
    last(Words, Last),
    spaces:metta_vocabulary_value(cm_size, Last),
    statistics(inferences, Before),
    forall(between(1, 20, _), spaces:metta_vocabulary_value(cm_size, Last)),
    statistics(inferences, After), Cost is After-Before,
    maplist(erase, Refs),
    retractall(spaces:metta_vocab_cache(cm_size, _, _)).

test(a_known_members_cost_does_not_grow_with_unrelated_members) :-
    cm_snapshot((
        cm_warm_cost(8, Small), cm_warm_cost(1024, Large),
        assertion(Large =< Small+20)
    )).

cm_first_reads_cost(Size, Cost) :-
    cm_cost_fixture(Size, Words, Refs),
    statistics(inferences, Before),
    forall(member(Word, Words), spaces:metta_vocabulary_value(cm_size, Word)),
    statistics(inferences, After), Cost is After-Before,
    maplist(erase, Refs),
    retractall(spaces:metta_vocab_cache(cm_size, _, _)).

test(first_reads_of_all_members_cost_linear_work_including_the_build) :-
    cm_snapshot((
        cm_first_reads_cost(32, Small), cm_first_reads_cost(256, Large),
        assertion(Large =< 10*Small)
    )).

:- end_tests(catalog_membership).
