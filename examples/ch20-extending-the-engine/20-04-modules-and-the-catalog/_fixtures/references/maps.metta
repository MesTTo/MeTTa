; Purpose: supply public heads and a private helper for the reference examples.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/12-reference_maps.metta; commit=WORKTREE].
(internal map-helper)
(: map-value (-> Number Number))
(= (map-helper $x) (+ $x 1))
(= (map-value $x) (map-helper $x))
(= (map-label) label)
