; Purpose: run the shipped discharge verifier through structural type aliases.
(: VdNumber (Alias Number))
(: VdSymbol (Alias Symbol))
(: VdResult (Alias %Undefined%))
!(pragma! verify-discharges true)

(: vd-double (-> VdNumber VdNumber))
(= (vd-double $x) (* $x 2))
!(test (vd-double 21) 42)
!(test (vd-double 1.5) 3.0)

(: vd-name (-> VdSymbol VdResult))
(= (vd-name $x) $x)
!(test (vd-name orange) orange)
!(test (vd-name (+ 1 2))
       (Error (vd-name (+ 1 2))
              (BadArgType 1 VdSymbol Number
                          (TypeExpansion (-> VdSymbol VdResult)
                                         (-> Symbol %Undefined%)))))
!(test (vd-double "not a number")
       (Error (vd-double "not a number")
              (BadArgType 1 VdNumber String
                          (TypeExpansion (-> VdNumber VdNumber)
                                         (-> Number Number)))))

!(pragma! verify-discharges false)
!(test (vd-double 4) 8)
