;The check every lib_pln2 formula that assumes independence runs first, on
;its own. `10-pln2-ctv.metta` meets it through `pln2-product-independent`
;and `pln2-total-probability-independent`, where a shared support ID is what
;the failure is about; this is the same check as a question a caller can ask
;before combining anything.
!(import! &self (library lib_pln2))

;Disjoint support sets are independent, and that is all the check asks.
!(test (pln2-require-independent-supports ((sensor-a) (sensor-b))) True)
!(test (pln2-require-independent-supports ((sensor-a sensor-b) (sensor-c))) True)

;Nothing to compare is independent too, which is what keeps the check total:
;a caller with one operand, or none, does not have to special-case it.
!(test (pln2-require-independent-supports ()) True)
!(test (pln2-require-independent-supports ((sensor-a))) True)
!(test (pln2-require-independent-supports ((sensor-a) ())) True)

;One shared ID is a refusal, and it names the ID rather than the pair, so a
;caller learns which evidence to factor out.
!(test (let $reported (catch (pln2-require-independent-supports ((sensor-a) (sensor-a))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(pln2_dependent_supports sensor-a)")
!(test (let $reported
          (catch (pln2-require-independent-supports ((sensor-a sensor-b) (sensor-b))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(pln2_dependent_supports sensor-b)")

;And the refusal ends in the remedy, because the library's whole position is
;that a formula assuming independence either gets disjoint evidence or says
;so: nothing here silently multiplies a probability by itself.
!(test (let $reported (catch (pln2-require-independent-supports ((s) (s))))
         (unify $reported (Error $ball $context) (index-atom $context 2) no-error))
       "factor shared support in an owned reasoner with stable signed evidence IDs, then combine only disjoint residual supports")
