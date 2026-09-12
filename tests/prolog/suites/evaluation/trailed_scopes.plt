% Purpose: exercise temporary contexts at every inference-limit call port.
% Assumes: each sweep runs in a fresh SWI engine, so a host findall-bag leak
%   cannot corrupt the test runner's enclosing collectors.
% Guarantees: the actual scope doors restore their prior state and permit a
%   clean second entry after interruption; ordinary answers, redo, cut and
%   nested mutable contexts preserve their dynamic extent
%   [tested: sh engine/test.sh suites/evaluation/trailed_scopes.plt; commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Guarantees: every declared context reader compiles to its nb_current/2 read,
%   a call site carries that read in place of a call, and an inactive or
%   one-element read costs the inferences of the dynamic fact it replaced
%   [tested: every_declared_reader_is_compiled_to_its_read,
%   a_call_site_carries_the_read_rather_than_a_call,
%   an_inactive_reader_costs_what_the_asserted_guard_cost; commit=WORKTREE].
% Owns resources: every sweep engine is destroyed after its result is read;
%   temporary clauses are owned by the production doors under test.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../engine/metta.pl', [metta_with_trailed/3]).

:- multifile seam:foreign_space/1, seam:foreign_capability/2,
             seam:foreign_token/3, seam:foreign_remove_token/3.
seam:foreign_space('&guard-token-provider').
seam:foreign_capability('&guard-token-provider', tokens).
seam:foreign_capability('&guard-token-provider', 'remove-token').
seam:foreign_token('&guard-token-provider', [guard_token], t(guard,1)).
seam:foreign_remove_token('&guard-token-provider', t(guard,1), true) :-
    nb_current('$metta_foreign_removal_token',[]),
    plunit_trailed_scopes:spin(30).

:- begin_tests(trailed_scopes).

:- metta_ensure_source_observation.
:- meta_predicate within(+, 0), minimum_budget(0, 0, -), sweep_trials(2, +, +, -),
                  minimum_budget(1, 0, 0, -), scope_fixture(+,0), observation_fixture(0),
                  bounded_call(0, +, -).

spin(0) :- !.
spin(N) :- M is N-1, spin(M).

% A native notification can defer the same limit ball past the limiter's
% return. Both forms mean interruption; neither skips the restoration check.
bounded_call(Goal, Budget, Outcome) :-
    catch(call_with_inference_limit(Goal, Budget, Outcome),
          inference_limit_exceeded, Outcome=inference_limit_exceeded).

test(answers_restore_the_outer_value_and_redo_restores_the_inner_value) :-
    metta_with_trailed('$plunit_trailed', outer,
        ( findall(N-In-Out,
              ( metta_with_trailed('$plunit_trailed', inner,
                    (member(N,[1,2]), nb_current('$plunit_trailed',In))),
                nb_current('$plunit_trailed',Out) ), Rows),
          Rows == [1-inner-outer,2-inner-outer],
          once(metta_with_trailed('$plunit_trailed', inner, member(_,[a,b]))),
          nb_current('$plunit_trailed',outer) )).

test(failure_exception_and_nested_mutation_restore_the_same_outer_object) :-
    Outer = cell(before),
    metta_with_trailed('$plunit_trailed', Outer,
        ( \+ metta_with_trailed('$plunit_trailed', inner, fail),
          catch(metta_with_trailed('$plunit_trailed', inner, throw(witness)),witness,true),
          metta_with_trailed('$plunit_trailed', cell(private),
              (nb_current('$plunit_trailed', Inner), nb_setarg(1, Inner, changed))),
          nb_current('$plunit_trailed', After), same_term(Outer,After),
          arg(1,After,before) )).

test(absent_contexts_are_inactive_after_success_and_absent_after_unwind) :-
    nb_delete('$plunit_trailed'),
    \+ metta_with_trailed('$plunit_trailed', inner, fail),
    \+ nb_current('$plunit_trailed',_),
    metta_with_trailed('$plunit_trailed', inner, true),
    nb_current('$plunit_trailed',[]).

scope(primitive, '$plunit_trailed').
scope(support_lock, '$metta_support_graph_locked').
scope(support_deferral, '$metta_support_repairs_deferred').
scope(typing, '$metta_typing_policy_snapshot').
scope(source_program, '$metta_source_programs').
scope(source_recompile, '$metta_source_recompile_contexts').
scope(source_owner, '$metta_source_loads').
scope(source_load, '$metta_source_loads').
scope(materialization_owner, '$metta_materialization_owner').
scope(materialization_batch, '$metta_materialization_batches').
scope(materialization_source, '$metta_source_materializations').
scope(effect_program, '$metta_effect_source_program').
scope(evaluation_context, '$metta_evaluation_contexts').
scope(working_directory, '$metta_working_dirs').
scope(module_context, '$metta_module').
scope(compiler_policy, '$metta_static_contract_shortcuts').
scope(equation_types, '$metta_queued_equation_types').
scope(parameter_environment, '$metta_static_parameter_environment').
scope(state_fence, '$metta_state_write_fence').
scope(occurrence_load, '$metta_occurrence_load').
scope(transaction, '$metta_user_tx').
scope(speculation, '$metta_user_tx').
scope(observation_session, '$metta_observation').
scope(observation_input, '$metta_source_input').
scope(observation_source, '$metta_source_context').
scope(observation_compiler, '$metta_compile_locations').
scope(observation_runnable, '$metta_observed_runnable').
scope(observation_suspension, '$metta_observed_runnable').

within(primitive, Goal) :- metta_with_trailed('$plunit_trailed', active, Goal).
within(support_lock, Goal) :- support_graph:support_atomic(Goal).
within(support_deferral, Goal) :- support_graph:with_support_repairs_deferred(Goal).
within(typing, Goal) :- type_rules:with_typing_policy_stable(Goal).
within(source_program, Goal) :- filereader:with_source_definition_order(guard_source,[],Goal).
within(source_recompile, Goal) :- filereader:with_source_recompile_owners([guard_owner],Goal).
within(source_owner, Goal) :- filereader:with_owning_source_load(guard_owner,Goal).
within(source_load, Goal) :-
    snapshot(filereader:with_source_load(guard_source, '&self',
        ( filereader:active_source_load(Load),
          assertz(filereader:source_load_digest(Load,guard_source,fixture)),
          call(Goal) ))).
within(materialization_owner, Goal) :- materialize:materialization_transaction(Goal).
within(materialization_batch, Goal) :-
    materialize:with_source_materialization_batch('&self',Goal,true).
within(materialization_source, Goal) :-
    metta_with_pragmas([['materialize-source-relations',true]],
        materialize:with_source_materialization('&self',[guard_absent],Goal), _).
within(effect_program, Goal) :-
    metta_self_module(Module), metta_engine:metta_with_source_effect_program(Module,[],Goal).
within(evaluation_context, Goal) :-
    metta_with_evaluation_context(evaluation_context(guard_algebra,0,none),Goal).
within(working_directory, Goal) :- filereader:with_working_directory(guard_directory,Goal).
within(module_context, Goal) :- metta_self_module(Module), with_metta_module(Module,Goal).
within(compiler_policy, Goal) :- translator:with_static_contract_shortcuts(enabled,Goal).
within(equation_types, Goal) :-
    metta_self_module(Module),
    translator:with_equation_types(Module,guard_equation,[[->,'Number','Number']],Goal).
within(parameter_environment, Goal) :-
    metta_self_module(Module),
    translator:with_static_parameter_environment(Module,guard_parameter,[_],
                                                [[->,'Number','Number']],Goal).
within(state_fence, Goal) :- metta_with_state_write_fence(Goal).
within(occurrence_load, Goal) :- spaces:metta_with_occurrence_load(Goal).
within(transaction, Goal) :- metta_transaction(Goal).
within(speculation, Goal) :- metta_speculate(Goal).
within(observation_session, Goal) :-
    source_observation:new_observation_buffer(Buffer),
    source_observation:with_observation("guard.metta",Buffer,_,Goal).
within(observation_input, Goal) :-
    observation_fixture(source_observation:source_input("",Goal)).
within(observation_source, Goal) :-
    observation_fixture(snapshot(source_observation:with_source("",[],'&self',Goal))).
within(observation_compiler, Goal) :-
    observation_fixture(source_observation:compile_clause(
        [=,[guard_compiler],ready],(guard_compiler:-true),Goal)).
within(observation_runnable, Goal) :-
    observation_fixture(
        ( nb_current('$metta_source_context',context(_,_,_,[Form-_])),
          source_observation:observe_form('&self',Form,[],Goal) )).
within(observation_suspension, Goal) :-
    observation_fixture(
        ( observation_tree(Tree), Context=compiling([],Tree,[]),
          metta_with_trailed('$metta_observed_runnable',
              runnable('&self',guard_document,Tree,Context),
              source_observation:observe_goals(plunit_trailed_scopes,[Goal],fail)) )).

observation_tree(node(span(0,1,1,1,1,2),[])).
observation_fixture(Goal) :-
    source_observation:new_observation_buffer(Buffer),
    nb_setarg(4,Buffer,guard_document),
    empty_assoc(Empty), metta_self_module(Module), observation_tree(Tree),
    Form=parsed(runnable,fixture,[guard_runnable],[]),
    Context=context(Module,guard_document,Empty,[Form-positioned(0,1,1,1,Tree)]),
    metta_with_trailed('$metta_observation',Buffer,
        metta_with_trailed('$metta_pending_source_maps',pending([]),
            metta_with_trailed('$metta_source_context',Context,Goal))).

inside(primitive) :- nb_current('$plunit_trailed',active).
inside(support_lock) :- support_graph:support_graph_locked.
inside(support_deferral) :- support_graph:support_repairs_deferred.
inside(typing) :- type_rules:typing_policy_snapshot(stable).
inside(source_program) :- filereader:active_source_program(guard_source).
inside(source_recompile) :- filereader:source_recompile_owners([guard_owner]).
inside(source_owner) :- filereader:active_source_load('$metta_owner_pin'(guard_owner)).
inside(source_load) :- filereader:active_source_load(Load), atom(Load).
inside(materialization_owner) :- materialize:materialization_transaction_owner.
inside(materialization_batch) :- materialize:materialization_batch(_).
inside(materialization_source) :-
    materialize:source_materialization('&self',[guard_absent]).
inside(effect_program) :- metta_self_module(Module), metta_engine:metta_effect_source_program(Module,_).
inside(evaluation_context) :-
    metta_engine:metta_evaluation_context(evaluation_context(guard_algebra,0,none)).
inside(working_directory) :- filereader:working_dir(guard_directory).
inside(module_context) :- metta_self_module(Module), nb_current('$metta_module',Module).
inside(compiler_policy) :- nb_current('$metta_static_contract_shortcuts',enabled).
inside(equation_types) :-
    metta_self_module(Module),
    nb_current('$metta_queued_equation_types',
               queued(Module,guard_equation,[[->,'Number','Number']])).
inside(parameter_environment) :-
    metta_self_module(Module),
    nb_current('$metta_static_parameter_environment',
               [static_parameter(_,Module,guard_parameter,1,1,'Number')]).
inside(state_fence) :- metta_engine:metta_state_write_fenced.
inside(occurrence_load) :- nb_current('$metta_occurrence_load',_-_).
inside(transaction) :- nb_current('$metta_user_tx',true).
inside(speculation) :- nb_current('$metta_user_tx',true).
inside(observation_session) :-
    nb_current('$metta_observation',observations(_,_,_,_,_,_)),
    nb_current('$metta_observe_label',"guard.metta"),
    nb_current('$metta_pending_source_maps',pending([])),
    source_observation:installed_hook(_).
inside(observation_input) :- nb_current('$metta_source_input',pending("",new)).
inside(observation_source) :-
    nb_current('$metta_source_context',context(_,Id,_,[])), integer(Id).
inside(observation_compiler) :-
    nb_current('$metta_compile_locations',compiling([=,[guard_compiler],ready],_,[])).
inside(observation_runnable) :-
    nb_current('$metta_observed_runnable',runnable('&self',guard_document,_,Context)),
    nb_current('$metta_compile_locations',Linked), same_term(Context,Linked).
inside(observation_suspension) :- nb_current('$metta_observed_runnable',[]).

% Sweep through the independently measured operation cost. The cut's host can
% report completion at an earlier budget, so that result alone cannot stop a
% sweep. Each trial also makes an unbounded second entry before yielding.
test(every_budget_restores_each_production_scope, [forall(scope(Site,Key))]) :-
    sweep(Site, Key, 1, Completed),
    format('scope-sweep(~q,1,~d,zero_leaks).~n',[Site,Completed]).

sweep(Site, Key, Budget, Completed) :-
    minimum_budget(scope_fixture(Site),
                   (nb_setval(Key,[]),once(within(Site,inside(Site)))),
                   once(within(Site,(inside(Site),spin(30)))), Minimum),
    sweep_trials(scope_entry(Site,Key),Budget,Minimum,Completed).

minimum_budget(Prepare, Goal, Minimum) :-
    minimum_budget(call,Prepare,Goal,Minimum).

minimum_budget(Fixture, Prepare, Goal, Minimum) :-
    setup_call_cleanup(
        engine_create(Cost,
            call(Fixture,(call(Prepare),statistics(inferences,Before),call(Goal),
                          statistics(inferences,After),Cost is After-Before-1)),Engine),
        engine_next(Engine,Minimum),engine_destroy(Engine)).

scope_fixture(observation_compiler,Goal) :- !,
    Input=[=,[guard_compiler],ready], metta_self_module(Module),
    variant_sha1(Input,Key), observation_tree(Tree),
    snapshot((add_sexp('&self',Input,_,Ref),
              assertz(source_observation:source_equation(Key,Module,Ref,guard_document,Tree)),
              call(Goal))).
scope_fixture(_,Goal) :- call(Goal).

scope_entry(Site,Key,Budget,Result) :-
    scope_fixture(Site,sweep_entry(Site,Key,Budget,Result)).

sweep_trials(Trial, Budget, Minimum, Completed) :-
    setup_call_cleanup(
        engine_create(Result,call(Trial,Budget,Result),Engine),
        engine_next(Engine,Result),engine_destroy(Engine)),
    ( Result == failed -> format('scope-bounded-failure(~q,~d).~n',[Trial,Budget]) ; true ),
    ( (Result == inference_limit_exceeded ; Result == failed ; Budget < Minimum)
    -> Next is Budget+1, sweep_trials(Trial,Next,Minimum,Completed)
    ; Result == completed, Completed=Budget ).

sweep_entry(Site, Key, Budget, Result) :-
    nb_setval(Key, []),
    % Warm resolution outside the measured scope; this test targets scope
    % restoration rather than the separate undefined-supervisor host defect.
    once(within(Site, inside(Site))),
    nb_setval(Key, []),
    ( bounded_call(once(within(Site,(inside(Site),spin(30)))), Budget, Outcome)
    -> true ; Outcome=failed ),
    ( nb_current(Key, []) -> true
    ; nb_current(Key, Leaked), throw(error(scope_leaked(Site,Budget,Leaked),none)) ),
    operation_clean(Site),
    once(within(Site,(inside(Site),spin(1)))),
    nb_current(Key, []), operation_clean(Site),
    ( memberchk(Outcome,[inference_limit_exceeded,failed]) -> Result=Outcome ; Result=completed ).

test(nested_directory_and_owner_contexts_preserve_enumeration_order) :-
    metta_with_trailed('$metta_working_dirs', [],
        filereader:with_working_directory(outer,
            filereader:with_working_directory(inner,
                findall(D,filereader:working_dir(D),[inner,outer])))),
    metta_with_trailed('$metta_source_loads', [outer],
        filereader:with_owning_source_load(inner,
            findall(L,filereader:active_source_load(L),['$metta_owner_pin'(inner),outer]))).

test(compiler_contexts_keep_the_callers_variable_identity) :-
    metta_self_module(Module),
    translator:with_equation_types(Module,guard_equation,[Variable],
        (nb_current('$metta_queued_equation_types',queued(_,_,[Linked])),
         Variable == Linked)),
    translator:with_static_parameter_environment(Module,guard_parameter,[Variable],
        [[->,'Number','Number']],
        (nb_current('$metta_static_parameter_environment',[static_parameter(Linked,_,_,_,_,_)]),
         Variable == Linked)).

operation(declared_types, '$metta_reading_declared_types').
operation(reference_refresh, '$metta_reference_refreshing').
operation(reference_force, '$metta_reference_forcing').
operation(specialization_check, '$metta_specialization_checking').
operation(source_rollback, '$metta_source_loads').
operation(reference_finishing, '$metta_reference_finishing').
operation(bridge_depth, '$metta_bridge_depth').
operation(counted_hook, '$metta_hook_granted').
operation(ordinary_hook, '$metta_hook_granted').
operation(post_hook, '$metta_hook_granted').
operation(foreign_selector, '$metta_foreign_removal_token').
operation(foreign_consumption, '$metta_foreign_removal_token').

perform(declared_types) :-
    metta_self_module(Module),
    metta_engine:metta_argument_types_in(Module,42,Types), Types \== [].
perform(reference_refresh) :- metta_engine:metta_reference_refresh.
perform(reference_force) :- metta_engine:metta_reference_force(guard_absent).
perform(specialization_check) :-
    retractall(specializer:ho_specialization_agrees('$plunit_guard_spec')),
    metta_self_module(Module),
    specializer:metta_verified_specialization('$plunit_guard_spec',
                                              Module:'$plunit_guard_spec'(42)).
perform(source_rollback) :-
    catch(filereader:with_source_load(guard_source, '&self',
              plunit_trailed_scopes:rollback_payload), guard_rollback, true).
perform(reference_finishing) :-
    thread_self(Owner),
    nb_setval('$metta_reference_frames',[guard_frame]),
    metta_engine:metta_reference_finish_frame(Owner,guard_frame).
perform(bridge_depth) :-
    snapshot(metta_engine:metta_bridge_descend([insert,'&self',[guard_payload]])).
perform(counted_hook) :-
    snapshot(metta_engine:metta_hook_apply_counted([accept,[guard_rewritten]],
        '&self',guard_handler,[guard_original],true,true)).
perform(ordinary_hook) :-
    snapshot(metta_engine:metta_hook_apply([accept,[guard_rewritten]],
        '&self',guard_handler,[guard_original],true,true)).
perform(post_hook) :-
    snapshot((metta_add_atom('&self',[guard_original],true),
              metta_engine:metta_hook_post_apply([accept,[guard_rewritten]],
                  '&self',guard_handler,[guard_original]))).
perform(foreign_selector) :-
    catch(spaces:metta_remove_occurrence('&guard-token-provider',t(guard,1),true),
          error(permission_error(remove,foreign_space,'&guard-token-provider'),_),true).
perform(foreign_consumption) :-
    metta_with_trailed('$metta_foreign_removal_token','&guard-token-provider'-t(guard,1),
        spaces:metta_remove_provider_occurrence('&guard-token-provider',[guard_token],true)).
perform(higher_order(Module)) :-
    snapshot(with_metta_module(Module,
        ( specializer:invalidate_specializations(Module,'guard-apply'),
          specializer:maybe_specialize_call('guard-apply',['guard-inc',42],_,_) ))).
perform(segment(Module)) :-
    snapshot(with_metta_module(Module,
        ( specializer:invalidate_specializations(Module,'guard-variadic'),
          specializer:segment_specialization('guard-variadic',[one,two],_,_) ))).

:- dynamic retirement_witness/1.
rollback_payload :-
    filereader:active_source_load(Load),
    nb_setval('$plunit_guard_load',Load),
    forall(between(1,3,_),
        ( assertz(retirement_witness(Load),Ref),
          catch(assertz(filereader:source_load_assertion(Load,artifact,Ref)),
                Ball,(ignore(erase(Ref)),throw(Ball))) )),
    throw(guard_rollback).

operation_clean(source_rollback) :- !,
    \+ retirement_witness(_),
    nb_current('$plunit_guard_load',Load),
    \+ filereader:source_load_assertion(Load,_,_).
operation_clean(observation_session) :- !,
    forall(member(Key,['$metta_observation','$metta_observe_label',
                       '$metta_pending_source_maps','$metta_source_input',
                       '$metta_source_context','$metta_compile_locations',
                       '$metta_observed_runnable']), context_inactive(Key)),
    \+ source_observation:installed_hook(_),
    \+ source_observation:source_document(_,_,_).
operation_clean(higher_order(_)) :- !, context_inactive('$metta_spec_needed').
operation_clean(observation_suspension) :- !, no_scoped_clause(observed).
operation_clean(_).

context_inactive(Key) :- \+ (nb_current(Key,Value), Value \== []).

test(internal_guarded_operations_restore_after_every_budget,
     [setup(install_operation_fixture(Refs)), cleanup(maplist(erase,Refs)),
      forall(operation(Site,Key))]) :-
    operation_sweep(Site,Key,1,Completed),
    retractall(specializer:ho_specialization_agrees('$plunit_guard_spec')),
    format('scope-sweep(~q,1,~d,zero_leaks).~n',[Site,Completed]).

install_operation_fixture([Plain,Spec,Mapping]) :-
    metta_self_module(Module),
    assertz(Module:'$plunit_guard_plain'(42), Plain),
    assertz(Module:'$plunit_guard_spec'(42), Spec),
    assertz(specializer:ho_specialization(Module,'$plunit_guard_plain',
                                        '$plunit_guard_spec'), Mapping).

specialization_fixture(Space, Module) :-
    'new-space'(Space), space_module(Space,Module),
    process_metta_string(
        "(= (guard-inc $x) (+ $x 1)) (= (guard-apply $f $x) ($f $x)) (= (guard-variadic (:seg $xs)) ready)",
        _,Space),
    with_metta_module(Module,
        maplist(spaces:metta_ensure_compiled,['guard-inc','guard-apply','guard-variadic'])).

specialization_scope(Module,higher_order(Module),'$metta_spec_stack').
specialization_scope(Module,segment(Module),'$metta_segment_stack').

test(specialization_construction_restores_all_its_roots,
     [setup(specialization_fixture(Space,Module)), cleanup(metta_release_space(Space))]) :-
    forall(specialization_scope(Module,Site,Key),
        (operation_sweep(Site,Key,1,Completed),
         format('scope-sweep(~q,1,~d,zero_leaks).~n',[Site,Completed]))).

operation_sweep(Site,Key,Budget,Completed) :-
    minimum_budget((nb_setval(Key,[]),once(perform(Site))),once(perform(Site)),Minimum),
    sweep_trials(operation_entry(Site,Key),Budget,Minimum,Completed).

operation_entry(Site,Key,Budget,Result) :-
    nb_setval(Key,[]), once(perform(Site)), nb_setval(Key,[]),
    ( bounded_call(once(perform(Site)), Budget, Outcome)
    -> true ; throw(error(operation_failed(Site,Budget),none)) ),
    ( nb_current(Key,[]) -> true
    ; nb_current(Key,Leaked), throw(error(scope_leaked(Site,Budget,Leaked),none)) ),
    operation_clean(Site),
    once(perform(Site)), nb_current(Key,[]), operation_clean(Site),
    ( Outcome == inference_limit_exceeded -> Result=Outcome ; Result=completed ).

test(early_loader_watcher_retires_at_every_budget) :-
    clause_sweep(loader, 1, Completed),
    format('scope-sweep(loader_watcher,1,~d,zero_leaks).~n',[Completed]).

test(executable_observation_clause_retires_at_every_budget) :-
    clause_sweep(observed, 1, Completed),
    format('scope-sweep(observed_clause,1,~d,zero_leaks).~n',[Completed]).

test(failed_loading_marker_retires_at_every_budget) :-
    clause_sweep(marker, 1, Completed),
    format('scope-sweep(loading_marker,1,~d,zero_leaks).~n',[Completed]).

test(registration_probe_retires_at_every_budget,
     [setup((metta_self_module(Base),assertz(Base:'$plunit_guard_probe'(held),Ref))),
      cleanup(erase(Ref))]) :-
    clause_sweep(probe, 1, Completed),
    format('scope-sweep(registration_probe,1,~d,zero_leaks).~n',[Completed]).

clause_sweep(Site, Budget, Completed) :-
    minimum_budget(once(clause_scope(Site)),once(clause_scope(Site)),Minimum),
    sweep_trials(clause_entry(Site),Budget,Minimum,Completed).

clause_entry(Site, Budget, Result) :-
    once(clause_scope(Site)),
    ( bounded_call(once(clause_scope(Site)),Budget,Outcome)
    -> true ; throw(error(clause_scope_failed(Site,Budget),none)) ),
    no_scoped_clause(Site),
    once(clause_scope(Site)), no_scoped_clause(Site),
    ( Outcome == inference_limit_exceeded -> Result=Outcome ; Result=completed ).

clause_scope(loader) :- metta_source_loading:loading_loudly(plunit_trailed_scopes:spin(30)).
clause_scope(observed) :-
    source_observation:execute_observed_goals(plunit_trailed_scopes,[spin(30)],
        guard_document,node(span(0,1,1,1,1,2),[]),compiling([],[],[])).
clause_scope(probe) :-
    metta_engine:metta_host_probe_function('$plunit_guard_probe',1).
clause_scope(marker) :-
    catch(filereader:run_with_loading_marker(plunit_trailed_scopes:loading_witness,
              (plunit_trailed_scopes:spin(30),throw(marker_witness))),marker_witness,true).

:- dynamic loading_witness/0.

no_scoped_clause(loader) :-
    \+ metta_source_loading:watching,
    \+ metta_source_loading:diagnostic(_,_).
no_scoped_clause(observed) :-
    \+ (current_predicate(plunit_trailed_scopes:Name/1),
        sub_atom(Name,0,_,_,'$metta_observed_')).
no_scoped_clause(probe) :-
    metta_self_module(Module),
    Module:'$plunit_guard_probe'(held),
    \+ clause(Module:'$plunit_guard_probe'(_),fail,_).
no_scoped_clause(marker) :- \+ loading_witness.

test(successful_loading_marker_remains_published,
     [cleanup(retractall(loading_witness))]) :-
    filereader:run_with_loading_marker(plunit_trailed_scopes:loading_witness,true),
    loading_witness.

test(signal_during_clause_use_propagates_and_retires_the_clause,
     [forall(member(Site,[loader,observed,marker]))]) :-
    catch(signal_scope(Site),Ball,true),
    Ball == async_witness,
    no_scoped_clause(Site).

% Predicate notifications run after assertion, inside the acquisition's
% signal mask. Queue the interrupt at that exact point, before publication.
test(signal_during_marker_acquisition_waits_for_ownership) :-
    Predicate = plunit_trailed_scopes:loading_witness/0,
    setup_call_cleanup(prolog_listen(Predicate,queue_acquisition_signal),
        ( catch(clause_scope(marker),Ball,true),
          Ball == async_witness,
          no_scoped_clause(marker) ),
        prolog_unlisten(Predicate,queue_acquisition_signal)).

queue_acquisition_signal(assertz, _) :- !, raise_signal.
queue_acquisition_signal(_, _).

raise_signal :-
    thread_self(Thread), thread_signal(Thread,throw(async_witness)), spin(1).
signal_scope(loader) :-
    metta_source_loading:loading_loudly(plunit_trailed_scopes:raise_signal).
signal_scope(observed) :-
    source_observation:execute_observed_goals(plunit_trailed_scopes,[raise_signal],
        guard_document,node(span(0,1,1,1,1,2),[]),compiling([],[],[])).
signal_scope(marker) :-
    filereader:run_with_loading_marker(plunit_trailed_scopes:loading_witness,
                                      plunit_trailed_scopes:raise_signal).

test(observed_clause_keeps_nondeterministic_answers_and_propagates_exceptions) :-
    Tree=node(span(0,1,1,1,1,2),[]), Context=compiling([],[],[]),
    findall(X, source_observation:execute_observed_goals(plunit_trailed_scopes,
                    [member(X,[one,two])], guard_document,Tree,Context), [one,two]),
    catch(source_observation:execute_observed_goals(plunit_trailed_scopes,
              [throw(witness)],guard_document,Tree,Context),witness,true),
    no_scoped_clause(observed).

test(a_worker_needs_no_global_initialization) :-
    setup_call_cleanup(message_queue_create(Queue),
        ( thread_create((thread_get_message(Queue,go),
                         metta_with_trailed('$plunit_late_context',true,
                             nb_current('$plunit_late_context',true)),
                         nb_current('$plunit_late_context',[])), Worker, []),
          thread_send_message(Queue,go), thread_join(Worker,true) ),
        message_queue_destroy(Queue)).

% The read side (engine/ext_points.pl, context_reader/4): a declared reader is
% a predicate for meta-calls and a compile-time read everywhere it is called.
test(every_declared_reader_is_compiled_to_its_read) :-
    aggregate_all(count, seam:context_reader(_,_,_,_), Declared),
    Declared >= 18,
    forall(seam:context_reader(Head, Owner, Key, _),
           ( once(clause(Owner:Head, Body)),
             ( Body = (nb_current(Key, _), _) -> true ; Body = nb_current(Key, _) ) )).

% These clauses are compiled by this suite, so their bodies show what any
% production caller compiles to: the read, qualified by the declaring module.
probe_flag_read :- support_graph:support_graph_locked.
probe_stack_read(Load) :- filereader:active_source_load(Load).
probe_value_read(Snapshot) :- type_rules:typing_policy_snapshot(Snapshot).
probe_imported_read(Context) :- metta_evaluation_context(Context).

test(a_call_site_carries_the_read_rather_than_a_call) :-
    clause(probe_flag_read, Flag),
    Flag = support_graph:nb_current('$metta_support_graph_locked', true),
    clause(probe_stack_read(_), Stack),
    Stack = (filereader:nb_current('$metta_source_loads', [_|_]), _),
    clause(probe_value_read(_), Value),
    Value = type_rules:nb_current('$metta_typing_policy_snapshot', snapshot(_)),
    clause(probe_imported_read(_), Imported),
    Imported = nb_current('$metta_evaluation_contexts', [_|_]).

% Per-call inferences of a compiled read against the empty dynamic fact it
% replaced, in the three states a reader meets: key unset, inactive [] and a
% one-element context. The loops are compiled the way production callers
% are, so the read is inlined rather than called.
:- dynamic reader_cost_fact/1.
cost_loop(empty) :- ( between(1, 10000, _), fail ; true ).
cost_loop(fact_absent) :- ( between(1, 10000, _), \+ reader_cost_fact(_), fail ; true ).
cost_loop(fact_present) :- ( between(1, 10000, _), reader_cost_fact(_), fail ; true ).
cost_loop(flag_absent) :- ( between(1, 10000, _), \+ support_graph:support_graph_locked, fail ; true ).
cost_loop(flag_present) :- ( between(1, 10000, _), support_graph:support_graph_locked, fail ; true ).
cost_loop(stack_absent) :- ( between(1, 10000, _), \+ filereader:active_source_load(_), fail ; true ).
cost_loop(stack_present) :- ( between(1, 10000, _), filereader:active_source_load(_), fail ; true ).

loop_cost(Loop, Cost) :-
    cost_loop(Loop), cost_loop(Loop),
    statistics(inferences, Before), cost_loop(Loop), statistics(inferences, After),
    Cost is After - Before.

test(an_inactive_reader_costs_what_the_asserted_guard_cost,
     [setup((nb_delete('$metta_support_graph_locked'), nb_delete('$metta_source_loads'),
             retractall(reader_cost_fact(_)))),
      cleanup((nb_setval('$metta_support_graph_locked', []), nb_setval('$metta_source_loads', []),
               retractall(reader_cost_fact(_))))]) :-
    loop_cost(fact_absent, FactAbsent),
    loop_cost(flag_absent, FlagUnset), loop_cost(stack_absent, StackUnset),
    assertion(FlagUnset == FactAbsent), assertion(StackUnset == FactAbsent),
    nb_setval('$metta_support_graph_locked', []), nb_setval('$metta_source_loads', []),
    loop_cost(flag_absent, FlagInactive), loop_cost(stack_absent, StackInactive),
    assertion(FlagInactive == FactAbsent), assertion(StackInactive == FactAbsent),
    assertz(reader_cost_fact(guard)),
    nb_setval('$metta_support_graph_locked', true), nb_setval('$metta_source_loads', [guard]),
    loop_cost(fact_present, FactPresent),
    loop_cost(flag_present, FlagPresent), loop_cost(stack_present, StackPresent),
    assertion(FlagPresent == FactPresent), assertion(StackPresent == FactPresent).

test(a_one_element_stack_reads_without_a_choicepoint,
     [cleanup(nb_setval('$metta_source_loads', []))]) :-
    nb_setval('$metta_source_loads', [only]),
    prolog_current_choice(Before),
    filereader:active_source_load(Read),
    prolog_current_choice(After),
    assertion(Read == only), assertion(Before == After),
    nb_setval('$metta_source_loads', [inner, outer]),
    findall(L, filereader:active_source_load(L), Both),
    assertion(Both == [inner, outer]).

test(a_malformed_reader_declaration_refuses_at_load) :-
    catch(expand_term((:- seam:context_reader(planted_reader, '$plunit_planted', ring)), _),
          error(domain_error(context_reader_shape, ring), _), Refused = shape),
    assertion(Refused == shape),
    catch(expand_term((:- seam:context_reader(planted_reader, "not an atom", value(true))), _),
          error(type_error(atom, _), _), Typed = key),
    assertion(Typed == key),
    \+ clause(planted_reader, _).

:- end_tests(trailed_scopes).
