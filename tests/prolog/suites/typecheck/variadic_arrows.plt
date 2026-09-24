% Purpose: verify one arrow splice through declaration, dispatch and reporting.
% Owns resources: each test releases its fresh space through plunit cleanup.
% Guarantees: run elements keep their own BadArgType positions, held Atom
%   arguments and empty arities; fixed arrows retain their exception.
% [tested: run_tests(variadic_arrows); commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7]

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(variadic_arrows).

:- dynamic redirect_sum/0.
:- multifile seam:dispatch_call/4.

seam:dispatch_call(sum, _, Out, '+'(70, 7, Out)) :-
    plunit_variadic_arrows:redirect_sum.

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

test(the_presented_family_preserves_shared_element_variables) :-
    forall(between(0, 12, Arity),
           ( once(translator:present_type_chain([->, [':seg', T], T], Arity,
                                               [->|Types])),
             length(Types, Count), assertion(Count =:= Arity + 1),
             forall(member(Type, Types), assertion(Type == T)),
             assertion(var(T)) )).

test(every_element_position_refuses,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: sum (-> (:seg Number) Number)) (= (sum (:seg $xs)) (foldl-atom $xs 0 +)) (: flag Bool)", []),
    forall(between(1, 8, Position),
           ( length(Args, 8), nth1(Position, Args, flag, Rest),
             maplist(=(1), Rest), space_module(S, M),
             with_metta_module(M, findall(A, eval([sum|Args], A), Answers)),
             assertion(Answers == [['Error', [sum|Args],
                                    ['BadArgType', Position, 'Number', 'Bool']]]) )).

test(a_segment_arity_cannot_call_an_inherited_native_predicate,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: sum (-> (:seg Number) Number)) (= (sum (:seg $xs)) (foldl-atom $xs 0 +)) !(sum 0 0) !(let $f sum ($f 1 2))", Answers),
    assertion(Answers == [0, 3]),
    space_module(S, M),
    with_metta_module(M,
        ( findall(A, translator:reduce([sum, 2, 3], A, _), Reduced),
          assertion(Reduced == [5]) )),
    run_in(S, "(= (sum $x $y) 99) !(collapse (sum 1 2))", Mixed),
    assertion(Mixed == [[99]]),
    run_in(S, "(= (sum $x) 88) !(collapse (sum 1))", SameArity),
    assertion(SameArity == [[1, 88]]).

test(a_segment_call_keeps_a_seam_selected_target,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: sum (-> (:seg Number) Number)) (= (sum (:seg $xs)) (foldl-atom $xs 0 +))", []),
    setup_call_cleanup(asserta(redirect_sum, Ref),
        ( run_in(S, "!(sum 1 2) !(let $f sum ($f 3 4))", Answers),
          assertion(Answers == [77,77]) ),
        erase(Ref)).

test(segment_dispatch_guards_are_source_occurrence_owned,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (sum (:seg $xs)) 0) !(sum 1 2)", [0]),
    space_module(S, M),
    findall(C-R, translator:segment_dispatch_refs(M, sum, _, C, R), Refs),
    assertion(Refs = [_]),
    \+ transaction((run_in(S, "(= (temporary (:seg $xs)) 1) !(temporary)", [1]), fail)),
    assertion(\+ translator:segment_dispatch_refs(M, temporary, _, _, _)),
    metta_remove_atom(S, [=,[sum,[':seg',_]],0], _),
    assertion(\+ translator:segment_dispatch_refs(M, sum, _, _, _)),
    forall(member(C-R, Refs),
           ( assertion(clause_property(C, erased)),
             assertion(clause_property(R, erased)) )),
    run_in(S, "(= (sum (:seg $xs)) 0) !(sum 1 2)", [0]),
    translator:clear_fun_meta(M, sum),
    assertion(\+ translator:segment_dispatch_refs(M, sum, _, _, _)).

test(segment_dispatch_does_not_charge_unrelated_fixed_calls,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (ordinary $x) $x) !(ordinary 1)", [1]),
    space_module(S, M),
    with_metta_module(M,
        plunit_variadic_arrows:call_cost(translator:dispatch_call_goal_for(M, ordinary, [1], Out,
                                                    ordinary(1,Out), _), Before)),
    run_in(S, "(= (sum (:seg $xs)) 0) !(sum 1 2)", [0]),
    with_metta_module(M,
        plunit_variadic_arrows:call_cost(translator:dispatch_call_goal_for(M, ordinary, [1], Out,
                                                    ordinary(1,Out), _), After)),
    assertion(After == Before).

test(a_native_collision_keeps_annotated_cardinality_verification,
     [setup('new-space'(S)),
      cleanup((set_metta_pragma('verify-cardinality', none), metta_release_space(S)))]) :-
    run_in(S, "(: sum (-[det]-> (:seg Number) Number)) (= (sum (:seg $xs)) 0) (= (sum (:seg $xs)) 1)", []),
    set_metta_pragma('verify-cardinality', true),
    catch(run_in(S, "!(sum 2 3)", _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_cardinality_violation(_, sum, det, nondet), _)).

test(a_program_cannot_capture_the_qualified_policy_dispatcher,
     [setup('new-space'(S)),
      cleanup((metta_remove_atom('&metta',
                 ['dispatch-policy','guarded-policy','FunctionResultEnum','Deterministic'],_),
               metta_release_space(S)))]) :-
    metta_add_atom('&metta',
        ['dispatch-policy','guarded-policy','FunctionResultEnum','Deterministic'],_),
    run_in(S, "(= (dispatch_policy_execute $a $b $c $d) captured) (= (guarded-policy $x) 1) (= (guarded-policy $x) 2) (= (run-policy $x) (guarded-policy $x)) !(dispatch_policy_execute a b c d) !(run-policy a)", Answers),
    assertion(Answers == [captured,1]).

test(fixed_admission_reuses_the_syntax_shape_without_an_arity_walk) :-
    findall(New-Old,
        ( member(N,[0,1,2,4,8,16,128]),
          length(Inputs,N), maplist(=('Number'),Inputs),
          append(Inputs,['Number'],Types), Type=[->|Types],
          call_cost(translator:validate_type_splices(Type,false), New),
          call_cost(plain_annotation(Type), Old) ), Costs),
    Costs=[First-OldFirst|_],
    forall(member(Cost-_,Costs), assertion(Cost==First)),
    last(Costs,_-OldLast), assertion(OldLast>OldFirst).

plain_annotation(Type) :- ( spaces:metta_annotated_type(Type) -> true ; true ).

test(a_syntax_cache_never_reuses_an_open_types_later_binding) :-
    Type=[->,Parameter,'Bool','Atom'],
    translator:validate_type_splices(Type,false), assertion(var(Parameter)),
    Parameter=[':seg','Number'],
    catch(translator:validate_type_splices(Type,_),Error,true),
    assertion(nonvar(Error)),
    assertion(Error=error(domain_error(final_arrow_splice,_),_)).

test(a_cached_syntax_analysis_observes_live_arrow_vocabulary,
     [setup(metta_add_atom('&metta',
                ['vocabulary-open',determinism,"test syntax-cache invalidation"],_)),
      cleanup((metta_remove_atom('&metta',
                  ['vocabulary-member',determinism,'syntax-test-cardinality'],_),
               metta_remove_atom('&metta',
                  ['vocabulary-open',determinism,"test syntax-cache invalidation"],_)))]) :-
    Type=['-[syntax-test-cardinality]->',[':seg','Number'],'Number'],
    catch(translator:validate_type_splices(Type,_),Before,true),
    assertion(nonvar(Before)),
    assertion(Before=error(domain_error(final_arrow_splice,_),_)),
    metta_add_atom('&metta',
        ['vocabulary-member',determinism,'syntax-test-cardinality'],_),
    translator:validate_type_splices(Type,true),
    metta_remove_atom('&metta',
        ['vocabulary-member',determinism,'syntax-test-cardinality'],_),
    catch(translator:validate_type_splices(Type,_),After,true),
    assertion(nonvar(After)),
    assertion(After=error(domain_error(final_arrow_splice,_),_)).

test(an_invalid_annotated_owner_precedes_its_elements_retired_token) :-
    Splice=[':seg','%Rest%'],
    Type=['-[unknown-cardinality]->',Splice,'Number'],
    catch(translator:validate_type_splices(Type,_),Error,true),
    assertion(nonvar(Error)),
    assertion(Error=error(domain_error(final_arrow_splice,Splice),_)).

test(dynamic_heads_and_the_runtime_mask_share_presentation,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: held (-> (:seg Atom) Atom)) (= (held (:seg $xs)) $xs) !(let $f held ($f (+ 1 2) (+ 3 4))) !(held)", Answers),
    assertion(Answers == [[[+,1,2],[+,3,4]], []]),
    space_module(S, M),
    with_metta_module(M,
        ( once(translator:metta_runtime_argument_mask(held, 3, Mask)),
          assertion(Mask == [false,false,false]) )).

test(zero_run_observers_report_the_result_and_the_name_reports_the_arrow,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: sum (-> (:seg Number) Number)) (= (sum (:seg $xs)) (foldl-atom $xs 0 +)) !(get-type sum) !(get-type (sum))", Answers),
    assertion(Answers == [[->,[':seg','Number'],'Number'], 'Number']),
    'get-type-space'(S, [sum], 'Number').

test(alias_refusal_names_the_element_at_the_expanded_position,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: sum (-> (:seg Count) Number)) (= (sum (:seg $xs)) (foldl-atom $xs 0 +)) (: flag Bool) !(sum 1 2 flag)", Answers),
    assertion(Answers == [['Error',[sum,1,2,flag],
        ['BadArgType',3,'Count','Bool',
         ['TypeExpansion',[->,[':seg','Count'],'Number'],
                          [->,[':seg','Number'],'Number']]]]]).

invalid_type([->, ['%Rest%', 'Number'], 'Number'], retired_arrow_splice).
invalid_type([['%Rest%', 'Number'], 'Atom'], retired_arrow_splice).
invalid_type([->, [':seg', 'Number'], 'Bool', 'Number'], final_arrow_splice).
invalid_type([->, [':seg', 'Number'], [':seg', 'Number'], 'Number'], final_arrow_splice).
invalid_type([->, [':seg'], 'Number'], final_arrow_splice).
invalid_type([->, [':seg', 'Number', 'Bool'], 'Number'], final_arrow_splice).
invalid_type([->, 'Number', [':seg', 'Number']], final_arrow_splice).
invalid_type([->, [->, [':seg', 'Number'], 'Bool', 'Number'], 'Atom'], final_arrow_splice).

test(invalid_declarations_refuse_before_storage,
     [forall(invalid_type(Type, Kind)),
      setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    catch(metta_add_atom(S, [':', bad, Type], true), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(domain_error(Kind, _), context(type_declaration, _))),
    assertion(\+ match_stored(S, [':', bad, _], true, true)).

test(source_validation_precedes_effects,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    catch(run_in(S, "!(add-atom &self (before bad)) (: bad (-> (%Rest% Number) Number))", _), Error, true),
    assertion(nonvar(Error)),
    assertion(\+ match_stored(S, [before,bad], true, true)).

test(an_alias_observer_still_validates_declarations,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number))", []),
    catch(metta_add_atom(S, [':', bad, [->, [':seg', 'Number'], 'Bool', 'Atom']], true), Error, true),
    assertion(nonvar(Error)),
    assertion(\+ match_stored(S, [':',bad,_], true, true)).

test(cyclic_alias_syntax_keeps_its_existing_refusal,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    Type = ['Alias', Type],
    catch(metta_add_atom(S, [':', bad, Type], true), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(domain_error(type_alias_declaration, _), _)).

test(cyclic_type_syntax_refuses_before_storage,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    Type = [box, Type],
    catch(metta_add_atom(S, [':', bad, Type], true), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(domain_error(acyclic_type_syntax, _), _)),
    assertion(\+ match_stored(S, [':',bad,_], true, true)).

test(validation_never_fills_an_open_type_or_splice) :-
    translator:validate_type_splices(Type), assertion(var(Type)),
    translator:validate_type_splices([box|Tail]),
    assertion(var(Tail)),
    translator:validate_type_splices([->|Parameters]),
    assertion(var(Parameters)),
    catch(translator:validate_type_splices([->, [':seg'|Run], 'Atom']), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(domain_error(final_arrow_splice, _), _)),
    assertion(var(Run)).

test(kwargs_masks_zero_one_and_more_than_six_pairs,
     [forall(member(Count, [0,1,7,12]))]) :-
    length(Pairs, Count), maplist(=([reverse,true]), Pairs),
    once(translate_expr(['Kwargs'|Pairs], Goals, Value)),
    translator:goals_list_to_conj(Goals, Goal),
    once(call(Goal)),
    assertion(Value == ['Kwargs'|Pairs]).

test(fixed_overapplication_keeps_its_named_exception,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: fixed2 (-> Number Number Number)) (= (fixed2 $a $b) (+ $a $b))", []),
    catch(run_in(S, "!(fixed2 1 2 3)", _), Error, true),
    assertion(Error = error(domain_error(function_input_arities(fixed2,[2]),3),_)).

test(compiled_trailing_and_prefixed_runs_cost_their_fixed_twins,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: v (-> (:seg Number) Number)) (= (v (:seg $xs)) 0) (: p (-> Number (:seg Number) Number)) (= (p $first (:seg $xs)) 0)", []),
    space_module(S, M),
    forall((member(N, [0,1,2,4,8]), member(Prefix, [[],[99]])),
        ( length(Rest, N), maplist(=(1), Rest), append(Prefix, Rest, Args),
          ( Prefix == [] -> Fun = v ; Fun = p ),
          same_length(Args, FixedArgs),
          length(Args, Count), atomic_list_concat([fixed,Count], Fixed),
          same_length(Args, Parameters), maplist(=('Number'), Parameters),
          append(Parameters, ['Number'], Types),
          metta_add_atom(S, [':',Fixed,[->|Types]], _),
          metta_add_atom(S, [=,[Fixed|FixedArgs],0], _),
          with_metta_module(M,
              ( metta_ensure_compiled(Fixed),
                metta_ensure_compiled(Fun),
                once(translator:build_call_or_partial_dl(
                    Fun, Args, V, VGoals, [], [])) )),
          translator:goals_list_to_conj(VGoals, VGoal),
          append(Args, [F], FixedCall), FGoal =.. [Fixed|FixedCall],
          call_cost(M:VGoal, VC), call_cost(M:FGoal, FC),
          assertion(V-F == 0-0), assertion(VC == FC),
          call_cost(translator:metta_segment_interpreted_dispatch(M, Fun, Args, _), Old),
          assertion(Old > FC),
          metta_remove_atom(S, [=,[Fixed|FixedArgs],0], _) )).

:- meta_predicate call_cost(0, -).
call_cost(Goal, Cost) :-
    once(Goal),
    statistics(inferences, Before),
    forall(between(1, 200, _), once(Goal)),
    statistics(inferences, After),
    Cost is After - Before.

test(cut_families_preserve_order_repetition_and_literal_markers,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: cuts (-> (:seg Atom) Atom)) (= (cuts (:seg $a) (:seg $b)) ($a $b)) (: repeated (-> (:seg Atom) Atom)) (= (repeated (:seg $a) stop (:seg $a)) $a) (: rebuilt (-> (:seg Atom) Atom)) (= (rebuilt (:seg $a)) (row (:seg $a))) !(collapse (cuts a b)) !(repeated 1 stop 1.0) !(rebuilt (:seg untouched))", Answers),
    assertion(Answers == [[[[],[a,b]],[[a],[b]],[[a,b],[]]],
                          [1], [row,[':seg',untouched]]]),
    space_module(S, M),
    forall(member(N, [2,4,8]),
        ( length(Args, N), maplist(=(a), Args),
          with_metta_module(M, findall(A, eval([cuts|Args], A), Bag)),
          length(Bag, Count), assertion(Count =:= N + 1) )).

test(shape_artifacts_are_reused_invalidated_and_transaction_owned,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: v (-> (:seg Atom) Atom)) (= (v (:seg $xs)) old) !(v a b)", [old]),
    space_module(S, M),
    findall(Name, ho_specialization(M, v, Name), Names),
    assertion(Names = [_]),
    forall(between(1, 20, X),
           with_metta_module(M, once(eval([v,X,X], old)))),
    findall(Name, ho_specialization(M, v, Name), Same),
    assertion(Same == Names),
    forall(member(Name, Names),
           assertion(\+ metta_host_stored(S, [=,[Name|_],_]))),
    \+ transaction((run_in(S, "!(v a b c)", [old]), fail)),
    findall(Name, ho_specialization(M, v, Name), RolledBack),
    assertion(RolledBack == Names),
    metta_remove_atom(S, [=,[v,[':seg',_]],old], _),
    assertion(\+ ho_specialization(M, v, _)),
    run_in(S, "(= (v (:seg $xs)) new) !(v a b)", [new]).

test(a_shape_cache_keeps_the_ordinary_clause_independent_of_the_first_head,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (kind (row ...)) row-shaped) (= (kind $other) anything) !(collapse (kind (row a b))) !(collapse (kind 7))", Answers),
    assertion(Answers == [['row-shaped',anything],[anything]]).

test(shape_recursion_and_the_differential_share_the_source_bag,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: recur (-> Number (:seg Atom) Number)) (= (recur $n (:seg $xs)) (if (== $n 0) 0 (recur (- $n 1) (:seg $xs)))) (: grow (-> Number (:seg Atom) Number)) (= (grow $n (:seg $xs)) (if (== $n 0) 0 (grow (- $n 1) x (:seg $xs)))) !(recur 10 a b) !(grow 4)", [0,0]),
    space_module(S, M),
    with_metta_module(M,
        ( once(specializer:segment_specialization(recur, [3,a,b], Out, Goal)),
          functor(Goal, Name, _),
          once(specializer:metta_check_specialization(Name, M:Goal)),
          once(call(M:Goal)), assertion(Out == 0) )).

test(fixed_builtin_mask_selection_remains_independent_of_arity_policy,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, M),
    with_metta_module(M,
        once(translator:builtin_argument_mask('new-space', [S, x], Before, Out))),
    run_in(S, "!(add-typing-rule! deny-two arrow-arity 2 2 (Refuse two-denied))", _),
    with_metta_module(M,
        once(translator:builtin_argument_mask('new-space', [S, x], After, Result))),
    assertion(After-Result == Before-Out).

:- end_tests(variadic_arrows).
