% Purpose: verify that a space release inside a transaction finishes only with its outcome.
% Guarantees: rows, storage cache and ownership return after an abort, the
%   hooks and the host completion run once after a commit, and the completion
%   reports retired or restored [tested: space_retirement; commit=WORKTREE].
% Owns resources: every test releases its generated spaces and erases its notes.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(space_retirement).

retire_setup :-
    metta_host_set_silent(true),
    nb_setval(space_retirement_notes, []),
    nb_setval(space_retirement_spaces, []).
retire_cleanup :-
    nb_getval(space_retirement_spaces, Spaces),
    forall(member(Space, Spaces),
           ( spaces:native_storage_module_cache(Space, _) -> metta_release_space(Space) ; true )),
    nb_delete(space_retirement_spaces),
    nb_delete(space_retirement_notes),
    metta_host_set_silent(false).

retire_space(Space) :-
    gensym('&space-retirement-', Space), space_module(Space, _),
    metta_add_atom(Space, [retained, 7], _),
    nb_getval(space_retirement_spaces, Before),
    nb_setval(space_retirement_spaces, [Space|Before]).

% The host completion the engine calls with the outcome.
retire_note(Outcome) :-
    nb_getval(space_retirement_notes, Before),
    nb_setval(space_retirement_notes, [Outcome|Before]).
retire_notes(Notes) :-
    nb_getval(space_retirement_notes, Reversed), reverse(Reversed, Notes).

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

:- end_tests(space_retirement).
