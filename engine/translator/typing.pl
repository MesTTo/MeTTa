% Purpose: compile declared input and output types while preserving shared branch variables
% Guarantees: committing generated type checks adds no native call around
%   intrinsic tests and preserves the caller's alternatives [tested:
%   run_tests(translator_check_commits), run_tests(translator_typed_checks);
%   commit=6c70946993db4811ebc46c618e8c68a18474694c].
% Guarantees: a computed Error crosses an ordinary result arrow unchanged;
%   other result mismatches still filter that branch
%   [tested: classes_transaction_results:typed_results_preserve_errors_and_filter_other_mismatches;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: a retained call reuses the proved sort of a ground constructor
%   argument when its result exactly matches an ordinary parameter; live
%   refinements and unsupported translations keep their check [tested:
%   translator_constructors:a_typed_callee_reuses_the_constructed_argument_sort,
%   translator_constructors:a_callee_arrow_change_retires_its_argument_proof,
%   translator_constructors:a_constructed_argument_keeps_a_live_callee_refinement,
%   translator_constructors:a_nullary_construction_proof_reaches_the_audit;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: present_type_chain/3 expands a final (:seg T), and
%   validate_type_splices/1 refuses retired or misplaced forms at admission
%   [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
% Owns resources: the private variant table of type_syntax_analysis/3
%   retains syntax analyses for the calling Prolog thread's lifetime.
%   It reads no declarations or policy, so withdrawal cannot invalidate it
%   [source: engine/translator/typing.pl:type_syntax_analysis/3;
%   commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
% Guarantees: Inherited annotated arrows retain their typed arity refusal through
%   metta_runtime_type/2
%   [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Assumes: engine/translator.pl consults this plain file while its owning module is the load context.
%   fun_meta_head/3 preserves each source head's bindings and multiplicity
%   [tested: run_tests(translator_metadata_projection); commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Guarantees: every definition retains engine/translator.pl's implementation module and original load order.
%   A named space's local binding cannot inherit a typed arity refusal, while
%   an inherited typed meaning still owns its own wrong-arity refusal
%   [tested: test_an_inherited_arrow_does_not_veto_a_local_definition,
%   lib_strategy:an_inherited_arrow_does_not_veto_a_local_definition;
%   commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c].
%   A parameter's checked governing type discharges the same contract in a
%   retained body only when every arrival-order chain proves it; gradual
%   consistency, computed values, and untracked clauses keep the runtime
%   check [tested:
%   test_a_consistent_chain_is_not_a_static_type_proof,
%   translator_literal_type_checks:an_untracked_clause_retains_static_and_intrinsic_contracts;
%   commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/translator/translator.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Guarantees: presented_parameter_type_chains/4 expands aliases before
%   parameter masks and static proofs are chosen [tested:
%   structural_aliases; commit=acad923476d21110870f235192757281a737ee71].

% Guarantees: Annotated parameter checks, including union members, run before
%   the body, retain joint
%   bindings with the result, and report observed refinement failures using
%   the original written call after all overloads decline
%   [tested: run_tests(tensor_shapes),
%   union_types:refined_union_failures_do_not_evaluate_an_argument_twice;
%   commit=7e2de138f59cd8137f55dce9e7f2f955906c76d1].
% Guarantees: a refined declared result type is checked at the result crossing
%   by metta_refined_result/6, which answers the produced value, the
%   BadReturnValue Error on the written call, or fails as a plain mismatch
%   [tested: refinements:a_return_refinement_refuses_with_the_constraint_and_the_value,
%   refinements:a_return_base_mismatch_stays_silent; commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
% Owns resources: each refined call owns a refinement_evidence/2 cell whose
%   failure snapshots and host references become collectible when that call
%   finishes or is abandoned. The cell never escapes into global state.
% Guarded by: no lock is needed because the evidence cell belongs to one call.

:- meta_predicate with_static_parameter_environment(+, +, +, +, 0).

%Type function call generation, returns function call plus typechecks for input and output:
%Translate a call against every type declaration that fits it.
%
%A symbol may carry several declarations at different arities, which is
%ordinary nondeterminism over declarations rather than a conflict, so a
%declaration whose shape does not fit THIS call simply does not contribute a
%branch. Collecting the branches with findall is what makes that true. It was
%a maplist, which meant one inapplicable declaration failed the entire form:
%with both (: g (-> A Atom B)) and (: g (-> A Atom Number B)) declared,
%(g x y 1) did not translate at all, while the same two equations with no
%declarations worked [tested: translator_multi_arity_declarations].
%
%Failing when no branch fits is deliberate: the caller falls back to the
%untyped translation, which is what a call carrying no usable declaration
%should get.
%
%The branches are collected by recursion rather than findall/3, because
%findall COPIES its template and every branch has to keep sharing the caller's
%Out and argument variables. Collecting them with findall compiled cleanly and
%answered an unbound variable for every typed call.
%RuntimeArgs is a REQUEST rather than an output variable: runtime_args(Args)
%from a caller that reports the call as dispatched, no_runtime_args from one
%that does not. The difference is a goal in the emitted body. A caller that
%discards the record used to get `Args = <the values>` emitted anyway, binding
%a variable nothing reads; SWI's compiler removes such a goal from the clause
%it STORES, so the emitted body and the stored one stopped being the same term
%and every source attribution in that clause was refused
%[tested: source_observation:exception_keeps_source_frames_and_restores_debugger;
%commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
typed_functioncall_dl(Fun, UniqueTypeChains, T, IsPartial, Bound, Out,
                      RuntimeArgs, BeforeCall, AfterHead, Goals) :-
    UniqueTypeChains \== [],
    %The arity guard below reads fun_meta rows, and a deferred function has
    %none until its equations translate: unforced, a declared 2-in name with
    %a 1-in equation compiled the ordinary typed branch instead of the
    %declared-arity refusal. The dispatch
    %stage's own force runs too late for this decision.
    metta_ensure_compiled(Fun),
    length(T, NewInputArity),
    length(Bound, BoundArity),
    InputArity is BoundArity + NewInputArity,
    Arity is InputArity + 1,
    (   declared_arity_misses_existing_equation(Fun, UniqueTypeChains,
                                                 InputArity)
    ->  ( IsPartial -> append(Bound, T, Written) ; Written = T ),
        record_runtime_args(RuntimeArgs, T),
        AfterHead = [declared_arity_refusal(Fun, Written, Out)|Goals]
    ;   incomplete_application_kind(Fun, Arity, ApplicationKind),
        ApplicationKind == overapplied,
        \+ metta_segment_equation(Fun)
    ->  ( IsPartial -> append(Bound, T, Written) ; Written = T ),
        record_runtime_args(RuntimeArgs, T),
        AfterHead = [function_overapplication(Fun, Written, Out)|Goals]
    ;   fitting_type_chains(UniqueTypeChains, InputArity, Selection),
        ( IsPartial -> append(Bound, T, Written) ; Written = T ),
        (   Selection = refused(Rule, Reason)
        ->  Refusal = ['Error', [Fun|Written],
                       ['TypingRuleRefusal', Rule, Reason]],
            record_runtime_args(RuntimeArgs, T),
            AfterHead = [Out = Refusal|Goals]
        ;   applicable_typed_branches(Selection, Fun, T, IsPartial, Bound,
                                      Out, RuntimeArgs, BeforeCall, Evidence,
                                      Branches),
            Branches \== [],
            (   nonvar(Evidence)
            ->  Evidence = refinement(Cell),
                AfterHead = [Cell = refinement_evidence([], false),
                             Dispatch|Goals],
                Fallback = dispatch_refinement_mismatch_result(
                               Fun, Written, Cell, Out)
            ;   AfterHead = [Dispatch|Goals],
                Fallback = dispatch_mismatch_result(Fun, Written, Out)
            ),
            first_applicable_branch(Branches, Fallback, Dispatch)
        )
    ).

declared_arity_misses_existing_equation(Fun, Chains, InputArity) :-
    presented_type_chains(Chains, InputArity, []),
    %A refusal rule that declined this arity owns the answer: a user
    %arrow-arity rule's (TypingRuleRefusal Name Reason) must not be
    %overwritten by the generic count mismatch
    %[tested: test_a_user_typing_rule_participates_like_a_shipped_one].
    \+ type_chain_refusal(Chains, InputArity, _, _),
    current_metta_module(Module),
    (   fun_meta_module(Module, Fun, Owner),
        fun_meta_head(Owner, Fun, Head),
        length(Head, InputArity)
    ;   inherited_stored_declaration_owns_arity(Module, Fun)
    ),
    !.

%A child with no binding of its own sees &self's declaration as the only typed
%meaning in its lexical environment, so a call shape no arrow presents is an
%arity error there. This is deliberately narrower than ordinary partial
%application in &self: it answers only for a named module, an inherited stored
%arrow, and no local declaration or function [tested:
%test_an_inherited_arrow_does_not_veto_a_local_definition;
%commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c].
inherited_stored_declaration_owns_arity(Module, Fun) :-
    \+ metta_self_module(Module),
    metta_module_space(Module, Space),
    \+ match_stored(Space, [':', Fun, _], _, _),
    \+ fun_in(Module, Fun),
    normalized_self_type_declaration(Fun, Raw),
    metta_runtime_type(Raw, [->|_]).

%THE FIRST ARROW THAT ANSWERS IS THE ONE THAT ANSWERS, and the soft cut has to
%sit on each branch rather than around all of them. A flat disjunction under
%one `*->` commits to the GROUP, so a name carrying two declarations at the
%same arity ran both and answered the call once per declaration.
%
%That is a multiplicity divergence and multiplicity is specified: with
%`(: df (-> Atom %Undefined%))` and `(: df (-> Number %Undefined%))` declared
%over one equation, the reference answers `(quote (+ 1 2))` once, reading the
%FIRST declaration's mask, where this engine answered `(quote (+ 1 2))` and
%`(quote 3)` [assumed 2026-08-24: measured against an earlier reference corpus
%at that date, not re-measured against upstream PeTTa]. It is not a corner:
%loading the reference's own prelude beside minimal_metta_lib gives `function`
%two declarations, and `!(function (return 7))` answered `7, 7`, which is what
%made every strategy suite answer nothing once the duplicates compounded
%through recursion.
%
%The arity filter above already removed the WIDER-declaration case; this
%removes the same-arity one, and the two together are what
%the reference's own signature lookup does in one step [assumed: adopted from
%an earlier reference semantics, not re-measured against upstream PeTTa].
%
%Each branch keeps its own soft cut, so a branch that answers keeps EVERY
%answer it has: a MeTTa function is nondeterministic and this must not become
%once/1.
first_applicable_branch([], Fallback, Fallback).
first_applicable_branch([Branch|Branches], Fallback, ( Branch *-> true ; Rest )) :-
    first_applicable_branch(Branches, Fallback, Rest).

%A declared call that no branch answered says WHY when the declaration is the
%reason: every rejection it makes, `(Error <call> (BadArgType <position>
%<expected> <actual>))`, against the arguments AS WRITTEN, which is the form
%whose types decide [assumed: the per-actual and widened-actual shapes were
%adopted from an earlier reference corpus, not re-measured against upstream
%PeTTa].
%
%It answers NOTHING when the declaration makes no rejection, so a call whose
%types check and whose equations do not match keeps this engine's own reading
%rather than gaining the reference's NotReducible: `(= (f 1) one)` then `!(f 2)`
%answers `[(f 2)]` there and nothing here, and that divergence is not this
%change's to make [measured 2026-08-19 against the arbiter]. The soft cut is
%what keeps the successful path unchanged: it commits to the branches whenever
%any of them answered.

%When some declaration has exactly this call's arity, only those apply. A
%wider declaration would otherwise also build a branch for a shorter call and
%answer the same thing twice: with (: g (-> A Atom B)) and
%(: g (-> A Atom Number B)) both declared, (g x y) answered (x y) twice.
%
%When NOTHING decides this arity the call is a partial application, and every
%declaration stays a candidate so currying keeps working. A named refusal is
%kept distinct from that absence; otherwise filtering it out would select the
%partial fallback and make an arrow-arity refusal behaviorally inert.
fitting_type_chains(Chains, InputArity, Fitting) :-
    presented_type_chains(Chains, InputArity, Exact),
    (   Exact \== []
    ->  Fitting = Exact
    ;   type_chain_refusal(Chains, InputArity, Rule, Reason)
    ->  Fitting = refused(Rule, Reason)
    ;   Fitting = Chains
    ).

%The full evaluator needs the same argument view as a compiled call, but it
%applies that view at run time before asking reduce/3 for one minimal step.
%The first signature decides, including the reference's raw-tail fallback for
%an arity that the arrow does not present.  With no signature every position
%evaluates.  Returning booleans keeps this boundary about evaluation only;
%the ordinary typed dispatcher still owns every argument check and rejection.
%[source: MettaHyperonFull/Minimal/Interpreter.lean:3760-3784 and 7394-7440,
%`argMask` and the argument fold in `mettaEval`; commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87]
metta_runtime_argument_mask(Fun, Arity, Mask) :-
    metta_runtime_first_signature(Fun, Signature),
    !,
    metta_runtime_parameter_types(Signature, Arity, Types),
    maplist(metta_runtime_parameter_evaluates, Types, Mask).
metta_runtime_argument_mask(_, Arity, Mask) :-
    length(Mask, Arity),
    maplist(=(true), Mask).

metta_runtime_first_signature(Fun, Signature) :-
    call_site_type_chains(Fun, [Signature|_]), !.
metta_runtime_first_signature(Fun, Signature) :-
    catch_recover(seam:builtin_type_declaration(Fun, Signature), fail),
    !.

metta_runtime_parameter_types([->|Types], Arity, Parameters) :-
    (   once(present_type_chain([->|Types], Arity, [->|Presented]))
    ->  append(Parameters, [_], Presented)
    ;   mask_prefix(Types, Arity, Parameters)
    ).

metta_runtime_parameter_evaluates(Type, false) :-
    non_evaluated_parameter_type(Type), !.
metta_runtime_parameter_evaluates(_, true).

%Result finality is the other half of the same first-signature convention.
%An Atom result is data even when its shape names another operation; every
%other result re-enters the full evaluator.
%[source: MettaHyperonFull/Minimal/Interpreter.lean:3786-3799 and 7451-7460,
%`returnsAtom` and its use in `mettaEval`; commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87]
metta_runtime_returns_atom(Fun) :-
    metta_runtime_first_signature(Fun, [->|Types]),
    append(_, [Declared], Types),
    declared_type_for_evaluation(Declared, View),
    View == 'Atom'.

type_chain_takes(InputArity, [->|Types]) :-
    present_type_chain([->|Types], InputArity, _).

presented_type_chains([], _, []).
presented_type_chains([Chain|Chains], Arity, Presented) :-
    (   present_type_chain(Chain, Arity, Expanded)
    ->  Presented = [Expanded|Rest]
    ;   Presented = Rest
    ),
    presented_type_chains(Chains, Arity, Rest).

%A final `(:seg T)` formal absorbs every remaining argument and presents one
%copy of T per position.  Fixed arrows retain the existing arity typing rule,
%including provider refusals.
present_type_chain([->|Types], InputArity, [->|Presented]) :-
    append(Parameters, [Out], Types),
    (   append(Fixed, [Rest], Parameters),
        rest_parameter(Rest, Element)
    ->  length(Fixed, FixedArity),
        InputArity >= FixedArity,
        RestArity is InputArity - FixedArity,
        length(RestTypes, RestArity),
        maplist(=(Element), RestTypes),
        append(Fixed, RestTypes, PresentedParameters),
        append(PresentedParameters, [Out], Presented)
    ;   length(Parameters, DeclaredInputArity),
        current_metta_module(Module),
        typing_rule_accepts_resolved(Module, 'arrow-arity', InputArity,
                            DeclaredInputArity),
        Presented = Types
    ).

rest_parameter(Rest, Element) :-
    nonvar(Rest),
    Rest = [Marker, Element],
    nonvar(Marker),
    Marker == ':seg'.

% Validate written type syntax at admission, never on fixed call presentation.
% Preparation and storage share one pure syntax analysis. Live vocabulary
% checks stay outside the table and retain their position among refusals.
validate_type_splices(Type) :-
    validate_type_splices(Type, _).

validate_type_splices(Type, Annotated) :-
    (   acyclic_term(Type)
    ->  type_syntax_analysis(Type, Classification, Checks),
        ( Checks == [] -> true ; validate_type_syntax_checks(Checks) ),
        Annotated = Classification
    ;   throw(error(domain_error(acyclic_type_syntax, Type), none))
    ).

% Variant keys distinguish a previously open type from its later binding.
% The scan records ordered checks instead of caching vocabulary-dependent
% validity or exceptions. Difference lists keep nested checks in source order.
% [source: engine/parser.pl:metta_symbol_writable/1; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7]
:- table type_syntax_analysis/3 as (variant, private).
type_syntax_analysis(Type, Annotated, Checks) :-
    type_syntax_scan(Type, Seen, Checks, []),
    ( var(Seen) -> Annotated = false ; Annotated = true ).

type_syntax_scan(Type, Annotated, Checks, Rest) :-
    (   var(Type)
    ->  Checks = Rest
    ;   Type == '%Rest%'
    ->  Checks = [retired(Type)|Rest]
    ;   Type = [Head|Items]
    ->  (   Head == '%Rest%'
        ->  Checks = [retired(Type)|Rest]
        ;   Head == ':seg'
        ->  Checks = [invalid(Type)|Rest]
        ;   (   atom(Head), sub_atom(Head, 0, 2, _, '-[')
            ->  Annotated = true, Owner = owner(Type)
            ;   Head == '->'
            ->  Owner = plain
            ;   Owner = ordinary
            ),
            ( compound(Head)
            -> type_syntax_scan(Head, _, Checks, AfterHead)
            ;  Checks = AfterHead ),
            ( is_list(Items), Items \== [] -> Context = Owner
            ; Context = ordinary ),
            type_syntax_items(Items, Context, Annotated, AfterHead, Rest)
        )
    ;   Checks = Rest
    ).

type_syntax_items(Items, Context, Annotated, Checks, Rest) :-
    (   var(Items)
    ->  Checks = Rest
    ;   Items = [Item|Tail]
    ->  (   Context \== ordinary, Tail \== [],
            nonvar(Item), Item = [Marker|_], Marker == ':seg'
        ->  (   Tail = [_], is_list(Item), Item = [_, Element]
            ->  ( Context = owner(Arrow)
                -> Checks = [owner(Arrow, Item)|AfterOwner]
                ;  Checks = AfterOwner ),
                type_syntax_scan(Element, Annotated, AfterOwner, AfterItem)
            ;   Checks = [invalid(Item)|AfterItem]
            )
        ;   ( compound(Item) ; Item == '%Rest%' )
        ->  type_syntax_scan(Item, Annotated, Checks, AfterItem)
        ;   Checks = AfterItem
        ),
        type_syntax_items(Tail, Context, Annotated, AfterItem, Rest)
    ;   type_syntax_scan(Items, Annotated, Checks, Rest)
    ).

validate_type_syntax_checks([]).
validate_type_syntax_checks([Check|Checks]) :-
    (   Check = retired(Type)
    ->  retired_arrow_splice(Type)
    ;   Check = invalid(Type)
    ->  invalid_arrow_splice(Type)
    ;   Check = owner(Arrow, Splice),
        ( metta_arrow_type_shape(Arrow, _, _, _, _) -> true
        ; invalid_arrow_splice(Splice) )
    ),
    validate_type_syntax_checks(Checks).

retired_arrow_splice(Type) :-
    throw(error(domain_error(retired_arrow_splice, Type),
                context(type_declaration,
                        '%Rest% is retired; write (:seg T) as the final arrow parameter'))).

invalid_arrow_splice(Type) :-
    throw(error(domain_error(final_arrow_splice, Type),
                context(type_declaration,
                        'write (:seg T) once, as the final parameter before the result type'))).

%THE CHEAP QUESTION FIRST, then the walk. This runs on the
%partial-application decision of every typed call, and the walk behind it is
%over every candidate type chain with a length/2 on each.
%
%Only a USER rule can refuse here. The one shipped arrow-arity rule is
%typing-arrow-arity-exact, `(Same, Same, accept)`, which accepts an exact
%match and defers everything else, and arrow-arity does not fall through to
%widening the way ordinary, derived and reporting do
%[source: engine/type_rules.pl, typing_rule_entry/7 and
%typing_check_decision/7]. So with no user arrow-arity rule registered the
%walk cannot succeed and every step of it is dead work.
%
%The saving is small and is recorded as small: nilbc, which decides partial
%application constantly, does not measurably reach this path
%[measured 2026-08-30: 308,570,186 inferences before and after]. What the
%guard buys is that the walk cannot grow into a cost for a program that does
%reach it while registering no rule, which is every program that registers
%none.
%
%current_metta_module/1 moves out of the loop with it: it was read once per
%candidate and answers the same thing every time.
type_chain_refusal(Chains, InputArity, Rule, Reason) :-
    current_metta_module(Module),
    raw_registered_typing_rule(user, Module, _, 'arrow-arity', _, _, _),
    !,
    member([->|Types], Chains),
    length(Types, Count),
    DeclaredInputArity is Count - 1,
    typing_rule_refusal_resolved(Module, 'arrow-arity', InputArity,
                        DeclaredInputArity, Rule, Reason),
    !.

applicable_typed_branches([], _, _, _, _, _, _, _, _, []).
applicable_typed_branches([TypeChain|Rest], Fun, T, IsPartial, Bound, Out,
                          RuntimeArgs, BeforeCall, Evidence, Branches) :-
    (   typed_functioncall_branch(Fun, TypeChain, T, [], IsPartial, Bound, Out,
                                  RuntimeArgs, BeforeCall, Evidence, BranchGoal)
    ->  Branches = [BranchGoal|More]
    ;   Branches = More
    ),
    applicable_typed_branches(Rest, Fun, T, IsPartial, Bound, Out,
                              RuntimeArgs, BeforeCall, Evidence, More).

typed_functioncall_branch(Fun, TypeChain, T, GsH, IsPartial, Bound, Out,
                          RuntimeArgs, BeforeCall, Evidence, BranchGoal) :-
    TypeChain = [->|Xs],
    append(_, [_], Xs), !,
    %The RESULT type is dropped by the same rule as the arguments, in the same
    %pass: a type variable that occurs once in the chain constrains nothing
    %wherever it sits.
    drop_unconstraining_types(TypeChain, Xs, AllTypes),
    typed_parameters(AllTypes, ArgTypes, OutType, Refined),
    metta_argument_type_origins(ArgTypes, ArgOrigins),
    argument_applicability_checks(T, ArgTypes, ArgOrigins, ApplicabilityChecks),
    translate_args_by_type(T, ArgTypes, GsT2, AVsTmp0, ArgChecks, Computed0),
    ( IsPartial -> append(Bound, AVsTmp0, AVsTmp) ; AVsTmp = AVsTmp0 ),
    append(GsH, ApplicabilityChecks, BeforeArgs),
    append(BeforeArgs, GsT2, InnerEval),
    %THE RESULT IS CHECKED, exempting only the three types that constrain
    %nothing. Upstream emits exactly this beside every typed call --
    %`( (OutType == '%Undefined%' ; OutType == '_' ; OutType == 'Atom')
    %   -> Extra = [] ; Extra = [('get-type'(Out,OutType) *-> true
    %                             ; 'get-metatype'(Out,OutType))] )`
    %[source: PeTTa@ae66fa8 src/translator.pl:382-383] -- and the same goal
    %shape it uses for an argument, which here is check_argument_type/3.
    %
    %This was `OutCheck = []` until 2026-08-30, on the arbiter's reading that a
    %declared result "controls whether the produced atom re-enters evaluation"
    %rather than filtering the value. Under that reading upstream's
    %examples/types_nondet.metta could not pass: `(: f (-> Type1 Type1))` beside
    %`(: f (-> Type2 Type2))` is supposed to answer NOTHING for an argument of
    %Type1 whose body produces a Type2, because the Type1 branch fails on its
    %RESULT and the Type2 branch fails on its argument. Without the result half
    %the Type1 branch answered [measured 2026-08-30: `(f T3in)` answered
    %Tdefault here and `()` upstream].
    %Through type_check_goal/4, the same door the argument checks below use.
    %Emitted as a bare check_argument_type/3 it cost 35 inferences on every
    %typed call against 3 for the same function undeclared, because the
    %general check walks the value's types where `number/1` decides it in one
    %VM instruction the counter does not even see
    %[measured 2026-08-30: per-call 47.24 typed against 15.24 plain over a
    %null-driver baseline of 12.24, and back to parity through this door;
    %tested: test_extension_cost_rows_are_marginal].
    %A REFINED result type is checked at the crossing by a goal that can
    %answer an Error rather than fail: the call binds a fresh Produced and
    %metta_refined_result/6 (engine/metta/refinements.pl) then binds Out to
    %the value the declared type admits, to `(Error <call as written>
    %(BadReturnValue <constraint> <value>))` when the base admits it and a
    %decided constraint fails, and fails as the ordinary check below does when
    %the base itself is wrong. The written call is the one
    %dispatch_mismatch_result/3 names for an argument refusal, computed here
    %exactly as typed_functioncall_dl/10 computes it above.
    (   metta_unchecked_result_type(OutType)
    ->  OutCheck = [],
        Produced = Out
    ;   nonvar(OutType), OutType = [OutHead|_], OutHead == 'Annotated',
        metta_refined_type(OutType, _, _)
    ->  ( IsPartial -> append(Bound, T, Written) ; Written = T ),
        metta_argument_type_origins([OutType], [OutOrigin]),
        OutCheck = [metta_refined_result(Fun, Written, Produced, OutType,
                                         OutOrigin, Out)]
    ;   metta_argument_type_origins([OutType], [OutOrigin]),
        type_check_goal(Out, OutType,
                        check_argument_type(Out, OutType, OutOrigin),
                        OutGoal),
        % A produced Error has already crossed the operation's failure door.
        % Keep it visible to transaction and try; other wrong sorts still fail.
        OutCheck = [(OutGoal *-> true
                    ; metta_engine:metta_error_operand([Out], Out))],
        Produced = Out
    ),
    %NO RESULT CONTINUATION IS EMITTED HERE, and the reason is that this engine
    %compiles where the reference steps. Its `eval` applies one equation
    %and hands the instantiated right-hand side to `returnsAtom`, which sends it
    %back through evaluation; compiling that right-hand side has ALREADY done
    %exactly that one round. Adding a second is a double evaluation, measured:
    %`(: uf2 (-> Atom %Undefined%))` with `(= (uf2 $x) (cons-atom (+ 1 2) (b)))`
    %answers `((+ 1 2) b)` there, because cons-atom's own `Atom` result
    %stops there, and a continuation at this call site answered `(3 b)`
    %[assumed 2026-08-24: measured against an earlier reference corpus at that
    %date, not re-measured against upstream PeTTa].
    %
    %The one shape compilation does NOT cover is a body that emits no goals,
    %where nothing was evaluated at all; that is handled once, at the equation,
    %in translate_clause/3.
    %The checks are placed against an EMPTY prefix so the guard below can sit
    %between the argument evaluations and them. An argument that produced an
    %Error fails its own declared check -- an Error is not a Number -- and a
    %failed check takes the whole branch down, which is how
    %`(needs-number (+ 1 "bad"))` answered nothing where the reference answers
    %the inner error atom.
    place_type_checks(ArgTypes, OutType, ArgChecks, OutCheck, [], AfterEval,
                      Extra),
    typed_call_operands(Fun, Computed0, Guarded),
    build_call_or_partial_dl(Fun, AVsTmp, Produced, CallGoals, [], Extra),
    (   nonvar(Refined)
    ->  Evidence = refinement(Cell),
        (   AfterEval == []
        ->  goals_list_to_conj(ArgChecks, ArgumentCheck),
            Probe = (\+ \+ ArgumentCheck)
        ;   goals_list_to_conj(AfterEval, Probe)
        ),
        append(BeforeCall, CallGoals, Continue),
        goals_list_to_conj(Continue, Proceed),
        Checked = [( Probe
                   -> nb_setarg(2, Cell, true), Proceed
                   ;  metta_record_refinement_failure(Fun, AVsTmp, Cell),
                      fail
                   )]
    ;   append([AfterEval, BeforeCall, CallGoals], Checked)
    ),
    guard_error_arguments(Guarded, Out, Checked, AfterInnerEval, []),
    append(InnerEval, AfterInnerEval, CallGoalsList),
    %The values THIS branch saw, recorded for the caller that reports the call
    %as dispatched. Each branch records its own, so backtracking out of one
    %leaves the next free to record what it saw. Written inline because ==/2
    %and =/2 compile to VM instructions where a helper predicate is a call,
    %and this runs once per branch of every typed call site the engine
    %compiles [measured 2026-09-07: the same split through a helper predicate
    %cost the boot 580 inferences and through an ==/2 test 475; unification in
    %the condition costs it 0].
    (   RuntimeArgs = runtime_args(Recorded)
    ->  GoalsList = [(Recorded = AVsTmp0)|CallGoalsList]
    ;   GoalsList = CallGoalsList
    ),
    goals_list_to_conj(GoalsList, BranchGoal).

%The same request answered where the branch is decided while the call
%compiles rather than emitted as a goal: a declared-arity refusal, an
%overapplication and a refused selection each name the written call directly.
%A call rather than an inline test, because these three are the rare paths.
record_runtime_args(no_runtime_args, _) :- !.
record_runtime_args(runtime_args(Args), Args).

% Split the result and detect refined parameters in the same arrow walk.
% Atomic types cannot contain a refinement. Only compound declarations need
% the checked-type projection that unwraps a type-position modifier.
typed_parameters([OutType], [], OutType, _) :- !.
typed_parameters([Type|Types], [Type|Parameters], OutType, Refined) :-
    (   compound(Type),
        declared_type_for_check(Type, Checked),
        nonvar(Checked),
        Checked = [Head, _, _|_],
        (   Head == 'Annotated'
        ;   Head == '|', metta_refined_union_type(Checked)
        )
    ->  Refined = true
    ;   true
    ),
    typed_parameters(Types, Parameters, OutType, Refined).

% Freeze the diagnostic when the evaluated values are still available. This
% does not evaluate the source operands again. Identical failed snapshots from
% alternative arrows are kept once, while their ordinary refusal multiplicity
% remains in Reasons. The cell survives branch backtracking, not call lifetime.
metta_record_refinement_failure(Fun, Arguments, Evidence) :-
    findall(Reason,
            ( \+ metta_call_accepted(Fun, Arguments),
              metta_bad_argument_reason(Fun, Arguments, Reason) ), Reasons),
    arg(1, Evidence, Previous),
    Snapshot = Arguments-Reasons,
    (   member(Seen, Previous), Seen =@= Snapshot
    ->  true
    ;   nb_setarg(1, Evidence, [Snapshot|Previous])
    ).

% A later accepting overload makes earlier failures irrelevant. A body or
% result check that fails after its parameters passed is not an argument
% refusal. Other mismatch policies retain their existing written-call answer.
dispatch_refinement_mismatch_result(Fun, Written, Evidence, Out) :-
    dispatch_policy_value(Fun, 'MismatchEnum', Policy),
    (   Policy == 'MismatchOriginal'
    ->  arg(2, Evidence, Accepted),
        Accepted == false,
        arg(1, Evidence, Reversed),
        (   Reversed == []
        ->  dispatch_mismatch_result(Fun, Written, Out)
        ;   reverse(Reversed, Snapshots),
            member(_-Reasons, Snapshots),
            member(Reason, Reasons),
            metta_error_atom(Fun, Written, Reason, Out)
        )
    ;   dispatch_mismatch(Policy, Fun, Written, Out)
    ).

%evaluated_argument_values/3's typed twin. A parameter the evaluation mask
%holds back (Atom, and any user type declared DontEvalType) receives the
%argument AS WRITTEN, so nothing was evaluated at that position and nothing
%there can have produced an Error: `(assertEqual (Error a b) (Error a b))`
%keeps comparing two Error atoms.
%An operation whose contract is to OBSERVE an error receives it as a value, so
%none of its operands is tested and none is recovered.
typed_call_operands(Fun, _, []) :- error_transparent_operation(Fun), !.
typed_call_operands(_, Computed, Computed).

%A shared raw type variable needs the whole written call checked before any
%argument runs. Earlier formals bind it and later formals consume that exact
%binding; ordinary chains retain the existing evaluate-then-check path.
argument_applicability_checks(Args, Types, Origins, Checks) :-
    memberchk(derived_variable, Origins),
    !,
    maplist(argument_applicability_check, Args, Types, Origins, Raw),
    commit_checks(Raw, Checks, []).
argument_applicability_checks(Args, Types, Origins, Checks) :-
    metatype_applicability_checks(Args, Types, Origins, Raw),
    commit_checks(Raw, Checks, []).

metatype_applicability_checks([], _, _, []).
metatype_applicability_checks([Argument|Arguments], [Type|Types],
                              [Origin|Origins], Checks) :-
    (   Origin == metatype,
        \+ unchecked_parameter_type(Type)
    ->  Checks = [check_argument_type(Argument, Type, Origin)|Rest]
    ;   Checks = Rest
    ),
    metatype_applicability_checks(Arguments, Types, Origins, Rest).

argument_applicability_check(Argument, Type, Origin,
                             check_argument_type(Argument, Type, Origin)).

%An argument whose declared type is a type variable occurring NOWHERE else in
%the chain constrains nothing, and its check is pure waste. The check is
%(has_type(A,T) *-> true ; get-metatype(A,T)), so with T unbound it enumerates
%the argument's types, binds T to the first, and cannot fail: get-metatype/2
%answers for every term. Nothing then reads T.
%
%(: == (-> $a $b Bool)) is the shape, and it is what the builtin type file
%declares for ==, != and =alpha. Measured 2026-08-15 over 1000 calls of a
%two-argument function: 683 inferences undeclared, 1620 declared with two free
%type variables, 1562 declared with concrete types. The free variables were
%the MOST expensive of the three, for checks that decide nothing.
%
%A variable occurring twice is a real constraint and stays: (-> $a $a Bool)
%requires both arguments to have a consistent type, and (-> $a Bool $a) ties an
%argument to the result. Only a bare singleton variable is dropped, so
%(-> (List $a) Bool) keeps its check on the list.
%A chain with no type variables at all has nothing to drop, and that is most
%of them: every arithmetic, comparison and math declaration in
%lib_builtin_types.metta is concrete. term_variables/2 answers that in one
%call, where the occurrence walk below cost 72 inferences per compiled call
%site [measured 2026-08-15].
drop_unconstraining_types(TypeChain, ArgTypes0, ArgTypes) :-
    term_variables(TypeChain, TypeVariables),
    (   TypeVariables == []
    ->  ArgTypes = ArgTypes0
    ;   type_variable_occurrences(TypeChain, Occurrences),
        maplist(drop_unconstraining_type(Occurrences), ArgTypes0, ArgTypes)
    ).

drop_unconstraining_type(Occurrences, Type, Dropped) :-
    (   var(Type),
        occurrence_count(Occurrences, Type, 1)
    ->  Dropped = '_'
    ;   Dropped = Type
    ).

%Every variable OCCURRENCE, duplicates kept, which is what term_variables/2
%cannot report.
type_variable_occurrences(Term, [Term]) :- var(Term), !.
type_variable_occurrences(Term, Occurrences) :-
    compound(Term),
    !,
    Term =.. [_|Args],
    maplist(type_variable_occurrences, Args, Lists),
    append(Lists, Occurrences).
type_variable_occurrences(_, []).

occurrence_count(Occurrences, Variable, Count) :-
    include(==(Variable), Occurrences, Same),
    length(Same, Count).

%One commit covers every check that constrains the same type variables.
%
%Where the output type shares no variable with the arguments, the argument
%checks commit as a group before the call, so an ill-typed call never runs the
%body, and the output check commits separately after it.
%
%Where the output shares one, as in (-> $a $a), committing before the call
%picks a witness the output cannot satisfy: with (: at A), (: at T), (: t T)
%and (= (testf at) t), the argument check binds $a to A and the answer t, of
%type T, is then rejected. Both halves solve together after the call instead,
%which is the only order in which a shared variable can be assigned
%consistently [tested: examples/ch09-types/01-types.metta,
%a_shared_type_variable_is_assigned_after_the_call].
%The three that constrain nothing, plus an undropped variable. `Atom` is here
%because a declared Atom result is the mask, not a filter: it says the value
%travels as written [source: PeTTa@ae66fa8 src/translator.pl:382].
metta_unchecked_result_type(Type) :- var(Type), !.
metta_unchecked_result_type('%Undefined%').
metta_unchecked_result_type('_').
metta_unchecked_result_type('Atom').

place_type_checks(ArgTypes, OutType, ArgChecks, OutCheck, InnerEval, Inner, Extra) :-
    term_variables(ArgTypes, ArgVars),
    term_variables(OutType, OutVars),
    ( shares_a_variable(ArgVars, OutVars)
      -> Inner = InnerEval,
         append(ArgChecks, OutCheck, Both),
         commit_checks(Both, Extra, [])
       ; commit_checks(ArgChecks, Committed, []),
         append(InnerEval, Committed, Inner),
         Extra = OutCheck ).

% Asserted clauses do not receive source-level apply_macros expansion. Emit
% its scoped once form here; the final true keeps an enclosing disjunction
% outside the condition's commit.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/apply_macros.pl#L204-L210
commit_checks([], Tail, Tail) :- !.
commit_checks(Checks, [((Conj -> true), true)|Tail], Tail) :-
    goals_list_to_conj(Checks, Conj).

shares_a_variable(As, Bs) :- member(A, As), member(B, Bs), A == B, !.

%Selectively apply translate_args for non-Expression args while Expression args stay as data input:
%The argument checks are collected and committed as ONE group, after the
%argument evaluations. Checking each argument under its own commit cannot
%satisfy a type variable the arguments share: the first witness for one
%argument binds it, and nothing backtracks to the assignment the next
%argument needs. Committing per argument loses answers, and not committing
%at all repeats them once per consistent assignment, so the group is the
%unit: find one assignment that satisfies every argument, then stop looking.
%The evaluations stay outside the commit, because a nondeterministic
%argument must keep every answer it produces
%[tested: a_parametric_expected_type_enumerates_its_witnesses,
%translator_typed_checks].
%Computed rides this walk for the same reason it rides
%translate_call_args_dl/5: asking a second time costs, and the answer is free
%here. It names the operand values this branch EVALUATED, which are the ones
%that can hold an error atom the call must hand on rather than consume.
translate_args_by_type([], _, [], [], [], []) :- !.
translate_args_by_type(Args, Types, GsOut, AVs, Checks, Computed) :-
    metta_argument_type_origins(Types, Origins),
    translate_args_by_type_dl(Args, Types, Origins,
                              GsOut, [], AVs, Checks, [], Computed).

translate_args_by_type_dl(Args, Types, Goals0, Goals, AVs) :-
    metta_argument_type_origins(Types, Origins),
    translate_args_by_type_dl(Args, Types, Origins,
                              Goals0, Tail, AVs, Checks, [], _),
    commit_checks(Checks, Tail, Goals).

translate_args_by_type_dl([], _, _, Goals, Goals, [], Checks, Checks, []) :- !.
translate_args_by_type_dl([A|As], [T|Ts], [Origin|Origins],
                          Goals0, Goals, [AV|AVs], Checks0, Checks, Computed) :-
    ( non_evaluated_parameter_type(T)
      -> AV = A,
         AfterArg = Goals0,
         %The argument was not evaluated, so nothing at this position can hold
         %an error this call has to hand on: Computed skips it either way.
         Computed = More,
         ( ( Origin == metatype ; unchecked_parameter_type(T) )
           -> AfterCheck = Checks0
           ;  declared_type_for_check(T, CheckType),
              metta_argument_type_origins([CheckType], [CheckOrigin]),
              type_check_goal(A, CheckType,
                              check_argument_type(A, CheckType, CheckOrigin),
                              MaskedGoal),
              Checks0 = [MaskedGoal|AfterCheck] )
    ; ( T == 'SpaceType'
        -> translate_space_expr_dl(A, Goals0, AfterArg, AV)
        ;  translate_eager_argument_dl(A, Goals0, AfterArg, AV) ),
      (   Goals0 == AfterArg
      ->  Computed = More
      ;   nonvar(AV)
      ->  Computed = More
      ;   error_reifying_argument(A)
      ->  Computed = More
      ;   Computed = [AV|More]
      ),
      %An EVALUATED position is checked against its declared type whatever
      %that type is, metatype or not. Upstream appends the same check for
      %every declared type that is not `Atom` or `%Undefined%`
      %[source: PeTTa@ae66fa8 src/translator.pl:392-396,
      %`append(GsA1, [('get-type'(AV, T) *-> true ; 'get-metatype'(AV, T))])`].
      %
      %`Origin == metatype` used to skip it here, which was invisible while
      %every metatype parameter was MASKED and checked on the held argument by
      %the branch above. With `Atom` the only mask, the skip silently dropped
      %two refusals: `(: p (-> Expression %Undefined%))` answered 3 for
      %`(p (+ 1 2))` where upstream refuses, and atom-subst stopped refusing a
      %second operand that is not a variable [measured 2026-08-30].
      %The literal discharge is split out of the first disjunct so the audit
      %mode can reach it. `%Undefined%` and `_` constrain nothing and there is
      %no check to audit; a settled literal HAS a check and it was dropped, so
      %under the mode it comes back as an audited one whose fast side is
      %`true`. Its own note says a get-type extension may legitimately give a
      %literal a second type, which is exactly the claim worth auditing.
      ( ( T == '%Undefined%' ; T == '_' )
        -> AfterCheck = Checks0
      ; statically_typed_literal(AV, T),
        retained_static_type_shortcuts_allowed
        -> ( metta_discharges_verified
             -> contract_fallback_goal(check_argument_type(AV, T, Origin),
                                       LiteralSlow),
                Checks0 = [verified_discharge(true, LiteralSlow,
                                              discharge(literal, T, AV))
                          |AfterCheck]
             ;  AfterCheck = Checks0 )
      % Construction established the sort before this argument arrived. Its
      % retained source dependencies retire that proof when either arrow
      % changes; a refinement still needs its live value predicate.
      ; Origin == ordinary, ground(AV), AV = [_|_], ground(T),
        \+ metta_refined_type(T, _, _),
        retained_static_type_shortcuts_allowed,
        current_metta_module(Module),
        constructor_sort_proved(Module, AV),
        constructor_argument_proved(AV, T, ordinary)
        -> contract_fallback_goal(check_argument_type(AV, T, Origin), Slow),
           ( metta_discharges_verified -> Audit = audited ; Audit = plain ),
           discharge_goal(Audit, true, true, Slow,
                          discharge(constructed_argument, T, AV), Proved),
           ( Proved == true -> AfterCheck = Checks0
           ; Checks0 = [Proved|AfterCheck] )
      ; type_check_goal(AV, T,
                        check_argument_type(AV, T, Origin),
                        ArgGoal),
        Checks0 = [ArgGoal|AfterCheck] ) ),
    translate_args_by_type_dl(As, Ts, Origins, AfterArg, Goals, AVs,
                              AfterCheck, Checks, More).

%THE EVALUATION MASK. `Atom` is the SOLE unevaluated parameter type, read off
%upstream's compiler rather than inferred from probes: translate_args_by_type/4
%is one line of decision, `( T == 'Atom' -> AV = A, GsA = [] ; translate_expr(...)
%...)`, so every other declared type takes the ordinary eager route and, when
%it is not %Undefined%, carries a runtime type check besides
%[source: PeTTa@ae66fa8 src/translator.pl:389-397].
%
%This named three members until 2026-08-30, `Atom`, `Variable` and
%`Expression`, the three an earlier reference semantics masks. The extra
%two are the difference, and it is observable: with `Expression` masked,
%`(map-atom (cdr-atom (a b)) $y (q $y))` answered
%`((q cdr-atom) (q (a b)))`, mapping over the two PARTS of an unevaluated
%call, where upstream evaluates the list first and answers `((q b))`
%[measured 2026-08-30 under both engines]. Symbol and
%Grounded were never members on either reading.
%
%type_position_modifier/3 and DontEvalType stay. They are this engine's own
%declarative way to ask for a held position, upstream has no equivalent, and
%no upstream program can name them, so they add a capability without moving
%any answer upstream gives.
%
%The mask decides EVALUATION only. Whether the position is also type-checked
%is unchecked_parameter_type/1 below, and upstream separates them the same
%way: its `Atom` branch emits no goals at all, and every other type appends
%its own `get-type` check.
non_evaluated_parameter_type(Type) :- Type == 'Atom', !.
non_evaluated_parameter_type(Type) :- type_position_modifier(Type, _, _), !.
non_evaluated_parameter_type(Type) :-
    nonvar(Type),
    catch_recover(type_declaration(Type, 'DontEvalType'), fail).

%A masked position whose declared type still DECIDES something keeps its check,
%and the check reads the argument AS WRITTEN, which is the term whose type
%the reference reports. Dropping it would turn two conforming answers into
%non-conforming ones: `(: ef (-> Expression %Undefined%))` answers
%`(Error (ef 5) (BadArgType 1 Expression Number))` and
%`(Error (ef "s") (BadArgType 1 Expression String))`
%[assumed 2026-08-24: measured against an earlier reference corpus at that
%date, not re-measured against upstream PeTTa].
%
%Atom decides nothing: it is the gradual top metatype, admitted against every
%actual type, so its check can only ever succeed and is the same foregone
%conclusion statically_typed_literal/2 removes elsewhere. A DontEvalType marker
%is a compiler instruction rather than a value type, so no runtime type could
%satisfy it.
unchecked_parameter_type(Type) :- Type == 'Atom', !.
unchecked_parameter_type(Type) :-
    nonvar(Type),
    catch_recover(type_declaration(Type, 'DontEvalType'), fail).

%The body of a declared function may reuse only a check its own call boundary
%already performed. Every governing chain at this arity must name the same
%ground ordinary type at the position, and only the head variable itself is
%tracked. A merely consistent %Undefined% chain, a metatype, and a value
%computed from the parameter all retain their runtime checks.
%
%The environment keeps variable identity through nb_linkval/2. Translation can
%force another function recursively, so the previous environment is restored
%rather than deleted unconditionally. The chain group is the exact
%arrival-order group retained for this equation, rather than every compatible
%declaration currently visible for the function.
%
%This is soft-contract verification: discharge a contract only when the
%enclosing checked boundary proves it, and keep the dynamic check for an
%unknown. A later policy change recompiles this module through
%filereader:typing_policy_changed/1; there is no per-call cache probe.
%[source: Nguyen et al., Soft Contract Verification, POPL 2014,
%DOI 10.1145/2628136.2628156; commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd]
with_static_parameter_environment(Module, Function, Arguments, Chains, Goal) :-
    static_parameter_entries(Module, Function, Arguments, Chains, Entries),
    (   nb_current('$metta_static_parameter_environment', Previous)
    ->  Restore = previous(Previous)
    ;   Restore = absent
    ),
    setup_call_cleanup(
        nb_linkval('$metta_static_parameter_environment', Entries),
        call(Goal),
        restore_static_parameter_environment(Restore)).

restore_static_parameter_environment(previous(Previous)) :-
    nb_linkval('$metta_static_parameter_environment', Previous).
restore_static_parameter_environment(absent) :-
    nb_delete('$metta_static_parameter_environment').

static_parameter_entries(Module, Function, Arguments, Chains, Entries) :-
    length(Arguments, Arity),
    presented_parameter_type_chains(Module, Chains, Arity, Presented),
    static_parameter_entries(Arguments, Presented, Module, Function, Arity,
                             1, Entries).

% Arrival groups retain source syntax; normalize in the presentation walk
% that static parameter proofs already need, before choosing argument origins.
presented_parameter_type_chains(_, [], _, []).
presented_parameter_type_chains(Module, [Raw|Chains], Arity, Presented) :-
    normalize_callable_type_in(Module, Raw, Chain),
    (   present_type_chain(Chain, Arity, Expanded)
    ->  Presented = [Expanded|Rest]
    ;   Presented = Rest
    ),
    presented_parameter_type_chains(Module, Chains, Arity, Rest).

static_parameter_entries([], _, _, _, _, _, []).
static_parameter_entries([Argument|Arguments], Chains, Module, Function,
                         Arity, Position, Entries) :-
    (   var(Argument),
        static_checked_parameter_type(Chains, Position, Type)
    ->  Entries = [static_parameter(Argument, Module, Function, Arity,
                                    Position, Type)|Rest]
    ;   Entries = Rest
    ),
    Next is Position + 1,
    static_parameter_entries(Arguments, Chains, Module, Function, Arity,
                             Next, Rest).

static_checked_parameter_type(Chains, Position, Type) :-
    Chains = [_|_],
    findall(Candidate-Origin,
            ( member([->|Types], Chains),
              append(Parameters, [_], Types),
              metta_argument_type_origins(Parameters, Origins),
              nth1(Position, Parameters, Candidate),
              nth1(Position, Origins, Origin) ),
            [Type-ordinary|Rest]),
    ground(Type),
    \+ unchecked_parameter_type(Type),
    forall(member(Other-OtherOrigin, Rest),
           ( OtherOrigin == ordinary, Other =@= Type )).

static_parameter_proof_goal(Value, Type, Goal) :-
    ground(Type),
    static_contract_shortcuts_enabled,
    nb_current('$metta_static_parameter_environment', Entries),
    member(static_parameter(Parameter, Owner, _, _, _, Known),
           Entries),
    Parameter == Value,
    Known =@= Type,
    type_rules:typing_policy_shortcuts_allowed(Owner),
    !,
    Goal = nb_current('$metta_module', Owner).

%A check that cannot be DROPPED can still be SPECIALISED. Three types are
%decided by a single Prolog builtin, and when the declared type is one of them
%the compiler knows so, because the type is a compile-time constant. Putting
%that test in front turns the common case from a walk through
%current_metta_module/1, has_type_in/3, once/1 and type_candidate_in/3 into one
%builtin call [measured 2026-08-17: an output check of type Number, 8.00
%inferences per call to 1.00].
%
%The fallback is untouched and reached whenever the fast test fails, so this
%decides nothing the general check would decide differently. It only answers
%the common case sooner. That matters because the fast test is INCOMPLETE on
%purpose: `(: mysym Number)` makes has_type(mysym, 'Number') true while
%number(mysym) is false, and the second disjunct is what still says so.
%
%Soundness in the other direction is what makes the shortcut legal at all.
%Both get_type_candidate/2 and get_type_candidate_in/3 open with a CUTTING
%numeric clause. Signed-i64 integers and floats answer Number directly. Wider
%integers answer BigInt, which metta_types_match/2 admits when Number is the
%expected type. Thus number(V) implies has_type(V, 'Number') in every module,
%whatever a get-type extension adds later [source: engine/metta.pl,
%metta_numeric_type/2 and metta_types_match/2].
%
%This is the other half of what statically_typed_literal/2 below does, from the
%same compile-time fact. A compiler holding type information "remov[es] type
%and mode checks and ... call[s] specialized versions of some builtins"
%[source: Morales, Carro and Hermenegildo, Improved Compilation of Prolog to C
%Using Moded Types]; the removal is the literal case and this is the
%specialisation case.
%
%nonvar/1 first, and it is not defensive: a parametric declaration leaves the
%type a VARIABLE here, and intrinsic_type_test/3's head would bind it to
%'Number' and emit a number/1 test for a type nobody wrote. That is the same
%trap intrinsic_literal_type/2 below carries a note about, from the same shape.
%[tested: translator_literal_type_checks:an_intrinsic_type_check_is_specialised].
type_check_goal(Value, Type, General, Goal) :-
    contract_fallback_goal(General, Fallback),
    % Number, String, and Bool lead because SWI compiles their tests to VM
    % instructions. Replacing one with the inherited-clause owner guard kept
    % the same two-inference residual and measured 0.240us rather than
    % 0.231us per proved Number call over 100,000 calls, min of seven
    % [measured 2026-09-02: 0.231us intrinsic-first versus 0.240us static-first;
    % command=python -m benchmarks.declared_contracts --calls 100000
    % --reflective-calls 2000 --rounds 7; fixture=compiled-proved-number;
    % commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
    %A discharge claims the check it replaced could not have failed. Under
    %(pragma! verify-discharges true) that claim is AUDITED: the fast side
    %still decides, so the audited program answers what it answered, and the
    %check it replaced runs beside it with a disagreement raised rather than
    %absorbed. This is engine/specializer.pl's translation validation applied
    %to type checks instead of to specializations
    %[source: Pnueli, Siegel and Singerman, Translation Validation, TACAS 1998].
    %
    %The mode is read HERE, at translation time, so a clause compiled without
    %it carries no trace and the mode costs nothing when off. That is the same
    %bargain verify-specializations strikes, and it means the pragma has to
    %precede the code it audits. The metatype discharge in engine/metta/terms.pl
    %is the exception: it is not emitted, so it reads a runtime marker and
    %audits code that was already compiled
    %[tested: discharge_audit:an_audited_discharge_raises_a_disagreement].
    ( metta_discharges_verified -> Audit = audited ; Audit = plain ),
    (   nonvar(Type),
        intrinsic_type_test(Type, Value, Fast),
        intrinsic_type_shortcut_goal(Fast, Fallback, Shortcut)
    ->  discharge_goal(Audit, Shortcut, Fast, Fallback,
                       discharge(intrinsic, Type, Value), Goal)
    ;   static_parameter_proof_goal(Value, Type, Proof)
    ->  discharge_goal(Audit, ( Proof -> true ; Fallback ), Proof, Fallback,
                       discharge(proved_parameter, Type, Value), Goal)
    ;   Goal = Fallback
    ).

%`plain` keeps exactly the goal the emitter built. `audited` replaces it with
%the one relation every discharge reduces to, Fast still deciding.
discharge_goal(plain, Goal, _, _, _, Goal).
discharge_goal(audited, _, Fast, Slow, Site,
               verified_discharge(Fast, Slow, Site)).

% Only generated argument checks need the policy-strict fallback. Arbitrary
% goals passed by translator tests and other internal users retain their exact
% meaning.
contract_fallback_goal(check_argument_type(Value, Type, Origin), Goal) :-
    !,
    (   nb_current('$metta_static_contract_shortcuts', enabled),
        current_metta_module(Module)
    ->  (   type_rules:typing_policy_is_default(Module)
        ->  Goal = check_argument_type(Value, Type, Origin)
        ;   Goal = check_argument_type_under_policy(Value, Type, Origin)
        )
    ;   Goal = check_argument_type_under_live_policy(Value, Type, Origin)
    ).
contract_fallback_goal(General, General).

intrinsic_type_shortcut_goal(Fast, General, Goal) :-
    nb_current('$metta_static_contract_shortcuts', enabled),
    current_metta_module(Module),
    type_rules:typing_policy_shortcuts_allowed(Module),
    !,
    Goal = ( Fast -> true ; General ).
intrinsic_type_shortcut_goal(Fast, General, Goal) :-
    nb_current('$metta_static_contract_shortcuts', guarded),
    current_metta_module(Module),
    type_rules:typing_policy_is_default(Module),
    Goal = ( ( type_rules:typing_policy_is_default(Module), Fast )
             -> true
             ;  General ).

retained_static_type_shortcuts_allowed :-
    static_contract_shortcuts_enabled,
    current_metta_module(Module),
    type_rules:typing_policy_shortcuts_allowed(Module).

static_contract_shortcuts_enabled :-
    nb_current('$metta_static_contract_shortcuts', enabled).

intrinsic_type_test('Number', V, number(V)).
intrinsic_type_test('String', V, string(V)).
intrinsic_type_test('Bool',   V, (V == true ; V == false)).

%A literal argument's type is settled while the call site is being COMPILED,
%so the check emitted for it can only ever succeed and every inference it
%spends is spent on a foregone conclusion. `(: f (-> Number Number Number))`
%called as `(f 1 2)` compiled two has_type/2 goals over the constants 1 and 2,
%and they cost as much as the same call on two unknown variables: 31
%inferences per call against 6 for the same function undeclared, the whole 25
%being the checks [measured 2026-08-16, 20,000 calls of a site compiled once].
%Dropping every check leaves no once/1 wrapper either, so the fully literal
%call compiles to exactly what the untyped one does.
%
%Only four literal shapes qualify. A number is accepted by Number, including
%a BigInt integer through the directed compatibility rule. A string is String,
%and true and false are Bool, whatever a user's get-type extension adds later.
%
%This only ever DROPS a check that must pass; it never rejects. `(f "s")`
%against a Number parameter still compiles its check and still refuses at run
%time, because a get-type extension may legitimately give a literal a second
%type and deciding THAT statically would be unsound
%[tested: translator_literal_type_checks].
statically_typed_literal(Value, Type) :-
    nonvar(Type),
    nonvar(Value),
    intrinsic_literal_type(Value, Type).

%nonvar/1 above and ==/2 rather than head unification below, because BOTH are
%needed and the second is what a reader would skip. Written as
%`intrinsic_literal_type(true, 'Bool')`, a call with an unbound Value and
%Type = 'Bool' UNIFIES the head and binds Value to true. The argument being
%bound there is the call site's compile-time variable, so
%`(= (f $a $b) (g $a $b))` against `(: g (-> Bool Atom Bool))` compiled its
%head as `f(true, A, B)` and `(f False ...)` then matched no clause and
%answered nothing at all [reproduced 2026-08-16].
%
%Caught by a hand probe rather than by the gate, because the shape needs a
%Bool, Number or String parameter reached from ANOTHER function's body with a
%variable, and no example in the corpus had one
%[tested: translator_literal_type_checks:a_typed_parameter_is_not_frozen_at_compile_time].
intrinsic_literal_type(Value, 'Number') :- number(Value), !.
intrinsic_literal_type(Value, 'String') :- string(Value), !.
intrinsic_literal_type(Value, 'Bool') :- ( Value == true ; Value == false ).
