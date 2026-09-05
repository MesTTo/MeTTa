; Purpose: demonstrate the structural operations shared with compiled Python.
; Collapse gathers answers; let* binds shapes; case preserves ordered branches
; and distinguishes an answerless subject from ordinary pattern mismatch.

(= (alternatives) 1)
(= (alternatives) 2)
(= (alternatives) 2)
(= (collected) (collapse (alternatives)))

(= (unpack $value)
   (let* ((($left ($middle $right)) $value)) ($right $middle $left)))

(= (selected--after-yield-1) (superpose (Done)))
(= (selected $value)
   (superpose
     ((case $value
        (((Box $item) (superpose ($item (selected--after-yield-1))))
         ($_ (superpose (Miss (selected--after-yield-1)))))))))

(= (absent)
   (case (superpose ()) ((1 Unexpected) (Empty Missing))))

(= (metatype $value) (get-metatype $value))

!(test (collected) (1 2 2))
!(test (unpack (1 (2 3))) (3 2 1))
!(test (collapse (selected (Box 7))) (7 Done))
!(test (collapse (selected Other)) (Miss Done))
!(test (absent) Missing)
!(test (metatype tag) Symbol)
