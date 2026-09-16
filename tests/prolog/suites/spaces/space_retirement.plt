% Purpose: verify that a space release inside a transaction finishes only with its outcome.
% Guarantees: rows, storage cache and ownership return after an abort, the
%   hooks and the host completion run once after a commit, and the completion
%   reports retired or restored [tested: space_retirement; commit=f9ef614a03bce1a1878d9b43fb7618df57ccfa21].
% Guarantees: a write and a retirement overlapping through
%   tests/prolog/overlap_transactions.pl are decided at the outer commit in
%   both orders, for removals, equal-valued replacements, definitions,
%   children, empty allocations, nested and snapshot entries, with disjoint
%   and multivalued writes as the positive controls [tested: space_retirement;
%   commit=23dee6dc5b745a57ade43bd5fd2d317116634f6f].
% Guarantees: the release's physical work follows the outcome: an aborted
%   release keeps the compiled equations and a receiver's imported binding
%   callable, a committed one abolishes the generated predicates and retires
%   the receiver's binding at the completion [tested: space_retirement;
%   commit=WORKTREE].
% Owns resources: every test releases its generated spaces and erases its notes.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(space_retirement).
:- use_module('../../overlap_transactions').

retire_setup :-
    metta_host_set_silent(true),
    forall(recorded(space_retirement_notes, _, Ref), erase(Ref)),
    nb_setval(space_retirement_spaces, []).
retire_cleanup :-
    nb_getval(space_retirement_spaces, Spaces),
    forall(member(Space, Spaces),
           ( spaces:native_storage_module_cache(Space, _) -> metta_release_space(Space) ; true )),
    nb_delete(space_retirement_spaces),
    forall(recorded(space_retirement_notes, _, Ref), erase(Ref)),
    metta_host_set_silent(false).

retire_space(Space) :-
    gensym('&space-retirement-', Space), space_module(Space, _),
    metta_add_atom(Space, [retained, 7], _),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Space|Before]).

% The host completion the engine calls with the outcome, recorded rather
% than held in a global variable so a completion in a worker thread is read
% by the test thread.
retire_note(Outcome) :-
    recordz(space_retirement_notes, Outcome).
retire_notes(Notes) :-
    findall(Outcome, recorded(space_retirement_notes, Outcome), Notes).

retired(Space) :-
    \+ spaces:native_storage_module_cache(Space, _),
    \+ spaces:metta_space_retired(Space, _).
restored(Space) :-
    spaces:native_storage_module_cache(Space, _),
    findall(Row, get_native_atom(Space, Row), Rows),
    Rows == [[retained, 7]],
    \+ spaces:metta_space_retired(Space, _).

test(a_release_outside_a_transaction_completes_before_returning,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    metta_release_space(Space, plunit_space_retirement:retire_note),
    retire_notes(Notes), assertion(Notes == [retired]),
    assertion(retired(Space)).

test(a_committed_release_completes_after_the_outcome,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    transaction(( metta_release_space(Space, plunit_space_retirement:retire_note),
                  retire_notes(Inside), assertion(Inside == []),
                  assertion(spaces:metta_space_retired(Space, _)),
                  assertion(\+ spaces:native_storage_module_cache(Space, _)) )),
    retire_notes(Notes), assertion(Notes == [retired]),
    assertion(retired(Space)).

test(an_aborted_release_restores_the_space_and_reports_restored,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    \+ transaction(( metta_release_space(Space, plunit_space_retirement:retire_note), fail )),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Space)).

test(an_exception_inside_the_transaction_restores_the_space,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    catch(transaction(( metta_release_space(Space, plunit_space_retirement:retire_note),
                        throw(space_retirement_abort) )),
          space_retirement_abort, true),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Space)).

test(a_snapshot_release_reports_restored,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    snapshot(metta_release_space(Space, plunit_space_retirement:retire_note)),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Space)).

test(a_nested_commit_inside_an_aborted_outer_transaction_is_restored,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    \+ transaction(( transaction(metta_release_space(Space, plunit_space_retirement:retire_note)),
                     retire_notes(Inside), assertion(Inside == []),
                     fail )),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Space)).

test(a_nested_abort_inside_a_committed_outer_transaction_is_restored,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    transaction(( \+ transaction(( metta_release_space(Space, plunit_space_retirement:retire_note),
                                   fail )),
                  assertion(restored(Space)) )),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Space)).

test(a_second_release_in_the_same_transaction_is_pending_and_a_host_is_refused,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    transaction(( metta_release_space(Space),
                  metta_release_space(Space),
                  catch(metta_release_space(Space, plunit_space_retirement:retire_note),
                        error(permission_error(release, pending_retirement, Refused), _), true),
                  assertion(Refused == Space) )),
    retire_notes(Notes), assertion(Notes == []),
    assertion(retired(Space)).

test(owned_children_follow_their_parent_through_abort_and_commit,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Parent),
    % An equation home is declared before the child's first use.
    gensym('&space-retirement-', Child),
    metta_declare_space_equation_home(Child, Parent),
    metta_add_atom(Child, [retained, 7], _),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Child|Before]),
    \+ transaction(( metta_release_space(Parent, plunit_space_retirement:retire_note), fail )),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(restored(Parent)), assertion(restored(Child)),
    assertion(spaces:space_equation_home(Child, Parent)),
    transaction(metta_release_space(Parent, plunit_space_retirement:retire_note)),
    retire_notes(After), assertion(After == [restored, retired]),
    assertion(retired(Parent)), assertion(retired(Child)),
    assertion(\+ spaces:space_equation_home(Child, _)).

% Commit validation. Two transactions overlap through
% tests/prolog/overlap_transactions.pl; the caller names who commits first,
% and the loser is refused at its own commit.
conflict(threw(error(metta_retirement_conflict(Party, Problem), _)), Party, Problem).

retire_empty_space(Space) :-
    gensym('&space-retirement-', Space), space_module(Space, _),
    ensure_native_storage_module(Space, _),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Space|Before]).

rows(Space, Rows) :-
    findall(Row, get_native_atom(Space, Row), Unsorted), msort(Unsorted, Rows).

test(a_write_loses_to_a_retirement_that_committed_first,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_add_atom(Space, [written, 1], _),
            metta_release_space(Space, plunit_space_retirement:retire_note),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(conflict(Writer, writer(Space), retired)),
    retire_notes(Notes), assertion(Notes == [retired]),
    assertion(retired(Space)).

test(a_retirement_loses_to_a_write_that_committed_first,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_add_atom(Space, [written, 1], _),
            metta_release_space(Space, plunit_space_retirement:retire_note),
            first, [first-Writer, second-Retirer]),
    assertion(Writer == committed),
    assertion(conflict(Retirer, retirement(Space), occurrences(1))),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(spaces:native_storage_module_cache(Space, _)),
    assertion(\+ spaces:metta_space_retired(Space, _)),
    rows(Space, Rows), assertion(Rows == [[retained, 7], [written, 1]]).

test(a_removal_loses_to_a_retirement_that_committed_first,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_remove_atom(Space, [retained, 7], _),
            metta_release_space(Space),
            second, [first-Remover, second-Retirer]),
    assertion(Retirer == committed),
    assertion(conflict(Remover, writer(Space), retired)),
    assertion(retired(Space)).

test(an_equal_valued_replacement_committed_first_survives_the_retirement,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(( metta_remove_atom(Space, [retained, 7], _),
              metta_add_atom(Space, [retained, 7], _) ),
            metta_release_space(Space),
            first, [first-Writer, second-Retirer]),
    assertion(Writer == committed),
    assertion(conflict(Retirer, retirement(Space), occurrences(1))),
    rows(Space, Rows), assertion(Rows == [[retained, 7]]).

test(an_equal_valued_replacement_loses_to_a_retirement_that_committed_first,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(( metta_remove_atom(Space, [retained, 7], _),
              metta_add_atom(Space, [retained, 7], _) ),
            metta_release_space(Space),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(conflict(Writer, writer(Space), retired)),
    assertion(retired(Space)).

test(a_definition_published_after_the_withdrawal_refuses_the_retirement,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_add_atom(Space, [=, [defined], 1], _),
            metta_release_space(Space),
            first, [first-Definer, second-Retirer]),
    assertion(Definer == committed),
    assertion(conflict(Retirer, retirement(Space), occurrences(1))),
    assertion(spaces:native_storage_module_cache(Space, _)).

test(a_child_reading_the_equations_declared_after_the_withdrawal_refuses_the_retirement,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Parent),
    gensym('&space-retirement-', Child),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Child|Before]),
    overlap(( metta_declare_space_equation_home(Child, Parent),
              metta_add_atom(Child, [kept, 1], _) ),
            metta_release_space(Parent),
            first, [first-Declarer, second-Retirer]),
    assertion(Declarer == committed),
    assertion(conflict(Retirer, retirement(Parent), children(1))),
    assertion(spaces:space_equation_home(Child, Parent)),
    assertion(spaces:native_storage_module_cache(Parent, _)).

test(an_heir_declared_after_the_withdrawal_refuses_the_retirement,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Parent),
    gensym('&space-retirement-', Heir),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Heir|Before]),
    overlap(( metta_declare_space_parent(Heir, Parent),
              metta_add_atom(Heir, [kept, 1], _) ),
            metta_release_space(Parent),
            first, [first-Declarer, second-Retirer]),
    assertion(Declarer == committed),
    assertion(conflict(Retirer, retirement(Parent), children(1))),
    assertion(spaces:space_parent(Heir, Parent)).

test(an_empty_allocation_written_after_the_withdrawal_refuses_the_retirement,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_empty_space(Space),
    overlap(metta_add_atom(Space, [first, 1], _),
            metta_release_space(Space),
            first, [first-Writer, second-Retirer]),
    assertion(Writer == committed),
    assertion(conflict(Retirer, retirement(Space), occurrences(1))),
    rows(Space, Rows), assertion(Rows == [[first, 1]]).

test(a_first_write_loses_to_the_retirement_of_its_empty_allocation,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_empty_space(Space),
    overlap(metta_add_atom(Space, [first, 1], _),
            metta_release_space(Space),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(conflict(Writer, writer(Space), retired)),
    assertion(retired(Space)).

test(a_nested_commit_of_the_write_is_validated_at_the_outer_boundary,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_transaction(metta_add_atom(Space, [written, 1], _)),
            metta_release_space(Space),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(conflict(Writer, writer(Space), retired)),
    assertion(retired(Space)).

test(an_inner_abort_leaves_the_outer_commit_nothing_to_validate,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(\+ metta_transaction(( metta_add_atom(Space, [written, 1], _), fail )),
            metta_release_space(Space),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(Writer == committed),
    assertion(retired(Space)).

test(a_snapshot_write_leaves_the_outer_commit_nothing_to_validate,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(snapshot(metta_add_atom(Space, [written, 1], _)),
            metta_release_space(Space),
            second, [first-Writer, second-Retirer]),
    assertion(Retirer == committed),
    assertion(Writer == committed),
    assertion(retired(Space)).

test(disjoint_writes_commit_in_either_order,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(A), retire_space(B),
    overlap(metta_add_atom(A, [written, 1], _),
            metta_add_atom(B, [written, 2], _),
            second, [first-First, second-Second]),
    assertion(First == committed), assertion(Second == committed),
    rows(A, RowsA), assertion(RowsA == [[retained, 7], [written, 1]]),
    rows(B, RowsB), assertion(RowsB == [[retained, 7], [written, 2]]).

test(multivalued_writes_into_one_space_commit_in_either_order,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    overlap(metta_add_atom(Space, [written, 1], _),
            metta_add_atom(Space, [written, 2], _),
            second, [first-First, second-Second]),
    assertion(First == committed), assertion(Second == committed),
    rows(Space, Rows), assertion(Rows == [[retained, 7], [written, 1], [written, 2]]).

% The physical half of the clear follows the outcome: a rolled-back release
% keeps the compiled program behind the restored rows callable, a committed
% one abolishes the module's generated predicates at its completion.
test(an_aborted_release_keeps_the_compiled_equations_callable,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    metta_add_atom(Space, [=, [answer], 42], _),
    space_module(Space, Module),
    assertion(eval_metta_in_module(Module, [answer], 42)),
    \+ transaction(( metta_release_space(Space, plunit_space_retirement:retire_note), fail )),
    retire_notes(Notes), assertion(Notes == [restored]),
    assertion(spaces:native_storage_module_cache(Space, _)),
    assertion(eval_metta_in_module(Module, [answer], 42)).

test(a_committed_release_abolishes_the_generated_predicates_at_completion,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Space),
    metta_add_atom(Space, [=, [answer], 42], _),
    space_module(Space, Module),
    transaction(( metta_release_space(Space, plunit_space_retirement:retire_note),
                  assertion(( current_predicate(Module:Name/_), Name \== '$metta_native_storage' )) )),
    retire_notes(Notes), assertion(Notes == [retired]),
    assertion(retired(Space)),
    assertion(\+ ( current_predicate(Module:Name/Arity), functor(Head, Name, Arity),
                    \+ predicate_property(Module:Head, imported_from(_)) )).

% A reference binding is physical: a publication imports or wraps a predicate
% in the receiver's module, which no journal restores. The release publishes
% nothing before the outcome: an aborted release leaves the receiver's binding
% callable, a committed one retires it at the completion.
test(an_aborted_release_keeps_the_receivers_imported_binding_callable,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Home), retire_space(Receiver),
    metta_add_atom(Home, [=, ['imported-answer'], 5], _),
    metta_add_atom(Receiver, [from, Home], _),
    space_module(Receiver, Module),
    assertion(eval_metta_in_module(Module, ['imported-answer'], 5)),
    \+ transaction(( metta_release_space(Home, plunit_space_retirement:retire_note), fail )),
    assertion(eval_metta_in_module(Module, ['imported-answer'], 5)),
    \+ transaction(( metta_release_space(Receiver, plunit_space_retirement:retire_note), fail )),
    retire_notes(Notes), assertion(Notes == [restored, restored]),
    assertion(eval_metta_in_module(Module, ['imported-answer'], 5)).

test(a_committed_release_retires_the_receivers_binding_at_completion,
     [setup(retire_setup), cleanup(retire_cleanup)]) :-
    retire_space(Home), retire_space(Receiver),
    metta_add_atom(Home, [=, ['imported-answer'], 5], _),
    metta_add_atom(Receiver, [from, Home], _),
    space_module(Receiver, Module),
    assertion(eval_metta_in_module(Module, ['imported-answer'], 5)),
    transaction(metta_release_space(Home, plunit_space_retirement:retire_note)),
    retire_notes(Notes), assertion(Notes == [retired]),
    assertion(\+ eval_metta_in_module(Module, ['imported-answer'], 5)).

:- end_tests(space_retirement).
