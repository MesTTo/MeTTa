; Purpose: trigger the informational note for an evaluated equation-head call.
(= (visible-inner $x) $x)
(= (visible-head (visible-inner $x)) $x)
!(test (visible-head (visible-inner 3)) 3)
