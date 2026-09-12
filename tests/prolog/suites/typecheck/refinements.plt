% Purpose: check the refinement vocabulary through the ordinary arrow rules:
%   a refined parameter, a refined result, the cast witness, and each rule.
% Guarantees: a body Error remains visible across a result refinement
%   [tested: refinements:a_result_refinement_preserves_a_produced_error;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: a refined metatype, including a union member, rejects an expression
%   by its failed length constraint rather than its numeric tuple type
%   [tested: refinements:a_refined_metatype_reports_the_constraint_once;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Assumes: engine/metta.pl owns type checking; the Python seat supplies host
%   numerics for the seam case, so this suite runs under `-- extensions`.
% Guarantees: a refined parameter accepts what its constraints admit and
%   refuses the rest by constraint and value, a base mismatch keeps
%   BadArgType, a refined result refuses at the crossing, an unknown head is
%   undecided rather than violated, and the rule table equals the catalog row
%   [tested: run_tests(refinements); commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
% Owns resources: each fixture releases its space.
% Guarantees: Literal constraints use exact membership, including an empty
%   domain, and never bind a variable while testing it [tested:
%   refinements:literal_membership_is_exact_and_does_not_bind;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- multifile seam:grounded_length/2, seam:grounded_structure/2.
seam:grounded_length(plunit_length_owned(N), N).
seam:grounded_structure(plunit_length_owned(_), _) :-
    throw(error(unexpected_structure_read, none)).
seam:grounded_structure(plunit_structure_owned(N), Elements) :-
    length(Elements, N).

:- begin_tests(refinements).

setup_refined(Space) :-
    'new-space'(Space),
    process_metta_string(
        "(: positive-double (-> (Annotated Number (Gt 0)) Number))
         (= (positive-double $x) (* $x 2))
         (: decrement (-> Number (Annotated Number (Ge 0))))
         (= (decrement $x) (- $x 1))
         (: as-text (-> Number (Annotated String (MinLen 1))))
         (= (as-text $x) $x)
         (: pair-size (-> (Annotated Expression (MinLen 2)) Number))
         (= (pair-size $e) (size-atom $e))
         (: initial (-> (Annotated String (MinLen 1)) String))
         (= (initial $s) $s)
         (= (small $x) (< $x 10))
         (: tiny-double (-> (Annotated Number (Predicate small)) Number))
         (= (tiny-double $x) (* $x 2))
         (: metres (-> (Annotated Number (Unit \"m\")) Number))
         (= (metres $x) $x)
         (: shaped (-> (Annotated Number (Shape (2 3))) Number))
         (= (shaped $x) $x)
         (: n (Annotated Number (Gt 0)))", _, Space).

cleanup_refined(Space) :-
    metta_release_space(Space).

answers(Space, Call, Values) :-
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, Call, Value), Values).

test(a_refined_parameter_accepts_a_value_the_constraint_admits,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, ['positive-double', 1], Values),
    assertion(Values == [2]),
    answers(Space, ['positive-double', 2.5], Halves),
    assertion(Halves == [5.0]).

test(a_refined_parameter_refuses_with_the_constraint_and_the_value,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, ['positive-double', 0], Values),
    assertion(Values == [['Error', ['positive-double', 0],
                          ['BadArgValue', 1, ['Gt', 0], 0]]]),
    answers(Space, ['positive-double', -3], Negative),
    assertion(Negative == [['Error', ['positive-double', -3],
                            ['BadArgValue', 1, ['Gt', 0], -3]]]).

test(a_base_mismatch_keeps_the_ordinary_bad_arg_type,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, ['positive-double', "s"], Values),
    assertion(Values == [['Error', ['positive-double', "s"],
                          ['BadArgType', 1,
                           ['Annotated', 'Number', ['Gt', 0]], 'String']]]).

test(a_declared_refined_type_still_admits_by_unification,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    % The symbol n is declared to be the refined type, so the declared path
    % accepts it without a value to test; the body then fails on a symbol.
    space_module(Space, Module),
    assertion(check_argument_type_in(Module, n,
                                     ['Annotated', 'Number', ['Gt', 0]],
                                     ordinary)).

test(literal_membership_is_exact_and_does_not_bind) :-
    assertion(metta_refinement_holds(['Literal', a, b], a)),
    assertion(metta_refinement_holds(['Literal', 1, "one", [a, b]], [a, b])),
    assertion(\+ metta_refinement_holds(['Literal', 1], 1.0)),
    assertion(\+ metta_refinement_holds(['Literal'], a)),
    assertion(\+ metta_refinement_holds(['Literal', a], Variable)),
    assertion(var(Variable)).

test(a_literal_parameter_and_result_enforce_their_finite_domains,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    process_metta_string(
        "(: mood (-> (Annotated Symbol (Literal up down)) Symbol))
         (= (mood $x) $x)
         (: result (-> Number (Annotated Number (Literal 1 2))))
         (= (result $n) $n)", _, Space),
    answers(Space, [mood, up], Allowed), assertion(Allowed == [up]),
    answers(Space, [mood, sideways], Refused),
    assertion(Refused == [['Error', [mood, sideways],
                           ['BadArgValue', 1, ['Literal', up, down], sideways]]]),
    answers(Space, [result, 2], Result), assertion(Result == [2]),
    answers(Space, [result, 3], BadResult),
    assertion(BadResult == [['Error', [result, 3],
                             ['BadReturnValue', ['Literal', 1, 2], 3]]]).

test(a_wildcard_typed_value_is_decided_by_the_constraint,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    % (a) reports %Undefined%, which the gradual rule would wave through a
    % plain type; a refinement is about the value and reads its length.
    answers(Space, ['pair-size', [a, b, c]], Three),
    assertion(Three == [3]),
    answers(Space, ['pair-size', [a]], One),
    assertion(One == [['Error', ['pair-size', [a]],
                       ['BadArgValue', 1, ['MinLen', 2], [a]]]]),
    answers(Space, ['pair-size', abc], Symbol),
    assertion(Symbol == [['Error', ['pair-size', abc],
                          ['BadArgValue', 1, ['MinLen', 2], abc]]]).

test(a_return_refinement_refuses_with_the_constraint_and_the_value,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, [decrement, 5], Values),
    assertion(Values == [4]),
    answers(Space, [decrement, 0], Refused),
    assertion(Refused == [['Error', [decrement, 0],
                           ['BadReturnValue', ['Ge', 0], -1]]]).

test(a_refined_metatype_reports_the_constraint_once,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)),
       forall(member(Base, ['Expression', ['|', 'Expression', list],
                           ['|', ['|', 'Expression', list],
                                 ['|', 'Expression', tuple]]])) ]) :-
    Type = ['Annotated', Base, ['MinLen', 2]],
    'add-atom'(Space, [':', 'metatype-pair', [->, Type, 'Number', 'Atom']], _),
    'add-atom'(Space, [=, ['metatype-pair', X, _], X], _),
    answers(Space, ['metatype-pair', [3, 4], 0], Accepted),
    assertion(Accepted == [[3, 4]]),
    answers(Space, ['metatype-pair', [3], 0], Refused),
    assertion(Refused == [['Error', ['metatype-pair', [3], 0],
                           ['BadArgValue', 1, ['MinLen', 2], [3]]]]),
    answers(Space, ['metatype-pair', [3, 4], "s"], Later),
    assertion(Later == [['Error', ['metatype-pair', [3, 4], "s"],
                         ['BadArgType', 2, 'Number', 'String']]]).

test(a_return_base_mismatch_stays_silent,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, ['as-text', 4], Values),
    assertion(Values == []).

test(a_result_refinement_preserves_a_produced_error,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    process_metta_string(
        "(: refined-error (-> Number (Annotated Number (Gt 0))))
         (= (refined-error $x) (throw (Error refused $x)))", _, Space),
    answers(Space, ['refined-error', 7], Values),
    assertion(Values == [['Error', refused, 7]]).

test(a_length_refinement_reads_strings_and_expressions,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, [initial, "ab"], Text),
    assertion(Text == ["ab"]),
    answers(Space, [initial, ""], Empty),
    assertion(Empty == [['Error', [initial, ""],
                         ['BadArgValue', 1, ['MinLen', 1], ""]]]),
    assertion(metta_refinement_holds(['MaxLen', 3], "abc")),
    assertion(\+ metta_refinement_holds(['MaxLen', 2], "abc")),
    assertion(metta_refinement_holds(['Len', 1, 3], [x, y])),
    assertion(\+ metta_refinement_holds(['Len', 3], [x, y])),
    assertion(\+ metta_refinement_holds(['MinLen', 0], 7)).

test(every_numeric_refinement_decides_a_number) :-
    assertion(metta_refinement_holds(['Gt', 0], 1)),
    assertion(\+ metta_refinement_holds(['Gt', 0], 0)),
    assertion(metta_refinement_holds(['Ge', 0], 0)),
    assertion(\+ metta_refinement_holds(['Ge', 0], -1)),
    assertion(metta_refinement_holds(['Lt', 1], 0.5)),
    assertion(\+ metta_refinement_holds(['Lt', 1], 1)),
    assertion(metta_refinement_holds(['Le', 1], 1)),
    assertion(\+ metta_refinement_holds(['Le', 1], 2)),
    assertion(metta_refinement_holds(['Interval', [ge, 0], [le, 1]], 1)),
    assertion(\+ metta_refinement_holds(['Interval', [ge, 0], [le, 1]], 2)),
    assertion(metta_refinement_holds(['Interval', [gt, 0]], 5)),
    assertion(metta_refinement_holds(['MultipleOf', 2], 4)),
    assertion(\+ metta_refinement_holds(['MultipleOf', 2], 3)),
    assertion(metta_refinement_holds(['MultipleOf', 0.5], 1.5)),
    assertion(\+ metta_refinement_holds(['MultipleOf', 0], 4)),
    assertion(\+ metta_refinement_holds(['Gt', 0], abc)).

test(a_length_provider_does_not_read_structure) :-
    assertion(metta_refinement_holds(['Len', 0, 0], plunit_length_owned(0))),
    assertion(metta_refinement_holds(['Len', 1000000], plunit_length_owned(1000000))),
    assertion(\+ metta_refinement_holds(['MinLen', 2], plunit_length_owned(1))),
    assertion(metta_refinement_holds(['Len', 2, 2], -(1, 2))).

test(a_structural_provider_still_answers_length) :-
    assertion(metta_refinement_holds(['Len', 2, 2], plunit_structure_owned(2))),
    assertion(\+ metta_refinement_holds(['MinLen', 2], plunit_structure_owned(1))).

numpy_scalar(Value) :-
    catch(py_call(numpy:int64(5), Value), _, fail).

test(a_host_numeric_decides_through_the_seam,
     [ condition(numpy_scalar(_)) ]) :-
    numpy_scalar(Five),
    assertion(metta_refinement_holds(['Gt', 0], Five)),
    assertion(\+ metta_refinement_holds(['Lt', 0], Five)),
    assertion(metta_refinement_holds(['MultipleOf', 5], Five)),
    assertion(\+ metta_refinement_holds(['MultipleOf', 2], Five)).

test(a_predicate_refinement_applies_a_metta_head,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, ['tiny-double', 4], Values),
    assertion(Values == [8]),
    answers(Space, ['tiny-double', 40], Refused),
    assertion(Refused == [['Error', ['tiny-double', 40],
                           ['BadArgValue', 1, ['Predicate', small], 40]]]).

test(a_unit_refinement_is_a_declaration_not_a_value_test,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    answers(Space, [metres, 3], Values),
    assertion(Values == [3]),
    assertion(metta_refinement_holds(['Unit', "s"], abc)).

test(an_unknown_refinement_head_neither_holds_nor_is_violated,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    assertion(\+ metta_refinement_holds(['Shape', [2, 3]], 7)),
    assertion(\+ metta_refinement_violated([['Shape', [2, 3]]], 7, _)),
    assertion(metta_refinement_violated([['Shape', [2, 3]], ['Gt', 9]], 7,
                                        ['Gt', 9])),
    % A bare number against a Shape-refined parameter is refused as a type
    % mismatch, exactly as before this vocabulary existed.
    answers(Space, [shaped, 7], Values),
    assertion(Values == [['Error', [shaped, 7],
                          ['BadArgType', 1,
                           ['Annotated', 'Number', ['Shape', [2, 3]]],
                           'Number']]]).

test(the_cast_witness_admits_a_refined_type,
     [ setup(setup_refined(Space)), cleanup(cleanup_refined(Space)) ]) :-
    space_module(Space, Module),
    Refined = ['Annotated', 'Number', ['Gt', 0]],
    assertion(with_metta_module(Module, 'get-type'(5, Refined))),
    assertion(\+ with_metta_module(Module, 'get-type'(0, Refined))),
    assertion(with_metta_module(Module,
                                metta_refinement_violation(Refined, 0, ['Gt', 0]))),
    assertion(\+ with_metta_module(Module,
                                   metta_refinement_violation(Refined, 5, _))),
    assertion(\+ with_metta_module(Module,
                                   metta_refinement_violation(Refined, "s", _))).

test(the_rule_table_and_the_catalog_vocabulary_agree) :-
    findall(Head, metta_refinement_head(Head), Heads),
    once(metta_catalog_row([vocabulary, refinement|Row])),
    assertion(Heads == Row).

:- end_tests(refinements).
