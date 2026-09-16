% Purpose: verify FROM source elaboration, supplied values and reader ownership.
% Assumes: ordinary global tokens and callable reference unions retain their
%   existing meaning [source: engine/metta/control.pl:register_metta_token/2,
%   engine/metta/references.pl:metta_reference_binding/6; commit=1a8c00f93ae6c63ccabd41d39fed3f967dadd3a9].
% Owns resources: every test releases its generated homes in reverse order;
%   callback and observation controls withdraw their exact installed clauses.
% Guarantees: the controls cover both data doors, supplied values,
%   shape-changing and malformed rewriters, mapper cycles, callable unions,
%   withdrawal, diamonds, ambiguity, rollback, type aliases and observation
%   alignment, each in four fresh homes released afterwards
%   [tested: reference_source_origins; commit=1a8c00f93ae6c63ccabd41d39fed3f967dadd3a9].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

% A public Prolog function is the mapper's effectful callback. The bound
% counter makes a missing cycle check fail before unbounded source recursion.
user:plunit_origin_source_map(Space, _, 'OriginPoint') :-
    nb_getval(reference_origin_map_count, Before), Count is Before+1,
    nb_setval(reference_origin_map_count, Count),
    ( Count < 3 -> true ; throw(error(origin_mapper_counter_limit, none)) ),
    nb_getval(reference_origin_map_mode, Mode),
    ( Mode == source
    -> filereader:metta_host_run_source("!(noeval OriginPoint)", Space, [], _)
    ; metta_engine:evalc([noeval, 'OriginPoint'], Space, 'OriginPoint') ).

:- begin_tests(reference_source_origins).

origin_setup :-
    metta_host_set_silent(true),
    findall(Space, (between(1, 4, _), gensym('&reference-origin-', Space)), Spaces),
    maplist(origin_create, Spaces), nb_setval(reference_origin_spaces, Spaces),
    origin_add(1, [':', 'OriginCanonicalA', ['->', 'Number', 'OriginRecord']]),
    origin_add(2, [':', 'OriginCanonicalB', ['->', 'Number', 'OriginRecord']]).
origin_create(Space) :- space_module(Space, _).
origin_space(Index, Space) :-
    nb_getval(reference_origin_spaces, Spaces), nth1(Index, Spaces, Space).
origin_cleanup :-
    nb_getval(reference_origin_spaces, Spaces), reverse(Spaces, Reversed),
    maplist(metta_release_space, Reversed), nb_delete(reference_origin_spaces),
    metta_host_set_silent(false).
origin_add(Index, Row) :- origin_space(Index, Space), metta_add_atom(Space, Row, _).
origin_from(Target, Provider, Original) :-
    origin_space(Provider, Home),
    origin_add(Target, [from, Home, [rename, [[Original, 'OriginPoint']]]]).
origin_groups(Index, Source, Groups) :-
    origin_space(Index, Space), origin_run(Source, Space, [], Groups).
origin_run(Source, Space, Bindings, Groups) :-
    filereader:metta_host_run_source(Source, Space, Bindings, Tagged),
    maplist(maplist(filereader:metta_answer_term), Tagged, Groups).

test(two_homes_author_construct_and_match_their_own_canonical_values,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_from(4, 2, 'OriginCanonicalB'),
    forall(member(Index-Canonical, [3-'OriginCanonicalA', 4-'OriginCanonicalB']),
           ( origin_groups(Index,
                 "(seed (OriginPoint 7)) (other (OriginPoint 8))\n\c
                  !(noeval (OriginPoint 9))\n\c
                  !(match &self (seed (OriginPoint $x)) $x)\n\c
                  !(get-type (OriginPoint 9))", Groups),
             assertion(Groups == [[[Canonical,9]], [7], ['OriginRecord']]),
             origin_space(Index, Space),
             assertion(spaces:metta_space_pair(Space, [seed,[Canonical,7]], _, _)),
             findall(Type, evalc(['get-type',[Canonical,9]], Space, Type), Types),
             assertion(Types == ['OriginRecord']) )).

test(source_follows_executed_prefix_despite_future_function_registration,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(1, Home),
    format(string(Source),
           '!(noeval (OriginPoint 1))\n\c
            (from ~w (rename ((OriginCanonicalA OriginPoint))))\n\c
            !(noeval (OriginPoint 2))\n\c
            (= (OriginPoint $x) (noeval (LocalPoint $x)))\n\c
            !(OriginPoint 3)', [Home]),
    origin_groups(3, Source, Groups),
    assertion(Groups == [[['OriginPoint',1]], [['OriginCanonicalA',2]], [['LocalPoint',3]]]).

test(declarations_introduce_names_but_nested_declarations_and_equations_are_uses,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'),
    origin_groups(3,
        "!(noeval (: OriginPoint Type))\n\c
         !(noeval (= (OriginPoint 1) (OriginPoint 2)))", Nested),
    assertion(Nested == [[[':', 'OriginCanonicalA', 'Type']],
                         [[=, ['OriginCanonicalA',1], ['OriginCanonicalA',2]]]]),
    origin_groups(3, "(: OriginPoint (-> Number OriginPoint))\n!(noeval (OriginPoint 3))", Local),
    assertion(Local == [[['OriginPoint',3]]]),
    origin_space(3, Space),
    metta_remove_atom(Space, [':','OriginPoint',['->','Number','OriginPoint']], true),
    origin_groups(3, "!(noeval (OriginPoint 4))", Restored),
    assertion(Restored == [[['OriginCanonicalA',4]]]).

test(explicit_atom_values_keep_their_origins_inside_nested_source,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_space(3, Space),
    origin_run(
        "!(noeval (Pair (OriginPoint 1) Held (Leaf 2)))", Space,
        ['Held'-['OriginPoint',9], 'Leaf'-'OriginPoint'], Groups),
    assertion(Groups == [[['Pair',['OriginCanonicalA',1],['OriginPoint',9],['OriginPoint',2]]]]).

origin_expand([noeval, ['origin-expand', Value]], Origins,
              [noeval, [expanded, Value, ['OriginPoint',3]]],
              children([source, children([source, ValueOrigin, source])])) :- !,
    filereader:source_children(Origins, [noeval, ['origin-expand',Value]], [_, Inner]),
    filereader:source_children(Inner, ['origin-expand',Value], [_, ValueOrigin]).
origin_expand(Term, Origins, Term, Origins).

test(a_shape_changing_rewriter_transports_supplied_origins_and_new_source,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_space(3, Space),
    setup_call_cleanup(
        asserta(seam:form_rewriter(plunit_reference_source_origins:origin_expand), Ref),
        ( origin_run("!(noeval (origin-expand Held))", Space,
              ['Held'-['OriginPoint',9]], Groups),
          assertion(Groups == [[[expanded,['OriginPoint',9],['OriginCanonicalA',3]]]]) ),
        erase(Ref)).

origin_bad_shape(_, _, [noeval, ['OriginPoint',3]], children([source])).

test(a_rewriter_cannot_silently_lose_its_origin_tree,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    setup_call_cleanup(
        asserta(seam:form_rewriter(plunit_reference_source_origins:origin_bad_shape), Ref),
        ( catch(origin_groups(3, "!(noeval 1)", _), Error, true),
          assertion(Error == error(metta_source_origins(
              [noeval,['OriginPoint',3]], children([source])), none)) ),
        erase(Ref)).

origin_mutate(add, Space, Row, Term, Origins, Term, Origins) :-
    metta_add_atom(Space, Row, _).
origin_mutate(remove, Space, Row, Term, Origins, Term, Origins) :-
    metta_remove_atom(Space, Row, true).

test(the_same_form_sees_from_changes_made_by_its_rewriter,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(1, Home), origin_space(3, Target),
    Row = [from,Home,[rename,[['OriginCanonicalA','OriginPoint']]]],
    forall(member(Action-Expected, [add-'OriginCanonicalA', remove-'OriginPoint']),
           setup_call_cleanup(
               asserta(seam:form_rewriter(
                   plunit_reference_source_origins:origin_mutate(Action, Target, Row)), Ref),
               ( origin_groups(3, "!(noeval (OriginPoint 5))", Groups),
                 assertion(Groups == [[[Expected,5]]]) ),
               erase(Ref))).

origin_forget_source_map(Target, Home, Map) :-
    metta_remove_atom(Target, [from,Home,Map], _),
    unregister_fun_everywhere(plunit_origin_source_map),
    retractall(fun(plunit_origin_source_map)),
    retractall(arity(plunit_origin_source_map, _)),
    nb_delete(reference_origin_map_count), nb_delete(reference_origin_map_mode).

test(an_unfinished_map_cannot_recursively_supply_its_own_source_names,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(1, Home), origin_space(3, Target),
    Map = ['|->', [Head], [plunit_origin_source_map, Target, Head]],
    setup_call_cleanup(
        ( import_prolog_function(plunit_origin_source_map, true),
          nb_setval(reference_origin_map_count, 0),
          nb_setval(reference_origin_map_mode, source) ),
        ( catch(metta_add_atom(Target, [from,Home,Map], _), Error, true),
          assertion(Error == error(metta_source_mapping_cycle(Target), none)),
          nb_getval(reference_origin_map_count, Count), assertion(Count < 3),
          assertion(\+ metta_engine:metta_reference_source_mapping(_)),
          assertion(\+ spaces:metta_space_pair(Target, [from,Home,Map], _, _)),
          nb_setval(reference_origin_map_count, 0),
          nb_setval(reference_origin_map_mode, held),
          metta_add_atom(Target, [from,Home,Map], _),
          origin_groups(3, "!(noeval (OriginPoint 8))", Groups),
          assertion(Groups == [[['OriginCanonicalA',8]]]) ),
        origin_forget_source_map(Target, Home, Map)).

test(data_doors_keep_their_existing_token_difference_and_share_from_resolution,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_space(3, Space),
    space_module(Space, Module),
    with_metta_module(Module, metta_engine:register_metta_token('OriginToken', 'OriginPoint')),
    filereader:process_metta_string("(host-data (OriginPoint 1) OriginToken)", [], Space),
    filereader:process_loader_string("(file-data (OriginPoint 2) OriginToken)", [], Space),
    assertion(spaces:metta_space_pair(Space,
        ['host-data',['OriginCanonicalA',1],'OriginPoint'], _, _)),
    assertion(spaces:metta_space_pair(Space,
        ['file-data',['OriginCanonicalA',2],'OriginToken'], _, _)),
    origin_groups(3, "!(noeval OriginToken)", Groups),
    assertion(Groups == [['OriginPoint']]).

test(callable_union_and_withdrawal_use_standing_roots,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'),
    Provider = [=,['OriginCanonicalA',X],[noeval,[provider,X]]],
    Local = [=,['OriginPoint',Y],[noeval,[local,Y]]],
    origin_add(1, Provider), origin_add(3, Local),
    origin_groups(3, "!(OriginPoint 4)", [Values]), msort(Values, Sorted),
    assertion(Sorted == [[local,4],[provider,4]]),
    origin_space(1, Home), origin_space(3, Target),
    metta_remove_atom(Target, Local, true), metta_remove_atom(Home, Provider, true),
    origin_groups(3, "!(noeval (OriginPoint 5))", Groups),
    assertion(Groups == [[['OriginCanonicalA',5]]]).

test(withdrawal_preserves_existing_values_and_compiled_constructor_patterns,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'),
    origin_groups(3,
        "(= (origin-build $x) (noeval (OriginPoint $x)))\n\c
         (= (origin-field (OriginPoint $x)) $x)\n\c
         !(origin-build 6)", [[Value]]),
    origin_space(1, Home), origin_space(3, Target),
    metta_remove_atom(Target, [from,Home,[rename,[['OriginCanonicalA','OriginPoint']]]], true),
    origin_groups(3, "!(origin-build 6)\n!(noeval (OriginPoint 7))", Groups),
    assertion(Groups == [[['OriginCanonicalA',6]], [['OriginPoint',7]]]),
    findall(Field, evalc(['origin-field',Value], Target, Field), Fields),
    assertion(Fields == [6]),
    assertion(\+ metta_engine:metta_reference_source_reader(Target, _, _)).

test(distinct_origins_refuse_only_the_ambiguous_use,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_from(4, 1, 'OriginCanonicalA'),
    origin_space(3, Left), origin_space(4, Right),
    origin_add(4, [from,Left]),
    origin_groups(4, "!(noeval (OriginPoint 5))", Diamond),
    assertion(Diamond == [[['OriginCanonicalA',5]]]),
    origin_from(4, 2, 'OriginCanonicalB'),
    catch(origin_groups(4, "!(noeval (OriginPoint 6))", _), Error, true),
    assertion(nonvar(Error)),
    Error = error(metta_source_name_ambiguity('OriginPoint', Origins), none),
    assertion(member(root(_, 'OriginCanonicalA', declaration, []), Origins)),
    assertion(member(root(_, 'OriginCanonicalB', declaration, []), Origins)),
    assertion(spaces:metta_space_pair(Right, [from,Left], _, _)).

test(rollback_restores_the_prior_source_projection,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'),
    origin_space(1, Home), origin_space(2, Other), origin_space(3, Target),
    setup_call_cleanup(
        nb_setval(reference_origin_inside, none),
        ( \+ transaction((
              metta_remove_atom(Target,[from,Home,[rename,[['OriginCanonicalA','OriginPoint']]]],true),
              metta_add_atom(Target,[from,Other,[rename,[['OriginCanonicalB','OriginPoint']]]],_),
              origin_groups(3, "!(noeval (OriginPoint 8))", Inside),
              nb_setval(reference_origin_inside, Inside), fail)),
          nb_getval(reference_origin_inside, Recorded),
          assertion(Recorded == [[['OriginCanonicalB',8]]]),
          origin_groups(3, "!(noeval (OriginPoint 9))", After),
          assertion(After == [[['OriginCanonicalA',9]]]) ),
        nb_delete(reference_origin_inside)).

test(a_type_alias_does_not_create_a_data_constructor_substitution,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_add(1, [':','OriginTypeAlias',['Alias','Number']]),
    origin_space(1, Home),
    origin_add(3, [from,Home,[rename,[['OriginTypeAlias','ImportedOriginType']]]]),
    origin_groups(3, "!(noeval ImportedOriginType)", Groups),
    assertion(Groups == [['ImportedOriginType']]).

test(source_observation_keeps_the_canonical_answer_and_original_coordinates,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_from(3, 1, 'OriginCanonicalA'), origin_space(3, Space),
    metta_ensure_source_observation,
    source_observation:observe_source(Space, "origin.metta",
        "(= (origin-observed $x) (noeval (OriginPoint $x)))\n!(origin-observed 4)", Rows),
    assertion(memberchk(['observation-answer',0,['OriginCanonicalA',4]], Rows)),
    assertion(member(['source-coverage',"origin.metta",1,1,1,_,1], Rows)).

origin_swap([=, Call, [+, Left, Right]], Origins,
            [=, Call, [+, Right, Left]], Origins) :- !.
origin_swap(Term, Origins, Term, Origins).

test(equal_shape_does_not_fabricate_coordinates_for_a_rewritten_body,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(3, Space), metta_ensure_source_observation,
    setup_call_cleanup(
        asserta(seam:form_rewriter(plunit_reference_source_origins:origin_swap), Ref),
        ( source_observation:observe_source(Space, "rewritten.metta",
              "(= (origin-swapped) (+ (+ 1 2) (+ 3 4)))\n!(origin-swapped)", Rows),
          assertion(memberchk(['observation-answer',0,10], Rows)),
          assertion(member(['source-coverage-unavailable',"rewritten.metta",1,1,1,_,
                            ['generated-by','form-rewriter']], Rows)),
          assertion(\+ ( member(['source-coverage',"rewritten.metta",1,Column,1,_,_], Rows),
                          Column > 1 )) ),
        erase(Ref)).

origin_rebuild(Term, Origins, Rebuilt, Origins) :- origin_copy_lists(Term, Rebuilt).
origin_copy_lists(Terms, Copies) :- is_list(Terms), !, maplist(origin_copy_lists, Terms, Copies).
origin_copy_lists(Term, Term).

% The Python seat's import rewriter rebuilds every list once an alias exists.
test(a_rebuilding_rewriter_keeps_every_unchanged_coordinate,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(3, Space), metta_ensure_source_observation,
    setup_call_cleanup(
        asserta(seam:form_rewriter(plunit_reference_source_origins:origin_rebuild), Ref),
        ( source_observation:observe_source(Space, "rebuilt.metta",
              "(= (origin-pick $flag $x)\n  (if $flag\n    (+ $x 2)\n    (+ $x 2)))\n!(origin-pick True 1)",
              Rows),
          assertion(memberchk(['observation-answer',0,3], Rows)),
          assertion(memberchk(['source-coverage',"rebuilt.metta",3,5,3,13,1], Rows)),
          assertion(memberchk(['source-coverage',"rebuilt.metta",4,5,4,13,0], Rows)),
          assertion(\+ member(['source-coverage-unavailable',"rebuilt.metta",_,_,_,_,
                               ['generated-by','form-rewriter']], Rows)) ),
        erase(Ref)).

origin_bump([=, Call, [+, Left, [/, 8, X]]], Origins, [=, Call, [+, Left, [/, 6, X]]], Origins) :- !.
origin_bump(Term, Origins, Term, Origins).

test(a_rewritten_leaf_marks_its_own_path_and_keeps_its_siblings,
     [setup(origin_setup), cleanup(origin_cleanup)]) :-
    origin_space(3, Space), metta_ensure_source_observation,
    setup_call_cleanup(
        asserta(seam:form_rewriter(plunit_reference_source_origins:origin_bump), Ref),
        ( source_observation:observe_source(Space, "bumped.metta",
              "(= (origin-bumped $x) (+ (* $x 2) (/ 8 $x)))\n!(origin-bumped 3)\n!(origin-bumped 0)",
              Rows),
          assertion(memberchk(['observation-answer',0,8], Rows)),
          assertion(member(['source-error',_,['Error',[/,6,0],'DivisionByZero']], Rows)),
          % The untouched sibling keeps its coordinates and its exact frame.
          assertion(memberchk(['source-coverage',"bumped.metta",1,26,1,34,1], Rows)),
          % The rewritten division and the body above it claim no coordinates;
          % their frames sit at the whole equation, the span the source vouches for.
          assertion(\+ member(['source-coverage',"bumped.metta",1,35,1,43,_], Rows)),
          assertion(\+ member(['source-coverage',"bumped.metta",1,23,1,44,_], Rows)),
          forall(member(L-C-EL-EC, [1-35-1-43, 1-23-1-44, 1-1-1-45]),
                 assertion(memberchk(['source-coverage-unavailable',"bumped.metta",L,C,EL,EC,
                                      ['generated-by','form-rewriter']], Rows))),
          assertion(member(['source-frame',_,_,'origin-bumped',"bumped.metta",1,1,1,45,
                            ['generated-by','form-rewriter']], Rows)),
          assertion(\+ member(['source-frame',_,_,'origin-bumped',"bumped.metta",1,35,1,43,_], Rows)) ),
        erase(Ref)).

:- end_tests(reference_source_origins).
