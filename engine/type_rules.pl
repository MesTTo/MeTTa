% Guarantees: with_typing_policy_stable/1 scopes typing_policy_snapshot/1 through
%   metta_with_trailed/3 while retaining the typing-policy mutex, and the
%   snapshot is a declared context reader compiled to its read
%   [tested: trailed_scopes; commit=3ff7688a605c1f0de0e021f66f3075353476a992].
%
% Purpose: hold the declared typing-rule registry and resolve its explicit
%   accept, refuse(Reason), and defer outcomes for every engine type checker.
% Guarantees: with_typing_policy_stable/1 restores its snapshot on inference
%   cuts while retaining the policy publication mutex
%   [tested: reference_scopes; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: the shipped decision clauses are compiled from typing_rule_entry/7
%   and preserve its directed matching, variable sharing and first decision
%   [tested: sh engine/test.sh suites/typecheck/compiled_typing_rules.plt;
%   commit=e246959279271d22f166a1c8fb1840896295a020].
%   Expected-family queries reuse compiled shipped patterns while user rules
%   retain query-time normalization and precedence [tested: sh engine/test.sh
%   suites/typecheck/compiled_typing_rules.plt; commit=e246959279271d22f166a1c8fb1840896295a020].
% Assumes:
%   - current_metta_module/1 identifies the execution module whose user rules
%     are in scope.
% Guarantees:
%   - shipped and user rules occupy typing_rule_entry/7, and compatibility,
%     arrow arity, widening, and metatype checks all resolve through that one
%     relation [tested: test_a_user_typing_rule_participates_like_a_shipped_one;
%     commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%   - a user refusal is decisive and keeps its rule name and reason, while
%     defer continues to the next rule [tested:
%     test_a_user_typing_rule_participates_like_a_shipped_one;
%     commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%   - typing_policy_is_default/1 identifies the exact module in which a
%     statically proved contract may be discharged, and an ordinary or
%     widening rule change recompiles that module's retained clauses through
%     the support graph before the mutation returns [tested:
%     test_a_static_parameter_proof_yields_to_a_later_typing_rule;
%     commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
%   - with_typing_policy_stable/1 permits static discharge only when it acquired
%     the policy mutex before the surrounding transaction began. A caller that
%     reaches it from an older transaction compiles the dynamic check instead
%     [tested:
%     translator_literal_type_checks:a_stale_transaction_keeps_the_dynamic_contract;
%     commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd].
%   - a user rule lives exactly as long as the space that declared it:
%     retire_typing_rules_in/1 withdraws the module's whole user tier through
%     the same door 'remove-typing-rule!'/2 uses, and engine/spaces/lifecycle.pl
%     calls it while releasing, so a pooled space name cannot inherit its past
%     life's typing policy [tested:
%     typing_rule_scope:a_released_space_retires_the_typing_rules_declared_in_it,
%     typing_rule_scope:the_next_life_of_a_released_module_answers_the_ordinary_refusal;
%     commit=84327245373bba29fba00cf2cea62d8257a9f5cb].
% Decides:
%   - rules are tried in registration order, user tier before shipped tier;
%     the shared overlap reporter names every ordering-sensitive intersection.
% Guarded by:
%   - '$metta_typing_policy' serializes each registry mutation with translation
%     and publication of clauses that reuse a static parameter proof.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None
% Guarantees: raw compatibility inputs and user patterns resolve aliases at
%   their lexical owner; resolved inputs preserve that meaning. Concrete
%   witness targets retain ordinary refusals and target-only wildcards
%   [tested: test_aliases_keep_the_fast_path_and_registry_in_agreement,
%   test_alias_casts_keep_the_strict_witness_and_obey_user_refusals;
%   commit=acad923476d21110870f235192757281a737ee71].
% Guarantees: a union type decomposes in every family only after both tiers
%   have declined the pair as written, so a user rule naming the whole union
%   stays decisive and a refused alternative never refuses a permitted one; an
%   accepted union remains nondeterministic so a shared type variable is
%   assigned once across the whole call [tested:
%   union_types:a_user_refusal_of_the_whole_pair_is_decisive_in_retained_and_runnable_code,
%   union_types:a_refused_alternative_does_not_refuse_a_permitted_one,
%   union_types:the_upstream_witness_cannot_discharge_a_shared_variable;
%   commit=78d1d8946990498965fa940a676d1b91fb8bd35f].

% The public families and registry views share one declaration inventory.
% registered_typing_rule/7 exposes the patterns the checker matches;
% raw_registered_typing_rule/7 preserves written names for dependency tracking.
% typing_rule_entry/7 stays private storage [tested:
% engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named;
% commit=acad923476d21110870f235192757281a737ee71].
:- module(type_rules,
          [ 'add-typing-rule!'/6,
            'remove-typing-rule!'/2,
            typing_rule_accepts/4,
            typing_rule_accepts_resolved/4,
            typing_rule_decision/7,
            typing_rule_decision_resolved/7,
            decisive_typing_rule/7,
            typing_rule_expected/3,
            typing_rule_expected_resolved/3,
            typing_rule_refusal/6,
            typing_rule_refusal_resolved/6,
            registered_typing_rule/7,
            raw_registered_typing_rule/7,
            typing_policy_is_default/1,
            typing_policy_shortcuts_allowed/1,
            % The context reader's callable form. Every call inside this
            % module is inlined by its declaration, so the predicate is
            % reached only from outside, where an unexported name is invisible.
            typing_policy_snapshot/1,
            with_typing_policy_stable/1,
            typing_rule_reference_module/2,
            retire_typing_rules_in/1
          ]).

% Assumes: metta_engine:goal_expansion/2 is visible while clauses compile.
% Set the base before the clauses and their engine-dependent directives.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/expand.pl#L239; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- set_module(base(metta_engine)).

:- dynamic typing_rule_entry/7.
:- discontiguous typing_rule_entry/7, shipped_typing_rule/5,
                 shipped_typing_rule_expected/2,
                 shipped_typing_rule_expected_unbound/2.
:- meta_predicate typing_rule_transaction(0).
:- meta_predicate with_typing_policy_stable(0).
:- seam:context_reader(typing_policy_snapshot(Snapshot),
                       '$metta_typing_policy_snapshot', value(snapshot(Snapshot))).

%Compile the invariant pattern tests beside each declaration. The source row
%remains the reflection surface, and the generated clauses choose in the same
%order. This is the declaration-to-clauses transformation used by SWI's record
%library, confined to this module and this declaration shape.
%[source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/record.pl#L541;
%commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
term_expansion(typing_rule_entry(shipped, '*', Name, Family, Left, Right, Decision),
               [typing_rule_entry(shipped, '*', Name, Family, Left, Right, Decision),
                (shipped_typing_rule(Family, Actual, Expected, Outcome, Name) :-
                     (LeftGoal, RightGoal, Decision \== defer, !, Outcome = Decision)),
                shipped_typing_rule_expected(Family, Right),
                (shipped_typing_rule_expected_unbound(Family, Expected) :-
                     RightGoal)]) :-
    prolog_load_context(module, type_rules),
    compiled_typing_pattern(Actual, Left, LeftGoal),
    compiled_typing_pattern(Expected, Right, RightGoal).

compiled_typing_pattern(Value, Pattern, Goal) :-
    (   var(Pattern)
    ->  Goal = (Value = Pattern)
    ;   Goal = (nonvar(Value), Value = Pattern)
    ).

% The shipped tier is data in exactly the relation add-typing-rule! extends.
% Actual and expected patterns are ordinary Prolog terms, so repeating Same in
% two positions declares equality without a separate hard-coded equality arm.
typing_rule_entry(shipped, '*', 'typing-ordinary-unknown-actual',
                  ordinary, '%Undefined%', _, accept).
typing_rule_entry(shipped, '*', 'typing-ordinary-unknown-expected',
                  ordinary, _, '%Undefined%', accept).
typing_rule_entry(shipped, '*', 'typing-ordinary-atom-actual',
                  ordinary, 'Atom', _, accept).
typing_rule_entry(shipped, '*', 'typing-ordinary-atom-expected',
                  ordinary, _, 'Atom', accept).
typing_rule_entry(shipped, '*', 'typing-ordinary-exact',
                  ordinary, Same, Same, accept).

% A raw type variable already fixed through a compound formal is not the Atom
% wildcard. Its family therefore omits the two Atom rules while retaining the
% gradual and exact rules.
typing_rule_entry(shipped, '*', 'typing-derived-unknown-actual',
                  derived, '%Undefined%', _, accept).
typing_rule_entry(shipped, '*', 'typing-derived-unknown-expected',
                  derived, _, '%Undefined%', accept).
typing_rule_entry(shipped, '*', 'typing-derived-exact',
                  derived, Same, Same, accept).

% Type reporting follows Hyperon's match_reducted_types relation. Unlike the
% runtime relation above, a literal Atom result is an ordinary type here; only
% the gradual unknown and exact equality are shipped matches.
typing_rule_entry(shipped, '*', 'typing-reporting-unknown-actual',
                  reporting, '%Undefined%', _, accept).
typing_rule_entry(shipped, '*', 'typing-reporting-unknown-expected',
                  reporting, _, '%Undefined%', accept).
typing_rule_entry(shipped, '*', 'typing-reporting-exact',
                  reporting, Same, Same, accept).

% A bound observation needs evidence. Only the expected side is gradual;
% an unknown actual does not establish Person. This is the strict cast door's
% existing target-only wildcard law, distinct from ordinary consistency.
typing_rule_entry(shipped, '*', 'typing-witness-unknown-expected',
                  witness, _, '%Undefined%', accept).
typing_rule_entry(shipped, '*', 'typing-witness-atom-expected',
                  witness, _, 'Atom', accept).
typing_rule_entry(shipped, '*', 'typing-witness-unchecked-expected',
                  witness, _, '_', accept).
typing_rule_entry(shipped, '*', 'typing-witness-exact',
                  witness, Same, Same, accept).

% Arrow arity is compared after a chain has been reduced to its declared
% input count. The rule, not type_chain_takes/2, decides equality.
typing_rule_entry(shipped, '*', 'typing-arrow-arity-exact',
                  'arrow-arity', Same, Same, accept).

% BigInt-to-Number is the implicit numeric widening. Declared :< edges use a
% separate family so their broad rule cannot turn every pair of ordinary types
% into a match.
typing_rule_entry(shipped, '*', 'typing-bigint-widens-to-number',
                  widening, 'BigInt', 'Number', accept).
typing_rule_entry(shipped, '*', 'typing-declared-widening-edge',
                  'declared-widening', _, _, accept).

% The metatype split is likewise declared: Atom is its wildcard and each
% shipped metatype is an explicit row. Keeping the four names here is what
% lets metta_argument_type_origin/3 discover the family from the registry
% instead of carrying a second closed list in metta.pl.
typing_rule_entry(shipped, '*', 'typing-metatype-atom',
                  metatype, _, 'Atom', accept).
typing_rule_entry(shipped, '*', 'typing-metatype-symbol',
                  metatype, 'Symbol', 'Symbol', accept).
typing_rule_entry(shipped, '*', 'typing-metatype-variable',
                  metatype, 'Variable', 'Variable', accept).
typing_rule_entry(shipped, '*', 'typing-metatype-grounded',
                  metatype, 'Grounded', 'Grounded', accept).
typing_rule_entry(shipped, '*', 'typing-metatype-expression',
                  metatype, 'Expression', 'Expression', accept).

typing_rule_family(ordinary).
typing_rule_family(derived).
typing_rule_family(reporting).
typing_rule_family(witness).
typing_rule_family('arrow-arity').
typing_rule_family(widening).
typing_rule_family('declared-widening').
typing_rule_family(metatype).

valid_typing_rule_outcome(accept).
valid_typing_rule_outcome(defer).
valid_typing_rule_outcome([refuse, Reason]) :- nonvar(Reason).

% add-typing-rule!(+Name, +Family, +Actual, +Expected, +Outcome, -Result).
% Patterns may contain variables; assertz/2 copies them into the declaration.
'add-typing-rule!'(Name, Family, Actual, Expected, Outcome, true) :-
    must_be(atom, Name),
    require_typing_rule_family(Family),
    require_typing_rule_outcome(Outcome),
    current_metta_module(Module),
    with_typing_policy_stable(
        typing_rule_transaction(
            ( add_typing_rule_locked(
                  Module, Name, Family, Actual, Expected, Outcome, Change),
              apply_typing_rule_change(Module, Change) ))).

add_typing_rule_locked(Module, Name, Family, Actual, Expected, Outcome,
                       Changed) :-
    findall(F-A-E-O,
            typing_rule_entry(user, Module, Name, F, A, E, O),
            Existing),
    (   Existing == []
    ->  assertz(typing_rule_entry(
                    user, Module, Name, Family, Actual, Expected,
                    Outcome), Ref),
        record_source_assertion(Ref),
        typing_policy_change_kind(Family, Changed)
    ;   member(Old, Existing), Old =@= Family-Actual-Expected-Outcome
    ->  Changed = unchanged
    ;   throw(error(metta_duplicate_typing_rule(Name, Existing),
                    context('add-typing-rule!'/6,
                            'a rule name identifies one declaration')))
    ).

% remove-typing-rule!(+Name, -Result). Only the current module's user rule is
% withdrawn; shipped rules cannot be removed through the user door.
'remove-typing-rule!'(Name, true) :-
    must_be(atom, Name),
    current_metta_module(Module),
    remove_typing_rule_in(Module, Name).

remove_typing_rule_in(Module, Name) :-
    with_typing_policy_stable(
        typing_rule_transaction(
            ( remove_typing_rule_locked(Module, Name, Change),
              apply_typing_rule_change(Module, Change) ))).

%A SPACE'S LIFE OWNS THE RULES DECLARED IN IT. add-typing-rule! writes into
%the execution module of the space that ran it, and engine/spaces/lifecycle.pl
%releases a space by retiring what its module accumulated: its tokens, its
%translator registrations, its type aliases and its generated predicates. A
%typing rule was not among them, and the Python surface POOLS anonymous space
%names, so the next life of a released name inherited the dead life's typing
%policy and re-decided its argument checks
%[tested: a_released_space_retires_the_typing_rules_declared_in_it;
%commit=84327245373bba29fba00cf2cea62d8257a9f5cb].
%Withdrawn through the public door rather than by retracting the entries, so
%the invalidation a rule change owes its module stays written once.
retire_typing_rules_in(Module) :-
    findall(Name, typing_rule_entry(user, Module, Name, _, _, _, _), Names0),
    sort(Names0, Names),
    forall(member(Name, Names), remove_typing_rule_in(Module, Name)).

remove_typing_rule_locked(Module, Name, Changed) :-
    findall(Family-Ref,
            clause(typing_rule_entry(
                       user, Module, Name, Family, _, _, _),
                   true, Ref),
            Entries),
    maplist(erase_typing_rule_entry, Entries),
    (   member(Family-_, Entries),
        typing_policy_fast_path_family(Family)
    ->  Changed = policy
    ;   Entries == []
    ->  Changed = unchanged
    ;   Changed = registry
    ).

erase_typing_rule_entry(_-Ref) :- erase(Ref).

%The families a STATIC FAST PATH depends on, which is what makes a user rule in
%one of them a policy change rather than a registry change: a compiled shortcut
%was chosen on the shipped relation and has to be withdrawn when that relation
%moves.
%
%`metatype` joined this list on 2026-09-05 with the metatype shape test in
%engine/metta/terms.pl. Before that test existed a metatype check always walked
%the registry, so a user metatype rule was honoured whatever this list said;
%the shape test decides the common case without the registry, so a user rule in
%that family would have been BYPASSED. Caught by
%metta_metatype_guards:a_user_metatype_rule_is_not_bypassed, which refuses
%'Symbol' for a symbol and requires the check to refuse it.
%
%The list is therefore not a preference: a fast path that reads a family and a
%family missing from here is an unsoundness, and adding the fast path means
%adding the family.
typing_policy_fast_path_family(ordinary).
typing_policy_fast_path_family(widening).
typing_policy_fast_path_family(metatype).

typing_policy_change_kind(Family, policy) :-
    typing_policy_fast_path_family(Family),
    !.
typing_policy_change_kind(_, registry).

apply_typing_rule_change(Module, policy) :-
    !,
    typing_policy_changed(Module).
apply_typing_rule_change(_, registry) :-
    !,
    clear_translation_cache.
apply_typing_rule_change(_, unchanged).

typing_rule_transaction(Goal) :-
    ( current_transaction(_) -> call(Goal) ; transaction(Goal) ).

% A transaction reads the dynamic database at the generation at which it
% began. If it starts before waiting for the mutex, it can therefore observe a
% policy that a preceding owner has already replaced. Such a caller may still
% compile while holding the mutex, but it must retain every dynamic check.
% Acquiring the mutex before transaction/1 begins marks the ordinary safe path.
with_typing_policy_stable(Goal) :-
    typing_policy_snapshot(_),
    !,
    call(Goal).
with_typing_policy_stable(Goal) :-
    (   current_transaction(_)
    ->  Snapshot = conservative
    ;   Snapshot = stable
    ),
    with_mutex(
        '$metta_typing_policy',
        metta_with_trailed_enumeration('$metta_typing_policy_snapshot',
                                      snapshot(Snapshot), Goal)).

% A static proof is valid only under the shipped ordinary/widening relation.
% Other rule families do not participate in an argument contract.
typing_policy_is_default(Module) :-
    \+ ( typing_rule_entry(user, Module, _, Family, _, _, _),
         typing_policy_fast_path_family(Family) ).

typing_policy_shortcuts_allowed(Module) :-
    typing_policy_snapshot(stable),
    typing_policy_is_default(Module).

% Source rollback owns only clause references. This projection lets it recover
% the module whose compiled clauses must be rebuilt after the referenced rule
% has been erased.
typing_rule_reference_module(Ref, Module) :-
    clause(typing_rule_entry(user, Module, _, Family, _, _, _), true, Ref),
    typing_policy_fast_path_family(Family).

require_typing_rule_family(Family) :-
    (   nonvar(Family), typing_rule_family(Family)
    ->  true
    ;   throw(error(domain_error(typing_rule_family, Family),
                    context('add-typing-rule!'/6,
                            'use ordinary, derived, reporting, witness, arrow-arity, widening, declared-widening, or metatype')))
    ).

require_typing_rule_outcome(Outcome) :-
    (   nonvar(Outcome), valid_typing_rule_outcome(Outcome)
    ->  true
    ;   throw(error(domain_error(typing_rule_outcome, Outcome),
                    context('add-typing-rule!'/6,
                            'use accept, (refuse Reason), or defer')))
    ).

prolog:error_message(metta_duplicate_typing_rule(Name, Existing)) -->
    [ 'typing rule ~w already names ~w'-[Name, Existing] ].

% typing_rule_decision_resolved(+Module, +Family, ?Actual, ?Expected, -Outcome,
%                      -Name, -Tier).
% `defer` is an explicit decline, not a negative decision: continue through
% the remaining user entries and then the shipped tier. If none decides, the
% registry itself returns defer.
% The public relation owns alias substitution. A resolved input is a type
% observer's result, not syntax to reinterpret in the observer's caller.
% Compiled checks use the resolved entry points after the declaration reader
% has fixed lexical meaning and chosen argument masks.
typing_rule_input(Module, Raw, Type) :-
    (   nonvar(Raw), Raw = '$metta_resolved_type'(Resolved)
    ->  metta_runtime_type(Resolved, Type)
    ;   normalize_callable_type_in(Module, Raw, Type)
    ).

typing_rule_decision(Module, Family, RawActual, RawExpected, Outcome, Name, Tier) :-
    typing_rule_input(Module, RawActual, Actual),
    typing_rule_input(Module, RawExpected, Expected),
    typing_rule_decision_resolved(Module, Family, Actual, Expected,
                                  Outcome, Name, Tier).

typing_rule_accepts(Module, Family, RawActual, RawExpected) :-
    typing_rule_input(Module, RawActual, Actual),
    typing_rule_input(Module, RawExpected, Expected),
    typing_rule_accepts_resolved(Module, Family, Actual, Expected).

typing_rule_refusal(Module, Family, RawActual, RawExpected, Name, Reason) :-
    typing_rule_input(Module, RawActual, Actual),
    typing_rule_input(Module, RawExpected, Expected),
    typing_rule_refusal_resolved(Module, Family, Actual, Expected, Name, Reason).

typing_rule_expected(Module, Family, RawExpected) :-
    typing_rule_input(Module, RawExpected, Expected),
    typing_rule_expected_resolved(Module, Family, Expected).

%A union decomposes only AFTER both tiers have been asked about the pair as
%written, which is what makes a user rule naming the whole union decisive: a
%refusal of `(Number, (| Number String))` is answered here and never reaches
%the alternatives, while a rule that says nothing about the pair leaves the
%alternatives to decide under this same family's rules. Its guard is inlined
%in the existing chain, so a pair with no `|` on either side reaches the
%unchanged `defer` at no extra cost.
typing_rule_decision_resolved(Module, Family, Actual, Expected, Outcome, Name, Tier) :-
    (   decisive_typing_rule(user, Module, Family, Actual, Expected,
                             Outcome, Name)
    ->  Tier = user
    ;   decisive_typing_rule(shipped, '*', Family, Actual, Expected,
                             Outcome, Name)
    ->  Tier = shipped
    ;   (   nonvar(Actual), Actual = [ActualHead|_], ActualHead == '|'
        ;   nonvar(Expected), Expected = [ExpectedHead|_], ExpectedHead == '|'
        )
    ->  typing_union_decision(Module, Family, Actual, Expected,
                              Outcome, Name, Tier)
    ;   Outcome = defer,
        Name = none,
        Tier = none
    ).

% A value-level type operator must read a declared decision on the whole pair
% before decomposing it. This door deliberately performs no union lifting.
% [tested: union_types:a_user_whole_union_refusal_precedes_its_value_refinements;
% commit=7e2de138f59cd8137f55dce9e7f2f955906c76d1].
decisive_typing_rule(shipped, '*', Family, Actual, Expected, Outcome, Name) :-
    shipped_typing_rule(Family, Actual, Expected, Candidate, Name),
    !,
    Outcome = Candidate.
decisive_typing_rule(user, Module, Family, Actual, Expected, Outcome, Name) :-
    typing_rule_entry(user, Module, Name, Family, RawActual,
                      RawExpected, Candidate),
    normalize_callable_type_in(Module, RawActual, ActualPattern),
    normalize_callable_type_in(Module, RawExpected, ExpectedPattern),
    typing_pattern_openness(ActualPattern, ActualOpen),
    typing_pattern_openness(ExpectedPattern, ExpectedOpen),
    typing_rule_pattern_matches(Actual, ActualPattern, ActualOpen),
    typing_rule_pattern_matches(Expected, ExpectedPattern, ExpectedOpen),
    Candidate \== defer,
    !,
    Outcome = Candidate.

% Matching is directed from a declaration pattern to the checker's value.
% A rule variable may bind to that value, including linking two positions in
% an exact rule. A literal pattern does not bind an as-yet unknown checker
% value: `%Undefined%` means the literal gradual type, not a type variable that
% happens to be free when the rule is tried.
typing_pattern_openness(Pattern, open) :- var(Pattern), !.
typing_pattern_openness(_, closed).

typing_rule_pattern_matches(Value, Pattern, open) :- Pattern = Value.
typing_rule_pattern_matches(Value, Pattern, closed) :-
    nonvar(Value),
    Pattern = Value.

% Ordinary and derived compatibility delegate their unmatched pairs to the
% widening family. A decisive refusal never falls through.
% A witness wildcard target asks for no evidence. These shipped rows have an
% unconstrained actual and a literal target; the exact row shares its variable
% and therefore does not qualify. This preserves casting.py:_UNCHECKED even
% when an alias reaches the engine instead of Python's literal-target shortcut
% [tested: test_aliases_of_unchecked_cast_targets_stay_unchecked;
% commit=acad923476d21110870f235192757281a737ee71]. Concrete witness targets still honor ordinary refusals.
typing_check_decision_resolved(_, witness, _, Expected, accept, Name, shipped) :-
    nonvar(Expected),
    typing_rule_entry(shipped, '*', Name, witness, AnyActual, Target, accept),
    var(AnyActual), nonvar(Target), Expected == Target,
    !.
typing_check_decision_resolved(Module, Family, Actual, Expected, Outcome, Name, Tier) :-
    typing_rule_decision_resolved(Module, Family, Actual, Expected,
                         Direct, DirectName, DirectTier),
    (   Direct == defer,
        ( Family == ordinary ; Family == derived ; Family == reporting
        ; Family == witness )
    ->  typing_rule_decision_resolved(Module, widening, Actual, Expected,
                                      Candidate, CandidateName, CandidateTier)
    ;   Candidate = Direct,
        CandidateName = DirectName,
        CandidateTier = DirectTier
    ),
    (   Family == witness, Candidate == accept,
        typing_check_decision_resolved(Module, ordinary, Actual, Expected,
                                        [refuse, Reason], Rule, RuleTier)
    ->  Outcome = [refuse, Reason], Name = Rule, Tier = RuleTier
    ;   Outcome = Candidate, Name = CandidateName, Tier = CandidateTier
    ).

typing_rule_accepts_resolved(Module, Family, Actual, Expected) :-
    typing_check_decision_resolved(Module, Family, Actual, Expected,
                          accept, _, _).

typing_rule_refusal_resolved(Module, Family, Actual, Expected, Name, Reason) :-
    typing_check_decision_resolved(Module, Family, Actual, Expected,
                          [refuse, Reason], Name, _).

% A checker can ask whether an expected type belongs to a declared family
% without inventing a parallel list. This is used to classify metatype
% parameters before their actual argument is known. A user rule with a broad
% expected pattern deliberately widens that family for its own module.
% A bound expected value can use the clause index directly. An initially free
% value keeps the directed checks: matching Family can bind a shared variable
% before the expected pattern is tested, so filtering open patterns in advance
% would change the relation [tested: compiled_typing_rules; commit=e246959279271d22f166a1c8fb1840896295a020].
typing_rule_expected_resolved(Module, Family, Expected) :-
    (   typing_rule_entry(user, Module, _, Family, _, RawPattern, _),
        normalize_callable_type_in(Module, RawPattern, Pattern),
        typing_pattern_openness(Pattern, Openness),
        typing_rule_pattern_matches(Expected, Pattern, Openness)
    ;   (   nonvar(Expected)
        ->  shipped_typing_rule_expected(Family, Expected)
        ;   shipped_typing_rule_expected_unbound(Family, Expected)
        )
    ),
    !.

% The reporter reads this predicate, so it analyzes the exact entries the
% checker resolves rather than maintaining a second inventory.
registered_typing_rule(Tier, Module, Name, Family, Actual, Expected, Outcome) :-
    typing_rule_entry(Tier, Module, Name, Family, RawActual, RawExpected, Outcome),
    (   Tier == user
    ->  normalize_callable_type_in(Module, RawActual, Actual),
        normalize_callable_type_in(Module, RawExpected, Expected)
    ;   Actual = RawActual, Expected = RawExpected
    ).

% Source dependency discovery needs the written names, including aliases that
% are still missing. Reflection through the rule-family view above needs the
% patterns the checker actually matches, including their lexical expansion.
raw_registered_typing_rule(Tier, Module, Name, Family, Actual, Expected, Outcome) :-
    typing_rule_entry(Tier, Module, Name, Family, Actual, Expected, Outcome).
