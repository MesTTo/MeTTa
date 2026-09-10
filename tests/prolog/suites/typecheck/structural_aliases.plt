% Purpose: verify transparent alias substitution across type readers and edits.
% Assumes: each fixture owns a fresh native space; scratch files stay in ai-tmp.
% Guarantees: alias and direct-RHS programs agree through source, file and
%   reflective doors; edits repair retained callers without losing lexical
%   scope or raw source, and neither door installs a clause in a scope that
%   holds none [tested: run_tests(structural_aliases); commit=e471c116647ffc9d3949501b3f2d3869a9153bc2].
%   A shared scope's declaration observers cover every space, not &self's
%   alone [tested:
%   structural_aliases:a_shared_alias_is_hidden_by_a_declaration_added_to_another_space;
%   commit=60d6ca9089f50521bba869c3b7a87c92fd6a990f].
% Guarantees: an alias expands before the prelude's exact type match; an
%   untyped symbol does not acquire Atom from the requested cast target
%   [tested: cast_targets_expand_in_the_requested_scope; commit=WORKTREE].
% Owns resources: setup/cleanup releases each space and deletes each source file.
%   The shared-scope case declares an alias in the process-wide &self and
%   withdraws it in its body and again in its cleanup.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
% The two-thread orchestration lives in the probe so that the same sequence can
% be run against another checkout, which is how the commit constraint below was
% shown to be the thing that changes the outcome.
:- ensure_loaded('../../probes/type_alias_transaction_race.pl').

:- begin_tests(structural_aliases).

context(Space, Module) :-
    'new-space'(Space),
    space_module(Space, Module).

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

answers_in(Module, Term, Answers) :-
    with_metta_module(Module, findall(Answer, eval(Term, Answer), Answers)).

source_file(Source, Path) :-
    absolute_file_name('../../ai-tmp', Scratch, [file_type(directory)]),
    gensym('ai-alias-', Name),
    atom_concat(Name, '.metta', File),
    directory_file_path(Scratch, File, Path),
    setup_call_cleanup(open(Path, write, Out, [encoding(utf8)]),
                       format(Out, '~s', [Source]), close(Out)).

route(string, Space, Source, Answers) :- run_in(Space, Source, Answers).
route(host, Space, Source, Answers) :-
    filereader:metta_host_run_source(Source, Space, [], Groups),
    append(Groups, Carried),
    maplist(metta_answer_term, Carried, Answers).
route(file, Space, Source, Answers) :-
    setup_call_cleanup(source_file(Source, Path),
                       ( filereader:metta_host_load_file(Path, Space, Groups),
                         append(Groups, Carried),
                         maplist(metta_answer_term, Carried, Answers) ),
                       delete_file(Path)).
route(reflective, Space, Source, Answers) :-
    filereader:parse_metta_source(Source, Forms),
    space_module(Space, Module),
    route_forms(Forms, Space, Module, Answers).

route_forms([], _, _, []).
route_forms([parsed(runnable, _, Term, _)|Rest], Space, Module, Answers) :-
    !,
    answers_in(Module, Term, These),
    route_forms(Rest, Space, Module, More),
    append(These, More, Answers).
route_forms([parsed(_, _, Term)|Rest], Space, Module, Answers) :-
    metta_add_atom(Space, Term, true),
    route_forms(Rest, Space, Module, Answers).

% A complete arrow is deliberately a name rather than a list in the source.
program(false, "(: probe (-> (Number String) (Number String)))\n(= (probe $x) $x)\n!(probe (1 \"s\"))\n!(get-type probe)\n!(get-type (probe (1 \"s\")))\n").
program(true, "(: Count (Alias Number))\n(: Row (Alias (Count String)))\n(: Signature (Alias (-> Row Row)))\n(: probe Signature)\n(= (probe $x) $x)\n!(probe (1 \"s\"))\n!(get-type probe)\n!(get-type (probe (1 \"s\")))\n").

test(every_route_agrees_with_the_literal_rhs,
     [forall(member(Route, [string, host, file, reflective])),
      setup((context(Direct, _), context(Aliased, _))),
      cleanup((metta_release_space(Direct), metta_release_space(Aliased)))]) :-
    program(false, Plain), program(true, Alias),
    route(Route, Direct, Plain, Expected),
    route(Route, Aliased, Alias, Actual),
    assertion(Expected == [[1,"s"], [->,['Number','String'],['Number','String']],
                           ['Number','String']]),
    assertion(Actual == Expected).

test(count_accepts_number_and_refuses_string_with_source_and_expansion,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: count-id (-> Count Count)) (= (count-id $x) $x) !(count-id 1) !(count-id \"s\")", Answers),
    assertion(Answers == [1, ['Error',['count-id',"s"],
        ['BadArgType',1,'Count','String',
         ['TypeExpansion',[->,'Count','Count'],[->,'Number','Number']]]]]).

test(nested_tuple_fields_and_nested_arrows_expand,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: Row (Alias (Count String))) (: Nested (Alias (Row Bool))) (: nest (-> Nested Nested)) (= (nest $x) $x) !(nest ((1 \"s\") True))", Answers),
    assertion(Answers == [[[1,"s"],true]]),
    normalize_type_in(M, [->,[->,'Count','Row'],'Nested'], Canonical, _),
    assertion(Canonical == [->,[->,'Number',['Number','String']],
                            [['Number','String'],'Bool']]).

test(atom_alias_holds_arguments_and_results_at_all_call_doors,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Held (Alias Atom)) (: hold (-> Held Held)) (= (hold $x) $x) (= (caller) (hold (+ 1 2))) !(hold (+ 1 2)) !(caller) !(eval (hold (+ 1 2)))", Answers),
    assertion(Answers == [[+,1,2],[+,1,2],[+,1,2]]),
    answers_in(M, [hold,[+,1,2]], [[+,1,2]]),
    with_metta_module(M, ( once(translator:metta_runtime_argument_mask(hold, 1, Mask)),
                          assertion(Mask == [false]) )).

test(reflection_keeps_raw_source_while_type_observers_expand,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: item Count)", []),
    findall(T, match_stored(S, [':',item,T], T, _), Raw),
    assertion(Raw == ['Count']),
    assertion(match_stored(S, [':','Count',['Alias','Number']], true, true)),
    answers_in(M, ['get-type',item], ['Number']),
    answers_in(M, ['get-type-space',S,item], ['Number']).

test(repeated_rhs_variables_relate_and_separate_occurrences_freshen,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':','Duo',['Alias',[T,T]]], true),
    Raw = [->,Outer,'Duo','Duo',Outer],
    normalize_type_in(M, Raw, Expanded, _),
    Expanded = [->,First,[A,A],[B,B],Last],
    assertion(First == Outer), assertion(Last == Outer),
    assertion(A \== B), assertion(A \== Outer),
    assertion(var(T)),
    run_in(S, "(: pair (-> Duo Duo Atom)) (= (pair $a $b) (quote ($a $b))) !(pair (1 2) (\"x\" \"y\")) !(pair (1 \"bad\") (2 3))", [Good, Bad]),
    assertion(Good == [quote,[[1,2],["x","y"]]]),
    assertion(Bad = ['Error',_,['BadArgType',1,'Duo',_|_]]).

test(normalization_preserves_arrow_metadata,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    normalize_type_in(M, ['-[$e,stable]->','Count','Count'], Canonical, _),
    assertion(Canonical == ['-[$e,stable]->','Number','Number']).

test(missing_and_successful_lookups_are_dependencies,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':','Count',['Alias','Later']], true),
    normalize_type_in(M, 'Count', 'Later', Dependencies),
    metta_self_module(Self),
    assertion(memberchk(derived(M,type_alias('Count')), Dependencies)),
    assertion(memberchk(derived(M,type_alias('Later')), Dependencies)),
    assertion(memberchk(derived(Self,type_alias('Later')), Dependencies)).

test(late_addition_and_removal_repair_already_compiled_callers,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: identity (-> Count Count)) (= (identity $x) $x) (= (caller $x) (identity $x)) !(caller 7)", [Before]),
    assertion(Before = ['Error',_,_]),
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [caller,7], [7]),
    metta_remove_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [caller,7], [After]),
    assertion(After = ['Error',_,_]).

% The same repair for the OTHER scope. &self's aliases are visible from every
% module, so the declaration observers a shared scope installs cover every
% space rather than &self's own: a plain declaration added to a named space
% hides the shared alias for that space's readers, and the callers compiled
% under the expansion have to be repaired for it. set_type_alias_mutation_scope/2
% asks type_alias_scope_space/2 which space a scope covers and gets no binding
% back for `shared`, which is what installs those clauses as templates over
% every space; binding them to &self's space instead leaves this program
% answering 7 at every step [measured 2026-09-06 by planting exactly that
% binding].
test(a_shared_alias_is_hidden_by_a_declaration_added_to_another_space,
     [setup(context(S, M)),
      cleanup((metta_release_space(S),
               ignore(metta_remove_atom('&self',
                                        [':','Count',['Alias','Number']],
                                        true))))]) :-
    metta_add_atom('&self', [':','Count',['Alias','Number']], true),
    assertion(spaces:type_alias_mutation_scope_ref(shared, _)),
    run_in(S, "(: identity (-> Count Count)) (= (identity $x) $x) (= (caller $x) (identity $x)) !(caller 7)", Before),
    assertion(Before == [7]),
    metta_add_atom(S, [':','Count','String'], true),
    answers_in(M, [caller,7], [Hidden]),
    assertion(Hidden = ['Error',_,['BadArgType',1,'Count','Number']]),
    metta_remove_atom(S, [':','Count','String'], true),
    answers_in(M, [caller,7], Revealed),
    assertion(Revealed == [7]),
    metta_remove_atom('&self', [':','Count',['Alias','Number']], true),
    assertion(\+ spaces:type_alias_mutation_scope_ref(shared, _)).

test(deferred_equations_keep_raw_type_groups_until_they_compile,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Atom)) (: identity (-> Count Count)) (= (identity $x) $x)", []),
    metta_remove_atom(S, [':','Count',['Alias','Atom']], true),
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [identity,7], [7]),
    answers_in(M, [identity,"bad"], [Bad]),
    assertion(Bad = ['Error',_,['BadArgType',1,'Count','String'|_]]).

test(direct_cycle_is_rejected_without_storing_it,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    catch(metta_add_atom(S, [':','Loop',['Alias','Loop']], _), Error, true),
    assertion(Error == error(metta_type_alias_cycle([M:'Loop',M:'Loop']), none)),
    assertion(\+ match_stored(S, [':','Loop',_], true, true)).

test(indirect_cycle_names_the_path_and_keeps_previous_behavior,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: A (Alias B)) (: identity (-> A A)) (= (identity $x) $x) !(identity 7)", Before),
    catch(metta_add_atom(S, [':','B',['Alias','A']], _), Error, true),
    assertion(Error == error(metta_type_alias_cycle([M:'B',M:'A',M:'B']),none)),
    answers_in(M, [identity,7], After),
    assertion(After == Before),
    assertion(\+ match_stored(S, [':','B',_], true, true)).

test(conflict_rolls_back_the_enclosing_transaction,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: identity (-> Count Count)) (= (identity $x) $x) !(identity 7)", [7]),
    catch(transaction((metta_add_atom(S, [':','Other',['Alias','Bool']], true),
                       metta_add_atom(S, [':','Count',['Alias','String']], true))),
          Error, true),
    assertion(Error == error(metta_type_alias_conflict(S,'Count','Number','String'),none)),
    assertion(\+ match_stored(S, [':','Other',_], true, true)),
    answers_in(M, [identity,7], [7]).

test(variant_repetition_is_idempotent,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':','Duo',['Alias',[A,A]]], true),
    metta_add_atom(S, [':','Duo',['Alias',[B,B]]], true),
    findall(T, match_stored(S, [':','Duo',T], T, _), Rows),
    assertion(Rows = [['Alias',[X,X]]]).

test(source_prepass_uses_the_declared_prefix,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    catch(run_in(S, "(: identity Signature) (: Signature (Alias (-> Number Number))) (= (identity $x) $x)", _), Error, true),
    assertion(Error == error(metta_untypable_declaration(identity,'Signature'),none)),
    assertion(\+ match_stored(S, [':','Signature',_], true, true)).

test(malformed_and_reserved_aliases_are_refused,
     [setup(context(S, _)), cleanup(metta_release_space(S)),
      forall(member(Term, [[':',[applied,x],['Alias','Number']],
                           [':','Bad',['Alias','Number','String']],
                           [':','->',['Alias','Number']],
                           [':',':Atom',['Alias','Number']],
                           [':','Alias',['Alias','Number']],
                           [':','-[det]->',['Alias','Number']]]))]) :-
    catch(metta_add_atom(S, Term, _), Error, true),
    assertion(nonvar(Error)),
    assertion(\+ match_stored(S, Term, true, true)).

test(aliases_compose_with_annotated_arrow_projection,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: Signature (Alias (-[det]-> Count Count))) (: annotated Signature) (= (annotated $x) $x) !(annotated 7) !(annotated \"bad\") !(get-type annotated)", [Good,Bad,Reported]),
    assertion(Good == 7),
    assertion(Bad = ['Error',_,['BadArgType',1,'Number','String'|_]]),
    assertion(Reported == ['-[det]->','Number','Number']).

test(aliased_subtype_edges_preserve_order_duplicates_and_variables,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Species (Alias Dog)) (: Top (Alias Animal)) (: rex Species) (:< Species B) (:< Species C) (:< B Top) (:< C Top) !(get-type rex)", Answers),
    assertion(Answers == ['Dog','B','C','Animal','Animal']),
    answers_in(M, ['get-type-space',S,rex], Answers),
    run_in(S, "(: Box (Alias (Boxed $t))) (: boxed (Boxed Number)) (:< (Boxed $t) (Related $t $t)) !(get-type boxed)", Boxed),
    assertion(Boxed == [['Boxed','Number'],['Related','Number','Number']]).

test(cast_targets_expand_in_the_requested_scope,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: Held (Alias Atom)) !(type-cast 7 Count &self) !(type-cast \"bad\" Count &self) !(type-cast unknown Held &self) !(type-cast-holds 7 Count &self)", Answers),
    assertion(Answers == [7,['Error',"bad",'BadType'],['Error',unknown,'BadType'],true]).

test(late_alias_repairs_a_typed_binding,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (bound $x) (let (__metta_typed_binding__ (: $v Count)) $x $v)) !(bound 7)", []),
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [bound,7], [7]),
    metta_remove_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [bound,7], []).

test(alias_change_retires_and_rebuilds_a_specialization,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: step (-> Count Count)) (= (step $x) $x) (= (apply $f $x) ($f $x)) !(apply step 7)", [7]),
    assertion(ho_specialization(M, apply, _)),
    metta_remove_atom(S, [':','Count',['Alias','Number']], true),
    metta_add_atom(S, [':','Count',['Alias','String']], true),
    answers_in(M, [apply,step,"s"], ["s"]),
    answers_in(M, [apply,step,7], [Bad]),
    assertion(Bad = ['Error',_,_]).

test(releasing_the_owner_removes_aliases_and_supports,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: identity (-> Count Count)) (= (identity $x) $x) !(identity 7)", [7]),
    assertion(supports(derived(M,type_alias('Count')), _)),
    metta_release_space(S),
    assertion(\+ supports(derived(M,type_alias('Count')), _)),
    assertion(\+ match_stored(S, [':','Count',_], true, _)).

test(alias_repair_preserves_the_raw_arrival_groups_of_overloads,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: pick (-> Count Atom)) (= (pick $x) numeric) (: pick (-> String Atom)) (= (pick $x) textual) !(pick 7)", _),
    findall(B-T, translator:fun_meta_clause_types(M,pick,_,B,T), Before),
    metta_remove_atom(S, [':','Count',['Alias','Number']], true),
    findall(B-T, translator:fun_meta_clause_types(M,pick,_,B,T), After),
    assertion(Before == [textual-[[->,'String','Atom']],numeric-[[->,'Count','Atom']]]),
    assertion(After == Before).

test(a_variable_or_variable_head_type_is_not_an_alias_declaration,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':','Opaque',_], true),
    metta_add_atom(S, [':','PairLike',[_, 'Number']], true),
    normalize_type_in(M, ['Opaque','PairLike'], Expanded),
    assertion(Expanded == ['Opaque','PairLike']),
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    once(normalize_type_in(M, 'Count', 'Number')),
    normalize_type_in(M, ['Opaque','PairLike'], ActiveExpanded),
    assertion(ActiveExpanded == ['Opaque','PairLike']).

test(shared_families_accept_aliases_without_changing_their_gradual_rules,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: Held (Alias Atom)) (: Duo (Alias ($t $t)))", []),
    forall(member(Family, [ordinary, derived, reporting, witness]),
           ( assertion(typing_rule_accepts(M, Family, 'Number', 'Count')),
             assertion(typing_rule_accepts(M, Family, 'Count', 'Number')),
             assertion(\+ typing_rule_accepts(M, Family, 'String', 'Count')) )),
    assertion(typing_rule_accepts(M, ordinary, 'Number', 'Held')),
    assertion(\+ typing_rule_accepts(M, derived, 'Number', 'Held')),
    assertion(\+ typing_rule_accepts(M, reporting, 'Number', 'Held')),
    assertion(typing_rule_accepts(M, witness, 'Number', 'Held')),
    assertion(typing_rule_accepts(M, ordinary, '%Undefined%', 'Count')),
    assertion(\+ typing_rule_accepts(M, witness, '%Undefined%', 'Count')),
    assertion(typing_rule_accepts(M, widening, 'BigInt', 'Count')),
    assertion(typing_rule_expected(M, metatype, 'Held')),
    assertion(typing_rule_accepts(M, ordinary, ['Number','Number'], 'Duo')),
    assertion(\+ typing_rule_accepts(M, ordinary, ['Number','String'], 'Duo')).

test(alias_rule_patterns_repair_a_caller_that_predates_the_alias,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: f (-> Number Number)) (= (f $x) $x) (= (caller $x) (f $x)) !(add-typing-rule! deny ordinary Count Count (refuse denied)) !(caller 7)", [true,7]),
    metta_add_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [caller,7], [Denied]),
    assertion(Denied = ['Error',_,['BadArgType',_,_,_,['TypingRuleRefusal',deny,denied]]]),
    assertion(registered_typing_rule(user, M, deny, ordinary,
                                      'Number', 'Number', [refuse,denied])),
    assertion(raw_registered_typing_rule(user, M, deny, ordinary,
                                          'Count', 'Count', [refuse,denied])),
    assertion(\+ typing_rule_accepts(M, witness, 'Number', 'Count')),
    assertion(typing_rule_refusal(M, ordinary, 'Number', 'Count', deny, denied)),
    metta_remove_atom(S, [':','Count',['Alias','Number']], true),
    answers_in(M, [caller,7], [7]).

test(bound_observers_and_admission_expand_the_expected_type,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Count (Alias Number)) (: Meta (Alias Grounded))", []),
    with_metta_module(M,
        ( assertion('get-type'(7, 'Count')),
          assertion(\+ 'get-type'("bad", 'Count')),
          assertion('get-metatype'(7, 'Meta')),
          assertion('get-type-space'(S, 7, 'Count')),
          assertion(\+ 'get-type-space'(S, "bad", 'Count')),
          assertion('has-declared-type'(7, 'Count', true)),
          assertion('has-declared-type'("bad", 'Count', false)) )).

normalization_cost(Module, Count) :-
    statistics(inferences, Before),
    normalize_type_in(Module, 'Number', 'Number'),
    statistics(inferences, After),
    Count is After - Before.

test(alias_readers_cost_only_their_visible_scope_and_retire_transactionally,
     [setup((context(A, MA), context(B, MB))),
      cleanup((metta_release_space(A), metta_release_space(B)))]) :-
    normalization_cost(MB, Plain),
    metta_add_atom(A, [':','Count',['Alias','Number']], true),
    normalization_cost(MB, Unrelated),
    assertion(Unrelated == Plain),
    catch(transaction((metta_add_atom(B, [':','Count',['Alias','Number']], true),
                       throw(abort_alias))), abort_alias, true),
    normalization_cost(MB, RolledBack),
    assertion(RolledBack == Plain),
    assertion(\+ type_alias_gate_ref(local(MB), _)),
    metta_add_atom(B, [':','Count',['Alias','Number']], true),
    once(normalization_cost(MB, Active)),
    assertion(Active > Plain),
    metta_remove_atom(B, [':','Count',['Alias','Number']], true),
    normalization_cost(MB, Retired),
    assertion(Retired == Plain),
    assertion(type_alias_gate_ref(local(MA), _)),
    assertion(\+ spaces:type_alias_mutation_scope_ref(local(MB), _)).

% Two transactions whose snapshots overlap each read a state the other's write
% is not in, so the declaration-time check passes in both and the space used to
% end up holding both aliases. The probe fixes the interleaving, so this asserts
% an outcome rather than sampling a race.
test(overlapping_transactions_leave_one_alias_and_name_the_loser) :-
    overlapping_alias_declarations(Declarations, Outcomes),
    assertion(one_alias_survives(Declarations, Outcomes)).

% The pending list a commit re-validates is recorded with nb_setval, which does
% not unwind on backtracking, so a nested transaction that declares an alias and
% then rolls back leaves its entry behind. Validating that entry would refuse
% the outer commit over a declaration that is no longer there.
test(a_rolled_back_nested_declaration_does_not_refuse_the_outer_commit,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    metta_transaction(
        ( \+ metta_transaction(( metta_add_atom(S, [':','Count',['Alias','Number']],
                                                true),
                                 fail )),
          metta_add_atom(S, [':','Count',['Alias','String']], true) )),
    findall(T, match_stored(S, [':','Count',T], T, _), Rows),
    assertion(Rows == [['Alias','String']]).

removal_door_clauses(Count) :-
    findall(Ref, clause(spaces:metta_remove_atom(_, _, _), _, Ref), Refs),
    length(Refs, Count).

withdrawal_cost(Space, Name, Count) :-
    metta_add_atom(Space, [':', Name, 'Number'], true),
    statistics(inferences, Before),
    metta_remove_atom(Space, [':', Name, 'Number'], true),
    statistics(inferences, After),
    Count is After - Before.

% The rule the readers above obey holds for the WITHDRAWAL door as well: a
% scope with no alias keeps the ordinary removal clauses and installs nothing
% in front of them. This clause left standing unconditionally cost the
% register-op benchmark 12,502 inferences over 100 registrations in a space
% that declares no alias at all, 2,899 of them once for the execution module
% its space_module/2 materialized and 97 per later cycle for a transaction and
% an invalidation sweep over a support graph holding no alias root
% [measured 2026-09-05, 103723 -> 116225;
% command=extensions/python/bench.py --counter-only register-op].
test(a_scope_without_an_alias_installs_no_withdrawal_clause,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    withdrawal_cost(S, 'Warm', _),
    removal_door_clauses(Plain),
    withdrawal_cost(S, 'Tally', Ordinary),
    removal_door_clauses(Unchanged),
    assertion(Unchanged =:= Plain),
    metta_add_atom(S, [':', 'Count', ['Alias', 'Number']], true),
    removal_door_clauses(Gated),
    assertion(Gated =:= Plain + 1),
    assertion(spaces:type_alias_mutation_scope_ref(local(M), _)),
    withdrawal_cost(S, 'Ledger', Aliased),
    assertion(Aliased > Ordinary),
    metta_remove_atom(S, [':', 'Count', ['Alias', 'Number']], true),
    removal_door_clauses(Retired),
    assertion(Retired =:= Plain).

:- end_tests(structural_aliases).
