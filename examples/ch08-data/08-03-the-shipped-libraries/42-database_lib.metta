; Purpose: persist metagraph syntax and derive queries and programs by matching.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/42-database_lib.metta; commit=WORKTREE].
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
!(test (database-atoms &first) ())
!(test (if-error (catch (database-open! &first-path flush)) refused fine) refused)

; A snapshot is an expression. Segments select an occurrence without evaluating
; it. The pattern and the result share variables, so projection is ordinary let.
!(test (database-add! &first (item apple 3)) True)
!(test (database-add! &first (item pear 5)) True)
!(test (database-add! &first (item apple 3)) True)
!(test (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms &first) (quote ($name $price)))) ((apple 3) (pear 5) (apple 3)))
!(test (collapse (let ((:seg $before) (item $name 3) (:seg $after))
          (database-atoms &first) (quote $name))) (apple apple))
!(test (database-remove! &first (item apple 3)) True)
!(test (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms &first) (quote ($name $price)))) ((pear 5) (apple 3)))
!(test (database-remove! &first (item missing 0)) False)
!(test (collapse (let ((:seg $before) (missing $value) (:seg $after))
          (database-atoms &first) (quote $value))) ())
!(test (collapse (let ((:seg $before) $row (:seg $after))
          (database-atoms &first)
          (let True (unify (item (:= pear) $price) $row True False) (quote $price)))) (5))

; The second store has its own schema, journal and lock.
!(test (database-atoms &second) ())
!(test (database-add! &second (item banana 8)) True)
!(test (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms &second) (quote ($name $price)))) ((banana 8)))
!(test (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms &first) (quote ($name $price)))) ((pear 5) (apple 3)))

; Held values preserve syntax. Selection uses the core numeric and gap matcher.
!(test (database-add! &first (+ 1 2)) True)
!(test (collapse (let ((:seg $before) (+ 1 $value) (:seg $after))
          (database-atoms &first) (quote $value))) (2))
!(test (database-add! &first (number 1)) True)
!(test (database-add! &first (number 1.0)) True)
!(test (collapse (let ((:seg $before) (number 1) (:seg $after))
          (database-atoms &first) (quote hit))) (hit hit))
!(test (database-remove! &first (number 1)) True)
!(test (collapse (let ((:seg $before) (number $value) (:seg $after))
          (database-atoms &first) (quote $value))) (1.0))
!(bind! &nul-text (string-from-codes (97 0 98)))
!(test (string-codes &nul-text) (97 0 98))
!(test (database-add! &first (text "café" &nul-text ())) True)
!(test (collapse (let ((:seg $before) (text $left $right ()) (:seg $after))
          (database-atoms &first) (quote ($left $right)))) (("café" &nul-text)))
!(test (database-add! &first (path a b c)) True)
!(test (collapse (let ((:seg $before) (path (:seg $left) (:seg $right)) (:seg $after))
          (database-atoms &first) (quote ($left $right)))) ((() (a b c)) ((a) (b c)) ((a b) (c)) ((a b c) ())))
!(test (database-add! &first ()) True)
!(test (collapse (let ((:seg $before) () (:seg $after))
          (database-atoms &first) (quote empty-value))) (empty-value))
!(test (database-add! &first (unbound $value)) True)
!(test (database-remove! &first (unbound $renamed)) True)
!(test (if-error (catch (database-add! &first &second)) refused fine) refused)

; Equations are stored data, including shared variables. Two alternatives can
; be inspected and reconstructed independently after reopening the journal.
!(test (database-add! &first (= (stored-twice $x) (+ $x $x))) True)
!(test (database-add! &first (= (stored-twice $x) (+ (+ $x $x) 1))) True)
!(test (collapse (match &self (= (stored-twice $x) $body) $body)) ())

; Edges can be referenced by other edges. A join is another pattern over the
; same snapshot, with shared variables connecting the two relations.
; The edge-reference model is also used by metta-examples' edges-to-edges:
; https://github.com/trueagi-io/metta-examples/blob/799ad9dbf92987cabeede6d1eca02ac7f8abb0ad/edges-to-edges/nte.metta
!(test (database-add! &first (edge e1 alice bob)) True)
!(test (database-add! &first (edge e2 bob carol)) True)
!(test (database-add! &first (supports e1 e2)) True)
!(test (let $graph (database-atoms &first)
         (collapse
           (let ((:seg $before) (supports $left $right) (:seg $after)) (quote $graph)
             (let ((:seg $a) (edge $left $source $middle) (:seg $b)) (quote $graph)
               (let ((:seg $c) (edge $right $middle $target) (:seg $d)) (quote $graph)
                 (quote ($source $middle $target))))))) ((alice bob carol)))

; Sync flushes the journal and keeps its lifetime lock. Close releases that lock.
!(test (database-sync! &first) True)
!(test (file-exists (path-join &first-path "journal.pl")) True)
!(test (if-error (catch (database-open! &first-path close)) refused fine) refused)
!(test (database-add! &first after-sync) True)
!(test (database-close! &first) True)
!(test (database-close! &first) True)
!(test (database-close! &second) True)
!(test (if-error (catch (database-atoms &first)) refused fine) refused)

!(bind! &reopened (database-open! &first-path flush))
!(test (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms &reopened) (quote ($name $price)))) ((pear 5) (apple 3)))
!(test (collapse (let ((:seg $before) (text $left $right ()) (:seg $after))
          (database-atoms &reopened) (quote ($left $right)))) (("café" &nul-text)))
!(test (collapse (let ((:seg $before) after-sync (:seg $after))
          (database-atoms &reopened) (quote present))) (present))
!(test (collapse
         (let ((:seg $before) (= (stored-twice $parameter) $body) (:seg $after))
              (database-atoms &reopened)
           (let $syntax (quote (|-> ($parameter) $body))
             (let $function (eval $syntax) ($function 7))))) (14 15))
!(test (collapse
         (let ((:seg $before) (= (stored-twice 9) $body) (:seg $after))
              (database-atoms &reopened) (eval $body))) (18 19))
!(test (collapse
         (let ((:seg $before) (= (stored-twice $parameter) $body) (:seg $after))
              (database-atoms &reopened) (is-var $parameter))) (True True))
!(test (database-remove! &reopened (= (stored-twice $fresh) (+ $fresh $fresh))) True)
!(test (collapse
         (let ((:seg $before) (= (stored-twice 4) $body) (:seg $after))
              (database-atoms &reopened) (eval $body))) (9))
!(test (database-close! &reopened) True)

; Scopes own creation, including callbacks with many answers or no answers.
!(test (with-database &first-path flush (|-> ($store) (collapse (let ((:seg $before) (item $name $price) (:seg $after))
          (database-atoms $store) (quote ($name $price)))))) ((pear 5) (apple 3)))
!(test (collapse (with-database &first-path none (|-> ($store) (superpose (left right))))) (left right))
!(test (collapse (with-database &first-path none (|-> ($store) (superpose ())))) ())
!(test (if-error (catch (with-database &first-path none (|-> ($store) (database-add! $store (bad $store))))) refused fine) refused)
!(test (with-database &first-path close (|-> ($store) (database-close! $store))) True)
!(test (with-database &second-path close (|-> ($store) (database-atoms $store))) ((item banana 8)))
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
