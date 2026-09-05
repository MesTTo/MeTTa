; Purpose: one implementation carries two correlated overload declarations.
(: compiled-identity (-> Number Number))
(: compiled-identity (-> String String))
(= (compiled-identity $value) $value)

!(test (collapse (get-type compiled-identity))
       ((-> Number Number) (-> String String)))
!(test (compiled-identity 7) 7)
!(test (compiled-identity "word") "word")
