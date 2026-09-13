; Purpose: compose and reflect on graph equations over relation and set expressions.
; Guarantees: variadic unions, alternative graphs and reconstructed path recipes
; retain literal vertices and variable sharing.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/25-graph_lib.metta; commit=WORKTREE].
!(import! &self (library lib_graph))

; A graph is built from its edges, each written (From To). Every vertex an edge
; mentions is a vertex; the first argument adds the ISOLATED ones, and the answer
; is a collection of (Vertex Neighbours) pairs in the standard order of terms.
!(bind! &tasks (graph-of (lunch) ((wake shower) (shower dress) (wake coffee))))
!(test &tasks ((coffee ()) (dress ()) (lunch ()) (shower (dress)) (wake (coffee shower))))
!(test (graph-of () ()) ())
!(test (graph-of (a) ()) ((a ())))

; `graph-is` asks whether a value is in that shape, which includes the condition a
; hand-written graph most often misses: every neighbour is itself a vertex.
!(test (graph-is &tasks) True)
!(test (graph-is ((a (b)))) False)
!(test (graph-is ((b ()) (a (b)))) False)
!(test (graph-is ((a ()) (b ()))) True)
!(test (graph-is 7) False)

; The vertices are a SET, so lib_sets asks about them, and the edges are a
; RELATION, so lib_pairs walks them.
!(test (graph-vertices &tasks) (coffee dress lunch shower wake))
!(test (graph-edges &tasks) ((shower dress) (wake coffee) (wake shower)))
!(test (graph-edges (graph-of () ())) ())

; The neighbours of a vertex are what it points at. A vertex the graph does not
; hold is a refusal naming it, not an empty answer that would read as a sink.
!(test (graph-neighbours &tasks wake) (coffee shower))
!(test (graph-neighbours &tasks lunch) ())
!(test (if-error (catch (graph-neighbours &tasks dinner)) refused fine) refused)

; Adding and removing. A vertex arrives with no neighbours, an edge brings its
; vertices with it, and removing a vertex removes every edge that touched it,
; which is what keeps the answer a graph.
!(test (graph-add-vertices &tasks (nap)) ((coffee ()) (dress ()) (lunch ()) (nap ()) (shower (dress)) (wake (coffee shower))))
!(test (graph-add-edges (graph-of () ()) ((a b))) ((a (b)) (b ())))
!(test (graph-remove-vertices &tasks (shower)) ((coffee ()) (dress ()) (lunch ()) (wake (coffee))))
!(test (graph-remove-edges &tasks ((wake coffee))) ((coffee ()) (dress ()) (lunch ()) (shower (dress)) (wake (shower))))
; The input is left alone by all four, as every operation here leaves its input.
!(test (graph-vertices &tasks) (coffee dress lunch shower wake))

; The transpose reverses every edge and keeps every vertex, so the union of a
; graph and its transpose is the undirected reading of it.
!(test (graph-edges (graph-transpose &tasks)) ((coffee wake) (dress shower) (shower wake)))
!(test (graph-vertices (graph-transpose &tasks)) (coffee dress lunch shower wake))
!(test (graph-edges (graph-union &tasks (graph-transpose &tasks)))
       ((coffee wake) (dress shower) (shower dress) (shower wake) (wake coffee) (wake shower)))

; The closure holds an edge for every path of one step or more, and reachability
; is the same question asked from one vertex, reflexively.
!(test (graph-edges (graph-closure &tasks))
       ((shower dress) (wake coffee) (wake dress) (wake shower)))
!(test (graph-reachable &tasks wake) (coffee dress shower wake))
!(test (graph-reachable &tasks lunch) (lunch))

; A topological order puts every edge's tail before its head, and a graph with a
; cycle has none: the refusal names a vertex that reaches itself, where the host's
; own sort would simply fail and read as no answer.
!(test (graph-topological-order &tasks) (lunch wake coffee shower dress))
!(test (graph-is-acyclic &tasks) True)
!(bind! &loop (graph-of () ((a b) (b c) (c a))))
!(test (graph-is-acyclic &loop) False)
!(test (if-error (catch (graph-topological-order &loop)) refused fine) refused)
; A self-edge is the smallest cycle there is.
!(test (graph-is-acyclic (graph-of () ((a a)))) False)
!(test (graph-reachable &loop a) (a b c))

; A value that is not a graph is refused by every head. Core assertions retain
; the invalid shape in the message.
!(test (if-error (catch (graph-vertices ((a (b))))) refused fine) refused)
!(test (if-error (catch (graph-closure 7)) refused fine) refused)
!(test (if-error (catch (graph-add-edges &tasks ((a)))) refused fine) refused)

; Union takes any number of graphs. A runtime collection supplies those
; arguments through the same apply-to used for every computed function.
!(test (graph-union) ())
!(test (graph-union &tasks) &tasks)
!(test (graph-vertices (graph-union &tasks &loop (graph-of (nap) ())))
       (a b c coffee dress lunch nap shower wake))
!(test (let $graphs (quote (&tasks &loop))
         (graph-vertices (apply-to graph-union $graphs)))
       (a b c coffee dress lunch shower wake))
!(test (collapse (graph-neighbours
                   (graph-of () (superpose (((a b)) ((a c))))) a))
       ((b) (c)))

; Variable vertices are identified by sharing, and never act as lookup wildcards.
!(test (let $graph (quote ((a ($x)) (b ()))) (graph-is $graph)) False)
!(test (let $graph (quote (($x ($y)) ($y ()))) (graph-is $graph)) True)
!(test (if-error (catch (graph-neighbours &tasks $missing)) refused fine) refused)
!(test (let $graph (graph-of (quote ($x $y)) (quote (($x $y))))
         (== $graph (quote (($x ($y)) ($y ()))))) True)
!(test (let $graph (quote (($x ($y)) ($y ())))
         (== (graph-closure $graph) $graph)) True)
!(test (graph-neighbours
         (graph-of () (quote (((+ 1 2) (Error data code))))) (quote (+ 1 2)))
       ((Error data code)))
!(test (graph-remove-vertices
         (graph-of () (quote (((+ 1 2) (Error data code))))) (quote ((+ 1 2))))
       (((Error data code) ())))
!(test (graph-is-acyclic
         (graph-of () (quote (((Error data code) (Error data code)))))) False)
; Even a vertex set spelled (Error a b) is data inside these graph recipes.
!(test (graph-reachable (graph-of () (quote ((Error a) (a b)))) Error) (Error a b))

; The path recipe is an equation in this space. Match its parameter and body,
; reconstruct the function, or specialize the graph before applying it.
!(test (let $source
         (match &self (= (graph-reachable $graph $vertex) $body)
           (quote (|-> ($graph $vertex) $body)))
         (let $walk (eval $source) ($walk &tasks wake)))
       (coffee dress shower wake))
!(test (let $graph &tasks
         (let $source
           (match &self (= (graph-reachable $graph $vertex) $body)
             (quote (|-> ($vertex) $body)))
           (let $walk (eval $source) ($walk shower))))
       (dress shower))

; Topology orders independent layers canonically, and isolated vertices belong
; to the first layer. A cycle's downstream vertex is not itself on that cycle.
!(test (graph-topological-order (graph-of (alone) ((a z) (b c)))) (a alone b c z))
!(test (graph-is-acyclic (graph-of () ((a b) (b a) (b tail)))) False)
