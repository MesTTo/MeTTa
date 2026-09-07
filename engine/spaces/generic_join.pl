% Purpose: plan native cyclic conjunctions as bag-preserving Generic Join.
% Assumes: spaces consults this file; conjunct_goal/4 enumerates stored rows
% without evaluating them [source: engine/spaces/native_matching.pl, conjunct_goal/4; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Guarantees: patterns are flat and attribute-free; trie plans require finite
% ground candidate rows and emit the product of their occurrence counts;
% an empty factor proves the empty bag directly
% [tested: native_generic_join; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Owns resources: immutable Prolog terms hold one query's tries and are released
% with its stack; no cache, database entry or external handle survives the query.
% Guarantees: native_conjunction_shape/4 decides the query half of the
% admission gate without building a trie, and native_conjunction_rows_admit/3
% decides the data half through the same join_rows/5 the trie build scans, so
% (explain (match ...)) names a planned mode exactly when
% native_conjunction_answer/1 runs [tested:
% native_generic_join:the_plan_says_generic_join_exactly_when_the_planned_join_runs;
% commit=3287d4dd4928f09ce7c111d05a1c516808e226d5].
% Decides: nonempty GYO-cyclic queries use variable-at-a-time intersection;
% other nonempty shapes retain match_relational_conjuncts/5
% [tested: native_generic_join; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].

:- use_module(library(assoc), [ord_list_to_assoc/2, gen_assoc/3]).
:- use_module(library(ordsets), [ord_intersection/3, ord_subset/2]).

% Shape alone does not say which plan wins. The trie plan pays library(assoc)
% AVL lookups in Prolog where the retained nested loop pays SWI's C clause
% index, so it is ahead only when the nested loop's intermediate product is
% far larger than the output, which needs skew. It is a 64.4x win on a
% two-hub graph whose triangle bag is empty, and a 3.58x, 1.39x and 4.15x
% loss on a uniform graph, a clique and a triangle closed by a one-row
% relation. Every statistic that separates those costs a scan and a sort per
% conjunct, which is the plan's own dominant cost, so the choice is declared
% rather than inferred. Free Join's lazy column-oriented tries (Wang, Willsey
% and Suciu, SIGMOD 2023, section 5) decide it without statistics and are not
% built here.
% [measured 2026-09-05: planned 785193, 383927, 7017703 and 103672 against
% nested 50579836, 107304, 5049530 and 25000 SWI inferences;
% command=PYTHONPATH=extensions/python $VENV/bin/python -m
% benchmarks.query_planning join --family FAMILY [--control];
% fixture=two-hub at 8192, uniform at 2048, clique at 48, small-third at 2048;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
cyclic_join_planning_enabled :-
    metta_pragma('plan-cyclic-joins', Value),
    Value \== false,
    Value \== none.

% Generic Join, including bags at the leaves: Wang, Willsey and Suciu,
% Free Join, SIGMOD 2023, sections 2.1 and 2.3:
% https://arxiv.org/html/2301.10841v2#S2.SS3
% This follows the existing MeTTa.jl src/join.jl plan/descend/emit design at
% 5526d3f73f15beede118a625ce432ae5398d04f9. Exact ground Prolog keys replace
% equivalence hashes, AVL maps add a logarithmic lookup factor, and counts
% replace repeated identical rows. Backtracking emits the bag without sorting
% its output or retaining it. Query variables keep first-occurrence order.
% The admission gate has two halves and they are separated here, because a
% reader can be answered by the first alone. The QUERY half,
% native_conjunction_shape/4, is decided from the conjunct list plus the
% one-candidate probe the executor already makes: arity, flatness, incidence
% cycle, GYO cyclicity, the variable order and the column map. The DATA half,
% join_rows/5, is the finite-ground-acyclic requirement on the projected
% candidate rows, which is a property of what is stored and cannot be decided
% without reading it. The executor still pays exactly one scan per conjunct,
% because join_rows/5 IS the findall the trie is built from; explain pays that
% scan and none of the sort, the tries or the traversal.
% [measured 2026-09-07: over 2,048 stored edges the whole triangle query costs
% 237,473 SWI inferences, the shape and its relations together 95,556, the data
% half 6,442 and the query half 248, which is flat across a sixteenfold change
% in stored rows; command=PYTHONPATH=extensions/python $VENV/bin/python
% ai-tmp/aa_probe13.py; fixture=a two-out-degree ring of 1,024 nodes at
% loadavg 62; commit=3287d4dd4928f09ce7c111d05a1c516808e226d5]
%
%The query half. Nothing here builds a trie or reads a relation whole: the
%empty-factor probe stops after one candidate per conjunct and unwinds its
%bindings, which is the probe the executor already made. Failure means the
%retained nested loop, and it is the only thing that means it.
%
%It takes the whole PATTERN rather than the conjunct list, so the caller's
%only remaining guards are its own extent and the pragma; both call sites read
%cyclic_join_planning_enabled/0 themselves rather than through this, because a
%conjunctive match with planning off must not pay a frame to learn so
%[measured 2026-09-07: one frame is +1 SWI inference per conjunctive match,
%which is five over the benchmark harness's four-inference allowance on
%direct-join's five repeats; command=PYTHONPATH=extensions/python
%$VENV/bin/python ai-tmp/aa_probe16.py; fixture=a 64-edge chain, minimum of
%five; commit=3287d4dd4928f09ce7c111d05a1c516808e226d5].
native_conjunction_shape(Module, Space, Pattern, Shape) :-
    nonvar(Pattern),
    Pattern = [Comma|Conjuncts],
    Comma == ',',
    is_list(Conjuncts),
    Conjuncts = [_,_,_|_],
    acyclic_term(Conjuncts),
    term_attvars(Conjuncts, []),
    maplist(join_flat_pattern, Conjuncts),
    (   member(Factor, Conjuncts),
        conjunct_goal(Module, Space, Factor, Goal),
        \+ call(Goal)
    ->  Shape = 'empty-factor'(Factor)
    ;   join_incidence_cycle(Conjuncts),
        term_variables(Conjuncts, Vars),
        maplist(join_columns(Vars), Conjuncts, Columns, Projections),
        join_cyclic(Columns),
        Shape = 'generic-join'(Vars, Conjuncts, Columns, Projections)
    ).

%The data half, asked without building anything. explain/1 asks it so its plan
%item names the route the executor TAKES rather than the route the query shape
%allows: a space holding one non-ground row for a conjunct's relation runs the
%nested loop, and saying generic-join there would be the lie the self-honesty
%law exists to catch.
native_conjunction_rows_admit('empty-factor'(_), _, _).
native_conjunction_rows_admit('generic-join'(_, Patterns, _, Projections),
                              Module, Space) :-
    maplist(join_admissible(Module, Space), Patterns, Projections).

join_admissible(Module, Space, Pattern, Projection) :-
    join_rows(Module, Space, Pattern, Projection, _).

%The shape's own relations. An empty factor annihilates the bag before any trie
%is built, which is why it is a shape and not a relation list.
%Shape leads, so the two clauses are told apart by first-argument indexing on
%the hot path rather than by a failed head unification.
native_conjunction_relations('empty-factor'(_), _, _, join([], [rel([], leaf(0))])).
native_conjunction_relations('generic-join'(Vars, Patterns, Columns, Projections),
                             Module, Space, join(Vars, Relations)) :-
    maplist(join_relation(Module, Space),
            Patterns, Columns, Projections, Relations).

join_flat_pattern([Head|Args]) :-
    atom(Head),
    is_list(Args),
    maplist(join_flat_argument, Args).

join_flat_argument(Arg) :- var(Arg), !.
join_flat_argument(Arg) :- ground(Arg).

join_columns(Vars, Pattern, Columns, Projection) :-
    term_variables(Pattern, Local),
    join_columns(Vars, Local, 1, Columns, Projection).

join_columns([], _, _, [], []).
join_columns([V|Vars], Local, I, Columns, Projection) :-
    (   member_same_variable(V, Local)
    ->  Columns = [I|Is], Projection = [V|Values]
    ;   Columns = Is, Projection = Values
    ),
    Next is I + 1,
    join_columns(Vars, Local, Next, Is, Values).

member_same_variable(V, [X|Xs]) :-
    ( V == X -> true ; member_same_variable(V, Xs) ).

% Reject incidence forests before constructing column maps or running GYO.
% A forest is hypergraph-acyclic; its copied variables serve as disjoint-set
% representatives. An edge joining already identical representatives closes
% an incidence cycle. Only copies unify, so this test cannot bind the query.
% This keeps a long path query off GYO's repeated subset comparisons.
join_incidence_cycle(Conjuncts) :-
    maplist(term_variables, Conjuncts, Vertices),
    copy_term(Vertices, Forest),
    join_forest_cycle(Forest).

join_forest_cycle([Vertices|Forest]) :-
    join_union_vertices(Vertices, _, Cycle),
    ( Cycle == true -> true ; join_forest_cycle(Forest) ).

join_union_vertices([], _, false).
join_union_vertices([Vertex|Vertices], Root, Cycle) :-
    (   Vertex == Root
    ->  Cycle = true
    ;   Vertex = Root,
        join_union_vertices(Vertices, Root, Cycle)
    ).

% GYO removes contained edges and variables used by only one edge. A nonempty
% fixed point is cyclic. This is the admission half of MeTTa.jl's joincyclic;
% unbounded integer column lists avoid a machine-word variable-count limit.
join_cyclic(Edges) :-
    (   select(Edge, Edges, Others),
        member(Super, Others),
        ord_subset(Edge, Super)
    ->  join_cyclic(Others)
    ;   append(Edges, All),
        msort(All, Sorted),
        join_shared_columns(Sorted, Shared),
        maplist(join_prune_columns(Shared), Edges, Pruned0),
        exclude(=([]), Pruned0, Pruned),
        Pruned \== [],
        ( Pruned == Edges -> true ; join_cyclic(Pruned) )
    ).

join_shared_columns([], []).
join_shared_columns([X|Xs], Shared) :-
    join_same_prefix(Xs, X, 1, Count, Rest),
    ( Count > 1 -> Shared = [X|More] ; Shared = More ),
    join_shared_columns(Rest, More).

join_same_prefix([X|Xs], Key, N0, N, Rest) :- X == Key, !,
    N1 is N0 + 1,
    join_same_prefix(Xs, Key, N1, N, Rest).
join_same_prefix(Rest, _, N, N, Rest).

join_prune_columns(Shared, Edge, Pruned) :-
    ord_intersection(Edge, Shared, Pruned).

join_relation(Module, Space, Pattern, Columns, Projection, rel(Columns, Trie)) :-
    join_rows(Module, Space, Pattern, Projection, Rows),
    msort(Rows, Sorted),
    length(Columns, Width),
    join_trie(Width, Sorted, Trie).

%One conjunct's candidate rows, and the data half of the admission gate with
%them. The trie build and explain call this and nothing else, so neither can
%hold a different opinion about which relations the plan admits, and neither
%pays a second scan to have one.
join_rows(Module, Space, Pattern, Projection, Rows) :-
    conjunct_goal(Module, Space, Pattern, Goal),
    findall(Projection, Goal, Rows),
    ground(Rows),
    acyclic_term(Rows).

join_trie(0, Rows, leaf(Count)) :- !,
    length(Rows, Count).
join_trie(Width, Rows, node(Count, Tree)) :-
    Next is Width - 1,
    join_trie_children(Rows, Next, Children),
    length(Children, Count),
    ord_list_to_assoc(Children, Tree).

join_trie_children([], _, []).
join_trie_children([[Key|Tail]|Rows], Width, [Key-Trie|Children]) :-
    join_row_prefix(Rows, Key, Tails, Rest),
    join_trie(Width, [Tail|Tails], Trie),
    join_trie_children(Rest, Width, Children).

join_row_prefix([[Key|Tail]|Rows], Value, [Tail|Tails], Rest) :-
    Key == Value, !,
    join_row_prefix(Rows, Value, Tails, Rest).
join_row_prefix(Rest, _, [], Rest).

native_conjunction_answer(join(Vars, Relations)) :-
    join_assign(Vars, 1, Relations).

join_assign([], _, Relations) :-
    join_multiplicity(Relations, 1, Count),
    between(1, Count, _).
join_assign([Value|Vars], I, Relations) :-
    join_participants(Relations, I, Participants, Others),
    Participants = [rel(_, First)|More],
    join_smallest(More, First, node(_, Tree)),
    gen_assoc(Value, Tree, _),
    maplist(join_advance(Value), Participants, Advanced),
    append(Advanced, Others, NextRelations),
    Next is I + 1,
    join_assign(Vars, Next, NextRelations).

join_participants([], _, [], []).
join_participants([rel(Columns, Trie)|Relations], I, Participants, Others) :-
    (   Columns = [I|_]
    ->  Participants = [rel(Columns, Trie)|Ps], Others = Os
    ;   Participants = Ps, Others = [rel(Columns, Trie)|Os]
    ),
    join_participants(Relations, I, Ps, Os).

join_smallest([], Smallest, Smallest).
join_smallest([rel(_, Node)|Nodes], Current, Smallest) :-
    Node = node(N, _),
    Current = node(C, _),
    ( N < C -> Next = Node ; Next = Current ),
    join_smallest(Nodes, Next, Smallest).

join_advance(Key, rel([_|Columns], node(_, Tree)), rel(Columns, Child)) :-
    get_assoc(Key, Tree, Child).

join_multiplicity([], Count, Count).
join_multiplicity([rel([], leaf(N))|Relations], Count0, Count) :-
    Next is Count0 * N,
    join_multiplicity(Relations, Next, Count).
