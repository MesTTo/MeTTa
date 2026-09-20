% Purpose: detect NUL truncation in the host's ISub boundary and core.
% Guarantees: the identity control and exact expected scores distinguish a
% live defect, a repaired provider and an unexpected result.
% [tested: sh tools/check.sh host-workarounds host-workarounds-selftest; commit=3aaad3435292e4c7d5cc3a01bfda39430aacc6e8].

:- use_module(library(isub), [isub/4]).

main :-
    ( isub("abc", "abc", Identity,
           [normalize(false),zero_to_one(false),substring_threshold(0)]),
      Identity =:= 1.0 -> true
    ; throw(error(isub_identity_control_failed, _)) ),
    string_codes(Text, [97,0,98]),
    isub(Text, "a", Score,
         [normalize(false),zero_to_one(false),substring_threshold(0)]),
    ( Score =:= 1.0 -> writeln(present)
    ; abs(Score-0.55) < 1.0e-12 -> writeln(absent)
    ; throw(error(unexpected_isub_result(Score), _)) ).
