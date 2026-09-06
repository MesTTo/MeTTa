;A lattice policy is answer subsumption: the table keeps ONE aggregated answer
;per input, joined by a function of two arguments the policy names, which is
;how a least fixpoint over a cyclic graph terminates where plain evaluation
;loops. Shortest paths are the classic case: every new route is joined with
;the one on record, and the record keeps the minimum.
;
;It is the developer's word that the function answers once per input. The
;bag semantics (every answer, every multiplicity) is deliberately set aside
;for this function, which is why the policy has to be written.

!(import! &self (library lib_tabling))

!(add-atom &self (edge a b 1))
!(add-atom &self (edge b c 1))
!(add-atom &self (edge c a 1))
!(add-atom &self (edge a c 5))

(= (shortest $p $q) (if (< $p $q) $p $q))
(= (cost $x $y) (match &self (edge $x $y $c) $c))
(= (cost $x $z) (let $c1 (cost $x $y) (match &self (edge $y $z $c2) (+ $c1 $c2))))

;plain is written on purpose. A lattice table cannot watch its reads on
;SWI-Prolog 10.1.13 (re-evaluating one answers a wrong table), so a bare
;(cache cost (lattice shortest)) over a function that reads a space is refused
;and names this spelling: the program says the table is cleared by hand after
;a write. The library chooses private for a lattice table (a shared one fails
;on its second call on this SWI), and reports both choices.
!(add-atom &metta (cache cost (plain (lattice shortest))))
!(test (table-stats (cost $x $y))
       ((tables 0) (answers 0) (complete-call 0) (invalidated 0) (reevaluated 0)
        (policy (plain private (lattice shortest)))))

;a -> b -> c is 2, cheaper than the direct edge of 5; a -> a goes round the
;cycle for 3. Without the policy the second equation of cost recurses through
;the cycle without end.
!(test (cost a c) 2)
!(test (cost a a) 3)
!(test (cost a b) 1)
!(test (sort-atom (collapse (cost a $y))) (1 2 3))

;A cheaper edge arrives. The plain table does not watch the space, exactly as
;the refusal said, so the answer stands until the table is cleared.
!(add-atom &self (edge a c 1))
!(test (cost a c) 2)
!(table-clear (cost $x $y))
!(test (cost a c) 1)
!(test (cost a a) 2)
