;Registration, from the two engine predicates that do it. The file before
;this one registers names through `import_prolog_function` and through
;lib_import's importer; these are the two operations underneath, and the
;order they run in is the whole point.
!(import! &self (library lib_import))

(: Predicate (-> Expression %Undefined%))

;`check_prolog_function_names` asks whether a whole list of names MAY be
;registered from a source, BEFORE that source loads. It answers true or
;raises, and it never touches anything.
!(test (check_prolog_function_names (noeval (rung_fresh_one rung_fresh_two)) "example.pl")
       True)

;Asking first is not politeness, it is the only order that can work.
;Consulting a file that defines a builtin's name has already replaced the
;engine's predicate by the time a per-name refusal could fire, so a reserved
;name is refused here rather than after the damage.
!(test (let $reported (catch (check_prolog_function_names (noeval (car-atom)) "example.pl"))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(permission_error register metta_builtin car-atom)")

;The name list is written under `noeval` here, and that is not decoration: a
;name the engine already holds a function for is CALLED if the list is
;evaluated, so a list meant to be read as names has to arrive as written.
;lib_import's importer spellings get that for free, because the translator
;keeps their name list literal.
;
;It is all-or-nothing about the LIST too: a bad name anywhere in it refuses
;the whole list, so a caller never has to work out how far the loop got.
!(test (let $reported
          (catch (check_prolog_function_names (noeval (rung_fresh_one car-atom))
                                              "example.pl"))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(permission_error register metta_builtin car-atom)")

;`import_prolog_functions` is the other half: register every name, or none.
;It refuses a name with no predicate behind it, because registering one
;compiles every call to it into a partial application rather than into a
;failure a reader could see.
!(test (let $reported (catch (import_prolog_functions (noeval (rung_absent_predicate))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(existence_error procedure rung_absent_predicate)")

;With the predicates there, the same call registers them and they are MeTTa
;functions from then on.
!(import_prolog_functions_from_file "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_functions.pl" ())
!(test (import_prolog_functions (rung_double rung_greeting)) True)
!(test (rung_double 21) 42)
!(test (rung_greeting) world)

;`assertzPredicate` and `retractPredicate` are the Prolog database from
;MeTTa: assert at the END of the clause list, retract the first clause that
;unifies. Both answer a Bool, and retracting something that is not there
;answers False rather than raising.
!(test (assertzPredicate (Predicate (rung_fact a))) True)
!(test (assertzPredicate (Predicate (rung_fact b))) True)
!(test (collapse (let $t (callPredicate (Predicate (rung_fact $x))) $x)) (a b))
!(test (retractPredicate (Predicate (rung_fact a))) True)
!(test (collapse (let $t (callPredicate (Predicate (rung_fact $x))) $x)) (b))
!(test (retractPredicate (Predicate (rung_fact zzz))) False)

;`assertaPredicate` beside it asserts at the FRONT, which is the difference
;between the two and the reason both exist: clause order is answer order.
!(test (assertaPredicate (Predicate (rung_fact earliest))) True)
!(test (collapse (let $t (callPredicate (Predicate (rung_fact $x))) $x))
       (earliest b))

;`register_metta_library_path` puts a directory under an alias, so a package
;can point MeTTa at files it ships beside itself and `(library <alias> <file>)`
;resolves. It is idempotent, and a directory that is not there is refused
;where the caller can still do something about it rather than at the first
;import that needs it.
!(test (register_metta_library_path rung-alias
                                    "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures")
       True)
!(test (register_metta_library_path rung-alias
                                    "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures")
       True)
!(import! &self (library rung-alias rung_library.metta))
!(test (rung-aliased 5) 105)
!(test (let $reported (catch (register_metta_library_path rung-nowhere "./no/such/directory"))
         (unify $reported (Error $ball $context) (car-atom $ball) no-error))
       existence_error)
