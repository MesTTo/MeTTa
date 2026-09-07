% Purpose: PlUnit coverage for the branch-local evaluation fuel, and for the
%   two SWI global-variable behaviours its single-global design depends on.
% Assumes: engine/metta.pl is loaded, so metta_run_with_fuel/3,
%   metta_open_fuel_scope/0, metta_close_fuel_scope/0 and
%   metta_fuel_step_goal/3 are reachable; `$metta_fuel_remaining` is the one
%   global they share. The charge is BUILT by metta_fuel_step_goal/3 and
%   written into each compiled clause, so these tests call the built goal,
%   which is the thing the engine actually runs.
% Guarantees:
%   - a step charges inside a scope and is inert outside one, an exhausted
%     branch records its culprit and fails, and the limit is read from
%     max-stack-depth on the first step rather than at scope open [tested:
%     fuel:a_step_charges_inside_a_scope_and_is_inert_outside_one;
%     commit=657ae9672c07b628f8a20c7fe39aa43e58b0014f].
%   - nb_delete/1 and an `off` sentinel both survive backtracking past a
%     trailed b_setval/2 write [tested:
%     fuel:a_deleted_global_is_not_resurrected_by_backtracking;
%     commit=657ae9672c07b628f8a20c7fe39aa43e58b0014f].
%   - a scope abandoned by an asynchronous limit closes itself, and the
%     runnable after it still replays its own exhausted branch [tested:
%     fuel:an_interrupted_scope_does_not_stay_open,
%     fuel:a_runnable_after_an_abandoned_scope_still_replays_its_overflow;
%     commit=WORKTREE].
% Fails when: read as coverage of max-stack-depth's user-facing law. That is
%   test_a_stack_depth_pragma_bounds_evaluation_instead_of_overflowing and the
%   arbiter's own boundary witnesses; this file covers the mechanism under it.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(fuel).

% ---------------------------------------------------------------- the mechanism

test(a_step_charges_inside_a_scope_and_is_inert_outside_one) :-
    metta_open_fuel_scope,
    nb_setval('$metta_fuel_remaining', 1000),
    charge(probe, 7),
    b_getval('$metta_fuel_remaining', Inside),
    metta_close_fuel_scope,
    b_getval('$metta_fuel_remaining', Closed),
    charge(probe, 7),
    b_getval('$metta_fuel_remaining', Outside),
    assertion(Inside == 993),
    assertion(Closed == off),
    assertion(Outside == off).

test(a_step_spends_from_the_balance_it_inherited_on_a_sibling_branch) :-
    metta_open_fuel_scope,
    nb_setval('$metta_fuel_remaining', 1000),
    %A branch that spends and then fails leaves the balance it started with,
    %which is the whole reason the write is backtrackable.
    (   charge(first, 100), fail
    ;   true
    ),
    b_getval('$metta_fuel_remaining', Restored),
    metta_close_fuel_scope,
    assertion(Restored == 1000).

test(an_exhausted_branch_records_its_culprit_and_fails) :-
    metta_open_fuel_scope,
    nb_setval('$metta_fuel_remaining', 10),
    (   charge(the_culprit, 9)
    ->  Charged = true
    ;   Charged = false
    ),
    nb_getval('$metta_fuel_scope', Recorded),
    metta_close_fuel_scope,
    assertion(Charged == false),
    assertion(Recorded == [the_culprit]).

%WITHOUT a max-stack-depth the budget is off, and the first step LATCHES that
%so no later reduction in the runnable re-reads the pragma table. The engine
%used to default to an earlier reference runner's 100000 here, which capped
%every program
%at 25,000 charged reductions and stopped six upstream examples that upstream
%completes
%[source: PeTTa@ae66fa8 src/metta.pl, which has no budget; measured 2026-08-30,
%`!(fib 22)` answered `(Error 4 StackOverflow)` under the old default and
%answers 17711 now].
%The balance CANNOT be the scope marker once the budget is opt-in, because an
%absent pragma latches it to `off` mid-scope and `off` is also what no scope at
%all reads. A nested run then opened its own scope, and its close deleted the
%error list the outer replay clause reads.
test(a_nested_run_inside_an_unbounded_scope_keeps_the_outer_error_list) :-
    setup_call_cleanup(
        'pragma!'('max-stack-depth', none, _),
        (   metta_open_fuel_scope,
            charge(probe, 1),
            b_getval('$metta_fuel_remaining', Latched),
            once(metta_run_with_fuel(inner, _, true)),
            (   catch(nb_getval('$metta_fuel_scope', E), Raised,
                      (E = raised(Raised), true))
            ->  true
            ;   E = failed
            ),
            metta_close_fuel_scope
        ),
        true),
    assertion(Latched == off),
    assertion(E == []).

test(an_absent_pragma_does_not_bound_evaluation) :-
    setup_call_cleanup(
        'pragma!'('max-stack-depth', none, _),
        (   metta_open_fuel_scope,
            b_getval('$metta_fuel_remaining', AtOpen),
            charge(probe, 1),
            b_getval('$metta_fuel_remaining', AfterFirst),
            charge(probe, 1),
            b_getval('$metta_fuel_remaining', AfterSecond),
            metta_close_fuel_scope
        ),
        true),
    %The scope still opens lazily, so a with-pragma! inside it is still read.
    assertion(AtOpen == unstarted),
    %...but an absent pragma resolves to `off` and stays there, which is the
    %one-comparison path every later step then takes.
    assertion(AfterFirst == off),
    assertion(AfterSecond == off).

test(the_limit_is_read_on_the_first_step_rather_than_at_scope_open) :-
    setup_call_cleanup(
        true,
        (   metta_open_fuel_scope,
            b_getval('$metta_fuel_remaining', AtOpen),
            'pragma!'('max-stack-depth', 500, _),
            charge(probe, 1),
            b_getval('$metta_fuel_remaining', AfterStep),
            metta_close_fuel_scope
        ),
        'pragma!'('max-stack-depth', none, _)),
    %`unstarted` at open is what lets a with-pragma! INSIDE the runnable set the
    %bound the runnable is then measured against.
    assertion(AtOpen == unstarted),
    assertion(AfterStep == 499).

%The scope belongs to the RUNNABLE, not to one answer: it stays open while the
%form can still produce answers, which is what lets the recorded overflow
%branches be replayed after the ordinary ones, and it closes when the caller
%stops asking. So an inner run inside it spends the outer balance, and only the
%cut puts the marker back to `off`.
test(a_nested_run_reuses_the_scope_the_outer_one_opened) :-
    once(metta_run_with_fuel(outer, Answer,
                             ( b_getval('$metta_fuel_remaining', Open),
                               nb_setval('$metta_plt_seen', Open),
                               metta_run_with_fuel(inner, _, true) ))),
    nb_getval('$metta_plt_seen', Seen),
    nb_delete('$metta_plt_seen'),
    b_getval('$metta_fuel_remaining', Afterwards),
    assertion(Answer == outer),
    assertion(Seen == unstarted),
    assertion(Afterwards == off).

%AN ABANDONED SCOPE CLOSES ITSELF. setup_call_cleanup/3 is
%`sig_atomic(Setup), '$call_cleanup'` [source: SWI-Prolog 10.1.13
%boot/init.pl, setup_call_cleanup/3], so an asynchronous limit delivered in
%the call port between those two goals leaves Setup's writes standing with no
%cleanup registered. A non-backtrackable scope marker then stayed open for the
%life of the process and every later runnable took the reentrant branch, which
%answers ordinary solutions and never replays a branch that ran out of fuel.
%The marker is trailed instead, so unwinding puts it back with no cleanup
%involved, and this sweep is what says so: every inference budget from 1 to
%6000 over a runnable that spends 300 steps, and the marker read afterwards.
%Against the nb_setval/2 marker this replaces it finds budgets that leak.
test(an_interrupted_scope_does_not_stay_open) :-
    findall(Limit-Marker,
            ( between(1, 6000, Limit),
              plt_bounded_fuel_run(Limit, Marker),
              Marker \== closed ),
            Leaks),
    assertion(Leaks == []).

%And the consequence the leak produced, in one goal: a runnable that follows
%an abandoned scope still replays its own exhausted branch as
%(Error <culprit> StackOverflow). Under a leaked-open marker the replay clause
%is unreachable and the same runnable answers nothing.
%The balance unwinds with the scope. A balance left at `unstarted` outside any
%scope makes the next charge read the pragma and spend, and a branch that ran
%out would then record its culprit into the atom `closed`.
test(an_interrupted_scope_leaves_the_balance_off) :-
    findall(Limit-Balance,
            ( between(1, 6000, Limit),
              plt_bounded_fuel_balance(Limit, Balance),
              Balance \== off ),
            Leaks),
    assertion(Leaks == []).

test(a_runnable_after_an_abandoned_scope_still_replays_its_overflow) :-
    setup_call_cleanup(
        'pragma!'('max-stack-depth', 20, _),
        ( plt_abandon_a_scope,
          findall(A,
                  metta_run_with_fuel(ordinary, A, plt_charge_until_exhausted),
                  Answers) ),
        'pragma!'('max-stack-depth', none, _)),
    assertion(Answers == [['Error', plt_culprit, 'StackOverflow']]).

% ------------------------------------------------- the SWI behaviour underneath

% The balance doubles as the scope marker, so a value restored by backtracking
% into an already-closed scope would silently reopen one. Neither closing form
% does that: the manual says a b_setval/2 that CREATED a variable has its
% creation undone on backtracking, and nothing says a later delete is undone
% [source: SWI-Prolog 10.1 Reference Manual section 4.33, b_setval/2].

test(a_deleted_global_is_not_resurrected_by_backtracking) :-
    (   plt_fuel_scope(nb_delete('$metta_plt_probe')),
        fail
    ;   true
    ),
    assertion(\+ nb_current('$metta_plt_probe', _)).

test(an_off_sentinel_is_not_restored_over_by_backtracking) :-
    (   plt_fuel_scope(nb_setval('$metta_plt_probe', off)),
        fail
    ;   true
    ),
    nb_getval('$metta_plt_probe', Value),
    nb_delete('$metta_plt_probe'),
    assertion(Value == off).

:- end_tests(fuel).

%A scope whose body writes the backtrackable balance three times and then
%closes, with the caller free to backtrack through every one of those writes
%after the close has run.
%The charge exactly as a compiled clause carries it.
charge(Culprit, Cost) :-
    metta_fuel_step_goal(Culprit, Cost, Goal),
    call(Goal).

plt_fuel_scope(Close) :-
    setup_call_cleanup(nb_setval('$metta_plt_probe', 100),
                       ( member(N, [1, 2, 3]),
                         b_setval('$metta_plt_probe', N) ),
                       Close).

plt_spin(0) :- !.
plt_spin(N) :- M is N - 1, plt_spin(M).

%One bounded runnable, and the scope marker it leaves behind. once/1 because a
%scope stays open while its runnable can still answer, which is the contract
%tested above; the cut is what ends the runnable.
plt_bounded_fuel_run(Limit, Marker) :-
    nb_setval('$metta_fuel_scope', closed),
    catch(call_with_inference_limit(
              once(metta_run_with_fuel(value, _, plt_spin(300))),
              Limit, _),
          _, true),
    b_getval('$metta_fuel_scope', Marker).

plt_bounded_fuel_balance(Limit, Balance) :-
    nb_setval('$metta_fuel_scope', closed),
    nb_setval('$metta_fuel_remaining', off),
    catch(call_with_inference_limit(
              once(metta_run_with_fuel(value, _, plt_spin(300))),
              Limit, _),
          _, true),
    b_getval('$metta_fuel_remaining', Balance).

%A scope whose cleanup never runs, which is what the interruption produces.
%The marker is written the way metta_open_fuel_scope/0 writes it and the
%enclosing goal then succeeds, so nothing unwinds it here either.
plt_abandon_a_scope :-
    catch(call_with_inference_limit(
              once(metta_run_with_fuel(value, _, plt_spin(300))),
              1, _),
          _, true).

%A branch that spends the whole budget and fails, which is the shape a
%recursive equation's compiled charge produces.
plt_charge_until_exhausted :-
    metta_fuel_step_goal(plt_culprit, 30, Charge),
    call(Charge),
    fail.
