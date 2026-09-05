% Purpose: plan native cyclic conjunctions as bag-preserving Generic Join.
% Assumes: spaces consults this file; conjunct_goal/4 enumerates stored rows
% without evaluating them [source: engine/spaces/native_matching.pl, conjunct_goal/4; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Guarantees: patterns are flat and attribute-free; trie plans require finite
% ground candidate rows and emit the product of their occurrence counts;
% an empty factor proves the empty bag directly
% [tested: native_generic_join; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Owns resources: immutable Prolog terms hold one query's tries and are released
% with its stack; no cache, database entry or external handle survives the query.
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
native_conjunction_plan(Module, Space, Conjuncts, Plan) :-
    Conjuncts = [_,_,_|_],
    acyclic_term(Conjuncts),
    term_attvars(Conjuncts, []),
    maplist(join_flat_pattern, Conjuncts),
    (   member(Pattern, Conjuncts),
        conjunct_goal(Module, Space, Pattern, Goal),
        \+ call(Goal)
    ->  % An empty factor annihilates the bag before any trie is built.
        % Each probe stops after one candidate and unwinds its bindings.
        Plan = join([], [rel([], leaf(0))])
    ;   join_incidence_cycle(Conjuncts),
        term_variables(Conjuncts, Vars),
        maplist(join_columns(Vars), Conjuncts, Columns, Projections),
        join_cyclic(Columns),
        maplist(join_relation(Module, Space),
                Conjuncts, Columns, Projections, Relations),
        Plan = join(Vars, Relations)
    ).

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
    conjunct_goal(Module, Space, Pattern, Goal),
    findall(Projection, Goal, Rows),
    ground(Rows),
    acyclic_term(Rows),
    msort(Rows, Sorted),
    length(Columns, Width),
    join_trie(Width, Sorted, Trie).

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
