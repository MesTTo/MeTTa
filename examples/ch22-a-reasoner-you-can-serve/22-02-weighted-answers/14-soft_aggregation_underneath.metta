;How lib_soft's scorer walks a term, and the one test it asks about a symbol.
;`02-soft.metta` uses `soft-score` and `soft-match`; these are the three
;operations underneath them.
!(import! &self (library lib_soft))

(similar cat feline 0.8)
(similar fish shark 0.5)

;`soft-symbol?` tests the WRITTEN representation rather than the metatype,
;and that is the whole reason it exists: since a name the engine holds a
;function for is Grounded under `get-metatype`, a metatype test would answer
;False for `min` and take the symbol similarity out of every scorer that met
;a function name.
!(test (soft-symbol? cat) True)
!(test (soft-symbol? min) True)
!(test (soft-symbol? 1) False)
!(test (soft-symbol? "text") False)
!(test (soft-symbol? (f 1)) False)

;`soft-fold` is the aggregation, dispatched on its name: two clauses, one per
;aggregation, rather than four accessors called once per position. `min` is
;the fuzzy t-norm, so a term is as close as its WORST position.
!(test (soft-fold min (cat fish) (feline fish)) 0.8)
!(test (soft-fold min (cat fish) (feline shark)) 0.5)
!(test (soft-fold min (cat fish) (dog fish)) 0.0)

;`mean` averages instead, which is the aggregation ranking wants: one
;unrelated symbol takes a strong match to zero under `min` and to a middling
;number under `mean`, and a flat ordering carries no gradient for a learned
;similarity to move.
!(test (soft-fold mean (cat fish) (feline shark)) 0.65)
!(test (soft-fold mean (cat fish) (dog fish)) 0.5)
!(test (soft-fold min (cat fish) (dog fish)) 0.0)

;`soft-walk` is the recursion each fold runs, with the accumulator exposed:
;`min` starts at 1.0 and takes minima, `mean` starts at 0.0 and SUMS, so the
;mean's division by the position count is the fold's job rather than the
;walk's.
!(test (soft-walk min (cat fish) (feline shark) 1.0) 0.5)
!(test (soft-walk mean (cat fish) (feline shark) 0.0) 1.3)
!(test (soft-fold mean (cat fish) (feline shark))
       (/ (soft-walk mean (cat fish) (feline shark) 0.0) 2))

;Which is where `min`'s early stop lives: once the accumulator is 0.0 no
;later position can raise it, so the walk stops and the positions after the
;mismatch are never scored. A `mean` has nothing to stop on and walks every
;position.
!(test (soft-walk min (dog whale otter) (cat shark seal) 1.0) 0.0)
!(test (soft-walk min (dog whale) (cat shark) 0.0) 0.0)

;Both walks over nothing answer the accumulator they were given, which is
;what makes the empty expression the fold's identity.
!(test (soft-walk min () () 1.0) 1.0)
!(test (soft-walk mean () () 0.0) 0.0)

;And the aggregation a space declares is what `soft-score` folds with, so
;these two are the same score under two readings of the same pair.
!(test (soft-score (likes cat fish) (likes feline shark)) 0.5)
(soft-aggregate mean)
!(test (soft-score (likes cat fish) (likes feline shark))
       (soft-fold mean (likes cat fish) (likes feline shark)))
