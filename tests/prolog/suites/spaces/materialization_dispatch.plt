% Purpose: verify that materialized dispatch owns only its selected functions.
% Guarantees: unrelated native calls retain the existing inference ceiling;
%   same-name images, rollback and removal retain exact bags and clause owners
%   [tested: materialization_dispatch; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Owns resources: fixture spaces and the host registration are removed by
%   cleanup goals. Clause references are inspected to test retained handlers,
%   whose resource lifetime is not observable from a returned answer bag.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

user:plunit_materialization_double(X, Y) :- Y is X*2.

:- begin_tests(materialization_dispatch,
               [setup(( filereader:metta_host_set_silent(true),
                        enable_source_materialization(Previous) )),
                cleanup(set_metta_pragma('materialize-source-relations',
                                         Previous))]).

enable_source_materialization(Previous) :-
    (   metta_pragma('materialize-source-relations', Previous)
    ->  true
    ;   Previous = none ),
    set_metta_pragma('materialize-source-relations', true).

fixture_source("(seed a) (seed a)\n\c
                (= (materialized-dispatch-pick $x) (match &self (seed $x) yes))").

make_image(I, Space) :-
    atom_concat('&plunit_materialization_dispatch_', I, Space),
    fixture_source(Source), process_metta_string(Source, _, Space),
    materialize:materialized_snapshot(Space, _, _, _, _).

clear_images(Spaces) :- maplist(spaces:metta_host_clear_space, Spaces).

forget_native :-
    unregister_fun_everywhere(plunit_materialization_double),
    retractall(fun(plunit_materialization_double)),
    retractall(arity(plunit_materialization_double, _)).

test(unrelated_native_dispatch_keeps_its_cost_with_many_images,
     [forall(member(Count, [0,1,16,64])),
      cleanup((clear_images(Spaces), forget_native))]) :-
    import_prolog_function(plunit_materialization_double, true),
    findall(I, between(1, Count, I), Indices),
    maplist(make_image, Indices, Spaces),
    reduce([plunit_materialization_double, 21], Out, _), assertion(Out == 42),
    statistics(inferences, Before),
    forall(between(1, 2000, _), reduce([plunit_materialization_double, 21], _, _)),
    statistics(inferences, After),
    PerCall is (After-Before)/2000,
    assertion(PerCall < 30).

test(removing_one_same_name_image_keeps_the_other_bag_and_handler,
     [cleanup(clear_images([First,Second]))]) :-
    make_image(first, First), make_image(second, Second),
    materialize:materialized_snapshot(First, _, FirstToken, _, _),
    materialize:materialized_snapshot(Second, _, SecondToken, _, _),
    assertion(materialize:materialized_dispatch_ref(FirstToken, _)),
    assertion(materialize:materialized_dispatch_ref(SecondToken, _)),
    spaces:metta_host_clear_space(First),
    assertion(\+ materialize:materialized_dispatch_ref(FirstToken, _)),
    assertion(materialize:materialized_dispatch_ref(SecondToken, _)),
    process_metta_string("!(materialized-dispatch-pick a)", Bag, Second),
    assertion(Bag == [yes,yes]).

test(rolling_back_removal_restores_the_same_live_handler,
     [cleanup(clear_images([Space]))]) :-
    make_image(rollback, Space),
    materialize:materialized_snapshot(Space, _, Token, _, _),
    materialize:materialized_dispatch_ref(Token, Ref),
    catch(metta_transaction((spaces:metta_host_clear_space(Space), throw(undo))),
          undo, true),
    assertion(materialize:materialized_dispatch_ref(Token, Ref)),
    assertion(\+ clause_property(Ref, erased)),
    process_metta_string("!(materialized-dispatch-pick a)", Bag, Space),
    assertion(Bag == [yes,yes]).

:- end_tests(materialization_dispatch).
