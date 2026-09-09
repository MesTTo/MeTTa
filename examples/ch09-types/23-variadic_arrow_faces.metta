; Purpose: check each splice element at its own position and hold Atom runs.
; [tested: variadic_arrows; commit=WORKTREE]

(: vsum (-> (:seg Number) Number))
(= (vsum (:seg $ns)) (foldl-atom $ns 0 +))
!(test ((vsum) (vsum 1) (vsum 1 2) (vsum 1 2 3)) (0 1 3 6))

(: vflag Bool)
!(test ((collapse (vsum vflag 2 3))
        (collapse (vsum 1 vflag 3))
        (collapse (vsum 1 2 vflag)))
       (((Error (vsum vflag 2 3) (BadArgType 1 Number Bool)))
        ((Error (vsum 1 vflag 3) (BadArgType 2 Number Bool)))
        ((Error (vsum 1 2 vflag) (BadArgType 3 Number Bool)))))

(: vheld (-> (:seg Atom) Atom))
(= (vheld (:seg $es)) $es)
!(test (vheld) ())
!(test (vheld (+ 1 1) (+ 2 2)) (noeval ((+ 1 1) (+ 2 2))))
!(test (get-type vheld) (-> (:seg Atom) Atom))

; A fixed prefix evaluates while every element of the tail stays held.
(: mixed (-> Number (:seg Atom) Atom))
(= (mixed $n (:seg $xs)) (kept $n $xs))
!(test (mixed (+ 1 1) (+ 2 2) (+ 3 3)) (noeval (kept 2 ((+ 2 2) (+ 3 3)))))
!(test (mixed 2) (kept 2 ()))

; Fixed arrows retain the engine's overapplication exception. catch makes
; that exception a value so this cell can inspect its exact payload.
(: fixed2 (-> Number Number Number))
(= (fixed2 $a $b) (+ $a $b))
!(test (fixed2 1 2) 3)
!(test (repr (catch (fixed2 1 2 3)))
       "(Error (domain_error (function_input_arities fixed2 (2)) 3) none)")
