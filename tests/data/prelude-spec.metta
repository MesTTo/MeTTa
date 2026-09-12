; Purpose: the executable spec for the engine's prelude vocabulary, and the
; oracle the differential suite runs the Prolog bodies against.
;
; Every form below was engine/prelude.metta until 2026-09-07, parsed and
; translated at every boot. The vocabulary is Prolog now: the bodies are
; engine/prelude.pl and the registers are engine/metta/prelude.pl. This file
; is what those bodies MEAN, in the language they are about, and
; tests/prolog/suites/evaluation/prelude_spec.plt is what holds them to it:
; it loads the declarations and equations here into a scratch space and
; proves bag-equality with the engine's own answers, per head, over the
; suites' cases and over adversarial ones.
; Guarantees:
;   - the engine's prelude_shipped_equation/2 register is exactly the 36
;     equations below, parsed
;     [tested: prelude_spec:the_shipped_register_is_the_spec_fixture;
;     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
;   - every head answers here what it answers in the engine
;     [tested: prelude_spec:every_head_agrees_with_its_spec_equation;
;     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
;   - reference maps hold names independently of their current metatype
;     [tested: references:a_reference_map_accepts_a_name_that_is_already_a_grounded_function;
;     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
; Assumes: the suite loads the declarations and the equations and SKIPS the
;   `!(add-translator-rule! ...)` runnables. A translator registration is
;   global, so running one from a scratch space would point the engine's own
;   compile-time rewriting at this fixture's equations; the registrations stay
;   written here because they are part of what each derived form IS.
; Open Obligations:
;   To Do: None
;   Hacks: None
;   Future Enhancements: None
;
; %%%% The engine's prelude: standard vocabulary, no import needed. %%%%
;
; Every form here is part of the core engine. The loader in metta.pl
; compiles these equations into the base tier at startup and registers
; each name as a builtin, so they are reachable from every space with no
; import!, shadowable per named space exactly as builtins are, and their
; atoms appear in NO space: a program enumerating &self sees only its
; own writes. Declarations land in the engine's prelude type register,
; where get-type and the call-site compiler read them after a program's
; own declarations, so a user redeclaration wins.
;
; The forms are Hyperon's standard vocabulary, promoted from
; lib/lib_he/lib_he.metta by the same route unify, add-reduct, add-atoms,
; add-reducts and evalc took before them: standard library operations
; rather than compatibility shims, and a program should not have to
; import anything to reach them. The equations ARE the executable spec;
; the parameter-evaluation decisions (which arguments are Atom) are
; carried over from the library unchanged, with the reasoning kept
; beside each.

;;; Equality and reduction ;;;

;The aligned equations are PeTTa's vendored lib_he equations. The differential
;also checks their parsed identity against that file.
(: if-equal (-> Atom Atom Atom Atom %Undefined%))
(: only (-> Atom Atom %Undefined%))
(: except (-> Atom Atom %Undefined%))
(: prefix (-> %Undefined% Atom %Undefined%))
(: rename (-> Atom Atom %Undefined%))
(: qualified (-> %Undefined% %Undefined%))
(= (if-equal $A $B $Then $Else)
   (if (== $A $B) $Then $Else))
(= (only $names $head) (if (is-member $head $names) $head (empty)))
(= (except $names $head) (if (is-member $head $names) (empty) $head))
(= (prefix $prefix $head) (atom_concat $prefix $head))
(= (rename $pairs $head) (let $cases (union-atom $pairs (($other $other))) (case $head $cases)))
(= (qualified $lib) (prefix (atom_concat $lib .)))

(: if-equal2 (-> Atom Atom Atom Atom %Undefined%))
(= (if-equal2 $A $B $Then $Else)
   (if (== $A $B) $Then $Else))

;A structural comparison whose operands stay written.  This declaration must
;precede the assert family because the engine prelude is compiled form by form;
;assertEqualToResult uses it to keep its expected-result tuple inert.
(: noreduce-eq (-> Atom Atom Bool))
(= (noreduce-eq $A $B)
   (=alpha $A $B))

;The non-Msg assert forms take Atom parameters and compare RESULT SETS,
;exactly as their own Msg twins below always did and as the arbiter
;declares them [source: same file, (: assertEqual (-> Atom Atom (->)))].
;The library evaluated the arguments applicatively and asserted once per
;combination, so a nondeterministic side asserted pairwise instead of
;set-wise; the two spellings agreed only on deterministic arguments.
;collapse owns the full evaluation, so its operand is not wrapped in eval.
;The return type stays %Undefined% for the reason type-cast's note
;records: an Atom RESULT type would leave the body untranslated.
;
;The two collapses are NAMED so the failure can report them. The verdict is
;the same == over the same two tuples it always was, and assert-answers never
;decides one: what changed is that the answers reach the failure instead of
;being discarded with the comparison. == is TERM equality, so this form is
;order-sensitive where its bag difference is not, and two empty bags beside a
;failure here mean the answers are a permutation of each other; the message
;says so [source: engine/metta/runtime.pl, assertion_permutation_note//2;
;commit=71de27a76dd16684941e3e090de0d17299d96493].
(: assertEqual (-> Atom Atom %Undefined%))
(= (assertEqual $A $B)
   (let $Actual (collapse $A)
     (let $Expected (collapse $B)
       (let $Same (== $Actual $Expected)
         (assert-answers $Same (assertEqual $A $B) $Actual $Expected)))))

;The operands are collapsed into ANSWER SETS first, so a nondeterministic
;side is compared set-wise rather than pairwise, which is the same reason
;assertEqual collapses.
;
;The VERDICT is what crosses to assert, never the comparison, and that is the
;rule assertEqualToResult and assertIncludes below already follow. A collapsed
;tuple is an APPLICATION whose head is its first answer, so evaluating one
;again under assert applies that answer to the rest:
;(assertAlphaEqual (quote (+ $x $y)) (quote (+ $a $b))) aborted the runnable
;with `+ ran backwards with more than one unknown` where upstream answers True
;[measured 2026-08-30 against PeTTa@ae66fa8 examples/he_assert.metta:5]. The
;comparison used to be safe here only because =alpha held both operands as
;written; it evaluates them now, as upstream's does.
(: assertAlphaEqual (-> Atom Atom %Undefined%))
(= (assertAlphaEqual $A $B)
   (let $Actual (collapse $A)
     (let $Expected (collapse $B)
       (let $Same (=alpha $Actual $Expected)
         (assert $Same)))))

;The ToResult forms do not evaluate their second argument: it is the set
;of expected results, written as a tuple. Both parameters are Atom so
;neither is evaluated on the way in, and the first is collapsed here into
;the tuple of every result it produces. Hyperon's own corpus states the
;contract, in tests/corpus/a1_symbols.metta: "assertEqualToResult checks
;all the results of the first expression; it doesn't evaluate the second
;expression, which is treated as a set of expected results."
;The comparison is NAMED here and the verdict is what crosses to assert.
;assert holds its operand and evaluates it, so handing it `(== $Actual $B)`
;would evaluate $B's value a second time and `(assertEqualToResult (+ 1 1)
;((+ 1 1)))` would pass, where it has to fail.  A Bool has no structure left
;to re-evaluate, which is why the verdict travels and the comparison does not.
;Upstream reaches the same verdict from a different mechanism: its
;`assertEqualToResult` is `assertEqual` is `(assert (== $A $B))`, checked once
;per answer of the first expression
;[source: PeTTa@43705f5d lib/lib_he.metta:12-22 over src/metta.pl:224-227].
;An earlier reference semantics reached it by routing these forms around
;assert entirely, through a quoting `_assert-results-are-equal`
;[assumed: read from that reference, not re-measured against upstream PeTTa].
;That operation compares MULTISETS: order is ignored, but one occurrence on
;one side consumes exactly one occurrence on the other.  The two directed
;subtractions below are the same bag-difference test using this engine's
;identity-preserving subtraction-atom.  Both must be empty, so `(a a b)` does
;not equal `(a b b)` even though their ordinary sets agree
;[assumed: the bag-difference reading was adopted from an earlier reference
;semantics, not re-measured against upstream PeTTa;
;commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87].
;Both verdicts were measured across the two engines on 2026-09-05 against
;PeTTa@43705f5d: `(assertEqualToResult (+ 1 1) ((+ 1 1)))` and
;`(assertEqualToResult (superpose (a a b)) (a b b))` each fail on both, and
;`(assertEqual (+ 1 1) 2)` passes on both.
;Only the comparison changes.  The public MeTTa contract remains the existing
;True answer on success and metta_assertion_failed exception on failure.
;
;The verdict below is unchanged and stays the multiset test these two
;subtractions have always made. What changed is where their result goes: it
;used to reach `assert` as one Bool and the two bags were dropped on the floor,
;which is the diff this form computes and nobody could read. assert-answers
;takes the same verdict plus the two answer bags and recomputes the same two
;differences ON THE FAILING PATH to report them, so what a failure says and
;what the verdict tested are one operation [source: engine/metta/runtime.pl,
;'assert-answers'/5; commit=71de27a76dd16684941e3e090de0d17299d96493].
(: assertEqualToResult (-> Atom Atom %Undefined%))
(= (assertEqualToResult $A $B)
   (let $Actual (collapse $A)
     (let $Missed (subtraction-atom $B $Actual)
       (let $Excessive (subtraction-atom $Actual $B)
         (let $Same (noreduce-eq ($Missed $Excessive) (() ()))
           (assert-answers $Same (assertEqualToResult $A $B) $Actual $B))))))

(: assertAlphaEqualToResult (-> Atom Atom %Undefined%))
(= (assertAlphaEqualToResult $A $B)
   (let $Actual (collapse $A)
     (let $Same (=alpha $Actual $B)
       (assert $Same))))

;Every expected result must appear among the results produced.
;Subtracting the produced set from the expected one leaves nothing when
;all of them did. subtraction-atom's two parameters are Expression and so
;hold their arguments as written, which is why the collapse is named first
;and the variable handed over; the definition this was taken from sequences it
;the same way, as
;(= (assertIncludes $atom $content) (let $eval_atom (collapse $atom) (let
;$diff (subtraction-atom $content $eval_atom) ...)))
;[assumed: adopted from an earlier reference semantics, not re-measured against
;upstream PeTTa].
(: assertIncludes (-> Atom Atom %Undefined%))
;The verdict crosses to assert-includes-answers rather than the comparison,
;for the reason assertEqualToResult above records: the difference is a set of
;WRITTEN expectations and == would evaluate it.
;
;The ONE-SIDED door, not assert-answers. This relation is containment, so an
;answer in excess of the expectation is legal and naming one would give the
;reader a bag that is not a reason for the failure; the door reports the
;answers missing from the expectation and leaves the excess side absent
;[source: engine/metta/runtime.pl, 'assert-includes-answers'/5;
;commit=48ec57e6df02e05ad3b5da50157dea321969bc48].
(= (assertIncludes $A $B)
   (let $Actual (collapse $A)
     (let $Diff (subtraction-atom $B $Actual)
       (let $Empty (== $Diff ())
         (assert-includes-answers $Empty (assertIncludes $A $B) $Actual $B)))))

;The Msg variants carry a failure message. Each reports the call AS WRITTEN,
;which carries the message with it, so the two bag-comparing twins below spell
;out their own bodies rather than delegating: a delegated body would report
;the delegate's name and lose the message the caller wrote. The alpha twins
;still delegate, because their relation computes no bag difference and their
;report is the delegate's already.
(: assertEqualMsg (-> Atom Atom Atom %Undefined%))
(= (assertEqualMsg $A $B $M)
   (let $Actual (collapse $A)
     (let $Expected (collapse $B)
       (let $Same (== $Actual $Expected)
         (assert-answers $Same (assertEqualMsg $A $B $M) $Actual $Expected)))))

(: assertAlphaEqualMsg (-> Atom Atom Atom %Undefined%))
(= (assertAlphaEqualMsg $A $B $M)
   (let $Actual (collapse $A)
     (let $Expected (collapse $B)
       (let $Same (=alpha $Actual $Expected)
         (assert $Same)))))

(: assertEqualToResultMsg (-> Atom Atom Atom %Undefined%))
(= (assertEqualToResultMsg $A $B $M)
   (let $Actual (collapse $A)
     (let $Missed (subtraction-atom $B $Actual)
       (let $Excessive (subtraction-atom $Actual $B)
         (let $Same (noreduce-eq ($Missed $Excessive) (() ()))
           (assert-answers $Same (assertEqualToResultMsg $A $B $M) $Actual $B))))))

(: assertAlphaEqualToResultMsg (-> Atom Atom Atom %Undefined%))
(= (assertAlphaEqualToResultMsg $A $B $M)
   (assertAlphaEqualToResult $A $B))

;Minimal MeTTa's three frame/carrier instructions are engine vocabulary. Their
;Prolog bodies live in lib/minimal_metta_lib/minimal_metta_lib.pl because a function frame needs
;a bounded evaluation loop and collapse-bind must retain branch bindings.
;These declarations precede every equation whose RHS is a function frame so
;the form is held and entered as a frame instead of being compiled as a call.
(: function (-> Atom Atom))
(: collapse-bind (-> Atom Expression))
(: superpose-bind (-> Expression Atom))

;;; Error handling ;;;

;The `function` wrapper is part of if-error's protocol, not presentation.
;Minimal `eval` stages an ordinary equation RHS but enters a returned function
;frame, so this reference body works through both native and reflected doors.
;[source: MettaHyperonFull/Minimal/Stdlib.lean:4015-4032, `if-error`;
;commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87]
(= (if-error $atom $then $else)
   (function (chain (eval (get-metatype $atom)) $meta
     (eval (if-equal $meta Expression
       (eval (if-equal $atom ()
         (return $else)
         (chain (decons-atom $atom) $list
           (unify $list ($head $tail)
             (eval (if-equal $head Error (return $then) (return $else)))
             (return $else)))))
       (return $else))))))

;throw is the half of the error story a program could not reach. It could
;BUILD an (Error ...) atom and it could CATCH a host exception, but a built
;atom is DATA: its refusal is decided from its static type, so
;`(+ (Error source message) 1)` is a BadArgType about an ErrorType operand
;rather than that error escaping. throw PRODUCES one, and a produced error
;finishes the enclosing call with it, so the atom a program raises here
;travels exactly as one the engine raised
;[source: ai-plan-synthesis-draft.md 8.10, "the only one that changes
;expressiveness, since a program can build (Error ...) and catch host
;exceptions but cannot raise"]
;[tested: test_a_thrown_reason_travels_as_a_produced_error].
;
;Re-raising is the same call: a reason that is ALREADY an error atom is
;handed on unchanged rather than wrapped a second time, so
;`(throw (catch (/ 1 0)))` raises the host error the catch reified instead of
;burying it. Upstream has no throw, so nothing here diverges from it; the
;shape follows the vocabulary's own, (Error <culprit> <reason>), with the
;throw call as the culprit.
(: throw (-> %Undefined% %Undefined%))
(= (throw $reason)
   (if-error $reason $reason (Error (throw $reason) $reason)))

(= (return-on-error $result $B)
   (if-error $result
             $result
             $B))

;;; Evaluation control ;;;

(= (for-each-in-atom $L $f)
   (map-atom $L $f))

;;; Atomicity ;;;

;atomically runs its argument inside one transaction, the name the
;concurrency vocabulary uses for an atomic block: Haskell's STM spells it
;`atomically`, Clojure's spells it `dosync`, and `transaction` is the same
;operation under the database name. Before this it did not exist, so
;!(atomically (+ 1 1)) answered (atomically 2), an unknown head applied to
;its evaluated argument, rather than running anything atomically.
;
;It is sugar over (transaction ...), deliberately, so the two forms cannot
;drift: every guarantee here is metta_transaction/1's, answer preservation
;and whole-set commit-or-rollback included, and there is one implementation
;of them.
;
;They are still not the same operation, and this is the difference.
;transaction is a SPECIAL FORM whose body is compiled into the call site, so
;the body has to be written there: (let $b <a term> (transaction $b))
;answers the TERM, unrun, because there is nothing to compile at the call
;site but a variable. atomically takes its body as an unreduced Atom and
;evaluates it, so the body may be a term the program computed. The 183
;inferences that separate them, 773.05 against 956.07 over a three-answer
;body [measured 2026-08-19], are what evaluating a runtime term costs
;against compiling the body in place.
(: atomically (-> Atom %Undefined%))
(= (atomically $expr) (transaction (eval $expr)))

;;; Quoting ;;;

;The operand is `Atom`, so it arrives UNREDUCED and the written `(quote X)`
;reaches the head below. That is load-bearing now that quote is an evaluation
;barrier rather than a value: an operand that evaluated would hand this `X`
;with the wrapper already gone, the first clause would not match, and
;`(unquote (quote (+ 1 2)))` would answer `(unquote (+ 1 2))` instead of 3
;[source: PeTTa@ae66fa8 lib/lib_he.metta:64-67; measured 2026-08-29 on
;examples/ch20-extending-the-engine/20-02-metta-written-in-metta/07-he_quoting.metta].
;
;The operand used to be `%Undefined%`, which let the quote arrive from a
;COMPUTATION rather than only from source, so `!(unquote (car-atom ((quote
;(+ 1 2)))))` answered 3 here. Upstream leaves that call inert and this engine
;now does too: the same input has to give the same answer, so the extra reach
;is not a superset to keep.
;
;The second clause is the inert fallback. Its body relies on the barrier as
;well: `(quote (unquote $A))` answers `(unquote $A)` and stops, where a quote
;that built a value would send this same rule round again.
(: unquote (-> Atom %Undefined%))
(= (unquote (quote $A))
   (let $cut (cut) (eval $A)))
(= (unquote $A) (quote (unquote $A)))

;The reference stdlib's public evaluator entry is `interpret`, whose first
;operand is held and whose Atom result is already final.  The full extracted
;stdlib replaces this bootstrap equation with its source interpreter.  Before
;that source is loaded, the native `metta` operation supplies the same typed
;evaluation boundary; a function frame is required so the Atom result rule
;does not return the `(metta ...)` call itself as inert data.
;[assumed: the `interpret` definition was adopted from an earlier reference
;semantics, not re-measured against upstream PeTTa;
;commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87]
(: interpret (-> Atom Type SpaceType Atom))
(= (interpret $atom $type $space)
   (function
     (chain (eval (metta $atom $type $space)) $result
       (return $result))))

;;; Types ;;;

;An arrow type is variadic.  Inspecting its first element handles every arity;
;the old pair of fixed heads recognized only `(->)` and one-argument arrows,
;so the ordinary `(-> Number Number Number)` function type was classified as
;False by the source interpreter.
;[source: MettaHyperonFull/Minimal/Stdlib.lean:4010-4038,
;`is-function`; commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87]
(: -> (-> (:seg Type) Type))
(: is-function (-> Type Bool))
(= (is-function $type)
   (let $mtype (get-metatype $type)
     (unify $mtype Expression
       (let $size (size-atom $type)
         (unify $size 0
           False
           (let ($head $tail) (decons-atom $type)
             (unify $head -> True False))))
       False)))

;get-type-space is a native builtin now: the engine's own get-type run
;with the selected space as context, upstream's selected-space spelling
;[source: pinned stdlib.md:849-868 via the arbiter]. The library's stub
;matched the literal &self and answered nothing for any named space.

;These two declarations are HERE rather than only in
;lib/lib_builtin_types/lib_builtin_types.metta because this is the register the CALL SITE
;reads. Asking for a type is a question about an expression, and the
;engine was answering it by running the expression first: an op that
;appends to a Python list fired on (get-type (metta-effectful)) and the
;answer was Number, the type of what it returned. Every linter walk and
;every REPL inspection was invisibly effectful on a seam whose whole
;purpose is arbitrary effects.
;
;An Atom parameter in the engine's own surface register is deliberately
;NOT honoured at call sites, because several of those declarations
;describe the argument a CALLER writes rather than the value the
;predicate receives, and honouring them broke every maplist call
;[source: call_site_type_chains/2 in engine/translator.pl]. get-type has no
;such gap: the declaration and the predicate agree that the argument
;arrives unreduced, so the prelude register, which IS honoured at call
;sites, is where it belongs.
;
;The answer then comes from the declaration: (get-type (literal-return 2)) is
;Atom for (: literal-return (-> Number Atom)), whatever its body would reduce
;to [assumed: [Atom] was measured from an earlier reference interpreter and
;from hyperon 0.2.10 alike, not re-measured against upstream PeTTa].
;
;get-type's arrow is upstream's. The first parameter of get-type-space said
;Symbol here while a space handle answered Symbol, and had to move with the
;handle's own type [tested: spaces:space_handle_type].
;
;get-type-space RETURNS %Undefined% and not Atom, and the difference only
;shows for a name a PROGRAM defines. The two spellings were measured identical
;on 2026-08-19 over an effectful call, a declared return, a value and a
;builtin application -- all of them the engine's own native path, where an
;Atom result decides nothing because there is no equation body to hold back.
;A program's equation is the case that was not measured: PeTTa ships
;get-type-space only as a lib_he equation, `(= (get-type-space &self $x)
;(get-type $x))`, with no declaration at all, and under an Atom RESULT this
;engine answered that body's `(get-type a)` as produced instead of evaluating
;it [measured 2026-08-30: `(A)` upstream against `((get-type a))` here;
;tested: examples/ch20-extending-the-engine/20-02-metta-written-in-metta/08-he_atomspace.metta]. The Atom spelling came from Hyperon's
;stdlib.md:849-868 through the previous arbiter, not from PeTTa.
(: get-type (-> Atom %Undefined%))
(: get-type-space (-> SpaceType Atom %Undefined%))

;Identity has no wildcard and does not bind either type.
(= (match-types $A $B $Then $Else)
   (if (== $A $B) $Then $Else))

;A failed comparison preserves the accumulator's value and type.
(= (match-type-or $value $type1 $type2)
   (match-types $type1 $type2 True $value))

;The fold used by type-cast is defined before its caller so the engine prelude's
;single-pass compiler sees an executable function rather than a constructor.
;foldl-atom's list parameter is Expression, so the collected declarations are
;named before it reads them.
(= (type-cast-holds $atom $raw-type $space)
   (let $type (__metta_type_syntax__ $raw-type $space)
     (let $declarations (collapse (get-type-space $space $atom))
       (foldl-atom $declarations False $acc $declared
          (match-type-or $acc $declared $type)))))

;type-cast, upstream's contract: the atom when the cast holds, the flat
;(Error $atom BadType) when it does not. UNDECLARED ON PURPOSE, and the
;absence carries behaviour: upstream ships this equation with no
;(: type-cast ...) line, so the operands evaluate before the equation
;runs, and an ill-typed subject reports its OWN error instead of being
;swallowed by an Atom mask [assumed: exactly that was measured against pinned
;Hyperon 0.2.10 in an earlier reference corpus, not re-measured against
;upstream PeTTa]. The library declared Atom
;parameters and compared metatypes with ==; both diverged.
;The atom's metatype is NAMED before the comparison. Both of =alpha's declared
;parameters are `Atom`, so an operand written as a call reaches the comparison
;unreduced and `(=alpha Symbol (get-metatype A))` compares a symbol with a call
;instead of with `Symbol`; the reference's own type-cast names the same value
;first, through a chain, as `(chain (eval (get-metatype $atom)) $meta ...)`
;[assumed: adopted from an earlier reference semantics, not re-measured against
;upstream PeTTa].
(= (type-cast $atom $raw-type $space)
   (let $type (__metta_type_syntax__ $raw-type $space)
     (let $meta (get-metatype $atom)
       (if (=alpha $type $meta)
           $atom
           (if (type-cast-holds $atom $raw-type $space)
               $atom
               (Error $atom BadType))))))

;;; Documentation ;;;
;
;The prelude documents its own vocabulary; the loader routes these into
;the engine's doc register, get-doc's first tier, so (help! type-cast)
;answers with no import and a program's own (@doc ...) atoms stay the
;program's. Descriptions follow the pinned corelib's where it has them.

;The unary get-doc is MeTTa's raw-document convenience. The two-input arrow
;and the four helpers are upstream's formal family. Atom keeps each documented
;subject and prose part unevaluated while the engine joins them with the type
;from the selected space [source: hyperon-experimental@3f76dc4,
;lib/src/metta/runner/stdlib/stdlib.metta:795-875].
(: get-doc (-> Atom %Undefined%))
(: get-property (-> Atom Expression))
(: get-doc (-> SpaceType Atom %Undefined%))
(: get-doc-atom (-> SpaceType Atom %Undefined%))
(: get-doc-single-atom (-> SpaceType Atom %Undefined%))
(: get-doc-function (-> SpaceType Atom Type %Undefined%))
(: get-doc-params (-> Expression Atom Expression (Expression Atom)))

(@doc if-equal
  (@desc "Selects the third argument when the first two are identical by ==, and the fourth otherwise")
  (@params ((@param "First atom") (@param "Second atom") (@param "Result on equivalence") (@param "Result otherwise")))
  (@return "Third or fourth argument"))
(@doc if-equal2
  (@desc "if-equal under its second historical name")
  (@params ((@param "First atom") (@param "Second atom") (@param "Result on equivalence") (@param "Result otherwise")))
  (@return "Third or fourth argument"))
(@doc only (@desc "Keeps a head present in the supplied names; partial application is a from map"))
(@doc except (@desc "Keeps a head absent from the supplied names; partial application is a from map"))
(@doc prefix (@desc "Concatenates a prefix and a head; partial application is a from map"))
(@doc rename (@desc "Uses the first matching (old new) pair, or keeps the head; partial application is a from map"))
(@doc qualified (@desc "Builds a prefix map using the library name and a dot"))
(@doc get-property (@desc "Answers visibility, defining origins and declared effect, cost, deprecation and documentation properties, one per answer"))
(@doc assert-answers
  (@desc "Asserts a verdict about two answer bags; a false verdict reports the call as written and the two directed bag differences, what was missing and what was in excess")
  (@params ((@param "Verdict, evaluated") (@param "Call to report, as written") (@param "Answers produced") (@param "Answers expected")))
  (@return "unit"))
(@doc assert-includes-answers
  (@desc "assert-answers for a containment: a false verdict reports the call as written and only the answers missing from the expectation, because an answer in excess of it is legal under this relation")
  (@params ((@param "Verdict, evaluated") (@param "Call to report, as written") (@param "Answers produced") (@param "Answers expected to be included")))
  (@return "unit"))
(@doc assertEqual
  (@desc "Compares the result sets of two expressions; passes silently or raises a failed assertion naming the expression and the answers missing from and in excess of the expectation")
  (@params ((@param "First expression, not evaluated on the way in") (@param "Second expression, not evaluated on the way in")))
  (@return "unit"))
(@doc assertAlphaEqual
  (@desc "assertEqual up to alpha-equivalence of the result sets")
  (@params ((@param "First expression") (@param "Second expression")))
  (@return "unit"))
(@doc assertEqualToResult
  (@desc "Checks all the results of the first expression against the second expression, which is not evaluated and is read as the set of expected results")
  (@params ((@param "Expression to evaluate") (@param "Expected results, as written")))
  (@return "unit"))
(@doc assertAlphaEqualToResult
  (@desc "assertEqualToResult up to alpha-equivalence")
  (@params ((@param "Expression to evaluate") (@param "Expected results, as written")))
  (@return "unit"))
(@doc assertIncludes
  (@desc "Passes when every expected result appears among the results the first expression produces")
  (@params ((@param "Expression to evaluate") (@param "Expected subset, as written")))
  (@return "unit"))
(@doc assertEqualMsg
  (@desc "assertEqual with a message argument, which the failure report carries because it reports the call as written")
  (@params ((@param "First expression") (@param "Second expression") (@param "Message")))
  (@return "unit"))
(@doc assertAlphaEqualMsg
  (@desc "assertAlphaEqual with a message argument, accepted and unused")
  (@params ((@param "First expression") (@param "Second expression") (@param "Message")))
  (@return "unit"))
(@doc assertEqualToResultMsg
  (@desc "assertEqualToResult with a message argument, which the failure report carries because it reports the call as written")
  (@params ((@param "Expression to evaluate") (@param "Expected results") (@param "Message")))
  (@return "unit"))
(@doc assertAlphaEqualToResultMsg
  (@desc "assertAlphaEqualToResult with a message argument, accepted and unused")
  (@params ((@param "Expression to evaluate") (@param "Expected results") (@param "Message")))
  (@return "unit"))
(@doc if-error
  (@desc "Selects the second argument when the first is an (Error ...) expression and the third otherwise")
  (@params ((@param "Value to inspect") (@param "Result on error") (@param "Result otherwise")))
  (@return "Second or third argument"))
(@doc return-on-error
  (@desc "Answers the first argument when it is an (Error ...) expression, stopping the computation there, and the second otherwise")
  (@params ((@param "Value to inspect") (@param "Result when the first is not an error")))
  (@return "The error, or the second argument"))
(@doc for-each-in-atom
  (@desc "Applies a function to every element of an expression; map-atom under its historical name")
  (@params ((@param "Expression to walk") (@param "Function to apply")))
  (@return "The mapped expression"))
(@doc unquote
  (@desc "Unquotes a quoted atom and evaluates it, e.g. (unquote (quote $x)) evaluates $x; a non-quote argument stays as written")
  (@params ((@param "Quoted atom")))
  (@return "Unquoted atom"))
(@doc noreduce-eq
  (@desc "Compares two atoms as written, neither evaluated")
  (@params ((@param "First atom, as written") (@param "Second atom, as written")))
  (@return "True or False"))
(@doc is-function
  (@desc "True when the argument is an arrow type")
  (@params ((@param "Type atom")))
  (@return "True or False"))
(@doc match-types
  (@desc "Compares two types by == and returns the third argument if identical, the fourth otherwise; neither type is bound")
  (@params ((@param "First type") (@param "Second type") (@param "Result on identity") (@param "Result otherwise")))
  (@return "Third or fourth argument"))
(@doc match-type-or
  (@desc "Returns True when the second and third arguments are identical by ==, and the first argument otherwise")
  (@params ((@param "Accumulator value") (@param "First type") (@param "Second type")))
  (@return "True or the accumulator"))
(@doc type-cast
  (@desc "Casts atom passed as a first argument to the type passed as a second argument using space as a context")
  (@params ((@param "Atom to be casted") (@param "Type to cast atom to") (@param "Context atomspace")))
  (@return "Atom if casting is successful, (Error ... BadType) otherwise"))
(@doc type-cast-holds
  (@desc "Whether any declared type of the atom in the space unifies with the requested type; type-cast's fold, named because MeTTa is applicative where the corelib chains")
  (@params ((@param "Atom") (@param "Requested type") (@param "Context atomspace")))
  (@return "True or False"))
(@doc get-type-space
  (@desc "get-type run with the selected space as the context")
  (@params ((@param "Space to select") (@param "Atom to type")))
  (@return "The type, as get-type answers it in that space"))
(@doc get-doc
  (@desc "Returns formal documentation for an atom or function in a selected space; the one-argument MeTTa overload returns the raw (@doc ...) atom")
  (@params ((@param "The space to search") (@param "The atom or function to document")))
  (@return "An (@doc-formal ...) atom"))
(@doc get-doc-atom
  (@desc "Builds formal atom documentation from prose and the selected space's type")
  (@params ((@param "The space to search") (@param "The atom to document")))
  (@return "An atom-shaped (@doc-formal ...) atom"))
(@doc get-doc-single-atom
  (@desc "Dispatches one atom to function or atom documentation according to its selected-space type")
  (@params ((@param "The space to search") (@param "The atom to document")))
  (@return "An (@doc-formal ...) atom"))
(@doc get-doc-function
  (@desc "Builds formal function documentation by pairing parameter and return prose with an arrow type")
  (@params ((@param "The space to search") (@param "The function name") (@param "Its arrow type")))
  (@return "A function-shaped (@doc-formal ...) atom"))
(@doc get-doc-params
  (@desc "Pairs informal parameter and return descriptions with their types")
  (@params ((@param "The (@param ...) list") (@param "The (@return ...) description") (@param "The parameter and return types")))
  (@return "The formal parameter list and return description"))
(@doc get-doc-space
  (@desc "get-doc run against the selected space")
  (@params ((@param "Space to select") (@param "The name to look up")))
  (@return "The (@doc ...) atom"))
(@doc help!
  (@desc "Prints the documentation for a name, the engine's own vocabulary included")
  (@params ((@param "The name to look up")))
  (@return "unit"))
(@doc documented
  (@desc "Every name the CURRENT SPACE documents, one per solution; program-scoped on purpose, so the engine's own vocabulary does not bury yours")
  (@params ())
  (@return "A name"))
(@doc documented-space
  (@desc "documented, against the selected space")
  (@params ((@param "Space to select")))
  (@return "A name"))
(@doc defined-name
  (@desc "Every function name the current space defines, builtins excluded, once each")
  (@params ())
  (@return "A name"))
(@doc undocumented
  (@desc "Every defined name in the current space with no documentation anywhere; the gap worth closing")
  (@params ())
  (@return "A name"))
(@doc undocumented-space
  (@desc "undocumented, against the selected space")
  (@params ((@param "Space to select")))
  (@return "A name"))

;;; Derived forms ;;;
;
; A form below is written in MeTTa, as an equation that says what the call
; EXPANDS TO, plus the registration that makes the translator consult it
; before it reaches its own special-form table. Nothing here needs a clause in
; the compiler: the expansion goes back through the ordinary translator, so
; one definition decides what the form means and the kernel carries one form
; fewer. The Atom parameters are what make an argument arrive as syntax; the
; %Undefined% RESULT type is what makes the (noeval ...) body translate, since
; an Atom result would leave the body untranslated and hand the noeval itself
; back as the expansion.
;
; Every form here was A/B'd against the compiler clause it replaced, on the
; goals it compiles to and on compile-time inference counts, over the whole
; examples corpus [tested: translator_derived_forms,
; test_a_prelude_derived_form_matches_its_fused_twin_on_the_corpus].

;and-then and or-else ARE `if` with one branch decided, which is what their
;compiler clauses spelled out by hand. The expansion compiles one goal FEWER
;than the clause did, because if builds its branches through build_branch/4
;and drops the empty conjunct the hand-written pair kept [measured 2026-08-19:
;the same conditional, minus one `true` conjunct].
(: and-then (-> Atom Atom %Undefined%))
(= (and-then $a $b) (noeval (if $a $b False)))
!(add-translator-rule! and-then)

(: or-else (-> Atom Atom %Undefined%))
(= (or-else $a $b) (noeval (if $a True $b)))
!(add-translator-rule! or-else)

;The stream operations. Each was a rewrite rule in the compiler that produced
;exactly the MeTTa term below, so moving them changes nothing but where they
;live [measured 2026-08-19: byte-identical compiled goals].
;
;Four of them carry a (cost ...) row, a claim about how the call's cost grows
;with the number of answers the stream carries, which the cost-rows lane
;measures and fails. union is linear, being an append, while intersection,
;subtraction and alpha-unique each build an association tree of one operand and
;look the other up in it, so each costs a log factor more; that difference is
;what the rows are for, since nothing else said so.
;
;unique carries NO row, on purpose. It reduces to unique-atom, which is SWI's
;list_to_set/2 and sorts in C, so the engine's inference counter reads it
;linear while retired instructions read it linearithmic, and a row would state
;the cheaper of the two. lib_builtin_types.metta records the same exclusion
;beside unique-atom itself
;[measured 2026-09-07: extensions/python/benchmarks/cost-baseline.json for the
;first counter and `python -m benchmarks.costs --paired` for the second].
(: trace! (-> Atom Atom %Undefined%))
(= (trace! $message $value) (noeval (progn (println! $message) $value)))
!(add-translator-rule! trace!)

(: unique (-> Atom %Undefined%))
(= (unique $stream)
   (noeval (let $collapsed (collapse $stream)
             (let $kept (unique-atom $collapsed)
               (superpose $kept)))))
!(add-translator-rule! unique
   ((extra-variables-exempt "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten")))

(: alpha-unique (-> Atom %Undefined%))
(= (alpha-unique $stream)
   (noeval (let $collapsed (collapse $stream)
             (let $kept (alpha-unique-atom $collapsed)
               (superpose $kept)))))
!(add-translator-rule! alpha-unique
   ((extra-variables-exempt "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten")))
(cost (alpha-unique (superpose $n)) linearithmic)

;The set operations name the shape they rewrite, `(superpose ...)` on both
;sides, exactly as the compiler's rewrite rules did. The second equation is
;what the compiler's identity clause was: a call that is not that shape is a
;program using the name as data, and `noeval` hands it back unevaluated
;rather than letting the expansion recurse [tested: translator_derived_forms].
(: union (-> Atom Atom %Undefined%))
(= (union (superpose $a) (superpose $b))
   (noeval (let $left (collapse (superpose $a))
             (let $right (collapse (superpose $b))
               (let $combined (union-atom $left $right)
                 (superpose $combined))))))
(= (union $a $b) (noeval (noeval (union $a $b))))
!(add-translator-rule! union
   ((extra-variables-exempt "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten")))
(cost (union (superpose $n) (superpose $n)) linear)

(: intersection (-> Atom Atom %Undefined%))
(= (intersection (superpose $a) (superpose $b))
   (noeval (let $left (collapse (superpose $a))
             (let $right (collapse (superpose $b))
               (let $combined (intersection-atom $left $right)
                 (superpose $combined))))))
(= (intersection $a $b) (noeval (noeval (intersection $a $b))))
!(add-translator-rule! intersection
   ((extra-variables-exempt "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten")))
(cost (intersection (superpose $n) (superpose $n)) linearithmic)

(: subtraction (-> Atom Atom %Undefined%))
(= (subtraction (superpose $a) (superpose $b))
   (noeval (let $left (collapse (superpose $a))
             (let $right (collapse (superpose $b))
               (let $combined (subtraction-atom $left $right)
                 (superpose $combined))))))
(= (subtraction $a $b) (noeval (noeval (subtraction $a $b))))
!(add-translator-rule! subtraction
   ((extra-variables-exempt "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten")))
(cost (subtraction (superpose $n) (superpose $n)) linearithmic)

; has-declared-type asks whether (: <atom> <type>) is declared, about the
; atom AS ITSELF: the first parameter carries the Atom mask so the question
; is asked of the unreduced atom, the way get-type asks
; [tested: metta_has_declared_type in tests/prolog/suites/evaluation/metta.plt].
(: has-declared-type (-> Atom %Undefined% Bool))

; space-contains asks whether the space holds an atom unifying with the
; given one, about the atom AS ITSELF: one indexed probe against the
; store, flat however large the space grows, which is what a
; set-semantics rule wants per add.
(: space-contains (-> %Undefined% Atom Bool))

; %%%% Space admission: the shipped judge over (admits ...) and (capacity ...) %%%%
;
; The judge itself is the engine builtin space-admission-verdict,
; Prolog-bodied by measurement: the same chain written here as equations
; cost 131.01 inferences per add against the builtin body, the two
; collapse-over-match reads of &metta being the gap, and a pool is a
; millions-of-adds surface (extensions/python/benchmarks/extension_cost.py's
; write-door table is the record). The declaration below is the half of
; its contract that lives at this level: the Atom mask keeps the offered
; atom unreduced, so a pool judges the atom AS ITSELF
; [tested: the_sugar_judges_the_offered_atom_as_itself in tests/prolog/suites/spaces/hooks.plt].
; metta_admission_claim/2 writes a one-line guard equation,
;   (= (space-admission-guard-<pool> $x) (space-admission-verdict <pool> $x))
; into the declaring space and claims the pool's pre-add hook with it, so
; enforcement rides the general one-claimant registry and a space may
; shadow the judge like any builtin. The same judge written in MeTTa runs
; as executable documentation, with a differential against this builtin,
; in examples/ch15-writing-transactions-and-worlds/04-admission_pools.metta.
(: space-admission-verdict (-> %Undefined% Atom %Undefined%))
