% Purpose: resolve scoped declarations, type compatibility, metatypes, and typed-call introspection
% Guarantees: native space classification does not bind an open expression
%   to a registered instance [tested:
%   space_value_recognition:classification_does_not_choose_a_registered_instance;
%   commit=5f3c10af0d15efa2c5acce4cc659edd4a7b83beb].
% Guarantees: refined union requirements retain value constraints at runnable
%   and compiled calls [tested:
%   union_types:a_refined_union_member_checks_the_value_at_each_call_door;
%   commit=7e2de138f59cd8137f55dce9e7f2f955906c76d1].
% Guarantees: constructor result sorts widen through subsorts while callable
%   result types retain their direct arrow result
%   [tested: a_data_constructor_result_sort_is_widened,
%   an_application_return_type_is_not_widened; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: reported_rest_arrow/3 reports the result of an empty splice run
%   while get-type of its head retains the written arrow
%   [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
% Guarantees: builtin_surface_governs_in/2 omits the prelude lookup for a
%   known name in the base module and retains named-space shadowing
%   [tested: prelude:a_named_space_shadows_a_prelude_name_at_another_arity;
%   commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
% Guarantees: Callable declaration readers and type witnesses use metta_runtime_type/2;
%   get-type and stored atoms retain the written annotation
%   [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Assumes: engine/metta.pl consults this plain file while its owning module is the load context.
% Guarantees: every definition retains engine/metta.pl's implementation module and original load order.
%   A host-owned numeric object satisfies a concrete Number requirement
%   without changing its reported class chain [tested:
%   test_numeric_objects_are_number_arguments_even_when_a_sibling_refuses;
%   commit=a0f1cc5f15a15e5ca6958fe02a20be8832c7237f].
%   Dispatch declarations obey lexical name hiding while reporting keeps the
%   complete in-scope declaration set [tested:
%   test_an_inherited_arrow_does_not_veto_a_local_definition,
%   lib_strategy:an_inherited_arrow_does_not_veto_a_local_definition;
%   commit=bbb512316280110a747e31c26adfc31e8c5104be].
%   A generated contract whose static shortcut is invalidated uses the
%   policy-strict witness relation, so an ordinary user refusal remains
%   decisive over numeric and exact witnesses while unrelated type queries
%   retain their established fast path [tested:
%   test_a_static_parameter_proof_yields_to_a_later_typing_rule;
%   commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
%   - metta_arrow_type_shape(+Raw,-Inputs,-Output,-Product,-Explicitness)
%   recognizes one proper prefix arrow declaration. Raw is the source list;
%   Inputs and Output are its unchanged type terms; Product is the normalized
%   cardinality/EffectClass product; Explicitness is implicit for `->` and
%   explicit for every `-[...]->` spelling. A non-arrow or malformed annotated
%   head fails instead of passing through or throwing.
%   - metta_arrow_type_chain(+Raw,-Types) projects both unannotated
%   `(-> A B)` and annotated `(-[det]-> A B)` declarations to the identical
%   runtime chain `[A,B]`. The annotation remains available only through
%   metta_arrow_type_shape/5.
%   - metta_presented_arrow_chain(+Raw,+Arity,-Presented) applies the existing
%   arrow-arity and `:seg` presentation rules to either spelling. Arity is
%   the call's input count; Presented is the headless parameter/result chain.
%   A named arrow-arity refusal or an invalid Raw makes the projection fail.
%   - This plain unit is consulted into the engine implementation module.
%   Sibling engine/metta/*.pl consumers call both predicates unqualified; a
%   declared module resolves them through its engine-module base or qualifies
%   that owning module, and must not load this unit as a module.
%   - Arrow projection classifies syntax only. It neither accepts a value nor
%   discharges a typing-rule check, so it reads no typing-rule family and does
%   not extend typing_policy_fast_path_family/1
%   [tested: tests/prolog/suites/typecheck/arrow_projection.plt;
%   commit=48cf04fb8dd80149b5e46e15f499f19f6c45348f].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/evaluation/metta.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Guarantees: scoped declaration readers resolve aliases in their declaration
%   tier; bound observers use the shared witness family while enumeration
%   reports expanded types [tested: structural_aliases; commit=acad923476d21110870f235192757281a737ee71].
% Guarantees: metta_runtime_type/2 canonicalises union syntax beside the arrow
%   projection, and the value doors admit a required union through some
%   alternative while a value whose own type is a union needs every alternative
%   admitted; a union is never read as a positional tuple
%   [tested: union_types:a_union_flattens_deduplicates_and_collapses_to_one_member,
%   union_types:an_actual_union_fits_a_wider_union_and_not_a_narrower_one,
%   union_types:a_union_of_tuples_keeps_the_positional_walk;
%   commit=78d1d8946990498965fa940a676d1b91fb8bd35f].

% Guarantees: metta_grounded_type/2 retains structural type candidates from
%   seam:grounded_type_names/2, so ordinary arrow unification checks live
%   tensor dimensions and binds their result dimensions
%   [tested: run_tests(tensor_shapes); commit=4eaefdd8d40e53b2613722287302a14b41704662].

%%% Type system: %%%

:- consult('type_aliases.pl').
:- consult('type_unions.pl').

% One surface parser feeds old runtime consumers and the compile-time checker.
% The output keeps binder names as canonical data: two `$e` slots therefore
% denote the same binder without exposing a fabricated Prolog variable.
metta_arrow_type_shape(Raw, Inputs, Output, Product, Explicitness) :-
    nonvar(Raw),
    Raw = [Head|Tail],
    Tail = [_|_],
    is_list(Raw),
    atom(Head),
    append(Inputs, [Output], Tail),
    (   Head == '->'
    ->  Product = effect(nondet, oracleIO),
        Explicitness = implicit
    ;   atom_concat('-[', Rest, Head),
        atom_concat(Inside, ']->', Rest),
        Inside \== '',
        atomic_list_concat(Slots, ',', Inside),
        (   Slots = [Slot]
        ->  (   catch(spaces:metta_determinism_canonical(Slot, Cardinality),
                      _, fail)
            ->  Product = effect(Cardinality, oracleIO)
            ;   atom_concat('$', Name, Slot),
                Name \== '',
                Product = effect_variable(Name)
            )
        ;   Slots = [CardinalitySlot, ClassSlot],
            (   catch(spaces:metta_determinism_canonical(CardinalitySlot,
                                                          Cardinality),
                      _, fail)
            ->  true
            ;   atom_concat('$', CardinalityName, CardinalitySlot),
                CardinalityName \== '',
                Cardinality = cardinality_variable(CardinalityName)
            ),
            (   atom_concat('$', ClassName, ClassSlot),
                ClassName \== ''
            ->  Class0 = effect_class_variable(ClassName)
            ;   catch(spaces:metta_effect_class_canonical(ClassSlot, Class0),
                      _, fail)
            ),
            (   Cardinality == nondet,
                \+ Class0 = effect_class_variable(_)
            ->  metta_effect_join(Class0, nondeterministicReadOnly, Class)
            ;   Class = Class0
            ),
            Product = effect(Cardinality, Class)
        ),
        Explicitness = explicit
    ),
    !.

metta_arrow_type_chain(Raw, Types) :-
    metta_arrow_type_shape(Raw, Inputs, Output, _, _),
    append(Inputs, [Output], Types).

% Callable readers inspect canonical structure while reporting retains spelling.
% Clang's written and canonical type views motivate this split.
% [source: https://github.com/llvm/llvm-project/blob/llvmorg-20.1.8/clang/docs/InternalsManual.rst#canonical-types;
% commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% The parser owns annotation validity; passing other types through preserves
% existing plain-arrow, unit and type-variable behaviour. Only the head is
% projected, so parameter and result variables still share their bindings.
% [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% A union is canonicalised HERE, beside the arrow projection, because this is
% the one written-to-canonical step every compatibility relation already applies
% to both of its sides. Doing it anywhere else would leave one family reading
% `(| Number Number)` where another reads `Number`. The guard is three inlined
% instructions and only a term whose head is `|` reaches
% metta_union_canonical/2 [tested: run_tests(union_types); commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
metta_runtime_type(Raw, Type) :-
    (   nonvar(Raw), Raw = [Head|_], Head \== '->',
        metta_arrow_type_chain(Raw, Types)
    ->  Type = [->|Types]
    ;   nonvar(Raw), Raw = [UnionHead|_], UnionHead == '|'
    ->  metta_union_canonical(Raw, Type)
    ;   Type = Raw
    ).

metta_presented_arrow_chain(Raw, Arity, Presented) :-
    metta_arrow_type_chain(Raw, Types),
    fitting_type_chains([[->|Types]], Arity, [[->|Presented]]),
    !.

%The space whose ':' declarations are in scope. A space's compiled clauses live
%in a module named after it, and space_module/2 is '&self' -> user and the
%identity otherwise, so inverting it recovers the space with no extra state to
%keep.
%
%Without this, get-type consulted '&self' literally, and a declaration made in
%any other space was invisible to it. That is not an edge case: every space
%pymetta creates is a named one, so `(: a A)` written there answered
%'%Undefined%' no matter what.
current_metta_space(Space) :- current_metta_module(Module),
                              metta_module_space(Module, Space).

%A ':' declaration in scope here: this space's, and &self's, since &self is the
%shared space. That is the rule fun_here/1 already applies to functions.
type_declaration(X, T) :- current_metta_module(Module),
                          type_declaration_in(Module, X, Raw),
                          metta_runtime_type(Raw, T).

%This reader retains written types for get-type; callable readers project
%each answer after lookup, even when their requested output is already bound.
%The prelude tier comes LAST in each clause, so a declaration a program
%writes for the same name wins over the engine's prelude, the order the
%type surface already keeps for get-type. The my-if tutorial mechanism is
%what this tier carries: an Atom parameter declared in engine/metta/prelude.pl
%masks that argument at every call site, which is how the prelude's
%assertEqualToResult receives its expected set unevaluated.
%In the user clause the prelude branch comes FIRST, and the order is
%about determinism, not precedence: a first-arg-indexed lookup fails
%fast for every ordinary name, and the disjunction is then EXHAUSTED
%when match/4 yields its last solution, so a raw first-solution caller
%(filereader.plt calls type_declaration/2 bare) is left with exactly the
%choicepoint profile this predicate had before the prelude existed.
%Precedence still belongs to the user because eviction removes the
%prelude's rows the moment &self defines or declares the name, so the
%two stores answer together only when the user has said nothing.
%A module and the space it serves used to be the same atom for every space but
%&self, so a module could be handed to match/4 where a SPACE was asked for.
%They are different atoms now, and metta_module_space/2 is the one step
%between them.
%match_stored/4 rather than match/4: this runs on every typed call, and the
%door's refusal decision is not one a declaration lookup can ever need, since
%the space it reads is the engine's own context rather than anything a program
%wrote [measured 2026-08-20: py-method-call paid three inferences per
%evaluation through the door].
:- dynamic type_declaration_in/3, governing_type_declaration_in/3.
:- dynamic definition_type_declaration_in/3.

type_declaration_in(Module, X, T) :- metta_self_module(Module), !,
                                     (   prelude_type_declaration(X, T)
                                     ;   match_stored('&self', [':', X, T], T, _) ).
%The prelude branch asks prelude_declaration_governs_in/2 here as the two
%definition readers below do, so get-type stops reporting the prelude's arrow
%for a name the named space has taken over: before this the call answered
%the space's own equation while get-type still answered the prelude's
%(-> Atom Atom Atom Atom %Undefined%), where &self, which evicts the row,
%answered %Undefined% [tested:
%prelude:a_named_space_shadows_a_prelude_name_at_another_arity; commit=bc0d495562674e064276e91f04c61286d0b93585].
type_declaration_in(Module, X, T) :- metta_module_space(Module, Space),
                                     (   prelude_declaration_governs_in(Module, X),
                                         prelude_type_declaration(X, T)
                                     ;   match_stored(Space, [':', X, T], T, _)
                                     ;   match_stored('&self', [':', X, T], T, _) ).
raw_type_declaration_in(Module, X, T, Owner) :-
    metta_self_module(Module), !,
    Owner = Module,
    ( prelude_type_declaration(X, T)
    ; match_stored('&self', [':', X, T], T, _) ).
raw_type_declaration_in(Module, X, T, Owner) :-
    metta_module_space(Module, Space),
    ( prelude_declaration_governs_in(Module, X),
      prelude_type_declaration(X, T), metta_self_module(Owner)
    ; match_stored(Space, [':', X, T], T, _), Owner = Module
    ; match_stored('&self', [':', X, T], T, _), metta_self_module(Owner) ).

%Call-site declarations are name lookup, not reporting. C++ unqualified
%lookup chooses the nearest nonempty declaration set before overload
%resolution; a declaration in an inner scope hides every outer overload even
%when their arities differ [source: WG21 N4986 sections 6.5.1, 6.5.2 and
%11.7.3; https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2024/n4986.pdf;
%commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c]. Here the prelude is not an outer SPACE row and remains in
%force. The selected stored tier is this space's declarations, or &self's only
%when this space binds neither declarations nor a function of that name.
%fun_in/2 is the arrival-time ownership bit: deferred equations set it before
%fun_meta_clause/4 exists, so fun_meta_module/3 is too late for this decision.
governing_type_declaration(X, T) :-
    current_metta_module(Module),
    governing_type_declaration_in(Module, X, T).

governing_type_declaration_in(Module, X, T) :-
    metta_self_module(Module),
    !,
    type_declaration_in(Module, X, Raw),
    metta_runtime_type(Raw, T).
governing_type_declaration_in(Module, X, T) :-
    (   prelude_type_declaration(X, Raw)
    ;   metta_module_space(Module, Space),
        (   once(match_stored(Space, [':', X, _], _, _))
        ->  match_stored(Space, [':', X, Raw], Raw, _)
        ;   \+ fun_in(Module, X),
            match_stored('&self', [':', X, Raw], Raw, _)
        )
    ),
    metta_runtime_type(Raw, T).
raw_governing_type_declaration_in(Module, X, T, Owner) :-
    metta_self_module(Module), !,
    raw_type_declaration_in(Module, X, T, Owner).
raw_governing_type_declaration_in(Module, X, T, Owner) :-
    (   prelude_type_declaration(X, T), metta_self_module(Owner)
    ;   metta_module_space(Module, Space),
        (   once(match_stored(Space, [':', X, _], _, _))
        ->  match_stored(Space, [':', X, T], T, _), Owner = Module
        ;   fun_in(Module, X)
        ->  fail
        ;   match_stored('&self', [':', X, T], T, _),
            metta_self_module(Owner)
        )
    ).

%An arriving equation owns its module before deferred compilation has made a
%fun_meta row. Its retained OrderFittest types therefore come only from the
%non-space prelude and declarations stored in that same space, never from an
%inherited &self row [tested:
%lib_strategy:an_inherited_arrow_does_not_veto_a_local_definition;
%commit=7b238053d2907cd514e3fd9a29927d43a53c5a3c].
definition_type_declaration_in(Module, X, T) :-
    prelude_declaration_governs_in(Module, X),
    prelude_type_declaration(X, Raw),
    metta_runtime_type(Raw, T).
definition_type_declaration_in(Module, X, T) :-
    metta_module_space(Module, Space),
    match_stored(Space, [':', X, Raw], Raw, _),
    metta_runtime_type(Raw, T).
raw_definition_type_declaration_in(Module, X, T) :-
    prelude_declaration_governs_in(Module, X),
    prelude_type_declaration(X, T).
raw_definition_type_declaration_in(Module, X, T) :-
    metta_module_space(Module, Space),
    match_stored(Space, [':', X, T], T, _).

%engine/prelude.metta promises a prelude name is "shadowable per named space
%exactly as builtins are", and the engine's own test for a builtin a module has
%taken over is fun_in/2: runtime_guarded_builtin_call/1 requires
%\+ fun_in(Module, Fun) before it will use the builtin's own guard
%[source: engine/translator/special_forms.pl:273-278; commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3]. The
%prelude's DECLARATION tier did not ask it. A named space defining if-equal at
%two inputs therefore kept the prelude's four-input arrow, no chain presented
%the written arity, and typed_functioncall_dl/10 compiled
%declared_arity_refusal/3: the same source text answered SHADOWED in &self and
%(Error (if-equal 1 1) IncorrectNumberOfArguments) under any host that mints a
%named space, which is the Python seat's every engine
%[measured 2026-09-07: `(= (if-equal $a $b) SHADOWED)` then `!(if-equal 1 1)`,
%SHADOWED through sh run.sh and the Error through MeTTa().run, and the same file
%answering SHADOWED in a named space once &self had evicted the prelude row
%first; command=swipl -q tests/prolog/probes/prelude/named_space_declaration_shadow.pl [named_first]; fixture=that probe, run in both orders on the merged tree e67e2db9 and answering ['SHADOWED'] in the named space and [yes] in &self each time; commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3].
%
%&self needs no such test and is deliberately excluded: a definition there
%EVICTS the prelude's row outright through evict_prelude_definition/1, because
%the prelude is &self's own tier. A named module cannot evict a row its
%siblings still read, so it shadows instead, and the two doors then agree
%[tested: prelude:a_named_space_shadows_a_prelude_name_at_another_arity;
%commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3].
%
%The question is about the NAME IN THIS MODULE rather than about a call site,
%so it is asked here, where both definition readers pass, and not at
%governing_type_chains_in/4 alone: equation_walk_class/5 would otherwise go on
%classifying the equation as `declared` on the strength of a declaration that
%no longer governs it.
prelude_declaration_governs_in(Module, X) :-
    (   metta_self_module(Module)
    ->  true
    ;   \+ fun_in(Module, X)
    ).

%The builtin type surface carries the prelude's declarations too, since that
%is where get-type reads them (engine/metta/prelude.pl writes each declaration
%into both stores), so get-type asks the same question of a surface row the
%PRELUDE wrote: in a named module that defines the name, that row stops
%governing and the module's own undeclared head reads %Undefined%, which is
%what &self answers once eviction takes the row. A row the engine's Prolog
%surface owns for a builtin keeps answering, because nothing evicts it in
%&self either and the two doors must agree [tested:
%prelude:a_named_space_shadows_a_prelude_name_at_another_arity; commit=bc0d495562674e064276e91f04c61286d0b93585].
builtin_surface_governs_in(Module, X) :-
    (   nonvar(Module), nonvar(X), metta_self_module(Module)
    ->  true
    ;   prelude_declaration(X, _)
    ->  prelude_declaration_governs_in(Module, X)
    ;   true
    ).

%Filter an already nonempty visible set. Keeping the emptiness test at the
%caller means the extra ownership lookup is paid only by typed heads.
governing_type_chains_in(Module, X, InScope, Unique) :-
    (   InScope == []
    ->  Unique = []
    ;   metta_self_module(Module)
    ->  list_to_set(InScope, Unique)
    ;   findall(Local,
                definition_type_declaration_in(Module, X, Local),
                Local0),
        list_to_set(Local0, Local),
        (   Local \== []
        ->  Selected = Local
        ;   fun_in(Module, X)
        ->  %A name this module DEFINES is not typed by anything it merely
            %inherits. The branch was written to stop an inherited &self row
            %vetoing a local definition, and read the prelude's rows back in
            %where the line above had just excluded them; since
            %prelude_declaration_governs_in/2 the prelude tier is inherited
            %too, so what a module-owned name with no stored declaration of
            %its own governs by is nothing, and the call compiles untyped --
            %which is exactly what the same equation gets in &self, where
            %evict_prelude_definition/1 takes the prelude's row away
            %[tested: prelude:a_named_space_shadows_a_prelude_name_at_another_arity,
            % lib_strategy:an_inherited_arrow_does_not_veto_a_local_definition;
            % commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3].
            Selected = []
        ;   Selected = InScope
        ),
        list_to_set(Selected, Unique)
    ).

%A declaration that is not an arrow types the SYMBOL and cannot type a call to
%it, and nothing said so. `(: inc Number)` beside `(= (inc $x) (+ $x 1))`
%compiles the call site as bare `inc("s", A)`, so the string travels into `+`
%and the program dies inside arithmetic with `+: number expected`; the same
%file written `(: inc (-> Number Number))` compiles
%`once(has_type("s",'Number') *-> true ; get-metatype(...))` around the call
%and refuses it at inc's own door [reproduced 2026-08-16, both goals are in
%filereader_untypable_declaration].
%
%So this refuses rather than warns. The defect is not that the declaration is
%wrong, it is that the declaration LOOKS like it types the function, does not,
%and every diagnostic the author then gets points somewhere else entirely.
%
%The condition is semantic, not spelling. A first draft rejected any type
%whose head merely LOOKED like a mistyped arrow, and this repository is its
%own counter-example: lib_nars.metta writes NARS inheritance as `(--> $a $b)`
%and lib_combinatorics.metta writes a lambda as `(|-> ...)`, 95 and 48
%occurrences, every one of them a deliberate atom in a data position. What
%decides here is whether the name has an arrow declaration AT ALL, which
%neither of those ever claims to be.
%
%One arrow among several declarations is enough, because MeTTa lets a name
%carry more than one. `%Undefined%` is the engine's own way of writing
%"deliberately untyped" and is not an offender, and neither is a variable,
%which a later binding may still fill.
%
%Judged over a name's WHOLE set of declarations, which is why the caller is
%the source loader and not add-atom/3. A build that writes `(: f Number)` and
%`(: f (-> Number Number))` as two atoms passes through a state where only the
%first is stored, and refusing there refuses a program that is about to be
%correct. Declarations that reach a space by any other route are named by
%space.lint(), which reads the finished space instead of an intermediate one.
untypable_declarations(Types, Offender) :-
    Types \== [],
    \+ ( member(Raw, Types), nonvar(Raw),
         metta_runtime_type(Raw, Arrow), Arrow = [->|_] ),
    member(Offender, Types),
    nonvar(Offender),
    Offender \== '%Undefined%'.

%The context is `none` rather than an unbound variable so that a file load
%replaces it with the filename: rethrow_metta_file_error/2 leaves an error
%whose context already unifies with context(_, _) exactly as it found it, and
%an unbound context unifies with anything.
refuse_untypable_declaration(Name, Types) :-
    (   untypable_declarations(Types, Offender)
    ->  throw(error(metta_untypable_declaration(Name, Offender), none))
    ;   true ).

%&self is always the engine's native space. Its fixed private storage module
%keeps this recursive type probe on a compiled direct call, with no provider
%dispatch or exception handler.
%The soft cut is the precedence rule: a program that declares an arrow for a
%name is answered from its own space and the engine's surface is never
%consulted, and only a name the program says nothing about falls through to
%the engine's. The engine's arrows have to be here at all because get-type
%stopped evaluating its argument, so an application now reaches this probe as
%written: without the fallthrough (get-type (+ 1 2)) typed ELEMENT-WISE and
%answered ((-> Number Number Number) Number Number) where it used to answer
%Number, and this engine answers ErrorType for (get-type (Error Foo Boo))
%from exactly this route.
get_function_type([F|Args], T) :- nonvar(F),
                                  (   normalized_self_type_declaration(F, Chain0)
                                  *-> true
                                  ;   seam:builtin_type_declaration(F, Chain0)
                                  ),
                                  metta_runtime_type(Chain0, Chain),
                                  length(Args, Arity),
                                  fitting_type_chains([Chain], Arity,
                                                      [[->|Ts]]),
                                  append(As,[T],Ts),
                                  metta_self_module(Self),
                                  metta_argument_type_origins(As, Origins),
                                  metta_arguments_match_in(Self, As, Origins, Args).
get_function_type_in(Module, [F|Args], T) :- \+ metta_self_module(Module),
                                             nonvar(F),
                                             (   type_declaration_in(Module, F,
                                                                       Chain0)
                                             *-> true
                                             ;   seam:builtin_type_declaration(F,
                                                                                Chain0)
                                             ),
                                             metta_runtime_type(Chain0, Chain),
                                             length(Args, Arity),
                                             fitting_type_chains([Chain], Arity,
                                                                 [[->|Ts]]),
                                             append(As,[T],Ts),
                                             metta_argument_type_origins(As,
                                                                         Origins),
                                             metta_arguments_match_in(Module, As,
                                                                      Origins, Args).

application_arrow_declared([F|_]) :-
    nonvar(F),
    (   normalized_self_type_declaration(F, Raw),
        metta_runtime_type(Raw, [->, _|_])
    ->  true
    ;   seam:builtin_type_declaration(F, [->, _|_])
    ).

application_arrow_declared_in(Module, [F|_]) :-
    nonvar(F),
    (   type_declaration_in(Module, F, Raw),
        metta_runtime_type(Raw, [->, _|_])
    ->  true
    ;   seam:builtin_type_declaration(F, [->, _|_])
    ).

%A `get-type` equation compiles into the module of the space that wrote it, so
%&self's rule predicate lives in &self's module and this declaration goes
%there: without it get_type_rule_in/3's last clause raises existence_error on
%the first (get-type ...) of a program that never defined a rule.
:- metta_self_module(Self), dynamic(Self:get_type_rule/2).
%get-type is the user-facing set boundary. Candidate derivations may overlap,
%for example an expression can be typed both element-wise and by an explicit
%declaration. Collecting candidates and retaining each first occurrence removes
%those duplicate answers without changing the declared type order.
%Internal checks call has_type/2 instead: a fixed expected type stops at its
%first witness, while an unbound shared type variable still enumerates the
%distinct choices needed to make later arguments consistent.
%A BOUND second argument is the witness question, "is X known to be a T", and
%the cast door (extensions/python/metta/_binding/shim.pl, metta_py_cast/4) is its
%caller. A refined T is witnessed by a reported type the witness relation
%admits as the whole type, or by one it admits as the BASE while every
%constraint holds on X; the constraint is a question about the value and the
%witness relation only ever saw types (engine/metta/refinements.pl).
'get-type'(X, T) :-
    current_metta_module(Module),
    reported_type_answers(Module, X, Types),
    (   var(T)
    ->  member(T, Types)
    ;   member(Actual, Types),
        typing_rule_accepts(Module, witness, '$metta_resolved_type'(Actual), T)
    ;   metta_refined_type(T, Base, Constraints),
        member(Actual, Types),
        typing_rule_accepts(Module, witness, '$metta_resolved_type'(Actual),
                            Base),
        metta_refinements_hold(Constraints, X)
    ).

%The rule here is that the reporting observers see the empty expression's unit
%type while the classifier derives no type and therefore uses its gradual
%%Undefined% fallback. Keeping this as a wrapper around the ordinary candidate
%set preserves that split: argument checks continue to call type_answers/3,
%and only get-type reads the observer correction
%[assumed: the split was adopted from an earlier reference semantics, not
%re-measured against upstream PeTTa;
%commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%That area's agreement moved from 45/76 to 46/76 with it
%[assumed 2026-08-21: measured against an earlier reference corpus at that
%date, through a runner this repository no longer ships;
%commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%Identity, not unification: an unbound subject is not the empty expression.
%The head-pattern version bound every `(get-type $x)` query to unit and broke
%the observer's relational surface while the ground P3.10 case stayed green.
reported_type_answers(_, X, [['->']]) :- X == [], !.
reported_type_answers(Module, [F], [Result]) :-
    reported_rest_arrow(Module, F, Result),
    !.
reported_type_answers(Module, X, Types) :- type_answers(Module, X, Types).

%A zero-argument use of a rest-only arrow consumes zero repetitions and
%reports the arrow's result. This remains observer-only: typed dispatch does
%not learn a new application rule through it.
reported_rest_arrow(Module, F, Result) :-
    nonvar(F),
    (   metta_self_module(Module)
    ->  (   normalized_self_type_declaration(F, Raw),
            metta_runtime_type(Raw, [->, [':seg', _], Result])
        *-> true
        ;   seam:builtin_type_declaration(F, [->, [':seg', _], Result])
        )
    ;   (   type_declaration_in(Module, F, Raw),
            metta_runtime_type(Raw, [->, [':seg', _], Result])
        *-> true
        ;   seam:builtin_type_declaration(F, [->, [':seg', _], Result])
        )
    ).

has_type(X, T) :- current_metta_module(Module),
                  has_type_in(Module, X, T).

has_resolved_type(X, T) :- current_metta_module(Module),
                           has_resolved_type_in(Module, X, T).

%The first-witness shortcut is only sound for a GROUND expected type. A
%parametric one such as (Pair $t) is nonvar but still carries a variable the
%later arguments must agree on, and once/1 commits to whichever witness came
%first: with (: p1 (Pair A)), (: p1 (Pair B)) and (: p2 (Pair B)) declared,
%(samepair p1 p2) answered nothing while (samepair p2 p1) answered True, from
%one symmetric definition [tested: a_parametric_expected_type_enumerates_its_witnesses].
%The widened list is consulted only AFTER the direct one has failed, which is
%where every subtype answer lives anyway: a value whose declared type already
%matches never pays for the graph, and a program with no (:< ...) edge pays one
%failing indexed query on the branch that was going to fail regardless. This is
%the check an argument goes through, so `(: Rex Dog)` with `(:< Dog Animal)`
%now satisfies a parameter of type Animal
%[tested: an_argument_is_accepted_through_its_supertype].
%%Undefined% is the GRADUAL type and it is compatible with everything, in
%both directions. A parameter declared %Undefined% accepts any argument, and
%an argument whose type is %Undefined% satisfies any parameter: nothing is
%known about it, so no violation is provable and gradual typing lets it
%through. This engine had both directions backwards. `%Undefined%` as the
%expected type demanded that the value be UNTYPED, so
%(: tensor (-> %Undefined% DLTensor)) refused 1.0 and typed its own
%application element-wise; and a value with no declaration failed a concrete
%parameter, so (== 1 a) had no answer through a shared type variable.
%
%Measured 2026-08-19 on hyperon 0.2.10 and on an earlier reference
%interpreter, byte-identical across both: with (: f2 (-> Number Number)) and
%(: g2 (-> %Undefined% Number)), (f2 a), (f2 (undeclared-call)), (g2 "s") and
%(g2 1) all answer, while (f2 "s") is a BadArgType. String is KNOWN and it is
%not Number; `a` is not known to be anything.
%
%The second direction is checked last, on the branch that was going to fail
%anyway, so a value whose declared type already matches never pays for it.
%EXPERIMENT (worktree only): type derivation measured Theta(2^d) in the nesting
%depth of the term, exactly 2.0 per level, and the whole of it was ONE
%enumeration too many.
%
%type_witness_in/3 asked two questions of the same term in sequence: whether a
%candidate WIDENS to T, and then, separately, whether T is itself a candidate.
%Each ran its own type_candidate_in/3, and each of those re-entered the same
%ground subterm through get_function_type_in/3 and metta_arguments_match_in/4.
%An exact match fails the first question by design, because widening is a
%subtype relation and reflexivity is the second question's job, so the common
%case paid for both walks and the recursion doubled at every level. A term
%nested d deep holds d distinct subproblems and the walk visited 2^d of them.
%
%Both questions are now asked of each candidate as it is produced, in one
%enumeration, so a level descends once and the cost is linear in the depth
%[measured 2026-08-22: ratios 4.25, 3.99 and 3.93 across depths 20, 100, 400 and
%1600, against depth increases of 5x, 4x and 4x, so an exponent of 1.0; depth 20
%went from 111,815,868,814 instructions to 1,759,888 and depth 1600 costs
%117,878,706; command=perf stat -e instructions:u sh run.sh, differenced against
%the same file whose last form does no work].
%
%A memo table was tried first and is NOT here for a reason worth recording. It
%does remove the exponential, and it cannot do better than Theta(d^2), because
%every probe has to read O(d) of a term nested d deep just to decide it is not
%the one it is looking for, and there are O(d) probes. Measured on this engine:
%term_hash/2 rises from 97ms to 10,846ms per 100k calls between depth 100 and
%6400, ==/2 on distinct terms from 65ms to 4,248ms, and assertz/1 copies its
%argument at 70ms to 3,752ms. No index escapes that, discrimination and
%substitution trees included, since they all key on the term's own shape. Only
%same_term/2 is constant, at 4.0ms hit and 12.8ms miss flat across those depths,
%and a cache it can search has to be non-backtrackable to survive the retry that
%creates the duplicate in the first place, which puts the O(d) copy back.
%Not asking twice is cheaper than any way of remembering the answer.
:- dynamic has_type_in/3.

has_type_in(_, X, T) :- metta_grounded_numeric_type(X, T), !.
has_type_in(Module, X, T) :- has_type_derive(Module, X, T).

has_resolved_type_in(_, X, T) :- metta_grounded_numeric_type(X, T), !.
%A refined type is satisfied the way it always was, by a declared type that
%unifies with it, and also by a value whose type satisfies the BASE while every
%constraint holds on the value (engine/metta/refinements.pl). The base takes
%this same relation, so a host numeric against `(Annotated Number (Gt 0))`
%keeps the grounded fast path above. A disjunction and not an if-then-else:
%the declared path may bind a shared type variable several ways and the
%argument group's commit is the only place that choice is closed.
%The guard is INLINED, as the union guards are: `T = [Head|_]` against an atom
%fails without a call, so a plain type reaches has_type_derive/3 retiring the
%same inferences it did before this arm existed.
has_resolved_type_in(Module, X, T) :-
    (   nonvar(T), T = [Head|_], Head == 'Annotated',
        metta_refined_type(T, Base, Constraints)
    ->  (   type_answers(Module, X, Types),
            member(Actual, Types),
            metta_refined_declared_match_in(Module, Actual, T)
        ;   has_resolved_type_in(Module, X, Base),
            metta_refinements_hold(Constraints, X)
        )
    ;   nonvar(T), T = [UnionHead|_], UnionHead == '|',
        metta_refined_union_type(T)
    ->  metta_refined_union_admits(Module, X, T)
    ;   has_type_derive(Module, X, T)
    ).

%A reported type that matches the WHOLE refined type by evidence. The two
%gradual wildcards are excluded on purpose: `%Undefined%` and `Atom` satisfy
%every expected type in the shipped relation, and letting them satisfy a
%refined one would discharge a constraint about the value without ever reading
%the value. A wildcard-typed value instead takes the base-plus-constraints road
%below, where `(a)` is refused by `(MinLen 2)` on its length rather than
%admitted for having no type.
metta_refined_declared_match_in(Module, Actual, Refined) :-
    nonvar(Actual),
    Actual \== '%Undefined%',
    Actual \== 'Atom',
    metta_resolved_types_match_in(Module, Actual, Refined).


has_type_derive(Module, X, T) :-
    ( ground(T)
      %ONE walk of the term decides this, whichever way it goes. The witness is
      %called before the branch, not inside its condition, because a condition's
      %bindings do not reach the else and the candidate list is exactly what the
      %else needs: asking again there would restore the second descent this is
      %removing. The answers used to be derived twice more besides, as
      %type_witness_in/3's last attempt and again below.
      -> (   type_witness_direct(Module, X, T, Outcome),
             (   Outcome == found
             ->  true
             ;   Outcome = exhausted(Candidates),
                 type_answers_from(Module, X, Candidates, Types),
                 (   once(( member(Widened, Types),
                            type_witness_candidate_matches(
                                Module, Widened, T) ))
                 ->  true
                 ;   member(Actual, Types),
                     metta_resolved_types_match_in(Module, Actual, T)
                 )
             )
         )
      %A GROUND union needs nothing here: the branch above compares the value's
      %own type against it through type_witness_candidate_matches/3, which is
      %what lets a value whose declared type is ITSELF a union be admitted by a
      %wider one. The two relational branches below instead compare by
      %unification, and a union does not unify with the alternative that
      %satisfies it, so a union carrying a type variable is taken apart per
      %alternative. Each alternative then runs the whole relation again, so the
      %variable is bound by the alternative that fits and the choice point the
      %next argument may need is still there. The guard sits after ground/1 and
      %is inlined, so nothing outside this case pays for it.
       ; nonvar(T), T = [UnionHead|_], UnionHead == '|'
         -> metta_union_admits(has_type_derive(Module), X, T)
       ; any_super_type_edge(Module)
         -> type_answers(Module, X, Types),
            member(Raw, Types),
            metta_runtime_type(Raw, Actual),
            metta_runtime_type(T, Actual)
        ; % No (:< ...) edge anywhere: the full set's order IS candidate
          % order, so the answers can stream, deduplicated by variance
          % exactly as unique_type_answers decides, first occurrence kept,
          % and a checking caller's soft cut stops at its first witness
          % instead of paying findall plus dedup for the whole set. On
          % nilbc's 797k nonground-type judgements the materialized set
          % was the remaining hot block [measured 2026-08-17, profile/2].
          % The seen-list is a per-call compound mutated with nb_setarg,
          % which library(solution_sequences) distinct/2 also does
          % underneath but with a per-call hash table whose setup cost
          % 1.6x the whole findall it replaced at one or two candidates
          % per call [measured 2026-08-17: 17.6e9 to 28.4e9 and back].
          (   lazy_unique_candidate(Module, X, C)
          *-> metta_runtime_type(C, Actual),
              metta_runtime_type(T, Actual)
          ;   T = '%Undefined%'
          ) ).

%A WITNESS that X has type T, which is the other question a caller can ask and
%is not the same one. has_type_in/3 asks whether X's type is CONSISTENT with T
%and lets an unknown through, because a call site may not refuse what it cannot
%prove wrong. A gate asks whether X is KNOWN to be a T, and an unknown must not
%pass one: `(admits &pool Space)` is a contract, and an atom nothing declares
%is not evidence of a Space. The directed BigInt-to-Number case is explicit
%here too, so reflective and compiled call checks use the same operational rule
%[tested:
%extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_admission_types_the_pool].
:- dynamic type_witness_in/3.
type_witness_in(Module, X, T) :-
    type_witness_direct(Module, X, T, Outcome),
    (   Outcome == found
    ->  true
    ;   Outcome = exhausted(Candidates),
        type_answers_from(Module, X, Candidates, Types),
        once(( member(Widened, Types),
               type_witness_candidate_matches(Module, Widened, T) ))
    ).

%The two attempts that reach a decision WITHOUT materialising the full answer
%set. has_declared_type/2 needs the whole witness including that set, so
%type_witness_in/3 keeps its contract; has_type_derive/3 derives the set itself
%and has no reason to ask for it twice.
%Reports `found`, or `exhausted(Candidates)` carrying every candidate the walk
%produced. A failing check needs that list, and enumerating it is the only part
%of the answer that re-enters the subterms, so remembering it as it goes is what
%keeps a FAILING check off a second descent. The accumulator is the mutable
%compound lazy_unique_candidate/3 above already uses for the same reason, with
%duplicate_term/2 for the same reason again: nb_setarg/3 is not undone by the
%backtracking that drives the enumeration, so what it stores must not share
%structure with the bindings that are.
type_witness_direct(Module, X, T, Outcome) :-
    tuple_positions_witness(Module, X, T),
    !,
    Outcome = found.
type_witness_direct(Module, X, T, Outcome) :-
    State = collected([]),
    (   (   type_candidate_in(Module, X, Actual),
            (   type_witness_candidate_matches(Module, Actual, T)
            ->  true
            %Only a REJECTED candidate is worth remembering. An accepted one ends
            %the walk and the list is never read, so the ordinary case pays for no
            %copy at all; the fail drives the enumeration on to the next one.
            ;   duplicate_term(Actual, Kept),
                arg(1, State, Acc),
                nb_setarg(1, State, [Kept|Acc]),
                fail
            )
        ->  Outcome = found
        ;   satisfies_metatype_in(Module, X, T)
        ->  Outcome = found
        ;   arg(1, State, Reversed),
            reverse(Reversed, Candidates),
            Outcome = exhausted(Candidates)
        )
    ).

%A witness is narrower than gradual consistency: Atom and %Undefined% do not
%prove a concrete type. Exact identity and an accepted widening prove the
%structural relation on the default hot path. A generated contract whose
%static proof was invalidated calls has_type_under_policy/3 instead, so
%unrelated type reporting does not pay a registry probe.
%A union reaches this relation as the ACTUAL type, from a value whose own
%declaration names one, and identity is the half it fails: `(| Number String)`
%satisfies a Number requirement only if BOTH alternatives do. The lift is a
%third disjunct over the whole relation rather than a wrapper on the widening
%call, because exact identity is the half a union alternative is usually
%admitted by. Every caller of this relation commits with once/1 or `->`.
type_witness_candidate_matches(Module, RawActual, RawExpected) :-
    metta_runtime_type(RawActual, Actual),
    metta_runtime_type(RawExpected, Expected),
    (   typing_rule_accepts_resolved(Module, widening, Actual, Expected)
    ;   Actual = Expected
    ;   metta_union_witness(type_witness_candidate_matches(Module),
                            Actual, Expected)
    ).

%The refined alternative under a user policy, the same split
%has_resolved_type_in/3 makes on the shipped one: the declared path first,
%then the base under this same policy-strict relation with every constraint
%holding on the value (engine/metta/refinements.pl).
has_type_under_policy(Module, X, T) :-
    (   nonvar(T), T = [Head|_], Head == 'Annotated',
        metta_refined_type(T, Base, Constraints)
    ->  (   type_answers(Module, X, Types),
            member(Actual, Types),
            metta_refined_declared_match_in(Module, Actual, T)
        ;   has_type_under_policy(Module, X, Base),
            metta_refinements_hold(Constraints, X)
        )
    ;   nonvar(T), T = [UnionHead|_], UnionHead == '|',
        metta_refined_union_type(T)
    ->  metta_refined_union_admits(Module, X, T)
    ;   has_type_under_policy_declared(Module, X, T)
    ).

%The policy-strict ground check mirrors has_type_derive/3's candidate order
%but deliberately omits its tuple and exact shortcuts. This path is reached
%only while a user ordinary or widening policy is installed, where every
%candidate must be accepted by that policy before it can discharge a
%generated contract.
has_type_under_policy_declared(Module, X, T) :-
    ground(T),
    State = collected([]),
    (   (   type_candidate_in(Module, X, Actual),
            (   type_witness_candidate_matches_under_policy(
                    Module, Actual, T)
            ->  true
            ;   duplicate_term(Actual, Kept),
                arg(1, State, Acc),
                nb_setarg(1, State, [Kept|Acc]),
                fail
            )
        ->  true
        ;   satisfies_metatype_in(Module, X, T)
        ->  true
        ;   arg(1, State, Reversed),
            reverse(Reversed, Candidates),
            type_answers_from(Module, X, Candidates, Types),
            (   once(( member(Widened, Types),
                       type_witness_candidate_matches_under_policy(
                           Module, Widened, T) ))
            ->  true
            ;   member(Other, Types),
                metta_resolved_types_match_in(Module, Other, T)
            )
        )
    ).

% A parameterized requirement must bind from the value before the policy can
% adjudicate its instantiated type. Reuse the ordinary relational derivation,
% retaining its alternatives for later shared parameters, then require the
% ordinary policy's approval of the resulting equal types. Union requirements
% choose an alternative through the same relation as has_type_derive/3.
% [tested: tensor_shapes:a_policy_checked_shape_variable_binds_at_the_live_call,
% tensor_shapes:a_policy_refusal_still_blocks_a_relational_shape_witness;
% commit=4eaefdd8d40e53b2613722287302a14b41704662].
has_type_under_policy_declared(Module, X, T) :-
    \+ ground(T),
    (   nonvar(T), T = [UnionHead|_], UnionHead == '|'
    ->  metta_union_admits(has_type_under_policy(Module), X, T)
    ;   has_type_derive(Module, X, Actual),
        metta_runtime_type(T, Actual),
        typing_rule_accepts_resolved(Module, ordinary, Actual, Actual)
    ).

type_witness_candidate_matches_under_policy(Module, RawActual, RawExpected) :-
    metta_runtime_type(RawActual, Actual),
    metta_runtime_type(RawExpected, Expected),
    (   typing_rule_accepts_resolved(Module, widening, Actual, Expected)
    ;   Actual = Expected
    ;   metta_union_witness(
            type_witness_candidate_matches_under_policy(Module),
            Actual, Expected)
    ),
    typing_rule_accepts_resolved(Module, ordinary, Actual, Expected).

%CHECKING a tuple against a KNOWN tuple type, decided per position instead of
%by finding it in the product.
%
%The clause below asks the question by SYNTHESIS: it enumerates X's candidate
%types and compares each to T. For an expression typed element-wise the
%candidates are the cartesian product of its members' type sets, so the cost of
%deciding `X : T` depends on where T sits in that enumeration. Measured on k
%members carrying three declared types each, checking the FIRST combination
%against checking the LAST: 102 and 859 inferences at three members, 312 and
%29,496,420 at thirteen, the first flat at 21 per member and the second growing
%3.0x per member. Same expression, same question, 94,540x apart
%[measured 2026-08-22].
%
%That is the rule Pfenning's notes call chk/syn, checking by synthesising and
%comparing, and the standard objection to it is that it is not MODE CORRECT: it
%recomputes something the caller already knows. Dunfield and Krishnaswami's
%recipe is that introduction forms CHECK and elimination forms SYNTHESISE, and
%an element-wise expression is an introduction form
%[source: Bidirectional Typing, ACM Computing Surveys 54(5), doi:10.1145/3450952].
%
%This is SOUND but deliberately INCOMPLETE, and it must be: a declared edge may
%widen a whole tuple type to something that is not a tuple at all, as
%`(:< (P1 Q1) S1)` does in metta_subtyping:an_expression_widens_in_two_phases,
%so per-position agreement is not the only way a tuple can have a type. In
%focusing terms the structural rule is invertible and this one is not, so
%failing here falls through to the enumeration below, which still decides every
%case it decided before. Succeeding here is a witness by construction: each
%position holds one of that member's own candidate types and none is
%%Undefined%, so the list IS one of the combinations the product would have
%enumerated, and tuple_fold/2 leaves it unchanged.
%The guard's order is measured, in inferences per check against the same build
%with this clause removed, over the shapes a hot ground check actually meets:
%an arrow application against an atom type +3, against a same-length list type
%+18, an atom against an atom +1, a tuple against an atom +1, and a tuple
%against its own tuple type -4, which is the case this exists for. The two
%unifications lead because they are inlined and decide the atom case at once,
%where is_list/1 is a call costing two inferences on its own
%[source: EXTENDING.md, "Dispatching on a value's type": is_list/1, is_dict/1
%and blob/2 cost two inferences each where var/1, atom/1 and the rest are
%inlined. Cited by section rather than by line: the line range this named
%pointed at the platform census, two sections earlier, and drifted again when
%that census grew]. The arrow probe comes before the two list
%walks because an application is the shape that reaches here and is not a
%tuple: after it, arrow-against-list costs 18 rather than 24. Running
%tuple_positions_hold/3 before it instead costs 66, so the probe is cheaper
%than the per-position derivation it would skip
%[measured 2026-08-23].
%A union is a list too, so `(| (Number Bool) (String Bool))` would be read here
%as a three-position tuple whose first position wants the type `|`. The head
%test separates the two readings before any of the work below, and an unbound
%head is not the union head, so a parametric tuple type still reaches the
%positional walk.
%
%A union of tuples takes each alternative through this same positional walk,
%which is what keeps the fast path's whole point. Falling through to the
%candidate enumeration instead would decide `(| (A B) (C D))` by finding the
%alternative in the product of the members' type sets, the Theta(c^k) synthesis
%the walk below exists to avoid, and having it only for the union spelling
%would be that exponential displaced rather than removed.
tuple_positions_witness(Module, X, T) :-
    T = [Tag|_],
    X = [_|_],
    (   Tag == '|'
    ->  metta_union_admits(tuple_positions_witness(Module), X, T)
    ;   \+ application_arrow_declared_in(Module, X),
        is_list(T),
        is_list(X),
        same_length(X, T),
        tuple_positions_hold(Module, X, T)
    ).

tuple_positions_hold(_, [], []).
tuple_positions_hold(Module, [Member|Members], [Type|Types]) :-
    Type \== '%Undefined%',
    member_holds_type(Module, Member, Type),
    tuple_positions_hold(Module, Members, Types).

%A member that is ITSELF an expression decomposes the same way, and it has to:
%enumerating a nested member's types to find the one wanted is the product
%again, one level down, so without this the exponential is displaced rather
%than removed. Measured on a two-member expression whose first member is an
%expression of k members carrying three types each, checked against the LAST
%combination: 614 inferences at k=2 rising 9x per added inner member to
%43,097,295 at k=8, where deciding it per position is linear
%[measured 2026-08-23].
%The fallback enumerates that member's own types and stops at the first match,
%which is Theta(c) for that member rather than Theta(c^k) for the expression.
%A union AT A POSITION descends here too, and it has to: the fallback below
%decides by exact identity, so `((| Number String) Bool)` would fail its first
%position against every candidate `1` has and push the whole check back into
%the product enumeration this clause exists to avoid.
member_holds_type(Module, Member, Type) :-
    (   nonvar(Type), Type = [UnionHead|_], UnionHead == '|'
    ->  metta_union_admits(member_holds_type(Module), Member, Type)
    ;   tuple_positions_witness(Module, Member, Type)
    ->  true
    ;   once(( has_resolved_type_in(Module, Member, Candidate), Candidate == Type ))
    ).

%A ground declaration is the admission common case, so probe its indexed
%storage shape first. Every miss and every relational call takes the exact
%type_witness_in/3 path, retaining builtins, metatypes, supertypes, type rules,
%foreign spaces and the named-space shared tier.
has_declared_type(X, T) :-
    current_metta_module(Module),
    (   ground(X), ground(T), direct_type_declaration_in(Module, X, T)
    ->  true
    ;   type_witness_in(Module, X, T)
    ).

direct_type_declaration_in(Module, X, T) :-
    metta_self_module(Module), !,
    normalized_self_type_declaration(X, T).
direct_type_declaration_in(Module, X, T) :-
    metta_module_space(Module, Space),
    (   native_storage_module_ready(Space, Storage),
        native_storage_functor(Space, Functor),
        Head =.. [Functor, ':', X, Raw, _],
        call(Storage:Head),
        normalize_type_in(Module, Raw, T)
    ;   normalized_self_type_declaration(X, T)
    ).

%The first clause is the whole common case and pays no bookkeeping at
%all: a deterministic check derives one candidate and commits. Only a
%caller that actually RETRIES reaches the second clause, which re-seeds
%the seen-list with the first candidate and streams the rest, so a
%variant repeat of the first is excluded exactly as it was when the
%whole set was materialized.
lazy_unique_candidate(Module, X, Candidate) :-
    once(type_candidate_in(Module, X, Candidate)).
lazy_unique_candidate(Module, X, Candidate) :-
    once(type_candidate_in(Module, X, First)),
    duplicate_term(First, Seed),
    State = seen([Seed]),
    type_candidate_in(Module, X, Candidate),
    arg(1, State, Seen),
    \+ ( member(Previous, Seen), Previous =@= Candidate ),
    duplicate_term(Candidate, Kept),
    nb_setarg(1, State, [Kept|Seen]).

type_answers(Module, X, Types) :-
    findall(Type, type_candidate_in(Module, X, Type), Candidates),
    type_answers_from(Module, X, Candidates, Types).

%Everything type_answers/3 does AFTER the candidates are in hand. Only the
%findall/3 above descends into the term's subterms; deduplication, widening and
%the empty-set ruling all read the list. So a caller that has already enumerated
%the candidates can finish the answer without walking the term a second time.
type_answers_from(Module, X, Candidates, Types) :-
    unique_type_answers(Candidates, Unique),
    widen_to_super_types(Module, X, Unique, Widened),
    (   Widened \== []
    ->  Types = Widened
    ;   inapplicable_typed_application(Module, X, Candidates)
    ->  Types = []
    ;   Types = ['%Undefined%']
    ).

%The candidate list already answers the second half. Reaching here means the
%widened set is empty, and widening only ever adds, so the unique set is empty
%and therefore so is Candidates; get_function_type/2 is one of the sources those
%candidates come from (get_type_candidate/2's first clause IS it), so an empty
%list means it produced nothing. Asking again re-ran the whole application
%typing and re-entered the argument, which is a second full descent on exactly
%the path that takes it: a check that FAILS. The \+ is kept as the fallback for
%a non-empty list so the predicate still states its own condition rather than
%relying on a caller's invariant.
inapplicable_typed_application(Module, X, Candidates) :-
    (   metta_self_module(Module)
    ->  application_arrow_declared(X),
        (   Candidates == []
        ->  true
        ;   \+ get_function_type(X, _)
        )
    ;   application_arrow_declared_in(Module, X),
        (   Candidates == []
        ->  true
        ;   \+ get_function_type_in(Module, X, _)
        )
    ).

%%%% Subtyping: (:< Sub Super) %%%%
%
%`:<` is upstream's spelling, SUB_TYPE_SYMBOL at lib/src/metta/mod.rs:22, and
%the arrow points from the subtype to the supertype, which is why it is not
%`:>`. Read `(:< Dog Animal)` as "Dog is below Animal".
%
%The mechanism is not what the name suggests, and getting that wrong is the
%whole of why this took a rewrite rather than a rule. Upstream never DECIDES a
%subtyping relation while checking an argument: it WIDENS the argument's type
%LIST, and the ordinary type check then runs unchanged against the wider list.
%So the matcher learns nothing about subtyping, and `get-type` is the surface
%where it shows [source: hyperon-experimental@3f76dc4 lib/src/metta/types.rs,
%get_atom_types_internal].
%
%Grounded intrinsic types and callable application results keep their direct
%types. A head with no implementation constructs sorted data instead; its
%result sort participates in the same subsort closure as a declared symbol.
%Two phases, because the ORDER is observable through collapse and upstream's
%is not the order one pass produces: tuple products first, then the direct
%declarations already widened, then one more widening over the whole list. With
%(: (a b) D), (:< (A B) C) and (:< D E) that answers ((A B) D E C), where a
%single pass over the whole list answers ((A B) D C E)
%[source: hyperon-experimental@3f76dc4 lib/src/metta/types.rs, get_tuple_types].
widen_to_super_types(Module, X, Types0, Types) :-
    %THE CHEAP TEST LEADS. Both are pure tests that bind nothing, so the order is
    %free, and it was the wrong way round: widening_applies_to/2 asks
    %application_return_type/2, which is get_function_type/2, which types the
    %application again and so re-enters its arguments. any_super_type_edge/1 is
    %one indexed probe of an empty ':<' bucket and its own note says that with no
    %edge declared anywhere, which is every program not using the feature, it is
    %the whole cost. Asking it first means such a program never pays the descent:
    %on a check that FAILS this was the last of the two walks per level, and
    %removing it makes the failing path linear rather than 2^d.
    (   any_super_type_edge(Module),
        widening_applies_to(Module, X)
    ->  findall(Declared, type_declaration_in(Module, X, Declared), Directs),
        partition(type_already_listed(Directs), Types0, Direct, Products),
        type_edge_view(visible(Module), Edges),
        add_super_types(Module, Edges, Direct, DirectWidened),
        append(Products, DirectWidened, Combined),
        add_super_types(Module, Edges, Combined, Types)
    ;   Types = Types0
    ).

%The dispatch mirrors type_candidate_in/3's, which sends the `user` module to
%the /2 predicates and every named space to the /3 ones. Asking the /3 one
%about `user` simply fails, so an application's return type was widened when it
%must not be: (: f (-> A B)) with (:< B C) answered (B C) for (get-type (f a))
%where upstream answers (B) [tested: an_application_return_type_is_not_widened].
widening_applies_to(Module, X) :-
    \+ number(X),
    \+ string(X),
    X \== true,
    X \== false,
    (   nonvar(X), X = [Head|_], atom(Head),
        \+ metta_host_function_callable_from(Module, Head)
    ->  true
    ;   \+ application_return_type(Module, X)
    ).

application_return_type(Module, X) :- metta_self_module(Module), !, get_function_type(X, _).
application_return_type(Module, X) :- get_function_type_in(Module, X, _).

%One indexed query rather than one per type: with no edge declared anywhere,
%which is every program that does not use the feature, this is the whole cost.
%The native probe peeks the storage clause directly instead of walking the
%match/4 chain: first-argument indexing answers an empty ':<' bucket in a
%few instructions, where the chain cost ~25 inferences 797k times on
%nilbc's type resolutions [measured 2026-08-17, profile/2]. A space
%served by a foreign provider keeps the full chain, because its edges do
%not live in a storage module.
any_super_type_edge(Module) :-
    (   metta_self_module(Module)
    ->  native_edge_probe('&self')
    ;   metta_module_space(Module, Space),
        seam:foreign_space(Space)
    ->  \+ \+ type_edge_from_view(visible(Module), _, _)
    ;   metta_module_space(Module, Space2),
        native_edge_probe(Space2)
    ->  true
    ;   %A native name with no storage module yet holds no clauses, so
        %only &self can carry an edge for it; probing the full match
        %chain here instead cost a fresh python space +400k inferences on
        %alpha-unique's counter before its first native write [measured
        %2026-08-17]. A provider that plugs in through raw multifile
        %match/4 clauses without seam:foreign_space/1 is outside this
        %probe, and outside the seam's documented contract (EXTENDING.md:
        %"Do not add raw match/4 clauses instead"); declaring the seam is
        %what buys module-local edge service.
        native_edge_probe('&self')
    ).

native_edge_probe(Space) :-
    native_storage_module_cache(Space, StorageModule),
    (   Space == '&self'
    ->  \+ \+ clause(StorageModule:'&self'(':<', _, _, _), _)
    ;   native_storage_functor(Space, Functor),
        Head =.. [Functor, ':<', _, _, _],
        \+ \+ clause(StorageModule:Head, _)
    ).

%add_super_types, round by round: each round asks for the supertypes of exactly
%what the PREVIOUS round appended, and appends every one that was not present
%in the list AS IT STOOD WHEN THE ROUND BEGAN.
%
%That last clause is why the diamond A<:B, A<:C, B<:D, C<:D answers
%(A B C D D) and not (A B C D). Both B and C reach D in the same round, and
%presence is checked against the list from before the round, so D is appended
%twice. It is a parity artifact and it is reproduced deliberately: answering
%more tidily than the arbiter is still answering differently
%[tested: the_diamond_reproduces_upstreams_duplicate].
%
%The three clauses below are upstream's own, read from the source rather than
%inferred from its behaviour [source 2026-08-16,
%hyperon-experimental lib/src/metta/types.rs:49-63]:
%
%    sub_types.iter().skip(from)          the frontier is only the last round
%    if !sub_types.contains(&typ)         checked BEFORE this round appends
%    add_super_types(space, sub_types, sub_types.len())   recurse over the new
%
%and the spelling is `:<` at lib/src/metta/mod.rs:22, `SUB_TYPE_SYMBOL`. There
%is no `:>` in that source: the arrow points from the subtype UP to the
%supertype, so `(:< Dog Animal)` is "Dog is below Animal".
%EXPERIMENT (worktree only): the presence test was member/2 over the whole
%accumulated list, run once per candidate, and the accumulator grew by an
%append/3 of that same list once per round. A chain of n subtype edges therefore
%cost Theta(n^2): widening along a 1600-edge chain took 4,935,292,461
%instructions, with the round-over-round ratio converging on 4.0 across
%n = 100, 200, 400, 800, 1600 [measured 2026-08-22: 3.24, 3.68, 3.90, 3.86;
%command=perf stat -e instructions:u sh run.sh, differenced against the same
%file whose last form does not widen, so parsing the chain cancels].
%
%The set is an AVL now, which library(assoc) already provides and which
%count_assoc/2 above uses for the same reason, and each round contributes its
%own segment instead of copying the accumulator, so the result is still
%Types followed by every round's fresh entries in order.
%
%get_assoc/3 decides by compare/3, which agrees with ==/2 on identity, so this
%is the same relation type_already_listed/2 tests and not unification. The keys
%can carry variables, from a polymorphic supertype, and stay sound because
%findall/3 hands back fresh copies whose variables nothing here binds: the
%bindings type_edge_from_view/3 makes are undone when the findall completes, before
%any lookup runs.
%
%The AVL is extended only AFTER the round's exclude, which is what preserves the
%parity artifact described above: B and C both reach D in one round, neither
%sees the other's D, and the diamond still answers (A B C D D)
%[tested: the_diamond_reproduces_upstreams_duplicate].
add_super_types(Module, Types, Widened) :-
    type_edge_view(visible(Module), Edges),
    add_super_types(Module, Edges, Types, Widened).

add_super_types(Module, Edges, Types, Widened) :-
    seen_types(Types, Seen),
    super_type_rounds(Module, Edges, Types, Seen, Fresh),
    append(Types, Fresh, Widened).

super_type_rounds(_, _, [], _, []) :- !.
super_type_rounds(Module, Edges, Frontier, Seen, Widened) :-
    findall(Super,
            ( member(Type, Frontier),
              type_edge_from_view(Edges, Type, Super),
              typing_rule_accepts_resolved(Module, 'declared-widening', Type, Super) ),
            Supers),
    exclude(type_seen(Seen), Supers, Fresh),
    (   Fresh == []
    ->  Widened = []
    ;   add_seen_types(Fresh, Seen, Grown),
        super_type_rounds(Module, Edges, Fresh, Grown, Rest),
        append(Fresh, Rest, Widened)
    ).

seen_types(Types, Seen) :- empty_assoc(Empty), add_seen_types(Types, Empty, Seen).

add_seen_types([], Seen, Seen).
add_seen_types([Type|Types], Seen0, Seen) :-
    put_assoc(Type, Seen0, [], Seen1),
    add_seen_types(Types, Seen1, Seen).

type_seen(Seen, Type) :- get_assoc(Type, Seen, _).

type_already_listed(Listed, Type) :- member(Present, Listed), Present == Type.

%Alpha-equivalent polymorphic types are one answer, first occurrence
%kept, which preserves derivation order (observable through collapse).
%The equivalence is =@=, variance, the same relation canonical
%numbervars keys decide: (List $x) repeats (List $y) and (F $x $x) does
%not repeat (F $x $y). The earlier implementation built a numbervars
%copy of every candidate and keysorted twice; candidate lists are almost
%always one or two entries, and on nilbc's 797k resolutions the copies
%and sorts were ~40% of the whole type-resolution profile [measured
%2026-08-17, profile/2], so the quadratic identity walk with the
%C-implemented =@= is the faster shape at every realistic length.
%EXPERIMENT (worktree only): the walk below is Theta(n^2) in the candidate
%count, and the paragraph above is the reason to keep it: at one or two
%candidates it beats canonicalizing, and that is what nearly every call passes.
%It is not what every call passes. A symbol carrying n declarations answers n
%candidates, and typing it measured 2.83, 3.34 and 3.66 per doubling over
%n = 100, 200, 400, 800, converging on 4.0, with 800 declarations costing
%5,997,121,957 instructions [measured 2026-08-22: 20 get-type calls, differenced
%against the same file with no call].
%
%So the walk keeps the short lists it was measured on, and a long one goes to a
%bucketed pass built the same way alpha_bucket_insert/5 above is: a numbervars
%canonical copy chooses the bucket, and identity inside it decides. The
%threshold is far above the one or two candidates the measurement talks about,
%so no call the =@= walk was chosen for changes path.
%
%The one thing that cannot be borrowed wholesale is what decides INSIDE the
%bucket. alpha_list_to_set/2 compares the canonical copies, which is right for
%'alpha-unique-atom' and wrong here: a literal '$VAR'(0) and a variable share a
%canonical form and are NOT variants. Running both over
%['$VAR'(0), $v, '$VAR'(0), $w], the walk answers two and the canonical compare
%answers one [measured 2026-08-22, differential over eight candidate shapes;
%the other seven agree]. So =@= decides on the ORIGINAL terms and the hash only
%narrows the search, which is the line translator.pl:1012-1019 already draws for
%its own normalized cache key.
unique_type_answers(Candidates, Unique) :-
    (   at_least_n(Candidates, 17)
    ->  variant_unique_bucketed(Candidates, Unique)
    ;   variant_unique_(Candidates, [], Unique)
    ).

at_least_n([_|Rest], N) :- ( N =< 1 -> true ; N1 is N - 1, at_least_n(Rest, N1) ).

variant_unique_bucketed(Candidates, Unique) :-
    empty_assoc(Empty),
    variant_unique_bucketed_(Candidates, Empty, Unique).

variant_unique_bucketed_([], _, []).
variant_unique_bucketed_([Type|Types], Seen0, Out) :-
    variant_bucket_key(Type, Key),
    (   get_assoc(Key, Seen0, Bucket)
    ->  true
    ;   Bucket = []
    ),
    (   variant_in_bucket(Type, Bucket)
    ->  variant_unique_bucketed_(Types, Seen0, Out)
    ;   put_assoc(Key, Seen0, [Type|Bucket], Seen1),
        Out = [Type|Rest],
        variant_unique_bucketed_(Types, Seen1, Rest)
    ).

%variant_hash/2 is SWI's own primitive for this, invariant under renaming and
%documented as being for finding variants in a set, so it replaces a copy_term
%plus numbervars plus term_hash and costs no term copy. It processes an
%attributed variable as an ordinary one, where =@=/2 does not, which is the
%second reason the bucket is resolved by =@=/2 rather than by the key: the hash
%is allowed to be coarser than the relation it indexes, never finer.
variant_bucket_key(Type, Key) :- variant_hash(Type, Key).

variant_in_bucket(Type, [Present|Rest]) :-
    (   Present =@= Type
    ->  true
    ;   variant_in_bucket(Type, Rest)
    ).

variant_unique_([], _, []).
variant_unique_([Type|Types], Seen, Out) :-
    (   member(Present, Seen), Present =@= Type
    ->  variant_unique_(Types, Seen, Out)
    ;   Out = [Type|Rest],
        variant_unique_(Types, [Type|Seen], Rest)
    ).

type_candidate_in(Module, X, T) :- metta_self_module(Module),
                                   get_type_candidate(X, T).
type_candidate_in(Module, X, T) :- \+ metta_self_module(Module),
                                   get_type_candidate_in(Module, X, T).
type_candidate_in(Module, X, T) :- get_type_rule_in(Module, X, T).

%A `get-type` equation compiles to get_type_rule/2 in the module of the space
%that wrote it, &self's included: the second clause is that space's own rule
%and reads &self's module by name rather than calling it unqualified, which
%before Phase 11 was the same thing and is not any more.
%A refusal's own type lookup does not run them, because they are programs and
%one that computes on its argument re-enters the operation that asked; see
%metta_argument_types/2, which sets the flag.
%EXPERIMENT (worktree only): the flag was a thread_local clause asserted and
%erased around every rule call. nilbc measured 5,007,442 call_get_type_rule/3
%calls, so assertz/2 + erase/1 + the setup_call_cleanup sig_atomic/1 cost
%3,047 of 15,206 profiled ticks, 20%. This is the same dynamic-extent state
%with_metta_module/2 and push_dual_frame/3 already keep in a backtrackable
%global, read with nb_current/2 exactly as current_metta_module/1 reads
%'$metta_module'. The reader is a boolean test, so a saved-and-restored
%boolean carries the nesting the clause count used to carry.
metta_evaluating_type_rule :- nb_current('$metta_evaluating_type_rule', true).

get_type_rule_in(Module, X, T) :-
    \+ metta_reading_declared_types,
    metta_self_module(Self),
    (   Module == Self
    ->  call_get_type_rule(Self, X, T)
    ;   (   fun_in(Module, 'get-type'),
            call_get_type_rule(Module, X, T)
        ;   call_get_type_rule(Self, X, T)
        )
    ).

call_get_type_rule(Module, X, T) :-
    (   nb_current('$metta_evaluating_type_rule', Previous)
    ->  true
    ;   Previous = false
    ),
    b_setval('$metta_evaluating_type_rule', true),
    Module:get_type_rule(X, T),
    b_setval('$metta_evaluating_type_rule', Previous).

%The current upstream Number holds Integer(i64) and Float(f64), while its
%tokenizer names an integer outside that capacity as the future BigInt case.
%It publishes no suffix or promotion table, so signed decimal syntax stays
%one class and the value boundary is signed i64 inclusive. SWI integers stay
%unbounded underneath: this predicate classifies a value and never converts
%it. A result can therefore cross either way after arithmetic
%[source: hyperon-experimental@3f76dc4, hyperon-atom/src/gnd/number.rs and
%lib/src/metta/text.rs:866-877; assumed 2026-08-20: the exact future boundary].
metta_numeric_type(X, 'BigInt') :-
    integer(X),
    ( X < -9223372036854775808 ; X > 9223372036854775807 ),
    !.
metta_numeric_type(X, 'Number') :- number(X).

get_type_candidate(X, T) :- number(X), !, metta_numeric_type(X, T).
get_type_candidate(X, _) :- var(X), !.
get_type_candidate(X, 'String')   :- string(X), !.
get_type_candidate(true, 'Bool')  :- !.
get_type_candidate(false, 'Bool') :- !.
%A live host object types through the bridge. The atomic/non-atom pre-test
%is the engine's own cheap class check; whether the value IS a live host
%object is the bridge's question, through the ownership seam, so an engine
%with no host loaded answers no at one failed lookup and never initializes
%anything [tested: metta_object_types].
get_type_candidate(X, T) :- atomic(X), \+ atom(X),
                            seam:host_object(X),
                            metta_grounded_type(X, T).
get_type_candidate([Family|Parameters], 'SpaceType') :-
    Space = [Family|Parameters],
    metta_space_operand(Space),
    !.
get_type_candidate(X, T) :- get_function_type(X,T).
%The shape test leads the negation, which is free: X is nonvar by the time
%this clause is reached (the var clause above cuts), so `X = [_|_]` and
%is_list/1 are pure tests that bind nothing outside X's own skeleton, and
%reordering pure tests against each other cannot change which solutions this
%clause produces or the order it produces them in. It changes only what an
%ATOM pays to leave: application_arrow_declared/1's head is [F|_], so the
%negation used to call it and have the head fail on every symbol this ladder
%enumerates [measured 2026-08-28: 1 of the 11 inferences an undeclared symbol
%spent in get_type_candidate/2].
get_type_candidate(X, T) :- X = [_|_],
                            is_list(X),
                            \+ application_arrow_declared(X),
                            metta_self_module(Self),
                            tuple_first_in(X, Self, First),
                            (   tuple_fold(First, T)
                            ;   tuple_rest_types(has_resolved_type_in(Self), X, T)
                            ).
get_type_candidate(X, T) :- normalized_self_type_declaration(X, T).
get_type_candidate(X, T) :- seam:builtin_type_declaration(X, T).
%A space handle's own type, which no declaration carries because no program
%wrote the handle. `(get-type &self)` and the type of a space a program made
%are both `SpaceType` on hyperon 0.2.10, including for a `(new-space)` nothing
%has been written to [assumed: measured against an earlier reference corpus,
%not re-measured against upstream PeTTa]. Last, like the engine's own
%declarations above it, so a program that declares something about a handle is
%still answered first [tested: space_handle_type].
get_type_candidate(X, 'SpaceType') :- atom(X), metta_space_operand(X).
get_type_candidate(X, T) :- metta_state_cell_type(X, T).

%A cell's type is PARAMETRIC in what it holds, which is the whole point of
%`(StateMonad $t)`: the cell that holds 5 is `(StateMonad Number)` and the one
%that holds "hi" is `(StateMonad String)`. The content's type is asked the same
%way any other value's is, so a cell holding a declared symbol reports that
%declaration [tested: test_a_state_cell_is_a_value_typed_by_what_it_holds].
metta_state_cell_type(X, ['StateMonad', Held]) :-
    metta_state_cell(X),
    metta_state_value(X, Value),
    get_type_candidate(Value, Held).

get_type_candidate_in(_, X, T) :- number(X), !, metta_numeric_type(X, T).
get_type_candidate_in(_, X, _) :- var(X), !.
get_type_candidate_in(_, X, 'String')   :- string(X), !.
get_type_candidate_in(_, true, 'Bool')  :- !.
get_type_candidate_in(_, false, 'Bool') :- !.
get_type_candidate_in(_, X, T) :- atomic(X), \+ atom(X),
                                  seam:host_object(X),
                                  metta_grounded_type(X, T).
get_type_candidate_in(_, [Family|Parameters], 'SpaceType') :-
    Space = [Family|Parameters],
    metta_space_operand(Space),
    !.
get_type_candidate_in(Module, X, T) :- get_function_type_in(Module, X, T).
%Shape before negation, for the reason get_type_candidate/2's twin above
%records: both are pure tests over a term the var clause has already made
%nonvar, so the swap moves no solution and only stops a symbol calling
%application_arrow_declared_in/2 to have its [F|_] head fail.
get_type_candidate_in(Module, X, T) :- X = [_|_],
                                       is_list(X),
                                       \+ application_arrow_declared_in(Module, X),
                                       tuple_first_in(X, Module, First),
                                       (   tuple_fold(First, T)
                                       ;   tuple_rest_types(has_resolved_type_in(Module),
                                                            X, T)
                                       ).

get_type_candidate_in(Module, X, T) :- type_declaration_in(Module, X, T).
get_type_candidate_in(Module, X, T) :- builtin_surface_governs_in(Module, X),
                                       seam:builtin_type_declaration(X, T).
get_type_candidate_in(_, X, 'SpaceType') :- atom(X), metta_space_operand(X).
get_type_candidate_in(_, X, T) :- metta_state_cell_type(X, T).

%A NONEMPTY expression no arrow types is read ELEMENT-WISE, and the tuple it reads is
%%Undefined% as soon as one member's type is. Nothing is known about a tuple
%one of whose components is unknown, so reporting the shape while a hole sits
%inside it claims more than was derived: `(get-type (some-undeclared-call))`
%answered `(%Undefined%)`, a one-element tuple, where the answer is that
%nothing is known at all.
%
%Recursion falls out of the bottom-up walk rather than being written: an inner
%tuple carrying a hole is itself %Undefined%, so the outer one collapses too.
%An arrow-headed expression is deliberately outside this fallback. If its
%argument count cannot fit a declared arrow, get_function_type/2 produces no
%candidate and inapplicable_typed_application/2 preserves that empty answer;
%typing `(Cons 1)` element-wise would mistake a partial application for tuple
%data [tested: test_an_underapplied_arrow_head_types_as_the_arbiter_does; commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%The two typing areas agreed on 46/76 and 16/20 checkable files
%[assumed 2026-08-21: measured against an earlier reference corpus at that
%date, through a runner this repository no longer ships;
%commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%Measured 2026-08-19 on hyperon 0.2.10 and on an earlier reference
%interpreter, byte-identical across both: `(typed-sym (typed-sym typed-sym))`
%is `(Number (Number Number))` and `(typed-sym (typed-sym aa))` is
%%Undefined%, one undeclared symbol away.
%
%The tuple rule: the FIRST combination through maplist/3, the rest off
%materialized sets.
%
%maplist/3 over a nondeterministic goal is the cartesian product computed by
%BACKTRACKING, and every redo into member i re-runs members i+1..k in full,
%recursive descent included: k members carrying c types each cost
%Theta(c^k * D) for D the size of a member's subtree. Deriving each member's
%set ONCE and enumerating combinations off those lists is the same product for
%Theta(k*D + c^k*k), optimal in the output, and it is what
%_type_annotations.py's _bounded_product already does on the Python side.
%
%The sets are derived only when a SECOND combination is actually asked for.
%Nearly every caller here wants one candidate and stops, and materializing
%every member's complete set for them charges the whole product's cost to a
%query that wanted one element of it: doing it unconditionally cost nilbc 1.4s
%to over 700s. The first combination therefore stays the same maplist/3 walk it
%always was, committed with once/1, and the sets appear on the redo that used
%to pay for the re-descent. maplist/3 also keeps the call DIRECT, which
%library(apply_macros) expands into a specialized recursion; threading the goal
%as a closure instead put a call/3 meta-call on every member of every
%expression nilbc types and cost 6.02% on its own
%[measured 2026-08-22: 28,295,015,801 against 26,689,624,690 instructions:u,
%five significant figures stable over three runs each, and stubbing the redo
%branch out entirely did not move it].
%The walk is written out at both call sites rather than behind one shared
%predicate. That is a deliberate duplication of four lines, and it is worth
%0.395%: the shared predicate measured 25,893,858,002 where these measure
%25,764,293,182, and adding the same predicate back as a clause NOTHING CALLS
%measured 25,792,468,254, so 0.109pp of the difference is code layout, the
%Mytkowicz bias this repository's own baseline.json records for typed-call, and
%the remaining 0.395pp is the call itself [measured 2026-08-22, interleaved
%min-of-two both ways]. The two clauses this serves are already parallel
%implementations of one rule for the self module and for a named one.
%The list leads each helper so clause selection is first-argument indexed.
%member_set_product_rest/2 varies the LAST member fastest, exactly as maplist/3
%did, so the candidate order every downstream deduplication reads is unchanged
%[tested: a_wide_expression_types_in_time_linear_in_its_width]
%[measured 2026-08-22: 15 members carrying 3 declared types each and one
%undeclared member, 581,130,797 inferences to 1,721, the base growing 3.02x per
%added member where this is flat at 109; command=swipl -g true -t halt over
%type_answers/3, differenced with statistics/2 on inferences].
tuple_first_in([], _, []).
tuple_first_in([Member|Members], Module, [T|Ts]) :-
    has_resolved_type_in(Module, Member, T),
    !,
    tuple_first_in(Members, Module, Ts).

tuple_types_scoped(Space, Module, Members, T) :-
    tuple_first_scoped(Members, Space, Module, First),
    (   tuple_fold(First, T)
    ;   tuple_rest_types(scoped_has_type(Space, Module), Members, T)
    ).

tuple_first_scoped([], _, _, []).
tuple_first_scoped([Member|Members], Space, Module, [T|Ts]) :-
    scoped_has_type(Space, Module, Member, T),
    !,
    tuple_first_scoped(Members, Space, Module, Ts).

tuple_rest_types(Goal, Members, T) :-
    tuple_member_sets(Members, Goal, Sets),
    %Every remaining combination folds to the %Undefined% the first one already
    %answered, so there is nothing left to enumerate.
    \+ undefined_member_set(Sets),
    member_set_product_rest(Sets, T).

%The type of one combination is a FOLD over its members, and one %Undefined%
%member makes it %Undefined% however many types the others offer.
%== rather than memberchk/2, because a member's type may still be an unbound
%variable and memberchk would BIND it to %Undefined% and answer yes.
tuple_fold(Members, Type) :-
    (   member(Member, Members), Member == '%Undefined%'
    ->  Type = '%Undefined%'
    ;   Type = Members
    ).

%Left to right and failing on the first EMPTY set, which is what maplist/3's
%conjunction did: one member with no type at all means the expression has no
%tuple type, and the product would otherwise discover that only after
%enumerating every combination of the members to its left. Testing a domain
%before using it is the cheapest case of arc consistency. An empty set is not
%an undefined one and must not answer %Undefined%: no candidate at all is
%inapplicable_typed_application/3's case, where %Undefined% would report a type
%that was never derived.
tuple_member_sets([], _, []).
tuple_member_sets([Member|Members], Goal, [Set|Sets]) :-
    findall(T, call(Goal, Member, T), Set),
    Set \== [],
    tuple_member_sets(Members, Goal, Sets).

undefined_member_set(Sets) :-
    member(Set, Sets),
    member(Type, Set),
    Type == '%Undefined%',
    !.

%Every combination EXCEPT the all-firsts one, which the maplist/3 walk already
%answered. Keeping each member's first type and recursing holds that prefix
%until some member takes a later type; from there the members to its right are
%unconstrained.
member_set_product_rest([[First|Rest]|Sets], [T|Ts]) :-
    (   T = First,
        member_set_product_rest(Sets, Ts)
    ;   member(T, Rest),
        member_set_product(Sets, Ts)
    ).

member_set_product([], []).
member_set_product([Set|Sets], [T|Ts]) :-
    member(T, Set),
    member_set_product(Sets, Ts).

%%%% Type lookup in one explicitly selected space %%%%
%
%Ordinary get-type in a named execution context intentionally sees that
%space and &self, the shared tier. get-type-space is a different operation:
%upstream's GetTypeSpaceOp passes exactly the selected DynSpace to
%get_atom_types, so a foreign declaration cannot acquire an ambient sibling
%[source: hyperon-experimental@3f76dc4,
%lib/src/metta/runner/stdlib/atom.rs:433-445].
%
%This is a separate call graph rather than a thread-local "scoped" flag in
%type_declaration_in/3. The ordinary named-space lookup is the typed-call hot
%path, and testing a flag there would charge every lookup for a mode only
%get-type-space requests. The explicit operation pays for its own isolation;
%ordinary get-type keeps the predicates and inference count it had before
%[tested: get_type_space_selects_only_the_space].
scoped_type_answers(Space, X, Types) :-
    space_module(Space, Module),
    findall(Type, scoped_type_candidate(Space, Module, X, Type), Candidates),
    unique_type_answers(Candidates, Unique),
    scoped_widen_to_super_types(Space, Module, X, Unique, Widened),
    ( Widened == [] -> Types = ['%Undefined%'] ; Types = Widened ).

scoped_type_candidate(_, _, X, T) :- number(X), !, metta_numeric_type(X, T).
scoped_type_candidate(_, _, X, _) :- var(X), !.
scoped_type_candidate(_, _, X, 'String') :- string(X), !.
scoped_type_candidate(_, _, true, 'Bool') :- !.
scoped_type_candidate(_, _, false, 'Bool') :- !.
scoped_type_candidate(_, _, X, T) :- atomic(X), \+ atom(X),
                                     seam:host_object(X),
                                     metta_grounded_type(X, T).
scoped_type_candidate(_, _, [Family|Parameters], 'SpaceType') :-
    Space = [Family|Parameters],
    metta_space_operand(Space),
    !.
scoped_type_candidate(Space, Module, X, T) :-
    scoped_function_type(Space, Module, X, T).
%Shape before negation, the third instance of the swap get_type_candidate/2
%records. It is worth more here than in either twin: the negated goal is
%scoped_function_type/4, which reads the selected space through
%match_stored/4, so an atom used to pay a space read to prove it is not an
%application before the free test that says it is not even an expression.
scoped_type_candidate(Space, Module, X, T) :-
    X = [_|_],
    is_list(X),
    \+ scoped_function_type(Space, Module, X, _),
    tuple_types_scoped(Space, Module, X, T).
scoped_type_candidate(Space, Module, X, T) :-
    scoped_type_declaration(Space, Module, X, T).
scoped_type_candidate(_, Module, X, T) :- builtin_surface_governs_in(Module, X),
                                          seam:builtin_type_declaration(X, T).
scoped_type_candidate(_, _, X, 'SpaceType') :- atom(X), metta_space_operand(X).
scoped_type_candidate(_, _, X, T) :- metta_state_cell_type(X, T).

scoped_function_type(Space, Module, [F|Args], T) :-
    nonvar(F),
    (   scoped_type_declaration(Space, Module, F, Raw),
        metta_runtime_type(Raw, [->|Ts0])
    *-> Ts = Ts0
    ;   seam:builtin_type_declaration(F, [->|Ts])
    ),
    append(Expected, [T], Ts),
    maplist(scoped_has_type(Space, Module), Args, Expected).

%The selected path materializes its candidate set. That cost belongs only to
%the explicit scoped operation; the ordinary has_type_in/3 path keeps its
%lazy first-witness fast path unchanged.
scoped_has_type(Space, Module, X, T) :-
    (   ground(T)
    ->  (   scoped_type_witness(Space, Module, X, T)
        ->  true
        ;   scoped_type_answers(Space, X, Types),
            member(Actual, Types),
            metta_resolved_types_match_in(Module, Actual, T)
        )
    ;   scoped_type_answers(Space, X, Types),
        member(Raw, Types),
        metta_runtime_type(Raw, Actual),
        metta_runtime_type(T, Actual)
    ).

%The same one-enumeration shape type_witness_in/3 above uses, for the same
%reason: asking whether a candidate widens to T and then, separately, whether T
%is itself a candidate ran scoped_type_candidate/4 twice over the same term, and
%each walk re-entered its subterms. typing_rule_accepts/4 still leads, so a
%decisive user rule is consulted before the reflexive case as it was.
scoped_type_witness(Space, Module, X, T) :-
    (   once(( scoped_type_candidate(Space, Module, X, Actual),
               type_witness_candidate_matches(Module, Actual, T) ))
    ->  true
    ;   satisfies_metatype_in(Module, X, T)
    ->  true
    ;   scoped_type_answers(Space, X, Types),
        once(( member(Widened, Types),
               type_witness_candidate_matches(Module, Widened, T) ))
    ).

%THE CHEAP TEST LEADS, for the reason widen_to_super_types/4 above records:
%scoped_widening_applies/3 reaches get_function_type/2 through
%application_return_type/2 and so types the application again, where
%scoped_any_super_type_edge/1 is one indexed probe of an empty ':<' bucket. Both
%are pure tests that bind nothing. get-type-space is a separate call graph on
%purpose, so the ordinary path's fix does not reach it.
scoped_widen_to_super_types(Space, Module, X, Types0, Types) :-
    (   scoped_any_super_type_edge(Space),
        scoped_widening_applies(Space, Module, X)
    ->  findall(Declared,
                scoped_type_declaration(Space, Module, X, Declared),
                Directs),
        partition(type_already_listed(Directs), Types0, Direct, Products),
        type_edge_view(space(Space), Edges),
        scoped_super_type_rounds(Module, Edges, Direct, Direct, DirectWidened),
        append(Products, DirectWidened, Combined),
        scoped_super_type_rounds(Module, Edges, Combined, Combined, Types)
    ;   Types = Types0
    ).

scoped_widening_applies(Space, Module, X) :-
    \+ number(X),
    \+ string(X),
    X \== true,
    X \== false,
    \+ scoped_function_type(Space, Module, X, _).

scoped_any_super_type_edge(Space) :-
    \+ \+ match_stored(Space, [':<', _, _], true, _).

scoped_add_super_types(Space, Types, Widened) :-
    space_module(Space, Module),
    type_edge_view(space(Space), Edges),
    scoped_super_type_rounds(Module, Edges, Types, Types, Widened).

scoped_super_type_rounds(_, _, [], Widened, Widened) :- !.
scoped_super_type_rounds(Module, Edges, Frontier, Accumulated, Widened) :-
    findall(Super,
            ( member(Type, Frontier),
              type_edge_from_view(Edges, Type, Super),
              typing_rule_accepts_resolved(Module, 'declared-widening', Type, Super) ),
            Supers),
    exclude(type_already_listed(Accumulated), Supers, Fresh),
    (   Fresh == []
    ->  Widened = Accumulated
    ;   append(Accumulated, Fresh, Grown),
        scoped_super_type_rounds(Module, Edges, Fresh, Grown, Widened)
    ).

%A grounded Python object is Grounded, and its Python classes are its types:
%every class on the object's method resolution order short of object itself is
%a candidate, so a torch Linear is a Linear and a Module, in the same way
%MeTTa's own types are nondeterministic. This is what lets a declared
%(-> Tensor Tensor Tensor) hold for values the host created.
%A bridge that knows how to read the object answers with every type name at
%once, protocols included, as names or structural type expressions; without
%one, the host's own class walk runs, which the HOST BRIDGE supplies through
%seam:grounded_class_type/2 because enumerating a value's classes is host
%code by nature. What a bridge owns is the CLASS WALK and
%nothing else, so the engine-side extra types are a second clause rather than
%a branch of this one.
%No catch here, deliberately. A bridge whose seam:grounded_type_names/2 clause
%THROWS is the registrant's bug, and reading the throw as "no bridge answered"
%ran the class walk instead: one broken protocol predicate silently destroyed
%typing for every host object in the process, and get-type answered Box, the
%envelope's own class, for all of them. extensions/python/metta/_binding/dispatch.py says the rule in
%as many words for the same probe on the Python side: "A broken probe is the
%registrant's bug: surface it with the protocol's name attached, never as a
%type quietly missing." The fallback is for a bridge that is ABSENT, which is
%an ordinary configuration and stays one [tested: metta_object_types].
metta_grounded_type(X, T) :- ( seam:grounded_type_names(X, Names)
                               -> member(N, Names),
                                  ( string(N) -> atom_string(T, N) ; T = N )
                             ; seam:grounded_class_type(X, T) ).
%A protocol the object satisfies may name a type too, and so may a (py-atom f
%Type) declaration, both through seam:grounded_extra_type/2, so a declared (->
%DLTensor ...) holds for every array library at once. This is a DECLARATION
%seam, where every clause has to stay reachable, and not an ownership one
%[source: engine/ext_points.pl, seam:every_clause_runs/1]. It used to hang off
%the class walk, which is the ELSE arm above, and the shipped library answers
%the bridge for every Python object: the arm was dead in that configuration and
%a declared type was accepted and then dropped. `(py-atom math.pow (-> Number
%Number Number))` answered `(builtin_function_or_method)` through the library
%and `(builtin_function_or_method (-> Number Number Number))` through run.sh
%[measured 2026-08-18] [tested:
%extensions/python/tests/ch11_python_as_a_notation/test_ops.py::test_a_declared_type_survives_the_library_being_loaded].
%Two relations rather than one wider if-then-else, for the reason Sterling and
%Shapiro give for lifting entitlement/2 out of pension/2: a cut that picks a
%default correctly still prevents the alternatives being found [source: The Art
%of Prolog 2nd ed, 11.5 "Default Rules", pp 206-207].
metta_grounded_type(X, T) :- seam:grounded_extra_type(X, T).

%Computed from the VALUE and then unified, rather than dispatched on the answer.
%The clauses below are ordered and cut on X, so they are only correct when the
%second argument arrives unbound; with it bound, an earlier clause whose head
%names a different metatype simply does not unify and the catch-all at the
%bottom claims the call. That made `(get-metatype foo Grounded)` SUCCEED for a
%symbol, and both callers ask with it bound: has_type/2 and the type guard the
%translator compiles around every declared parameter, so a parameter declared
%`Grounded` accepted anything at all
%[tested: a_grounded_parameter_admits_an_unknown_and_refuses_a_declared_other].
'get-metatype'(X, Metatype) :-
    metatype_of(X, Computed),
    (   var(Metatype)
    ->  Metatype = Computed
    ;   current_metta_module(Module),
        typing_rule_accepts(Module, witness,
                            '$metta_resolved_type'(Computed), Metatype)
    ).

metatype_of(X, 'Variable') :- var(X), !.
metatype_of(X, 'Grounded') :- number(X), !.
metatype_of(X, 'Grounded') :- string(X), !.
metatype_of(true,  'Grounded') :- !.
metatype_of(false, 'Grounded') :- !.
%A NAME is Grounded when this engine holds a function for it and a Symbol
%when it does not. That is upstream PeTTa's entire rule, one clause asking
%one register [source: PeTTa@43705f5d src/metta.pl:202, `'get-metatype'(X,
%'Grounded') :- atom(X), fun(X), !.`; commit=7bc8e2ac2a2adfa252d5251ee123f320c2dd5ce7].
%
%It replaced a 115-name table adopted from an earlier reference semantics,
%which classified a name by what MINIMAL MeTTa calls grounded rather than what
%this engine holds. Over the 268 names in the union of both engines' fun/1
%and that table, the two rules disagreed on 108 and 74 of those were names
%whose fun/1 membership is IDENTICAL in both engines -- `car-atom`, `let`,
%`eval`, `empty`, `min`, `nop` and `&self` among them -- so on those 74 the
%disagreement was the rule and nothing else. Under this clause that number
%is 0 and the surviving 115 are exactly the names one engine ships and the
%other does not [measured 2026-09-05; command=one generated file of 268
%labelled `!(get-metatype ...)` forms run through `sh run.sh` and through the
%pinned upstream checkout's own run.sh; fixture=the union of both engines'
%fun/1 and this table; commit=7bc8e2ac2a2adfa252d5251ee123f320c2dd5ce7]. The run and its residues are
%recorded in docs/journal/2026-09-05-get-metatype-follows-fun.md.
%
%fun/1 rather than builtin_fun/1, because the classification is a fact about
%the CONTEXT and not about the language: a `(= (my-f $x) $x)` in the program
%makes `my-f` Grounded on BOTH engines, upstream's src/filereader.pl:22
%registering the head of every equation it reads exactly as this engine's
%does [measured 2026-09-05: `!(get-metatype my-f)` after that equation is
%Grounded on upstream and on this tree].
metatype_of(X, 'Grounded') :- atom(X), fun(X), !.
%A SPACE HANDLE and a STATE CELL are atoms here, so they answer through the
%clause above and are Symbols unless a function carries their name. Upstream
%answers Symbol for all three of `&self`, a handle bound with
%`!(bind! &space-a (new-space))`, and a state name bound with
%`!(bind! &st (new-state 5))` [measured 2026-09-05, both engines]. Two
%clauses answered Grounded for them until then; they went with the table,
%because keeping either would have restored an exception list of exactly the
%kind this change retired. What carries their SPECIES is get-type, which
%still answers `SpaceType` and `(StateMonad $t)` and which is what the
%engine's own paths and lib_builtin_types' declarations consult
%[tested: spaces:space_handle_type].
%
%THE THREE CLAUSES BELOW ARE COST-ORDERED, WHICH IS FREE BECAUSE THEY AGREE.
%Every one of them answers 'Grounded' and every one of them cuts, so no
%permutation of them can change the answer for any term: whichever fires
%first ends the call with the same second argument. That is stronger than
%mutual exclusivity and does not depend on it, which matters because
%seam:host_object/1 is an open ownership seam and an extension may claim a
%term that also spells a function name or a parametric space.
%They are therefore ordered by what they cost an ordinary SYMBOL, the atom
%this ladder decides most often, cheapest first: an indexed registry lookup,
%a head that does not unify, and last the seam, which is the only one that
%leaves the engine
%[measured 2026-09-05 in the shipped Python configuration, per-call slope
%between 20,000 and 40,000 iterations: metatype_of(+) 4 inferences, an
%ordinary symbol 9, a number 3, an expression 8; the probe is in
%docs/journal/2026-09-05-get-metatype-follows-fun.md; commit=7bc8e2ac2a2adfa252d5251ee123f320c2dd5ce7].
%The order below CANNOT be extended past list_shaped/1 or the 'Symbol'
%clause: those answer something else, so a term claimed by the seam and
%shaped like a list would change its metatype.
metatype_of([Family|Parameters], 'Grounded') :-
    Space = [Family|Parameters],
    metta_space_operand(Space),
    !.
metatype_of(X, 'Grounded') :- seam:host_object(X), !.
metatype_of(X, 'Expression') :- list_shaped(X), !. % e.g., (+ 1 2), (a b)
metatype_of(X, 'Symbol') :- atom(X), !.            % e.g., a
metatype_of(_, 'Grounded').                        % e.g., partial(f,[1]), f(1)

%The names MINIMAL MeTTa treats as GROUNDED TOKENS. It decided `get-metatype`
%until 2026-09-05, when the user ruled that this engine follows upstream
%PeTTa, whose rule is fun/1 and nothing else; metatype_of/2 above carries that
%rule now and the differential behind it. What still reads this table is
%minimal `eval`, which must RUN a grounded operation rather than take one
%equality step over equations that happen to share its name. It decided
%`if-equal` and `trace!` while the prelude was MeTTa and wrote
%`(eval (if-equal ...))` eight times; the prelude is Prolog since 2026-09-07
%and NO name is both in this table and carrying equations in a fresh engine
%[measured 2026-09-07 by enumerating metta_grounded_token(N),
%fun_meta_module(Self, N, _) with Self the &self module: the empty list]. The
%guard is not dead: it decides for a name a PROGRAM defines, which is what a
%space's own `(= (if-equal ...) ...)` is [source: engine/translator/runtime.pl,
%metta_minimal_equation_step/3].
%
%The list stays as adopted, because upstream PeTTa at ae66fa8e, the arbiter, is
%silent about what it now answers: minimal MeTTa is a form upstream PeTTa
%does not have at all, so the PeTTa ruling does not reach it
%[assumed: 98 names were read from an earlier reference semantics on 2026-08-19
%and 115 stand here since]. The engine's vocabulary lane also
%reads it, as one of the four registers that make a name one this engine
%speaks about [source: tests/checks/check_llms_names.py, engine_vocabulary].
metta_grounded_token('%'). metta_grounded_token('&self').
metta_grounded_token('*'). metta_grounded_token('+').
metta_grounded_token('-'). metta_grounded_token('/').
metta_grounded_token('<'). metta_grounded_token('<=').
metta_grounded_token('=='). metta_grounded_token('=alpha').
metta_grounded_token('>'). metta_grounded_token('>=').
metta_grounded_token('_assert-results-are-alpha-equal').
metta_grounded_token('_minimal-foldl-atom').
metta_grounded_token('_assert-results-are-alpha-equal-msg').
metta_grounded_token('_assert-results-are-equal').
metta_grounded_token('_assert-results-are-equal-msg').
metta_grounded_token('_new-state').
metta_grounded_token('abs-math').
metta_grounded_token('acos-math').
metta_grounded_token('add-atom'). metta_grounded_token('and').
metta_grounded_token('asin-math').
metta_grounded_token('atan-math'). metta_grounded_token('bind!').
metta_grounded_token('call-native').
metta_grounded_token('capture').
metta_grounded_token('ceil-math').
metta_grounded_token('change-state!').
metta_grounded_token('collapse-extract').
metta_grounded_token('cos-math').
metta_grounded_token('declare-pre-add!').
metta_grounded_token('declare-post-add!').
metta_grounded_token('undeclare-pre-add!').
metta_grounded_token('undeclare-post-add!').
metta_grounded_token('div-euclid').
metta_grounded_token('div-floor').
metta_grounded_token('div-trunc').
metta_grounded_token('floor-math').
metta_grounded_token('fork-space').
metta_grounded_token('format-args').
metta_grounded_token('fuzzy-match').
metta_grounded_token('fuzzy-match-space').
metta_grounded_token('fuzzy-match-context').
metta_grounded_token('get-atoms').
metta_grounded_token('match-under').
metta_grounded_token('owned-record-read').
metta_grounded_token('get-metatype').
metta_grounded_token('get-state').
metta_grounded_token('get-type').
metta_grounded_token('has-declared-type').
metta_grounded_token('space-admission-verdict').
metta_grounded_token('space-contains').
metta_grounded_token('get-type-space').
metta_grounded_token('git-import!').
metta_grounded_token('git-module!').
metta_grounded_token('hyperpose').
metta_grounded_token('if-equal'). metta_grounded_token('import!').
metta_grounded_token('import-into!').
metta_grounded_token('import-item!').
metta_grounded_token('include').
metta_grounded_token('index-atom').
metta_grounded_token('atom-subst').
metta_grounded_token('intersection-atom').
metta_grounded_token('isinf-math').
metta_grounded_token('isnan-math').
metta_grounded_token('loaded-mods!').
metta_grounded_token('log-math'). metta_grounded_token('match').
metta_grounded_token('match%'). metta_grounded_token('max-atom').
metta_grounded_token('min-atom').
metta_grounded_token('mod-euclid').
metta_grounded_token('mod-floor').
metta_grounded_token('mod-space!').
metta_grounded_token('module-space-no-deps').
metta_grounded_token('module-tree!').
metta_grounded_token('near-match').
metta_grounded_token('new-space'). metta_grounded_token('nop').
metta_grounded_token('not'). metta_grounded_token('or').
metta_grounded_token('bit-shift-left').
metta_grounded_token('bit-shift-right').
metta_grounded_token('bit-and').
metta_grounded_token('bit-or').
metta_grounded_token('bit-xor').
metta_grounded_token('bit-not').
metta_grounded_token('floor-div').
metta_grounded_token('pow-math'). metta_grounded_token('pragma!').
metta_grounded_token('print-alternatives!').
metta_grounded_token('print-mods!').
metta_grounded_token('println!').
metta_grounded_token('register-module!').
metta_grounded_token('rem-trunc').
metta_grounded_token('require-extension!').
metta_grounded_token('remove-atom').
metta_grounded_token('subtract-atom').
metta_grounded_token('round-math').
metta_grounded_token('sealed'). metta_grounded_token('sin-math').
metta_grounded_token('size-atom').
metta_grounded_token('skel-swap-pair-native').
metta_grounded_token('sort-atom').
metta_grounded_token('sort-strings').
metta_grounded_token('space-atom-count').
metta_grounded_token('sqrt-math').
metta_grounded_token('subtraction-atom').
metta_grounded_token('superpose').
metta_grounded_token('tan-math'). metta_grounded_token('trace!').
metta_grounded_token('trunc-math').
metta_grounded_token('union-atom').
metta_grounded_token('unique-atom'). metta_grounded_token('xor').

%A parameter declared with a METATYPE accepts any atom of that kind, which is
%what makes a variadic constructor declarable: a container has no fixed arity
%and the language's answer for that is `Expression`, which is how HE declares
%`(: superpose (-> Expression Atom))`. Before this, no metatype checked in a
%parameter position at all, so `(: PyList (-> Expression PyList))` typed a call
%to it as the tuple product of its arguments rather than as PyList.
%
%`Atom` accepts everything, and the mechanism is NOT the subtype relation `:<`
%spells even though the tutorial's wording invites that reading. It is one
%equality with a wildcard, and the implementation line is:
%
%    *typ == ATOM_TYPE_ATOM || *typ == get_meta_type(atom)
%
%[source: hyperon-experimental@3f76dc4 lib/src/metta/types.rs:606-617].
%So the check is
%"the parameter is Atom, or it equals this value's metatype", which is what the
%shipped typing-rule rows declare. The tutorial line calling Atom "a supertype
%for Symbol,
%Expression, Variable, Grounded" is recorded there as tutorial prose that
%"records intent only", and taking it literally would have routed metatypes
%through add_super_types, where they do not belong: no widening happens and
%nothing declares an edge [tested: metta_metatype_parameters]. Issue #611 is
%the developers' own phrasing of the same thing, "Atom is the metatype that is
%the sum of Symbol, Variable, Grounded and Expression".
%
%This is consulted only after the declared types have failed, so a value with a
%matching declaration answers exactly as it did, and a program using none of
%these names never reaches it.
satisfies_metatype(X, Metatype) :-
    current_metta_module(Module),
    satisfies_metatype_in(Module, X, Metatype).

satisfies_metatype_in(Module, X, Metatype) :-
    metatype_of(X, Actual),
    typing_rule_accepts_resolved(Module, metatype, Actual, Metatype).
