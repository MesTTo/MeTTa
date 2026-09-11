% Purpose: detect lost numerator signs when the host divides signed zero by infinity.
% Guarantees: finite division and all four infinite-divisor signs distinguish
% an active defect, a repaired implementation and an unexpected result.
% [tested: sh check.sh host-workarounds host-workarounds-selftest; commit=615e8a68dce996a0c05b3ddddc71b80bc598442d].

:- use_module(library(apply), [maplist/3]).

main :-
    A is -0.0 / -1.0, B is -0.0 / 1.0,
    ( copysign(1.0,A) =:= 1.0, copysign(1.0,B) =:= -1.0 -> true
    ; throw(error(zero_sign_control_failed, _)) ),
    C is -0.0 / -1.0Inf, D is -0.0 / 1.0Inf,
    E is 0.0 / -1.0Inf, F is 0.0 / 1.0Inf,
    Signs = [C,D,E,F], maplist(sign, Signs, Actual),
    ( Actual == [-1.0,1.0,-1.0,1.0] -> writeln(present)
    ; Actual == [1.0,-1.0,-1.0,1.0] -> writeln(absent)
    ; throw(error(unexpected_infinite_division_signs(Actual), _)) ).

sign(Value, Sign) :- Sign is copysign(1.0, Value).
