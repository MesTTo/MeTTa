; Purpose: show values, shared entity facts and private prototype spaces.
; Guarantees: the three representations support field access, transactional
;   replacement and scoped retirement
;   [tested: examples/ch17-concurrency-and-the-loop/08-class_grains.metta;
;   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
; Owns resources: scope releases the class spaces, population and prototypes.

!(import! &self (library lib_thread))

;A frozen Point is its fields. An Account is a token whose fields live in
;one class space. An Agent holds a space because it can own private rules.
;These equations expose the storage operations a Python class declaration
;derives. The Python twin declares the same three shapes with dataclasses.
!(test
  (scope
    (let $home (new-space)
      (progn
        (add-atom &GrainPoint (: GrainPoint (-> Number Number GrainPoint)))
        (add-atom &GrainPoint
          (= (GrainPoint-x (GrainPoint $x $y)) $x))
        (add-atom &GrainPoint
          (= (GrainPoint-y (GrainPoint $x $y)) $y))

        (add-atom &GrainAccount (: GrainAccount (-> Atom GrainAccount)))
        ;Each defining space imports the operations its own bodies use.
        (add-atom &GrainAccount
          (from (library lib_thread) (only (scope-defer))))
        (add-atom &GrainAccount
          (internal owned-by _field-owner _field-balance scope-defer))
        (add-atom &GrainAccount
          (= (GrainAccount-balance (GrainAccount $id))
             (match &GrainAccount (_field-balance (GrainAccount $id) $n) $n)))
        (add-atom &GrainAccount
          (= (GrainAccount-balance! (GrainAccount $id) $n)
             (transaction
               (progn
                 (remove-atom &GrainAccount
                   (_field-balance (GrainAccount $id) $old))
                 (add-atom &GrainAccount (_field-balance (GrainAccount $id) $n))
                 True))))
        (add-atom &GrainAccount
          (= (retire-GrainAccount $account)
             (progn
               (remove-atom &GrainAccount ($field $account $value))
               (remove-atom &GrainAccount (owned-by $account))
               True)))
        (add-atom &GrainAccount
          (= (make-GrainAccount $owner $balance)
             (transaction
               (progn
                 (add-atom &GrainAccount (owned-by (GrainAccount $id)) $id)
                 (add-atom &GrainAccount (_field-owner (GrainAccount $id) $owner))
                 (add-atom &GrainAccount (_field-balance (GrainAccount $id) $balance))
                 (scope-defer (GrainAccount $id)
                   (evalc (retire-GrainAccount (GrainAccount $id)) &GrainAccount))
                 (GrainAccount $id)))))

        (add-atom &GrainAgent (: GrainAgent (-> SpaceType GrainAgent)))
        (add-atom &GrainAgent (internal owned-by _field-label))
        (add-atom &GrainAgent
          (= (GrainAgent-label (GrainAgent $space))
             (match $space (_field-label $label) $label)))
        (add-atom &GrainAgent
          (= (make-GrainAgent $label)
             (transaction
               (let $space (new-space)
                 (progn
                   (add-atom $space (from &GrainAgent))
                   (add-atom $space (internal _field-label private_rule))
                   (add-atom $space (_field-label $label))
                   (add-atom &GrainAgent (owned-by (GrainAgent $space)))
                   (GrainAgent $space))))))

        (add-atom $home (from &GrainPoint))
        (add-atom $home (from &GrainAccount))
        (add-atom $home (from &GrainAgent))
        ;Python's compiled del calls the retirement equation.
        (add-atom $home
          (= (discard $account) (progn (retire-GrainAccount $account) True)))

        (evalc
          (let* (($projection
                    (match &GrainPoint
                      (= (GrainPoint-x (GrainPoint $x $y)) $x) True))
                 ($point-x (GrainPoint-x (GrainPoint 3 4)))
                 ($alice (make-GrainAccount "alice" 40))
                 ($bob (make-GrainAccount "bob" 80))
                 ($_write (GrainAccount-balance! $alice 50))
                 ($population
                    (msort (collapse
                      (match &GrainAccount (_field-balance $account $n) $n))))
                 ($_refused
                    (if-error
                      (transaction
                        (progn (GrainAccount-balance! $alice 0)
                               (Error withdraw overdraft)))
                      rejected unexpected))
                 ($restored (GrainAccount-balance $alice))
                 ($_retired (discard $bob))
                 ($remaining
                    (size-atom (collapse
                      (match &GrainAccount (owned-by $account) $account))))
                 ($left (make-GrainAgent left))
                 ($right (make-GrainAgent right)))
            (let* (((GrainAgent $left-space) $left)
                   ((GrainAgent $right-space) $right))
              (progn
                ;The receiver is explicit. &self inside an equation would
                ;still name its defining home, never the argument's space.
                (add-atom $left-space
                  (= (private_rule $receiver) (GrainAgent-label $receiver)))
                (add-atom $right-space
                  (= (private_rule $receiver) (GrainAgent-label $receiver)))
                ($projection $point-x $population $restored $remaining
                  ((evalc (private_rule $left) $left-space)
                   (evalc (private_rule $right) $right-space))
                  (== (private_rule $left) (quote (private_rule $left)))))))
          $home))))
  (True 3 (50 80) 50 1 (left right) True))

;The longhand scope_defer holds a native cleanup expression just as
;scope-defer does. Leaving the scope retires its facts. A space allocated
;outside that scope remains owned by its caller until explicitly released.
;drop-space and its Prolog-backed spelling space_drop release the same kind
;of resource.
!(test
  (let* (($rows (new-space))
         ($during
           (scope
             (progn
               (add-atom $rows (owned item))
               (scope_defer item (remove-atom $rows (owned item)))
               (== (collapse (match $rows (owned $x) $x)) (item)))))
         ($after (collapse (match $rows (owned $x) $x)))
         ($released (drop-space $rows))
         ($other (new-space))
         ($released-longhand (space_drop $other)))
    ($during $after $released $released-longhand))
  (True () True True))
