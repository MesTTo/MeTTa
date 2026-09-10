; Purpose: observe upstream lib_he's equation storage and space queries.
; [tested: sh test.sh examples/ch20-extending-the-engine/20-02-metta-written-in-metta/08-he_atomspace.metta; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
!(import! &self (library lib_he))

!(add-atom &self (= (addnormal) (+ 1 3)))
!(add-reduct &self (= (addreduct) (+ 1 3)))

; Upstream lib_he reduces the one-element body list and stores (4). The
; prelude's add-reduct, available without this import, stores 4 instead.
; repr observes stored syntax without evaluating it again.
!(test (repr (match &self (= (addnormal) $X) $X)) "(+ 1 3)")
!(test (repr (match &self (= (addreduct) $X) $X)) "(4)")

!(get-type 1)

(: a A)
!(test (get-type-space &self a) A)

(hello world)
!(test (unify &self (hello world) Yes No) Yes)
!(test (unify &self (hello dream) Yes No) No)
