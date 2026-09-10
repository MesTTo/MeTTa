; Purpose: prove non-eager reference admission refuses an effectful initializer.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/13-reference_loading.metta; commit=WORKTREE].
!(println! forbidden-initializer)
(= (effectful-value) 1)
