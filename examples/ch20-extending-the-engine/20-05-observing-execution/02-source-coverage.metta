; Purpose: query which written branch ran, including the branch with zero hits.
!(import! &self (library lib_observe))
!(bind! &coverage (observe-source &self "branches.metta" "(= (choose $flag $x)\n  (if $flag\n    (+ $x 2)\n    (+ $x 2)))\n!(choose True 1)"))
!(test (match &coverage (observation-status $status) $status) complete)
!(test (match &coverage (observation-answer 0 $answer) $answer) 3)
!(test (match &coverage (source-coverage "branches.metta" 3 5 3 13 $hits) (> $hits 0)) True)
!(test (match &coverage (source-coverage "branches.metta" 4 5 4 13 $hits) $hits) 0)
