; Purpose: inspect engine declarations and manipulate literal code through MeTTa.
; Guarantees: exact replacements preserve topmost matches, shared variables,
; runnable syntax and every alternative [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/14-reflect_lib.metta; commit=WORKTREE].
;lib_reflect: the engine's own surface as data you can match. A tool that
;keeps its own list of what the engine knows drifts; a list the engine
;answers cannot.
!(import! &self (library lib_reflect))

(= (mine $x) $x)

;`knows?` is the guard: True or False for one name, so a query can ask before
;it calls.
!(test (knows? car-atom) True)
!(test (knows? mine) True)
!(test (knows? no-such-name-anywhere) False)

;`arity-of` answers the REGISTERED arities, one per solution, and a
;registered arity counts the answer position: `car-atom` takes one argument
;and is registered at 2.
!(test (collapse (arity-of car-atom)) (2))
!(test (collapse (arity-of cons-atom)) (3))
!(test (collapse (arity-of no-such-name-anywhere)) ())

;`origin-of` gives (origin space file line), one per defining occurrence.
;The common property reader supplies these rows, including a deferred head's
;source position. An unknown name has no origin.
!(test (once (car-atom (origin-of car-atom))) origin)
!(test (car-atom (origin-of mine)) origin)
!(test (collapse (origin-of no-such-name-anywhere)) ())

;The four enumerations. `builtins` is what is registered, `special-forms` is
;what the translator COMPILES and so appears in no registry, `functions` is
;everything, and `user-functions` is what this space defines itself. Every
;one answers a name per solution, so a tuple is a collapse.
!(test (> (size-atom (collapse (builtins))) 100) True)
!(test (> (size-atom (collapse (special-forms))) 10) True)
!(test (is-member mine (collapse (user-functions))) True)
!(test (is-member car-atom (collapse (user-functions))) False)
!(test (is-member car-atom (collapse (functions))) True)
!(test (is-member case (collapse (builtins))) False)
!(test (is-member case (collapse (special-forms))) True)
;`let` is in BOTH, which is what a name with a registered implementation and
;a compiled form looks like: the translator lowers it and the registry still
;holds it, so a tool reading only one list still finds it.
!(test (is-member let (collapse (builtins))) True)
!(test (is-member let (collapse (special-forms))) True)

;`extension-points` is the seam catalogue, one (name arity kind) per point.
;The kind is what a handler may do in it, and it is the difference between a
;seam every clause of which is read and one the first success claims.
!(test (> (size-atom (collapse (extension-points))) 3) True)
!(test (is-member (foreign_space 1 ownership) (collapse (extension-points))) True)

;`surface-counts` is the cheap health check, four pairs rather than four
;enumerations. The numbers move as libraries are imported, so what a lane
;pins is the shape.
!(test (size-atom (surface-counts)) 4)
!(test (let $counts (surface-counts) (index-atom (car-atom $counts) 0)) builtins)

;`surface-json` is the same thing as a JSON string, which is what an outside
;tool consumes. It is built here out of the accessors and lib_json, so the
;Prolog half never learns that JSON exists.
!(test (> (string-length (surface-json)) 1000) True)
!(test (string-starts-with (surface-json) "{") True)

;The enumerations have Prolog rungs imported from lib_reflect.pl. The legacy
;engine-origin door classifies implementation tiers; origin-of gives source
;origins through the common property reader.
!(test (== (collapse (engine-arity car-atom)) (collapse (arity-of car-atom))) True)
!(test (engine-knows car-atom) True)
!(test (engine-knows no-such-name-anywhere) False)
!(test (collapse (engine-origin car-atom)) ((builtin)))
!(test (== (engine-surface-counts) (surface-counts)) True)
!(test (== (size-atom (collapse (engine-builtin))) (size-atom (collapse (builtins)))) True)
!(test (== (size-atom (collapse (engine-special-form)))
           (size-atom (collapse (special-forms))))
       True)
!(test (== (size-atom (collapse (engine-function))) (size-atom (collapse (functions)))) True)
!(test (== (size-atom (collapse (engine-user-function)))
           (size-atom (collapse (user-functions))))
       True)
!(test (== (size-atom (collapse (engine-extension-point)))
           (size-atom (collapse (extension-points))))
       True)

; Terms remain literal, even when their head is executable or spells Error.
!(test (atom-replace (+ 1 2) ((1 10))) (noeval (+ 10 2)))
!(test (atom-replace (f a) (((f a) root) (a child))) root)
!(test (atom-replace (a a) ((a b) (b c))) (b b))
!(test (collapse (atom-replace (a a) ((a b) (a c)))) ((b b) (b c) (c b) (c c)))
!(test (collapse (atom-replace a ((a b) (a b)))) (b b))
!(test (atom-replace (f ()) ((f g) (() empty-value))) (g empty-value))
!(test (atom-replace () ((() (f a)))) (f a))
!(test (atom-replace (+ 1 2) ()) (noeval (+ 1 2)))
!(test (atom-replace a ((a (Error data code)))) (noeval (Error data code)))
!(test (atom-replace a ((a Empty))) (noeval Empty))
!(test (collapse (atom-replace (a a) ((a Empty) (a b))))
       (noeval ((Empty Empty) (Empty b) (b Empty) (b b))))
!(test (atom-replace (1 1.0) ((1 integer) (1.0 float))) (integer float))

; All written variables count, including binder positions. Compare identity
; inside the same expression so an alpha-renamed answer cannot pass the check.
!(test (let $vars (atom-variables ($x ($y $x) $z $y)) (== $vars (quote ($x $y $z)))) True)
!(test (let $vars (atom-variables (let $x $y (f $x $z))) (== $vars (quote ($x $y $z)))) True)
!(test (atom-variables (+ 1 2)) ())
!(test (let $changed (atom-replace ($x $y $x) (($x $z)))
         (== $changed (quote ($z $y $z)))) True)
!(test (let $kept (atom-replace (p $x) (((p $y) wrong)))
         (== $kept (quote (p $x)))) True)

; A rewrite relation can come from a Space, then ordinary matching selects it.
(reflect-rule a b)
(reflect-rule a c)
!(test (let $rules (collapse (match &self (reflect-rule $from $to) (quote ($from $to))))
         (collapse (atom-replace (h a) $rules))) ((h b) (h c)))

; Strategy's traversal is independent of exact lookup. Plans remain values;
; empty composition is identity and numeric repeat has its separate meaning.
!(test (alltd fail (+ 1 2)) (noeval (+ 1 2)))
!(test (seq (+ 1 2)) (noeval (+ 1 2)))
!(test (seq id id id (+ 1 2)) (noeval (+ 1 2)))
!(test (collapse (choice (+ 1 2))) ())
!(test (collapse (repeat 3 (noeval token))) (token token token))
!(test (if-error (catch (atom-replace a ((a)))) refused accepted) refused)

; An equation is data too. Reconstruct this library's inspection recipe as a
; function, then apply it with the caller's original variable.
!(test (let $source
         (match &self (= (atom-variables $term) $body)
           (quote (|-> ($term) $body)))
         (let $inspect (eval $source)
           (let $vars ($inspect (quote ($x $x))) (== $vars (quote ($x)))))) True)
