;A (cache Name Policy) row in &metta says HOW a function is tabled, in the
;engine's own words: the cache-policy vocabulary is SWI-Prolog's table option
;list spelled as MeTTa symbols, and the row installs the table by itself, for
;every arity the name is defined at, now or when its equations arrive.
;
;The policy here is monotonic. An incremental table (the default a bare
;(tabled ...) builds) is INVALIDATED by a write to a space it reads and
;re-evaluated from scratch on the next call. A monotonic table takes the write
;and propagates only its consequences, so an add-atom costs the new answers it
;implies and the next call is a read. The price is a promise: the body must be
;monotonic, no absence turned into an answer, because a retraction the body
;relied on is what re-evaluation exists for.

!(import! &self (library lib_tabling))

!(add-atom &self (link a b))
(= (connected $x $y) (match &self (link $x $y) $y))
(= (connected $x $z) (let $y (connected $x $y) (match &self (link $y $z) $z)))

!(add-atom &metta (cache connected monotonic))

;table-stats reports the policy in force beside its counters: the watch, the
;thread word the library chose, and every further word the table carries.
!(test (table-stats (connected $x $y))
       ((tables 0) (answers 0) (complete-call 0) (invalidated 0) (reevaluated 0)
        (policy (monotonic shared))))

!(test (sort-atom (collapse (connected a $y))) (b))
!(test (table-stats (connected $x $y))
       ((tables 1) (answers 1) (complete-call 1) (invalidated 0) (reevaluated 0)
        (policy (monotonic shared))))

;--------------------------------------------- the write propagates, nobody calls
;The new consequence is in the table BEFORE the next call, and the table was
;never invalidated. Under the incremental policy the same write reads
;(answers 1) (invalidated 1) here, and the answer arrives with the next call's
;re-evaluation (12-tabling_statistics.metta shows that pair).
!(add-atom &self (link b c))
!(test (table-stats (connected $x $y))
       ((tables 1) (answers 2) (complete-call 1) (invalidated 0) (reevaluated 0)
        (policy (monotonic shared))))

!(test (sort-atom (collapse (connected a $y))) (b c))

;A retraction is what monotonic tabling cannot propagate, so SWI falls back
;to invalidation and re-evaluation for it, and the answers stay right.
!(remove-atom &self (link b c))
!(test (sort-atom (collapse (connected a $y))) (b))

;The row is the declaration. Removing it takes the table with it and releases
;the watch on the space: the (tabled ...) row this library reflects is gone.
;connected is left-recursive, so it terminated BECAUSE it was tabled; a
;program that removes the row it relied on for termination has taken the
;termination away with it, which is why nothing calls it after this line.
!(remove-atom &metta (cache connected monotonic))
!(test (collapse (match &metta (tabled $s connected $a) $a)) ())
