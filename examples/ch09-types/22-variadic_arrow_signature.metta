; Purpose: present an arrow's final splice at every arriving arity.
; [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7]

; Each Bool-valued effect is evaluated before do2 discards its run. The body
; returns unit, whose type is (->); printing itself returns Bool here.
(: do2 (-> (:seg Bool) (->)))
(= (do2 (:seg $args)) ())
!(test ((do2)
        (do2 (println! one))
        (do2 (println! one) (println! two))
        (do2 (println! one) (println! two) (println! three)))
       (() () () ()))
!(test (get-type do2) (-> (:seg Bool) (->)))

; An undeclared segment head still binds the same run.
(= (undeclared-do (:seg $args)) (got $args))
!(test (undeclared-do a b) (got (a b)))
!(test (undeclared-do) (got ()))
