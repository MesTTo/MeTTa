% Purpose: classify reference bodies in their defining execution modules.
% Guarantees: aliases, unions and recursive references retain their sources'
%   effects without executing them [tested: reference_effects; commit=WORKTREE].
% Owns resources: each fixture releases its spaces and native reference links.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(reference_effects).

effect_spaces(Spaces) :-
    metta_host_set_silent(true),
    findall(Space, (between(1,3,_), gensym('&reference-effect-',Space)), Spaces),
    maplist(effect_space, Spaces).
effect_space(Space) :- space_module(Space, _).
effect_cleanup(Spaces) :-
    reverse(Spaces, Reversed), maplist(metta_release_space, Reversed),
    metta_host_set_silent(false).
effect_add(Space, Row) :- metta_add_atom(Space, Row, _).
effect_reference(Target, Home, Original, Alias) :-
    effect_add(Target, [from,Home,[rename,[[Original,Alias]]]]).
effect_plan(Space, Call, Operations, Effect) :-
    space_module(Space, Module),
    with_metta_module(Module,
        metta_host_source_runtime_effect_plan(Module,Call,Operations,Effect)).

test(renamed_and_patterned_aliases_follow_the_body_without_executing_it,
     [forall(member(Target,['reference-effect-alias',['reference-effect-alias',_]])),
      setup(effect_spaces([Home,View,Unused])),
      cleanup(effect_cleanup([Home,View,Unused]))]) :-
    effect_add(Home, [':','reference-effect-body',[->,'Number','Number']]),
    effect_add(Home, [=,['reference-effect-body',N],[+,N,1]]),
    effect_reference(View,Home,'reference-effect-body',Target),
    effect_plan(View,['reference-effect-alias',4],Operations,Effect),
    assertion(Effect == pureStructural), assertion(member([+,pureStructural],Operations)),
    effect_add(Home,[=,['reference-effect-body',_],['random-int',1,6]]),
    effect_plan(View,['reference-effect-alias',4],Changed,After),
    assertion(After == oracleIO), assertion(member(['random-int',oracleIO],Changed)).

test(a_recursive_self_alias_terminates_at_its_shared_source,
     [setup(effect_spaces([Home,Other,Unused])),
      cleanup(effect_cleanup([Home,Other,Unused]))]) :-
    effect_add(Home,[':','reference-effect-recursive',[->,'Number','Number']]),
    effect_add(Home,[=,['reference-effect-recursive',N],
                    [if,['==',N,0],0,[+ ,1,['reference-effect-again',[-,N,1]]]]]),
    effect_reference(Home,Home,'reference-effect-recursive',['reference-effect-again',_]),
    effect_plan(Home,['reference-effect-again',4],Operations,Effect),
    assertion(Effect == pureStructural), assertion(member([+,pureStructural],Operations)).

test(equal_helper_names_in_distinct_homes_keep_distinct_effects,
     [setup(effect_spaces([Left,Right,View])),
      cleanup(effect_cleanup([Left,Right,View]))]) :-
    effect_add(Left,[=,['reference-effect-local',N],[+,N,1]]),
    effect_add(Right,[=,['reference-effect-local',_],['random-int',1,6]]),
    forall(member(Home,[Left,Right]),
           ( effect_add(Home,[internal,'reference-effect-local']),
             effect_add(Home,[':','reference-effect-entry',[->,'Number','Number']]),
             effect_add(Home,[=,['reference-effect-entry',N],['reference-effect-local',N]]),
             effect_reference(View,Home,'reference-effect-entry','reference-effect-joined') )),
    effect_plan(View,['reference-effect-joined',4],Operations,Effect),
    assertion(Effect == oracleIO), assertion(member([+,pureStructural],Operations)),
    assertion(member(['random-int',oracleIO],Operations)),
    once(spaces:metta_space_pair(View,[from,Right|_],Token,_)),
    once(spaces:metta_remove_occurrence(View,Token,true)),
    effect_plan(View,['reference-effect-joined',4],Remaining,After),
    assertion(After == pureStructural), assertion(\+ member(['random-int',_],Remaining)).

test(an_owned_body_wrapped_in_a_union_remains_visible_to_the_plan,
     [setup(effect_spaces([Left,Right,View])),
      cleanup(effect_cleanup([Left,Right,View]))]) :-
    effect_add(Left,[=,['reference-effect-wrapped',N],[+,N,1]]),
    effect_add(Right,[=,['reference-effect-wrapped',_],['random-int',1,6]]),
    effect_add(Left,[from,Right]),
    effect_reference(View,Left,'reference-effect-wrapped',['reference-effect-union',_]),
    effect_plan(View,['reference-effect-union',4],Operations,Effect),
    assertion(Effect == oracleIO), assertion(member([+,pureStructural],Operations)),
    assertion(member(['random-int',oracleIO],Operations)).

test(a_written_head_with_a_different_native_name_keeps_its_source,
     [setup(effect_spaces([Home,View,Unused])),
      cleanup(effect_cleanup([Home,View,Unused]))]) :-
    effect_add(Home,[=,['get-type',['reference-effect-tag']],['random-int',1,6]]),
    effect_reference(View,Home,'get-type','reference-effect-type-rule'),
    effect_plan(View,['reference-effect-type-rule',['reference-effect-tag']],Operations,Effect),
    assertion(Effect == oracleIO), assertion(member(['random-int',oracleIO],Operations)).

:- end_tests(reference_effects).
