; Purpose: exercise every Vector head over ordinary numeric expressions.
; Guarantees: exact reductions preserve cancellation and extreme finite
; directions; construction equations can be inspected and reused as functions.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/13-vector_lib.metta; commit=c7bacead4feb29b9761d026b52b952e91b26b10b].
; A vector is an ordinary expression, so existing list operations still apply.
!(import! &self (library lib_vector))

; Dot validates equal dimensions and rounds the exact finite sum once.
!(test (dot (1.0 2.0) (3.0 4.0)) 11.0)
!(test (dot () ()) 0.0)
!(test (dot (1.0 0.0) (0.0 1.0)) 0.0)

; Norm takes the square root before rounding the exact squared sum.
!(test (norm (3.0 4.0)) 5.0)
!(test (norm (1.0 0.0)) 1.0)
!(test (norm ()) 0.0)

; Cosine measures angle: a vector and twice itself have the same direction.
!(test (cosine (1.0 0.0) (2.0 0.0)) 1.0)
!(test (cosine (1.0 0.0) (0.0 1.0)) 0.0)
!(test (cosine (1.0 0.0) (-2.0 0.0)) -1.0)

; The shortcut is dot; on unit vectors it is the cosine.
!(test (cosine-of-normalized (1.0 0.0) (1.0 0.0)) 1.0)
!(test (cosine-of-normalized (1.0 0.0) (0.0 1.0)) 0.0)
!(test (== (cosine-of-normalized (1.0 0.0) (0.6 0.8))
           (cosine (1.0 0.0) (0.6 0.8)))
       True)

; The shortcut keeps its historical behavior on nonunit inputs too.
!(test (cosine-of-normalized (3.0 4.0) (3.0 4.0)) 25.0)
!(test (cosine (3.0 4.0) (3.0 4.0)) 1.0)

; Random construction projects positive uniform draws onto the unit sphere.
; This distribution is neither Gaussian nor uniform on the sphere.
; A seed makes the examples and their measured costs reproducible.
!(test (let $v (with-seed 17 (random-normal-vector 3)) (size-atom $v)) 3)
; Each returned coordinate is rounded, so unit length has a tolerance.
!(test (let $v (with-seed 17 (random-normal-vector 5))
            (< (abs-math (- (norm $v) 1.0)) 0.000001))
       True)
!(test (let $v (with-seed 17 (random-normal-vector 4))
            (< (abs-math (- (cosine-of-normalized $v $v) 1.0)) 0.000001))
       True)

; Component arithmetic keeps exact inputs exact; division may return rationals.
!(test (vector-add (1 2) (3 4)) (4 6))
!(test (vector-subtract (3 4) (1 2)) (2 2))
!(test (vector-multiply (1 2) (3 4)) (3 8))
!(test (vector-divide (6 8) (2 4)) (3 2))
!(test (vector-scale (1 2) 3) (3 6))
!(test (vector-normalize (3 4)) (0.6 0.8))
!(test (vector-distance (1 2) (4 6)) 5.0)
!(test (vector-fill 3 7) (7 7 7))
!(test (vector-fill 0 7) ())
!(test (vector-normalize ()) ())

; Exact intermediate values retain residuals and representable small lengths.
!(test (dot (18014398509481984.0 1.0 -18014398509481984.0) (1 1 1)) 1.0)
!(test (norm (1e-300)) 1e-300)
!(test (cosine (1e308 1e308) (1e308 1e308)) 1.0)

; Zero directions keep IEEE NaN. A nonfinite norm remains observable.
!(test (isnan-math (cosine (0 0) (1 2))) True)
!(test (isinf-math (norm (1e400))) True)

; Zero draws normalize the supplied accumulator; negative counts also draw nothing.
!(test (random-normal-vector 0 (3 4)) (0.6 0.8))
!(test (random-normal-vector -2) ())

; Construction is a relation over answer streams, with inspectable equations.
!(test (collapse (vector-fill (superpose (0 2)) 7)) (() (7 7)))
!(test (let $recipe
         (match &self (= (vector-fill $count $value) $body)
           (quote (|-> ($count $value) $body)))
         (let $constructor (eval $recipe) ($constructor 3 7))) (7 7 7))
!(test (let $q (index-atom (vector-divide (1) (3)) 0)
         (vector-scale (vector-fill 3 $q) 3)) (1 1 1))
!(test (vector-fill 2 -0.0) (-0.0 -0.0))

; Invalid inputs refuse even when no values would be produced.
!(test (if-error (catch (vector-fill -1 7)) refused accepted) refused)
!(test (if-error (catch (vector-fill 0 bad)) refused accepted) refused)
!(test (if-error (catch (random-normal-vector 1.5)) refused accepted) refused)
!(test (if-error (catch (random-normal-vector 0 (bad))) refused accepted) refused)
; A literal runnable component is rejected without running it or drawing.
!(test (== (with-seed 17
             (if-error (catch (random-normal-vector 3 (quote ((random-float 0 1)))))
               (random-float 0 1) 0))
           (with-seed 17 (random-float 0 1))) True)
