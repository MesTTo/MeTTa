% Purpose: check data constructors at construction and resolve sorted projections.
% Assumes: translator.pl owns this unit; retained compilation holds the typing
%   policy stable and filereader:record_translated_supports/3 records its source.
% Guarantees: constructor checks preserve written-call refusals and joint type
%   variables; sorted projections preserve duplicate answers and live changes
%   [tested: run_tests(translator_constructors); commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: construction facts extend the clause's static parameter
%   environment, which restores its parent on exit. Retained clauses and sort
%   proofs belong to translated-form support nodes and retire with their source
%   [tested: run_tests(translator_constructors); commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Decides: only a finite structural projection with an already-normal result
%   is resolved; arbitrary method bodies remain compiled calls.

% Maude retains the sort of a normalized ground node. Here retained source
% dependencies provide the lifetime of the corresponding construction proof.
% https://github.com/maude-lang/Maude/blob/46e89557efc7791d01b3399f10df7b30d615972c/src/Interface/dagNode.hh#L564-L574
compiled_constructor_answer(Fun, Chain, Written, Values, Out, Goals0, Goals) :-
    retained_static_type_shortcuts_allowed,
    % The selected arrow is already normalized in its defining scope. Its
    % intrinsic literal fields need no second declaration or origin lookup.
    (   Chain = [->|Types], is_list(Types),
        constructor_literal_parameters(Written, Types),
        \+ metta_discharges_verified
    ->  Checks = true
    ;   findall(Parameters-Origins,
                metta_operation_parameters(Fun, Written, Parameters, Origins),
                Signatures),
        Signatures \== [],
        constructor_signature_checks(Signatures, Written, Checks)
    ),
    (   Checks == true
    ->  Out = [Fun|Values], Goals0 = Goals,
        (   Written == Values, ground(Out),
            nb_current('$metta_static_parameter_environment', Entries)
        ->  current_metta_module(Module),
            nb_linkval('$metta_static_parameter_environment',
                       [sorted_constructor(Module, Out)|Entries])
        ;   true
        )
    ;   current_metta_module(Owner),
        Goals0 = [( Checks
                  -> Out = [Fun|Values]
                  ;  with_metta_module(Owner,
                         ( metta_bad_argument_reason(Fun, Written, Reason)
                         *-> metta_error_atom(Fun, Written, Reason, Out)
                         ; Out = [Fun|Values] ))
                  )|Goals]
    ).

% Consume a fixed arrow beside its arguments, leaving exactly its result.
constructor_literal_parameters([], [_]).
constructor_literal_parameters([Value|Values], [Type|Types]) :-
    statically_typed_literal(Value, Type),
    constructor_literal_parameters(Values, Types).

constructor_signature_checks([], _, fail).
constructor_signature_checks([Parameters-Origins|Rest], Written, Check) :-
    constructor_argument_checks(Written, Parameters, Origins, Arguments),
    (   Arguments == []
    ->  Check = true
    ;   goals_list_to_conj(Arguments, First),
        constructor_signature_checks(Rest, Written, More),
        ( More == fail -> Check = First ; Check = (First ; More) )
    ).

constructor_argument_checks([], [], [], []).
constructor_argument_checks([Value|Values], [Type|Types], [Origin|Origins],
                            Checks) :-
    (   constructor_argument_proved(Value, Type, Origin)
    ->  (   metta_discharges_verified
        ->  contract_fallback_goal(check_argument_type(Value, Type, Origin),
                                   Slow),
            current_metta_module(Owner),
            Checks = [verified_discharge(true, with_metta_module(Owner, Slow),
                         discharge(constructor, Type, Value))|Rest]
        ;   Checks = Rest
        )
    ;   current_metta_module(Owner),
        type_check_goal(Value, Type,
                       with_metta_module(Owner,
                           check_argument_type(Value, Type, Origin)), Goal),
        Checks = [Goal|Rest]
    ),
    constructor_argument_checks(Values, Types, Origins, Rest).

constructor_argument_proved(_, Type, _) :-
    ( Type == 'Atom' ; Type == '%Undefined%' ; Type == '_' ), !.
constructor_argument_proved(Value, Type, _) :-
    statically_typed_literal(Value, Type), !.
constructor_argument_proved(Value, Type, ordinary) :-
    ground(Value),
    written_arg_settled(Type, Value).

% A projection has a bounded result and no body to execute. Matching the
% complete equation bag first keeps repeated identical equations observable.
fold_sorted_constructor_projection(Module, Fun, Args, Out, Goal) :-
    member(Value, Args),
    nonvar(Value), Value = [Constructor|_], atom(Constructor),
    ground(Args),
    static_contract_shortcuts_enabled,
    \+ metta_discharges_verified,
    \+ nb_current('$metta_observation', _),
    var(Out), term_attvars(Out, []),
    \+ dispatch_selection_override(Fun),
    constructor_sort_proved(Module, Value),
    fun_meta_module(Module, Fun, Owner),
    findall(Head-Body,
            ( fun_meta_clause(Owner, Fun, Head, Body),
              subsumes_term(Head, Args) ),
            [Head-Body]),
    var(Body),
    structural_constructor_pattern(Head),
    % The direct target check preserves seam-selected implementations.
    append(Args, [Out], DirectArgs), Direct =.. [Fun|DirectArgs],
    Goal == Direct,
    % Binding Out early must not constrain the argument-refusal alternative
    % of a typed caller. Its input contract must already be proved as well.
    (   \+ raw_governing_type_declaration_in(Module, Fun, _, _),
        \+ seam:builtin_type_declaration(Fun, _)
    ->  true
    ;   findall(Parameters-ParameterOrigins,
                metta_operation_parameters(Fun, Args, Parameters,
                                           ParameterOrigins), Signatures),
        ( Signatures == [] -> true
        ; constructor_signature_checks(Signatures, Args, true) )
    ),
    Head = Args,
    ground(Body),
    structural_constructor_pattern(Body),
    Body \== '$metta_not_reducible',
    !,
    Out = Body.

% Bottom-up construction has already proved an unchanged ground argument
% under the typing-policy lock held for this compilation environment.
% Quoted terms and standalone translations have no such construction fact
% and use the same complete check before a projection can be resolved.
constructor_sort_proved(Module, Value) :-
    nb_current('$metta_static_parameter_environment', Entries),
    member(sorted_constructor(Owner, Known), Entries),
    Owner == Module, Known == Value,
    !.
constructor_sort_proved(Module, [Constructor|Fields]) :-
    type_rules:typing_policy_shortcuts_allowed(Module),
    \+ fun_here(Constructor),
    arrow_declared_data_head(Constructor, _),
    metta_operation_parameters(Constructor, Fields, Types, Origins),
    constructor_argument_checks(Fields, Types, Origins, []).

structural_constructor_pattern(Value) :- var(Value), !.
structural_constructor_pattern(Value) :- atomic(Value), !.
structural_constructor_pattern([]) :- !.
structural_constructor_pattern([Head|Tail]) :-
    (   atom(Head)
    ->  \+ fun_here(Head)
    ;   structural_constructor_pattern(Head)
    ),
    maplist(structural_constructor_pattern, Tail).
