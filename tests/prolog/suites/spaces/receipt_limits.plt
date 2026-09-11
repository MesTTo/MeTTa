% Purpose: sweep native receipt acquisition, rollback and completion under a bound.
% Guarantees: every budget 1..600 preserves native storage atomicity, retires
%   finished receipt rows and engine reservations, and keeps a live outer owner
%   [tested: spaces_receipt_limits; commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Owns resources: fixtures release their spaces, erase their artifact clauses
%   and destroy the engines used to inspect committed reservation state.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(spaces_receipt_limits).

:- dynamic artifact/1.
:- meta_predicate boundary(+, 0), bounded(0, +, -).

boundary(plain, Goal) :- transaction(Goal).
boundary(options, Goal) :- transaction(Goal, []).
boundary(constraint, Goal) :- transaction(Goal, true, receipt_limits).
boundary(snapshot, Goal) :- snapshot(Goal).

bounded(Goal, Budget, Result) :-
    ( catch(call_with_inference_limit(Goal, Budget, Value), Ball,
            Value=raised(Ball))
    -> Result=Value
    ; Result=failed ),
    % A deferred native notification can raise the same ball after SWI's
    % limiter has returned. No other exception or failed goal is accepted.
    assertion(memberchk(Result, [inference_limit_exceeded,
                                raised(inference_limit_exceeded), !, true])).

seed :- maplist(assertz, [artifact(a),artifact(b),artifact(b),artifact(c)]).

reserve(Space) :-
    spaces:metta_with_occurrence_load(
        spaces:metta_receive_occurrences(
            Space, [[t,receipt_limits,1],[t,receipt_limits,2]], _)).

work(erase, _) :-
    spaces:metta_retract_storage(plunit_spaces_receipt_limits:artifact(_)).
work(reserve, Space) :- reserve(Space), reserve(Space), work(erase, Space).

% A caller inside an outer transaction has an older database view. Read the
% standing engine's committed pending rows from an engine with no transaction.
pending(Pending) :-
    setup_call_cleanup(
        engine_create(Rows,
            findall(Scope-Claim,
                    spaces:metta_receipt_pending(_,_,owner(Scope,_),Claim), Rows),
            Engine),
        engine_next(Engine, Pending),
        engine_destroy(Engine)).

state(state(Atoms,Owner,Erased,Markers,Reserved,Pending)) :-
    findall(Atom, artifact(Atom), Atoms),
    ( nb_current('$metta_occurrence_transaction', Frame-scope(Scope,_))
    -> Owner=Frame-Scope
    ; assertion(\+ nb_current('$metta_occurrence_transaction', _)), Owner=none ),
    findall(S-R, spaces:metta_receipt_erased(S,R), Erased),
    findall(S-L, spaces:metta_receipt_marker(S,L), Markers),
    findall(S, spaces:metta_receipt_reserved(S), Reserved),
    pending(Pending).

atomic_atoms([]).
atomic_atoms([a,b,b,c]).
clean(state(Atoms,none,[],[],[],[])) :- atomic_atoms(Atoms).

require_clean(Context) :-
    state(State),
    ( clean(State) -> true ; throw(receipt_limit_residue(Context, State)) ).

second_entry(Mode, Work, Space) :-
    retractall(artifact(_)), seed,
    boundary(Mode, work(Work,Space)),
    require_clean(second_entry(Mode,Work)),
    retractall(artifact(_)).

positive_control(Space) :-
    transaction((reserve(Space), pending(Pending), assertion(Pending \== []))),
    require_clean(positive_control).

test(every_budget_retires_the_finished_scope,
     [forall((member(Mode,[plain,options,constraint,snapshot]),
              member(Work,[erase,reserve]))),
      setup('new-space'(Space)),
      cleanup((retractall(artifact(_)), metta_release_space(Space)))]) :-
    positive_control(Space),
    forall(between(1,600,Budget),
           ( seed,
             bounded(boundary(Mode,work(Work,Space)), Budget, Result),
             require_clean(bounded(Mode,Work,Budget,Result)),
             second_entry(Mode,Work,Space) )).

live_claims(Pending) :-
    forall(member(Scope-Claim, Pending),
           clause(spaces:metta_receipt_marker(Scope,_), true, Claim)).

outer_receipt(existing, Space, Owner) :-
    reserve(Space),
    nb_current('$metta_occurrence_transaction', Frame-scope(Scope,_)),
    Owner=Frame-Scope.
outer_receipt(fresh, _, none).

live_owner(existing, Expected, Owner) :- Owner == Expected.
live_owner(fresh, _, none).
live_owner(fresh, _, Frame-_) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    spaces:metta_receipt_transaction_predicate(Predicate).

test(every_budget_preserves_the_live_outer_scope,
     [forall((member(Mode,[plain,options,constraint,snapshot]),
              member(First,[existing,fresh]))),
      setup('new-space'(Space)),
      cleanup((retractall(artifact(_)), metta_release_space(Space)))]) :-
    positive_control(Space),
    forall(between(1,600,Budget),
           ( seed,
             transaction((
                 outer_receipt(First,Space,Expected),
                 bounded(boundary(Mode,work(reserve,Space)), Budget, Result),
                 state(State), State=state(Atoms,Owner,_,_,_,Pending),
                 ( atomic_atoms(Atoms), live_owner(First,Expected,Owner),
                   live_claims(Pending)
                 -> true
                 ; throw(receipt_limit_outer_residue(Mode,First,Budget,Result,
                                                     Expected,State)) ) )),
             require_clean(outer_completion(Mode,First,Budget)),
             second_entry(Mode,reserve,Space) )).

test(the_public_bound_keeps_its_control_envelope,
     [forall((member(Mode,[plain,options,constraint,snapshot]),
              member(Work,[erase,reserve]))),
      setup('new-space'(Space)),
      cleanup((retractall(artifact(_)), metta_release_space(Space)))]) :-
    positive_control(Space),
    forall(between(1,600,Budget),
           ( seed,
             metta_host_inference_budget(boundary(Mode,work(Work,Space)),
                                         Budget, Bounded),
             ( catch(call(Bounded), Ball, true) -> true
             ; throw(receipt_public_bound_failed(Mode,Work,Budget)) ),
             assertion((var(Ball) ;
                        Ball=error(metta_control_signal(inference_limit,Budget),
                                   context(metta,inference_limit)))),
             require_clean(public_bound(Mode,Work,Budget,Ball)),
             second_entry(Mode,Work,Space) )).

test(a_bound_caught_inside_the_transaction_keeps_each_erasure_journaled,
     [cleanup(retractall(artifact(_)))]) :-
    forall(between(1,600,Budget),
           ( seed, clause(artifact(a),true,Ref),
             transaction((
                 bounded(spaces:metta_erase_storage_ref(Ref), Budget, Result),
                 ( clause(artifact(a),true,Ref) -> true
                 ; nb_current('$metta_occurrence_transaction', _-scope(Scope,_)),
                   ( spaces:metta_receipt_erased(Scope,Ref) -> true
                   ; throw(receipt_limit_missing_erasure(Budget,Result,Ref)) ) ) )),
             state(state(Atoms,Owner,Erased,Markers,Reserved,Pending)),
             assertion(memberchk(Atoms, [[a,b,b,c],[b,b,c]])),
             assertion(Owner-Erased-Markers-Reserved-Pending == none-[]-[]-[]-[]),
             retractall(artifact(_)) )).

:- end_tests(spaces_receipt_limits).
