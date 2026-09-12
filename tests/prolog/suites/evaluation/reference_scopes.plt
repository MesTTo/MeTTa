% Purpose: verify trailed scopes used by reference publication and its locks.
% Guarantees: answer and enumeration scopes preserve linked context and retire
%   after success, failure, cut, exception and every native inference limit
%   [tested: reference_scopes; commit=WORKTREE].
% Owns resources: each fixture restores its context; worker tests join their
%   native thread and engine tests destroy their suspended engine.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- begin_tests(reference_scopes).

test(answer_scopes_restore_the_caller_and_reinstate_on_redo) :-
    metta_with_trailed('$reference_scope_test', outer,
        ( findall(N-In-Out,
              ( metta_with_trailed('$reference_scope_test', inner,
                    (member(N,[1,2]), nb_current('$reference_scope_test',In))),
                nb_current('$reference_scope_test',Out) ), Rows),
          assertion(Rows == [1-inner-outer,2-inner-outer]),
          once(metta_with_trailed('$reference_scope_test', inner, member(_,[a,b]))),
          assertion(nb_current('$reference_scope_test',outer)) )).

test(enumeration_scopes_hold_context_between_answers) :-
    metta_with_trailed('$reference_scope_test', outer,
        ( findall(In-Between,
              ( metta_with_trailed_enumeration('$reference_scope_test', inner,
                    (member(N,[1,2]), nb_current('$reference_scope_test',In))),
                nb_current('$reference_scope_test',Between), N > 0 ), Rows),
          assertion(Rows == [inner-inner,inner-outer]),
          assertion(nb_current('$reference_scope_test',outer)) )).

test(unwinding_preserves_the_same_outer_object,
     [forall(member(Scope,[metta_with_trailed,metta_with_trailed_enumeration]))]) :-
    Outer = cell(before),
    metta_with_trailed('$reference_scope_test', Outer,
        ( \+ call(Scope, '$reference_scope_test', inner, fail),
          catch(call(Scope, '$reference_scope_test', inner, throw(witness)), witness, true),
          once(call(Scope, '$reference_scope_test', inner, member(_,[a,b]))),
          call(Scope, '$reference_scope_test', cell(private),
              (nb_current('$reference_scope_test', Inner), nb_setarg(1, Inner, changed))),
          nb_current('$reference_scope_test', After),
          assertion(same_term(Outer,After)), assertion(arg(1,After,before)) )).

test(a_fresh_thread_needs_no_context_initialization) :-
    thread_create(( metta_with_trailed('$reference_scope_worker', true,
                                      nb_current('$reference_scope_worker', true)),
                    nb_current('$reference_scope_worker', []) ), Worker, []),
    thread_join(Worker, Status), assertion(Status == true).

test(a_suspended_engine_retains_its_own_context) :-
    metta_with_trailed('$reference_scope_test', outer,
        setup_call_cleanup(
            engine_create(Result,
                metta_with_trailed_enumeration('$reference_scope_test', inner,
                    ( engine_yield(ready), nb_current('$reference_scope_test', Result) )),
                Engine),
            ( engine_next(Engine, ready),
              assertion(nb_current('$reference_scope_test', outer)),
              engine_next(Engine, Result), assertion(Result == inner),
              assertion(nb_current('$reference_scope_test', outer)) ),
            engine_destroy(Engine))).

guard(support_graph:with_support_repairs_deferred, '$metta_support_repairs_deferred', true).
guard(support_graph:support_atomic, '$metta_support_graph_locked', true).
guard(type_rules:with_typing_policy_stable, '$metta_typing_policy_snapshot', snapshot(stable)).

test(every_inference_cut_restores_each_production_guard,
     [forall(guard(Scope, Key, Value))]) :-
    Goal = call(Scope, nb_current(Key, Value)),
    call(Goal),
    statistics(inferences, Before), call(Goal), statistics(inferences, After),
    Last is After-Before+1,
    forall(between(1, Last, Budget),
           ( catch(ignore(call_with_inference_limit(Goal, Budget, _)),
                   inference_limit_exceeded, true),
             assertion(\+ nb_current(Key, Value)) )).

test(a_malformed_reader_declaration_refuses_at_load) :-
    catch(expand_term((:- seam:context_reader(planted_reader, '$reference_scope_bad', ring)), _),
          error(domain_error(context_reader_shape, ring), _), Refused = shape),
    assertion(Refused == shape),
    catch(expand_term((:- seam:context_reader(planted_reader, "not an atom", value(true))), _),
          error(type_error(atom, _), _), Typed = key),
    assertion(Typed == key),
    assertion(\+ current_predicate(planted_reader/0)).

test(both_scope_doors_are_published_host_services,
     [forall(member(Name,[metta_with_trailed,metta_with_trailed_enumeration]))]) :-
    functor(Head, Name, 3),
    assertion(predicate_property(metta_engine:Head, exported)),
    assertion(seam:kind(Name/3, host_service)).

:- end_tests(reference_scopes).
