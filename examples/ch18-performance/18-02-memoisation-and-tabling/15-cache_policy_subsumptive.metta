;Variant tabling, the default, keeps one table per call VARIANT: (choice $x)
;and (choice a) are two calls and two tables. A subsumptive policy answers a
;more specific call from a completed more general table instead, so a program
;that asks the open question first pays for the closed ones nothing.
;
;The library chooses plain for it: a subsumptive table cannot watch its reads
;on SWI-Prolog 10.1.13, so over a body that reads a space the policy has to
;say plain itself, and this body reads none.

!(import! &self (library lib_tabling))

(= (choice $x) (superpose ((pair $x 1) (pair $x 2))))

!(add-atom &metta (cache choice subsumptive))
!(test (table-stats (choice $x))
       ((tables 0) (answers 0) (complete-call 0) (invalidated 0) (reevaluated 0)
        (policy (plain shared subsumptive))))

;The general call fills one table.
!(test (sort-atom (collapse (choice $x))) ((pair $a 1) (pair $b 2)))
!(test (table-stats (choice $x))
       ((tables 1) (answers 2) (complete-call 1) (invalidated 0) (reevaluated 0)
        (policy (plain shared subsumptive))))

;The specific call is answered out of it: the table count stays at one, where
;variant tabling would have added a second table for (choice a).
!(test (sort-atom (collapse (choice a))) ((pair a 1) (pair a 2)))
!(test (table-stats (choice $x))
       ((tables 1) (answers 2) (complete-call 2) (invalidated 0) (reevaluated 0)
        (policy (plain shared subsumptive))))
