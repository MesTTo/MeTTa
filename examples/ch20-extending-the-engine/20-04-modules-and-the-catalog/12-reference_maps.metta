; Purpose: demonstrate head maps and the receiving space's default map.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/12-reference_maps.metta; commit=WORKTREE].

; only selects named public heads; except selects the remaining public heads.
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (only (map-value)))
!(test (map-value 2) 3)
!(test (collapse (map-label)) ((map-label)))
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (except (map-value)))
!(test (map-label) label)

; Each map runs on a head name, once. Aliases retain the same defining body.
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (prefix p.))
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (rename ((map-value renamed))))
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (qualified module))
!(test (p.map-value 2) 3)
!(test (renamed 2) 3)
!(test (module.map-value 2) 3)
!(test (collapse (map-label)) (label))

; A map may answer several symbols or none. Lambda and partial application
; are ordinary functions here; the five map helpers have no special loader.
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps
      (|-> ($h) (if (== $h map-value) (superpose (lambda-one lambda-two)) (empty))))
!(test (lambda-one 2) 3)
!(test (lambda-two 2) 3)
!(test ((prefix text.) word) text.word)

; A missing map uses this space's default, identity until changed.
!(pragma! from-map (prefix default.))
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps)
!(test (default.map-value 2) 3)
!(pragma! from-map none)
