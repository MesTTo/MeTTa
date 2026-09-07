;lib_vector: the four operations a similarity search needs, over expressions
;of numbers. There is no vector type; a vector is an ordinary expression, so
;every list operation still applies to one.
!(import! &self (library lib_vector))

;`dot` walks both expressions together, so it is defined exactly when they
;are the same length, and the empty pair is the base case that makes the
;recursion terminate.
!(test (dot (1.0 2.0) (3.0 4.0)) 11.0)
!(test (dot () ()) 0.0)
!(test (dot (1.0 0.0) (0.0 1.0)) 0.0)

;`norm` is the dot product with itself under a square root, the Euclidean
;length.
!(test (norm (3.0 4.0)) 5.0)
!(test (norm (1.0 0.0)) 1.0)
!(test (norm ()) 0.0)

;`cosine` divides that product by both lengths, so it measures ANGLE and
;ignores magnitude: a vector and twice itself are the same direction.
!(test (cosine (1.0 0.0) (2.0 0.0)) 1.0)
!(test (cosine (1.0 0.0) (0.0 1.0)) 0.0)
!(test (cosine (1.0 0.0) (-2.0 0.0)) -1.0)

;`cosine-of-normalized` skips both divisions, because on unit vectors the
;dot product IS the cosine. It is the one to call in a loop over vectors
;that were normalised once.
!(test (cosine-of-normalized (1.0 0.0) (1.0 0.0)) 1.0)
!(test (cosine-of-normalized (1.0 0.0) (0.0 1.0)) 0.0)
!(test (== (cosine-of-normalized (1.0 0.0) (0.6 0.8))
           (cosine (1.0 0.0) (0.6 0.8)))
       True)

;It says `of-normalized` rather than checking, so a caller who has not
;normalised gets a number that is not a cosine, and that is the trade the
;name is warning about.
!(test (cosine-of-normalized (3.0 4.0) (3.0 4.0)) 25.0)
!(test (cosine (3.0 4.0) (3.0 4.0)) 1.0)

;`random-normal-vector` mints one of unit length, which is what the whole
;library is for: a random DIRECTION, the seed of a random projection or a
;random hyperplane.
!(test (let $v (random-normal-vector 3) (size-atom $v)) 3)
;Unit length up to the rounding a square root and a division leave behind,
;which is why this is a tolerance rather than an equality: the draw is random
;and the last bit of a float is not.
!(test (let $v (random-normal-vector 5)
            (< (abs-math (- (norm $v) 1.0)) 0.000001))
       True)
!(test (let $v (random-normal-vector 4)
            (< (abs-math (- (cosine-of-normalized $v $v) 1.0)) 0.000001))
       True)
