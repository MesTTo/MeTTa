% Purpose: verify runnable translation caching, variant keys, and invalidation.
% Owns resources: concurrency fixtures join their worker and remove their
%   compiler observer, queues, pending reservations and temporary space.
% Guarantees: a miss compiles once outside the publication mutex; a concurrent
%   source change or cache clear prevents stale publication
%   [tested: translation_cache; commit=4b61fbdba18f37f8b2857a879dd5220e9f08cb3f].
% Guarantees: retiring generated calls or returned functions evicts their
%   cached translations and cancels incomplete dependency reservations
%   [tested: translation_cache; commit=4b61fbdba18f37f8b2857a879dd5220e9f08cb3f].

% Guarantees: ordinary eval preserves attributed-variable identity, sharing,
%   delayed hook counts and binding-time exceptions, including after a plain
%   template is warm [tested: translation_cache; commit=4b61fbdba18f37f8b2857a879dd5220e9f08cb3f].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(when)).

:- begin_tests(translation_cache).

clear_translation_cache_test_state :-
    user:clear_translation_cache.

:- dynamic translation_compile_count/1.

install_translation_compile_counter :-
    retractall(translation_compile_count(_)),
    assertz(translation_compile_count(0)),
    %The compiler's own module, not the engine's. wrap_predicate/4 on a name
    %the engine merely IMPORTS wraps the import and leaves the definition
    %alone, so the counter watched a link nothing inside the compiler follows
    %and every run looked like a cache hit [measured 2026-08-22].
    wrap_predicate(translator:translate_runnable_expr(_, _, _),
                   translation_cache_acceptance_counter, Wrapped,
                   count_translation_compile(Wrapped)).

remove_translation_compile_counter :-
    unwrap_predicate(translator:translate_runnable_expr/3,
                     translation_cache_acceptance_counter),
    retractall(translation_compile_count(_)).

count_translation_compile(Wrapped) :-
    retract(translation_compile_count(Before)),
    After is Before + 1,
    assertz(translation_compile_count(After)),
    call(Wrapped).

run_translated(Expression, Answer) :-
    translate_cached_expr(Expression, Goals, Answer),
    current_metta_module(Module),
    call_goals_in_(Module, Goals).

test(a_repeated_eval_reuses_one_translated_template,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    run_translated([+, 20, 22], 42),
    run_translated([+, 20, 22], 42),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  1).

test(variant_calls_share_a_template_without_sharing_call_variables,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    %`(quote V)` is the cheapest form that compiles to no goals at all, which
    %is why it is the probe here. It answers its PAYLOAD, the quote being an
    %evaluation barrier rather than a wrapper, so the template's value is the
    %variable itself.
    translate_cached_expr([quote, X], [], X),
    translate_cached_expr([quote, Y], [], Y),
    X = first,
    var(Y),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  1).

test(a_numbervars_literal_cannot_alias_a_real_variable_key,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    translate_cached_expr([quote, _], _, VariableValue),
    translate_cached_expr([quote, '$VAR'(0)], _, LiteralValue),
    VariableValue = Variable,
    var(Variable),
    LiteralValue == '$VAR'(0),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  2).

test(ordinary_eval_preserves_nested_shared_dif_constraints,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    dif(Left, Right),
    Source = [noeval, [pair, Left, Left, Right]],
    eval(Source, Result),
    assertion(Result == [pair, Left, Left, Right]),
    Result = [pair, First, Repeated, Last],
    First = admitted,
    assertion(Repeated == admitted),
    assertion(Left == admitted),
    assertion(\+ Last = admitted),
    Last = distinct,
    assertion(Right == distinct),
    assertion(\+ translator:translated_form_cache(_, _, _, _, _, _)),
    assertion(\+ translator:translated_form_pending(_, _, _)).

test(ordinary_eval_preserves_when_wakeup_count,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    Counter = count(0),
    when(nonvar(Variable), increment_attribute_wakeup(Counter)),
    eval([noeval, Variable], First),
    eval([noeval, Variable], Second),
    assertion(First == Variable),
    assertion(Second == Variable),
    assertion(Counter == count(0)),
    First = admitted,
    assertion(Second == admitted),
    assertion(Counter == count(1)),
    assertion(\+ translator:translated_form_cache(_, _, _, _, _, _)).

test(ordinary_eval_preserves_a_hidden_when_reference,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state) ]) :-
    Counter = count(0),
    when((nonvar(Variable);nonvar(Hidden)), increment_attribute_wakeup(Counter)),
    eval([noeval, Variable], Result),
    assertion(Result == Variable),
    assertion(Counter == count(0)),
    Hidden = activated,
    assertion(Counter == count(1)),
    assertion(var(Variable)),
    Result = later,
    assertion(Counter == count(1)).

test(a_warmed_plain_template_does_not_admit_constraint_hooks,
     [ setup((clear_translation_cache_test_state, install_translation_compile_counter)),
       cleanup((remove_translation_compile_counter, clear_translation_cache_test_state)) ]) :-
    eval([noeval, Plain], PlainResult),
    assertion(PlainResult == Plain),
    assertion(translation_compile_count(1)),
    Counter = count(0),
    when(nonvar(Variable), increment_attribute_wakeup(Counter)),
    eval([noeval, Variable], First),
    eval([noeval, Variable], Second),
    assertion(translation_compile_count(3)),
    aggregate_all(count, translator:translated_form_cache(_, _, _, _, _, _), 1),
    assertion(First == Variable),
    assertion(Second == Variable),
    assertion(var(Plain)),
    assertion(Counter == count(0)),
    Variable = admitted,
    assertion(Counter == count(1)).

test(a_when_exception_occurs_only_at_the_original_binding,
     [ setup(clear_translation_cache_test_state),
       cleanup(clear_translation_cache_test_state),
       throws(attribute_wakeup_error) ]) :-
    when(nonvar(Variable), throw(attribute_wakeup_error)),
    catch(eval([noeval, Variable], Result), Early,
          throw(unexpected_evaluation_wakeup(Early))),
    assertion(Result == Variable),
    Result = admitted.

increment_attribute_wakeup(Counter) :-
    arg(1, Counter, Before), After is Before + 1, nb_setarg(1, Counter, After).

test(a_function_change_evicts_only_templates_that_mention_its_name,
     [ setup(clear_translation_cache_test_state),
       cleanup(( clear_translation_cache_test_state,
                 metta_self_module(Module),
                 specializer:forget_symbol(Module, 'tc-late') )) ]) :-
    run_translated(['tc-late', 2], ['tc-late', 2]),
    run_translated([+, 1, 2], 3),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  2),
    process_metta_string("(= (tc-late $x) (+ $x 1))", _),
    \+ translator:translated_form_mention('tc-late', _),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  1),
    run_translated(['tc-late', 2], 3),
    translator:translated_form_mention('tc-late', _),
    metta_remove_atom('&self',
                      [=, ['tc-late', X], [+, X, 1]], _),
    \+ translator:translated_form_mention('tc-late', _),
    run_translated(['tc-late', 2], ['tc-late', 2]).

test(concurrent_first_use_publishes_one_template,
     [ setup((clear_translation_cache_test_state,install_translation_compile_counter)),
       cleanup((remove_translation_compile_counter,clear_translation_cache_test_state)) ]) :-
    concurrent_forall(between(1, 32, _),
                      run_translated([+, 40, 2], 42),
                      [threads(32)]),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  1),
    assertion(translation_compile_count(1)).

test(a_compiling_miss_releases_publication_and_observes_invalidation,
     [forall((member(Change,[definition,cache,module,retirement]),member(Snapshot,[live,transaction]))),
      condition(current_prolog_flag(threads,true)),
      setup(clear_translation_cache_test_state),
      cleanup(clear_translation_cache_test_state)]) :-
    gensym('&translation-pending-',Space), space_module(Space,Module),
    setup_call_cleanup(
        ( message_queue_create(Entered), message_queue_create(Release),
          wrap_predicate(translator:translate_runnable_expr(Form,_,_),
                         translation_pending_test,Compile,
                         (call(Compile),
                          (Form = ['tc-pending'|_]
                          -> thread_send_message(Entered,compiled),
                             thread_get_message(Release,continue)
                          ; true))) ),
        ( ( Change == retirement
          -> Source = ['tc-pending',['|->',[Argument],Argument]]
          ; Source = ['tc-pending',2] ),
          setup_call_cleanup(
            thread_create(translate_pending_snapshot(Snapshot,Module,Source),Worker,[]),
            ( thread_get_message(Entered,compiled),
              setup_call_cleanup(mutex_trylock('$metta_translation_cache'),
                                 true,mutex_unlock('$metta_translation_cache')),
              run_translated([+,40,2],42),
              invalidate_pending_translation(Change,Space,Module),
              assertion(\+ translator:translated_form_pending(Module,_,_)),
              thread_send_message(Release,continue) ),
            (thread_send_message(Release,continue),thread_join(Worker,true)) ),
          assertion(\+ translator:translated_form_cache(Module,_,_,_,_,_)),
          assertion(\+ translator:translated_form_mention('tc-pending',_)) ),
        ( unwrap_predicate(translator:translate_runnable_expr(_,_,_),translation_pending_test),
          message_queue_destroy(Entered), message_queue_destroy(Release),
          metta_release_space(Space) )).

translate_pending_snapshot(live,Module,Source) :-
    with_metta_module(Module,translate_cached_expr(Source,_,_)).
translate_pending_snapshot(transaction,Module,Source) :-
    transaction(translate_pending_snapshot(live,Module,Source)).

invalidate_pending_translation(definition,Space,_) :-
    metta_add_atom(Space,[=,['tc-pending',X],[+,X,1]],_).
invalidate_pending_translation(cache,_,_) :- clear_translation_cache_test_state.
invalidate_pending_translation(module,_,Module) :-
    translator:clear_module_translation_state(Module).
invalidate_pending_translation(retirement,_,Module) :-
    findall(Name,
            (translator:translated_from(Ref,[=,[Name|_],_]),
             clause_property(Ref,module(Module))), Names),
    ( Names == []
    -> % An uncommitted compiler's generated clauses are private to its
       % transaction, just as its reservation is. Announce the same event.
       spaces:announce_function_removed('tc-private-generated')
    ; forall(member(Name,Names),specializer:forget_symbol(Module,Name)) ).

test(a_cached_generated_call_is_rebuilt_after_its_functions_retire,
     [forall(member(Arity,[0,1,5])),
      setup(clear_translation_cache_test_state),
      cleanup(clear_translation_cache_test_state)]) :-
    gensym('&translation-artifact-',Space), space_module(Space,Module),
    setup_call_cleanup(true,
        with_metta_module(Module, plunit_translation_cache:
            ( findall(N,between(1,Arity,N),Values),
              Source = [['|->', [[':seg',Args]], [evalc,[noeval,Args],Space]]|Values],
              findall(Value,run_translated(Source,Value),Before),
              assertion(Before == [Values]),
              run_translated([+,20,22],42),
              findall(Name,
                      (translator:translated_from(Ref,[=,[Name|_],_]),
                       clause_property(Ref,module(Module))),Generated),
              assertion(Generated \== []),
              forall(member(Name,Generated),specializer:forget_symbol(Module,Name)),
              assertion(translator:translated_form_cache(Module,_,_,[+,_,_],_,_)),
              findall(Value,run_translated(Source,Value),After),
              assertion(After == [Values]) )),
        metta_release_space(Space)).

test(a_cached_generated_value_is_rebuilt_after_its_function_retires,
     [setup(clear_translation_cache_test_state),
      cleanup(clear_translation_cache_test_state)]) :-
    gensym('&translation-value-',Space), space_module(Space,Module),
    setup_call_cleanup(true,
        with_metta_module(Module, plunit_translation_cache:
            ( Source = ['|->',[X],[+,X,1]],
              run_translated(Source,First),
              eval([First,2],3),
              specializer:forget_symbol(Module,First),
              run_translated(Source,Second),
              assertion(First \== Second),
              eval([Second,4],5) )),
        metta_release_space(Space)).

test(a_failed_compiler_releases_its_reservation_and_key,
     [setup(clear_translation_cache_test_state),
      cleanup(clear_translation_cache_test_state)]) :-
    setup_call_cleanup(
        wrap_predicate(translator:translate_runnable_expr(Form,_,_),
                       translation_failure_test,Compile,
                       (Form = ['tc-failed'|_] -> throw(compile_failure) ; call(Compile))),
        catch(translate_cached_expr(['tc-failed',2],_,_),compile_failure,true),
        unwrap_predicate(translator:translate_runnable_expr(_,_,_),translation_failure_test)),
    assertion(\+ translator:translated_form_pending(_,_,_)),
    assertion(\+ translator:translated_form_mention('tc-failed',_)),
    assertion(\+ metta_engine:metta_source_flight(translation(_,_),_,_)),
    run_translated(['tc-failed',2],['tc-failed',2]).

test(test_a_repeated_eval_does_not_recompile_and_the_effects_cluster_conforms,
     [ setup(( clear_translation_cache_test_state,
               process_metta_string("(: tc-effect (-> Atom String))", _),
               process_metta_string(
                   "(= (tc-effect $l) (prog1 \"s\" (add-atom &self (tc-ran))))",
                   _),
               clear_translation_cache_test_state,
               install_translation_compile_counter )),
       cleanup(( remove_translation_compile_counter,
                 clear_translation_cache_test_state,
                 remove_sexp('&self', ['tc-ran']),
                 metta_self_module(Module),
                 specializer:forget_symbol(Module, 'tc-effect') )) ]) :-
    once(run_translated([+, 20, 22], 42)),
    translation_compile_count(AfterFirst),
    assertion(AfterFirst == 1),
    once(run_translated([+, 20, 22], 42)),
    translation_compile_count(AfterSecond),
    assertion(AfterSecond == 1),
    aggregate_all(count,
                  translator:translated_form_cache(_, _, _, _, _, _),
                  1),
    once(run_translated([+, 1, ['tc-effect', 'TC-MARK']], Answer)),
    swrite(Answer, Text),
    assertion(Text == "(Error (+ 1 (tc-effect TC-MARK)) (BadArgType 2 Number String))"),
    assertion(\+ get_native_atom('&self', ['tc-ran'])).

:- end_tests(translation_cache).
