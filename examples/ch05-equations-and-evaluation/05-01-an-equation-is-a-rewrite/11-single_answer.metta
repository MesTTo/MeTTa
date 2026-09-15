;; Purpose: observe one answer while keeping its value and editable source.
;; Guarantees: a failing alternative does not add an answer; replacing the
;;   source equation changes the next observation [tested:
;;   sh test.sh examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/11-single_answer.metta;
;;   commit=eec241dcf822db6c4c1d1ecdb6092a6a9f3c7851].

(= (unique-value) 11)
(= (unique-value) (superpose ()))

!(test (eval-one (+ 1 2)) 3)
!(test (eval-one (unique-value)) 11)
!(test (eval-one (noeval (+ 2 3))) (noeval (+ 2 3)))
!(test (eval-one (noeval ())) ())

!(remove-atom &self (= (unique-value) 11))
(= (unique-value) 22)
!(test (eval-one (unique-value)) 22)
