% Purpose: decide the refinements an `(Annotated Base C1 ... Cn)` type carries
%   against a VALUE, one rule per head of the refinement vocabulary, and name
%   the first constraint a value violates so the refusal can say which.
% Assumes: engine/metta.pl consults this plain file after metta/types.pl while
%   its owning module is the load context, so metta_grounded_numeric_type/2,
%   check_argument_type_under_live_policy/3 and metta_error_atom/4 from
%   metta/terms.pl, 'get-type'/2 from metta/types.pl and the translator's
%   exported metta_dynamic_value_call/4 are all callable unqualified.
% Guarantees:
%   - a produced Error crosses a result refinement unchanged
%     [tested: refinements:a_result_refinement_preserves_a_produced_error;
%     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
%   - a constraint is decided three ways: it HOLDS, it is VIOLATED, or its head
%     is outside the vocabulary and it decides nothing. metta_refinements_hold/2
%     requires every constraint to hold, so an undecided one keeps the
%     declared-type path the only acceptance, which is what `(Shape ...)` had
%     before this unit existed; metta_refinement_violated/3 names only a
%     constraint the vocabulary decides against the value, so an undecided one
%     is never reported as a violation
%     [tested: refinements:an_unknown_refinement_head_neither_holds_nor_is_violated;
%     commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
%   - Gt, Ge, Lt and Le compare a native number natively and a host numeric
%     through seam:grounded_numeric_operation/3, the door metta_math_eval/4
%     already routes host arithmetic through; Interval decides each written
%     bound the same way and MultipleOf reads the remainder
%     [tested: refinements:every_numeric_refinement_decides_a_number,
%     refinements:a_host_numeric_decides_through_the_seam; commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
%   - MinLen, MaxLen and Len read a string's length, an expression's child
%     count, and a grounded value's length through seam:grounded_length/2,
%     falling back to seam:grounded_structure/2 when no length provider claims it;
%     a value with no length satisfies no length refinement
%     [tested: refinements:a_length_refinement_reads_strings_and_expressions,
%     refinements:a_length_provider_does_not_read_structure,
%     refinements:a_structural_provider_still_answers_length;
%     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
%   - Predicate applies its test to the value as a finished value, through the
%     translator's dynamic-value door, so a MeTTa head runs its equations and
%     a grounded host callable runs through seam:grounded_apply/3; the
%     refinement holds only when the application answers True
%     [tested: refinements:a_predicate_refinement_applies_a_metta_head,
%     extensions/python/tests/ch09_types/test_refinements.py::test_a_predicate_refinement_calls_the_grounded_predicate_at_the_seam;
%     commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
%   - Unit holds for every value: a unit is a claim about the DECLARATION, decided
%     by unification between declared types, and a bare number carries none to
%     disagree with [tested: refinements:a_unit_refinement_is_a_declaration_not_a_value_test;
%     commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
%   - metta_refined_result/6 answers the produced value when the declared result
%     type admits it, the Error `(BadReturnValue <constraint> <value>)` on the
%     written call when the base admits it and a decided constraint fails, and
%     nothing otherwise, which keeps a plain result-type mismatch the silent
%     branch failure the arbiter gives it
%     [tested: refinements:a_return_refinement_refuses_with_the_constraint_and_the_value,
%     refinements:a_return_base_mismatch_stays_silent; commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
% Guarantees: Literal constraints test exact finite membership without binding
%   the value [tested: refinements:literal_membership_is_exact_and_does_not_bind;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Decides: the refinement vocabulary is the twelve heads below, and the
%   catalog's `(vocabulary refinement ...)` row in engine/spaces/catalog.pl
%   names the same twelve; the two are held equal by
%   refinements:the_rule_table_and_the_catalog_vocabulary_agree rather than
%   derived from one another, because catalog.pl is consulted into the spaces
%   module and may not reach an engine predicate.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%%%%%%%%%% The shape of a refined type %%%%%%%%%%
%
%`(Annotated Base C1 ... Cn)` with at least one constraint. The head is compared
%with ==/2 after binding a fresh variable and every tail is tested with nonvar/1
%before it is taken apart, so a partial list standing for a type pattern is
%never turned INTO a refined type by the test that asks whether it is one; that
%is the discipline engine/metta/type_unions.pl records for `|`.
metta_refined_type(Type, Base, Constraints) :-
    nonvar(Type),
    Type = [Head|Rest],
    Head == 'Annotated',
    nonvar(Rest),
    Rest = [Base|Constraints],
    nonvar(Constraints),
    Constraints = [_|_].

%%%%%%%%%% The vocabulary %%%%%%%%%%
%
%One fact per head the rules below decide. A constraint whose head is not here
%is data the engine has no opinion on: `(Shape (4 1))` is decided by the arrays
%library's own typing rule and by declared-type unification, never here.
metta_refinement_head('Gt').
metta_refinement_head('Ge').
metta_refinement_head('Lt').
metta_refinement_head('Le').
metta_refinement_head('Interval').
metta_refinement_head('MultipleOf').
metta_refinement_head('MinLen').
metta_refinement_head('MaxLen').
metta_refinement_head('Len').
metta_refinement_head('Predicate').
metta_refinement_head('Unit').
metta_refinement_head('Literal').

metta_refinement_constraint(Constraint, Head, Arguments) :-
    nonvar(Constraint),
    Constraint = [Head|Arguments],
    atom(Head),
    metta_refinement_head(Head),
    is_list(Arguments).

%%%%%%%%%% The three-valued decision %%%%%%%%%%

metta_refinements_hold([], _).
metta_refinements_hold([Constraint|Constraints], Value) :-
    metta_refinement_holds(Constraint, Value),
    metta_refinements_hold(Constraints, Value).

metta_refinement_holds(Constraint, Value) :-
    metta_refinement_constraint(Constraint, Head, Arguments),
    metta_refinement_rule(Head, Arguments, Value).

%The FIRST decided constraint that is false, in declaration order, which is the
%one refusal a bad call answers. An undecided constraint is skipped rather than
%reported: the engine cannot say a value violates what it cannot read.
metta_refinement_violated([Constraint|Constraints], Value, Violated) :-
    (   metta_refinement_constraint(Constraint, Head, Arguments)
    ->  (   metta_refinement_rule(Head, Arguments, Value)
        ->  metta_refinement_violated(Constraints, Value, Violated)
        ;   Violated = Constraint
        )
    ;   metta_refinement_violated(Constraints, Value, Violated)
    ).

%%%%%%%%%% One rule per head %%%%%%%%%%
%
%Every rule is deterministic: the callers commit with `->` and the acceptance
%path runs under the argument group's once/1, so a choice point here would only
%be retried for nothing.
metta_refinement_rule('Gt', [Bound], Value) :-
    metta_refinement_compare('>', Value, Bound).
metta_refinement_rule('Ge', [Bound], Value) :-
    metta_refinement_compare('>=', Value, Bound).
metta_refinement_rule('Lt', [Bound], Value) :-
    metta_refinement_compare('<', Value, Bound).
metta_refinement_rule('Le', [Bound], Value) :-
    metta_refinement_compare('<=', Value, Bound).
%`(Interval (ge 0) (le 1))` carries only the bounds that were written, each as
%a (keyword limit) pair, so the rule decides the written ones and no other.
metta_refinement_rule('Interval', Bounds, Value) :-
    is_list(Bounds),
    forall(member(Bound, Bounds), metta_interval_bound(Bound, Value)).
metta_refinement_rule('MultipleOf', [Divisor], Value) :-
    metta_refinement_multiple(Value, Divisor).
metta_refinement_rule('MinLen', [Least], Value) :-
    number(Least),
    metta_refinement_length(Value, Length),
    Length >= Least.
metta_refinement_rule('MaxLen', [Most], Value) :-
    number(Most),
    metta_refinement_length(Value, Length),
    Length =< Most.
metta_refinement_rule('Len', [Least], Value) :-
    number(Least),
    metta_refinement_length(Value, Length),
    Length >= Least.
metta_refinement_rule('Len', [Least, Most], Value) :-
    number(Least),
    number(Most),
    metta_refinement_length(Value, Length),
    Length >= Least,
    Length =< Most.
metta_refinement_rule('Predicate', [Test], Value) :-
    metta_refinement_predicate(Test, Value).
metta_refinement_rule('Unit', [_], _).
metta_refinement_rule('Literal', Values, Value) :-
    member(Candidate, Values), Value == Candidate, !.

metta_interval_bound(Bound, Value) :-
    nonvar(Bound),
    Bound = [Kind, Limit],
    atom(Kind),
    metta_interval_operation(Kind, Operation),
    metta_refinement_compare(Operation, Value, Limit).

metta_interval_operation(gt, '>').
metta_interval_operation(ge, '>=').
metta_interval_operation(lt, '<').
metta_interval_operation(le, '<=').

%The comparison is spelled with MeTTa's own operation names because the seam
%speaks those: seam:grounded_numeric_operation/3 receives the operation a
%MeTTa program would have written, and answers the MeTTa boolean. A native
%number is compared by the VM, which is where a Number parameter's check
%already decides in one instruction (engine/translator/typing.pl,
%intrinsic_type_test/3).
metta_refinement_compare(Operation, Value, Bound) :-
    number(Bound),
    (   number(Value)
    ->  metta_refinement_native_comparison(Operation, Value, Bound)
    ;   metta_grounded_numeric_type(Value, 'Number')
    ->  once(seam:grounded_numeric_operation(Operation, [Value, Bound], Truth)),
        Truth == true
    ).

metta_refinement_native_comparison('>',  Value, Bound) :- Value > Bound.
metta_refinement_native_comparison('>=', Value, Bound) :- Value >= Bound.
metta_refinement_native_comparison('<',  Value, Bound) :- Value < Bound.
metta_refinement_native_comparison('<=', Value, Bound) :- Value =< Bound.

%A multiple is decided by the quotient being whole, which reads the same for
%integers and floats: 6 / 3 is the integer 2 and 7 / 2 the float 3.5 under this
%engine's flags, and 0.3 / 0.1 is 2.9999999999999996, which is also what
%Python's `0.3 % 0.1 != 0` says about the same pair. A host numeric takes its
%remainder through the seam and compares it with zero through the seam again,
%so a numpy scalar is never coerced into Prolog's number representation.
metta_refinement_multiple(Value, Divisor) :-
    number(Divisor),
    Divisor =\= 0,
    (   number(Value)
    ->  Quotient is Value / Divisor,
        Quotient =:= truncate(Quotient)
    ;   metta_grounded_numeric_type(Value, 'Number')
    ->  once(seam:grounded_numeric_operation('%', [Value, Divisor], Remainder)),
        metta_refinement_compare('>=', Remainder, 0),
        metta_refinement_compare('<=', Remainder, 0)
    ).

% Native values supply their own length. A grounded owner's length query can
% avoid enumeration and admit sized values that have no structural reading.
% Providers supplying only structure retain that route; no provider means the
% constraint fails. An exception from a claimed length query still propagates.
metta_refinement_length(Value, Length) :-
    (   string(Value)
    ->  string_length(Value, Length)
    ;   is_list(Value)
    ->  length(Value, Length)
    ;   once(seam:grounded_length(Value, Length))
    ->  true
    ;   once(seam:grounded_structure(Value, Elements)),
        length(Elements, Length)
    ).

%The test is APPLIED to a finished value, never re-evaluated around it: the
%value reaching a refinement is the argument after evaluation, and
%metta_dynamic_value_call/4 is the translator's door for applying a head to
%values it has already computed. A symbol head runs its equations in the
%current module and a grounded host callable runs through
%seam:grounded_apply/3, the same two roads `((py-atom f) x)` and `(f x)` take.
%The refinement holds only when some answer is True: a head that answers
%nothing, a False, an Error, or a value that is not an operation all decide
%against the value rather than raising.
metta_refinement_predicate(Test, Value) :-
    nonvar(Test),
    once(( metta_dynamic_value_call(Test, [Value], [Value], Answer),
           Answer == true )).

%%%%%%%%%% The result crossing %%%%%%%%%%
%
%Emitted by engine/translator/typing.pl in place of the ordinary result check
%whenever the declared result type is refined. Three outcomes, in this order:
%the declared type admits the produced value, so it is the answer; the base
%admits it and a decided constraint fails, so the answer is the Error naming
%that constraint and the value on the call AS WRITTEN, the form
%dispatch_mismatch_result/3 names for an argument; neither, and the branch
%fails as a plain result-type mismatch always has.
%The live-policy door is the check, because a refined result is a rare shape
%and reading the module's policy per call costs less than compiling three
%variants of it.
metta_refined_result(Fun, Written, Produced, OutType, Origin, Out) :-
    (   metta_error_operand([Produced], Error)
    ->  Out = Error
    ;   check_argument_type_under_live_policy(Produced, OutType, Origin)
    ->  Out = Produced
    ;   metta_refined_type(OutType, Base, Constraints),
        check_argument_type_under_live_policy(Produced, Base, Origin),
        metta_refinement_violated(Constraints, Produced, Constraint)
    ->  metta_error_atom(Fun, Written, ['BadReturnValue', Constraint, Produced],
                         Out)
    ;   fail
    ).

%%%%%%%%%% The cast door's question %%%%%%%%%%
%
%The first constraint a value violates under a refined type whose BASE admits
%it as a witness, asked through the same `get-type` and `get-metatype` pair
%the cast itself asks. Published as a host service in engine/ext_points.pl so
%a binding's cast can name the constraint instead of the value's types. Fails
%when the type is not refined, when the base does not admit the value, and
%when every decided constraint holds.
metta_refinement_violation(Type, Value, Constraint) :-
    metta_refined_type(Type, Base, Constraints),
    (   'get-type'(Value, Base)
    *-> true
    ;   'get-metatype'(Value, Base)
    ),
    metta_refinement_violated(Constraints, Value, Constraint).
