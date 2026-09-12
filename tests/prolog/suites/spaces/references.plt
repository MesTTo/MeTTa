% Purpose: exercise reference meaning, multiplicity, visibility and withdrawal.
% Owns resources: each test releases its fresh native spaces in reverse order.
% Guarantees: comparisons inspect answer bags, stored occurrence identities and
%   SWI's actual import property [tested: references; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(ugraphs), [vertices_edges_to_ugraph/3, transitive_closure/2]).

:- begin_tests(references).

reference_setup :-
    metta_host_set_silent(true),
    findall(Space, (between(1, 4, _), gensym('&reference-test-', Space)), Spaces),
    maplist(reference_create, Spaces), nb_setval(reference_test_spaces, Spaces).
reference_create(Space) :- space_module(Space, _).
reference_space(Index, Space) :- nb_getval(reference_test_spaces, Spaces), nth1(Index, Spaces, Space).
reference_cleanup :-
    nb_getval(reference_test_spaces, Spaces), reverse(Spaces, Reversed),
    maplist(metta_release_space, Reversed), nb_delete(reference_test_spaces),
    metta_host_set_silent(false).
reference_add(Index, Row) :- reference_space(Index, Space), metta_add_atom(Space, Row, _).
reference_from(Target, Source, Map) :-
    reference_space(Source, Home), reference_add(Target, [from, Home, Map]).
reference_from(Target, Source) :-
    reference_space(Source, Home), reference_add(Target, [from, Home]).
reference_answers(Index, Call, Bag) :-
    reference_space(Index, Space), findall(R, evalc(Call, Space, R), Answers),
    msort(Answers, Bag).

test(a_same_name_binding_is_native_and_its_body_resolves_at_home,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-f', X], ['reference-helper', X]]),
    reference_add(1, [=, ['reference-helper', 1], home]),
    reference_add(2, [=, ['reference-helper', 1], caller]),
    reference_from(2, 1),
    reference_answers(2, ['reference-f', 1], Bag), assertion(Bag == [home]),
    reference_space(1, Home), space_module(Home, Source),
    reference_space(2, Target), space_module(Target, Module),
    assertion(predicate_property(Module:'reference-f'(_, _), imported_from(Source))).

test(one_face_publication_recompiles_a_shared_caller_once,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-left'], 2]),
    reference_add(1, [=, ['reference-right'], 3]),
    reference_add(2, [=, ['reference-sum'],
                      [+, ['reference-left'], ['reference-right']]]),
    reference_from(2, 1),
    reference_space(2, Target), space_module(Target, Module),
    flag(reference_repairs, _, 0),
    setup_call_cleanup(
        wrap_predicate(filereader:recompile_function_in_module_stable(Owner, Name),
                       reference_repairs, Original,
                       ( ( Owner == Module, Name == 'reference-sum'
                         -> flag(reference_repairs, N, N+1) ; true ),
                         call(Original) )),
        ( metta_engine:metta_reference_refresh,
          flag(reference_repairs, Count, Count), assertion(Count == 1),
          reference_answers(2, ['reference-sum'], Bag), assertion(Bag == [5]) ),
        unwrap_predicate(filereader:recompile_function_in_module_stable(_, _),
                         reference_repairs)).

test(every_arity_travels_and_actual_equation_duplicates_survive,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-many'], zero]),
    reference_add(1, [=, ['reference-many', X], X]),
    reference_add(1, [=, ['reference-many', X], X]),
    reference_from(2, 1),
    reference_answers(2, ['reference-many'], Zero), assertion(Zero == [zero]),
    reference_answers(2, ['reference-many', 7], One), assertion(One == [7,7]).

test(enumerating_a_write_answer_mutates_exactly_one_occurrence,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_from(2, 1), reference_space(1, Home),
    findall(R, metta_add_atom(Home, [data, once], R), Added),
    assertion(Added == [true]),
    findall(T, spaces:metta_native_pair(Home, [data, once], T, _), Tokens),
    assertion(length(Tokens, 1)),
    reference_add(1, [=, ['reference-duplicate'], 9]),
    reference_add(1, [=, ['reference-duplicate'], 9]),
    findall(R, metta_remove_atom(Home, [=, ['reference-duplicate'], 9], R), Removed),
    assertion(Removed == [true]),
    reference_answers(1, ['reference-duplicate'], Own), assertion(Own == [9]),
    reference_answers(2, ['reference-duplicate'], Linked), assertion(Linked == [9]).

test(references_and_own_equations_form_a_union,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_add(1, [=, ['reference-union'], a]),
    reference_add(1, [=, ['reference-union'], a]),
    reference_add(2, [=, ['reference-union'], b]),
    reference_add(3, [=, ['reference-union'], c]),
    reference_from(3, 1), reference_from(3, 2),
    reference_answers(3, ['reference-union'], Bag), assertion(Bag == [a,a,b,c]),
    reference_space(3, Target), space_module(Target, Module),
    findall(Origins,
            head_pattern_note(Module, 'reference-union', [], _, reference_union(Origins)),
            Notes),
    assertion(Notes \== []),
    reference_space(2, Other), metta_remove_atom(Target, [from, Other], true),
    reference_answers(3, ['reference-union'], Left), assertion(Left == [a,a,c]).

test(two_paths_to_one_home_do_not_duplicate_its_occurrences,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-diamond'], a]),
    reference_add(1, [=, ['reference-diamond'], a]),
    reference_from(2, 1), reference_from(3, 1),
    reference_from(4, 2), reference_from(4, 3),
    reference_answers(4, ['reference-diamond'], Bag), assertion(Bag == [a,a]).

test(cycles_are_bounded_even_when_maps_change_names,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-a'], a]),
    reference_add(2, [=, ['reference-b'], b]),
    reference_from(1, 2, [prefix, 'x.']),
    reference_from(2, 1, [prefix, 'y.']),
    reference_answers(1, ['x.reference-b'], A), assertion(A == [b]),
    reference_answers(2, ['y.reference-a'], B), assertion(B == [a]),
    reference_space(1, Space),
    metta_engine:metta_reference_face(Space, [], Face), assertion(length(Face, 2)).

test(a_standing_row_follows_new_heads_and_their_later_withdrawal,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_from(2, 1),
    reference_add(1, [=, ['reference-late'], arrived]),
    reference_answers(2, ['reference-late'], Bag), assertion(Bag == [arrived]),
    reference_space(1, Home),
    metta_remove_atom(Home, [=, ['reference-late'], arrived], true),
    reference_answers(2, ['reference-late'], Gone),
    assertion(Gone == [['reference-late']]).

test(a_local_equation_can_arrive_after_a_native_import,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-later-own'], a]), reference_from(2, 1),
    reference_add(2, [=, ['reference-later-own'], b]),
    reference_answers(2, ['reference-later-own'], Bag), assertion(Bag == [a,b]).

test(prefix_rename_lambda_empty_and_multiple_names_compose,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-map'], mapped]),
    reference_from(2, 1, [rename, [['reference-map', renamed]]]),
    reference_from(3, 1, ['|->', [H], [superpose, [H, [atom_concat, 'q.', H]]]]),
    reference_from(4, 1, [except, ['reference-map']]),
    reference_answers(2, [renamed], Renamed), assertion(Renamed == [mapped]),
    reference_answers(3, ['q.reference-map'], Qualified), assertion(Qualified == [mapped]),
    reference_answers(3, ['reference-map'], Plain), assertion(Plain == [mapped]),
    reference_answers(4, ['reference-map'], Absent), assertion(Absent == [['reference-map']]).

test(a_bad_mapper_refuses_and_does_not_leave_its_row,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-bad-map'], a]),
    reference_space(1, Home), reference_space(2, Target),
    Row = [from, Home, ['|->', [_], 7]],
    catch(metta_add_atom(Target, Row, _), Error, true),
    assertion(Error = error(metta_reference_map_result(_, 'reference-bad-map', 7), _)),
    assertion(\+ get_native_atom(Target, [from|_])),
    reference_answers(2, ['reference-bad-map'], Bag),
    assertion(Bag == [['reference-bad-map']]).

test(internal_is_an_occurrence_grade_and_direct_home_calls_still_work,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_add(1, [internal, 'reference-private']),
    reference_add(1, [=, ['reference-private'], secret]),
    reference_add(1, [':', 'reference-private', [->, 'Symbol']]),
    reference_add(1, ['@doc', 'reference-private', [description, secret]]),
    reference_add(1, [=, ['reference-public'], public]),
    reference_from(2, 1), reference_space(1, Home),
    findall(Token,
            ( spaces:metta_native_pair(Home, Row, Token, _),
              metta_engine:metta_reference_row_head(Row, 'reference-private') ), Tokens),
    assertion(length(Tokens, 3)),
    forall(member(Token, Tokens),
           assertion(metta_engine:metta_occurrence_grade(Home, Token, visibility, 'INTERNAL'))),
    reference_answers(1, ['reference-private'], Own), assertion(Own == [secret]),
    reference_answers(2, ['reference-private'], Hidden), assertion(Hidden == [['reference-private']]),
    reference_answers(2, ['reference-public'], Public), assertion(Public == [public]),
    catch(reference_from(3, 1, [only, ['reference-private']]), Error, true),
    assertion(Error = error(metta_internal_reference(Home, 'reference-private'), _)),
    metta_remove_atom(Home, [internal, 'reference-private'], true),
    reference_answers(2, ['reference-private'], NowPublic), assertion(NowPublic == [secret]).

test(metadata_is_projected_but_data_is_not_and_equal_owned_docs_survive,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    Doc = ['@doc', 'reference-doc', [description, text]],
    reference_add(1, [=, ['reference-doc', X], X]),
    reference_add(1, [':', 'reference-doc', [->, 'Number', 'Number']]),
    reference_add(1, Doc), reference_add(1, [data, retained]),
    reference_add(2, Doc), reference_from(2, 1),
    reference_space(2, Target), reference_space(1, Home),
    assertion(get_native_atom(Target, [':', 'reference-doc', [->, 'Number', 'Number']])),
    assertion(\+ get_native_atom(Target, [data, retained])),
    findall(Ref, spaces:metta_native_pair(Target, Doc, _, Ref), Before),
    assertion(length(Before, 2)),
    metta_remove_atom(Target, [from, Home], true),
    findall(Ref, spaces:metta_native_pair(Target, Doc, _, Ref), After),
    assertion(After = [Own]), assertion(Before = [Own|_]).

test(rollback_restores_native_links_and_nested_rollback_restores_its_parent,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_add(1, [=, ['reference-rollback'], a]),
    reference_add(2, [=, ['reference-rollback'], b]),
    reference_space(1, A), reference_space(2, B), reference_space(3, Target),
    reference_from(3, 1),
    \+ transaction((metta_remove_atom(Target, [from, A], true),
                    metta_add_atom(Target, [from, B], _), fail)),
    reference_answers(3, ['reference-rollback'], Restored), assertion(Restored == [a]),
    transaction((metta_add_atom(Target, [from, B], _),
                 \+ transaction((metta_remove_atom(Target, [from, A], true), fail)),
                 reference_answers(3, ['reference-rollback'], Parent),
                 assertion(Parent == [a,b]))),
    reference_answers(3, ['reference-rollback'], Committed), assertion(Committed == [a,b]).

test(inner_failure_transfers_one_watch_and_outer_completion_retires_it,
     [forall(member(Outcome,[commit,rollback])),
      setup(reference_setup),
      cleanup((nb_delete(reference_test_failed_frame),reference_cleanup))]) :-
    reference_add(1, [=, ['reference-watch'], visible]), reference_from(2,1),
    metta_engine:metta_reference_pending_frames(Initial), assertion(Initial == []),
    Scope = transaction((
        metta_engine:metta_reference_track_transaction,
        metta_engine:metta_reference_pending_frames(Before),
        assertion(Before = [_]), Before = [Outer],
        \+ transaction((
            metta_engine:metta_reference_track_transaction,
            metta_engine:metta_reference_pending_frames([Inner|_]),
            assertion(Inner \== Outer),
            nb_setval(reference_test_failed_frame, Inner),
            reference_add(1, [internal, 'reference-watch']), fail)),
        metta_engine:metta_reference_pending_frames(After),
        assertion(After == [Outer]),
        nb_getval(reference_test_failed_frame, Finished),
        assertion(\+ memberchk(Finished, After)),
        reference_answers(2, ['reference-watch'], Restored),
        assertion(Restored == [visible]),
        Outcome == commit)),
    ( Outcome == commit -> call(Scope) ; \+ call(Scope) ),
    metta_engine:metta_reference_pending_frames(Retired), assertion(Retired == []),
    assertion(\+ metta_engine:metta_reference_finishing(_)).

test(the_bulk_data_loop_executes_from_and_internal_rows,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-bulk'], value]),
    reference_space(1, Home), reference_space(2, Target),
    metta_add_program_atoms(Target, [[from, Home], [internal, 'reference-bulk']]),
    reference_answers(2, ['reference-bulk'], Own), assertion(Own == [value]),
    reference_from(3, 2),
    reference_answers(3, ['reference-bulk'], Hidden), assertion(Hidden == [['reference-bulk']]).

test(visibility_is_a_checked_two_element_lattice,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    metta_catalog_row([algebra, visibility, max, min, 'INTERNAL', 'PUBLIC',
                       Laws, Carrier, Requires, global]),
    assertion(Carrier == [carrier,'INTERNAL','PUBLIC']),
    Row = [algebra, visibility, max, min, 'INTERNAL', 'PUBLIC', Laws, Carrier, Requires, global],
    spaces:metta_check_algebra_fields(visibility, max, min, 'INTERNAL', 'PUBLIC',
                                     Laws, Carrier, Requires, Row),
    reference_space(1, Space),
    catch(metta_with_under(visibility, metta_k_extend(Space, 'PUBLIC', 1, _)), Error, true),
    assertion(Error = error(metta_algebra_value_outside_carrier(visibility, 1, Carrier), _)).

test(a_map_runs_once_per_head_even_across_arities_and_refreshes,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_space(3, Counter), reference_space(1, Home), reference_space(2, Target),
    Map = ['|->', [H], [let, _, ['add-atom', Counter, [mapped,H]], H]],
    reference_add(1, [=, ['reference-once'], zero]),
    reference_from(2, 1, Map),
    reference_add(1, [=, ['reference-once', X], X]),
    reference_add(1, ['@doc', 'reference-once', [description, same_head]]),
    reference_add(1, [=, ['reference-next'], new_head]),
    findall(H, get_native_atom(Counter, [mapped,H]), Heads),
    assertion(Heads == ['reference-once','reference-next']),
    metta_remove_atom(Target, [from, Home, Map], true),
    reference_from(2, 1, Map),
    findall(H, get_native_atom(Counter, [mapped,H]), Again), assertion(length(Again,4)).

test(transitive_selection_does_not_report_a_defined_head_missing,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-transitive'], here]), reference_from(2,1),
    reference_from(3, 2, [only,['reference-transitive']]),
    reference_space(2, Home), space_module(Home, Module),
    assertion(\+ head_pattern_note(Module,'reference-transitive',[],_,reference_missing(Home))),
    reference_answers(3, ['reference-transitive'], [here]).

test(withdrawal_retires_the_row_support_and_mapping_cache,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_add(1, [=, ['reference-retire'], here]),
    reference_space(1, Home), reference_space(2, Target), space_module(Target, Module),
    metta_add_atom(Target, [from,Home], Token, true),
    assertion(supports(derived(_,reference_face),derived(Module,reference_row(Token)))),
    metta_remove_atom(Target,[from,Home],true),
    assertion(\+ supports(_,derived(Module,reference_row(Token)))),
    assertion(\+ supports(derived(Module,reference_row(Token)),_)),
    assertion(\+ metta_engine:metta_reference_map(Token,_,_)),
    assertion(\+ supports(_,derived(Module,reference('reference-retire',1)))).

test(releasing_a_source_withdraws_its_old_lifetime_from_receivers,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-release'], old]), reference_from(2,1),
    reference_space(1, Home), metta_release_space(Home),
    reference_answers(2, ['reference-release'], [['reference-release']]),
    reference_add(1, [=, ['reference-release'], new]),
    reference_answers(2, ['reference-release'], [['reference-release']]),
    reference_from(2,1), reference_answers(2, ['reference-release'], [new]).

test(a_reused_receiver_inherits_no_union_wrapper,
     [setup(reference_setup), cleanup(reference_cleanup)]) :-
    reference_add(1, [=, ['reference-reuse'], imported]),
    reference_add(2, [=, ['reference-reuse'], own]), reference_from(2,1),
    reference_space(2, Target), metta_release_space(Target),
    reference_add(2, [=, ['reference-reuse'], new]),
    reference_answers(2, ['reference-reuse'], [new]),
    assertion(\+ metta_engine:metta_reference_slot(_, 'reference-reuse', _, _)).

test(a_compiled_caller_is_repaired_when_a_reference_arrives_and_leaves,
     [setup(reference_setup), cleanup(reference_cleanup), nondet]) :-
    reference_add(2, [=, ['reference-caller'], ['reference-callee']]),
    reference_answers(2, ['reference-caller'], [['reference-callee']]),
    reference_add(1, [=, ['reference-callee'], here]), reference_from(2,1),
    reference_answers(2, ['reference-caller'], [here]),
    reference_space(1, Home), reference_space(2, Target),
    metta_remove_atom(Target,[from,Home],true),
    reference_answers(2, ['reference-caller'], [['reference-callee']]).

test(every_three_vertex_graph_preserves_reachable_occurrence_bags) :-
    forall((between(0,63,Edges),between(0,7,Private)),
           setup_call_cleanup(reference_setup,
                              reference_graph_case(Edges,Private), reference_cleanup)).

reference_graph_case(EdgeMask, PrivateMask) :-
    forall(between(1,3,I),
           ( reference_add(I,[=,['reference-graph'],I]),
             ( I mod 2 =:= 1 -> reference_add(I,[=,['reference-graph'],I]) ; true ),
             ( PrivateMask /\ (1 << (I-1)) =\= 0
             -> reference_add(I,[internal,'reference-graph']) ; true ) )),
    findall(I-J,(between(1,3,I),between(1,3,J),I =\= J), Candidates),
    findall(I-J,(nth0(Bit,Candidates,I-J), EdgeMask /\ (1 << Bit) =\= 0), Edges),
    forall(member(I-J,Edges),reference_from(I,J)),
    % A private vertex contributes no outward face. Transitive closure of the
    % remaining edges is an independent graph oracle, separate from the linker.
    findall(I-J,(member(I-J,Edges),PrivateMask /\ (1 << (J-1)) =:= 0), Public),
    vertices_edges_to_ugraph([1,2,3],Public,Graph),transitive_closure(Graph,Closure),
    forall(member(I-Reachable,Closure),
           ( sort([I|Reachable],Roots),
             findall(R,(member(R,Roots),Count is 1+(R mod 2),between(1,Count,_)),Expected),
             reference_answers(I,['reference-graph'],Actual),
             assertion(Actual == Expected) )).

:- end_tests(references).
