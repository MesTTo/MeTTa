; Purpose: demonstrate live references, defining homes and occurrence visibility.
; Guarantees: each claim runs through the stored row's public behavior
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/11-reference_rows.metta; commit=WORKTREE].

; A reference exposes definitions and their metadata. The body still calls
; its own helper, and the source's data stays in its home.
!(add-atom &reference-home (internal module-helper))
!(add-atom &reference-home (: module-helper (-> Number Number)))
!(add-atom &reference-home (= (module-helper $x) (+ $x 1)))
!(add-atom &reference-home (: module-answer (-> Number Number)))
!(add-atom &reference-home (= (module-answer $x) (module-helper $x)))
!(add-atom &reference-home (@doc module-answer (@desc "Add one at home")))
!(add-atom &reference-home (home-data kept))

(internal module-helper)
(: module-helper (-> Number Number))
(= (module-helper $x) (+ $x 100))
(from &reference-home)
!(test (module-answer 2) 3)
!(test (module-helper 2) 102)
!(test (collapse (match &self (home-data $x) $x)) ())
!(test (collapse (match &self (= (module-answer $x) $body) $body)) ())
!(test (collapse (match &self (: module-answer $type) $type)) ((-> Number Number)))

; Properties are ordinary answers. Origin keeps the defining space; a row
; added by a runnable keeps the file's ownership but has no equation line.
; Visibility permits an explicit call in the home with evalc.
!(test (case (get-property module-answer) (((visibility $v) $v))) public)
!(test (case (get-property module-helper) (((visibility $v) $v))) internal)
!(test (case (get-property module-answer) (((origin $home $file $line) ($home $line))))
       (&reference-home -1))
!(test (evalc (module-helper 2) &reference-home) 3)

; The standing row follows later heads. Two equal source equations remain
; two answers, and removing one occurrence leaves the other.
!(add-atom &reference-home (= (module-later) 9))
!(add-atom &reference-home (= (module-later) 9))
!(test (collapse (module-later)) (9 9))
!(subtract-atom &reference-home (= (module-later) 9))
!(test (collapse (module-later)) (9))

; Removing the reference withdraws its definitions and copied metadata.
!(remove-atom &self (from &reference-home))
!(test (collapse (module-answer 2)) ((module-answer 2)))
!(test (collapse (match &self (: module-answer $type) $type)) ())
