; Purpose: negate nested case arms without turning wildcard patterns into Empty.

(= (case-band $key)
   (case $key
     ((90 True)
      ($remaining (case $remaining ((40 False)))))))

(= (case-default $key)
   (case $key
     ((90 True)
      ($remaining (case $remaining ((40 False) ($other False)))))))

!(test (not-provable (case-band 90)) False)
!(test (not-provable (case-band 40)) True)
!(test (not-provable (case-band 55)) True)
!(test (collapse (case-band 55)) ())
!(test (not-provable (case-default 90)) False)
!(test (not-provable (case-default 40)) True)
!(test (not-provable (case-default 55)) True)
