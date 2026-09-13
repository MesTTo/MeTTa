; Purpose: exact number operations and native floating functions.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/35-math_lib.metta; commit=WORKTREE].
!(import! &self (library lib_math))

; Counts compose from combinatorics. Gcd and lcm accept any number of integers.
!(test (factorial 20) 2432902008176640000)
!(test (binomial 52 5) 2598960)
!(test (math-gcd ()) 0)
!(test (math-gcd (0 0)) 0)
!(test (math-gcd (-18 24 30)) 6)
!(test (math-gcd (18446744073709551616 36893488147419103232)) 18446744073709551616)
!(test (math-lcm ()) 1)
!(test (math-lcm (-6 8 15)) 120)
!(test (math-lcm (0 5)) 0)

; Rationals stay numeric and exact. A float's exact ratio differs from a
; rationalization that admits the floating rounding error.
!(test (* (math-rational 1 3) 3) 1)
!(test (math-ratio (math-rational 10 -20)) (-1 2))
!(test (math-class (math-rational 6 3)) integer)
!(test (math-class (math-rational 1 3)) rational)
!(test (math-ratio 0.1) (3602879701896397 36028797018963968))
!(test (math-ratio (math-rational 0.1)) (3602879701896397 36028797018963968))
!(test (math-ratio -0.0) (0 1))
!(test (math-ratio (math-rationalize 0.1)) (1 10))
!(test (math-rationalize 42) 42)
!(test (math-ratio (math-rationalize (math-rational 2 3))) (2 3))

; Roots and modular powers never pass through a float or build the full power.
!(test (math-integer-root 2 101) (10 1))
!(test (math-integer-root 3 -28) (-3 -1))
!(test (math-integer-root 1 -42) (-42 0))
!(test (math-integer-root 2 340282366920938463463374607431768211456) (18446744073709551616 0))
!(test (math-power-mod 2 100 1000) 376)
!(test (math-power-mod -2 3 5) 2)
!(test (math-power-mod 42 0 1) 0)
!(test (collapse (math-factor-pairs 1)) ((1 1)))
!(test (collapse (math-factor-pairs 36)) ((1 36) (2 18) (3 12) (4 9) (6 6)))
!(test (once (math-factor-pairs 36)) (1 36))

; Take a floating root before rounding its exact input, retaining signed zero.
!(test (math-sqrt 4) 2.0)
!(test (math-sqrt (bit-shift-left 1 2000)) (math-float (bit-shift-left 1 1000)))
!(test (math-sqrt (math-rational 1 (bit-shift-left 1 2000)))
       (math-float (math-rational 1 (bit-shift-left 1 1000))))
!(test (math-real copysign (1.0 (math-sqrt -0.0))) -1.0)
!(test (if-error (catch (math-sqrt -1)) refused fine) refused)
!(test (if-error (catch (math-sqrt (math-real inf ()))) refused fine) refused)

; Scalar conversion shares Vector's final rounding and signed-zero policy.
!(test (math-float (math-rational 1 10)) 0.1)
!(test (math-class (math-float 1)) normal)
!(test (math-class (math-float -0.0)) zero)
!(test (math-real copysign (1.0 (math-float -0.0))) -1.0)
!(test (math-class (math-float (math-rational 18014398509481985 (bit-shift-left 1 1129)))) subnormal)
!(test (math-class (math-float (bit-shift-left 1 2000))) infinite)

; The catalog states arity, including constants with no arguments. One dispatch
; form covers the selected native functions while core arithmetic keeps its names.
!(test (size-atom (math-real-functions)) 20)
!(test (math-real sinh (0)) 0.0)
!(test (math-real cosh (0)) 1.0)
!(test (math-real tanh (0)) 0.0)
!(test (math-real asinh (0)) 0.0)
!(test (math-real acosh (1)) 0.0)
!(test (math-real atanh (0)) 0.0)
!(test (math-real log10 (100)) 2.0)
!(test (math-real erf (0)) 0.0)
!(test (math-real erfc (0)) 1.0)
!(test (math-real lgamma (1)) 0.0)
!(test (math-real atan2 (1 1)) (/ (math-real pi ()) 4))
!(test (math-real nexttoward (1.0 2.0)) 1.0000000000000002)
!(test (math-real float_integer_part (-1.75)) -1.0)
!(test (math-real float_fractional_part (-1.75)) -0.75)
!(test (< 2.7 (math-real e ())) True)
!(test (math-real epsilon ()) 2.220446049250313e-16)
!(test (math-class (math-real inf ())) infinite)
!(test (math-class (math-real nan ())) nan)

; Boundary errors identify an invalid domain, function or argument shape.
!(test (if-error (catch (math-gcd (1 2.5))) refused fine) refused)
!(test (if-error (catch (math-lcm (0 2.5))) refused fine) refused)
!(test (if-error (catch (math-rational 1 0)) refused fine) refused)
!(test (if-error (catch (math-ratio (math-real inf ()))) refused fine) refused)
!(test (if-error (catch (math-rationalize (math-real nan ()))) refused fine) refused)
!(test (if-error (catch (math-integer-root 0 5)) refused fine) refused)
!(test (if-error (catch (math-integer-root 2 -1)) refused fine) refused)
!(test (if-error (catch (math-power-mod 2 -1 5)) refused fine) refused)
!(test (if-error (catch (math-power-mod 2 3 0)) refused fine) refused)
!(test (if-error (catch (math-factor-pairs 0)) refused fine) refused)
!(test (if-error (catch (math-real missing (1))) refused fine) refused)
!(test (if-error (catch (math-real atan2 (1))) refused fine) refused)
!(test (if-error (catch (math-real erf ("x"))) refused fine) refused)
!(test (if-error (catch (math-real acosh (0))) refused fine) refused)
