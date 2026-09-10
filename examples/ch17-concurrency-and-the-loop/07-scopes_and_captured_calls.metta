; Purpose: join child work, release local resources and carry a call's space.
; Guarantees: scope preserves answer multiplicity, joins children before
; answering and releases unreturned spaces; capture holds a call with its home.
; [tested: examples/ch17-concurrency-and-the-loop/07-scopes_and_captured_calls.metta; commit=WORKTREE]
; Owns resources: outer scopes release the channels, temporary spaces and
; captured homes used below; a returned inner space transfers to its outer scope.

!(import! &self (library lib_thread))

;A scope finishes its body and children before replaying every body answer.
;Duplicate answers stay duplicate; no answers stay absent. Collapse makes
;absence an explicit value that the assertion can check.
!(test (collapse (scope (superpose (1 1 2)))) (1 1 2))
!(test (collapse (scope (superpose ()))) ())

;The equation (scope $body) delegates to (scope_body $body). The longhand
;has the same held argument and preserves the same answer multiplicity.
!(test (collapse (scope_body (superpose (3 3 4)))) (3 3 4))

;The inner scope joins both sends without an explicit await. Only then do
;the non-blocking receives run. Sorting allows either arrival order.
;The outer scope owns and closes the mailbox after the answers are read.
!(test
  (collapse
    (scope
      (let $mail (channel)
        (progn
          (scope (progn (spawn (send $mail 1))
                        (spawn (send $mail 2)) joined))
          (msort ((try-recv $mail) (try-recv $mail)))))))
  ((1 2)))

;A space first created in the body belongs to that scope. Returning a
;different value releases it; its old name then refuses access.
!(test
  (collapse (scope (progn (add-atom &scope-transient (item one)) finished)))
  (finished))
!(test (if-error (catch (get-atoms &scope-transient)) released live) released)

;Returning a space transfers it to the enclosing scope. It remains writable
;there and is released when that outer scope returns the ordinary item list.
!(test
  (collapse
    (scope
      (let $kept (scope (new-space))
        (progn (add-atom $kept (item retained)) (collapse (get-atoms $kept))))))
  (((item retained))))

;Capture answers an (evalc expression space) value. It holds the expression,
;so changing its home after capture changes the eventual answer. Evaluating
;the value from the right-hand home still calls the left-hand definition.
!(test
  (collapse
    (scope
      (progn
        (import! &captured-left (library lib_thread))
        (import! &captured-right (library lib_thread))
        (add-atom &captured-left (= (home) left))
        (add-atom &captured-right (= (home) right))
        (let $held (evalc (capture (home)) &captured-left)
          (progn
            (remove-atom &captured-left (= (home) left))
            (add-atom &captured-left (= (home) left-later))
            ((evalc (home) &captured-right)
             (evalc (eval $held) &captured-right)))))))
  ((right left-later)))
