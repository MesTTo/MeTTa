; Purpose: structured messages, topic controls and explicit capture handlers.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/34-logging_lib.metta; commit=cf6b111ffad74477d9fa7169b215379dcabe721c].
!(import! &self (library lib_logging))

; A handler takes an evaluated event expression and returns a Boolean verdict.
; Partial application supplies its capture label; add-atom supplies True.
(: record-log (-> String Expression Bool))
(= (record-log $label $event) (add-atom &log-records (captured $label $event)))

!(test (log-levels) (debug informational warning error))
!(test (log-enabled "library-example") False)
!(test (log-topics) ())
!(test (log-to! missing-handler "library-example" error (+ 1 2)) ())
!(test (log-format "library-example" debug (+ 1 2)) "library-example [debug] (+ 1 2)")
!(test (log-topic! "library-example" True) ())
!(test (log-enabled "library-example") True)
!(test (log-topics) ((log-topic "library-example" True)))

; The default door uses host printing. The explicit handler captures an event
; instead, including its unevaluated payload. All levels follow the same route.
!(test (log! "library-example" informational "hello") ())
!(test (log-to! (record-log "first") "library-example" debug (+ 1 2)) ())
!(test (match &log-records (captured "first" (log-event $topic $level $payload))
             (size-atom $payload)) 3)
!(test (match &log-records (captured "first" (log-event $topic $level $payload))
             (== (quote $payload) (quote (+ 1 2)))) True)
!(test (log-to! (record-log "second") "library-example" informational (loaded "data.csv")) ())
!(test (log-to! (|-> ($event) True) "library-example" warning (retry 2)) ())
!(test (log-to! (|-> ($event) True) "library-example" error (failed "input")) ())
!(test (size-atom (collapse (get-atoms &log-records))) 2)
!(test (log-to! (|-> ($event) False) "library-example" informational "visible") ())

; Invalid levels and handler verdicts raise. A disabled topic never applies its
; handler, but still checks the requested level. Topic names are exact Strings.
!(test (if-error (catch (log-to! (|-> ($event) 7) "library-example" debug x)) refused fine) refused)
!(test (if-error (catch (log-to! (|-> ($event) (empty)) "library-example" debug x)) refused fine) refused)
!(test (if-error (catch (log-to! missing-handler "library-example" debug x)) refused fine) refused)
!(test (if-error (catch (log! "library-example" fatal x)) refused fine) refused)
!(test (if-error (catch (log-format "library-example" fatal x)) refused fine) refused)
!(test (log-topic! "library-example" False) ())
!(test (log-enabled "library-example") False)
!(test (log-to! missing-handler "library-example" error x) ())
!(test (log-topics) ((log-topic "library-example" False)))
!(test (if-error (catch (log! "library-example" fatal x)) refused fine) refused)
!(test (log-enabled "library-example.child") False)
