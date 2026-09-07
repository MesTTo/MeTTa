;Three doors into the evaluator, all with the same three arguments -- the
;atom, a type, and the space to run it in -- and two different answers.
;
;`metta` is the one chapter 14 and the foreign-rules file already use.
;`interpret` is minimal MeTTa's own name for it, and `metta-thread` is the
;reference's `mettaThreadStep`, which delegates to `mettaEval` and so runs
;the same evaluator to a FIXPOINT.
;[source: MettaHyperonFull/Minimal/Interpreter.lean, `mettaThreadStep`
;delegating to `mettaEval`]

(= (twice $x) (* 2 $x))

;On an ordinary call all three agree, because one step is all it takes.
!(test (metta (twice 5) %Undefined% &self) 10)
!(test (interpret (twice 5) %Undefined% &self) 10)
!(test (metta-thread (twice 5) %Undefined% &self) 10)
!(test (interpret (+ 1 2) Number &self) 3)

;They agree on nondeterminism too: each answers once per branch rather than
;collapsing, so the space's own multiplicity comes through.
(= (gen) (superpose (1 2)))
!(test (collapse (interpret (gen) %Undefined% &self)) (1 2))
!(test (collapse (metta-thread (gen) %Undefined% &self)) (1 2))

;They part on a body whose ANSWER is itself reducible. `interpret` and
;`metta` take the carrier one step and hand back what they got, so a body
;that answers a held call answers that call; `metta-thread` keeps stepping
;until nothing reduces, so the same body answers the number.
(= (held) (noeval (+ 1 2)))
!(test (let $r (interpret (held) %Undefined% &self) (repr $r)) "(+ 1 2)")
!(test (let $r (metta (held) %Undefined% &self) (repr $r)) "(+ 1 2)")
!(test (metta-thread (held) %Undefined% &self) 3)

;A function frame is the same story: `return` hands one value back to the
;frame and the two step-at-a-time doors stop there.
(= (framed) (function (return (+ 1 2))))
!(test (let $r (interpret (framed) %Undefined% &self) (repr $r)) "(+ 1 2)")
!(test (metta-thread (framed) %Undefined% &self) 3)

;An atom nothing reduces is its own answer through every one of them, which
;is the language's bare-execution rule reaching the evaluator doors.
!(test (interpret nosuchhead %Undefined% &self) nosuchhead)
!(test (metta-thread nosuchhead %Undefined% &self) nosuchhead)

;`interpret` and `metta` are declared and `metta-thread` is not, which is why
;the first two mask their atom argument and the third is a bare operation.
!(test (get-type interpret) (-> Atom Type SpaceType Atom))
!(test (get-type metta) (-> Atom Type SpaceType Atom))
!(test (get-type metta-thread) %Undefined%)

;The space argument is the point of all three: an atom evaluates against the
;equations of the space it is handed, not of the caller's.
!(add-atom &elsewhere (= (twice $x) (+ 1000 $x)))
!(test (interpret (twice 5) %Undefined% &elsewhere) 1005)
!(test (metta-thread (twice 5) %Undefined% &elsewhere) 1005)
!(test (interpret (twice 5) %Undefined% &self) 10)
