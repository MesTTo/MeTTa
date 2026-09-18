% Guarantees: metta_argument_types_in/3 scopes its recursion guard through
%   metta_with_trailed/3; metta_record_error/1 ignores an inactive observation
%   [source: engine/metta/terms.pl:metta_argument_types_in/3; commit=40b71fc99571872ca5fc85cdaf7902b467166539].
%
% Purpose: provide representation, parsing, grounded-operation errors, and numeric term recovery
% Guarantees: metta_operation_parameters/6 and
%   metta_shallow_operation_parameters/4 present the arriving arity before
%   diagnostic checks, retaining each element's position and alias spelling
%   [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
% Guarantees: a refused host object reports one corresponding refinement or
%   its concrete type; accepted class and protocol witnesses are not blamed
%   [tested: run_tests(grounded_refusals),
%   run_tests(tensor_shapes),
%   extensions/python/tests/ch09_types/test_grounded_refusals.py;
%   commit=074dc0a88b1605c54824de677d586b6f60998bcf].
% Guarantees: Runtime argument checking and shallow declaration reads use
%   metta_runtime_type/2 for annotated function types
%   [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Assumes: engine/metta.pl consults this plain file while its owning module is the load context.
% Guarantees: every definition retains engine/metta.pl's implementation module and original load order.
%   Python numeric objects reach their owning operator seam only after the
%   native-number branch declines [tested:
%   test_numpy_numeric_family_keeps_python_result_types; commit=a0f1cc5f15a15e5ca6958fe02a20be8832c7237f].
%   Operation argument checks consume the same lexical declaration set as
%   compiled calls [tested:
%   test_an_inherited_arrow_does_not_veto_a_local_definition;
%   commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c].
%   A generated contract can request the policy-strict relation without
%   taxing the global numeric type fast path; default unannotated Python
%   operators therefore retain parity with their ordinary MeTTa twin while a
%   later user refusal remains decisive [tested:
%   test_extension_cost_rows_are_marginal,
%   test_a_static_parameter_proof_yields_to_a_later_typing_rule;
%   commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/evaluation/metta.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Guarantees: argument origins and masks consume expanded types, while
%   BadArgType retains the written alias and can show TypeExpansion [tested:
%   structural_aliases; commit=acad923476d21110870f235192757281a737ee71].
% Guarantees: metta_error_atom/4 preserves Error data, and metta_record_error/1
%   reaches an observer only while one is running: outside an observation it is
%   one failing nb_current/2 read and engine/source_observation.pl is not loaded
%   [tested: source_observation, tests/prolog/suites/reader/source_observation.plt;
%   measured 2026-09-05: boot 536,337 with that file loaded at boot against
%   532,641 without; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136].
% Guarantees: metta_shipped_types_match/2 decides union membership itself, in
%   the same direction and with the same shared-variable discipline as the
%   registry route, and its arm is reached only after the six shipped
%   comparisons decline [tested:
%   union_types:the_shipped_fast_path_decides_union_membership_on_its_own,
%   test_unions_keep_the_fast_path_and_registry_in_agreement;
%   commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
% Guarantees: metta_error_atom/4 preserves Error data and records diagnostics only
%   during explicit observation [tested: source_observation; commit=df1367c75148ca6c7262134a8736b237e1150383].
% Guarantees: a module holding a user typing rule still answers the ordinary
%   BadArgType for every pair that rule says nothing about, while a named
%   refusal replaces it for the pair the rule does name [tested:
%   typing_rule_scope:a_user_rule_that_names_no_refusal_leaves_the_ordinary_one,
%   typing_rule_scope:a_named_refusal_replaces_the_ordinary_one_for_its_own_pair;
%   commit=84327245373bba29fba00cf2cea62d8257a9f5cb].

% Guarantees: metta_bad_argument_reason/3 builds the same refusal payload
%   independently of Error context and observation, allowing an evaluated
%   refinement mismatch to retain its written call
%   [tested: run_tests(tensor_shapes); commit=4eaefdd8d40e53b2613722287302a14b41704662].
% Guarantees: a refined expected type `(Annotated Base C...)` admits a value
%   whose declared type unifies with it, as before, and also a value whose
%   reported type admits Base while every constraint holds on the value
%   (engine/metta/refinements.pl); the refusal for a value whose base is
%   admitted and whose first decided constraint fails is
%   `(BadArgValue <position> <constraint> <value>)`, one per bad call, and a
%   base mismatch keeps the ordinary BadArgType. At compile time the shallow
%   reading defers every constraint to the value's arrival, so a literal
%   satisfying the base compiles the ordinary typed call
%   [tested: refinements:a_refined_parameter_accepts_a_value_the_constraint_admits,
%   refinements:a_refined_parameter_refuses_with_the_constraint_and_the_value,
%   refinements:a_base_mismatch_keeps_the_ordinary_bad_arg_type;
%   commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
% Guarantees: refinement diagnostics admit a base through the value's metatype
%   as well as its reported types, including a metatype inside a union
%   [tested: refinements:a_refined_metatype_reports_the_constraint_once;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].

%%%%%%%%%% Standard Library for MeTTa %%%%%%%%%%

%%% Representation and parsing conversions: %%%
id(X, X).
%noeval is the Atom mask on both sides: the declaration in
%lib/lib_builtin_types/lib_builtin_types.metta stops the argument being reduced on the way in and
%its Atom return type stops the answer being reduced on the way out, so the
%body is the identity and the types are the whole implementation. That is how
%the reference defines it [source: metta-lang-docs, types_basics/metatypes:
%"This is the way noeval function is implemented"].
noeval(X, X).
repr(Term, R) :- sdisplay(Term, Text), R = Text.
repra(Term, R) :- term_to_atom(Term, R).
parse(Str, _) :- var(Str), !, refuse_unbound_input(parse, 1).
parse(Str, R) :- sread(Str, R).

%%% What a grounded operation answers when it cannot compute: %%%
%
%MeTTa's error channel is an ANSWER and not an exception. `(Error <call>
%<reason>)` is a value a program can test with if-error, compare with
%assertEqual and pass on, and the FORM AFTER IT STILL RUNS; a raise here ended
%the whole file instead, which is why eleven of the reference corpus's grounded
%transcripts stopped at their first probe. So an operation handed an argument
%it cannot use answers, and which answer is decided by the argument's own type:
%
%  - a type the parameter RULES OUT is `(BadArgType <position> <expected>
%    <actual>)`, one answer per rejected declared actual type, positions left
%    to right; a host object's class and protocol witnesses describe one value
%    and its refusal names the corresponding refinement when available,
%    otherwise the first class name supplied by its bridge
%  - an argument whose type does not DECIDE, %Undefined% or a symbol declared
%    the right type but carrying no value, is the operation's own refusal: its
%    message where upstream gives it one, and otherwise the call left as
%    written, which is upstream's NoReduce
%
%[assumed: the three answer shapes and the multiplicity were adopted from an
%earlier reference semantics, not re-measured against upstream PeTTa]
%[tested: operation_answers].
%
%NOTHING HERE IS ON A HOT PATH. Every caller reaches it only after its own
%ground fast path has already declined, so the type lookups below are paid by
%the call that was about to fail and by no other.
metta_operation_answer(Operation, Arguments, Answer) :-
    (   metta_error_operand(Arguments, Produced)
    ->  Answer = Produced
    ;   findall(Error,
                metta_bad_argument_error(Operation, Arguments, Error), Errors),
        (   Errors == []
        ->  (   metta_operation_refusal(Operation, Arguments, Message)
            ->  metta_error_atom(Operation, Arguments, Message, Answer)
            ;   Answer = [Operation|Arguments]
            )
        ;   member(Answer, Errors)
        )
    ).

%An operand that already IS an error atom finishes the call with that atom,
%unchanged, rather than being reported as an ErrorType argument: `(+ 1 (+ 1
%"bad"))` is `(Error (+ 1 "bad") (BadArgType 2 Number String))` and not a
%second error naming the first. That is the rule for an operand the evaluation
%PRODUCED: a BadArgType raised while preparing a nested call emerges unchanged
%[assumed: adopted from an earlier reference semantics, not re-measured against
%upstream PeTTa]. An operand WRITTEN as an error atom keeps the other reading,
%`(+ (Error source message) 1)` is `(BadArgType 1 Number ErrorType)`, and
%never reaches here: its static type is ErrorType, so refused_argument_call/2
%rejects the call at compile time and dispatch_mismatch_result/3 answers first
%[tested: test_the_error_vocabulary_answers_what_the_arbiter_answers].
%
%The head is COMPARED and the spine only inspected, never unified, so an
%ordinary expression holding an unbound variable in head position is left
%exactly as it was; unifying it bound that variable to the symbol Error.
metta_error_operand([A|_], A) :-
    nonvar(A), A = [Head|Tail], Head == 'Error', nonvar(Tail), !.
metta_error_operand([_|As], Error) :- metta_error_operand(As, Error).

metta_error_atom(Operation, Arguments, Reason, Error) :-
    Error = ['Error', [Operation|Arguments], Reason],
    metta_record_error(Error).

%A constructed Error is announced to whoever asked to observe this execution,
%and to nobody otherwise. The buffer carries its own sink, so the engine names
%no predicate of engine/source_observation.pl and an engine that never runs
%observe-source does not load that file at all: the whole cost of an
%unobserved Error is one global read that fails.
%'$metta_observation' is set only by source_observation:observe_source_locked/4,
%which is in the module that supplies the sink, so the sink is always callable
%by the time this reads one. The four sites in engine/translator/lowering.pl
%reach this name through the translator's base module, the way they already
%reach metta_bad_argument_error/3 below.
metta_record_error(Error) :-
    (   nb_current('$metta_observation', Buffer), Buffer \== []
    ->  arg(5, Buffer, Sink),
        call(Sink, Buffer, Error)
    ;   true
    ).

%A declared refusal retains both names: the rule that made the decision and
%the reason its author supplied. The ordinary BadArgType shape remains exact
%for shipped mismatches; only this user-declared case carries the fifth field
%[tested: test_a_user_typing_rule_participates_like_a_shipped_one;
%commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%THE GUARD IS ASKED ONCE. Both refusal shapes below opened with the same
%\+ metta_call_accepted/2, so an ACCEPTED call, which is every ordinary one,
%asked it twice: the first clause's negation failed and the second put the
%identical question again. metta_call_accepted/2 runs metta_arguments_match/3,
%which walks each argument's type, so on a term nested d deep that was two full
%walks per level and the compiled form emits one of these per level.
%The guard is a pure test that binds nothing, so hoisting it decides once and
%the two refusal shapes are tried underneath it, in the order they had.
metta_bad_argument_error(Operation, Arguments, Error) :-
    \+ metta_call_accepted(Operation, Arguments),
    metta_bad_argument_reason(Operation, Arguments, Reason),
    metta_error_atom(Operation, Arguments, Reason, Error).

%THE CHEAP QUESTION FIRST. This clause exists to find a NAMED refusal, and
%only a rule the program registered can produce one: engine/type_rules.pl
%ships nineteen typing rules and not one of them has a `refuse` outcome, so
%with no user rule in this module typing_rule_refusal/6 cannot succeed and
%everything this clause does before reaching it is dead.
%
%What it does is not cheap. metta_named_rule_refusal/10 walks every parameter
%and derives each argument's types through typing_refusal_actual/4, and the
%clause below then walks the same parameters again, so metta_operation_parameters/4
%ran twice per refused call with a full type derivation for nothing in
%between. One indexed probe on an EMPTY predicate is what a program with no
%typing rules pays instead.
%
%The saving is recorded as what it measured rather than what it looked like:
%nilbc does not reach this path often enough to move
%[measured 2026-08-30: 308,570,186 inferences before and after]. A refused
%call pays it, and a refused call is exactly where an error message is being
%built, so the work removed is work no answer depended on.
%
%THE PROBE SELECTS THE QUESTION, IT DOES NOT ANSWER IT. The cut commits to
%asking about a named refusal, and the ordinary shape is the ELSE of that
%question rather than a clause the cut has removed. A user rule decides only
%the pairs it names: a module holding one rule about `Count` still owes the
%ordinary `(BadArgType 1 Number String)` for every pair the rule says nothing
%about. Written as two clauses with the cut between them, the module's FIRST
%user rule silenced every ordinary argument refusal in it, so a wrong-typed
%call answered nothing at all, no value and no error
%[tested: a_user_rule_that_names_no_refusal_leaves_the_ordinary_one;
%commit=84327245373bba29fba00cf2cea62d8257a9f5cb].
metta_bad_argument_reason(Operation, Arguments, Refusal) :-
    current_metta_module(Module),
    raw_registered_typing_rule(user, Module, _, _, _, _, _),
    !,
    (   metta_operation_parameters(Operation, Arguments, ParameterTypes,
                                   Origins, RawChain, Chain),
        metta_named_rule_refusal(Module, ParameterTypes, Origins, Arguments, 1,
                                 Position, Expected, Actual, Rule, Reason)
    ->  metta_type_refusal_reason(RawChain, Chain, Position, Expected, Actual,
                                  [['TypingRuleRefusal', Rule, Reason]],
                                  Refusal)
    ;   metta_ordinary_argument_reason(Operation, Arguments, Refusal)
    ).

metta_bad_argument_reason(Operation, Arguments, Refusal) :-
    metta_ordinary_argument_reason(Operation, Arguments, Refusal).

%One error per declared ARROW and per rejected declared ACTUAL type, arrows
%in declaration order. A host object's ordered class/protocol witnesses are
%consolidated by metta_rejected_argument_type/5 on the refusal path alone.
metta_ordinary_argument_reason(Operation, Arguments, Refusal) :-
    metta_operation_parameters(Operation, Arguments, ParameterTypes, Origins,
                               RawChain, Chain),
    metta_bad_argument(ParameterTypes, Origins, Arguments, 1,
                       Position, Expected, Actual),
    metta_type_refusal_reason(RawChain, Chain, Position, Expected, Actual, [],
                              Refusal).

%A refinement violation names the constraint and the VALUE, because the value's
%type said nothing wrong: `0` is a Number, and `(Gt 0)` is what it fails. One
%reason per bad call, the first decided constraint that fails, so the alias
%expansion detail of the ordinary shape below has nothing to add here.
metta_type_refusal_reason(_, _, Position, _, violated(Constraint, Value), _,
                          ['BadArgValue', Position, Constraint, Value]) :- !.
% Preserve the source parameter spelling and carry the complete expansion for
% a whole-arrow alias, where no source parameter position exists to project.
metta_type_refusal_reason(Raw, Canonical, Position, Expected, Actual, Details,
                          ['BadArgType', Position, Written, Actual|More]) :-
    (   Raw =@= Canonical
    ->  Written = Expected, More = Details
    ;   (   nonvar(Raw), metta_arrow_type_chain(Raw, RawTypes),
            append(RawParameters, [_], RawTypes),
            (   nth1(Position, RawParameters, Parameter),
                \+ translator:rest_parameter(Parameter, _)
            ->  RawExpected = Parameter
            ;   append(Fixed, [Splice], RawParameters),
                translator:rest_parameter(Splice, RawExpected),
                length(Fixed, FixedArity), Position > FixedArity
            )
        ->  declared_type_for_check(RawExpected, Written)
        ;   Written = Expected
        ),
        append(Details, [['TypeExpansion', Raw, Canonical]], More)
    ).

%A type-position modifier is REPORTED and CHECKED by its value type:
%this engine answers `(BadArgType 1 Number String)` for a `(:Atom Number)`
%parameter, naming the type that decided rather than the pair that carried it
%[measured 2026-09-07: `(: mf2 (-> (:Atom Number) %Undefined%))` with
%`(= (mf2 $x) (quote $x))` makes `!(mf2 "s")` answer
%`(Error (mf2 "s") (BadArgType 1 Number String))`]. The projection sits on the
%refusal path, which this file's own note above metta_operation_answer/3
%records as reached only after a caller's fast path has declined.
metta_named_rule_refusal(Module, [Declared|_], [Origin|_],
                         [Argument|_], Position,
                         Position, Expected, Actual, Rule, Reason) :-
    declared_type_for_check(Declared, Expected),
    typing_origin_family(Origin, Family),
    typing_refusal_actual(Module, Family, Argument, Actual),
    typing_rule_refusal_resolved(Module, Family, Actual, Expected, Rule, Reason).
metta_named_rule_refusal(Module, [_|Expected], [_|Origins], [_|Arguments], N,
                         Position, Reported, Actual, Rule, Reason) :-
    Next is N + 1,
    metta_named_rule_refusal(Module, Expected, Origins, Arguments, Next,
                             Position, Reported, Actual, Rule, Reason).

typing_origin_family(derived_variable, derived) :- !.
typing_origin_family(metatype, metatype) :- !.
typing_origin_family(_, ordinary).

typing_refusal_actual(_, metatype, Argument, Actual) :-
    metatype_of(Argument, Actual).
typing_refusal_actual(Module, Family, Argument, Actual) :-
    Family \== metatype,
    metta_argument_types_in(Module, Argument, Types),
    member(Actual, Types).

%Nothing is reported when SOME declared arrow takes every argument under ONE
%consistent assignment, even where another arrow, or another of an argument's
%own types, does not. Measured 2026-08-19 against the arbiter: with
%`(: a A)`, `(: a C)`, `(: b D)` and `(: g (-> C D Number))`, `!(g a b)`
%answers `[(g a b)]` and reports nothing, while the same program with
%`(: b B)` answers both `(BadArgType 1 C A)` and `(BadArgType 2 D B)`; and
%with two arrows where the second fits, `!(g a)` answers `[7]`.
%
%The search backtracks over each argument's types because that is what makes
%the assignment CONSISTENT: a chain naming one type variable twice is only
%accepted by a pair of types that agree.
metta_call_accepted(Operation, Arguments) :-
    metta_operation_parameters(Operation, Arguments, ParameterTypes, Origins),
    current_metta_module(Module),
    (   type_rules:typing_policy_is_default(Module)
    ->  metta_arguments_match(ParameterTypes, Origins, Arguments)
    ;   metta_arguments_match_under_policy(
            ParameterTypes, Origins, Arguments)
    ),
    !.

%A compile-time refusal may use only the immediate types the shallow reader
%can prove. An unknown argument is compatible here: refusing it would turn a
%missing proof into a type error, while its nested call site or the runtime
%check can still decide it later. Shared formal variables remain shared across
%the walk, so two known arguments must still make one consistent assignment.
metta_arguments_match_shallow([], [], []).
metta_arguments_match_shallow([Expected|Rest], [Origin|Origins],
                              [Argument|Arguments]) :-
    (   Origin == metatype,
        satisfies_metatype(Argument, Expected)
    ->  true
    ;   shallow_argument_types(Argument, Types)
    ->  (   nonvar(Expected), Expected = [Head|_], Head == 'Annotated'
        ->  metta_shallow_refined_admits(Types, Expected, Origin)
        ;   member(Actual, Types),
            metta_argument_type_matches(Actual, Expected, Origin)
        )
    ;   true
    ),
    metta_arguments_match_shallow(Rest, Origins, Arguments).

%A refinement is DEFERRED at compile time: the base decides here, and the value
%a constraint needs arrives at run time, where the check below names it. Refusing
%`(f 0)` at compile time from its literal would be a second copy of every rule
%in engine/metta/refinements.pl, and accepting it costs nothing the runtime
%check does not already do for every other argument. The guard above is
%inlined so a plain declared type compiles with the inferences it had.
metta_shallow_refined_admits(Types, Expected, Origin) :-
    metta_refined_type(Expected, Base, _),
    (   member(Actual, Types),
        metta_refined_declared_match(Actual, Expected, Origin)
    ;   member(Actual, Types),
        metta_argument_type_matches(Actual, Base, Origin)
    ).

metta_shallow_call_accepted(Operation, Arguments) :-
    metta_shallow_operation_parameters(Operation, Arguments,
                                       ParameterTypes, Origins),
    metta_arguments_match_shallow(ParameterTypes, Origins, Arguments),
    !.

%A refusal is proven only when at least one declaration has this arity and no
%such declaration accepts the immediate argument types. Double negation keeps
%the compile-time question from binding the source term or a declaration's
%type variables.
metta_shallow_call_refused(Operation, Arguments) :-
    \+ \+ ( \+ metta_shallow_call_accepted(Operation, Arguments),
            metta_shallow_operation_parameters(Operation, Arguments, _, _) ).

metta_arguments_match([], [], []).
metta_arguments_match([Expected|Rest], [Origin|Origins],
                      [Argument|Arguments]) :-
    check_argument_type(Argument, Expected, Origin),
    metta_arguments_match(Rest, Origins, Arguments).

metta_arguments_match_under_policy([], [], []).
metta_arguments_match_under_policy([Expected|Rest], [Origin|Origins],
                                   [Argument|Arguments]) :-
    check_argument_type_under_policy(Argument, Expected, Origin),
    metta_arguments_match_under_policy(Rest, Origins, Arguments).

metta_arguments_match_in(_, [], [], []).
metta_arguments_match_in(Module, [Expected|Rest], [Origin|Origins],
                         [Argument|Arguments]) :-
    check_argument_type_in(Module, Argument, Expected, Origin),
    metta_arguments_match_in(Module, Rest, Origins, Arguments).

%A FRESH copy per arrow: a chain naming a type variable has to be free to bind
%it again for the next call, and for the next arrow.
%A TYPE-POSITION MODIFIER pairs an unevaluated metatype with a separate value
%type, so a parameter can say "do not evaluate this, and it must still be a
%Number". Without it those are exclusive: the official "Controlling pattern
%matching" page records that a specific parameter type and a metatype cannot
%be supplied together and links trueagi-io/hyperon-experimental#177, and these
%two spellings are what close that quadrant [assumed: the modifier registry,
%its check type and its evaluation type were adopted from an earlier reference
%semantics, not re-measured against upstream PeTTa].
%
%The registry is CLOSED and the arity is part of the shape: a three-element
%`(:Atom a b)` is ordinary data, exactly as `registeredMod?` requires.
type_position_modifier(Type, Metatype, ValueType) :-
    nonvar(Type),
    Type = [Head, ValueType],
    atom(Head),
    type_position_metatype(Head, Metatype).

type_position_metatype(':Atom', 'Atom').
type_position_metatype(':Expression', 'Expression').

%The checker reads the inner type of a modifier and every other declaration as
%written; argument preparation reads the metatype head. Two projections of one
%declaration, named as the reference names them.
declared_type_for_check(Type, ValueType) :-
    (   type_position_modifier(Type, _, Inner)
    ->  ValueType = Inner
    ;   ValueType = Type
    ).

metta_operation_parameters(Operation, Arguments, ParameterTypes, Origins) :-
    metta_operation_parameters(Operation, Arguments, ParameterTypes, Origins,
                               _, _).

metta_operation_parameters(Operation, Arguments, ParameterTypes, Origins,
                           Raw, Canonical) :-
    current_metta_module(Module),
    (   raw_governing_type_declaration_in(Module, Operation, Chain0, Owner)
    ;   \+ raw_type_declaration_in(Module, Operation, _, _),
        seam:builtin_type_declaration(Operation, Chain0),
        metta_self_module(Owner)
    ),
    copy_term(Chain0, Raw),
    normalize_type_in(Owner, Raw, Canonical),
    metta_runtime_type(Canonical, [->|Types]),
    %The types are read AS DECLARED. A type-position modifier is projected by
    %the consumers below, and only there: every declared argument check runs
    %through this reader, so projecting each parameter here costs an inference
    %per parameter per call and query-where paid 140 of them, 0.02%, for a
    %shape no shipped declaration uses [measured 2026-08-24].
    metta_operation_parameter_types(Types, Arguments, ParameterTypes),
    metta_argument_type_origins(ParameterTypes, Origins).

metta_shallow_operation_parameters(Operation, Arguments, ParameterTypes,
                                   Origins) :-
    shallow_declared_type(Operation, Chain0),
    copy_term(Chain0, [->|Types]),
    %The types are read AS DECLARED. A type-position modifier is projected by
    %the consumers below, and only there: every declared argument check runs
    %through this reader, so projecting each parameter here costs an inference
    %per parameter per call and query-where paid 140 of them, 0.02%, for a
    %shape no shipped declaration uses [measured 2026-08-24].
    metta_operation_parameter_types(Types, Arguments, ParameterTypes),
    metta_argument_type_origins(ParameterTypes, Origins).

% Remove the result and check the arriving length in one walk. Only the final
% splice generates parameters; fixed arrows need no arity-policy presentation
% to report their positional diagnostics.
% [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7]
metta_operation_parameter_types([_], [], []).
metta_operation_parameter_types([Type,_], Arguments, Parameters) :-
    nonvar(Type), Type = [Marker, Element], Marker == ':seg', !,
    same_length(Arguments, Parameters), maplist(=(Element), Parameters).
metta_operation_parameter_types([Type|Types], [_|Arguments], [Type|Parameters]) :-
    metta_operation_parameter_types(Types, Arguments, Parameters).

%Keep whether a formal was a raw type variable before an earlier argument
%binds it. A derived Atom is an ordinary type constraint, not the literal
%Atom metatype wildcard written in the declaration.
metta_argument_type_origins(Types, Origins) :-
    maplist(metta_argument_type_origin(Types), Types, Origins).

metta_argument_type_origin(Types, Expected, derived_variable) :-
    var(Expected),
    member(Compound, Types),
    nonvar(Compound),
    term_variables(Compound, Variables),
    member(Variable, Variables),
    Variable == Expected,
    !.
metta_argument_type_origin(_, Expected, variable) :- var(Expected), !.
metta_argument_type_origin(_, Expected, metatype) :-
    nonvar(Expected),
    current_metta_module(Module),
    typing_rule_expected_resolved(Module, metatype, Expected),
    !.
metta_argument_type_origin(_, _, ordinary).

%THE RUNTIME CHECK AND THE REPORTED TYPE ASK DIFFERENT QUESTIONS, and this
%engine answers them with different relations. Admitting an argument selects
%the permissive `match_types`, where `Atom` on either side is a
%match. Reporting an application's type keeps the stricter
%`match_reducted_types`, where a literal `Atom` result is an ordinary type.
%
%Both were measured on the same day against an earlier reference corpus
%[assumed 2026-08-24: not re-measured against upstream PeTTa]. With
%`(: idv (-> Atom Atom))` declared, `(: vf (-> Variable %Undefined%))` ACCEPTS
%`!(vf (idv $y))` and answers `(quote (idv $y))`, while
%`!(get-type (needs-grounded (atom-result value)))` answers NOTHING for the
%same shape. One relation cannot serve both, and this engine used the
%reporting one for both until the evaluation mask made a masked parameter
%check its argument as written and the difference became reachable.
%The split is made HERE rather than behind another predicate. Every declared
%argument check runs this, so one extra call is one extra inference per check
%and a query workload pays it once per row: routing the two relations through
%a helper cost query-where 140 inferences, 0.02%, for a decision the clause
%head already makes [measured 2026-08-24].
%A METATYPE argument goes through one door, metta_metatype_check/3 below, which
%tries the shape before the registry walk and, under
%(pragma! verify-discharges true), runs the walk beside it and raises a
%disagreement. This clause is what a TRACKED equation emits under the enabled
%mode; check_argument_type_in/4 carries the same call for the route a runnable
%takes, and the relation is the only thing that differs.
check_argument_type(Argument, Expected, metatype) :-
    !,
    metta_metatype_check(Argument, Expected, ordinary).
check_argument_type(Argument, Expected, Origin) :-
    current_metta_module(Module),
    check_argument_type_in(Module, Argument, Expected, Origin).

%Whether the engine would ADMIT one value for one declared parameter type in
%a space: the same origin classification and the same relation the compiled
%call check runs, under that space's typing policy, so a user rule that
%widens or refuses a pair reaches a host's answer with nothing host-side to
%change. `Atom` and `%Undefined%` admit everything, a metatype admits by the
%value's own metatype, an ordinary type by the value's reported types, and an
%unbound expected type admits anything, as a bare type variable does. The
%module's policy selects the relation exactly as the generated call check
%does: the shipped one where no user rule is declared, the policy-strict one
%where one is, since a user rule may widen or narrow a metatype family that
%the shipped shape test knows nothing about. A semidet question that binds
%nothing. Published for hosts (ext_points.pl); the Python seat's lint reads
%it in place of a metatype list of its own
%[tested: argument_admission; commit=e492f2a5bb995b6c2b86bdeb90cb1d2f27282b07].
metta_argument_admitted(Space, Argument, Expected) :-
    space_module(Space, Module),
    with_metta_module(Module,
        \+ \+ ( metta_argument_type_origin([Expected], Expected, Origin),
                (   type_rules:typing_policy_is_default(Module)
                ->  check_argument_type_in(Module, Argument, Expected, Origin)
                ;   check_argument_type_under_policy_in(Module, Argument, Expected, Origin)
                ) )).

%%%%%%%%%% Verifying what the compiler decided not to check %%%%%%%%%%
%
%This engine DISCHARGES type checks statically in four places: a literal whose
%type is settled at compile time (statically_typed_literal/2), an argument a
%caller's declaration already proved (static_parameter_proof_goal/3), a
%registry walk replaced by a VM test (intrinsic_type_shortcut_goal/4), and a
%registry walk replaced by the metatype ladder (the clause above). Each is a
%claim that "for every value reaching this site, the check I removed would have
%passed", and until this mode existed the only evidence for any of them was a
%battery someone wrote by hand.
%
%Under (pragma! verify-discharges true) the fast side still DECIDES, so the
%audited program keeps its meaning, and the slow side it replaced runs beside
%it with a disagreement raised rather than absorbed. That is translation
%validation, the same discipline engine/specializer.pl applies to
%specializations [source: Pnueli, Siegel and Singerman, Translation Validation,
%TACAS 1998], and it compares two INDEPENDENTLY WRITTEN relations rather than
%re-asking one. Upstream's own oracle records that as the limitation it could
%not escape: an oracle built on the checker's own value relation "can only ever
%re-ask the same question ... Auditing the model needs an INDEPENDENT value
%relation, which is out of scope"
%[source: trueagi-io/PeTTa@e038e4db src/typecheck/oracles.pl].
%
%SAFER to run than the specialization verifier it borrows from. That one is
%opt-in partly because running both paths can duplicate a program's EFFECTS; a
%type check has none, so re-running a discharged one duplicates nothing and the
%opt-in here is for cost alone.

%The pragma door and the environment door, the pair verify-specializations
%already uses, so an operator turns this on the same way for both.
%The mode is MATERIALISED, not asked. Reading the pragma costs a dynamic probe
%plus a getenv on every check, and this sits on the path a Symbol parameter
%takes per call; the marker below is one failing clause probe when the mode is
%off, which is what keeps the discharge cheap in the case that matters. The
%pragma WRITE installs it, the same way a typing policy is materialised rather
%than re-derived.
:- dynamic metta_discharges_verified/0.

metta_verifying_discharges :-
    (   metta_pragma('verify-discharges', V), V \== false, V \== none
    ->  true
    ;   getenv('METTA_VERIFY_DISCHARGES', Set), Set \== '0'
    ).

%Called by the pragma door and once at boot, so the environment variable and
%the pragma reach the same marker.
metta_refresh_discharge_verification :-
    (   metta_verifying_discharges
    ->  (   metta_discharges_verified
        ->  true
        ;   %Turning the mode ON starts a fresh count. Without this the tally
            %is the process's whole history, so a positive `agreed` could
            %describe an earlier file and coverage would stop being a
            %statement about the run in front of the reader.
            metta_discharge_reset,
            assertz(metta_discharges_verified)
        )
    ;   metta_discharges_verified
    ->  %Turning the mode OFF is where its coverage becomes visible. A tally
        %nothing reads is a shipped capability with no door, which is the
        %defect class this audit exists to catch, so the mode reports what it
        %checked rather than leaving the number to whoever knows the
        %predicate's name. Silent when it checked nothing, so a program that
        %never set the pragma prints nothing on the way past.
        metta_discharge_report,
        retractall(metta_discharges_verified)
    ;   true
    ).

metta_discharge_report :-
    metta_discharge_coverage(Counts),
    (   memberchk(agreed-0, Counts),
        memberchk(disagreed-0, Counts),
        memberchk(unverified-0, Counts)
    ->  true
    ;   memberchk(agreed-A, Counts),
        memberchk(disagreed-D, Counts),
        memberchk(unverified-U, Counts),
        Total is A + D + U,
        %To user_error DIRECTLY, not print_message/2 at `informational`, which
        %is what this was first: `sh run.sh` passes -q, so the report never
        %appeared and the door was still invisible [measured 2026-09-05]. This
        %is the deliberate output of a mode someone opted into, not a log line
        %a quiet run is right to drop.
        format(user_error,
               "verify-discharges checked ~w discharge(s): ~w agreed, \c
                ~w disagreed, ~w could not be checked inside the bound~n",
               [Total, A, D, U])
    ).


%%%%%%%%%% The metatype check, one place for both doors %%%%%%%%%%
%
%engine/metta/terms.pl has THREE runtime entry points, and a metatype check
%arrives through two of them: check_argument_type/3, which a tracked equation
%emits under the enabled mode, and check_argument_type_in/4, which a RUNNABLE
%reaches through check_argument_type_under_live_policy/3 once that has
%established the module's policy is the shipped one. They differ only in which
%relation the walk uses, `ordinary` or `reporting`, so the shape test lives
%here once and takes the relation as an argument. Putting it in only the first
%left `!(f abc)` paying the full walk while `(= (g $x) (f $x))` did not.
%
%The user-policy route is closed in check_argument_type_under_policy_in/4
%rather than tested here, so every caller that arrives has already established
%the precondition the shape test needs.
metta_metatype_check(Argument, Expected, Relation) :-
    (   metta_discharges_verified
    ->  current_metta_module(Module),
        verified_discharge(( metatype_of(Argument, Computed),
                             Computed == Expected ),
                           metatype_argument_admitted(Module, Argument,
                                                      Expected, Relation),
                           discharge(metatype, Relation, Argument, Expected))
    ;   metatype_of(Argument, Computed),
        Computed == Expected
    ->  true
    ;   current_metta_module(Module),
        metatype_argument_admitted(Module, Argument, Expected, Relation)
    ).

%COVERAGE IS A NUMBER, not a claim of completeness, which is the specialization
%verifier's own discipline: a mode that says how much it could check is worth
%more than one that implies it checked everything.
metta_discharge_coverage(Counts) :-
    findall(Outcome-N,
            ( metta_discharge_outcome(Outcome, Key),
              flag(Key, N, N) ),
            Counts).

metta_discharge_reset :-
    forall(metta_discharge_outcome(_, Key), flag(Key, _, 0)).

%flag/3 rather than retract-then-assert: the update is ATOMIC, where the pair
%loses an increment if two threads interleave between them, and a counter that
%undercounts silently is worse than no counter.
metta_discharge_note(Outcome) :-
    metta_discharge_outcome(Outcome, Key),
    flag(Key, N, N + 1).

%A CLOSED set, so the key space stays bounded: a refusal carries its detail in
%the exception it raises rather than in a counter key, which is what stops one
%flag per distinct refusal accumulating for the process's life.
%
%Each outcome gets its OWN ATOM. flag/3 does not distinguish the arguments of a
%compound key, so the three tallies written as metta_discharge_tally(agreed)
%and its siblings were ONE counter wearing three names: a single agreeing
%discharge read back as agreed-1, disagreed-1 and unverified-1
%[measured 2026-09-05; caught by
%discharge_audit:an_agreeing_discharge_is_silent_and_counted].
metta_discharge_outcome(agreed, metta_discharge_agreed).
metta_discharge_outcome(disagreed, metta_discharge_disagreed).
metta_discharge_outcome(unverified, metta_discharge_unverified).

%The one relation every discharge reduces to. A check DROPPED outright is this
%with `true` as its fast side, so nothing needs a second shape.
%
%The slow side is BOUNDED. Comparing forces work the program did not ask for,
%and a check over a deeply parametric type can walk a long way; exceeding the
%bound records `unverified` and leaves the fast side's answer standing, rather
%than turning a verification mode into a hang. call_with_inference_limit/3
%disarms the limit before it throws, so catching the ball here is sound and
%does not leak the caller's own budget
%[source: SWI-Prolog pl-prims.c, raiseInferenceLimitException sets
%INFERENCE_NO_LIMIT before the throw].
:- meta_predicate verified_discharge(0, 0, +).
verified_discharge(Fast, Slow, Site) :-
    (   call(Fast)
    ->  (   metta_discharge_agrees(Slow, Site)
        ->  true
        ;   metta_discharge_note(disagreed),
            throw(error(discharge_disagreement(Site), typecheck))
        )
    ;   call(Slow)
    ).

metta_discharge_bound(200000).

%The whole point of the mode is a reader who can act on the answer, so the
%disagreement says which discharge, against which type, on which value. Without
%this clause SWI renders it as `Unknown error term`, which is the mode telling
%someone that something is wrong and nothing else.
:- multifile prolog:message//1.
prolog:message(error(discharge_disagreement(discharge(Kind, Type, Value)), _))
--> { sdisplay(Value, ValueText) },
    [ 'the ~w discharge for ~w accepted ~w, and the check it replaced \c
       refuses it. The compiler decided this check could not fail and it \c
       can'-[Kind, Type, ValueText] ].

metta_discharge_agrees(Slow, Site) :-
    metta_discharge_bound(Limit),
    catch(call_with_inference_limit(Slow, Limit, Outcome),
          Ball,
          Raised = Ball),
    (   nonvar(Raised)
    ->  %The slow side REFUSED loudly where the fast side accepted, which is a
        %disagreement and not an error of this mode's own making.
        metta_discharge_note(refused(Site, Raised)),
        fail
    ;   Outcome == inference_limit_exceeded
    ->  metta_discharge_note(unverified),
        true
    ;   metta_discharge_note(agreed)
    ).


% A generated check whose static shortcut was invalidated must bypass only
% the global grounded-number shortcut. The derived relation below still uses
% the exact and widening witnesses, but under a user policy each witness also
% needs an ordinary acceptance, so an explicit refusal remains decisive.
% Keeping this as a separate entry point is what leaves unrelated has_type/2
% clients, including Python's live numeric protocol, on their established
% zero-registry-probe path.
check_argument_type_under_policy(Argument, Expected, Origin) :-
    current_metta_module(Module),
    check_argument_type_under_policy_in(
        Module, Argument, Expected, Origin).

check_argument_type_under_policy_in(Module, Argument, Expected, Origin) :-
    Origin \== metatype,
    Origin \== derived_variable,
    Origin \== variable,
    !,
    (   metta_evaluating_type_rule
    ->  metta_argument_types_in(Module, Argument, Types),
        (   nonvar(Expected), Expected = [Head|_], Head == 'Annotated'
        ->  metta_reported_type_admits_in(Module, Argument, Types, Expected)
        ;   member(Actual, Types),
            metta_resolved_types_match_in(Module, Actual, Expected)
        )
    ;   has_type_under_policy(Module, Argument, Expected)
    ).
%A metatype under a USER policy goes straight to the walk. The shape test in
%check_argument_type_in/4 below is only sound where the module's typing policy
%is the shipped one, and this is the one route into that clause that is not:
%a user rule may widen or narrow the metatype family for its own module, and
%metatype_of/2 knows nothing about it
%[source: engine/type_rules.pl, typing_rule_expected/3's family widening;
%tested: metta_metatype_guards:a_user_metatype_rule_is_not_bypassed].
check_argument_type_under_policy_in(Module, Argument, Expected, metatype) :-
    !,
    metatype_argument_admitted(Module, Argument, Expected, reporting).
check_argument_type_under_policy_in(Module, Argument, Expected, Origin) :-
    check_argument_type_in(Module, Argument, Expected, Origin).

% Runnable and untracked translations have no retained support record to
% invalidate between translation and execution, so they select the strict
% fallback against the live policy. Retained clauses make this choice once at
% translation time while holding the policy mutex.
check_argument_type_under_live_policy(Argument, Expected, Origin) :-
    current_metta_module(Module),
    (   type_rules:typing_policy_is_default(Module)
    ->  check_argument_type_in(Module, Argument, Expected, Origin)
    ;   check_argument_type_under_policy_in(
            Module, Argument, Expected, Origin)
    ).

%The SAME shape test the ordinary door carries, on the route a RUNNABLE takes.
%A runnable and an untracked translation emit
%check_argument_type_under_live_policy/3, which lands here once it has
%established that the module's policy is the shipped one, so the test that made
%a Symbol parameter cheap in a compiled equation was doing nothing for
%`!(f abc)` until this clause existed. The user-policy route into this
%predicate is closed above rather than tested here, so the precondition holds
%for every caller that arrives.
check_argument_type_in(_Module, Argument, Expected, metatype) :-
    metta_metatype_check(Argument, Expected, reporting).
check_argument_type_in(Module, Argument, Expected, derived_variable) :-
    metta_runtime_type_candidate(Module, Argument, Actual),
    metta_derived_types_match_in(Module, Actual, Expected).
%A BARE TYPE VARIABLE BINDS TO A CANDIDATE, it does not search for a
%membership witness. This is the parameter whose declared type is a variable
%the chain uses again, `(: bc (-> $a Nat $b $b))`, so the check exists to FIX
%$b from the argument rather than to test the argument against a known type.
%
%Upstream emits exactly a binding for it:
%`('get-type'(AV, T) *-> true ; 'get-metatype'(AV, T))`, and its get-type is
%`(get_type_candidate(X, T) *-> true ; T = '%Undefined%')` -- one candidate,
%and %Undefined% when there is none
%[source: PeTTa@ae66fa8 src/translator.pl:392-396 and src/metta.pl:186].
%
%This fell to the clause below, which for an unbound Expected reaches
%has_type_in/3 with a non-ground type and derives the argument's COMPLETE
%widened answer set. A nested type variable already took the candidate path
%through the derived_variable clause above; a bare one did not, and the
%asymmetry is what made a dependent-type backward chainer pay a full type
%derivation per recursive call. Argument checking is 99.4% of nilbc
%[measured 2026-08-30: 306,132,002 inferences against 1,866,723 with
%check_argument_type/3 stubbed to true].
check_argument_type_in(Module, Argument, Expected, variable) :-
    (   metta_runtime_type_candidate(Module, Argument, Expected)
    *-> true
    ;   Expected = '%Undefined%'
    ).

check_argument_type_in(Module, Argument, Expected, Origin) :-
    Origin \== metatype,
    Origin \== derived_variable,
    Origin \== variable,
    (   metta_evaluating_type_rule
    ->  metta_argument_types_in(Module, Argument, Types),
        (   nonvar(Expected), Expected = [Head|_], Head == 'Annotated'
        ->  metta_reported_type_admits_in(Module, Argument, Types, Expected)
        ;   member(Actual, Types),
            metta_resolved_types_match_in(Module, Actual, Expected)
        )
    ;   has_resolved_type_in(Module, Argument, Expected)
    ).

%A reported type admits a REFINED expected type by evidence on the whole type,
%or by admitting its base while the value satisfies every constraint. The
%second disjunct is what lets `5` reach a `(Annotated Number (Gt 0))`
%parameter: its one reported type is Number, which unifies with no Annotated
%type, and the constraint is a question about the value, not about the type
%(engine/metta/refinements.pl). A disjunction rather than an if-then-else, so
%a chain sharing a type variable keeps the witness the next argument may need.
%Reached behind the inlined `Head == 'Annotated'` guard at both callers, so a
%plain type never pays the call.
metta_reported_type_admits_in(Module, Argument, Types, Expected) :-
    metta_refined_type(Expected, Base, Constraints),
    (   member(Actual, Types),
        metta_refined_declared_match_in(Module, Actual, Expected)
    ;   member(Actual, Types),
        metta_resolved_types_match_in(Module, Actual, Base),
        metta_refinements_hold(Constraints, Argument)
    ).

%The metatype is asked first and decides on its own where it can; only where
%it defers do the argument's reported types answer, under the caller's chosen
%relation.
metatype_argument_admitted(Module, Argument, Expected, Relation) :-
    metatype_of(Argument, Actual),
    typing_rule_decision_resolved(Module, metatype, Actual, Expected,
                         Outcome, _, _),
    (   Outcome == accept
    ->  true
    ;   Outcome = [refuse, _]
    ->  fail
    ;   metta_argument_types_in(Module, Argument, Types),
        member(Reported, Types),
        typing_rule_accepts_resolved(Module, Relation, Reported, Expected)
    ).

metta_runtime_type_candidate(Module, Argument, Actual) :-
    type_candidate_in(Module, Argument, Raw),
    metta_runtime_type(Raw, Actual).
metta_runtime_type_candidate(Module, Argument, '%Undefined%') :-
    \+ once(type_candidate_in(Module, Argument, _)).

metta_argument_type_matches(Actual, Expected, variable) :-
    metta_resolved_types_match(Actual, Expected).
metta_argument_type_matches(Actual, Expected, derived_variable) :-
    metta_derived_types_match(Actual, Expected).
metta_argument_type_matches(Actual, Expected, metatype) :-
    metta_resolved_types_match(Actual, Expected).
metta_argument_type_matches(Actual, Expected, ordinary) :-
    metta_resolved_types_match(Actual, Expected).

%Every rejected declared actual type at a position, then later positions,
%which is what the arbiter reports when one actual type of an argument matched
%and carried the check forward while another did not
%[source: types-basic/48-badargtype-argument-order.metta]. The cut commits to
%the first carrying type, because the check continues under ONE assignment.
%
%A parameter naming a METATYPE is settled by the argument's metatype alone and
%reports nothing, which is the other half of the compiled call site's
%`(has_type(A,T) *-> true ; get-metatype(A,T))`: `(format-args "{}" (1 2))`
%passes an Expression parameter whose argument's DECLARED type is the tuple
%`(Number Number)` [measured 2026-08-19 against the arbiter, which answers
%"1"]. The declared types still decide when the metatype does not, which is
%why `(: xs Expression)` also passes and `(: n Number)` does not.
metta_bad_argument([Declared|Rest], [Origin|Origins], [Argument|Arguments], N,
                   Position, Reported, Actual) :-
    %The value type of a type-position modifier is what decides and what is
    %named, on this refusal path for the same reason as above.
    declared_type_for_check(Declared, Expected),
    (   Origin == metatype,
        satisfies_metatype(Argument, Expected)
    ->  Next is N + 1,
        metta_bad_argument(Rest, Origins, Arguments, Next,
                           Position, Reported, Actual)
    ;   Origin \== metatype,
        metta_grounded_numeric_type(Argument, Expected)
    ->  Next is N + 1,
        metta_bad_argument(Rest, Origins, Arguments, Next,
                           Position, Reported, Actual)
    ;   metta_argument_types(Argument, Types),
        (   Position = N, Reported = Expected,
            metta_argument_rejection(Argument, Types, Expected, Origin, Actual)
        ;   member(Carried, Types),
            metta_argument_type_admits(Argument, Carried, Expected, Origin),
            !,
            Later is N + 1,
            metta_bad_argument(Rest, Origins, Arguments, Later,
                               Position, Reported, Actual)
        )
    ).

%What one position rejects. A refined expected type whose base the value's
%metatype or reported type admits, while no type matches the whole refinement, rejects
%by the first decided constraint the VALUE fails, as `violated(Constraint,
%Value)`, and metta_type_refusal_reason/7 spells that BadArgValue; a value
%every constraint accepts is not rejected here and the carrying alternative
%above takes it forward. Every other shape keeps the type-by-type rejection
%below, one BadArgType per rejected reported type.
metta_argument_rejection(Argument, Types, Expected, Origin, Rejection) :-
    (   metta_refined_type(Expected, Base, Constraints),
        \+ ( member(Whole, Types),
             metta_refined_declared_match(Whole, Expected, Origin) ),
        member(Actual, Types),
        metta_refined_base_admits(Argument, Actual, Base, Origin),
        metta_refinement_violated(Constraints, Argument, Constraint)
    ->  Rejection = violated(Constraint, Argument)
    ;   metta_rejected_argument_type(Argument, Types, Expected, Origin,
                                     Rejection)
    ).

%A reported type carries an argument past a parameter when it matches the
%expected type, or, for a refined expected type, when it matches the whole
%type by evidence or admits the base while the value satisfies every
%constraint: the acceptance relation the refusal walk has to agree with,
%restated over one reported type. The wildcard exclusion is
%metta_refined_declared_match_in/3's, for the reason given there.
% The refusal walk shares the value relation used to admit a refined union.
% [tested: union_types:a_refined_alternative_retains_the_assignment_a_later_parameter_needs;
% commit=7e2de138f59cd8137f55dce9e7f2f955906c76d1].
metta_argument_type_admits(Argument, Actual, Expected, Origin) :-
    (   metta_refined_type(Expected, Base, Constraints)
    ->  (   metta_refined_declared_match(Actual, Expected, Origin)
        ;   metta_refined_base_admits(Argument, Actual, Base, Origin),
            metta_refinements_hold(Constraints, Argument)
        )
    ;   nonvar(Expected), Expected = [Head|_], Head == '|',
        metta_refined_union_type(Expected)
    ->  current_metta_module(Module),
        metta_refined_value_admits(Module, Actual, Argument, Expected)
    ;   metta_argument_type_matches(Actual, Expected, Origin)
    ).

% The runtime witness in type_witness_direct/4 also reads the metatype. A
% numeric expression reports (Number ...), which cannot match Expression by
% ordinary type equality, but its shape still satisfies that refined base.
metta_refined_base_admits(Argument, Actual, Base, Origin) :-
    (   satisfies_metatype(Argument, Base)
    ;   metta_argument_type_admits(Argument, Actual, Base, Origin)
    ).

metta_refined_declared_match(Actual, Refined, Origin) :-
    nonvar(Actual),
    Actual \== '%Undefined%',
    Actual \== 'Atom',
    metta_argument_type_matches(Actual, Refined, Origin).

%A bridge supplies named classes in resolution order; structural protocol
%witnesses may precede those names
%[source: extensions/python/metta/_binding/dispatch.py:784,
%extensions/python/metta/_binding/surface.pl:459; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
%All witnesses still participate in acceptance. Only a wholly refused host
%value needs a diagnostic. A refined requirement reports its corresponding
%observed refinement; ordinary requirements report the first class name once.
%Independent MeTTa declarations retain their existing refusal alternatives.
%Admission rather than matching decides what is rejected, so a refined
%expected type rejects exactly the reported types that neither match it by
%evidence nor carry the value past its constraints; for a plain expected type
%the two relations are the same one.
metta_rejected_argument_type(Argument, Types, Expected, Origin, Actual) :-
    (   atomic(Argument), \+ atom(Argument), seam:host_object(Argument)
    ->  \+ ( member(Candidate, Types),
             metta_argument_type_admits(Argument, Candidate, Expected, Origin) ),
        metta_host_refusal_type(Types, Expected, Actual)
    ;   member(Actual, Types),
        \+ metta_argument_type_admits(Argument, Actual, Expected, Origin)
    ).

% The caller has already projected parameter modifiers and normalized aliases.
% Match the refinement's base without binding either type: dimensions describe
% the failed constraint, rather than another candidate to accept or instantiate.
metta_host_refusal_type(Types, Expected, Actual) :-
    (   nonvar(Expected), Expected = [Head, Base, _|_], Head == 'Annotated',
        member(Refined, Types),
        nonvar(Refined), Refined = [ActualHead, ActualBase, _|_],
        ActualHead == 'Annotated', Base =@= ActualBase
    ->  Actual = Refined
    ;   member(Named, Types), atom(Named)
    ->  Actual = Named
    ;   Types = [Actual|_]
    ).

%The types an ARGUMENT CHECK may read, which is not everything get-type
%answers. A `get-type` EQUATION is a MeTTa program, and a program that types
%its argument by COMPUTING on it re-enters the operation whose refusal asked:
%examples/ch09-types/12-types_dependent.metta writes
%`(= (get-type $x) (catch (if (=alpha (% $x 2) 0) EvenNumber)))`, so asking
%get-type why `%` refused ran `%` again, and again
%[reproduced 2026-08-19: 16,777,031 frames and the 8Gb stack limit].
%
%Upstream reads the space's `(: x T)` atoms and the grounded object's own type
%here and nothing else, so the equations are off for the whole lookup rather
%than only at its top: the walk reaches them again through a list member's
%type. The flag is thread-local because the refusal is, and re-entrant because
%a nested lookup must not turn them back on when it finishes.
:- seam:context_reader(metta_reading_declared_types, '$metta_reading_declared_types', value(true)).

metta_argument_types(Argument, Types) :-
    current_metta_module(Module),
    metta_argument_types_in(Module, Argument, Types).

%THE COMPILE-TIME READING of the same question, and the difference is that it
%does not descend. A type walk over a nested call is proportional to the whole
%subtree, so asking it at every call site while compiling one made compilation
%quadratic in nesting depth: the translator's own linear-work test builds 400
%nested additions and holds compilation to at most double the work for double
%the depth [tested: translator_translation_depth:
%every_nesting_shape_compiles_in_linear_work].
%
%One lookup per argument answers what the refusal needs: a literal carries its
%own type, a call carries its head's declared RETURN type, and a symbol carries
%what was declared for it. Nothing else is decided, and an argument this cannot
%type is an argument the check accepts, so the compile-time decision is a
%SUBSET of the runtime one and a call it does not refuse compiles exactly as it
%did. The nesting is not lost either: the inner call is a call site of its own
%and is asked the same question when it is compiled.
%A VARIABLE first, and with a cut, because the clauses below match by head and
%an unbound argument would UNIFY with `true` and be typed Bool: the compiled
%body of `(= (qq $x) (+ $x 1))` came out as `qq(true, A)`, the check having
%bound the head's own variable before refusing the call it then reported
%[reproduced 2026-08-20].
shallow_argument_types(X, _) :- var(X), !, fail.
shallow_argument_types(X, ['Number']) :- number(X), !.
shallow_argument_types(X, ['String']) :- string(X), !.
shallow_argument_types(true, ['Bool']) :- !.
shallow_argument_types(false, ['Bool']) :- !.
shallow_argument_types([H|_], Types) :-
    atom(H), !,
    (   '$metta_atoms:&self':'&self'(':', H, _, _)
    ->  findall(Return,
                ( normalized_self_type_declaration(H, Expanded),
                  metta_runtime_type(Expanded, Chain),
                  nonvar(Chain), Chain = [->|Rest], last(Rest, Return) ),
                Types),
        Types \== []
    ;   seam:builtin_type_declaration(H, Chain),
        nonvar(Chain), Chain = [->|Rest],
        last(Rest, Return),
        Types = [Return]
    ).
shallow_argument_types(X, Types) :-
    atom(X),
    (   '$metta_atoms:&self':'&self'(':', X, _, _)
    ->  findall(Type,
                ( normalized_self_type_declaration(X, Expanded),
                  metta_runtime_type(Expanded, Type),
                  \+ ( nonvar(Type), Type = [->|_] ) ),
                Types),
        Types \== []
    ;   seam:builtin_type_declaration(X, Type),
        \+ ( nonvar(Type), Type = [->|_] ),
        Types = [Type]
    ).

%The two indexed registers, read directly: &self's own declarations and the
%engine's surface. type_declaration/2 would go through match/4 and the prelude,
%which is the door data_head_answer_dl/6's note measures at +44% on a compile
%path [measured 2026-08-19].
shallow_declared_type(Name, Type) :-
    '$metta_atoms:&self':'&self'(':', Name, Raw, _),
    metta_self_module(Self),
    normalize_callable_type_in(Self, Raw, Type).
shallow_declared_type(Name, Type) :-
    \+ '$metta_atoms:&self':'&self'(':', Name, _, _),
    seam:builtin_type_declaration(Name, Type).

metta_argument_types_in(Module, Argument, Types) :-
    (   metta_reading_declared_types
    ->  type_answers(Module, Argument, Types)
    ;   % Workaround: swi-cleanup-window - a trailed guard bounds the type lookup.
        metta_with_trailed('$metta_reading_declared_types', true,
                           type_answers(Module, Argument, Types))
    ).

%The call site's compatibility relation is declared in type_rules.pl.
%%Undefined%, Atom, equality, and BigInt widening are shipped entries in the
%same registry a program extends. The wrapper keeps existing callers on the
%current execution module; module-aware call sites use the explicit form
%[tested: test_a_user_typing_rule_participates_like_a_shipped_one;
%commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
metta_types_match(Left, Right) :-
    current_metta_module(Module),
    metta_types_match_in(Module, Left, Right).

metta_resolved_types_match(Left, Right) :-
    current_metta_module(Module),
    metta_resolved_types_match_in(Module, Left, Right).

%THE SHIPPED ANSWER WITHOUT THE SEARCH. This is the call site's compatibility
%relation and the hottest type predicate the engine has; every typed argument
%of every typed call asks it.
%
%The registry stays the authority and a program that registers an ordinary or
%widening rule gets the full search. What the fast path serves is the case
%where nothing has: engine/type_rules.pl ships exactly five ordinary rules and
%one widening rule, and between them they accept precisely
%  %Undefined% on either side, Atom on either side, an exact match, and
%  BigInt against Number,
%which is the same six-way test this relation was before the registry existed.
%Reading them off the registry instead means decisive_typing_rule/7
%backtracking over the family's entries and running typing_pattern_openness/2
%and typing_rule_pattern_matches/3 per entry, where the test below is inline
%comparisons the VM does not count.
%
%That change cost 5.3x on a dependent-type program: nilbc went from 44,327,926
%inferences to 236,070,644 in one commit and has carried it since 2026-08-21,
%because check_upstream_parity.py's drift tripwire was reading a baseline path
%the file had moved out of and could not fail [measured 2026-08-30 at ecb213fc
%and its parent; reverting this hunk alone at that commit restores 44,328,446].
%
%The two paths must answer the same thing, and that is a test rather than an
%argument: a differential over every pair drawn from the shipped vocabulary,
%run with no user rule and again with one registered, so the fast path is
%checked for agreement AND for standing aside
%[tested: test_the_shipped_fast_path_answers_what_the_registry_answers;
%commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
:- dynamic metta_types_match_in/3.

metta_types_match_in(Module, RawLeft, RawRight) :-
    metta_runtime_type(RawLeft, Left),
    metta_runtime_type(RawRight, Right),
    (   metta_user_typing_rule_present(Module)
    ->  typing_rule_accepts_resolved(Module, ordinary, Left, Right)
    ;   metta_shipped_types_match(Left, Right)
    ).

metta_resolved_types_match_in(Module, RawLeft, RawRight) :-
    metta_runtime_type(RawLeft, Left),
    metta_runtime_type(RawRight, Right),
    (   metta_user_typing_rule_present(Module)
    ->  typing_rule_accepts_resolved(Module, ordinary, Left, Right)
    ;   metta_shipped_types_match(Left, Right)
    ).

%Whether anything can override the shipped answer here. Ordinary AND widening,
%because typing_check_decision/7 defers an ordinary rule to widening, so a
%user rule in either family changes what this relation answers.
metta_user_typing_rule_present(Module) :-
    (   raw_registered_typing_rule(user, Module, _, ordinary, _, _, _)
    ->  true
    ;   raw_registered_typing_rule(user, Module, _, widening, _, _, _)
    ).

%The union arm is LAST and its guard is inlined, so the six comparisons above
%decide exactly what they decided before and a pair with no `|` on either side
%retires no extra inference reaching the end of the chain. A MISS runs the
%whole chain including this guard where a HIT stops at the sixth comparison,
%so the two costing the same is the measurable form of that claim
%[tested: union_types:the_union_guards_retire_no_inference_on_a_pair_with_no_union;
%commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
%
%Last also because `Left = Right` must keep binding an unbound side to the type
%expression AS WRITTEN: a union is what such a variable should become, not one
%alternative of it.
metta_shipped_types_match(Left, Right) :-
    (   Left == '%Undefined%' -> true
    ;   Right == '%Undefined%' -> true
    ;   Left == 'Atom' -> true
    ;   Right == 'Atom' -> true
    ;   Left == 'BigInt', Right == 'Number' -> true
    ;   Left = Right -> true
    ;   (   nonvar(Left), Left = [LeftHead|_], LeftHead == '|'
        ;   nonvar(Right), Right = [RightHead|_], RightHead == '|'
        )
    ->  metta_union_relates(metta_shipped_types_match, Left, Right)
    ).

%A raw type variable uses Atom as an ordinary bound once another formal has
%fixed it. The gradual unknown and numeric widening rules still apply.
metta_derived_types_match(Left, Right) :-
    current_metta_module(Module),
    metta_derived_types_match_in(Module, Left, Right).

metta_derived_types_match_in(Module, RawLeft, RawRight) :-
    metta_runtime_type(RawLeft, Left),
    metta_runtime_type(RawRight, Right),
    typing_rule_accepts_resolved(Module, derived, Left, Right).

%The operations that refuse BY NAME rather than leaving the call. Each text is
%upstream's own, quoted from a transcript rather than invented, and upstream's
%noun is not uniform: sqrt-math and abs-math say `number` where every later
%unary operation says `input number`, and log-math names both arguments
%[source: hyperon-experimental lib/src/metta/runner/stdlib/math.rs, whose unit
%tests pin each text].
%
%The ARGUMENTS are in the head because three of these operations word the
%refusal differently for different arguments, and the caller has them anyway.
%EVERY NUMERIC OPERATION SAYS THE SAME THING. Only `/` did, so `(/ 40 a)`
%answered a refusal naming what it wanted while `(+ 40 a)`, `(< 1 a)` and
%`(min 1 a)` answered the call back as written, and a program could not tell
%those from a form that had simply not reduced yet. Upstream draws no such
%line: every one of them reaches is/2 or a comparison and raises, so
%`(repr (catch (+ 40 a)))` is
%"(Error (type_error evaluable (/ a 0)) (context (: system (/ is 2)) $_0))"
%there [measured 2026-08-30 against PeTTa@ae66fa8]. This engine ANSWERS where
%upstream raises, which is the choice metta_operation_answer/3 above records,
%and the answer names the operation and its operands
%[tested: metta_operation_errors:arithmetic_answers_a_non_number_argument_rather_than_raising,
%metta_operation_errors:divide_names_its_two_operands,
%examples/ch10-errors-and-refusals/01-he_error.metta; commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
metta_operation_refusal('/', Arguments,
                        "Divide expects two numbers: dividend and divisor") :-
    metta_numeric_operands_settled(Arguments).
metta_operation_refusal(Operation, Arguments, Message) :-
    metta_numeric_binary_operation(Operation),
    metta_numeric_operands_settled(Arguments),
    format(string(Message), "~w expects two numbers", [Operation]).


metta_operation_refusal('sqrt-math', _, "sqrt-math expects one argument: number").
metta_operation_refusal('abs-math', _, "abs-math expects one argument: number").
metta_operation_refusal('pow-math', _,
    "pow-math expects two arguments: number (base) and number (power)").
metta_operation_refusal('bit-shift-left', _,
    "bit-shift-left expects two arguments: integer (value) and \c
     non-negative integer (count)").
metta_operation_refusal('bit-shift-right', _,
    "bit-shift-right expects two arguments: integer (value) and \c
     non-negative integer (count)").
metta_operation_refusal('bit-and', _, "bit-and expects two integers").
metta_operation_refusal('bit-or', _, "bit-or expects two integers").
metta_operation_refusal('bit-xor', _, "bit-xor expects two integers").
metta_operation_refusal('bit-not', _, "bit-not expects one argument: integer").
metta_operation_refusal('floor-div', _,
    "floor-div expects two arguments: number (dividend) and number (divisor)").
metta_operation_refusal('log-math', _,
    "log-math expects two arguments: base (number) and input value (number)").
metta_operation_refusal(Operation, _, Message) :-
    metta_input_number_operation(Operation),
    format(string(Message), "~w expects one argument: input number",
           [Operation]).
%min-atom and max-atom carry ONE text now, for a list holding something that
%is not a number. Their other two arguments follow upstream instead: a
%non-expression answers `()` and an empty expression answers nothing, both
%decided in engine/metta/operators.pl beside the clauses that do it
%[source: PeTTa@ae66fa8 src/metta.pl:85-88; measured 2026-08-30].
%format-args words its refusal by WHICH argument is wrong: a first argument
%that is not a format string earns the long text, and a first that is one with
%a second that is not an expression earns the conversion's own
%[assumed: the three cases were adopted from an earlier reference semantics,
%not re-measured against upstream PeTTa].
metta_operation_refusal('format-args', [Format|_], Message) :-
    (   string(Format)
    ->  Message = "Atom is not an ExpressionAtom"
    ;   Message = "format-args expects format string as a first argument and expression as a second argument"
    ).
metta_operation_refusal('sort-strings', _,
    "sort-strings expects expression with strings as a first argument").
metta_operation_refusal(Operation, [Argument], Message) :-
    metta_numeric_expression_operation(Operation),
    (   non_list(Argument)
    ->  Message = "Atom is not an ExpressionAtom"
    ;   \+ maplist(number, Argument),
        swrite(Argument, Written),
        format(string(Message), "Only numbers are allowed in expression: ~w",
               [Written])
    ).

%An UNBOUND operand is not a WRONG one. The value may still arrive -- a
%backward arithmetic mode binds it, and a partially applied numeric form waits
%for it -- so the call stays as written until every operand is there. Only a
%bound operand that is not a number is the refusal
%[tested: test_python_numeric_dispatch_waits_for_every_operand].
metta_numeric_operands_settled(Arguments) :-
    is_list(Arguments),
    maplist(nonvar, Arguments).

%The ten that take two numbers and nothing else. `/` keeps the longer text it
%already had, which names its two operands.
metta_numeric_binary_operation('+').
metta_numeric_binary_operation('-').
metta_numeric_binary_operation('*').
metta_numeric_binary_operation('%').
metta_numeric_binary_operation('<').
metta_numeric_binary_operation('>').
metta_numeric_binary_operation('<=').
metta_numeric_binary_operation('>=').
metta_numeric_binary_operation(min).
metta_numeric_binary_operation(max).

metta_numeric_expression_operation('min-atom').
metta_numeric_expression_operation('max-atom').


metta_input_number_operation('sin-math').    metta_input_number_operation('cos-math').
metta_input_number_operation('tan-math').    metta_input_number_operation('asin-math').
metta_input_number_operation('acos-math').   metta_input_number_operation('atan-math').
metta_input_number_operation('trunc-math').  metta_input_number_operation('ceil-math').
metta_input_number_operation('floor-math').  metta_input_number_operation('round-math').
metta_input_number_operation('isnan-math').  metta_input_number_operation('isinf-math').
metta_input_number_operation('exp-math').    metta_input_number_operation(exp).

%One registry owns the numeric math family and its input arities. The runtime
%guards below and their exhaustive string-operand pin both read this table, so
%a newly admitted math operation cannot inherit SWI's one-character-string
%arithmetic by omission [tested:
%test_a_string_operand_to_math_refuses_instead_of_answering_its_char_code].
metta_math_operation('sqrt-math', 1).
metta_math_operation('abs-math', 1).
metta_math_operation('pow-math', 2).
metta_math_operation('log-math', 2).
metta_math_operation(Operation, 1) :- metta_input_number_operation(Operation).

%The math family's recovery, which decides between the two failures the host
%reports the same way. An argument that is not a number at all is the MeTTa
%operation's own refusal and an ANSWER; a numeric fault outside the licensed
%IEEE family remains a host error. It sits in the catch's recovery rather than
%in front of the call, so the fast path pays nothing: this runs only where
%is/2 has already raised
%[tested: operation_answers, metta_operation_errors].
%The NUMERIC branch hands the fault to metta_operation_recovery/4, the shared
%classifier the grounded doors already use, rather than rethrowing it here. A
%second copy of "what an arithmetic fault means" is how `(/ 7 0)` came to
%answer `(Error (/ 7 0) DivisionByZero)` while `(pow-math 0 -1)` KILLED THE
%RUN: same fault, same shape of call, two funnels, and only one of them knew
%the rule. Nothing saw it while pow-math coerced both operands with float/1,
%because the expression was then always floating and always saturated
%[measured 2026-08-30: `!(pow-math 0 -1)` aborted with
%`'pow-math': Arithmetic: evaluation error: zero_divisor` where `!(/ 7 0)`
%answered, and upstream aborts on BOTH, having no vocabulary for either
%(PeTTa@ae66fa8 src/metta.pl:69 is `Out is A ** B`, uncaught)].
metta_math_recovery(Operation, Arguments, Error, Answer) :-
    (   maplist(metta_numeric_operand, Arguments)
    ->  metta_operation_recovery(Operation, Arguments, Error, Answer)
    ;   metta_operation_answer(Operation, Arguments, Answer)
    ).

%The float-capable operations chain the two recoveries: an IEEE-class fault
%in a floating expression saturates to the value the arbiter's raw f64 answers
%(metta_saturating_recover), and everything else takes the split above, a
%wrong-typed operand answering and a numeric host error staying one.
metta_math_saturating_recovery(Operation, Expression, Arguments, Error, Out) :-
    (   metta_ieee_saturable(Expression, Error)
    ->  metta_saturating_recover(Operation, Expression, Out, Error)
    ;   metta_math_recovery(Operation, Arguments, Error, Out)
    ).

%Check the numeric input at the operation's own door, before is/2 can interpret
%a one-character string as its character code. The refusal itself is derived
%from seam:builtin_type_declaration/2 through metta_operation_answer/3, the same
%table that guards translated calls; computed and direct operands therefore
%name the operation, position, expected Number and actual String alike.
metta_math_eval(Operation, Expression, Arguments, Out) :-
    (   maplist(metta_numeric_operand, Arguments)
    ->  catch(Out is Expression, Error,
              metta_math_recovery(Operation, Arguments, Error, Out))
    ;   metta_host_numeric_arguments(Arguments)
    ->  once(seam:grounded_numeric_operation(Operation, Arguments, Out))
    ;   metta_operation_answer(Operation, Arguments, Out)
    ).

metta_math_saturating_eval(Operation, Expression, Arguments, Out) :-
    (   maplist(metta_numeric_operand, Arguments)
    ->  catch(Out is Expression, Error,
              metta_math_saturating_recovery(
                  Operation, Expression, Arguments, Error, Out))
    ;   metta_host_numeric_arguments(Arguments)
    ->  once(seam:grounded_numeric_operation(Operation, Arguments, Out))
    ;   metta_operation_answer(Operation, Arguments, Out)
    ).

%An unbound operand counts as numeric here, so it does NOT become a type
%report: a missing value is not a wrong one, which is the split
%metta_arith_operands/2 already draws. It reaches metta_operation_recovery/4
%instead, where metta_arithmetic_rethrow/2 refuses it by the operation's own
%name as an unsolved arithmetic query -- the same answer the grounded doors
%have always given it, rather than a second spelling for one contract
%[tested: test_arithmetic_inverts_past_the_linear_case_or_refuses_with_the_reason].
metta_numeric_operand(Value) :- var(Value), !.
metta_numeric_operand(Value) :- number(Value).
%The reader's source spellings remain evaluable atoms until is/2 consumes
%them. They are numeric inputs, unlike every other atom and every string.
metta_numeric_operand(inf).
metta_numeric_operand(nan).

%A bridge owns both the admission fact and the operator that consumes it. Keep
%the value out of Prolog's number representation: the exact host object is the
%argument Python's reflected operator or array namespace must receive.
metta_grounded_numeric_type(Value, Expected) :-
    Expected == 'Number',
    nonvar(Value),
    \+ number(Value),
    once(seam:grounded_numeric(Value)).

metta_host_numeric_operand(Value) :- var(Value), !.
metta_host_numeric_operand(Value) :- number(Value), !.
metta_host_numeric_operand(Value) :-
    metta_grounded_numeric_type(Value, 'Number').

metta_host_numeric_arguments(Arguments) :-
    maplist(nonvar, Arguments),
    maplist(metta_host_numeric_operand, Arguments),
    member(Argument, Arguments),
    \+ number(Argument), !.
