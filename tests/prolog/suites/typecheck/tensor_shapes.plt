% Purpose: check structural host shape types through the ordinary arrow rules.
% Assumes: engine/metta.pl owns type checking and Janus supplies opaque values.
% Guarantees: host shape expressions refine typed arguments, share dimension
%   variables across parameters, and project instantiated return types
%   [tested: run_tests(tensor_shapes); commit=WORKTREE].
% Owns resources: each fixture releases its space and removes its host rows.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- dynamic tensor_shape_fixture/2.
:- multifile seam:grounded_type_names/2.
seam:grounded_type_names(Object, Types) :-
    user:tensor_shape_fixture(Object, Types).

:- begin_tests(tensor_shapes).

setup_shapes(Space, Matrix, Other, Right) :-
    'new-space'(Space),
    py_call(builtins:object(), Matrix),
    py_call(builtins:object(), Other),
    py_call(builtins:object(), Right),
    assertz(user:tensor_shape_fixture(Matrix,
        ['DLTensor', "HostArray", ['Annotated', 'DLTensor', ['Shape', [2, 3]]]])),
    assertz(user:tensor_shape_fixture(Other,
        ['DLTensor', ['Annotated', 'DLTensor', ['Shape', [4, 1]]]])),
    assertz(user:tensor_shape_fixture(Right,
        ['DLTensor', ['Annotated', 'DLTensor', ['Shape', [3, 4]]]])),
    process_metta_string(
        "(: shape-fixed (-> (Annotated DLTensor (Shape (2 3)))
                            (Annotated DLTensor (Shape (2 3)))))
         (= (shape-fixed $x) $x)
         (: shape-project (-> (Annotated DLTensor (Shape ($rows $columns)))
                              (Annotated DLTensor (Shape ($rows)))))
         (: shape-compose (-> (Annotated DLTensor (Shape ($rows $shared)))
                              (Annotated DLTensor (Shape ($shared $columns)))
                              (Annotated DLTensor (Shape ($rows $columns)))))
         (: shape-square (-> (Annotated DLTensor (Shape ($n $n))) Bool))
         (= (shape-square $x) True)", _, Space).

cleanup_shapes(Space) :-
    retractall(user:tensor_shape_fixture(_, _)),
    metta_release_space(Space).

test(a_host_bridge_keeps_structural_candidates_and_class_names,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    findall(Type, metta_grounded_type(Matrix, Type), Types),
    assertion(Types == ['DLTensor', 'HostArray',
                        ['Annotated', 'DLTensor', ['Shape', [2, 3]]]]).

test(a_concrete_shape_arrow_accepts_its_live_value,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, ['shape-fixed', Matrix], Value),
            Values),
    assertion(Values == [Matrix]).

test(a_concrete_shape_refusal_names_expected_and_actual_shapes,
     [ setup(setup_shapes(Space, _, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, ['shape-fixed', Other], Value),
            Values),
    assertion(Values == [['Error', ['shape-fixed', Other],
                          ['BadArgType', 1,
                           ['Annotated', 'DLTensor', ['Shape', [2, 3]]],
                           'DLTensor']],
                         ['Error', ['shape-fixed', Other],
                          ['BadArgType', 1,
                           ['Annotated', 'DLTensor', ['Shape', [2, 3]]],
                           ['Annotated', 'DLTensor', ['Shape', [4, 1]]]]]]).

test(a_symbolic_shape_projects_the_result_and_freshens_each_call,
     [ setup(setup_shapes(Space, Matrix, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    forall(member(Argument-Rows, [Matrix-2, Other-4]),
           (findall(Type, eval_metta_in_module(Module,
                         ['get-type', ['shape-project', Argument]], Type), Types),
            assertion(Types == [['Annotated', 'DLTensor', ['Shape', [Rows]]]]),
            findall(Type, 'get-type-space'(Space,
                           ['shape-project', Argument], Type), Scoped),
            assertion(Scoped == Types))).

test(shared_dimensions_bind_across_parameters_before_projecting_the_result,
     [ setup(setup_shapes(Space, Matrix, Other, Right)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    findall(Type, eval_metta_in_module(Module,
                  ['get-type', ['shape-compose', Matrix, Right]], Type), Types),
    assertion(Types == [['Annotated', 'DLTensor', ['Shape', [2, 4]]]]),
    assertion(\+ get_function_type_in(Module,
                                      ['shape-compose', Matrix, Other], _)).

test(a_repeated_dimension_is_an_equality_constraint,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    assertion(\+ get_function_type_in(Module, ['shape-square', Matrix], _)).

test(a_policy_checked_shape_variable_binds_at_the_live_call,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "(: shape-preserve (-> (Annotated DLTensor (Shape $dimensions))
                               (Annotated DLTensor (Shape $dimensions))))
         (= (shape-preserve $x) $x)
         !(add-typing-rule! shape-base ordinary
           (Annotated DLTensor (Shape $dimensions)) DLTensor accept)", _, Space),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, ['shape-preserve', Matrix], Value),
            Values),
    assertion(Values == [Matrix]),
    findall(Dimensions,
            has_type_under_policy(Module, Matrix,
              ['Annotated', 'DLTensor', ['Shape', Dimensions]]), Shapes),
    assertion(Shapes == [[2, 3]]).

test(a_policy_refusal_still_blocks_a_relational_shape_witness,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "!(add-typing-rule! shape-denied ordinary
           (Annotated DLTensor (Shape (2 3)))
           (Annotated DLTensor (Shape (2 3))) (refuse blocked))", _, Space),
    space_module(Space, Module),
    assertion(\+ has_type_under_policy(Module, Matrix,
                    ['Annotated', 'DLTensor', ['Shape', _]])).

test(a_grounded_type_candidate_keeps_a_variable_or_grounded_type_atom,
     [ setup(assertz(user:tensor_shape_fixture('shape-type-terms', [42, _]))),
       cleanup(retractall(user:tensor_shape_fixture('shape-type-terms', _))) ]) :-
    findall(Type, metta_grounded_type('shape-type-terms', Type), Types),
    Types = [Grounded, Variable],
    assertion(Grounded == 42),
    assertion(var(Variable)).

test(a_constructor_result_is_checked_after_its_shape_is_available,
     [ setup(setup_shapes(Space, Matrix, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "(: shape-source (-> DLTensor))
         (: shape-other-source (-> DLTensor))", _, Space),
    metta_add_atom(Space, ['=', ['shape-source'], Matrix], _),
    metta_add_atom(Space, ['=', ['shape-other-source'],
        ['let', _, ['println!', 'shape-source-ran'], Other]], _),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module,
                    ['shape-fixed', ['shape-source']], Value), Values),
    assertion(Values == [Matrix]),
    with_output_to(string(Printed),
        findall(Value, eval_metta_in_module(Module,
                        ['shape-fixed', ['shape-other-source']], Value), Refusals)),
    assertion(Printed == "shape-source-ran\n"),
    assertion(Refusals == [['Error', ['shape-fixed', ['shape-other-source']],
                            ['BadArgType', 1,
                             ['Annotated', 'DLTensor', ['Shape', [2, 3]]],
                             'DLTensor']],
                           ['Error', ['shape-fixed', ['shape-other-source']],
                            ['BadArgType', 1,
                             ['Annotated', 'DLTensor', ['Shape', [2, 3]]],
                             ['Annotated', 'DLTensor', ['Shape', [4, 1]]]]]]).

test(shared_shape_arguments_are_checked_together_before_the_body_runs,
     [ setup(setup_shapes(Space, Matrix, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "(: shape-shared (-> (Annotated DLTensor (Shape $dimensions))
                             (Annotated DLTensor (Shape $dimensions))
                             (Annotated DLTensor (Shape $dimensions))))
         (= (shape-shared $a $b) (let $_ (println! shape-body-ran) $a))", _, Space),
    space_module(Space, Module),
    with_output_to(string(Printed),
        findall(Value, eval_metta_in_module(Module,
                        ['shape-shared', Matrix, Other], Value), Refusals)),
    assertion(Printed == ""),
    assertion(Refusals \== []),
    assertion(\+ member(Matrix, Refusals)).

test(a_later_overload_accepts_after_an_earlier_refinement_refuses,
     [ setup(setup_shapes(Space, _, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "(: shape-overload (-> (Annotated DLTensor (Shape (2 3)))
                               (Annotated DLTensor (Shape (2 3)))))
         (: shape-overload (-> (Annotated DLTensor (Shape (4 1)))
                               (Annotated DLTensor (Shape (4 1)))))
         (= (shape-overload $x) $x)", _, Space),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module,
                    ['shape-overload', Other], Value), Values),
    assertion(Values == [Other]).

test(a_result_mismatch_does_not_invent_an_argument_refusal,
     [ setup(setup_shapes(Space, Matrix, Other, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    process_metta_string(
        "(: shape-result (-> (Annotated DLTensor (Shape (2 3)))
                             (Annotated DLTensor (Shape (2 3)))))
         (: shape-source (-> DLTensor))", _, Space),
    metta_add_atom(Space, ['=', ['shape-source'], Matrix], _),
    metta_add_atom(Space, ['=', ['shape-result', _], Other], _),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module,
                    ['shape-result', ['shape-source']], Value), Values),
    assertion(Values == []).

test(refinement_evidence_is_fresh_when_a_cached_call_runs_again,
     [ setup(setup_shapes(Space, Matrix, _, _)),
       cleanup(cleanup_shapes(Space)) ]) :-
    space_module(Space, Module),
    Call = ['shape-fixed', Matrix],
    findall(Value, eval_metta_in_module(Module, Call, Value), First),
    assertion(First == [Matrix]),
    retractall(user:tensor_shape_fixture(Matrix, _)),
    assertz(user:tensor_shape_fixture(Matrix,
        [['Annotated', 'DLTensor', ['Shape', [4, 1]]]])),
    findall(Value, eval_metta_in_module(Module, Call, Value), Second),
    assertion(Second == [['Error', Call,
                          ['BadArgType', 1,
                           ['Annotated', 'DLTensor', ['Shape', [2, 3]]],
                           ['Annotated', 'DLTensor', ['Shape', [4, 1]]]]]]),
    retractall(user:tensor_shape_fixture(Matrix, _)),
    assertz(user:tensor_shape_fixture(Matrix,
        [['Annotated', 'DLTensor', ['Shape', [2, 3]]]])),
    findall(Value, eval_metta_in_module(Module, Call, Value), Third),
    assertion(Third == [Matrix]).

test(an_unchecked_refined_overload_accepts_its_held_argument,
     [ setup('new-space'(Space)),
       cleanup(metta_release_space(Space)) ]) :-
    process_metta_string(
        "(: (Annotated Number (Unit metres)) DontEvalType)
         (: hold-review (-> (Annotated Number (Unit metres)) Number))
         (: hold-review (-> (Annotated Number (Unit seconds)) Number))
         (= (hold-review $x) \"wrong-result\")
         (: hold-source (-> Number))
         (= (hold-source) 1)", _, Space),
    space_module(Space, Module),
    findall(Value,
            eval_metta_in_module(Module, ['hold-review', ['hold-source']],
                                 Value), Values),
    assertion(Values == []).

:- end_tests(tensor_shapes).
