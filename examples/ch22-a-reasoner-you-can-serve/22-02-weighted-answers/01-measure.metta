!(import! &self (library lib_measure))

;The measure algebra over weighted alternatives: (weight value) pairs.
!(test (ws-total ((0.5 a) (0.25 b) (0.25 c))) 1.0)
!(test (ws-normalize ((2.0 a) (2.0 b))) ((0.5 a) (0.5 b)))
!(test (ws-best ((0.2 low) (0.7 high) (0.1 mid))) high)
!(test (ws-top ((0.2 low) (0.7 high) (0.1 mid)) 2) ((0.7 high) (0.2 low)))
!(test (ws-collapse ((0.3 x) (0.4 y) (0.2 x))) ((0.5 x) (0.4 y)))
!(test (ws-expect ((0.5 10) (0.5 20))) 15.0)
!(test (ws-filter ((0.9 keep) (0.05 drop)) 0.1) ((0.9 keep)))
!(test (ws-flip ((cat 0.9) (dog 0.4))) ((0.9 cat) (0.4 dog)))

;Softmax with temperature: cold sharpens toward the argmax, hot flattens.
(= (first-weight $ps) (let $head (car-atom $ps) (index-atom $head 0)))
!(test (ws-best (ws-softmax ((1.0 low) (3.0 high)) 0.1)) high)
!(test (> (first-weight (ws-softmax ((1.0 a) (3.0 b)) 0.1)) 0.0) true)
!(test (< (abs-math (- (first-weight (ws-softmax ((1.0 a) (3.0 b)) 1000.0)) 0.5)) 0.01) true)
;A softmax is a distribution whatever the temperature:
!(test (< (abs-math (- (ws-total (ws-softmax ((2.0 a) (5.0 b) (1.0 c)) 0.7)) 1.0)) 1.0e-9) true)
;And whatever the SIZE of the scores, because the peak is subtracted before
;exponentiating. The same one-unit gap answers the same distribution at 1.0,
;at 1000.0 and at -1000.0; exponentiating directly gave NaN at the top end
;and an "ws-normalize requires positive total mass" refusal at the bottom.
;Scores a network produced are exactly the ones that reach those ends.
(= (both-weights $ps) ((first-weight $ps) (first-weight (cdr-atom $ps))))
!(test (both-weights (ws-softmax ((1.0 a) (2.0 b)) 1.0))
       (both-weights (ws-softmax ((1000.0 a) (1001.0 b)) 1.0)))
!(test (both-weights (ws-softmax ((1.0 a) (2.0 b)) 1.0))
       (both-weights (ws-softmax ((-1000.0 a) (-999.0 b)) 1.0)))
!(test (ws-peak ((1.0 a) (7.0 b) (3.0 c))) 7.0)

;Sampling draws only values the superposition carries, every time:
!(test (is-member (ws-sample! ((0.5 heads) (0.5 tails))) (heads tails)) true)
!(test (ws-sample! ((1.0 sure))) sure)
!(test (is-member (ws-sample! ((0.1 a) (0.2 b) (0.7 c))) (a b c)) true)

;The nondeterministic reading: alternatives with their measure as data.
!(test (collapse (ws-choose ((0.6 yes) (0.4 no)))) ((0.6 yes) (0.4 no)))
