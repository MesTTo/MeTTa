; Purpose: supply a separate rows-only home for background reference loading.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/13-reference_loading.metta; commit=WORKTREE].
(: background-value (-> Number Number))
(= (background-value $x) (+ $x 1))
