; Purpose: exercise strategy application, traversal and exact type selection.
; Guarantees: a subject with no matching type declines the typed strategy
; [tested: examples/ch20-extending-the-engine/20-02-metta-written-in-metta/13-strategy_internals.metta; commit=505ce25b9384e782afa26f621527d4b1fd695924].

;lib_strategy from the inside. The file before this one uses the combinators;
;these are the application, traversal and type operations they use, and they are ordinary
;functions rather than a hidden layer, which is the library's whole claim:
;applying a strategy lowers to a MeTTa call and never installs a host
;callback.
!(import! &self (library lib_strategy))

(= (mark $x) (marked $x))

;`strategy-eval` is application itself: a strategy value and a term, answering
;what the strategy answers. Every combinator bottoms out here.
!(test (strategy-eval mark a) (marked a))
!(test (strategy-eval id a) a)
!(test (== (strategy-eval mark a) (strategy-apply mark a)) True)

; Runtime strategy collections use the same first-nonempty-bag rule as choice.
!(test (strategy-choice-tail (fail id mark) (+ 1 2)) (noeval (+ 1 2)))
!(test (collapse (strategy-choice-tail () a)) ())

;`strategy-all` is `all`: the strategy at every immediate child, including
;the written expression head, because a head is a child in MeTTa's flat term
;model. A leaf and the empty expression are identities.
!(test (strategy-all mark (h a b)) ((marked h) (marked a) (marked b)))
!(test (strategy-all mark leaf) leaf)
!(test (strategy-all mark ()) ())

;`strategy-all-tail` maps the strategy over an expression through map-atom.
;It is the expression-only operation under strategy-all, so a leaf has no
;answer here where strategy-all answers that leaf unchanged.
!(test (strategy-all-tail mark (a b)) ((marked a) (marked b)))
!(test (strategy-all-tail mark ()) ())
!(test (== (strategy-all-tail mark (a b))
           (cdr-atom (strategy-all mark (h a b))))
       True)
!(test (collapse (strategy-all-tail mark leaf)) ())
!(test (strategy-all mark leaf) leaf)

;`strategy-one` is `one`: every successful single-child rewrite, left to
;right, as separate answers rather than one term with every child rewritten.
!(test (collapse (strategy-one mark (h a)))
       (((marked h) a) (h (marked a))))
!(test (collapse (strategy-one mark leaf)) ())

;The three typed operations under `◁`. A type-preserving strategy is one
;whose arrow has the same sort on both sides, and `strategy-typed-tp` finds
;that sort by MATCHING the declaration rather than by asking for a type.
(: DA Type)
(: DS Type)
(: da DA)
(: preserve (-> DA DA))
(= (preserve $x) (kept $x))
!(test (strategy-typed-tp preserve da) (kept da))
!(test (collapse (strategy-typed-tp preserve 1)) ())

;`strategy-typed-tu` takes the RESULT sort instead, which is the type-unifying
;scheme: any arrow whose output is the sort asked for.
(: summarize (-> DA DS))
(= (summarize $x) (sum $x))
!(test (strategy-typed-tu summarize DS da) (sum da))
!(test (collapse (strategy-typed-tu summarize DA da)) ())

;Both then hand the sort they selected to `strategy-typed-apply`, which is
;the type check: the term's type against the expected one, and the strategy
;runs only if they are identical under the upstream-compatible match-types.
!(test (strategy-typed-apply preserve DA da) (kept da))
!(test (collapse (strategy-typed-apply preserve DA 1)) ())
!(test (== (strategy-typed-apply preserve DA da) (◁ preserve TP da)) True)

;An undeclared subject has no type identical to DA, so it declines too.
!(test (collapse (strategy-typed-apply preserve DA (undeclared-name))) ())
