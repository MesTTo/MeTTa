; Purpose: persist independent stores, match their values and close their owners.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/42-database_lib.metta; commit=060bea3199e9f504c6d425f60841f229fc96e861].
; Owns resources: each explicit handle closes below; with-database closes its
; callback handles. The temporary directory is removed after the final check.
!(import! &self (library lib_file))
!(import! &self (library lib_database))

!(test (path-join "store" "journal.pl") "store/journal.pl")
!(bind! &work (temp-dir! "database-lib"))
!(bind! &first-path (path-join &work "first"))
!(bind! &second-path (path-join &work "second"))
!(bind! &first (database-open! &first-path none))
!(bind! &second (database-open! &second-path close))
!(test (database-query &first $value $value) ())
!(test (if-error (catch (database-open! &first-path flush)) refused fine) refused)

; A store is an ordered multiset. Removing one occurrence preserves the rest.
!(test (database-add! &first (item apple 3)) True)
!(test (database-add! &first (item pear 5)) True)
!(test (database-add! &first (item apple 3)) True)
!(test (database-query &first (item $name $price) ($name $price)) ((apple 3) (pear 5) (apple 3)))
!(test (database-query &first (item $name 3) $name) (apple apple))
!(test (database-remove! &first (item apple 3)) True)
!(test (database-query &first (item $name $price) ($name $price)) ((pear 5) (apple 3)))
!(test (database-remove! &first (item missing 0)) False)
!(test (database-query &first (missing $value) $value) ())
!(test (database-query &first (item (:= pear) $price) $price) (5))

; The second store has its own schema, journal and lock.
!(test (database-query &second $value $value) ())
!(test (database-add! &second (item banana 8)) True)
!(test (database-query &second (item $name $price) ($name $price)) ((banana 8)))
!(test (database-query &first (item $name $price) ($name $price)) ((pear 5) (apple 3)))

; Held values preserve syntax. Queries share the core numeric and gap matcher.
!(test (database-add! &first (+ 1 2)) True)
!(test (database-query &first (+ 1 $value) $value) (2))
!(test (database-add! &first (number 1)) True)
!(test (database-add! &first (number 1.0)) True)
!(test (database-query &first (number 1) hit) (hit hit))
!(test (database-remove! &first (number 1)) True)
!(test (database-query &first (number $value) $value) (1.0))
!(bind! &nul-text (string-from-codes (97 0 98)))
!(test (string-codes &nul-text) (97 0 98))
!(test (database-add! &first (text "café" &nul-text ())) True)
!(test (database-query &first (text $left $right ()) ($left $right)) (("café" &nul-text)))
!(test (database-add! &first (path a b c)) True)
!(test (database-query &first (path (:seg $left) (:seg $right)) ($left $right)) ((() (a b c)) ((a) (b c)) ((a b) (c)) ((a b c) ())))
!(test (database-add! &first ()) True)
!(test (database-query &first () empty-value) (empty-value))
!(test (if-error (catch (database-add! &first (unbound $value))) refused fine) refused)
!(test (if-error (catch (database-add! &first &second)) refused fine) refused)

; Sync flushes the journal and keeps its lifetime lock. Close releases that lock.
!(test (database-sync! &first) True)
!(test (file-exists (path-join &first-path "journal.pl")) True)
!(test (if-error (catch (database-open! &first-path close)) refused fine) refused)
!(test (database-add! &first after-sync) True)
!(test (database-close! &first) True)
!(test (database-close! &first) True)
!(test (database-close! &second) True)
!(test (if-error (catch (database-query &first $value $value)) refused fine) refused)

!(bind! &reopened (database-open! &first-path flush))
!(test (database-query &reopened (item $name $price) ($name $price)) ((pear 5) (apple 3)))
!(test (database-query &reopened (text $left $right ()) ($left $right)) (("café" &nul-text)))
!(test (database-query &reopened after-sync present) (present))
!(test (database-close! &reopened) True)

; Scopes own creation, including callbacks with many answers or no answers.
!(test (with-database &first-path flush (|-> ($store) (database-query $store (item $name $price) ($name $price)))) ((pear 5) (apple 3)))
!(test (collapse (with-database &first-path none (|-> ($store) (superpose (left right))))) (left right))
!(test (collapse (with-database &first-path none (|-> ($store) (superpose ())))) ())
!(test (if-error (catch (with-database &first-path none (|-> ($store) (database-add! $store (bad $unbound))))) refused fine) refused)
!(test (with-database &first-path close (|-> ($store) (database-close! $store))) True)
!(test (with-database &second-path close (|-> ($store) (database-query $store $value $value))) ((item banana 8)))
!(bind! &invalid-path (path-join &work "invalid"))
!(test (if-error (catch (database-open! &invalid-path invented)) refused fine) refused)
!(test (dir-exists &invalid-path) False)

; A damaged journal is refused in full, and its bytes remain available to repair.
!(bind! &bad-path (path-join &work "bad"))
!(test (with-database &bad-path close (|-> ($store) (database-add! $store original))) True)
!(bind! &journal (path-join &bad-path "journal.pl"))
!(bind! &damaged "created(0).\nassert(row(original)).\ninvented(corruption).\n")
!(test (write-file! &journal &damaged) True)
!(test (if-error (catch (database-open! &bad-path flush)) refused fine) refused)
!(test (read-file! &journal) &damaged)
!(test (delete-tree! &work) True)
