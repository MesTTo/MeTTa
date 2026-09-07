;What lib_memo lets you ask and change once a function is memoized: the
;policy in force, the counters, the two ways to throw answers away, and the
;variant that stores an exact bag rather than a bounded cache.
!(import! &self (library lib_memo))

(= (sq $x) (* $x $x))

;`memoize-exact` is `memoize` with the policies that change what a function
;ANSWERS switched off: no key quantization, no aggregation, no answer limit.
;It exists so a caller can cache a function whose whole answer bag matters.
!(memoize-exact sq)
!(test (is-memoized sq) True)
!(test (sq 9) 81)
!(test (sq 9) 81)

;`get-memoize-config` reports the policy the library is running under. It
;takes no argument, because the budget it describes is one global budget
;rather than a per-function setting.
!(test (size-atom (get-memoize-config)) 6)
!(test (index-atom (car-atom (get-memoize-config)) 0) strategy)

;`get-memoize-stats` has two arities and they answer two different questions.
;With no argument it is the global hit and miss counters; with a function it
;is that function's stored entries and answers.
!(test (size-atom (get-memoize-stats)) 2)
!(test (get-memoize-stats sq) ((entries 1) (answers 1)))

;A second key adds an entry rather than replacing one, which is what makes it
;a cache of the call and not of the function.
!(test (sq 4) 16)
!(test (get-memoize-stats sq) ((entries 2) (answers 2)))

;`clear-memoize-stats` DELETES the global counters rather than zeroing them,
;so the report is empty until something is counted again, and it touches no
;cached answer: the next call is still a hit.
!(clear-memoize-stats)
!(test (get-memoize-stats) ())
!(test (sq 9) 81)
!(test (get-memoize-stats) ((cache_hit 1)))
!(test (get-memoize-stats sq) ((entries 2) (answers 2)))

;`invalidate-memoize` drops ONE function's cached answers in this space and
;leaves the decision to cache it standing, so the next call recomputes and
;caches again.
!(invalidate-memoize sq)
!(test (get-memoize-stats sq) ((entries 0) (answers 0)))
!(test (is-memoized sq) True)
!(test (sq 9) 81)
!(test (get-memoize-stats sq) ((entries 1) (answers 1)))

;`clear-memoize` is the wide one: every space's cache, because the memory
;budget it resets is global. It clears ANSWERS and not decisions either, so
;`sq` is still memoized afterwards.
!(clear-memoize)
!(test (get-memoize-stats sq) ((entries 0) (answers 0)))
!(test (is-memoized sq) True)
!(test (sq 9) 81)
!(test (get-memoize-stats sq) ((entries 1) (answers 1)))
