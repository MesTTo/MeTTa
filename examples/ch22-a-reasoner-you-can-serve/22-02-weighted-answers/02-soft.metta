!(import! &self (library lib_measure))
!(import! &self (library lib_soft))

;Symbol closeness: identity is 1.0, declared similarity reads both ways,
;anything else is 0.0.
(similar cat feline 0.8)
(similar dog wolf 0.7)
!(test (sym-sim cat cat) 1.0)
!(test (sym-sim cat feline) 0.8)
!(test (sym-sim feline cat) 0.8)
!(test (sym-sim cat dog) 0.0)

;Weak unification: structure crisp, symbols soft, minimum aggregation.
!(test (soft-score (likes cat fish) (likes cat fish)) 1.0)
!(test (soft-score (likes feline fish) (likes cat fish)) 0.8)
!(test (soft-score (likes feline wolf) (likes cat dog)) 0.7)
!(test (soft-score (likes cat) (likes cat fish)) 0.0)
!(test (soft-score (likes cat fish) (hates cat fish)) 0.0)
!(test (soft-score 3 3) 1.0)
!(test (soft-score 3 4) 0.0)

;A scorer does not RUN the program it is scoring: both operands are Atom, so
;an equation is compared as written. Undeclared, the call below refused with
;"* ran backwards with more than one unknown", which is correct arithmetic
;met in the wrong place, and the atoms in a space that most deserve scoring
;are its equations.
!(test (soft-score (= (likes cat $f) $body) (= (likes feline fish) tasty)) 0.8)
!(test (soft-score (likes cat (+ 1 2)) (likes feline (+ 1 2))) 0.8)

;A variable binds at degree one, and the binding is real:
!(test (soft-score $x anything) 1.0)
!(test (let $probe (soft-score (likes $who fish) (likes cat fish)) ($probe $who)) (1.0 cat))

;Soft matching over a space, feeding the measure algebra:
!(add-atom &zoo (likes cat fish))
!(add-atom &zoo (likes dog bones))
!(add-atom &zoo (likes bird seeds))
!(test (collapse (soft-match &zoo (likes feline fish) 0.5)) ((0.8 (likes cat fish))))
!(test (soft-best &zoo (likes feline fish)) (likes cat fish))
;Attention over terms: every candidate scored, softmaxed into a distribution.
;The Python value is NAMED before the family operation reads it: `car-atom`,
;`cdr-atom`, `size-atom` and `index-atom` all declare `Expression`
;parameters, so the operand reaches them AS WRITTEN.
!(test (let $answers (collapse (soft-match &zoo (likes $x $y) 0.0))
         (size-atom $answers))
       3)
!(test (< (abs-math (- (ws-total (ws-softmax (collapse (soft-match &zoo (likes feline $f) 0.0)) 1.0)) 1.0)) 1.0e-9) true)

;How the position degrees combine is a CHOICE, and the default is min, the
;fuzzy t-norm: a term is as close as its worst position. That is the right
;rule for logic and the wrong one for ranking, because one unrelated symbol
;takes an otherwise strong match to zero and a flat ordering carries no
;gradient. `dog` is nobody's declared neighbour here, so under min the two
;terms are not close at all:
!(test (soft-score (likes cat fish) (likes dog fish)) 0.0)
;Under a mean over positions the same pair keeps the two positions that DO
;agree, which is the ordering a ranker wants:
!(test (< (abs-math (- (soft-score-by mean (likes cat fish) (likes dog fish))
                       0.6666666666666666))
          1.0e-9)
       true)
!(test (soft-score-by mean (likes cat fish) (likes cat fish)) 1.0)

;The choice is a declaration in the space, Bousi~Prolog's own shape for the
;same decision, so every scorer in a program reads one atom. This one goes
;last because it changes what soft-score means for everything after it.
!(test (soft-aggregation) min)
(soft-aggregate mean)
!(test (soft-aggregation) mean)
!(test (< (abs-math (- (soft-score (likes cat fish) (likes dog fish))
                       0.6666666666666666))
          1.0e-9)
       true)
