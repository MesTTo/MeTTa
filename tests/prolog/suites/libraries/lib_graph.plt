% Purpose: check every graph operation against library(ugraphs) over generated
% graphs, check the three walks against each other, and check the two refusals
% the library adds over the host: an unknown vertex and a cycle.
% Guarantees: for generated graphs each head answers exactly what the host answers
% over the same graph in its own representation, every answer that is a graph is
% in this library's representation, a vertex is reachable exactly when the closure
% holds the edge, and a topological order puts every edge's tail before its head
% [tested: lib_graph; commit=a5738e9390f2941d8f1c3207b5a28310a22e1f14].
% Owns resources: none; every value is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, nth0/3, nth1/3, numlist/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(ugraphs), [add_edges/3, add_vertices/3, del_edges/3,
                                del_vertices/3, edges/2, neighbours/3,
                                reachable/3, top_sort/2, transitive_closure/2,
                                transpose_ugraph/2, ugraph_union/3, vertices/2,
                                vertices_edges_to_ugraph/3]).
:- use_module(library(random), [random_between/3]).
:- initialization(consult('../../lib/lib_graph/lib_graph.pl')).

:- begin_tests(lib_graph).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% A random graph over five vertices, built twice from the same edges: once as this
% library's (Vertex Neighbours) expressions and once as the host's Vertex-Ns
% compounds. Five vertices and up to eight edges is dense enough that most
% graphs have a cycle and some have none.
random_graph(Graph, Ugraph) :-
    random_between(0, 8, Count),
    length(Slots, Count),
    maplist(random_edge, Slots),
    findall([From, To], member(From-To, Slots), Edges),
    vertices_edges_to_ugraph([], Slots, Ugraph),
    'graph-of'([], Edges, Graph).

random_edge(From-To) :-
    random_vertex(From), random_vertex(To).

random_vertex(Vertex) :-
    random_between(1, 5, Which),
    nth1(Which, [a, b, c, d, e], Vertex).

as_graph(Ugraph, Graph) :- maplist([V-Ns, [V, Ns]]>>true, Ugraph, Graph).

% Every head that a host predicate backs, against that predicate, over the same
% graph. This is the differential the library exists to be checked by: the
% conversion between the two representations is the only thing it adds, so a
% divergence is a conversion bug.
test(the_operations_agree_with_library_ugraphs) :-
    set_random(seed(20260912)),
    forall(between(1, 300, _),
           ( random_graph(Graph, Ugraph),
             'graph-vertices'(Graph, Vertices),
             vertices(Ugraph, ExpectedVertices), assertion(Vertices == ExpectedVertices),
             'graph-edges'(Graph, Edges),
             edges(Ugraph, ExpectedTerms),
             findall([From, To], member(From-To, ExpectedTerms), ExpectedEdges),
             assertion(Edges == ExpectedEdges),
             'graph-transpose'(Graph, Transposed),
             transpose_ugraph(Ugraph, ExpectedTransposed),
             as_graph(ExpectedTransposed, ExpectedTransposedGraph),
             assertion(Transposed == ExpectedTransposedGraph),
             'graph-closure'(Graph, Closure),
             transitive_closure(Ugraph, ExpectedClosure),
             as_graph(ExpectedClosure, ExpectedClosureGraph),
             assertion(Closure == ExpectedClosureGraph),
             'graph-union'(Graph, Transposed, Union),
             ugraph_union(Ugraph, ExpectedTransposed, ExpectedUnion),
             as_graph(ExpectedUnion, ExpectedUnionGraph),
             assertion(Union == ExpectedUnionGraph),
             forall(member(Vertex, Vertices),
                    ( 'graph-neighbours'(Graph, Vertex, Neighbours),
                      neighbours(Vertex, Ugraph, ExpectedNeighbours),
                      assertion(Neighbours == ExpectedNeighbours),
                      'graph-reachable'(Graph, Vertex, Reachable),
                      reachable(Vertex, Ugraph, ExpectedReachable),
                      assertion(Reachable == ExpectedReachable) )),
             'graph-add-vertices'(Graph, [z], Bigger),
             add_vertices(Ugraph, [z], ExpectedBigger),
             as_graph(ExpectedBigger, ExpectedBiggerGraph),
             assertion(Bigger == ExpectedBiggerGraph),
             'graph-remove-vertices'(Graph, [a], Smaller),
             del_vertices(Ugraph, [a], ExpectedSmaller),
             as_graph(ExpectedSmaller, ExpectedSmallerGraph),
             assertion(Smaller == ExpectedSmallerGraph),
             'graph-add-edges'(Graph, [[a, z]], WithEdge),
             add_edges(Ugraph, [a-z], ExpectedWithEdge),
             as_graph(ExpectedWithEdge, ExpectedWithEdgeGraph),
             assertion(WithEdge == ExpectedWithEdgeGraph),
             'graph-remove-edges'(Graph, [[a, b]], WithoutEdge),
             del_edges(Ugraph, [a-b], ExpectedWithoutEdge),
             as_graph(ExpectedWithoutEdge, ExpectedWithoutEdgeGraph),
             assertion(WithoutEdge == ExpectedWithoutEdgeGraph) )).

% Every answer that is a graph satisfies the representation this library states,
% including the condition the host leaves implicit: every neighbour is a vertex.
test(every_answer_is_a_graph) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_graph(Graph, _),
             'graph-is'(Graph, true),
             'graph-transpose'(Graph, Transposed), 'graph-is'(Transposed, true),
             'graph-closure'(Graph, Closure), 'graph-is'(Closure, true),
             'graph-union'(Graph, Transposed, Union), 'graph-is'(Union, true),
             'graph-add-vertices'(Graph, [z], Bigger), 'graph-is'(Bigger, true),
             'graph-remove-vertices'(Graph, [a], Smaller), 'graph-is'(Smaller, true),
             'graph-add-edges'(Graph, [[y, z]], WithEdge), 'graph-is'(WithEdge, true),
             'graph-remove-edges'(Graph, [[a, b]], WithoutEdge), 'graph-is'(WithoutEdge, true) )),
    % The shape check refuses the three ways a hand-written graph goes wrong: a
    % neighbour that is not a vertex, vertices out of order, and a row that is not
    % a pair.
    'graph-is'([[a, [b]]], false),
    'graph-is'([[b, []], [a, [b]]], false),
    'graph-is'([[a, []], a], false),
    'graph-is'([[a, [b, b]], [b, []]], false),
    'graph-is'([], true),
    'graph-is'(notalist, false).

% The three walks answer the same question three ways, so each one checks the
% others: a vertex is reachable from another exactly when the closure holds that
% edge or they are the same vertex, and a topological order exists exactly when no
% vertex reaches itself.
test(the_walks_agree_with_each_other) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_graph(Graph, _),
             'graph-vertices'(Graph, Vertices),
             'graph-closure'(Graph, Closure),
             forall(member(From, Vertices),
                    ( 'graph-reachable'(Graph, From, Reachable),
                      'graph-neighbours'(Closure, From, Closed),
                      forall(member(To, Vertices),
                             (   memberchk(To, Reachable)
                             ->  assertion(( To == From ; memberchk(To, Closed) ))
                             ;   assertion(\+ memberchk(To, Closed))
                             )) )),
             'graph-is-acyclic'(Graph, Acyclic),
             (   Acyclic == true
             ->  forall(member(Vertex, Vertices),
                        ( 'graph-neighbours'(Closure, Vertex, Reached),
                          assertion(\+ memberchk(Vertex, Reached)) )),
                 'graph-topological-order'(Graph, Order),
                 msort(Order, SortedOrder), assertion(SortedOrder == Vertices),
                 'graph-edges'(Graph, Edges),
                 forall(member([From2, To2], Edges),
                        ( nth0(Before, Order, From2), nth0(After, Order, To2),
                          assertion(Before < After) ))
             ;   assertion(\+ top_sort_of(Graph))
             ) )).

top_sort_of(Graph) :-
    maplist([[V, Ns], V-Ns]>>true, Graph, Ugraph),
    top_sort(Ugraph, _).

% A cycle refuses the ordering and names a vertex that reaches itself, which the
% host's top_sort/2 cannot do because it only fails.
test(a_cycle_refuses_the_ordering_and_names_a_vertex_on_it) :-
    'graph-of'([], [[a, b], [b, c], [c, a]], Loop),
    must_throw('graph-topological-order'(Loop, _),
               error(domain_error(acyclic_graph, a), _)),
    'graph-is-acyclic'(Loop, false),
    % The smallest cycle is a self-edge, and it is named as itself.
    'graph-of'([], [[x, x]], Self),
    must_throw('graph-topological-order'(Self, _),
               error(domain_error(acyclic_graph, x), _)),
    % The named vertex really is on a cycle: it reaches itself.
    'graph-closure'(Loop, Closure), 'graph-neighbours'(Closure, a, Reached),
    assertion(memberchk(a, Reached)),
    % An acyclic graph answers an order rather than raising, and the empty graph
    % is acyclic.
    'graph-of'([], [[a, b]], Line),
    'graph-topological-order'(Line, Order), assertion(Order == [a, b]),
    'graph-of'([], [], Empty),
    'graph-topological-order'(Empty, None), assertion(None == []),
    'graph-is-acyclic'(Empty, true).

% An unknown vertex is named, where the host's neighbours/3 and reachable/3
% simply fail and a caller reads the failure as an empty answer.
test(an_unknown_vertex_is_named) :-
    'graph-of'([], [[a, b]], Graph),
    must_throw('graph-neighbours'(Graph, z, _), error(existence_error(vertex, z), _)),
    must_throw('graph-reachable'(Graph, z, _), error(existence_error(vertex, z), _)),
    'graph-neighbours'(Graph, b, Sink), assertion(Sink == []),
    'graph-reachable'(Graph, b, Alone), assertion(Alone == [b]).

% Every head that takes a graph refuses a value that is not one, and the two that
% take edges name the element that is not an edge.
test(a_value_that_is_not_a_graph_is_refused_by_every_head) :-
    Bad = [[a, [b]]],
    forall(member(Goal, ['graph-vertices'(Bad, _), 'graph-edges'(Bad, _),
                         'graph-neighbours'(Bad, a, _), 'graph-transpose'(Bad, _),
                         'graph-closure'(Bad, _), 'graph-reachable'(Bad, a, _),
                         'graph-topological-order'(Bad, _), 'graph-is-acyclic'(Bad, _),
                         'graph-add-vertices'(Bad, [], _),
                         'graph-remove-vertices'(Bad, [], _),
                         'graph-add-edges'(Bad, [], _),
                         'graph-remove-edges'(Bad, [], _),
                         'graph-union'(Bad, [], _), 'graph-union'([], Bad, _)]),
           must_throw(Goal, error(type_error(graph, Bad), _))),
    forall(member(Goal, ['graph-vertices'(notalist, _), 'graph-closure'(notalist, _)]),
           must_throw(Goal, error(type_error(list, notalist), _))),
    'graph-of'([], [], Empty),
    must_throw('graph-of'([], [[a]], _), error(type_error(edge, [a]), _)),
    must_throw('graph-add-edges'(Empty, [[a, b, c]], _),
               error(type_error(edge, [a, b, c]), _)),
    must_throw('graph-of'(notalist, [], _), error(type_error(list, notalist), _)),
    must_throw('graph-of'([], notalist, _), error(type_error(list, notalist), _)).

:- end_tests(lib_graph).
