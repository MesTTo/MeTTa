;The rest of lib_tabling: withdrawing a declaration, clearing every table at
;once, the five Prolog-facing predicates the MeTTa names are written over,
;and the escape hatch that loads Prolog source from a string.
!(import! &self (library lib_tabling))
!(import! &self (library lib_spaces))

!(add-atom &self (edge a b))
(= (reach $x $y) (match &self (edge $x $y) $y))

;A declaration installs the table, and the statistics carry the policy in
;force while it stands.
!(tabled (reach $x $y))
!(test (collapse (reach a $y)) (b))
!(test (table-stats (reach $x $y))
       ((tables 1) (answers 1) (complete-call 1) (invalidated 0) (reevaluated 0)
        (policy (incremental shared))))

;`untabled` removes the instrumentation again. The table's own counters
;survive as SWI's, and the POLICY pair is gone, because a policy is a
;property of a standing declaration rather than of a table.
!(test (untabled (reach $x $y)) True)
!(test (table-stats (reach $x $y))
       ((tables 1) (answers 0) (complete-call 1) (invalidated 0) (reevaluated 0)))

;Declaring again is the same operation and it is idempotent, so a library
;that declares on import does not fight a program that declares too.
!(test (tabled (reach $x $y)) True)
!(test (tabled (reach $x $y)) True)
!(test (index-atom (table-stats (reach $x $y)) 5)
       (policy (incremental shared)))

;`table-clear-all` abolishes every table in the process, which is the reset a
;benchmark takes between runs; `table-clear` above it is the one-function
;version.
!(test (collapse (reach a $y)) (b))
!(test (table-clear-all) True)
!(test (index-atom (table-stats (reach $x $y)) 1) (answers 0))

;Underneath, five Prolog predicates, each taking the call QUOTED because a
;tabling declaration names a call rather than making one. The MeTTa spellings
;above are one equation each over these.
!(test (metta_untabled_decl (quote (reach $x $y))) True)
!(test (metta_tabled_decl (quote (reach $x $y))) True)
!(test (collapse (reach a $y)) (b))
!(test (== (metta_table_statistics (quote (reach $x $y)))
           (table-stats (reach $x $y)))
       True)
!(test (metta_table_clear (quote (reach $x $y))) True)
!(test (index-atom (metta_table_statistics (quote (reach $x $y))) 1) (answers 0))
!(test (metta_table_clear_all) True)

;`injectPrologCode` is the expert door tabling used to ride through and no
;longer does: it loads Prolog SOURCE from a string, so a program can define a
;predicate the interop surface has no spelling for. Everything else in this
;library builds a module-qualified goal instead, which is why hyphenated and
;uppercase MeTTa names work there and would not here.
!(test (injectPrologCode "metta_doors_greeting(world).") True)
!(test (succeedsPredicate (metta_doors_greeting world)) True)
!(test (succeedsPredicate (metta_doors_greeting mars)) False)

;A clause body works the same way, so this is a whole predicate rather than a
;fact table. Chapter 20 is where the predicate surface itself is taught; this
;file only needs to show that what the string defined is really there.
!(test (injectPrologCode "metta_doors_add(X, Y) :- Y is X + 1.") True)
!(test (succeedsPredicate (metta_doors_add 41 42)) True)
!(test (succeedsPredicate (metta_doors_add 41 43)) False)
