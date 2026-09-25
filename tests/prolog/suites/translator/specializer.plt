% Purpose: verify higher-order specialization keys, per-clause bindings, and
%   recursive folding directly against generated Prolog clauses.
% Guarantees: a copied specialization compiles before its native call is
%   emitted, including when an earlier definition retains erased clauses
%   [tested: specializer_invalidation:a_copied_specialization_materializes_before_its_call;
%   commit=540eb6ad437efe08b343e6b86e89ac7dcb63ffee].
% Guarantees: a named-space specialization inherits only declarations that
%   govern its local source function [tested:
%   specializer_invalidation:an_untyped_local_shadow_does_not_type_its_specialization;
%   commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c].
% Guarantees:
%   - the name minter preserves established writable spellings and encodes a
%     structured key when its display spelling is not one MeTTa symbol
%     [tested: specializer:specialization_names_are_writable_and_stable;
%     commit=5d93a44cf4820717163bbf8dfaf667ae14e5e4ee].
%   - the plan's argument walk costs no metacall per position, so a call
%     argument's size prices only the graft
%     [tested: specializer:the_argument_walk_makes_no_metacall_per_position;
%     commit=7e7cac85fee08c117032b2efa5a58a40f3b21365].
%   - substituting a registered nullary application into a specialization
%     keeps the clone at the generic call's arity and returns the partial value
%     [tested: specializer:a_specialization_keeps_the_generic_call_arity;
%     commit=1aebfc7b41e7d89893903a3a5f614e5b7c7f8eac].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(specializer).

set_specializer_test_mode :-
    retractall(silent(_)),
    assertz(silent(true)).

cleanup_specializer_symbols(Names) :-
    metta_self_module(Module),
    forall(member(Name, Names),
           ( specializer:invalidate_specializations(Module, Name),
             specializer:forget_symbol(Module, Name) )),
    retractall(silent(_)),
    assertz(silent(false)).

load_specializer_regression(File, Results) :-
    directory_file_path('../fixtures', File, Path),
    load_metta_file(Path, Results).

setup_concurrent_specialization :-
    set_specializer_test_mode,
    process_metta_string("\n
(= (plunit-spec-race-inc $x) (+ $x 1))\n
(= (plunit-spec-race $f $x) ($f $x))\n
", _).

cleanup_concurrent_specialization :-
    cleanup_specializer_symbols(
        ['plunit-spec-race', 'plunit-spec-race-inc']).

run_concurrent_specialization(_) :-
    translate_expr(
        ['plunit-spec-race', 'plunit-spec-race-inc', 1], Goals, Out),
    translator:goals_list_to_conj(Goals, Goal),
    %A specialization is compiled into the module of the space whose code
    %triggered it, so a test that calls or reads it has to name that module.
    metta_self_module(Self),
    once(call(Self:Goal)),
    Out == 2.

test(concurrent_translation_creates_one_specialization,
     [ setup(setup_concurrent_specialization),
       cleanup(cleanup_concurrent_specialization) ]) :-
    concurrent_forall(between(1, 64, Worker),
                      run_concurrent_specialization(Worker),
                      [threads(64)]),
    findall(SpecName,
            ho_specialization(_, 'plunit-spec-race', SpecName),
            Specializations),
    Specializations = [SpecName],
    functor(Head, SpecName, 3),
    metta_self_module(Self),
    aggregate_all(count, clause(Self:Head, _), 1),
    aggregate_all(count,
                  get_native_atom('&self', [=, [SpecName|_], _]),
                  1).

setup_multiclause :-
    set_specializer_test_mode,
    process_metta_string("\n
(= (plunit-spec-inc $x) (+ $x 1))\n
(= (plunit-spec-t2 $f 0) ($f 100))\n
(= (plunit-spec-t2 $f $x) ($f ($f $x)))\n
", _),
    process_metta_string("!(plunit-spec-t2 plunit-spec-inc 5)", [7]).

cleanup_multiclause :-
    cleanup_specializer_symbols(['plunit-spec-t2', 'plunit-spec-inc']).

test(all_clauses_are_bound_independently,
     [setup(setup_multiclause), cleanup(cleanup_multiclause)]) :-
    ho_specialization(_, 'plunit-spec-t2', SpecName),
    SpecName == 'plunit-spec-t2_Spec_[plunit-spec-inc]',
    functor(Head, SpecName, 3),
    metta_self_module(Self),
    findall(Head-Body, clause(Self:Head, Body), Clauses),
    length(Clauses, 2),
    forall(member(ClauseHead-_, Clauses),
           arg(1, ClauseHead, 'plunit-spec-inc')),
    \+ ( member(_-ClauseBody, Clauses),
         sub_term(Reduce, ClauseBody),
         compound(Reduce),
         functor(Reduce, reduce, 2) ),
    process_metta_string("!(plunit-spec-t2 plunit-spec-inc 0)", [101, 2]).

setup_two_bindings :-
    set_specializer_test_mode,
    process_metta_string("\n
(= (plunit-spec-inc2 $x) (+ $x 1))\n
(= (plunit-spec-dbl2 $x) (* $x 2))\n
(= (plunit-spec-p2 $f $g 1) ($f 1))\n
(= (plunit-spec-p2 $f $g 2) ($g 2))\n
", _),
    process_metta_string(
        "!(plunit-spec-p2 plunit-spec-inc2 plunit-spec-dbl2 1)", [2]).

cleanup_two_bindings :-
    cleanup_specializer_symbols(
        ['plunit-spec-p2', 'plunit-spec-dbl2', 'plunit-spec-inc2']).

test(global_key_covers_every_specialized_argument_position,
    [setup(setup_two_bindings), cleanup(cleanup_two_bindings)]) :-
    ho_specialization(_, 'plunit-spec-p2', SpecName),
    specializer:specialization_name(
        'plunit-spec-p2',
        ['plunit-spec-inc2', 'plunit-spec-dbl2'],
        ExpectedName),
    SpecName == ExpectedName,
    parser:metta_symbol_writable(SpecName),
    functor(Head, SpecName, 4),
    metta_self_module(Self),
    findall(Body, clause(Self:Head, Body), Bodies),
    length(Bodies, 2),
    \+ ( member(Body, Bodies),
         sub_term(Reduce, Body),
         compound(Reduce),
         functor(Reduce, reduce, 2) ).

test(a_specialization_keeps_the_generic_call_arity,
     [ setup(( set_specializer_test_mode,
               process_metta_string(
                   "(: plunit-wrap-one (-> %Undefined% %Undefined%))\n\
(= (plunit-wrap-one $x) ($x))", _) )),
       cleanup(( metta_remove_atom(
                     '&self',
                     [':', 'plunit-wrap-one',
                      [->, '%Undefined%', '%Undefined%']], _),
                 cleanup_specializer_symbols(['plunit-wrap-one']) )) ]) :-
    process_metta_string("!(plunit-wrap-one plain)", [[plain]]),
    process_metta_string("!(plunit-wrap-one sleep)", [Partial]),
    assertion(Partial == partial(sleep, [])),
    metta_self_module(Module),
    ho_specialization(Module, 'plunit-wrap-one', SpecName),
    functor(Runnable, SpecName, 2),
    aggregate_all(count, clause(Module:Runnable, _), Clauses),
    assertion(Clauses == 1),
    functor(Widened, SpecName, 3),
    assertion(\+ clause(Module:Widened, _)).

setup_recursive :-
    set_specializer_test_mode,
    process_metta_string("\n
(= (plunit-spec-step $x) (+ $x 1))\n
(= (plunit-spec-rep $f 0 $x) $x)\n
(= (plunit-spec-rep $f $n $x)\n
   (if (> $n 0)\n
       (plunit-spec-rep $f (- $n 1) ($f $x))\n
       (empty)))\n
", _),
    process_metta_string("!(plunit-spec-rep plunit-spec-step 3 0)", [3]).

cleanup_recursive :-
    cleanup_specializer_symbols(['plunit-spec-rep', 'plunit-spec-step']).

test(exact_recursive_key_folds_to_specialized_predicate,
     [setup(setup_recursive), cleanup(cleanup_recursive)]) :-
    ho_specialization(_, 'plunit-spec-rep', SpecName),
    functor(Head, SpecName, 4),
    metta_self_module(Self),
    forall(clause(Self:Head, Body),
           \+ ( sub_term(GenericCall, Body),
                compound(GenericCall),
                functor(GenericCall, 'plunit-spec-rep', 4) )),
    Goal =.. [SpecName, 'plunit-spec-step', 1000, 0, Result],
    once(call(Self:Goal)),
    Result == 1000.

% The test above checks that the recursive step does not name the generic
% predicate. reduce/2 is the OTHER way back to it, at run time and under a
% functor the clause body never mentions, so the absence of one is a separate
% question. It is asked of the two-binding specialization at
% global_key_covers_every_specialized_argument_position and was asked of the
% recursive one nowhere.
%
% Measured 2026-08-18, min of three: the specialized predicate costs 8,004
% inferences over 1,000 steps against the generic path's 24,004, and 804
% against 2,404 over 100, so the saving is per step rather than one-off.
test(the_recursive_specialization_never_re_enters_the_reducer,
     [setup(setup_recursive), cleanup(cleanup_recursive)]) :-
    ho_specialization(_, 'plunit-spec-rep', SpecName),
    functor(Head, SpecName, 4),
    metta_self_module(Self),
    findall(Body, clause(Self:Head, Body), Bodies),
    %The base case and the recursive one. Counted rather than left open,
    %because "no clause holds a reduce/2" is vacuously true of a predicate
    %with no clauses, which is what a specialization that failed to publish
    %would leave behind.
    length(Bodies, 2),
    \+ ( member(Body, Bodies),
         sub_term(Reduce, Body),
         compound(Reduce),
         functor(Reduce, reduce, 2) ).

setup_failed_specialization_memo :-
    set_specializer_test_mode,
    load_specializer_regression(
        'repro1_failed_specialization_memo.metta', [1, 2, 3, 4, 5]).

cleanup_failed_specialization_memo :-
    cleanup_specializer_symbols([wrap, pass, wrap2, myfun]).

test(repeated_failed_specialization_is_recorded_once_per_function,
     [ setup(setup_failed_specialization_memo),
       cleanup(cleanup_failed_specialization_memo) ]) :-
    findall(F-Arity-Key,
            specializer:ho_specialization_failed(_, F, Arity, Key),
            Failures),
    Failures == [pass-3-[myfun], wrap-3-[myfun]].

setup_failed_specialization_chain :-
    set_specializer_test_mode,
    load_specializer_regression(
        'repro2_exponential_failed_specialization.metta', [1]).

cleanup_failed_specialization_chain :-
    findall(Name,
            ( between(1, 12, Index),
              atom_concat(f, Index, Name) ),
            Functions),
    append(Functions, [g, myfun], Names),
    cleanup_specializer_symbols(Names).

test(branching_failed_specialization_is_linear_in_chain_depth,
     [ setup(setup_failed_specialization_chain),
       cleanup(cleanup_failed_specialization_chain) ]) :-
    aggregate_all(count, specializer:ho_specialization_failed(_, _, _, _), 11),
    forall(between(1, 11, Index),
           ( atom_concat(f, Index, Function),
             specializer:ho_specialization_failed(_, Function, 3, [myfun]) )).

setup_failed_specialization_type :-
    set_specializer_test_mode,
    load_specializer_regression(
        'repro3_failed_specialization_self_leak.metta', _).

cleanup_failed_specialization_type :-
    cleanup_specializer_symbols([wrap, wrap2, myfun]).

test(failed_specialization_does_not_leak_generated_type,
     [ setup(setup_failed_specialization_type),
       cleanup(cleanup_failed_specialization_type) ]) :-
    once(get_native_atom(
        '&self', [':', wrap, ['->', 'Number', 'Number', 'Number']])),
    specializer:ho_specialization_failed(_, wrap, 3, [myfun]),
    \+ ( get_native_atom('&self', [':', Name, _]),
         atom(Name),
         sub_atom(Name, 0, _, _, 'wrap_Spec_') ).

:- dynamic variant_normalization_preexisting_lambda/1.

setup_variant_normalization :-
    retractall(silent(_)),
    assertz(silent(false)),
    %Snapshot the lambdas that exist BEFORE the repro runs: the engine
    %prelude compiles a foldl lambda of its own at boot, and sweeping
    %every lambda_ name in cleanup would unregister the prelude's.
    retractall(variant_normalization_preexisting_lambda(_)),
    forall(( fun(Name), atom(Name), sub_atom(Name, 0, _, _, lambda_) ),
           assertz(variant_normalization_preexisting_lambda(Name))).

cleanup_variant_normalization :-
    findall(Name,
            ( fun(Name),
              atom(Name),
              sub_atom(Name, 0, _, _, lambda_),
              \+ variant_normalization_preexisting_lambda(Name) ),
            LambdaNames),
    retractall(variant_normalization_preexisting_lambda(_)),
    cleanup_specializer_symbols([app|LambdaNames]).

test(compound_partial_key_has_stable_anonymous_variables,
     [ setup(setup_variant_normalization),
       cleanup(cleanup_variant_normalization) ]) :-
    with_output_to(
        string(Output),
        catch(load_specializer_regression(
                  'repro4_variant_normalization.metta', _),
              Error,
              true)),
    %The fixture's (+ $y $z) leaves the addend and the result both unbound,
    %which the arithmetic refusal names: two unknowns, no finite domain.
    Error = error(metta_unsolved_arithmetic('+', unbounded_domain), _),
    %The subject here is the STABLE `_` in the variant key, not the
    %lambda's index: boot-time compiles (the engine prelude's own foldl
    %lambda among them) advance the shared sequence before this file
    %loads, so the index is whatever the boot left. Match the key by its
    %stable frame and recover the actual name from the output.
    re_matchsub("app_Spec_k[0-9a-fz]+",
                Output, Sub, []),
    get_dict(0, Sub, SpecStr),
    atom_string(SpecName, SpecStr),
    \+ ho_specialization(_, app, _),
    \+ fun(SpecName),
    \+ arity(SpecName, _),
    \+ translator:fun_meta_clause(_, SpecName, _, _),
    functor(SpecHead, SpecName, 3),
    \+ clause(SpecHead, _),
    \+ get_native_atom('&self', [=, [SpecName|_], _]).

test(specialization_names_are_writable_and_stable) :-
    specializer:specialization_name(f, [g], 'f_Spec_[g]'),
    specializer:specialization_name(
        'map-flat', [partial(+,[1])], First),
    specializer:specialization_name(
        'map-flat', [partial(+,[1])], Again),
    First == Again,
    sub_atom(First, 0, _, _, 'map-flat_Spec_k'),
    parser:metta_symbol_writable(First),
    specializer:specialization_name(
        'bad name', [partial('quoted key',[1])], Hostile),
    sub_atom(Hostile, 0, _, _, 'metta_Spec_h'),
    parser:metta_symbol_writable(Hostile),
    First \== Hostile,
    specializer:specialization_name(
        app, [partial(lambda,[Variable])], VariableFirst),
    specializer:specialization_name(
        app, [partial(lambda,[AnotherVariable])], VariableAgain),
    var(Variable),
    var(AnotherVariable),
    VariableFirst == VariableAgain,
    specializer:specialization_name(a, ['b_Spec_[c]'], CollisionLeft),
    specializer:specialization_name('a_Spec_[b', [c], CollisionRight),
    CollisionLeft \== CollisionRight,
    parser:metta_symbol_writable(CollisionLeft),
    parser:metta_symbol_writable(CollisionRight).

setup_named_space_specialization :-
    set_specializer_test_mode,
    process_metta_string("\n
(= (plunit-spec-ns-bump $n) (+ $n 1))\n
(= (plunit-spec-ns-twice $f $x) ($f ($f $x)))\n
", _, '&plunit_spec_ns').

cleanup_named_space_specialization :-
    cleanup_specializer_symbols(['plunit-spec-ns-twice', 'plunit-spec-ns-bump']),
    clear_native_atoms('&plunit_spec_ns').

test(higher_order_code_runs_inside_a_named_space,
     [ setup(setup_named_space_specialization),
       cleanup(cleanup_named_space_specialization) ]) :-
    % The generated clause used to be asserted into user, where the space's
    % own functions do not exist, so this crashed on its first call with
    % Unknown procedure: plunit-spec-ns-bump/2.
    process_metta_string("!(plunit-spec-ns-twice plunit-spec-ns-bump 0)",
                         [2], '&plunit_spec_ns').


% Reading a function's equations to plan a specialization is worth it only if
% some call argument can carry a function into a head-variable position. An
% ATOMIC argument has no sub-terms but itself, so a call whose arguments are all
% atomic and none of them a function name settles that without reading any
% equation. Compiling such a call site cost 64,191 inferences against a
% 2,048-equation function and 903 against an 8-equation one; it costs 682 and
% 634.
compile_call_site_cost(N, Per) :-
    set_specializer_test_mode,
    forall(between(1, N, I),
           ( format(atom(D), '(= (plunit-spec-scale~w ss~w) r~w)', [N, I, I]),
             atom_string(D, DS), process_metta_string(DS, _) )),
    format(atom(Q), '!(plunit-spec-scale~w ss~w)', [N, N]), atom_string(Q, QS),
    ( between(1, 5, _), process_metta_string(QS, _), fail ; true ),
    Rounds = 20,
    statistics(inferences, Before),
    ( between(1, Rounds, _), process_metta_string(QS, _), fail ; true ),
    statistics(inferences, After),
    statistics(inferences, Settle),
    Overhead is Settle - After,
    Per is ((After - Before) - Overhead) / Rounds,
    format(atom(Name), 'plunit-spec-scale~w', [N]),
    cleanup_specializer_symbols([Name]).

test(compiling_a_call_site_does_not_read_the_callee_equations) :-
    compile_call_site_cost(8, Narrow),
    compile_call_site_cost(512, Wide),
    assertion(Wide < Narrow * 2).

% Planning a specialization grafts each call argument onto a fresh copy of the
% equation's head pattern, one position at a time. That walk must not metacall
% anything per position: a yall lambda passed as data costs a copy_term_nat of
% the lambda and a =../2 rebuilt goal on EVERY call, which is the same defect
% static_checks.pl's compile_time_helper('>>') rule forbids in a generated
% body, and it also makes the first plan in a process pay the lambda's
% one-time resolution. Over a ground list argument of 16 and 256 positions the
% lambda cost 17.0 inferences per position and the first-order walk costs 4.0,
% the 4.25x that rule's own note records as 3.6 to 4.7. The bound is stated on
% the SLOPE, not on either point, so compiled-image layout cannot move it
% [measured 2026-08-26: this test read 17 against the yall walk and 4 against
% the first-order one, identical across runs; command=cd tests/prolog && swipl
% -g "set_test_options([format(log)]), run_tests" -t halt specializer.plt;
% commit=7e7cac85fee08c117032b2efa5a58a40f3b21365].
argument_walk_cost(N, Per) :-
    numlist(1, N, Positions),
    Rounds = 50,
    ( between(1, 5, _),
      specializer:specializable_vars([ok], Positions, Positions, _, _),
      fail ; true ),
    statistics(inferences, Before),
    ( between(1, Rounds, _),
      specializer:specializable_vars([ok], Positions, Positions, _, _),
      fail ; true ),
    statistics(inferences, After),
    statistics(inferences, Settle),
    Overhead is Settle - After,
    Per is ((After - Before) - Overhead) / Rounds.

test(the_argument_walk_makes_no_metacall_per_position) :-
    argument_walk_cost(16, Narrow),
    argument_walk_cost(256, Wide),
    PerPosition is (Wide - Narrow) / 240,
    assertion(PerPosition =< 8).

:- end_tests(specializer).

:- begin_tests(specializer_invalidation).

% specializer:invalidate_specializations/2 recurses through ho_specialization/3 and
% retracts only AFTER descending, so a cycle among those facts would not
% terminate. It is called unguarded from three engine write sites and, since
% the register-an-operation path stopped swallowing its failures, from there
% too, where a hang is worse than the swallowed failure it replaced.
%
% No cycle is reachable today, because the recursive-specialization fold
% reuses the active name rather than recording a new fact. This constructs one
% directly, which is the only way to exercise the guard at all: without the
% visited set the goal below does not return.
% Both facts are planted in ONE module, which is the only shape the cycle can
% take now that the walk is scoped to the writing space's module.
test(an_invalidation_cycle_terminates,
     [ setup(( metta_self_module(M),
               assertz(user:ho_specialization(M, plunit_cycle_a,
                                              plunit_cycle_b)),
               assertz(user:ho_specialization(M, plunit_cycle_b,
                                              plunit_cycle_a)) )),
       cleanup(( retractall(user:ho_specialization(_, plunit_cycle_a, _)),
                 retractall(user:ho_specialization(_, plunit_cycle_b, _)) )) ]) :-
    metta_self_module(Self),
    call_with_inference_limit(specializer:invalidate_specializations(Self, plunit_cycle_a),
                              100000, Outcome),
    assertion(Outcome \== inference_limit_exceeded),
    assertion(\+ user:ho_specialization(_, plunit_cycle_a, _)),
    assertion(\+ user:ho_specialization(_, plunit_cycle_b, _)).

test(a_tabled_function_never_specializes,
     [ setup(( sread("(= (spt-loop $x $y) (spt-loop $y $x))", Eq),
               add_sexp('&self', Eq),
               translate_clause(Eq, Clause),
               assertz(Clause),
               assertz(fun('spt-loop')),
               assertz(arity('spt-loop', 3)),
               add_sexp('&metta', [tabled, '&self', 'spt-loop', 2]) )),
       cleanup(( remove_sexp('&metta', [tabled, '&self', 'spt-loop', 2]),
                 remove_sexp('&self', [=, ['spt-loop'|_], _]),
                 retractall(fun('spt-loop')),
                 retractall(arity('spt-loop', _)) )) ]) :-
    % The reflection fact says spt-loop is tabled, so a call whose
    % argument names a defined function must NOT plan a specialization:
    % the clone would carry the recursion without the tabling. The
    % 27,525-frame precedent is recorded at maybe_specialize_call.
    \+ maybe_specialize_call('spt-loop', [d, x], _, _).

test(string_run_equation_invalidates_specializations,
     [ setup(( metta_self_module(M),
                assertz(user:ho_specialization(M, 'plunit-door-fn',
                                               plunit_door_spec)) )),
       cleanup(( retractall(user:ho_specialization(_, 'plunit-door-fn', _)),
                 remove_sexp('&self', [=, ['plunit-door-fn'|_], _]),
                 retractall(fun('plunit-door-fn')),
                 retractall(arity('plunit-door-fn', _)) )) ]) :-
    % The string-run door (process_form/3) used to notify
    % seam:function_changed and skip invalidate_specializations, so a
    % specialization of a name survived new equations for it. The one
    % compile door notifies completely; this pins that a run-defined
    % equation retracts the stale specialization record.
    process_metta_string("(= (plunit-door-fn $x) $x)", _),
    \+ user:ho_specialization(_, 'plunit-door-fn', _).

test(a_recursive_specialization_survives_its_compile,
     [ cleanup(( remove_sexp('&self', [=, ['plunit-tricky'|_], _]),
                 retractall(fun('plunit-tricky')),
                 retractall(arity('plunit-tricky', _)),
                 metta_self_module(M),
                 specializer:invalidate_specializations(M, 'plunit-tricky') )) ]) :-
    % A definition whose body calls ITSELF with a ground higher-order
    % argument compiles a clone for that call and a generic clause that
    % names it. Invalidating after the compile abolished that clone while
    % the clause naming it stood, so the generic path called an empty
    % predicate: the direct call still answered through its own
    % specialization, and a call arriving through a variable answered
    % NOTHING. Stale clones are dropped BEFORE the body compiles now.
    process_metta_string(
        "(= (plunit-tricky $f) (if (= ($f 1) 2) (plunit-tricky (+ 2)) ($f 1)))",
        _),
    process_metta_string("!(plunit-tricky (+ 1))", [Direct]),
    assertion(Direct == 3),
    process_metta_string("!(let $g (+ 1) (plunit-tricky $g))", [ViaVariable]),
    assertion(ViaVariable == 3).

% Forgetting a specialization has to take its PROVENANCE with its clauses and
% its source atoms out of the space that holds them. It erased the clauses and
% left translated_from/2 naming the dead references, so removing the
% specialization's own atom found one, called erase/1 on it, and FAILED: every
% caller of the removal failed with it, and dropping a Python space that had
% specialized a higher-order function raised
% "the engine refused metta_py_clear". And it removed the source atoms from
% '&self' by name while the specializer writes them into the space that
% triggered it, so a named space kept the atoms of a specialization whose
% clauses were gone.
test(a_removed_equation_forgets_its_specialization,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(E, [['plunit-forget'|_], ['plunit-forget-inc'|_],
                                   ['plunit-forget-use'|_]]),
                        remove_sexp('&plunit_spec_forget', [=, E, _])),
                 space_module('&plunit_spec_forget', M),
                 forall(member(N, ['plunit-forget', 'plunit-forget-inc',
                                   'plunit-forget-use']),
                        ( specializer:invalidate_specializations(M, N),
                          specializer:forget_symbol(M, N) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Space = '&plunit_spec_forget',
    space_module(Space, Module),
    'add-atom'(Space, [=, ['plunit-forget-inc', X], ['+', X, 1]], _),
    'add-atom'(Space, [=, ['plunit-forget', F, Y], [F, Y]], _),
    % The call site with a ground higher-order argument is what makes the
    % specializer clone plunit-forget, and it is compiled into THIS space's
    % module, not the engine's.
    'add-atom'(Space, [=, ['plunit-forget-use', Z],
                          ['plunit-forget', 'plunit-forget-inc', Z]], _),
    with_metta_module(Module, reduce(['plunit-forget-use', 1], Answer, _)),
    assertion(Answer == 2),
    ho_specialization(Module, 'plunit-forget', SpecName),
    % The clone, its provenance and its source atom all exist first, so the
    % check below is about them going rather than about them never arriving.
    functor(SpecHead, SpecName, 3),
    assertion(( clause(Module:SpecHead, _, SpecRef),
                clause_property(SpecRef, module(Module)) )),
    assertion(get_native_atom(Space, [=, [SpecName|_], _])),
    % Removing the equation the clone came from forgets it.
    'remove-atom'(Space, [=, ['plunit-forget', F2, Y2], [F2, Y2]], _),
    assertion(\+ ho_specialization(Module, 'plunit-forget', _)),
    assertion(\+ ( clause(Module:SpecHead, _, R2),
                   clause_property(R2, module(Module)) )),
    % No dangling provenance is left behind, which is the half that made the
    % next removal fail.
    assertion(\+ ( translated_from(Ref, [=, [SpecName|_], _]),
                   \+ catch(clause_property(Ref, module(_)), _, fail) )),
    % And the source atom went out of the space that held it, not out of &self.
    assertion(\+ get_native_atom(Space, [=, [SpecName|_], _])).

% The verifying mode runs the clone and the generic function it was cloned
% from and compares their whole answer sets. Both live in the module of the
% space that triggered the specialization, and both used to be called from
% the engine's module, so with &self no longer being that module every
% specialization in the corpus raised existence_error under the mode that
% exists to prove they agree.
test(the_verifier_runs_a_clone_in_its_own_module,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(E, [['plunit-verify'|_], ['plunit-verify-inc'|_],
                                   ['plunit-verify-use'|_]]),
                        remove_sexp('&plunit_spec_verify', [=, E, _])),
                 space_module('&plunit_spec_verify', M),
                 forall(member(N, ['plunit-verify', 'plunit-verify-inc',
                                   'plunit-verify-use']),
                        ( specializer:invalidate_specializations(M, N),
                          specializer:forget_symbol(M, N) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Space = '&plunit_spec_verify',
    space_module(Space, Module),
    'add-atom'(Space, [=, ['plunit-verify-inc', X], ['+', X, 1]], _),
    'add-atom'(Space, [=, ['plunit-verify', F, Y], [F, Y]], _),
    'add-atom'(Space, [=, ['plunit-verify-use', Z],
                          ['plunit-verify', 'plunit-verify-inc', Z]], _),
    with_metta_module(Module, reduce(['plunit-verify-use', 1], _, _)),
    ho_specialization(Module, 'plunit-verify', SpecName),
    SpecGoal =.. [SpecName, 'plunit-verify-inc', 1, Out],
    % Qualified the way a compiled clause in that module qualifies it, which
    % is what the meta_predicate declaration on the verifier produces.
    specializer:metta_verified_specialization(SpecName, Module:SpecGoal),
    assertion(Out == 2),
    assertion(specializer:ho_specialization_agrees(SpecName)).

%The comparison runs the call two more times than the program asked, once as
%the clone and once as the generic, and then the wrapper runs the real one.
%That is invisible for a read and WRONG for a write, so the comparison runs
%inside snapshot/1 and its writes are discarded. This counts them: the tally
%must gain exactly one atom across a verified call, and gains three without
%the snapshot. examples/ch08-data/08-03-the-shipped-libraries/12-dict_lib.metta
%is where the corpus showed it, answering 22 against an asserted 10 because
%4 + 6 + 6 + 6 is 22.
test(a_verified_call_writes_once_however_often_the_comparison_ran,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(E, [['plunit-write'|_], ['plunit-write-inc'|_],
                                   ['plunit-write-use'|_]]),
                        remove_sexp('&plunit_spec_write', [=, E, _])),
                 forall('get-atoms'('&plunit_spec_tally', Atom),
                        remove_sexp('&plunit_spec_tally', Atom)),
                 space_module('&plunit_spec_write', M),
                 forall(member(N, ['plunit-write', 'plunit-write-inc',
                                   'plunit-write-use']),
                        ( specializer:invalidate_specializations(M, N),
                          specializer:forget_symbol(M, N) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Space = '&plunit_spec_write',
    Tally = '&plunit_spec_tally',
    space_module(Space, Module),
    'add-atom'(Space, [=, ['plunit-write-inc', X],
                          [let, _Ignored, ['add-atom', Tally, [wrote]],
                                ['+', X, 1]]], _),
    'add-atom'(Space, [=, ['plunit-write', F, Y], [F, Y]], _),
    'add-atom'(Space, [=, ['plunit-write-use', Z],
                          ['plunit-write', 'plunit-write-inc', Z]], _),
    with_metta_module(Module, reduce(['plunit-write-use', 1], _, _)),
    ho_specialization(Module, 'plunit-write', SpecName),
    %A DELTA rather than a total, because reduce/3 above already ran the
    %function once to trigger the specialization.
    findall(Before, 'get-atoms'(Tally, Before), Started),
    length(Started, StartCount),
    SpecGoal =.. [SpecName, 'plunit-write-inc', 1, Answer],
    specializer:metta_verified_specialization(SpecName, Module:SpecGoal),
    findall(After, 'get-atoms'(Tally, After), Ended),
    length(Ended, EndCount),
    Written is EndCount - StartCount,
    assertion(Answer == 2),
    assertion(Written == 1),
    assertion(specializer:ho_specialization_agrees(SpecName)).

% A specialization belongs to the space whose code triggered it, and
% ho_specialization/3 has said so in its first argument since it was written.
% specializer:invalidate_specializations/2's predecessor read that argument with a WILDCARD, so adding an
% equation for a name in ANY space invalidated that name's specializations in
% EVERY space: their compiled clauses went, and so did the equations
% specializer:specialize_call_locked/7 stores into each space, which is a write in one
% space changing another space's atom count.
%
% Reproduced through MeTTa.copy(), which enumerates &self and re-adds every
% atom into a fresh space: re-adding the base equation there stripped four spec
% atoms from &self, so the SOURCE of a copy lost atoms to the copy. It was the
% suite's one known flake, 1 firing in 12 parallel runs, and no concurrency was
% involved.
%The copy door: MeTTa.copy() enumerates a space and re-adds every atom into
%a fresh one, generated specializations included. Compiling a copied
%specialization's body re-enters the specializer with no ho_specialization/3
%row behind the name, and regenerating there stored every specialization
%TWICE, the copies orphans nothing would invalidate. Adoption records the
%row instead: same atom count, one answer, and the clone's specializations
%are tracked again.
test(a_copied_space_adopts_its_specializations_instead_of_duplicating,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(S, ['&self', '&plunit_spec_clone']),
                        forall(member(N, ['plunit-copy-hof', 'plunit-copy-inc',
                                          'plunit-copy-use']),
                               remove_sexp(S, [=, [N|_], _]))),
                 forall(member(S, ['&self', '&plunit_spec_clone']),
                        ( space_module(S, M),
                          forall(member(N, ['plunit-copy-hof', 'plunit-copy-inc',
                                            'plunit-copy-use']),
                                 specializer:invalidate_specializations(M, N)) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Clone = '&plunit_spec_clone',
    space_module('&self', SelfModule),
    space_module(Clone, CloneModule),
    'add-atom'('&self', [=, ['plunit-copy-inc', X], ['+', X, 1]], _),
    'add-atom'('&self', [=, ['plunit-copy-hof', F, Y], [F, Y]], _),
    'add-atom'('&self', [=, ['plunit-copy-use', Z],
                            ['plunit-copy-hof', 'plunit-copy-inc', Z]], _),
    with_metta_module(SelfModule, reduce(['plunit-copy-use', 1], Answer, _)),
    assertion(Answer == 2),
    spec_equation_count('&self', SelfSpecs),
    assertion(SelfSpecs > 0),
    findall(A, 'get-atoms'('&self', A), Atoms),
    forall(member(A, Atoms), 'add-atom'(Clone, A, _)),
    spec_equation_count(Clone, CloneSpecs),
    assertion(CloneSpecs == SelfSpecs),
    assertion(ho_specialization(CloneModule, 'plunit-copy-hof', _)),
    with_metta_module(CloneModule,
                      findall(Out, reduce(['plunit-copy-use', 5], Out, _),
                              CloneAnswers)),
    assertion(CloneAnswers == [6]),
    spec_equation_count(Clone, CloneSpecsAfter),
    assertion(CloneSpecsAfter == SelfSpecs).

% A space that holds a reference row publishes its own heads into its face,
% and translating a specialization's body forces the deferred functions it
% calls, so the materialisation reports a face change whose closure reaches
% the specialization being built. Its registrations were forgotten while its
% clauses were still translating, and publishing them anyway left an orphan
% equation a removal could not withdraw and the next call regenerated beside.
test(a_specialization_invalidated_while_it_translates_is_rebuilt_once,
     [ setup(( retractall(silent(_)), assertz(silent(true)),
               'new-space'(Origin), 'new-space'(Space) )),
       cleanup(( metta_release_space(Space), metta_release_space(Origin),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    space_module(Space, Module),
    metta_add_program_atoms(Origin, [[=, ['plunit-face-other', X0], X0]]),
    % The program arrives deferred through the batch door, and the reference
    % row after it: with the row's observers already installed the batch door
    % compiles per atom, and a compiled function has nothing left to
    % materialise at the call.
    metta_add_program_atoms(Space,
                           [[=, ['plunit-face-inc', X], [+, X, 1]],
                            [=, ['plunit-face-hof', F, Y], [F, Y]]]),
    assertion(spaces:deferred_metta_function('plunit-face-inc', Module,
                                             Space, 1, _, _)),
    'add-atom'(Space, [from, Origin], _),
    with_metta_module(Module,
        ( translate_expr(['plunit-face-hof', 'plunit-face-inc', 1], Goals, Out),
          translator:goals_list_to_conj(Goals, Call),
          findall(Out, call(Module:Call), Answers) )),
    assertion(Answers == [2]),
    ho_specialization(Module, 'plunit-face-hof', SpecName),
    functor(SpecHead, SpecName, 3),
    assertion(aggregate_all(count, ( clause(Module:SpecHead, _, Ref),
                                     clause_property(Ref, module(Module)) ), 1)),
    spec_equation_count(Space, Specs),
    assertion(Specs == 1),
    % The equation the clone came from goes, and the clone goes with it: an
    % orphan row would survive this removal and answer beside a regenerated
    % clone on the next call.
    'remove-atom'(Space, [=, ['plunit-face-hof', F2, Y2], [F2, Y2]], _),
    assertion(\+ ho_specialization(Module, 'plunit-face-hof', _)),
    spec_equation_count(Space, AfterRemoval),
    assertion(AfterRemoval == 0),
    metta_add_program_atoms(Space, [[=, ['plunit-face-hof', F3, Y3], [F3, Y3]]]),
    with_metta_module(Module,
        ( translate_expr(['plunit-face-hof', 'plunit-face-inc', 1], Goals2, Out2),
          translator:goals_list_to_conj(Goals2, Call2),
          findall(Out2, call(Module:Call2), Again) )),
    assertion(Again == [2]),
    spec_equation_count(Space, AfterRebuild),
    assertion(AfterRebuild == 1),
    !.

test(a_copied_specialization_materializes_before_its_call,
     [ forall(member(History, [fresh, retired])),
       setup(( retractall(silent(_)), assertz(silent(true)),
               'new-space'(Source), 'new-space'(Clone) )),
       cleanup(( metta_release_space(Clone), metta_release_space(Source),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    space_module(Source, SourceModule),
    space_module(Clone, CloneModule),
    metta_add_program_atoms(Source,
                           [[=, ['plunit-lazy-copy', F, X], [F, X]]]),
    with_metta_module(SourceModule,
        ( translate_expr(['plunit-lazy-copy', [+, 1], 4], Goals, First),
          translator:goals_list_to_conj(Goals, Call),
          once(call(SourceModule:Call)) )),
    assertion(First == 5),
    ho_specialization(SourceModule, 'plunit-lazy-copy', SpecName),
    findall(Row, get_native_atom(Source, Row), Rows),
    (   History == retired
    ->  functor(OldHead, SpecName, 3),
        assertz(CloneModule:OldHead, OldRef),
        assertz(CloneModule:OldHead, OtherRef),
        % The open native choice keeps an old clause reachable through the
        % logical update view, independently of the clause-GC schedule.
        call(CloneModule:OldHead),
        abolish(CloneModule:SpecName/3),
        Retired = [OldRef, OtherRef]
    ;   Retired = []
    ),
    metta_add_program_atoms(Clone, Rows),
    assertion(spaces:deferred_metta_function(
                  SpecName, CloneModule, Clone, 2, _, 1)),
    atom_multiset(Clone, Before),
    with_metta_module(CloneModule,
        ( translate_expr(['plunit-lazy-copy', [+, 1], 8], CopiedGoals, Out),
          translator:goals_list_to_conj(CopiedGoals, CopiedCall),
          findall(Out, call(CloneModule:CopiedCall), Answers) )),
    assertion(Answers == [9]),
    atom_multiset(Clone, After),
    assertion(After == Before),
    assertion(ho_specialization(CloneModule, 'plunit-lazy-copy', SpecName)),
    forall(member(Ref, Retired), assertion(clause_property(Ref, erased))),
    !.

spec_equation_count(Space, Count) :-
    findall(Name,
            ( 'get-atoms'(Space, [=, [Name|_], _]),
              atom(Name), sub_atom(Name, _, _, _, '_Spec_') ),
            Names),
    length(Names, Count).

test(writing_in_one_space_leaves_another_alone,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(S, ['&self', '&plunit_spec_other']),
                        forall(member(N, ['plunit-cross', 'plunit-cross-inc',
                                          'plunit-cross-use']),
                               remove_sexp(S, [=, [N|_], _]))),
                 forall(member(S, ['&self', '&plunit_spec_other']),
                        ( space_module(S, M),
                          forall(member(N, ['plunit-cross', 'plunit-cross-inc',
                                            'plunit-cross-use']),
                                 specializer:invalidate_specializations(M, N)) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Other = '&plunit_spec_other',
    space_module('&self', SelfModule),
    'add-atom'('&self', [=, ['plunit-cross-inc', X], ['+', X, 1]], _),
    'add-atom'('&self', [=, ['plunit-cross', F, Y], [F, Y]], _),
    'add-atom'('&self', [=, ['plunit-cross-use', Z],
                            ['plunit-cross', 'plunit-cross-inc', Z]], _),
    with_metta_module(SelfModule, reduce(['plunit-cross-use', 1], Answer, _)),
    assertion(Answer == 2),
    % &self now holds the specialization and its stored equation.
    assertion(ho_specialization(SelfModule, 'plunit-cross', _)),
    atom_multiset('&self', Before),
    % The SAME equation written into another space, which is exactly what
    % MeTTa.copy() does when it re-adds an enumerated atom into a fresh space.
    'add-atom'(Other, [=, ['plunit-cross', F2, Y2], [F2, Y2]], _),
    atom_multiset('&self', After),
    assertion(After == Before),
    assertion(ho_specialization(SelfModule, 'plunit-cross', _)),
    % and the other direction: &self writing does not strip the other space
    'add-atom'(Other, [=, ['plunit-cross-inc', X2], ['+', X2, 2]], _),
    atom_multiset(Other, OtherBefore),
    'add-atom'('&self', [=, ['plunit-cross-inc', X3], ['+', X3, 1]], _),
    atom_multiset(Other, OtherAfter),
    assertion(OtherAfter == OtherBefore).

% A space's atoms as a comparable multiset. The store hands back a fresh copy
% each time, so the variables differ between two reads of the same atom and
% ==/2 on the raw terms compares nothing useful; numbervars over a copy makes
% two reads of one atom the same term and keeps two atoms that differ apart.
atom_multiset(Space, Sorted) :-
    findall(Ground,
            ( get_native_atom(Space, Atom),
              copy_term(Atom, Ground),
              numbervars(Ground, 0, _) ),
            Atoms),
    msort(Atoms, Sorted).

% The other direction of the same root, and the one that changes ANSWERS
% rather than atom counts. The specializer reads a function's retained
% equations to build the specialized clause, one clause per equation, and
% translator:fun_meta_clause/4 was keyed by NAME alone: two spaces each defining
% plunit-two-map put two equations under that one key, so the space that
% specialized generated TWO identical clauses and answered its query twice.
% Measured at c7126f1 as well, so it is older than the module migration.
test(a_definition_in_another_space_does_not_double_an_answer,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( forall(member(S, ['&plunit_spec_two_a', '&plunit_spec_two_b']),
                        ( forall(member(N, ['plunit-two-map', 'plunit-two-inc',
                                            'plunit-two-use']),
                                 remove_sexp(S, [=, [N|_], _])),
                          space_module(S, M),
                          forall(member(N, ['plunit-two-map', 'plunit-two-inc',
                                            'plunit-two-use']),
                                 ( specializer:invalidate_specializations(M, N),
                                   clear_fun_meta(M, N) )) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    A = '&plunit_spec_two_a',
    B = '&plunit_spec_two_b',
    forall(member(S, [A, B]),
           ( 'add-atom'(S, [=, ['plunit-two-map', F, Y], [F, Y]], _),
             'add-atom'(S, [=, ['plunit-two-inc', X], ['+', X, 1]], _) )),
    'add-atom'(B, [=, ['plunit-two-use', Z],
                      ['plunit-two-map', 'plunit-two-inc', Z]], _),
    space_module(B, BModule),
    findall(Answer,
            with_metta_module(BModule, reduce(['plunit-two-use', 1], Answer, _)),
            Answers),
    assertion(Answers == [2]),
    %One specialized clause, not one per space that happens to share the name.
    ho_specialization(BModule, 'plunit-two-map', SpecName),
    functor(SpecHead, SpecName, 3),
    aggregate_all(count, clause(BModule:SpecHead, _), 1).

test(an_untyped_local_shadow_does_not_type_its_specialization,
     [ setup(( retractall(silent(_)), assertz(silent(true)) )),
       cleanup(( metta_remove_atom(
                     '&self',
                     [':', 'plunit-shadow-hof',
                      [->, 'Atom', 'Number', 'Number']], _),
                 clear_native_atoms('&plunit_spec_shadow'),
                 space_module('&plunit_spec_shadow', M),
                 forall(member(N, ['plunit-shadow-hof',
                                   'plunit-shadow-inc',
                                   'plunit-shadow-use']),
                        ( specializer:invalidate_specializations(M, N),
                          specializer:forget_symbol(M, N) )),
                 retractall(silent(_)), assertz(silent(false)) )) ]) :-
    Space = '&plunit_spec_shadow',
    'add-atom'('&self',
               [':', 'plunit-shadow-hof',
                [->, 'Atom', 'Number', 'Number']], _),
    'add-atom'(Space,
               [=, ['plunit-shadow-inc', X], ['+', X, 1]], _),
    'add-atom'(Space,
               [=, ['plunit-shadow-hof', F, Y], [F, Y]], _),
    'add-atom'(Space,
               [=, ['plunit-shadow-use', Z],
                ['plunit-shadow-hof', 'plunit-shadow-inc', Z]], _),
    space_module(Space, Module),
    findall(Answer,
            with_metta_module(Module,
                              reduce(['plunit-shadow-use', 1], Answer, _)),
            Answers),
    assertion(Answers == [2]),
    ho_specialization(Module, 'plunit-shadow-hof', SpecName),
    findall(Type,
            with_metta_module(
                Module, type_declaration('plunit-shadow-hof', Type)),
            ReportingTypes),
    assertion(ReportingTypes == [[->, 'Atom', 'Number', 'Number']]),
    assertion(\+ with_metta_module(
                     Module,
                     governing_type_declaration('plunit-shadow-hof', _))),
    assertion(\+ match_stored(Space, [':', SpecName, _], _, _)).

% A specialization's name is made from the call, so every module that
% specializes the same call makes the same name. Dropping a space that had
% specialized a call its parent had specialized too removes the space's copy
% and uncovers the parent's, and the shadow repair re-imports the parent's
% predicate into the space's module so a compiled call keeps resolving
% (metta_restore_inherited_predicate/3). The name's next life keeps that import
% while its parent is unchanged, and specializing the same call there asserted
% through the import into the parent: the parent's specialization held its
% clause twice and every call answered twice. The weighted-subset marginals
% property hung on exactly this, unfold's specializations doubled in the
% process home and every level of unfold doubling the answers.
test(a_recycled_space_specializes_into_its_own_module) :-
    Parent = '&plunit_spec_recycled_parent',
    Child = '&plunit_spec_recycled_child',
    setup_call_cleanup(
        ( retractall(silent(_)), assertz(silent(true)) ),
        once(( recycled_specialization_program(Parent),
               recycled_specialization_answers(Parent, [2]),
               space_module(Parent, ParentModule),
               ho_specialization(ParentModule, 'plunit-rc-map', SpecName),
               current_predicate(ParentModule:SpecName/Arity),
               functor(SpecHead, SpecName, Arity),
               metta_declare_space_parent(Child, Parent),
               recycled_specialization_program(Child),
               recycled_specialization_answers(Child, [2]),
               metta_release_space(Child),
               metta_declare_space_parent(Child, Parent),
               space_module(Child, ChildModule),
               recycled_specialization_source(ChildModule, SpecHead, Planted),
               recycled_specialization_program(Child),
               recycled_specialization_answers(Child, ChildAnswers),
               recycled_specialization_answers(Parent, ParentAnswers),
               aggregate_all(count, clause(ParentModule:SpecHead, _), ParentClauses),
               recycled_specialization_source(ChildModule, SpecHead, Derived) )),
        ( catch(metta_release_space(Child), _, true),
          catch(metta_release_space(Parent), _, true),
          retractall(silent(_)),
          assertz(silent(false)) )),
    %The state under test: the recycled module reaches the parent's copy.
    assertion(Planted == ParentModule),
    assertion(ChildAnswers == [2]),
    assertion(ParentAnswers == [2]),
    assertion(ParentClauses == 1),
    assertion(Derived == local).

recycled_specialization_program(Space) :-
    forall(member(Equation,
                  [ [=, ['plunit-rc-map', F, X], [F, X]],
                    [=, ['plunit-rc-inc', Y], ['+', Y, 1]],
                    [=, ['plunit-rc-use', Z],
                     ['plunit-rc-map', 'plunit-rc-inc', Z]] ]),
           'add-atom'(Space, Equation, _)).

recycled_specialization_answers(Space, Answers) :-
    space_module(Space, Module),
    findall(Answer,
            with_metta_module(Module, reduce(['plunit-rc-use', 1], Answer, _)),
            Answers).

%Where a module's predicate comes from: the module an import names, local when
%the module defines it, none when it resolves nowhere.
recycled_specialization_source(Module, Head, Source) :-
    (   predicate_property(Module:Head, imported_from(From))
    ->  Source = From
    ;   predicate_property(Module:Head, defined)
    ->  Source = local
    ;   Source = none
    ).

:- end_tests(specializer_invalidation).
