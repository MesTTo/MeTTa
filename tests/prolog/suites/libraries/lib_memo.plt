% Purpose: direct PlUnit coverage for memoization storage, eviction, and the
%   per-space keying that keeps one space's cache out of another's answers.
% Guarantees:
%   - every inference budget through the first completed reconciliation leaves
%     no active marker and permits the next reconciliation to publish its plan
%     [tested: memo_reconciliation_interrupt:every_budget_restores_the_guard;
%     commit=8358dfc233bf299bb23eceddd94593a62372fe4b].
%   - A changed callee invalidates transitive caller caches through supports/2
%     while an unrelated cache survives [tested:
%     memo_support_graph:a_leaf_change_invalidates_transitive_callers_only;
%     commit=7ade2b90e2631451fd6ffc23d22dd8c2d4a7a7aa].
%   - A written declaration is honoured over a body the effect walk cannot
%     classify, over one that reads a space, and over a function a library
%     declared volatile; the one refusal left names a mechanism rather than a
%     body [tested: lib_memo_volatility:a_declaration_memoizes_an_impure_body,
%     lib_memo_volatility:a_declaration_memoizes_a_space_reading_body,
%     lib_memo_volatility:a_volatile_function_still_memoizes_on_the_declaration,
%     lib_memo_volatility:a_name_that_is_not_a_function_is_still_refused;
%     commit=ccad9f6d588270ec2f0810fc56c30e9e59207e7c].
%   - A declaration REACHES the calls it governs: a registered operation is
%     cached through a caller compiled before it, and enabling does not rewrite
%     the space's stored program [tested:
%     lib_memo_reach:memoizing_an_operation_reaches_a_caller_compiled_before_it,
%     lib_memo_reach:a_body_that_writes_its_own_space_is_not_duplicated_by_memoize;
%     commit=295f4c80ace06f6bf8e132ea936777afd79ac3d5].
%   - Exact-cache invalidation advances a hidden table generation seen by
%     already-live worker engines [tested:
%     lib_memo_stats:invalidation_moves_a_live_worker_to_a_fresh_exact_table_generation;
%     commit=39092863ae34184a9f955f185ff57c1ff177ec40].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_memo/lib_memo.pl')).

% The eviction test drives the store against a tiny budget, so it has to move
% the limits. Both are dynamic predicates carrying a default fact, and a
% cleanup that only retracts leaves them with no clause at all: every later
% cache write then fails on the missing limit and the function answers
% nothing. Save the value and put it back.

memo_setting(memo_size_limit).
memo_setting(metta_memo_total_bytes).
memo_setting(memo_answer_limit).
memo_setting(memo_aggregate_mode).
memo_setting(memo_float_precision).

%lib_memo: and not user:. The five settings are lib/lib_memo/lib_memo.pl's own
%dynamic predicates, which live in that library's module now; asserting them in
%`user` would build a second set of facts the library never reads, and the
%eviction tests would drive the shipped defaults instead of these
%[tested: memo_eviction_output; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
memo_setting_save :-
    forall(memo_setting(Name),
           ( Fact =.. [Name, Value],
             lib_memo:Fact,
             atom_concat('$memo_plt_', Name, Key),
             nb_setval(Key, Value) )).

memo_setting_restore :-
    forall(memo_setting(Name),
           ( atom_concat('$memo_plt_', Name, Key),
             nb_getval(Key, Value),
             Wild =.. [Name, _],
             retractall(lib_memo:Wild),
             Fact =.. [Name, Value],
             assertz(lib_memo:Fact) )).

memo_setting_override(Name, Value) :-
    Wild =.. [Name, _],
    retractall(lib_memo:Wild),
    Fact =.. [Name, Value],
    assertz(lib_memo:Fact).

:- begin_tests(memo_eviction_output,
               [ setup((memo_setting_save,
                        memo_setting_override(memo_size_limit, 100),
                        memo_setting_override(metta_memo_total_bytes, 100),
                        assertz(lib_memo:metta_memo_head(test_fun, user, 1, 0)),
                        assertz(lib_memo:metta_memo_tail(test_fun, user, 1, 1)),
                        assertz(lib_memo:metta_memo_count(test_fun, user, 1, 1)),
                        assertz(lib_memo:metta_memo_q(test_fun, user, 1, 1, [key])),
                        assertz(lib_memo:metta_memo_entry(test_fun, user, 1, 0,
                                                      [key], [value])))),
                 cleanup((memo_setting_restore,
                          retractall(lib_memo:metta_memo_head(test_fun, user, 1, _)),
                          retractall(lib_memo:metta_memo_tail(test_fun, user, 1, _)),
                          retractall(lib_memo:metta_memo_count(test_fun, user, 1, _)),
                          retractall(lib_memo:metta_memo_q(test_fun, user, 1, _, _)),
                          retractall(lib_memo:metta_memo_entry(test_fun, user, 1, _, _, _))))
               ]).

capture_user_error(Goal, Text) :-
    new_memory_file(Memory),
    setup_call_cleanup(
        open_memory_file(Memory, write, ErrorStream),
        ( current_input(Input),
          current_output(Output),
          stream_property(OriginalError, alias(user_error)),
          setup_call_cleanup(
              set_prolog_IO(Input, Output, ErrorStream),
              call(Goal),
              set_prolog_IO(Input, Output, OriginalError)) ),
        close(ErrorStream)),
    memory_file_to_string(Memory, Text),
    free_memory_file(Memory).

test(routine_eviction_is_silent) :-
    capture_user_error(lib_memo:evict_global_space(1), Output),
    Output == "",
    \+ lib_memo:metta_memo_entry(test_fun, user, 1, _, [key], _).

:- end_tests(memo_eviction_output).

% Two spaces defining one name hold two functions. Before the cache carried
% the module, enabling memoization in either space enabled it in both, one
% cache served both, and each space answered with the other's equation too.

:- begin_tests(memo_space_isolation,
               [ setup(memo_iso_define),
                 cleanup(memo_iso_forget) ]).

memo_iso_equation('&self', "(= (isocalc $x) (+ $x 100))").
memo_iso_equation('&memo_iso', "(= (isocalc $x) (+ $x 900))").

memo_iso_shared("(= (isoshared $x) (+ $x 7))").

memo_iso_define :-
    forall(memo_iso_equation(Space, Text),
           ( sread(Text, Term), 'add-atom'(Space, Term, _) )).

memo_iso_forget :-
    memo_iso_reset,
    forall(memo_iso_equation(Space, Text),
           ( sread(Text, Term), 'remove-atom'(Space, Term, _) )).

memo_iso_reset :-
    lib_memo:disable_memoization(isocalc),
    lib_memo:cache_clear.

%Every answer the space gives for (isocalc 2), read through the module its
%equations were compiled into.
memo_iso_answers(Space, Answers) :-
    space_module(Space, Module),
    findall(R, with_metta_module(Module, reduce([isocalc, 2], R)), Answers).

memo_iso_memoize(Space) :-
    space_module(Space, Module),
    with_metta_module(Module, user:'memoize'(isocalc, true)).

memo_iso_reports(Space, Reported) :-
    space_module(Space, Module),
    with_metta_module(Module, user:'is-memoized'(isocalc, Reported)).

test(each_space_answers_with_its_own_equation,
     [ cleanup(memo_iso_reset) ]) :-
    memo_iso_answers('&self', [102]),
    memo_iso_answers('&memo_iso', [902]).

test(memoizing_one_space_leaves_the_other_unchanged,
     [ cleanup(memo_iso_reset) ]) :-
    memo_iso_memoize('&self'),
    memo_iso_answers('&self', [102]),
    memo_iso_answers('&memo_iso', [902]),
    memo_iso_answers('&self', [102]),
    memo_iso_answers('&memo_iso', [902]).

test(memoizing_both_spaces_keeps_two_caches,
     [ cleanup(memo_iso_reset) ]) :-
    memo_iso_memoize('&self'),
    memo_iso_memoize('&memo_iso'),
    memo_iso_answers('&self', [102]),
    memo_iso_answers('&memo_iso', [902]),
    memo_iso_answers('&self', [102]),
    memo_iso_answers('&memo_iso', [902]).

test(is_memoized_answers_for_the_asking_space,
     [ cleanup(memo_iso_reset) ]) :-
    memo_iso_memoize('&self'),
    memo_iso_reports('&self', true),
    memo_iso_reports('&memo_iso', false).

%A shared function is one function: a space that only inherits &self's
%equations caches under &self, so it neither duplicates the cache nor
%reports itself separately memoized.
test(an_inheriting_space_shares_the_one_cache,
     [ setup(( memo_iso_shared(SetupText),
               sread(SetupText, SetupTerm),
               'add-atom'('&self', SetupTerm, _) )),
       cleanup(( memo_iso_reset,
                 lib_memo:disable_memoization(isoshared),
                 memo_iso_shared(CleanupText),
                 sread(CleanupText, CleanupTerm),
                 'remove-atom'('&self', CleanupTerm, _) )) ]) :-
    space_module('&memo_iso', Module),
    with_metta_module(Module, user:'memoize'(isoshared, true)),
    with_metta_module(Module, user:'is-memoized'(isoshared, true)),
    metta_self_module(Self),
    with_metta_module(Self, user:'is-memoized'(isoshared, true)),
    findall(R, with_metta_module(Module, reduce([isoshared, 1], R)), [8]),
    findall(R, with_metta_module(Self, reduce([isoshared, 1], R)), [8]).

%WHERE A DECLARATION LANDS, all four branches of the rule, because only the
%last one moved and a test that pins one branch cannot say the others held.
%A declaration may PRECEDE the equations it governs, which is how the
%aggregate example writes it: !(memoize choices) and then the three
%(= (choices $x) ...) alternatives. The rule used to fall back to &self
%whenever the speaking module held no equations for the name YET, so a
%forward declaration from a space landed in a module the program never wrote
%to, and the definitions then compiled into the speaking one.
test(a_declaration_lands_in_the_module_that_is_speaking,
     [ setup(( memo_iso_shared(Text),
               sread(Text, Term),
               'add-atom'('&self', Term, _) )),
       cleanup(( memo_iso_shared(CleanupText),
                 sread(CleanupText, CleanupTerm),
                 'remove-atom'('&self', CleanupTerm, _) )) ]) :-
    space_module('&memo_iso', Iso),
    metta_self_module(Self),
    Iso \== Self,
    %&self speaking about its own function: &self.
    with_metta_module(Self, lib_memo:memo_scope_module(isocalc, HomeSaysHome)),
    %A space speaking about a function IT defines: itself.
    with_metta_module(Iso, lib_memo:memo_scope_module(isocalc, IsoSaysIso)),
    %A space speaking about a function only &self defines: &self, which is
    %the case the fallback exists for and the one an inheriting space needs.
    with_metta_module(Iso, lib_memo:memo_scope_module(isoshared, IsoSaysHome)),
    %A space speaking about a name neither module defines yet: itself. This
    %is the forward declaration, and this branch is the one that moved.
    with_metta_module(Iso, lib_memo:memo_scope_module(isoforward, IsoSaysForward)),
    HomeSaysHome == Self,
    IsoSaysIso == Iso,
    IsoSaysHome == Self,
    IsoSaysForward == Iso.

%The forward-declaration branch above is the COMMON one, because a declaration
%may precede the definitions it governs, and asking about a name nothing has
%compiled yet with imported_from/1 ran SWI's undefined-procedure trap: it
%searches the whole autoload library index before raising the existence error
%memo_owner_module/4 discards. 1,033 inferences against 10 for a name the
%space inherits [measured 2026-09-06; commit=693b1bdb6ed06cd0ba01e901a8a6d774bc733d19]. A RATIO rather than a
%count, because the honest number moves a few inferences with clause layout,
%and ten rather than four because the plunit lane runs under
%tests/prolog/lock_order.pl, which costs about twenty inferences per mutex
%acquisition and the missing path takes mutexes the present one does not
%[measured 2026-09-13: missing 73 against present 12 under the recorder;
%command=sh engine/test.sh suites/libraries/lib_memo.plt; commit=WORKTREE].
%The hundredfold search this bound exists to catch is two orders away either way.
test(asking_who_owns_an_undefined_name_costs_what_asking_about_an_inherited_one_costs) :-
    space_module('&memo_iso', Iso),
    assertion(\+ current_predicate(Iso:'plunit-memo-no-such-name'/2)),
    memo_owner_cost('car-atom', Iso, 2, Present),
    memo_owner_cost('plunit-memo-no-such-name', Iso, 2, Missing),
    assertion(Missing =< 10 * Present).

memo_owner_cost(Fun, Module, PredArity, Per) :-
    Rounds = 1000,
    statistics(inferences, Before),
    forall(between(1, Rounds, _),
           ( memo_owner_module(Fun, Module, PredArity, _) -> true ; true )),
    statistics(inferences, After),
    Per is (After - Before - 3 * Rounds) // Rounds.

%A released table is the case the invalidation sweep is written for -- space
%teardown untables before removing equations, so by the time invalidation runs
%there is nothing left to clear. tabled/0 is one of the properties SWI answers
%by running its undefined-procedure trap, which searches the whole autoload
%library index before raising the existence error, so learning "already gone"
%cost 1,030 inferences against 8 for a name the module has
%[measured 2026-09-06; commit=693b1bdb6ed06cd0ba01e901a8a6d774bc733d19]. A RATIO rather than a count, because
%the honest number moves a few inferences with clause layout.
test(clearing_a_table_that_is_already_gone_costs_what_clearing_a_present_name_costs) :-
    metta_engine_module(Engine),
    assertion(\+ current_predicate(Engine:'plunit-memo-released-table'/4)),
    assertion(lib_memo:reset_exact_memo_table(Engine, 'plunit-memo-released-table', 2)),
    reset_table_cost(Engine, 'car-atom', 0, Present),
    reset_table_cost(Engine, 'plunit-memo-released-table', 2, Missing),
    assertion(Missing =< 4 * Present).

reset_table_cost(Module, TableName, Arity, Per) :-
    Rounds = 500,
    statistics(inferences, Before),
    forall(between(1, Rounds, _),
           ( lib_memo:reset_exact_memo_table(Module, TableName, Arity)
           -> true ; true )),
    statistics(inferences, After),
    Per is (After - Before - 3 * Rounds) // Rounds.

:- end_tests(memo_space_isolation).


:- begin_tests(lib_memo_stats,
               [ setup(( memo_setting_save,
                         memo_setting_override(memo_answer_limit, 2),
                         memo_setting_override(memo_aggregate_mode, count),
                         memo_setting_override(memo_float_precision, 0),
                         filereader:process_metta_string(
                             "(= (plunit-exact-bag $x) a)\n(= (plunit-exact-bag $x) a)\n(= (plunit-exact-bag $x) b)",
                             _, '&plunit_exact_bag') )),
                 cleanup(( memo_setting_restore,
                           lib_memo:disable_memoization('plunit-exact-bag'),
                           lib_memo:cache_clear,
                           user:clear_native_atoms('&plunit_exact_bag'),
                           user:metta_release_space('&plunit_exact_bag') )) ]).

test(a_function_report_counts_answer_occurrences) :-
    space_module('&plunit_exact_bag', Module),
    with_metta_module(
        Module,
        lib_memo:memoize_exact('plunit-exact-bag')),
    findall(Answer,
            with_metta_module(
                Module,
                reduce(['plunit-exact-bag', 1.1], Answer)),
            First),
    msort(First, [a, a, b]),
    findall(Answer,
            with_metta_module(
                Module,
                reduce(['plunit-exact-bag', 1.2], Answer)),
            Second),
    msort(Second, [a, a, b]),
    with_metta_module(
        Module,
        user:'get-memoize-stats'('plunit-exact-bag', Stats)),
    assertion(Stats == [[entries, 2], [answers, 6]]).

plunit_exact_worker(Module, Requests, Replies) :-
    repeat,
    thread_get_message(Requests, Request),
    (   Request == query
    ->  findall(Answer,
                with_metta_module(
                    Module,
                    reduce(['plunit-exact-bag', 1.3], Answer)),
                Answers),
        thread_send_message(Replies, answers(Answers)),
        fail
    ;   Request == stop,
        !
    ).

test(invalidation_moves_a_live_worker_to_a_fresh_exact_table_generation,
     [ cleanup(catch(
           filereader:process_metta_string(
               "!(remove-atom &plunit_exact_bag (= (plunit-exact-bag $x) a))",
               _, '&plunit_exact_bag'), _, true)) ]) :-
    space_module('&plunit_exact_bag', Module),
    with_metta_module(Module,
                      lib_memo:memoize_exact('plunit-exact-bag')),
    setup_call_cleanup(
        ( message_queue_create(Requests),
          message_queue_create(Replies),
          thread_create(plunit_exact_worker(Module, Requests, Replies),
                        Worker, []) ),
        ( thread_send_message(Requests, query),
          thread_get_message(Replies, answers(First)),
          msort(First, [a, a, b]),
          filereader:process_metta_string(
              "!(add-atom &plunit_exact_bag (= (plunit-exact-bag $x) a))",
              _, '&plunit_exact_bag'),
          thread_send_message(Requests, query),
          thread_get_message(Replies, answers(Second)),
          msort(Second, [a, a, a, b]) ),
        ( thread_send_message(Requests, stop),
          thread_join(Worker, _),
          message_queue_destroy(Requests),
          message_queue_destroy(Replies) )).

:- end_tests(lib_memo_stats).


% Function-level memo nodes retain the safe over-approximation the old
% metta_memo_dep/6 table provided, but their edges now live in the common
% support graph and need no reverse-graph construction at invalidation time.
:- begin_tests(memo_support_graph,
               [ setup(memo_support_setup),
                 cleanup(memo_support_cleanup) ]).

memo_support_equation(
    "(= (plunit-memo-support-base $x) (+ $x 1))").
memo_support_equation(
    "(= (plunit-memo-support-middle $x) (plunit-memo-support-base $x))").
memo_support_equation(
    "(= (plunit-memo-support-derived $x) (plunit-memo-support-middle $x))").
memo_support_equation(
    "(= (plunit-memo-support-other $x) (+ $x 10))").

memo_support_name('plunit-memo-support-base').
memo_support_name('plunit-memo-support-middle').
memo_support_name('plunit-memo-support-derived').
memo_support_name('plunit-memo-support-other').

memo_support_setup :-
    retractall(silent(_)),
    assertz(silent(true)),
    forall(memo_support_equation(Text), process_metta_string(Text, _)),
    metta_self_module(Module),
    % Memoize callers before callees. Recompiling a callee then repairs its
    % callers through the graph, so every nested call reaches the memo door.
    forall(member(Name,
                  ['plunit-memo-support-derived',
                   'plunit-memo-support-middle',
                   'plunit-memo-support-base',
                   'plunit-memo-support-other']),
           with_metta_module(Module, 'memoize'(Name, true))).

memo_support_cleanup :-
    cache_clear,
    forall(memo_support_name(Name), disable_memoization(Name)),
    forall(memo_support_equation(Text),
           ( sread(Text, Term),
             ( metta_remove_atom('&self', Term, _) -> true ; true ) )),
    retractall(silent(_)),
    assertz(silent(false)).

test(a_leaf_change_invalidates_transitive_callers_only) :-
    metta_self_module(Module),
    findall(R,
            with_metta_module(Module,
                              reduce(['plunit-memo-support-derived', 1], R)),
            [2]),
    findall(R,
            with_metta_module(Module,
                              reduce(['plunit-memo-support-other', 1], R)),
            [11]),
    assertion(lib_memo:metta_memo_entry('plunit-memo-support-derived', Module,
                               _, _, _, _)),
    assertion(lib_memo:metta_memo_entry('plunit-memo-support-other', Module,
                               _, _, _, _)),
    sread("(= (plunit-memo-support-base $x) (+ $x 1))", Base),
    metta_remove_atom('&self', Base, true),
    assertion(\+ lib_memo:metta_memo_entry('plunit-memo-support-base', Module,
                                  _, _, _, _)),
    assertion(\+ lib_memo:metta_memo_entry('plunit-memo-support-middle', Module,
                                  _, _, _, _)),
    assertion(\+ lib_memo:metta_memo_entry('plunit-memo-support-derived', Module,
                                  _, _, _, _)),
    assertion(lib_memo:metta_memo_entry('plunit-memo-support-other', Module,
                               _, _, _, _)).

:- end_tests(memo_support_graph).


% WHOSE QUESTION IT IS. `(memoize f)` is the developer saying what they want
% done with their own program, and this library's job is to do it. It used to
% answer back on five grounds -- a library's (volatility f volatile) export, a
% declared or annotated effect class, an effect walk over the body, a space
% read anywhere in it, and an annotation arriving while a cache was live -- and
% every one of them judged whether the developer should have asked. A cache put
% somewhere it does not belong is a bug in the program that put it there
% (user ruling, 2026-09-06). These pin the acceptances that replaced them, and
% the one refusal left, which is not about the body at all.
:- begin_tests(lib_memo_volatility).

user:plunit_memo_volatile(X, X).
user:plunit_memo_pure(X, X).

test(a_volatile_function_still_memoizes_on_the_declaration,
     [ setup(( import_prolog_function(plunit_memo_volatile, _),
               metta_engine:declare_function_volatility(plunit_memo_volatile, volatile) )),
       cleanup(( retractall(user:metta_function_volatility(plunit_memo_volatile, _)),
                 catch('clear-memoize'(plunit_memo_volatile, _), _, true),
                 release_function_name(plunit_memo_volatile),
                 unregister_fun_everywhere(plunit_memo_volatile),
                 retractall(user:fun(plunit_memo_volatile)),
                 retractall(user:arity(plunit_memo_volatile, _)) )) ]) :-
    assertion(\+ metta_function_cacheable(plunit_memo_volatile)),
    'memoize'(plunit_memo_volatile, true).

test(an_undeclared_function_still_memoizes,
     [ setup(import_prolog_function(plunit_memo_pure, _)),
       cleanup(( catch('clear-memoize'(plunit_memo_pure, _), _, true),
                 release_function_name(plunit_memo_pure),
                 unregister_fun_everywhere(plunit_memo_pure),
                 retractall(user:fun(plunit_memo_pure)),
                 retractall(user:arity(plunit_memo_pure, _)) )) ]) :-
    assertion(metta_function_cacheable(plunit_memo_pure)),
    'memoize'(plunit_memo_pure, true).

%The body prints. Nothing above it says anything, and the declaration alone
%carries it; it used to need (cache plunit-memo-impure unchecked) beside it.
test(a_declaration_memoizes_an_impure_body,
     [ setup(process_metta_string(
                 "(= (plunit-memo-impure $k) (let $i (println! $k) $k))", _)),
       cleanup(catch('clear-memoize'('plunit-memo-impure', _), _, true)) ]) :-
    'memoize'('plunit-memo-impure', true),
    assertion('is-memoized'('plunit-memo-impure', true)).

%A body that READS a space, which memoization cannot invalidate on: the cache
%outlives the atoms it was computed from, and that is the caller's own trade
%rather than something to refuse.
test(a_declaration_memoizes_a_space_reading_body,
     [ setup(process_metta_string(
                 "(plunit-memo-fact 1) \c
                  (= (plunit-memo-reader $k) \c
                     (match &self (plunit-memo-fact $v) $v))", _)),
       cleanup(catch('clear-memoize'('plunit-memo-reader', _), _, true)) ]) :-
    'memoize'('plunit-memo-reader', true),
    assertion('is-memoized'('plunit-memo-reader', true)).

test(an_immutable_function_memoizes,
     [ setup(( import_prolog_function(plunit_memo_pure, _),
               metta_engine:declare_function_volatility(plunit_memo_pure, immutable) )),
       cleanup(( retractall(user:metta_function_volatility(plunit_memo_pure, _)),
                 catch('clear-memoize'(plunit_memo_pure, _), _, true),
                 release_function_name(plunit_memo_pure),
                 unregister_fun_everywhere(plunit_memo_pure),
                 retractall(user:fun(plunit_memo_pure)),
                 retractall(user:arity(plunit_memo_pure, _)) )) ]) :-
    'memoize'(plunit_memo_pure, true).

%The refusal that stays, and its ground is a mechanism rather than a judgement:
%a name no function answers to has no equations to recompile and no predicate
%to dispatch, so there is nothing a cache could be put on.
test(a_name_that_is_not_a_function_is_still_refused,
     [ throws(error(domain_error(function_symbol,
                                 'plunit-memo-nosuchname'), _)) ]) :-
    'memoize'('plunit-memo-nosuchname', true).

:- end_tests(lib_memo_volatility).

% WHAT THE DECLARATION HAS TO REACH. Both cases below were admitted and then did
% nothing, and both for one reason: the declaration was recorded in the module
% that was SPEAKING while every call is keyed by the module that owns the
% clauses. When the speaking space is also the owner they agree, which is why
% the ordinary case worked and these did not.
:- begin_tests(lib_memo_reach).

:- dynamic user:plunit_memo_op_runs/1.
user:plunit_memo_op_impl(X, Y) :-
    ( retract(user:plunit_memo_op_runs(N0)) -> true ; N0 = 0 ),
    N1 is N0 + 1,
    assertz(user:plunit_memo_op_runs(N1)),
    Y is X + 0.

%A registered operation is ONE predicate imported into every space's execution
%module. It has no equations, so nothing of its own is recompiled and its call
%sites are its CALLERS' bodies; and its calls are keyed by the module that
%registered it, not by the space that spoke. Both halves were wrong: the
%declaration landed in the speaking space, where no call ever looked, and the
%caller kept the direct goal it was compiled with. `memoize-exact` answered
%true, `is-memoized` answered true, and the operation ran on every call.
test(memoizing_an_operation_reaches_a_caller_compiled_before_it,
     [ setup(( retractall(user:plunit_memo_op_runs(_)),
               import_prolog_function(plunit_memo_op_impl, _) )),
       cleanup(( catch('clear-memoize'(plunit_memo_op_impl, _), _, true),
                 catch(disable_memoization(plunit_memo_op_impl), _, true),
                 retractall(user:plunit_memo_op_runs(_)),
                 release_function_name(plunit_memo_op_impl),
                 unregister_fun_everywhere(plunit_memo_op_impl),
                 retractall(user:fun(plunit_memo_op_impl)),
                 retractall(user:arity(plunit_memo_op_impl, _)),
                 catch('remove-atom'('&self',
                                     [=, ['plunit-memo-op-caller', _],
                                      [plunit_memo_op_impl, _]], _), _, true) )) ]) :-
    %The caller is compiled BEFORE the declaration, which is the case the wide
    %recompile door exists for.
    process_metta_string(
        "(= (plunit-memo-op-caller $k) (plunit_memo_op_impl $k))", _),
    process_metta_string("!(plunit-memo-op-caller 1)", _),
    'memoize-exact'(plunit_memo_op_impl, true),

    %The declaration lands where the calls look, which is the module that
    %registered the operation and not the space that spoke.
    metta_self_module(Self),
    memo_owner_module(plunit_memo_op_impl, Self, 2, Owner),
    assertion(lib_memo:memo_enabled(plunit_memo_op_impl, Owner, exact)),
    assertion(lib_memo:memoization_enabled_for_call(plunit_memo_op_impl, Owner, 1)),

    %The caller compiled before it now dispatches through the cache.
    functor(Head, 'plunit-memo-op-caller', 2),
    clause(Self:Head, Body),
    assertion(( sub_term(Sub, Body), nonvar(Sub), Sub = cache_call(_, _, _, _) )),

    %And the cache SERVES: two calls, one run of the operation.
    retractall(user:plunit_memo_op_runs(_)),
    process_metta_string("!(plunit-memo-op-caller 2)", First),
    process_metta_string("!(plunit-memo-op-caller 2)", Second),
    assertion(First == [2]),
    assertion(Second == [2]),
    assertion(user:plunit_memo_op_runs(1)).

%THE ROUND TRIP THAT DUPLICATED AN EQUATION. Enabling used to remove each
%stored equation and add it back around the enable, which is not the same term:
%the source says (add-atom &self ...) and the retained form the compiler kept
%carries the space's RESOLVED name, so the removal matched nothing and the add
%left a second copy. The function then had two clauses, wrote twice and answered
%a doubled bag on its first call.
%
%Through metta_host_run_source/4 and a NAMED space, which is what makes the two
%forms differ. Written into &self the source name and the resolved name are the
%same word and nothing duplicates, which is why this went unseen from the
%suite's own space; the stored form below says &self and the retained one says
%&memo_reach.
test(a_body_that_writes_its_own_space_is_not_duplicated_by_memoize,
     [ cleanup(( space_module('&memo_reach', M),
                 with_metta_module(M,
                     ( catch('clear-memoize'('memo-reach-writer', _), _, true),
                       catch(disable_memoization('memo-reach-writer'), _, true) )),
                 forall(metta_host_stored('&memo_reach', ['memo-reach-wrote', K]),
                        catch('remove-atom'('&memo_reach',
                                            ['memo-reach-wrote', K], _), _, true)),
                 forall(metta_host_stored('&memo_reach',
                                          [=, ['memo-reach-writer'|Args], Body]),
                        catch('remove-atom'('&memo_reach',
                                            [=, ['memo-reach-writer'|Args], Body],
                                            _), _, true)) )) ]) :-
    metta_host_run_source(
        "(= (memo-reach-writer $k) \c
           (let $i (add-atom &self (memo-reach-wrote $k)) $k))",
        '&memo_reach', [], _),
    metta_host_run_source("!(memo-reach-writer 1)", '&memo_reach', [], _),
    space_module('&memo_reach', Module),
    functor(Head, 'memo-reach-writer', 2),
    aggregate_all(count, clause(Module:Head, _), Before),
    %The premise: the two forms of this equation really do differ, which is
    %what the removal used to miss.
    findall(Retained, memo_equation('memo-reach-writer', Module, any, Retained),
            [[=, _, RetainedBody]]),
    findall(StoredBody,
            metta_host_stored('&memo_reach',
                              [=, ['memo-reach-writer'|_], StoredBody]),
            [SoleStored]),
    assertion(\+ RetainedBody =@= SoleStored),

    with_metta_module(Module, 'memoize'('memo-reach-writer', true)),
    aggregate_all(count, clause(Module:Head, _), After),
    assertion(After == Before),
    findall(Body,
            metta_host_stored('&memo_reach',
                              [=, ['memo-reach-writer'|_], Body]),
            Equations),
    assertion(Equations = [_]),

    %One run of the body on a miss, one write, one answer, and the second call
    %is a hit that writes nothing. The 1 is the uncached warm-up above.
    metta_host_run_source("!(memo-reach-writer 7)", '&memo_reach', [], First),
    metta_host_run_source("!(memo-reach-writer 7)", '&memo_reach', [], Second),
    assertion(memo_reach_answers(First, [7])),
    assertion(memo_reach_answers(Second, [7])),
    findall(K, metta_host_stored('&memo_reach', ['memo-reach-wrote', K]), Wrote),
    assertion(Wrote == [1, 7]).

%One directive's answers, without the name state the host door carries.
memo_reach_answers([Group], Answers) :-
    findall(Term, member('$metta_answer'(Term, _), Group), Answers).

:- end_tests(lib_memo_reach).

%The catalog's two profitability overrides are covered from Python, but every
%function they are declared on there is recursive
%[source: extensions/python/tests/ch18_performance/test_automatic_tabling.py
%test_automatic_cache_force_and_refuse_overrides, and the same in
%test_an_impure_function_is_never_cached_automatically,
%test_automatic_caching_preserves_multiplicity_and_answer_limit and
%test_cache_decorator]. A recursive name is already a component of the
%source-call graph and arrives through those, so the branch that collects a
%declaration on a name the graph does NOT hold, OverrideFuns in
%memo_automatic_module_plan/2, runs empty in all of them. It is the branch this
%unit is for.
:- begin_tests(memo_cache_override).

forget_cache_override(Fun, Mode) :-
    catch('remove-atom'('&metta', [cache, Fun, Mode], _), _, true).

cache_explanation(Fun, Choice-Reason) :-
    (   seam:automatic_cache_explanation(Fun, Choice, Reason)
    ->  true
    ;   Choice-Reason = none-none
    ).

%Both directions, because a decision that cannot be taken back is a leak
%rather than an override.
test(a_force_declaration_memoizes_a_function_that_calls_nothing,
     [ setup(process_metta_string(
                 "(= (plunit-memo-forced $x) (+ $x 1))", _)),
       cleanup(forget_cache_override('plunit-memo-forced', force)) ]) :-
    cache_explanation('plunit-memo-forced', Before),
    assertion(Before == declined-'not-recursive'),
    process_metta_string(
        "!(add-atom &metta (cache plunit-memo-forced force))", _),
    cache_explanation('plunit-memo-forced', Forced),
    assertion(Forced == forced-declaration),
    assertion(lib_memo:memo_automatic_enabled('plunit-memo-forced', _)),
    forget_cache_override('plunit-memo-forced', force),
    cache_explanation('plunit-memo-forced', After),
    assertion(After == declined-'not-recursive'),
    assertion(\+ lib_memo:memo_automatic_enabled('plunit-memo-forced', _)).

%Reconciliation runs once per source whose call graph changed, and finding the
%declarations used to enumerate every equation in the module and ask each name
%whether it carried one. Declarations are rare and equations are not, so the
%declarations drive now and one indexed probe confirms the name has an
%equation here. Cost of compiling a two-form source containing one source
%call, into a space already holding M unrelated equations [measured
%2026-08-23: 4,831 inferences at M=200 and 37,831 at M=3,200, exactly 11.0 an
%equation, and 2,615 at both after].
plunit_bulk_equations(M, Text) :-
    findall(Line,
            ( between(1, M, I),
              format(atom(Line), "(= (plunit_memo_bulk_b~w) ~w)~n", [I, I]) ),
            Lines),
    atomics_to_string(Lines, Text).

reconcile_cost(M, Cost) :-
    Space = '&plunit_memo_reconcile',
    plunit_bulk_equations(M, Bulk),
    setup_call_cleanup(
        assertz(user:silent(true), SilentRef),
        setup_call_cleanup(
            filereader:process_metta_string(Bulk, _, Space),
            ( statistics(inferences, Before),
              filereader:process_metta_string(
                  "(= (plunit_memo_gee $x) (quote $x))\n(= (plunit_memo_use) (plunit_memo_gee k0))\n",
                  _, Space),
              statistics(inferences, After),
              Cost is After - Before ),
            ( user:clear_native_atoms(Space),
              user:metta_release_space(Space) )),
        erase(SilentRef)).

test(reconciling_a_source_costs_nothing_that_grows_with_the_module) :-
    reconcile_cost(100, Narrow),
    reconcile_cost(1600, Wide),
    assertion(Wide < Narrow * 2).

:- end_tests(memo_cache_override).

%The one TIMED test in the tree, and it has to be. Every caller of
%memo_equation/4 binds the function name, and the store it reads keys on the
%whole source term, so the lookup either takes the deep index or walks every
%equation in the engine. The inference counter cannot tell those apart: a
%candidate rejected by head unification sends the VM to shallow_backtrack,
%which asks for the next clause and resumes without raising the counter
%[source: SWI-Prolog src/pl-vmi.c, VMH(shallow_backtrack) against
%VMH(depart_or_retry_continue); V10.1.13, upstream commit
%fc7ef84b949378b729052c3ade79c90ce5416abb], so the walk reads THREE inferences
%at 20 clauses and three at 20,000. prolog_trace_interception/4 does see it,
%one call of translated_from/2 with 19 redos against one with none at 20
%clauses, but plunit meta-calls its test bodies and cannot trace them.
%
%CPU time is the instrument that is left, and it is safe at this margin:
%process CPU time does not move with machine load, both readings come from one
%process, and the walk measures 17.4x for a 16x module where the index
%measures 1.2 [measured 2026-08-23: 20,000 lookups cost 0.145s at M=200 and
%2.523s at M=3,200 before, 0.009s and 0.012s after].
:- begin_tests(memo_equation_lookup).

plunit_lookup_equations(M, Text) :-
    findall(Line,
            ( between(1, M, I),
              format(atom(Line), "(= (plunit_lookup_b~w) ~w)~n", [I, I]) ),
            Lines),
    atomics_to_string(Lines, Text).

%The first lookup builds the index, so it is spent before the clock starts.
lookup_cputime(M, Reps, Seconds) :-
    atom_concat('&plunit_memo_lookup_', M, Space),
    plunit_lookup_equations(M, Bulk),
    setup_call_cleanup(
        assertz(user:silent(true), SilentRef),
        setup_call_cleanup(
            ( filereader:process_metta_string(Bulk, _, Space),
              filereader:process_metta_string(
                  "(= (plunit_lookup_target $x) 7)\n", _, Space) ),
            ( user:metta_module_space(Module, Space),
              !,
              ( lib_memo:memo_equation(plunit_lookup_target, Module, any, _)
                -> true ; true ),
              statistics(cputime, T0),
              forall(between(1, Reps, _),
                     ( lib_memo:memo_equation(plunit_lookup_target, Module,
                                              any, _)
                       -> true ; true )),
              statistics(cputime, T1),
              Seconds is T1 - T0 ),
            ( user:clear_native_atoms(Space),
              user:metta_release_space(Space) )),
        erase(SilentRef)).

%Inferences cannot decide this one: the walk being priced is a C-level
%clause scan the counter never sees, which is why the measure is cputime.
%One sample per side failed at load average 35 with sibling batteries
%running (2026-08-24: 6.1s wide sample against a quiet-box 2.9s), so the
%sides interleave and each takes its minimum, the same protocol the push
%gate uses against contention smear.
test(one_head_is_found_without_walking_the_other_equations) :-
    lookup_cputime(200, 20000, N1), lookup_cputime(3200, 20000, W1),
    lookup_cputime(200, 20000, N2), lookup_cputime(3200, 20000, W2),
    lookup_cputime(200, 20000, N3), lookup_cputime(3200, 20000, W3),
    Narrow is min(N1, min(N2, N3)),
    Wide is min(W1, min(W2, W3)),
    assertion(Wide < Narrow * 4).

:- end_tests(memo_equation_lookup).

% A worker thread that only ever HITS still records what it sees. The cache is
% shared and the sketch is not, so this is the arm that used to record nothing.
:- begin_tests(memo_admission_sketch).

test(a_hit_only_thread_records_its_own_frequency) :-
    %metta_memo_entry/6 is `dynamic`, so the cache is SHARED across threads,
    %while the sketch lives in nb_setval and is THREAD-LOCAL. A worker reading a
    %cache another thread warmed therefore hits constantly and misses never, and
    %record_hit/4 used to require a sketch that only record_miss/4 ever built:
    %it fell to its `; true` arm and recorded nothing, for ever. Measured then:
    %main 1 miss and 20 hits reported 21, the worker 20 hits reported 0.
    lib_memo:record_miss(sketchfn, user, 1, [a]),
    forall(between(1, 20, _), lib_memo:record_hit(sketchfn, user, 1, [a])),
    lib_memo:get_freq(sketchfn, user, 1, [a], MainFreq),
    assertion(MainFreq >= 20),
    message_queue_create(Answer),
    thread_create(
        ( forall(between(1, 20, _), lib_memo:record_hit(sketchfn, user, 1, [a])),
          ( catch(lib_memo:get_freq(sketchfn, user, 1, [a], WorkerFreq), _, fail)
          -> true
          ;  WorkerFreq = failed ),
          thread_send_message(Answer, WorkerFreq) ),
        Worker, []),
    thread_join(Worker),
    thread_get_message(Answer, Seen),
    message_queue_destroy(Answer),
    assertion(integer(Seen)),
    assertion(Seen >= 20).

:- end_tests(memo_admission_sketch).

:- begin_tests(memo_reconciliation_interrupt).

clean_reconciliation_fixture :-
    retractall(lib_memo:memo_automatic_dirty('$plunit_memo_interrupt')),
    retractall(lib_memo:memo_automatic_decision(_, '$plunit_memo_interrupt', _, _)),
    nb_delete('$metta_memo_reconciling').

prepare_reconciliation :-
    retractall(lib_memo:memo_automatic_decision(_, '$plunit_memo_interrupt', _, _)),
    assertz(lib_memo:memo_automatic_decision(stale, '$plunit_memo_interrupt',
                                           declined, stale)),
    lib_memo:memo_automatic_mark_dirty('$plunit_memo_interrupt').

sweep_reconciliation(Budget, Initial, Completed) :-
    ( Initial == unset -> nb_delete('$metta_memo_reconciling')
    ; nb_setval('$metta_memo_reconciling', false) ),
    prepare_reconciliation,
    call_with_inference_limit(lib_memo:memo_automatic_reconcile_dirty,
                              Budget, Result),
    assertion(\+ nb_current('$metta_memo_reconciling', true)),
    % A clear marker alone is insufficient: the next drain must replace a
    % stale decision with the empty module's actual plan.
    prepare_reconciliation,
    lib_memo:memo_automatic_reconcile_dirty,
    assertion(\+ lib_memo:memo_automatic_dirty('$plunit_memo_interrupt')),
    assertion(\+ lib_memo:memo_automatic_decision(_, '$plunit_memo_interrupt', _, _)),
    ( Result == inference_limit_exceeded
    -> Next is Budget + 1,
       sweep_reconciliation(Next, Initial, Completed)
    ; Completed = Budget ).

test(every_budget_restores_the_guard,
     [ forall(member(Initial, [unset, false])),
       setup(clean_reconciliation_fixture),
       cleanup(clean_reconciliation_fixture) ]) :-
    sweep_reconciliation(1, Initial, Completed),
    assertion(Completed > 1),
    assertion(\+ nb_current('$metta_memo_reconciling', true)).

:- end_tests(memo_reconciliation_interrupt).
