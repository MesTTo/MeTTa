% Purpose: detect double rounding at the host's rational-to-subnormal boundary.
% Guarantees: exact normal and subnormal controls distinguish an active defect,
% a repaired conversion and an unexpected arithmetic result.
% [tested: sh check.sh host-workarounds host-workarounds-selftest; commit=WORKTREE].

main :-
    Normal is float(3 rdiv 2), Smallest is 2.0** -1074,
    ExactSmallest is float(1 rdiv (1<<1074)),
    ( Normal =:= 1.5, Smallest > 0.0, ExactSmallest =:= Smallest -> true
    ; throw(error(rational_rounding_control_failed, _)) ),
    AboveHalf is ((1<<54)+1) rdiv (1<<1129), Actual is float(AboveHalf),
    ( Actual =:= 0.0 -> writeln(present)
    ; Actual =:= Smallest -> writeln(absent)
    ; throw(error(unexpected_rational_rounding(Actual), _)) ).
