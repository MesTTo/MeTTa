% Purpose: compare graph equations with independent graph models and identity laws.
% Guarantees: ground models cover every operation, while literal terms, variables,
% alternative answers and reflected recipes exercise the public MeTTa contract.
% [tested: lib_graph; commit=2951a00d660131f008c2779be828c97f53aa1555].
% Owns resources: none; graph values and model state are local terms.

:- use_module(collection_test_support).
:- use_module(library(lists), [append/3, member/2, memberchk/2, nth0/3, nth1/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(ugraphs), [add_edges/3, add_vertices/3, del_edges/3,
                                del_vertices/3, edges/2, neighbours/3,
                                reachable/3, top_sort/2, transitive_closure/2,
                                transpose_ugraph/2, ugraph_union/3, vertices/2,
                                vertices_edges_to_ugraph/3]).
:- use_module(library(random), [random_between/3]).
:- load_collection_library(lib_graph).

:- begin_tests(lib_graph).

% A refused unknown vertex or cycle must carry the named value in its payload.
must_name(Goal, Message) :-
    catch(invoke(Goal), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_assertion_failed(
        [assertEqualMsg,_,_,[quote,Message]],_,_),_)).

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
    invoke('graph-of'([], Edges, Graph)).

random_edge(From-To) :-
    random_vertex(From), random_vertex(To).

random_vertex(Vertex) :-
    random_between(1, 5, Which),
    nth1(Which, [a, b, c, d, e], Vertex).

as_graph(Ugraph, Graph) :- maplist([V-Ns, [V, Ns]]>>true, Ugraph, Graph).

% The host algorithms independently check the MeTTa derivations over ground
% graphs. Variable identity has separate cases because native unification is
% not the contract of the expression library.
test(the_operations_agree_with_library_ugraphs) :-
    set_random(seed(20260912)),
    forall(between(1,300,_),
           (random_graph(Graph,Ugraph),check_graph_operations(Graph,Ugraph))).

check_graph_operations(Graph,Ugraph) :-
    invoke('graph-vertices'(Graph, Vertices)),
    vertices(Ugraph, ExpectedVertices), assertion(Vertices == ExpectedVertices),
    invoke('graph-edges'(Graph, Edges)),
    edges(Ugraph, ExpectedTerms),
    findall([From, To], member(From-To, ExpectedTerms), ExpectedEdges),
    assertion(Edges == ExpectedEdges),
    invoke('graph-transpose'(Graph, Transposed)),
    transpose_ugraph(Ugraph, ExpectedTransposed),
    as_graph(ExpectedTransposed, ExpectedTransposedGraph),
    assertion(Transposed == ExpectedTransposedGraph),
    invoke('graph-closure'(Graph, Closure)),
    transitive_closure(Ugraph, ExpectedClosure),
    as_graph(ExpectedClosure, ExpectedClosureGraph),
    assertion(Closure == ExpectedClosureGraph),
    invoke('graph-union'(Graph, Transposed, Union)),
    ugraph_union(Ugraph, ExpectedTransposed, ExpectedUnion),
    as_graph(ExpectedUnion, ExpectedUnionGraph),
    assertion(Union == ExpectedUnionGraph),
    forall(member(Vertex, Vertices),
           ( invoke('graph-neighbours'(Graph, Vertex, Neighbours)),
             neighbours(Vertex, Ugraph, ExpectedNeighbours),
             assertion(Neighbours == ExpectedNeighbours),
             invoke('graph-reachable'(Graph, Vertex, Reachable)),
             reachable(Vertex, Ugraph, ExpectedReachable),
             assertion(Reachable == ExpectedReachable) )),
    invoke('graph-add-vertices'(Graph, [z], Bigger)),
    add_vertices(Ugraph, [z], ExpectedBigger),
    as_graph(ExpectedBigger, ExpectedBiggerGraph),
    assertion(Bigger == ExpectedBiggerGraph),
    invoke('graph-remove-vertices'(Graph, [a], Smaller)),
    del_vertices(Ugraph, [a], ExpectedSmaller),
    as_graph(ExpectedSmaller, ExpectedSmallerGraph),
    assertion(Smaller == ExpectedSmallerGraph),
    invoke('graph-add-edges'(Graph, [[a, z]], WithEdge)),
    add_edges(Ugraph, [a-z], ExpectedWithEdge),
    as_graph(ExpectedWithEdge, ExpectedWithEdgeGraph),
    assertion(WithEdge == ExpectedWithEdgeGraph),
    invoke('graph-remove-edges'(Graph, [[a, b]], WithoutEdge)),
    del_edges(Ugraph, [a-b], ExpectedWithoutEdge),
    as_graph(ExpectedWithoutEdge, ExpectedWithoutEdgeGraph),
    assertion(WithoutEdge == ExpectedWithoutEdgeGraph).

% Every answer that is a graph satisfies the representation this library states,
% including the condition the host leaves implicit: every neighbour is a vertex.
test(every_answer_is_a_graph) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_graph(Graph, _),
             invoke('graph-is'(Graph, true)),
             invoke('graph-transpose'(Graph, Transposed)), invoke('graph-is'(Transposed, true)),
             invoke('graph-closure'(Graph, Closure)), invoke('graph-is'(Closure, true)),
             invoke('graph-union'(Graph, Transposed, Union)), invoke('graph-is'(Union, true)),
             invoke('graph-add-vertices'(Graph, [z], Bigger)), invoke('graph-is'(Bigger, true)),
             invoke('graph-remove-vertices'(Graph, [a], Smaller)), invoke('graph-is'(Smaller, true)),
             invoke('graph-add-edges'(Graph, [[y, z]], WithEdge)), invoke('graph-is'(WithEdge, true)),
             invoke('graph-remove-edges'(Graph, [[a, b]], WithoutEdge)), invoke('graph-is'(WithoutEdge, true)) )),
    % The shape check refuses the three ways a hand-written graph goes wrong: a
    % neighbour that is not a vertex, vertices out of order, and a row that is not
    % a pair.
    invoke('graph-is'([[a, [b]]], false)),
    invoke('graph-is'([[b, []], [a, [b]]], false)),
    invoke('graph-is'([[a, []], a], false)),
    invoke('graph-is'([[a, [b, b]], [b, []]], false)),
    invoke('graph-is'([], true)),
    invoke('graph-is'(notalist, false)).

% The three walks answer the same question three ways, so each one checks the
% others: a vertex is reachable from another exactly when the closure holds that
% edge or they are the same vertex, and a topological order exists exactly when no
% vertex reaches itself.
test(the_walks_agree_with_each_other) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_graph(Graph, _),
             invoke('graph-vertices'(Graph, Vertices)),
             invoke('graph-closure'(Graph, Closure)),
             forall(member(From, Vertices),
                    ( invoke('graph-reachable'(Graph, From, Reachable)),
                      invoke('graph-neighbours'(Closure, From, Closed)),
                      forall(member(To, Vertices),
                             (   memberchk(To, Reachable)
                             ->  assertion(( To == From ; memberchk(To, Closed) ))
                             ;   assertion(\+ memberchk(To, Closed))
                             )) )),
             invoke('graph-is-acyclic'(Graph, Acyclic)),
             (   Acyclic == true
             ->  forall(member(Vertex, Vertices),
                        ( invoke('graph-neighbours'(Closure, Vertex, Reached)),
                          assertion(\+ memberchk(Vertex, Reached)) )),
                 invoke('graph-topological-order'(Graph, Order)),
                 msort(Order, SortedOrder), assertion(SortedOrder == Vertices),
                 invoke('graph-edges'(Graph, Edges)),
                 forall(member([From2, To2], Edges),
                        ( nth0(Before, Order, From2), nth0(After, Order, To2),
                          assertion(Before < After) ))
             ;   assertion(\+ top_sort_of(Graph))
             ) )).

top_sort_of(Graph) :-
    maplist([[V, Ns], V-Ns]>>true, Graph, Ugraph),
    top_sort(Ugraph, _).

test(a_cycle_refuses_the_ordering_and_names_a_vertex_on_it) :-
    invoke('graph-of'([],[[a,b],[b,c],[c,a]],Loop)),
    must_name('graph-topological-order'(Loop,_),['cyclic-graph',a]),
    invoke('graph-is-acyclic'(Loop,false)),
    invoke('graph-of'([],[[x,x]],Self)),
    must_name('graph-topological-order'(Self,_),['cyclic-graph',x]),
    % a is blocked downstream, but only x and y lie on the cycle.
    invoke('graph-of'([],[[x,y],[y,x],[y,a]],Blocked)),
    must_name('graph-topological-order'(Blocked,_),['cyclic-graph',x]),
    invoke('graph-closure'(Loop,Closure)),invoke('graph-neighbours'(Closure,a,Reached)),
    assertion(memberchk(a,Reached)),
    invoke('graph-of'([],[[a,b]],Line)),
    invoke('graph-topological-order'(Line,[a,b])),
    invoke('graph-topological-order'([],[])),invoke('graph-is-acyclic'([],true)).

test(an_unknown_vertex_is_named_without_binding_it) :-
    invoke('graph-of'([],[[a,b]],Graph)),
    must_name('graph-neighbours'(Graph,z,_),['unknown-vertex',z]),
    must_name('graph-reachable'(Graph,z,_),['unknown-vertex',z]),
    must_name('graph-neighbours'(Graph,Unknown,_),['unknown-vertex',_]),
    assertion(var(Unknown)),
    invoke('graph-neighbours'(Graph,b,[])),
    invoke('graph-reachable'(Graph,b,[b])).

test(a_value_that_is_not_a_graph_is_refused_by_every_head) :-
    Bad=[[a,[b]]],
    forall(member(Goal,['graph-vertices'(Bad,_),'graph-edges'(Bad,_),
                        'graph-neighbours'(Bad,a,_),'graph-transpose'(Bad,_),
                        'graph-closure'(Bad,_),'graph-reachable'(Bad,a,_),
                        'graph-topological-order'(Bad,_),'graph-is-acyclic'(Bad,_),
                        'graph-add-vertices'(Bad,[],_),'graph-remove-vertices'(Bad,[],_),
                        'graph-add-edges'(Bad,[],_),'graph-remove-edges'(Bad,[],_),
                        'graph-union'(Bad,[],_),'graph-union'([],Bad,_),
                        'graph-vertices'(notalist,_),'graph-closure'(notalist,_),
                        'graph-of'([],[[a]],_),'graph-add-edges'([],[[a,b,c]],_),
                        'graph-remove-edges'([],[[a]],_),
                        'graph-of'(notalist,[],_),'graph-of'([],notalist,_)]),
           refused(Goal)),
    eval_expr(['if-error',[catch,['graph-of',[],[[id,b]]]],refused,accepted],refused),
    invoke('graph-of'([],[[id,b]],Quoted)),
    invoke('graph-vertices'(Quoted,[b,id])),
    invoke('graph-of'([],[["id",b]],String)),
    invoke('graph-vertices'(String,["id",b])).

test(variable_vertices_keep_identity_through_every_graph_operation) :-
    invoke('graph-of'([X,Y],[[X,Y]],Graph)),
    assertion(Graph == [[X,[Y]],[Y,[]]]),
    invoke('graph-is'(Graph,true)),invoke('graph-vertices'(Graph,Vertices)),
    assertion(Vertices == [X,Y]),
    invoke('graph-neighbours'(Graph,X,Neighbours)),assertion(Neighbours == [Y]),
    invoke('graph-reachable'(Graph,X,Reachable)),assertion(Reachable == [X,Y]),
    invoke('graph-closure'(Graph,Closure)),assertion(Closure == Graph),
    invoke('graph-transpose'(Graph,Transpose)),
    assertion(Transpose == [[X,[]],[Y,[X]]]),
    invoke('graph-remove-vertices'(Graph,[Unknown],Untouched)),
    assertion(var(Unknown)),assertion(Untouched == Graph),
    invoke('graph-remove-vertices'(Graph,[X],OnlyY)),assertion(OnlyY == [[Y,[]]]),
    invoke('graph-remove-edges'(Graph,[[X,Y]],NoEdges)),
    assertion(NoEdges == [[X,[]],[Y,[]]]),
    invoke('graph-topological-order'(Graph,Order)),assertion(Order == [X,Y]),
    assertion(var(X)),assertion(var(Y)),assertion(X \== Y).

test(graph_shape_rejects_unshared_variable_neighbours) :-
    invoke('graph-is'([[a,[Unknown]],[b,[]]],false)),assertion(var(Unknown)),
    invoke('graph-is'([[X,[Y]],[Y,[]]],true)),
    invoke('graph-is'([[X,[Fresh]],[Y,[]]],false)),
    assertion(var(Fresh)),assertion(Fresh \== X),assertion(Fresh \== Y),
    invoke('graph-is'([Unknown],false)),assertion(var(Unknown)),
    invoke('graph-is'([[a,Unknown]],false)),assertion(var(Unknown)),
    invoke('graph-is'(Unknown,false)),assertion(var(Unknown)).

test(literal_and_numeric_vertex_kinds_remain_distinct) :-
    invoke('graph-of'([1,1.0],[[1,1.0]],Graph)),
    invoke('graph-vertices'(Graph,Vertices)),length(Vertices,2),
    invoke('graph-neighbours'(Graph,1,Neighbours)),assertion(Neighbours == [1.0]),
    invoke('graph-neighbours'(Graph,1.0,[])),
    Literal=['+',1,2],Error=['Error',data,code],
    invoke('graph-of'([],[ [Literal,Error] ],Runnable)),
    invoke('graph-neighbours'(Runnable,Literal,Actual)),assertion(Actual == [Error]),
    invoke('graph-edges'(Runnable,Edges)),assertion(Edges == [[Literal,Error]]).

% The same independent oracle covers vertices and vertex sets that look like
% runnable calls or Error values. No operation may confuse those with effects.
test(literal_vertex_graphs_match_the_independent_ground_oracle) :-
    forall((member(Labels,[['Error',a,b],[['Error',a,b],['+',1,2],done],[1,1.0,"1"]]),
            member(Indices,[[],[0-1,0-2],[0-1,1-2],[0-1,1-0],[0-0,1-2],[0-1,0-1]])),
        (findall(A-B,(member(I-J,Indices),nth0(I,Labels,A),nth0(J,Labels,B)),Terms),
         findall([A,B],member(A-B,Terms),Edges),
         vertices_edges_to_ugraph(Labels,Terms,Ugraph),as_graph(Ugraph,Expected),
         invoke('graph-of'(Labels,Edges,Graph)),assertion(Graph==Expected),
         check_graph_operations(Graph,Ugraph))),
    Error=['Error',data,code],
    invoke('graph-is-acyclic'([[Error,[Error]]],false)),
    must_name('graph-topological-order'([[Error,[Error]]],_),['cyclic-graph',Error]).

test(union_accepts_zero_one_and_arbitrarily_many_graphs) :-
    invoke('graph-union'([])),
    invoke('graph-of'([a],[],Graph)),invoke('graph-union'(Graph,Graph)),
    forall(between(0,24,Count),
        (length(Graphs,Count),maplist(=(Graph),Graphs),
         append(Graphs,[Answer],GraphsWithAnswer),
         Goal=..['graph-union'|GraphsWithAnswer],
         invoke(Goal),
         (Count=:=0 -> assertion(Answer==[]) ; assertion(Answer==Graph)))),
    invoke('graph-of'([] ,[[a,b]],Left)),invoke('graph-of'([],[[b,c]],Right)),
    invoke('graph-union'(Left,Right,Left,[[a,[b]],[b,[c]],[c,[]]])).

test(alternative_graphs_remain_alternative_answers) :-
    findall(Neighbours,
        eval_expr(['graph-neighbours',
                    ['graph-of',[],[superpose,[[[a,b]],[[a,c]]]]],a],Neighbours),
        Answers),
    assertion(Answers == [[b],[c]]).

test(path_equations_reconstruct_and_specialize) :-
    once(eval_expr([let,Source,
        [match,'&self',['=',['graph-reachable',Graph,Vertex],Body],
         [quote,['|->',[Graph,Vertex],Body]]],
        [let,Walk,[eval,Source],[Walk,['graph-of',[],[[a,b],[b,c]]],a]]],
        [a,b,c])),
    once(eval_expr([let,Specialized,
        [match,'&self',['=',['graph-reachable',[[a,[b]],[b,[c]],[c,[]]],V],B],
         [quote,['|->',[V],B]]],
        [let,Run,[eval,Specialized],[Run,b]]],[b,c])).

test(topological_layers_have_canonical_order) :-
    invoke('graph-of'([alone],[[a,z],[b,c]],Graph)),
    invoke('graph-topological-order'(Graph,[a,alone,b,c,z])),
    invoke('graph-of'([a,b,c,d],[],Isolated)),
    invoke('graph-topological-order'(Isolated,[a,b,c,d])).

:- end_tests(lib_graph).
