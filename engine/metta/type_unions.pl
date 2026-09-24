% Purpose: read `(| T1 T2 ...)` as a union where a type is read, and lift a
%   binary type relation over it in both directions.
% Assumes: this plain source unit is consulted by engine/metta/types.pl, so its
%   definitions land in the engine implementation module beside
%   metta_runtime_type/2, which is the projection that canonicalises a union.
% Guarantees:
%   - metta_union_alternatives/2 flattens a nested union, projects each member
%     through metta_runtime_type/2 so an annotated arrow member reaches the
%     arrow relation, and keeps the first of any structurally identical members
%     in written order [tested:
%     tests/prolog/suites/typecheck/union_types.plt; commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
%   - metta_union_relates/3 admits an ACTUAL union only when every alternative
%     satisfies the requirement under ONE assignment of the type variables they
%     share, and a REQUIRED union when some alternative is satisfied. A pair
%     that is ground on both sides commits after one proof; anything else keeps
%     its alternatives so the enclosing argument group can still solve a shared
%     variable [tested:
%     union_types:the_upstream_witness_cannot_discharge_a_shared_variable;
%     commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
% Fails when: the written union is empty or improperly terminated. Those throw
%   metta_type_union_syntax rather than standing as a type name nothing can
%   satisfy [tested: union_types:an_empty_union_is_refused_as_type_syntax;
%   commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
% Decides: `|` heads a union only where a type is read. An expression atom whose
%   head begins with `|`, the corpus's `(|-> ($x) ...)` lambdas included, stays
%   data [tested: union_types:a_pipe_expression_outside_a_type_stays_data;
%   commit=78d1d8946990498965fa940a676d1b91fb8bd35f].

% Every caller reaches this behind an inlined `Head == '|'` test at its own
% reader, so a program that writes no union pays nothing for the feature. A
% chain extended with that guard retires the same inferences as the chain
% without it, and the tracked form of that claim compares a hit, which stops
% before the guard, with a miss, which runs through it
% [tested: union_types:the_union_guards_retire_no_inference_on_a_pair_with_no_union,
% union_types:a_union_free_check_does_not_scan_declared_unions;
% commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
%
% The head is compared with ==/2 after binding a fresh variable, never unified
% against the literal `'|'`: a partial list whose head is unbound would
% otherwise be turned INTO a union by the test that asks whether it is one.
metta_union_alternatives(Type, Alternatives) :-
    nonvar(Type),
    Type = [Head|Written],
    Head == '|',
    (   Written = [_|_],
        is_list(Written)
    ->  metta_union_flatten(Written, Members),
        metta_union_distinct(Members, [], Alternatives)
    ;   throw(error(metta_type_union_syntax(Type), none))
    ).

% metta_runtime_type/2 canonicalises a member that is itself a union, so a
% nested union arrives here already flat and splices in written order.
metta_union_flatten([], []).
metta_union_flatten([Written|Rest], Members) :-
    metta_runtime_type(Written, Member),
    (   metta_union_alternatives(Member, Nested)
    ->  append(Nested, Tail, Members)
    ;   Members = [Member|Tail]
    ),
    metta_union_flatten(Rest, Tail).

% Structural identity, NOT variant equality. Two distinct free type variables
% are variants of one another, so `=@=` would collapse `(| $a $b)` to a single
% alternative and drop a constraint the rest of the chain may still need. On
% ground members the two agree exactly, which is the case a repeated member
% actually arises in.
metta_union_distinct([], _, []).
metta_union_distinct([Member|Rest], Kept, Alternatives) :-
    (   metta_union_member_kept(Kept, Member)
    ->  Alternatives = Tail,
        Next = Kept
    ;   Alternatives = [Member|Tail],
        Next = [Member|Kept]
    ),
    metta_union_distinct(Rest, Next, Tail).

metta_union_member_kept([Present|Rest], Member) :-
    (   Present == Member
    ->  true
    ;   metta_union_member_kept(Rest, Member)
    ).

% A one-member union IS that member, and a union whose written members survive
% unchanged keeps the term it was given so callers comparing types with ==/2
% see no new structure.
metta_union_canonical(Raw, Canonical) :-
    metta_union_alternatives(Raw, Alternatives),
    (   Alternatives = [Single]
    ->  Canonical = Single
    ;   Raw = [_|Written],
        Written == Alternatives
    ->  Canonical = Raw
    ;   Canonical = ['|'|Alternatives]
    ).

% The directional rule, lifted over whichever family relation Base names.
%
% An actual union on the left must satisfy the requirement in ALL of its
% alternatives, a required union on the right in SOME. What makes the left rule
% sound is that the alternatives are checked in one conjunction, so alternative
% two is decided under whatever alternative one bound and backtracking searches
% assignments rather than accepting each alternative in isolation. Typed
% Racket's subtyping threads its accumulator through the left-union alternatives
% the same way, with `for/fold` and `#:break (not A)`, while the right-union
% case is a plain `for/or`
% [source: https://github.com/racket/typed-racket/blob/57b7edab6074dbf4361354b546185f41e4a4c572/typed-racket-lib/typed-racket/types/subtype.rkt,
% the `(case: Union (Union/set: base1 ts1 elems1))` clause of `subtype*` and the
% `Union/set:` arm of `continue<:`; commit=78d1d8946990498965fa940a676d1b91fb8bd35f].
%
% Upstream PeTTa writes the left rule as `\+ ( member(MA, As), \+
% type_compat_soft(MA, B) )` over `type_compat_soft(A, B) :- \+ \+
% type_unify(A, B)`, and the double negation discards the binding each
% alternative needed: `(| Number String)` is then accepted against `(| T Bool)`
% with `T` still free, and `T = 'Number'` afterwards succeeds
% [source: trueagi-io/PeTTa@e038e4dbb587e48fdb9d14990966108d38fde0b3
% src/typecheck/type_lang.pl:27-30, 94; commit=78d1d8946990498965fa940a676d1b91fb8bd35f]. Neither forall/2 nor
% \+ \+ appears below for that reason.
%
% A pair that is ground on both sides carries no assignment for a later
% argument to disagree with, so it commits after one proof and stays as
% deterministic as the equality it stands in for; that is what keeps a repeated
% member from ever producing a repeated answer.
:- meta_predicate metta_union_relates(2, +, +).
metta_union_relates(Base, Actual, Expected) :-
    (   ground(Actual),
        ground(Expected)
    ->  once(metta_union_related(Base, Actual, Expected))
    ;   metta_union_related(Base, Actual, Expected)
    ).

:- meta_predicate metta_union_related(2, +, +).
metta_union_related(Base, Actual, Expected) :-
    (   metta_union_alternatives(Actual, Alternatives)
    ->  metta_union_every_alternative(Alternatives, Base, Expected)
    ;   metta_union_alternatives(Expected, Alternatives),
        member(Alternative, Alternatives),
        call(Base, Actual, Alternative)
    ).

:- meta_predicate metta_union_every_alternative(+, 2, +).
metta_union_every_alternative([], _, _).
metta_union_every_alternative([Alternative|Rest], Base, Expected) :-
    call(Base, Alternative, Expected),
    metta_union_every_alternative(Rest, Base, Expected).

% The third witness both candidate relations fall to, which is one guard and
% one call rather than the same four inlined lines in each twin. The call is
% reached only where identity and widening have both declined, and only a pair
% with a union on one side runs the lift.
:- meta_predicate metta_union_witness(2, +, +).
metta_union_witness(Base, Actual, Expected) :-
    (   nonvar(Actual), Actual = [ActualHead|_], ActualHead == '|'
    ;   nonvar(Expected), Expected = [ExpectedHead|_], ExpectedHead == '|'
    ),
    metta_union_relates(Base, Actual, Expected).

% The same right-hand rule for a VALUE door, where the left side is a term
% rather than a type: the value needs one suitable alternative, and Base is the
% door's own complete witness machinery so each alternative still reaches
% candidates, metatypes, declared `:<` widening and the named-space tier.
:- meta_predicate metta_union_admits(2, +, +).
metta_union_admits(Base, Value, Expected) :-
    metta_union_alternatives(Expected, Alternatives),
    (   ground(Expected)
    ->  once(( member(Alternative, Alternatives),
               call(Base, Value, Alternative) ))
    ;   member(Alternative, Alternatives),
        call(Base, Value, Alternative)
    ).

% The registry's own union decision, defined HERE rather than in
% engine/type_rules.pl, because a predicate resident in that module is not free:
% five inert four-argument predicates appended to it move the identity twin's
% pinned inference count from 3398 to 3403 and ten move it to 3413, while the
% same predicates in this unit move it not at all
% [measured 2026-09-05: 3398 base, 3403 with five, 3413 with ten, 3398 with
% this unit resident and no caller, 3393 as shipped;
% command=PYTHONPATH=extensions/python $CHECK_PY
% extensions/python/tools/twin_coverage.py --measure --rounds 3
% examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta;
% fixture=examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta;
% commit=78d1d8946990498965fa940a676d1b91fb8bd35f]. type_rules keeps the one arm that selects this decision,
% and the alternatives are put back to it through its PUBLIC surface,
% typing_rule_accepts_resolved/4 and typing_rule_refusal_resolved/6, which
% engine/metta.pl's ensure_loaded of that module imports here.

%Three clauses rather than an if-then-else chain, because an accept must stay
%NONDETERMINISTIC. A shared type variable is assigned by whichever combination
%of alternatives satisfies every argument and the result together, and a `->`
%here would commit to the first alternative that fits the first argument and
%lose the assignment a later one needs. The two negative clauses are mutually
%exclusive with the first and with each other, so the relation still answers
%once for a pair no assignment satisfies.
%
%`typing-union-membership` names an accept, because no registry row made that
%decision: the type language did, out of rows that decided the alternatives. A
%refusal instead names the row that refused, and its tier is `user` because
%engine/type_rules.pl ships no rule whose outcome is a refusal, so a refused
%alternative can only have been refused by a rule a program registered.
typing_union_decision(Module, Family, Actual, Expected, 'Accept',
                      'typing-union-membership', shipped) :-
    typing_union_accepts(Module, Family, Actual, Expected).
typing_union_decision(Module, Family, Actual, Expected, ['Refuse', Reason],
                      Name, user) :-
    \+ typing_union_accepts(Module, Family, Actual, Expected),
    typing_union_refusal(Module, Family, Actual, Expected, Reason, Name).
typing_union_decision(Module, Family, Actual, Expected, 'Defer', none, none) :-
    \+ typing_union_accepts(Module, Family, Actual, Expected),
    \+ typing_union_refusal(Module, Family, Actual, Expected, _, _).

%The alternatives are related through the family's own public acceptance
%relation, so each one reaches the widening fallthrough and the witness
%cross-check exactly as a written type would.
typing_union_accepts(Module, Family, Actual, Expected) :-
    metta_union_relates(typing_union_member_accepts(Module, Family),
                        Actual, Expected).

typing_union_member_accepts(Module, Family, Member, Requirement) :-
    typing_rule_accepts_resolved(Module, Family, Member, Requirement).

%A refusal is carried out of the alternatives so the call site still names the
%rule that refused, and it is reported only when NO alternative was admitted:
%a rejected member of a required union must not reject a permitted one.
typing_union_refusal(Module, Family, Actual, Expected, Reason, Name) :-
    (   metta_union_alternatives(Actual, Alternatives)
    ->  member(Alternative, Alternatives),
        typing_union_alternative_refusal(Module, Family, Alternative, Expected,
                                         Reason, Name)
    ;   metta_union_alternatives(Expected, Alternatives),
        member(Alternative, Alternatives),
        typing_union_alternative_refusal(Module, Family, Actual, Alternative,
                                         Reason, Name)
    ).

%A refusal is a negative verdict, so the alternative that produced it must not
%leave its rule pattern's bindings on the caller's type variables. The reason
%and rule name are read out of a copy for that reason alone.
typing_union_alternative_refusal(Module, Family, Actual, Expected, Reason,
                                 Name) :-
    copy_term(pair(Actual, Expected), pair(CopyActual, CopyExpected)),
    once(typing_rule_refusal_resolved(Module, Family, CopyActual, CopyExpected,
                                      Name, Reason)).

:- multifile prolog:error_message//1.
prolog:error_message(metta_type_union_syntax(Type)) -->
    [ 'a union type needs one or more members in a proper list: ~p'-[Type] ].
