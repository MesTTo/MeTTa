% Purpose: materialize finite function-free equation bags at source boundaries.
% Guarantees: only ground acyclic dependency graphs replace ordinary dispatch;
%   every tuple retains its proof count and unsupported calls retain compiled
%   execution [tested: function_free_materialization; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
%   A process that publishes no image registers no erase listener, so clause
%   garbage collection runs no Prolog in it and its inference counts repeat
%   exactly [tested: sh tests/shell/test_boot_inference_determinism.sh;
%   commit=001c97213388e39b14ba3789a60e59a5e2c79f41].
% Assumes: constant query lookup is data complexity for fixed source signatures
%   and arities; validating a generation stamp walks those program properties.
% Owns resources: each snapshot owns one immutable trie through its blob handle.
%   discard_space/1 removes registry references transactionally; ordinary clause
%   and atom garbage collection reclaim the trie after its last reference.
%   A running reader owns one copied result descriptor, with ordinary term life.
%   A transactional image holds source clause references until its first
%   postcommit query validates them or discards the image.
%   One stored-equation owner reference ties an image to clause collection,
%   including unmanaged clear transactions whose old view missed the image.
%   A transactional erase callback retires it through one standing engine,
%   aliased '$metta_source_owner_retirement', created beside the listener and
%   held for the life of the process. A per-callback engine cannot be used:
%   engine_create/3 and engine_destroy/1 zero the calling thread's own
%   pthread_t while they run, and a concurrent thread_join/2 on that thread
%   then dereferences null [tested:
%   a_transactional_collection_creates_no_engine_on_the_collecting_thread;
%   commit=81d05b34f938ff97f835ca1c00205220690cb6f0]. Between posts that
%   engine stays suspended holding the last reference it was handed, one
%   already-collected clause reference, which the next post unbinds.
%   One process-wide erase listener carries that channel, registered by
%   flush_space_materialization/2 before the first publication, outside
%   '$metta_materialization' because the callback takes it, and held for the
%   life of the process because the registration is not transactional.
% Guarded by: '$metta_materialization' protects publication, lookup and removal.
%   Owned outer transactions reconcile touched images in their commit
%   constraint while holding that mutex through commit. Building reads one
%   SWI snapshot and never holds the lookup lock.
% Decides: cyclic proof graphs, evaluated templates, typed calls, inherited
%   data, open calls, multiple distinct results, retained source clauses,
%   attributed outputs and active reduction fuel use ordinary dispatch.
%   Source construction inside unmanaged outer transactions is declined.

:- module(materialize,
          [ with_source_materialization/3,
            with_source_materialization_batch/3,
            materialization_transaction/1,
            materialization_transaction/2,
            materialize_source/1,
            flush_source_materialization/0,
            discard_space/1,
            materialized_call/5,
            space_materialized/1
          ]).
:- use_module(library(apply)).
:- use_module(library(assoc)).
:- use_module(library(lists)).
:- use_module(library(pairs)).
:- use_module(library(ugraphs)).

:- meta_predicate with_source_materialization(+, +, 0).
:- meta_predicate with_source_materialization_batch(+, 0, 0).
:- meta_predicate materialization_transaction(0).
:- meta_predicate materialization_transaction(0, 0).
:- thread_local source_materialization/2.
:- thread_local materialization_transaction_owner/0.
:- thread_local materialization_changed_space/1.
:- thread_local materialization_batch/1.
:- thread_local materialization_pending/1.
:- dynamic materialized_snapshot/5.
:- dynamic materialized_predicate/4.
:- dynamic materialized_owner/3.
:- dynamic materialized_dispatch_ref/2.
:- multifile seam:dispatch_call/4.
:- dynamic seam:dispatch_call/4.
:- multifile seam:effect_operation_name/3.
:- multifile support_graph:support_invalidation_action/1.

% Only an outer transaction/3 changes to current global visibility and holds
% its mutex through commit. A nested constraint has neither property. Capture
% this transaction's final proposals before the visibility change, then
% reconcile only the spaces it touched against the global commit view.
% https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/src/pl-transaction.c#L632-L650
% [tested: overlapping_owned_publications_leave_one_image,
% an_older_owned_release_retires_a_concurrently_published_image; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
materialization_transaction(Goal) :-
    materialization_transaction(Goal, true).

% A caller's own commit-time constraint runs first and in the same refreshed
% view: it is the check that can still reject the transaction, so reconciling
% images for one that will be discarded is publication work thrown away. One
% mutex covers both, and it has to be this one, because publication takes
% '$metta_materialization' outside any transaction and an owned commit must
% exclude it; the alias constraint's own mutex had this call site as its only
% user, so serializing user transactions here instead is a superset.
% [tested: overlapping_owned_publications_leave_one_image,
% structural_aliases:overlapping_transactions_leave_one_alias_and_name_the_loser;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
materialization_transaction(Goal, Constraint) :-
    (   current_transaction(_)
    ->  transaction(Goal, Constraint, '$metta_materialization')
    ;   setup_call_cleanup(
            assertz(materialization_transaction_owner, Ref),
            transaction(( call(Goal), materialization_proposals(Proposals) ),
                        ( call(Constraint),
                          reconcile_materialization(Proposals) ),
                        '$metta_materialization'),
            ( erase(Ref), retractall(materialization_changed_space(_)) ))
    ).

materialization_changed(Space) :-
    (   materialization_transaction_owner,
        \+ materialization_changed_space(Space)
    ->  assertz(materialization_changed_space(Space))
    ;   true
    ).

materialization_proposals(Proposals) :-
    findall(proposal(Space, Images),
            ( materialization_changed_space(Space),
              findall(image(Module, Trie, Stamp, Signatures, Owner),
                      ( materialized_snapshot(Space, Module, Trie, Stamp,
                                              Signatures),
                        materialized_owner(Owner, Space, Trie) ), Images) ),
            Proposals).

reconcile_materialization([]).
reconcile_materialization([proposal(Space, Images)|Rest]) :-
    discard_space_rows(Space),
    (   Images = [image(Module, Trie, Stamp, Signatures, Owner)],
        validated_stamp(Space, Module, Stamp, Current)
    ->  publish_materialization(Space, Module, Current, Signatures, Trie, Owner)
    ;   true
    ),
    reconcile_materialization(Rest).

materialize_source(Space) :-
    (   source_materialization_dormant(Space)
    ->  true
    ;   findall(F, (spaces:get_native_atom(Space, [=, [F|_], _]), atom(F)), Names),
        with_source_materialization(Space, Names, true)
    ).

% Nothing to prepare and nothing prepared: the source doors take the shape
% they had before this subsystem existed. Reading the candidate names walks
% every stored atom, and even the empty walk plus its sort, context row and
% flush cost the loader on every completed source. Both goals are one indexed
% lookup, and the second is what keeps a live relation on the maintained path
% when a program has asked for one.
% [measured 2026-09-05: 786829 SWI inferences over 2000 completed
% runnable-only calls, equal to the pre-subsystem tree at 8f853f99;
% command=cd extensions/python && PYTHONPATH=. $VENV/bin/python bench.py
% --counter-only foreign-match;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
source_materialization_dormant(Space) :-
    \+ source_relation_materialization_enabled,
    \+ materialized_snapshot(Space, _, _, _, _).

%Whether this space's source relations are materialised RIGHT NOW, which is
%what (explain (match ...)) reports beside the plan. The pragma is a request
%and a snapshot is the fact, so a program that asked for materialization and
%whose source held nothing to derive reads False and is telling the truth.
space_materialized(Space) :-
    materialized_snapshot(Space, _, _, _, _),
    !.

with_source_materialization(Space, _Names, Goal) :-
    source_materialization_dormant(Space),
    !,
    call(Goal).
with_source_materialization(Space, Names, Goal) :-
    findall(F, (materialized_snapshot(Space, _, _, _, Signatures),
                member(F/_, Signatures)), Previous),
    append(Names, Previous, All),
    sort(All, Candidates),
    (   Candidates == []
    ->  call(Goal)
    ;   setup_call_catcher_cleanup(
            asserta(source_materialization(Space, Candidates), Ref),
            ( call(Goal), flush_source_materialization ),
            Catcher,
            ( erase(Ref), source_materialization_cleanup(Catcher, Space) ))
    ).

source_materialization_cleanup(exit, _) :- !.
source_materialization_cleanup(!, _) :- !.
source_materialization_cleanup(_, Space) :- discard_space(Space).

% One completed load prepares each space it touched once. A relation built
% while the file body is still running is discarded work, because the loader's
% dependency repairs run after the last form and invalidate it; a fast image
% additionally restores child spaces the caller never names, so the queue and
% not the caller's argument decides what gets prepared. Deferring is invisible
% to a form inside the file: a lookup revalidates its stamp and falls back to
% the retained compiled clauses, which answer the same bag. This is the
% batching boundary the loader already uses for deferred support repairs.
% [source: engine/filereader/source_lifecycle.pl, run_source_repairs/1,
% with_source_load/3; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
% [tested: extensions/python/tests/ch18_performance/test_materialization.py,
% test_a_reloaded_program_builds_its_relation_once; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
with_source_materialization_batch(Space, Prepare, Publish) :-
    gensym(materialization_batch_, Id),
    setup_call_catcher_cleanup(
        assertz(materialization_batch(Id)),
        ( call(Prepare),
          close_materialization_batch(Id, Space),
          call(Publish) ),
        Catcher,
        abandon_materialization_batch(Id, Catcher)).

% The queue closes before publication, so every prepared relation is still
% inside the load's own rollback boundary. A nested load forwards its spaces
% to the enclosing batch, which is the boundary that runs the last repair.
close_materialization_batch(Id, Space) :-
    retractall(materialization_batch(Id)),
    queue_materialization(Space),
    (   materialization_batch(_)
    ->  true
    ;   forall(materialization_pending(Queued), materialize_source(Queued))
    ).

queue_materialization(Space) :-
    (   materialization_pending(Space)
    ->  true
    ;   assertz(materialization_pending(Space))
    ).

% The queue outlives construction and publication, so a throw after one image
% was installed discards every space this load touched rather than only the
% one the caller named.
abandon_materialization_batch(Id, Catcher) :-
    retractall(materialization_batch(Id)),
    (   materialization_batch(_)
    ->  true
    ;   (   batch_completed(Catcher)
        ->  true
        ;   forall(materialization_pending(Queued), discard_space(Queued))
        ),
        retractall(materialization_pending(_))
    ).

batch_completed(exit).
batch_completed(!).

flush_source_materialization :-
    source_materialization(Space, Names),
    !,
    (   materialization_batch(_)
    ->  queue_materialization(Space)
    ;   flush_space_materialization(Space, Names)
    ).
flush_source_materialization.

flush_space_materialization(Space, Names) :-
    % This asks whether any transaction exists. Enumerating its ancestors
    % after the owner check fails repeats an ancestor on SWI 10.1.13.
    % https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-transaction.c#L721-L745
    % [tested: nested_source_transactions_finish_and_restore_the_rolled_back_bag;
    % commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
    (   once(current_transaction(_)), \+ materialization_transaction_owner
    ->  true
    ;   materialized_snapshot(Space, Module, _, Stamp, _),
        snapshot_current(Space, Module, Stamp)
    ->  true
    ;   discard_space(Space),
        (   source_candidates(Space, Names, Module, Candidates),
            Candidates \== [],
            with_metta_module(Module,
                forall(member(F, Candidates), spaces:metta_ensure_compiled(F))),
            snapshot(build_materialization(Space, Module, Candidates,
                                           Stamp, Signatures, Trie, Owner))
        ->  ensure_source_owner_listener,
            with_mutex('$metta_materialization',
                publish_if_current(Space, Module, Stamp, Signatures, Trie,
                                   Owner)),
            forall(member(F/_, Signatures),
                   support_graph:support_record(derived(Module, materialization),
                                                function(Module, F)))
        ;   true
        )
    ).

% Preparation derives the whole relation, which is quadratic in the chain
% family the admission gate is built for, and a load pays it whether or not
% the program ever asks. Loading the two-rule chain at 128 edges costs 5189
% inferences without construction and 4300722 with it, against 2706 saved per
% completed ground query: about 1600 queries to break even. Nothing bounds the
% derived relation, and a load has no way to know how many queries follow, so
% the program says whether to prepare.
% [measured 2026-09-05: 4300722 against 5189 load inferences and 283 against
% 2989 warmed query inferences; command=PYTHONPATH=extensions/python
% $VENV/bin/python -m benchmarks.query_planning_materialization
% {materialized,original} --sizes 128; fixture=the two-rule reach chain;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
source_relation_materialization_enabled :-
    metta_pragma('materialize-source-relations', Value),
    Value \== false,
    Value \== none.

% The routing compiler in metta-on-mork requires finite flat inputs, range
% restriction and co-materialized terminal calls. Retaining the source avoids
% its catchall and equation-introspection changes.
% https://github.com/MesTTo/metta-on-mork/blob/a5f312063529ab7d8df92275c83b288d493edb7e/src/program/mod.rs
% [source: compile_routing and compile_routed_body; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
source_candidates(Space, Names, Module, Candidates) :-
    source_relation_materialization_enabled,
    atom(Space),
    spaces:native_storage_module_ready(Space, _),
    spaces:metta_exec_module_known(Space, Module),
    \+ spaces:space_parent(Space, _),
    \+ metta_fuel_budget_configured,
    \+ translator_rules:translator_rule(match),
    predicate_property(Module:match(_, _, _, _), imported_from(spaces)),
    findall(F,
            ( member(F, Names),
              findall(E, ( E = [=, [F|_], _],
                           spaces:get_native_atom(Space, E) ), Equations),
              Equations \== [],
              maplist(equation_rule(Space, Names), Equations, _) ),
            Candidates),
    member(Useful, Candidates),
    spaces:get_native_atom(Space, [=, [Useful|_], Body]),
    body_factors(Body, Space, [_|_], _),
    !.

build_materialization(Space, Module, Names, Stamp, Signatures, Trie, Owner) :-
    findall(spec(F, Arity, Rules),
            ( member(F, Names),
              compiled_spec(Space, Module, Names, F, Arity, Rules) ), Specs0),
    closed_specs(Specs0, Specs),
    Specs \== [],
    member(spec(_, _, SomeRules), Specs),
    member(rule(_, [_|_], _), SomeRules),
    !,
    findall(Rel/Arity,
            ( member(spec(_, _, Rules), Specs),
              member(rule(_, Factors, _), Rules),
              member([Rel|Args], Factors), length(Args, Arity) ), Relations0),
    sort(Relations0, Relations),
    findall(Arity, ( member(_/Inputs, Relations), Arity is Inputs+1 ), Arities0),
    sort([3|Arities0], Arities),
    findall(F/A, member(spec(F, A, _), Specs), Signatures),
    materialization_source_owner(Space, Signatures, Owner),
    materialization_receipt(Space, Module, Arities, Signatures, Receipt),
    Stamp = pending(Receipt),
    spaces:native_storage_module_ready(Space, Storage),
    maplist(relation_rows(Storage, Space), Relations, RelationRows),
    append(RelationRows, Facts),
    findall(Constant,
            ( sub_term(Constant, Specs-Facts), atomic(Constant) ), Domain0),
    sort(Domain0, Domain),
    findall(Call-Tail,
            ( member(spec(_, _, Rules), Specs),
              member(rule(Call, Factors, Tail), Rules),
              satisfy_factors(Storage, Space, Factors),
              term_variables(Call-Tail, Remaining),
              maplist(domain_member(Domain), Remaining) ), GroundRules),
    derive_ground_bags(GroundRules, Rows),
    trie_new(Trie),
    forall(member(Call-Values, Rows),
           ( result_descriptor(Values, Result), trie_insert(Trie, Call, Result) )).

materialization_source_owner(Space, Signatures, Owner) :-
    spaces:native_storage_module_ready(Space, Storage),
    member(F/_, Signatures),
    spaces:native_atom_clause(Space, [=,[F|_],_], Head),
    clause(Storage:Head, true, Owner),
    !.

compiled_spec(Space, Module, Names, F, Arity, Rules) :-
    \+ translator_rules:translator_rule(F),
    \+ type_declaration_in(Module, F, _),
    default_policies(F),
    findall(E,
            ( current_predicate(Module:F/CompiledArity),
              functor(CompiledHead, F, CompiledArity),
              clause(Module:CompiledHead, _, Ref),
              clause_property(Ref, module(Module)),
              filereader:translated_from(Ref, E) ), Equations),
    Equations = [[=, [F|Args], _]|_],
    length(Args, Arity),
    maplist(equation_arity(F, Arity), Equations),
    maplist(compiled_equation_rule(Space, Names), Equations, Rules),
    PredicateArity is Arity+1,
    functor(Head, F, PredicateArity),
    predicate_property(Module:Head, dynamic),
    \+ predicate_property(Module:Head, tabled),
    predicate_property(Module:Head, number_of_clauses(Count)),
    length(Equations, Count),
    length(CallArgs, Arity),
    with_metta_module(Module, \+ seam:dispatch_call(F, CallArgs, _, _)).

equation_arity(F, Arity, [=, [F|Args], _]) :- length(Args, Arity).

% Native add-atom stores the author's literal &self and compiles the clause
% against the receiving space, the split a source load makes, so the reader
% binds the same clause either door wrote and materializes it the same way.
% The compiled clause's recorded source carries that resolution; the stored
% atom alone does not prove local relational semantics.
% [tested: a_native_literal_self_reads_its_own_space_through_the_materializer; commit=WORKTREE]
compiled_equation_rule(Space, Names, Equation, Rule) :-
    equation_rule(Space, Names, Equation, Rule),
    Equation = [=, _, Body], compiled_local_matches(Body, Space).

compiled_local_matches(Body, Space) :-
    nonvar(Body), Body = [match, Target, _, Tail],
    !,
    Target == Space, compiled_local_matches(Tail, Space).
compiled_local_matches(_, _).

equation_rule(Space, Names, Equation, rule(Call, Factors, Tail)) :-
    acyclic_term(Equation), term_attvars(Equation, []),
    Equation = [=, Call, Body],
    Call = [F|Inputs], atom(F), is_list(Inputs),
    maplist(flat_input, Inputs),
    body_factors(Body, Space, Factors, Leaf),
    maplist(relational_factor, Factors),
    (   nonvar(Leaf), Leaf = [Callee|Args], atom(Callee),
        memberchk(Callee, Names)
    ->  is_list(Args), maplist(flat_input, Args), Tail = invoke(Leaf),
        term_variables(Factors-Args, Bound)
    ;   immutable_template(Leaf), Tail = value(Leaf),
        term_variables(Factors, Bound)
    ),
    term_variables(Call-Leaf, Required),
    variables_in(Required, Bound).

flat_input(X) :- var(X), !, term_attvars(X, []).
flat_input(X) :- atomic(X).

body_factors([match, Target, Pattern, Body], Space, Factors, Leaf) :-
    nonvar(Target), ( Target == Space ; Target == '&self' ),
    !,
    (   nonvar(Pattern), Pattern = [','|Here]
    ->  is_list(Here)
    ;   Here = [Pattern]
    ),
    body_factors(Body, Space, Rest, Leaf),
    append(Here, Rest, Factors).
body_factors(Leaf, _, [], Leaf).

relational_factor([Rel|Args]) :-
    atom(Rel), Rel \== ',', is_list(Args), maplist(flat_input, Args).

immutable_template(X) :- var(X), !.
immutable_template(X) :- atomic(X), !, X \== '$metta_not_reducible'.
immutable_template([F|Args]) :-
    atom(F), \+ fun(F), \+ translator_rules:translator_rule(F),
    is_list(Args), maplist(immutable_template, Args).

variables_in([], _).
variables_in([V|Vs], Bound) :-
    member_same(V, Bound), variables_in(Vs, Bound).
member_same(V, [B|_]) :- V == B, !.
member_same(V, [_|Bs]) :- member_same(V, Bs).

closed_specs(Specs0, Specs) :-
    include(callees_covered(Specs0), Specs0, Kept),
    ( same_length(Specs0, Kept) -> Specs = Kept
    ; closed_specs(Kept, Specs) ).

callees_covered(Specs, spec(_, _, Rules)) :-
    forall(member(rule(_, _, invoke([F|Args])), Rules),
           ( length(Args, Arity),
             member(spec(F, Arity, CalleeRules), Specs),
             forall(member(rule([F|Head], _, _), CalleeRules),
                    distinct_variables(Head)) )).

distinct_variables(Args) :-
    maplist(var, Args), term_variables(Args, Vars), same_length(Args, Vars).

% Inspect candidates before binding the relation name: a stored variable in
% that position must decline admission, even if an indexed call would bind it.
relation_rows(Storage, Space, Rel/Arity, Rows) :-
    StorageArity is Arity+1,
    spaces:native_storage_functor(Space, Predicate),
    functor(Head, Predicate, StorageArity),
    findall(Atom,
            ( clause(Storage:Head, true), Head =.. [_|Atom],
              Atom = [StoredRel|_],
              ( var(StoredRel) ; StoredRel == Rel ) ), Rows),
    maplist(ground_flat_row, Rows).

ground_flat_row(Row) :- ground(Row), maplist(atomic, Row).

satisfy_factors(_, _, []).
satisfy_factors(Storage, Space, [Pattern|Rest]) :-
    spaces:native_atom_clause(Space, Pattern, Goal),
    call(Storage:Goal),
    satisfy_factors(Storage, Space, Rest).

domain_member(Domain, Value) :- member(Value, Domain).

% Motik et al. (AAAI 2014), algorithm 1, materializes consequences once.
% Here the admitted ground graph is a DAG, so a reverse topological pass is
% sufficient. Cycles are declined before evaluating any rule: a finite set
% closure need not have a finite bag of proofs.
% https://ojs.aaai.org/index.php/AAAI/article/view/8730/8589
% [source: Motik et al., algorithm 1 and section 4; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
derive_ground_bags(GroundRules, Rows) :-
    pairs_keys(GroundRules, Vertices),
    findall(Call-Callee, member(Call-invoke(Callee), GroundRules), Edges),
    vertices_edges_to_ugraph(Vertices, Edges, Graph),
    indexed_topological_order(Graph, Order), reverse(Order, BottomUp),
    msort(GroundRules, Sorted), clumped(Sorted, Counted),
    findall(Call-(Premise-Count), member((Call-Premise)-Count, Counted), Pairs),
    group_pairs_by_key(Pairs, Groups), list_to_assoc(Groups, RuleIndex),
    empty_assoc(Empty), foldl(derive_call(RuleIndex), BottomUp, Empty, Computed),
    assoc_to_list(Computed, Rows).

% CPython graphlib keeps an indexed predecessor count and enqueues a node
% when its last predecessor finishes. SWI's list-based top_sort scans the
% vertex list per edge; on a materialized relation that makes preparation
% quadratic in the number of ground calls. An AVL index retains O(log V)
% edge updates, and this difference-list queue costs O(1) per insertion.
% [source: TopologicalSorter.done in
% https://github.com/python/cpython/blob/v3.13.0/Lib/graphlib.py;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
indexed_topological_order(Graph, Order) :-
    maplist(topological_node, Graph, Nodes), list_to_assoc(Nodes, Initial),
    foldl(count_successors, Graph, Initial, Index),
    findall(V, gen_assoc(V, Index, node(_, 0)), Ready),
    append(Ready, Tail, Queue), length(Graph, Count),
    drain_topological(Count, Queue, Tail, Index, Order).

topological_node(V-Successors, V-node(Successors, 0)).
count_successors(_-Successors, Before, After) :-
    foldl(increment_predecessors, Successors, Before, After).
increment_predecessors(V, Before, After) :-
    get_assoc(V, Before, node(Successors, N)), Next is N+1,
    put_assoc(V, Before, node(Successors, Next), After).

drain_topological(0, _, _, _, []) :- !.
drain_topological(Count, Queue, Tail, Before, [V|Order]) :-
    Queue \== Tail, Queue = [V|Rest],
    get_assoc(V, Before, node(Successors, _)),
    ready_successors(Successors, Before, After, Tail, NextTail),
    Remaining is Count-1,
    drain_topological(Remaining, Rest, NextTail, After, Order).

ready_successors([], Index, Index, Tail, Tail).
ready_successors([V|Vs], Before, After, Tail, End) :-
    get_assoc(V, Before, node(Successors, N)), Next is N-1,
    put_assoc(V, Before, node(Successors, Next), Updated),
    ( Next =:= 0 -> Tail = [V|Rest] ; Rest = Tail ),
    ready_successors(Vs, Updated, After, Rest, End).

derive_call(RuleIndex, Call, Before, After) :-
    ( get_assoc(Call, RuleIndex, Premises) -> true ; Premises = [] ),
    findall(Value-Count,
            ( member(Premise-Multiplicity, Premises),
              premise_value(Premise, Before, Value, Ways),
              Count is Multiplicity*Ways ), Values0),
    keysort(Values0, Values1), group_pairs_by_key(Values1, Grouped),
    maplist(sum_proofs, Grouped, Values),
    put_assoc(Call, Before, Values, After).

% Natural-number provenance adds alternative proofs and multiplies joint
% premises. Arbitrary precision counts do not collapse duplicate derivations.
% https://doi.org/10.1145/1265530.1265535
% [source: Green, Karvounarakis and Tannen, Provenance Semirings, section 3;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
premise_value(value(Value), _, Value, 1).
premise_value(invoke(Call), Computed, Value, Ways) :-
    get_assoc(Call, Computed, Values), member(Value-Ways, Values).
sum_proofs(Value-Counts, Value-Count) :- sum_list(Counts, Count).

materialization_stamp(Space, Module, Arities, Signatures,
                      stamp(Storage, Life, Arities, Generations, Self, Rules, Funs,
                            Signatures, Clauses)) :-
    spaces:native_storage_module_ready(Space, Storage),
    spaces:metta_exec_module_generation(Module, Life),
    spaces:native_storage_functor(Space, Predicate),
    maplist(predicate_generation(Storage, Predicate), Arities, Generations),
    storage_generation('&self', 3, Self),
    predicate_generation(translator_rules, translator_rule, 3, Rules),
    metta_engine_module(Engine), predicate_generation(Engine, fun, 1, Funs),
    maplist(compiled_generation(Module), Signatures, Clauses).

compiled_generation(Module, F/Inputs, Generation) :-
    Arity is Inputs+1, predicate_generation(Module, F, Arity, Generation).

predicate_generation(Module, Predicate, Arity, Generation) :-
    functor(Head, Predicate, Arity),
    ( predicate_property(Module:Head, last_modified_generation(G))
    -> Generation = G ; Generation = absent ).

storage_generation(Space, Arity, Generation) :-
    ( spaces:native_storage_module_ready(Space, Storage)
    -> spaces:native_storage_functor(Space, Predicate),
       predicate_generation(Storage, Predicate, Arity, Generation)
    ; Generation = absent ).

% SWI reports transaction-local generations before commit, then replaces
% them with the commit generation. It can also report an external generation
% whose clauses are invisible to a transaction. Record the entire read set
% in the build snapshot; checking only live references would miss additions.
% https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/man/builtin.doc
% [source: Impact of transactions, Last modified generation; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
materialization_receipt(Space, Module, Arities, Signatures,
                        receipt(Storage, Life, Arities, References, Self,
                                Rules, Funs, Signatures, Clauses)) :-
    spaces:native_storage_module_ready(Space, Storage),
    spaces:metta_exec_module_generation(Module, Life),
    spaces:native_storage_functor(Space, Predicate),
    maplist(predicate_references(Storage, Predicate), Arities, References),
    ( spaces:native_storage_module_ready('&self', SelfStorage)
    -> spaces:native_storage_functor('&self', SelfPredicate),
       predicate_references(SelfStorage, SelfPredicate, 3, SelfReferences),
       Self = SelfStorage-SelfReferences
    ; Self = absent ),
    predicate_references(translator_rules, translator_rule, 3, Rules),
    metta_engine_module(Engine), predicate_references(Engine, fun, 1, Funs),
    maplist(compiled_references(Module), Signatures, Clauses).

predicate_references(Module, Predicate, Arity, References) :-
    functor(Head, Predicate, Arity),
    findall(Ref, clause(Module:Head, _, Ref), References).

compiled_references(Module, F/Inputs, References) :-
    Arity is Inputs+1, predicate_references(Module, F, Arity, References).

snapshot_current(Space, Module, pending(Receipt)) :-
    !,
    receipt_current(Space, Module, Receipt).
snapshot_current(Space, Module, Stamp) :-
    spaces:metta_exec_module_known(Space, Module),
    \+ spaces:space_parent(Space, _),
    Stamp = stamp(_, _, Arities, _, _, _, _, Signatures, _),
    materialization_stamp(Space, Module, Arities, Signatures, Current),
    Current == Stamp.

receipt_current(Space, Module, Receipt) :-
    spaces:metta_exec_module_known(Space, Module),
    \+ spaces:space_parent(Space, _),
    Receipt = receipt(_, _, Arities, _, _, _, _, Signatures, _),
    materialization_receipt(Space, Module, Arities, Signatures, Current),
    Current == Receipt.

% Validate a committed read set in a fresh snapshot, bracketed by generation
% reads outside it. A concurrent change anywhere in that interval declines
% admission. A transactional load retains its receipt until after commit;
% only this one-time validation, never derivation, remains for the first query.
% [tested: a_transaction_receipt_detects_an_invisible_concurrent_addition;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
validated_stamp(Space, Module, pending(Receipt), Stamp) :-
    !,
    (   current_transaction(_)
    ->  receipt_current(Space, Module, Receipt), Stamp = pending(Receipt)
    ;   Receipt = receipt(_, _, Arities, _, _, _, _, Signatures, _),
        materialization_stamp(Space, Module, Arities, Signatures, Before),
        snapshot(receipt_current(Space, Module, Receipt)),
        materialization_stamp(Space, Module, Arities, Signatures, After),
        Before == After,
        spaces:metta_exec_module_known(Space, Module),
        \+ spaces:space_parent(Space, _),
        Stamp = After
    ).
validated_stamp(Space, Module, Stamp, Stamp) :-
    snapshot_current(Space, Module, Stamp).

publish_if_current(Space, Module, Stamp, Signatures, Trie, Owner) :-
    (   current_transaction(_)
    ->  (   validated_stamp(Space, Module, Stamp, Current)
        ->  transaction(( discard_space_rows(Space),
                          publish_materialization(Space, Module, Current,
                                                  Signatures, Trie, Owner) ))
        ;   true
        )
    ;   Stamp = pending(Receipt),
        Receipt = receipt(_, _, Arities, _, _, _, _, Signatures, _),
        materialization_stamp(Space, Module, Arities, Signatures, Before),
        (   transaction((
                receipt_current(Space, Module, Receipt),
                materialization_stamp(Space, Module, Arities, Signatures, After),
                Before == After,
                discard_space_rows(Space),
                publish_materialization(Space, Module, After, Signatures,
                                        Trie, Owner) ))
        ->  true
        ;   true
        )
    ).

% A trie has its index before publication; dynamic row indexes would be built
% by the first query and can disappear when a surrounding transaction finishes.
% The blob owns its nodes through atom GC, so retracting a reference preserves
% rollback and readers without explicitly destroying a published index.
% [source: release_trie_ref in
% https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/src/pl-trie.c#L155-L164;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
publish_materialization(Space, Module, Stamp, Signatures, Trie, Owner) :-
    materialization_changed(Space),
    forall(member(F/Arity, Signatures),
           ( assertz(materialized_predicate(Module, F, Arity, Trie)),
             length(Args, Arity),
             assertz(seam:(
                 dispatch_call(F, Args, Out,
                               materialize:materialized_call(Space, Module,
                                                             F, Args, Out)) :-
                     materialize:materialized_query_context(Module)), Ref),
             assertz(materialized_dispatch_ref(Trie, Ref)) )),
    assertz(materialized_snapshot(Space, Module, Trie, Stamp, Signatures)),
    assertz(materialized_owner(Owner, Space, Trie)).

% Copying k distinct outputs before the first answer would turn constant
% startup into O(k). One value plus its count preserves duplicate streaming;
% calls with several distinct values keep the original enumerator.
% [tested: a_many_value_call_keeps_constant_prefix_startup; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
result_descriptor([], none).
result_descriptor([Value-Count], one(Value, Count)).
result_descriptor([_,_|_], original).

% Ground function heads keep unrelated calls off this path, as in lib_memo's
% memo_install_dispatch_handler/1. Each image owns exact clause references;
% shared function counters would let stale transactions erase another image.
% [source: lib/lib_memo/lib_memo.pl, memo_install_dispatch_handler/1;
% commit=8f853f992a4c732eca39de34ff0a3dfe161508dd]
materialized_query_context(Module) :-
    % A retained source body must remain visible to clause-based proof search.
    % Source runnables use guarded mode and direct host expressions have no
    % mode. Tracked equations use enabled and untracked clauses use disabled,
    % including nested lambdas.
    % [source: engine/translator/analysis.pl, translate_tracked_clause/3,
    % translate_clause/3; engine/translator/lowering.pl,
    % translate_runnable_expr/3; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
    ( nb_current('$metta_static_contract_shortcuts', Mode) -> Mode == guarded
    ; true ),
    current_metta_module(Module).

seam:effect_operation_name(materialize:materialized_call(_, _, F, Args, _),
                           F, Arity) :-
    length(Args, Inputs), Arity is Inputs+1.

materialized_call(Space, Module, F, Args, Out) :-
    (   maplist(atomic, Args), term_attvars(Out, []),
        \+ current_transaction(_),
        \+ metta_fuel_budget_configured,
        \+ nb_current('$metta_trace_depth', _),
        metta_effective_algebra(Space, bool), default_policies(F)
    ->  with_mutex('$metta_materialization',
            select_relation(Space, Module, F, Args, Selected)),
        selected_call(Selected, Module, F, Args, Out)
    ;   selected_call(original, Module, F, Args, Out)
    ).

select_relation(Space, Module, F, Args, Selected) :-
    (   length(Args, Arity),
        materialized_predicate(Module, F, Arity, Token),
        materialized_snapshot(Space, Module, Token, Stamp, Signatures)
    ->  (   validated_stamp(Space, Module, Stamp, Current)
        ->  (   Current == Stamp
            ->  true
            ;   transaction((
                    retract(materialized_snapshot(Space, Module, Token,
                                                   Stamp, Signatures)),
                    assertz(materialized_snapshot(Space, Module, Token,
                                                  Current, Signatures)) ))
            ),
            ( trie_lookup(Token, [F|Args], Result)
            -> Selected = Result ; Selected = none )
        ;   discard_space_locked(Space), Selected = original
        )
    ;   Selected = original
    ).

% One copied descriptor survives removal of its image by ordinary term life.
% [tested: a_running_reader_keeps_its_result_after_the_relation_is_removed;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
selected_call(one(Out, Count), _, _, _, Out) :-
    system:between(1, Count, _).
selected_call(original, Module, F, Args, Out) :-
    append(Args, [Out], All), Goal =.. [F|All], call(Module:Goal).

discard_space(Space) :-
    materialization_changed(Space),
    with_mutex('$metta_materialization', discard_space_locked(Space)).

discard_space_locked(Space) :-
    ( current_transaction(_) -> discard_space_rows(Space)
    ; transaction(discard_space_rows(Space)) ).

discard_space_rows(Space) :-
    forall(retract(materialized_snapshot(Space, _, Token, _, _)),
           discard_image_rows(Space, Token)).

% The caller owns both the publication lock and its transaction. Exact refs
% preserve rollback and another image's handlers even for the same function.
% [tested: materialization_dispatch, function_free_materialization;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
discard_image_rows(Space, Token) :-
    forall(retract(materialized_dispatch_ref(Token, Ref)), erase(Ref)),
    retractall(materialized_snapshot(Space, _, Token, _, _)),
    retractall(materialized_predicate(_, _, _, Token)),
    retractall(materialized_owner(_, Space, Token)).

% The channel opens with the first image instead of at load time. SWI delivers
% this event from clause garbage collection, which runs on the `gc` thread or
% on whichever thread trips the collector first, and statistics/2 counts every
% inference retired on the thread that reads it, so a callback landing on the
% main thread is charged to whatever measurement is open there. Registered at
% load time it ran over every clause any program collected, including the 322
% an engine boot collects, and made the engine's own counters
% nondeterministic: the boot case read 264,281 to 265,616 over eight samples
% with it registered that way and 265,016 eight times with this, against a
% four-inference harness band. That is this file's whole share of the spread;
% the residual excursion those eight did not show came from a different place
% and is recorded at metta_rule_gates_refresh/0
% [measured 2026-09-06; command=sh tests/shell/test_boot_inference_determinism.sh;
% fixture=engine/bench.pl boot case with the .qlf set warm; commit=001c97213388e39b14ba3789a60e59a5e2c79f41].
%
% It is registered by flush_space_materialization/2, which is the only path to
% a FIRST publication: reconcile_materialization/1 republishes an image whose
% materialized_owner/3 row it just read, so a publication came before it.
%
% EXACTLY ONCE, and that is not tidiness. A registration under a name replaces
% the handler of that name [source: SWI-Prolog 10.1.13 prolog_listen/3, the
% name(Atom) option, `swipl -g "help(prolog_listen/3)"`; commit=001c97213388e39b14ba3789a60e59a5e2c79f41], and
% replacing this one while the collector is inside it deadlocks: registering on
% every publication stopped the suite in
% a_transaction_receipt_detects_an_invisible_concurrent_addition with the
% publishing thread and the `gc` thread both in pthread_mutex_lock on one
% address, the `gc` thread's stack showing PL_call_predicate under it, and the
% main thread in pthread_join waiting for the publisher. Fifteen minutes
% against 23.4 seconds for the whole unit, and it happened whether or not the
% load-time directive was also present, so it is the run-time call and not the
% absence of the old one [measured 2026-09-06: gdb `thread apply all bt` over
% the hung process, and the same run with the directive restored beside this
% call]. The single registration this does perform runs when no handler of
% that name exists, so no delivery of it can be in flight to contend with.
%
% The flag is flag/3 rather than a clause because this is reached from inside a
% caller's transaction and a rollback must not forget that the listener is
% installed: a forgotten registration is a repeated one, which is the deadlock
% above [measured 2026-09-06: after a rolled-back transaction that set all
% three, flag/3 reads 1, the asserted clause is gone and the recorded term
% survives]. The mutex is this listener's own and the handler never takes it,
% so the two cannot invert; '$metta_materialization' could not be used here for
% exactly that reason.
%
% It is never removed: the registration is not transactional, and a publication
% still inside another thread's uncommitted transaction is invisible to any
% emptiness test a remover could run, so removing it would race a commit into
% an image nothing retires.
ensure_source_owner_listener :-
    flag(materialized_source_owner_listener, Installed, Installed),
    (   Installed == 1
    ->  true
    ;   with_mutex('$metta_materialization_listener',
                   register_source_owner_listener)
    ).

% The retirement engine is created HERE, beside the listener and under the same
% flag, and never destroyed. It cannot be created from the callback, and this
% is the reason: engine_create/3 and engine_destroy/1 both wrap their work in
% PL_set_engine(Other, &Caller), whose detach_engine() memsets the CALLING
% thread's own PL_thread_info_t.tid to zero and restores it on the way out
% [source: SWI-Prolog 10.1.13 src/pl-thread.c:7038 detach_engine, called from
% PL_set_engine at :7056 by its line :7077; '$engine_create'/3 at :4083 makes
% the pair at :4134 and :4148, and destroy_interactor at :4164 the pair at
% :4168 and :4170; commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
% thread_join/2 reads that field once, with no has_tid test, and hands it to
% pthread_timedjoin_np [source: SWI-Prolog 10.1.13 src/pl-thread.c:2898
% thread_join, its call at :2927, pthread_join_interruptible at :2873;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0], so a join landing in that
% window dereferences a null struct pthread and the process dies with
% SIGSEGV inside __pthread_clockjoin_ex. This event is delivered from clause
% garbage collection, so an engine created per collected clause made EVERY
% thread that collects inside a transaction intermittently unjoinable, through
% no act of the program running on it. Driving one standing engine with
% engine_post/3 instead goes through activate_interactor/suspend_interactor,
% which detach the ENGINE's info and never the host's [source: SWI-Prolog
% 10.1.13 src/pl-thread.c:4251 activate_interactor, :4266 suspend_interactor;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
% [measured 2026-09-06: a thread parked inside engine_destroy/1 and joined
% crashes 10 runs out of 10; parked inside engine_post/3 or engine_next/2, and
% churning engine_create/3 under a join, it joins cleanly 10 out of 10, at
% loadavg 65; command=sh tests/prolog/probes/engine_join_window.sh 10;
% fixture=tests/prolog/probes/engine_join_window.pl;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]
% [tested: a_transactional_collection_creates_no_engine_on_the_collecting_thread;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]
%
% Creating it here rather than at load time keeps a process that publishes no
% image free of it, which is the same reason the listener is registered here.
register_source_owner_listener :-
    flag(materialized_source_owner_listener, Installed, Installed),
    (   Installed == 1
    ->  true
    ;   engine_create(_, materialize:source_owner_retirement_loop, _,
                      [alias('$metta_source_owner_retirement')]),
        prolog_listen(erase, materialize:source_owner_erased,
                      [name(materialized_source_owner)]),
        flag(materialized_source_owner_listener, _, 1)
    ).

% The standing engine. Its Prolog thread holds no transaction of its own, so
% every reference it is handed is looked up in a view no caller's transaction
% can hide a row from, and its transaction/1 commits against the global
% generation rather than into a caller that may still roll back. catch/3 keeps
% one failed retirement from ending the loop; the poster re-raises.
% [tested: source_collection_inside_rollback_keeps_the_orphan_image_retired,
% a_cleanup_engine_finds_an_owner_hidden_from_the_gc_callers_snapshot;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]
source_owner_retirement_loop :-
    repeat,
      engine_fetch(Reference),
      (   catch(retire_source_owner(Reference), Error, true)
      ->  ( var(Error) -> Outcome = retired ; Outcome = raised(Error) )
      ;   Outcome = declined
      ),
      engine_yield(Outcome),
    fail.

% Clause GC emits erase before unlinking even when a DBREF_CLAUSE still owns
% the allocation. Active transaction generations postpone this event. One
% source owner therefore outlives every transaction able to publish its image.
% https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-proc.c#L1849-L1850
% [tested: an_unmanaged_stale_release_retires_its_image_at_source_collection;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
% An owner is always a clause of a space's storage predicate, so a record
% reference is never one and needs no fresh view. Nothing else about the
% reference may be asked here: this event also fires from $fixup_reconsult/1,
% and SWI 10.1.13 segfaults in $get_clause_attribute/3 when clause_property/2
% asks a clause being replaced by that reconsult for its predicate. Identity
% is the only remaining test, and a transaction can predate the owner row, so
% an apparently unrelated clause still needs the standing engine's view.
% [tested: an_unrelated_record_erasure_does_not_reach_the_retirement_engine,
% static_library_reconsult_preserves_materialized_answer_bags,
% a_cleanup_engine_finds_an_owner_hidden_from_the_gc_callers_snapshot;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]
%
% The mutex serialises posters: the engine is one shared resource and a second
% engine_post/3 while a package is pending raises a permission error. The
% engine's own goal must not take it, because the engine is a distinct Prolog
% thread on the caller's OS thread and mutex_lock/1 recurses per thread, not
% per OS thread; retire_source_owner/1 takes nothing.
source_owner_erased(Reference) :-
    (   \+ blob(Reference, clause)
    ->  true
    ;   current_transaction(_)
    ->  with_mutex('$metta_materialization',
                   retire_owner_through_engine(Reference))
    ;   materialized_owner(Reference, _, _)
    ->  with_mutex('$metta_materialization', retire_source_owner(Reference))
    ;   true
    ).

% engine_post/3 posts and resumes in one step, so the outcome the loop yields
% is this reference's own. A raised error is re-raised here, where the caller
% that tripped the collector sees it, which is where engine_next/2 used to
% deliver it.
retire_owner_through_engine(Reference) :-
    engine_post('$metta_source_owner_retirement', Reference, Outcome),
    (   Outcome == retired
    ->  true
    ;   Outcome = raised(Error)
    ->  throw(Error)
    ;   fail
    ).

% The poster owns the mutex. The standing engine supplies the fresh view when
% synchronous GC runs inside a transaction; its erasures must survive that
% caller's rollback, and reacquiring the poster's mutex would deadlock.
% [tested: source_collection_inside_rollback_keeps_the_orphan_image_retired;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]
retire_source_owner(Reference) :-
    transaction(forall(retract(materialized_owner(Reference, Space, Token)),
                       discard_image_rows(Space, Token))).

support_graph:support_invalidation_action(derived(Module, materialization)) :-
    spaces:metta_module_space(Module, Space), materialize:discard_space(Space).

default_policies(F) :-
    spaces:metta_dispatch_value(F, 'MismatchEnum', 'MismatchOriginal'),
    spaces:metta_dispatch_value(F, 'NoMatchEnum', 'NoMatchFail'),
    spaces:metta_dispatch_value(F, 'EvaluationOrderEnum', 'OrderClause'),
    spaces:metta_dispatch_value(F, 'FunctionResultEnum', 'Nondeterministic'),
    spaces:metta_dispatch_value(F, 'ClauseFailedEnum', 'ClauseFailNonDet'),
    spaces:metta_dispatch_value(F, 'OutOfClausesEnum', 'FailureOriginal').
