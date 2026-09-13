% Purpose: verify argument patterns on live references to shared definitions.
% Guarantees: aliases retain input contracts, original receivers, source
%   multiplicity and lifetime [tested: reference_patterns; commit=WORKTREE].
% Owns resources: fixtures release every native space and its reference rows.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(reference_patterns).

pattern_setup :-
    metta_host_set_silent(true),
    findall(Space, (between(1,4,_), gensym('&reference-pattern-',Space)), Spaces),
    maplist(pattern_create, Spaces), nb_setval(reference_pattern_spaces, Spaces).
pattern_create(Space) :- space_module(Space, _).
pattern_space(Index, Space) :- nb_getval(reference_pattern_spaces, Spaces), nth1(Index,Spaces,Space).
pattern_cleanup :-
    nb_getval(reference_pattern_spaces, Spaces), reverse(Spaces, Reversed),
    maplist(metta_release_space, Reversed), nb_delete(reference_pattern_spaces),
    metta_host_set_silent(false).
pattern_add(Index, Row) :- pattern_space(Index, Space), metta_add_atom(Space,Row,_).
pattern_from(Target, Source, Old, New) :-
    pattern_space(Source, Home), pattern_add(Target,[from,Home,[rename,[[Old,New]]]]).
pattern_answers(Index, Call, Answers) :-
    pattern_space(Index, Space), findall(Value,evalc(Call,Space,Value),Bag), msort(Bag,Answers).

test(a_pattern_retains_the_original_receiver_and_shared_body,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1, [':', 'pattern-body', [->,'Atom','Number','Atom']]),
    pattern_add(1, [=,['pattern-body',Self,N],[received,Self,N]]),
    pattern_from(2,1,'pattern-body',['pattern-method',['Point',_,_],_]),
    pattern_answers(2,['pattern-method',['Point',3,4],5],Answers),
    assertion(Answers == [[received,['Point',3,4],5]]),
    pattern_space(2, Target), space_module(Target, Module),
    assertion(\+ call(Module:'pattern-method'(['Other',3,4],5,_))),
    pattern_space(1, Home),
    assertion(metta_head_property(Target,'pattern-method',[origin,Home,_,_])),
    findall(Row,spaces:metta_space_pair(Home,Row,_,_),Source),
    include(pattern_equation,Source,Equations), assertion(length(Equations,1)),
    assertion(\+ spaces:metta_space_pair(Target,[=|_],_,_)).

pattern_equation([=|_]).

test(variables_are_fresh_per_call_and_repeated_positions_still_unify,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-pair',A,B],[pair,A,B]]),
    pattern_from(2,1,'pattern-pair',['pattern-equal',X,X]),
    pattern_answers(2,['pattern-equal',1,1],[[pair,1,1]]),
    pattern_answers(2,['pattern-equal',2,2],[[pair,2,2]]),
    pattern_space(2, Target), space_module(Target, Module),
    assertion(\+ call(Module:'pattern-equal'(1,2,_))).

test(a_call_pattern_selects_its_input_arity,
     [forall(between(0,3,Arity)), setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    forall(between(0,3,N),
           ( length(Args,N), pattern_add(1,[=,['pattern-arity'|Args],N]) )),
    length(Pattern,Arity), pattern_from(2,1,'pattern-arity',['pattern-selected'|Pattern]),
    length(Values,Arity), maplist(=(7),Values),
    pattern_answers(2,['pattern-selected'|Values],[Arity]),
    pattern_space(2, Target), space_module(Target, Module), NativeArity is Arity+1,
    findall(A,metta_engine:metta_reference_slot(Module,'pattern-selected',A),Arities),
    assertion(Arities == [NativeArity]).

test(self_aliases_read_the_own_face_once_and_project_its_arrow,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[':','pattern-owned',[->,'Number','Number']]),
    pattern_add(1,[=,['pattern-owned',X],[+,X,1]]),
    pattern_from(1,1,'pattern-owned',['pattern-local',_]),
    pattern_answers(1,['pattern-local',41],[42]),
    pattern_space(1, Home),
    assertion(spaces:metta_space_pair(Home,[':','pattern-local',[->,'Number','Number']],_,_)),
    pattern_from(2,1,'pattern-local','pattern-imported'),
    pattern_answers(2,['pattern-imported',41],[42]),
    pattern_answers(1,['pattern-owned',41],[42]).

test(alias_paths_keep_source_multiplicity_and_alpha_equal_filters_share_a_root,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-duplicate',X],[item,X]]),
    pattern_add(1,[=,['pattern-duplicate',X],[item,X]]),
    pattern_from(2,1,'pattern-duplicate',['pattern-view',['Pair',_,_]]),
    pattern_from(3,1,'pattern-duplicate',['pattern-view',['Pair',_,_]]),
    pattern_space(2, Left), pattern_space(3, Right),
    pattern_add(4,[from,Left]), pattern_add(4,[from,Right]),
    pattern_answers(4,['pattern-view',['Pair',3,4]],Answers),
    assertion(Answers == [[item,['Pair',3,4]],[item,['Pair',3,4]]]).

test(chained_patterns_constrain_the_same_arguments,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-shared',X,Y],[pair,X,Y]]),
    pattern_from(2,1,'pattern-shared',['pattern-first',['Pair',_,_],_]),
    pattern_from(3,2,'pattern-first',['pattern-second',['Pair',X,X],_]),
    pattern_answers(3,['pattern-second',['Pair',7,7],8],[[pair,['Pair',7,7],8]]),
    pattern_space(3, Target), space_module(Target, Module),
    assertion(\+ call(Module:'pattern-second'(['Pair',7,9],8,_))).

test(distinct_overlapping_patterns_retain_both_answers,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-overlap',X],X]),
    pattern_from(2,1,'pattern-overlap',['pattern-overlap-view',_]),
    pattern_from(2,1,'pattern-overlap',['pattern-overlap-view',['Pair',_,_]]),
    pattern_answers(2,['pattern-overlap-view',['Pair',3,4]],
                    [['Pair',3,4],['Pair',3,4]]),
    pattern_answers(2,['pattern-overlap-view',7],[7]).

test(patterned_cycles_stop_at_a_visited_space,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-cycle-a',X],X]),
    pattern_add(2,[=,['pattern-cycle-b',X],X]),
    pattern_from(1,2,'pattern-cycle-b',['pattern-cycle-import-b',_]),
    pattern_from(2,1,'pattern-cycle-a',['pattern-cycle-import-a',_]),
    pattern_answers(1,['pattern-cycle-import-b',3],[3]),
    pattern_answers(2,['pattern-cycle-import-a',4],[4]).

test(withdrawal_and_rollback_follow_the_exact_alias_occurrence,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[=,['pattern-retained',X],X]),
    pattern_from(2,1,'pattern-retained',['pattern-retained-view',['Pair',_,_]]),
    pattern_space(2, Target),
    once(spaces:metta_space_pair(Target,[from|_],Token,_)),
    \+ transaction((spaces:metta_remove_occurrence(Target,Token,true),fail)),
    pattern_answers(2,['pattern-retained-view',['Pair',1,2]],[['Pair',1,2]]),
    once(spaces:metta_remove_occurrence(Target,Token,true)),
    pattern_answers(2,['pattern-retained-view',['Pair',1,2]],[]),
    space_module(Target,Module),
    assertion(\+ metta_engine:metta_reference_slot(Module,'pattern-retained-view',_)),
    assertion(\+ metta_engine:metta_reference_roots(Module,'pattern-retained-view',_,_)).

test(the_alias_projects_refinements_and_rejects_bad_arguments,
     [setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    Type = ['Annotated','Number',['Gt',0]],
    pattern_add(1,[':','pattern-positive',[->,'Atom',Type,'Number']]),
    pattern_add(1,[=,['pattern-positive',_,N],N]),
    pattern_from(2,1,'pattern-positive',['pattern-positive-view',['Box',_],_]),
    pattern_answers(2,['pattern-positive-view',['Box',a],3],[3]),
    pattern_answers(2,['pattern-positive-view',['Box',a],-1],Bad),
    assertion(Bad = [['Error',['pattern-positive-view',['Box',a],-1],_]]).

test(a_structural_alias_adds_one_native_call_for_every_parameter_contract,
     [forall(member(Type,['Number',['Annotated','Number',['Gt',0]],'PatternRecord'])),
      setup(pattern_setup), cleanup(pattern_cleanup)]) :-
    pattern_add(1,[':','PatternRecord',[->,'Number','PatternRecord']]),
    pattern_add(1,[':','pattern-cost',[->,'Atom',Type,'Atom']]),
    pattern_add(1,[=,['pattern-cost',Receiver,Argument],[value,Receiver,Argument]]),
    pattern_from(2,1,'pattern-cost',['pattern-cost-view',['Pair',_,_],_]),
    pattern_space(1, Home), space_module(Home, Provider),
    pattern_space(2, Target), space_module(Target, Module),
    ( Type == 'PatternRecord' -> Arg = ['PatternRecord',5] ; Arg = 5 ),
    Direct = Provider:'pattern-cost'(['Pair',3,4],Arg,_),
    Alias = Module:'pattern-cost-view'(['Pair',3,4],Arg,_),
    with_metta_module(Module, plunit_reference_patterns:
        ( pattern_slope(Direct,Plain), pattern_slope(Alias,Wrapped) )),
    assertion(Wrapped-Plain =:= 1000).

pattern_slope(Goal, Slope) :-
    pattern_count(Goal,100,_), pattern_count(Goal,100,Low),
    pattern_count(Goal,1100,High), Slope is High-Low.
pattern_count(Goal, N, Count) :-
    statistics(inferences,Before),
    forall(between(1,N,_),once(Goal)),
    statistics(inferences,After), Count is After-Before.

:- end_tests(reference_patterns).
