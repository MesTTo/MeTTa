% Purpose: the least fixpoint of a space's tagged program under an algebra,
%   computed by the engine's own tabling with the tag as a lattice-moded
%   argument, so a cyclic program converges where the carrier's arithmetic
%   does and an acyclic one costs the engine's semi-naive completion rather
%   than rounds of scanning outside it.
% Assumes: metta_engine loads this unit after metta/algebra_operations.pl;
%   the host's tabling implements the lattice/1 answer-subsumption mode and
%   updates a table only when the joined answer is not a variant of the old
%   one [source: SWI-Prolog boot/tabling.pl, update/7, `Agg \=@= Next`];
%   a module of class temporary is what '$destroy_module'/1 removes, and no
%   clause stored in it may name it [source: SWI-Prolog library/modules.pl,
%   in_temporary_module/3].
% Guarantees:
%   - every relation of the program becomes a tabled predicate whose last
%     argument is the tag under lattice('$join'/3), join being the carrier's
%     combine followed by its saturation test, which is the PITA
%     transformation (Riguzzi and Swift, TPLP 2011, 10.1017/S147106841100010X)
%     [tested: test_a_cyclic_program_converges_under_every_shipped_carrier;
%     commit=WORKTREE].
%   - the fixpoint is exact when combine is idempotent, or when no ground
%     subgoal depends on itself: a completed table is read by its consumers
%     once, at its final answer; inside a strongly connected component of
%     subgoals a non-idempotent join re-adds a premise's earlier answer, and
%     the value grows until the carrier's declared saturation, or the
%     caller's budget, stops it, which is the convergence theorem for naive
%     evaluation (Abo Khamis, Ngo, Pichler, Suciu and Wang, JACM 2024,
%     10.1145/3643027: convergence iff the semiring is stable) [tested:
%     algebra_fixpoint:an_acyclic_program_is_exact_under_a_sum,
%     algebra_fixpoint:a_sum_over_a_cycle_has_no_fixpoint_and_the_budget_stops_it,
%     test_a_cyclic_program_converges_under_every_shipped_carrier; commit=WORKTREE].
%   - a carrier declaring a variable operation receives each fact, and each
%     ground rule instance, as a variable of its own with the written tag as
%     its weight, keyed [src, Space, N] and [rule, Space, N, Head], the keys
%     the derived route mints, so the formula carrier is the free Boolean
%     algebra over the program's facts on either route [tested:
%     test_the_formula_carrier_counts_each_proof_once; commit=WORKTREE].
%   - a rule tagged (function F) labels each instance with F applied to its
%     premise tags in order, evaluated under the carrier, in place of the
%     extend fold: Kifer and Subrahmanian's generalized annotated programs
%     (JLP 1992, 10.1016/0743-1066(92)90007-P), where each rule carries its
%     own label function and the fixpoint is over the carrier's join, whose
%     convergence is the author's obligation as monotonicity of F is theirs
%     [tested: algebra_fixpoint:a_rule_may_label_its_instances_by_a_function_of_its_premise_tags;
%     commit=WORKTREE].
% Fails when: a proposition's head is not a symbol, which the reader refuses
%   by name; a carrier with no fixpoint over cyclic data runs until the
%   caller's timeout or inference budget stops it, as any other unbounded
%   program does, or until its arithmetic overflows, which the host reports
%   as an evaluation error.
% Owns resources: one module per call, destroyed on exit whatever the
%   outcome, its tables abolished first.
% Guarded by: the module name comes from an atomic flag, so concurrent calls
%   never share one; the formula tables are guarded in their own unit.
% Decides: a saturation test that answers anything but True is a change;
%   numbers saturate on =:=, every other value on ==.

%metta_algebra_fixpoint(+Space, +Algebra, +Goal, -Answers): every proposition
%the program derives that matches Goal, each once, paired with its tag at the
%fixpoint, as [[Proposition, Tag], ...] in the order the tables answer.
metta_algebra_fixpoint(Space, Algebra, Goal, Answers) :-
    metta_algebra_descriptor(Algebra, Combine, Extend, _, _, _, _, _),
    metta_algebra_program(Space, Facts, Rules),
    flag('$metta_algebra_fixpoint', N, N + 1),
    % A plain name: a module named with a leading $ is a system module, and
    % only a user module may become temporary.
    atom_concat(metta_algebra_fixpoint_, N, Module),
    setup_call_cleanup(
        ( set_module(Module:class(temporary)),
          metta_algebra_load_program(Module, Space, Algebra, Combine, Extend,
                                     Facts, Rules) ),
        metta_algebra_query(Module, Goal, Answers),
        metta_algebra_unload_program(Module)).

%The program as its two stored forms, each numbered by its position among
%the space's atoms: the number the derived route gives a source, so the two
%routes name one fact by one key.
metta_algebra_program(Space, Facts, Rules) :-
    findall(Atom, 'get-atoms'(Space, Atom), Atoms),
    metta_algebra_program_(Atoms, 0, Facts, Rules).

metta_algebra_program_([], _, [], []).
metta_algebra_program_([Atom|Atoms], N, Facts, Rules) :-
    N1 is N + 1,
    (   Atom = [fact, Tag, Proposition]
    ->  metta_algebra_coefficient(Tag, Coefficient),
        Facts = [fact(N, Coefficient, Proposition)|Facts1], Rules = Rules1
    ;   Atom = [rule, Tag, Head, [premises|Premises]]
    ->  metta_algebra_coefficient(Tag, Coefficient),
        Facts = Facts1, Rules = [rule(N, Coefficient, Head, Premises)|Rules1]
    ;   Facts = Facts1, Rules = Rules1
    ),
    metta_algebra_program_(Atoms, N1, Facts1, Rules1).

%The normative (rate n) declaration reads as its carrier value, as it does on
%the derived route.
metta_algebra_coefficient([rate, Value], Value) :- !.
metta_algebra_coefficient(Tag, Tag).

%A proposition is a symbol applied to arguments, or a bare symbol; its
%predicate takes the arguments and then the tag.
metta_algebra_relation([Name|Args], Name, Args) :- atom(Name), !.
metta_algebra_relation(Name, Name, []) :- atom(Name), !.
metta_algebra_relation(Proposition, _, _) :-
    throw(error(metta_algebra_proposition_head(Proposition), none)).

metta_algebra_literal(Proposition, Tag, Goal) :-
    metta_algebra_relation(Proposition, Name, Args),
    append(Args, [Tag], Slots),
    Goal =.. [Name|Slots].

metta_algebra_load_program(Module, Space, Algebra, Combine, Extend, Facts, Rules) :-
    % The program's clauses call the engine's operations unqualified, so the
    % fresh module imports from the module this unit is loaded into.
    context_module(Engine),
    add_import_module(Module, Engine, start),
    assertz(Module:('$join'(Old, New, Out) :-
                        metta_algebra_join(Algebra, Combine, Old, New, Out))),
    assertz(Module:('$extend'(Left, Right, Out) :-
                        metta_apply_algebra_operation(Algebra, Extend, Left, Right, Out))),
    (   metta_algebra_claim(Algebra, variable, VariableOp)
    ->  assertz(Module:('$variable'(Key, Weight, Out) :-
                            metta_apply_algebra_operation(Algebra, VariableOp, Key, Weight, Out)))
    ;   assertz(Module:('$variable'(_, Weight, Weight)))
    ),
    assertz(Module:('$label'(Function, Tags, Out) :-
                        metta_algebra_label(Algebra, Function, Tags, Out))),
    metta_algebra_relations(Facts, Rules, Relations),
    forall(member(Name/Arity, Relations),
           metta_algebra_table(Module, Name, Arity)),
    forall(member(fact(N, Tag, Proposition), Facts),
           metta_algebra_assert_fact(Module, Space, N, Tag, Proposition)),
    forall(member(rule(N, Tag, Head, Premises), Rules),
           metta_algebra_assert_rule(Module, Space, N, Tag, Head, Premises)).

%Every relation a head, a fact or a premise names, so a premise nobody
%derives is a tabled predicate with no clauses, which fails, rather than an
%unknown procedure.
metta_algebra_relations(Facts, Rules, Relations) :-
    findall(Name/Arity,
            ( ( member(fact(_, _, Proposition), Facts)
              ; member(rule(_, _, Proposition, _), Rules)
              ; member(rule(_, _, _, Premises), Rules),
                member(Proposition, Premises) ),
              metta_algebra_relation(Proposition, Name, Args),
              length(Args, Arity) ),
            Named),
    sort(Named, Relations).

metta_algebra_table(Module, Name, Arity) :-
    PredicateArity is Arity + 1,
    dynamic(Module:Name/PredicateArity),
    length(Slots, Arity),
    % Unqualified: the join resolves in the table's own module, and a clause
    % of a temporary module may not name that module.
    append(Slots, [lattice('$join'/3)], SpecSlots),
    Spec =.. [Name|SpecSlots],
    table(Module:Spec).

%A fact's tag is its variable under a carrier that mints them and its written
%tag otherwise.
metta_algebra_assert_fact(Module, Space, N, Tag, Proposition) :-
    metta_algebra_literal(Proposition, Out, Head),
    assertz(Module:(Head :- '$variable'([src, Space, N], Tag, Out))).

%A rule threads its premises left to right, extending the rule's own tag by
%each premise's tag, the derived route's arithmetic; a carrier that mints
%variables gets one per ground head instance, minted after the premises have
%bound the head, which is ProbLog's variable per ground clause. A rule tagged
%(function F) labels the instance with F over the premise tags instead.
metta_algebra_assert_rule(Module, Space, N, Tag, Head, Premises) :-
    metta_algebra_literal(Head, Out, HeadGoal),
    % Built by recursion, not findall, so the premises keep sharing their
    % variables with the head.
    metta_algebra_premise_literals(Premises, Goals, PremiseTags),
    (   Tag = [function, Function]
    ->  append(Goals, ['$label'(Function, PremiseTags, Out)], Body)
    ;   metta_algebra_extend_chain(PremiseTags, Start, Out, Chain),
        append(Goals, ['$variable'([rule, Space, N, Head], Tag, Start)|Chain], Body)
    ),
    metta_algebra_conjunction(Body, Conjunction),
    assertz(Module:(HeadGoal :- Conjunction)).

%metta_algebra_label(+Algebra, +Function, +Tags, -Label): a rule's label
%function applied to its premise tags, one answer under the carrier.
metta_algebra_label(Algebra, Function, Tags, Label) :-
    (   once(metta_with_under(Algebra, eval([Function|Tags], Label0)))
    ->  Label = Label0
    ;   throw(error(metta_algebra_operation_failed(Algebra, Function, Tags), none))
    ).

metta_algebra_premise_literals([], [], []).
metta_algebra_premise_literals([Premise|Premises], [Goal|Goals], [Tag|Tags]) :-
    metta_algebra_literal(Premise, Tag, Goal),
    metta_algebra_premise_literals(Premises, Goals, Tags).

metta_algebra_extend_chain([], Value, Value, []).
metta_algebra_extend_chain([Tag|Tags], Acc, Out, ['$extend'(Acc, Tag, Next)|Chain]) :-
    metta_algebra_extend_chain(Tags, Next, Out, Chain).

metta_algebra_conjunction([], true).
metta_algebra_conjunction([Goal], Goal) :- !.
metta_algebra_conjunction([Goal|Goals], (Goal, Rest)) :-
    metta_algebra_conjunction(Goals, Rest).

%A relation the program never names has no table and derives nothing.
metta_algebra_query(Module, Goal, Answers) :-
    metta_algebra_literal(Goal, Tag, Call),
    functor(Call, Name, Arity),
    (   current_predicate(Module:Name/Arity)
    ->  findall([Goal, Tag], Module:Call, Answers)
    ;   Answers = []
    ).

metta_algebra_unload_program(Module) :-
    abolish_module_tables(Module),
    '$destroy_module'(Module).

%%%% Join, saturation, claims %%%%

metta_algebra_join(Algebra, Combine, Old, New, Out) :-
    metta_apply_algebra_operation(Algebra, Combine, Old, New, Combined),
    (   metta_algebra_saturated(Algebra, Old, Combined)
    ->  Out = Old
    ;   Out = Combined
    ).

%metta_algebra_saturated(+Algebra, +Old, +New): whether a joined answer is
%not worth another round. Equality after combine is the exact fixpoint in
%the carrier's own arithmetic, which is where a stable carrier stops; a
%declared saturation operation answers True earlier, Scallop's saturated(old,
%new) [source: scallop-lang/scallop core/src/runtime/provenance/provenance.rs].
metta_algebra_saturated(Algebra, Old, New) :-
    (   metta_algebra_claim(Algebra, saturation, Operation)
    ->  metta_with_under(Algebra, eval([Operation, Old, New], Verdict)),
        Verdict == true
    ;   number(Old), number(New)
    ->  Old =:= New
    ;   Old == New
    ).

%metta_algebra_claim(+Algebra, +Claim, -Value): the value of one semiring
%claim, (claim semiring <name> <claim> <value>), as the ordered claim is read.
metta_algebra_claim(Algebra, Claim, Value) :-
    metta_catalog_row([claim, semiring, Algebra, Claim, Value]),
    !.
