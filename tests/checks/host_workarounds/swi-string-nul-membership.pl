% Purpose: detect implicit NUL membership in the host's String splitter.
% Guarantees: a failed ordinary control or an unexpected result refuses a verdict.
% [tested: sh check.sh host-workarounds host-workarounds-selftest; commit=3aaad3435292e4c7d5cc3a01bfda39430aacc6e8].

main :-
    ( split_string("a,b", ",", "", ["a","b"]) -> true
    ; throw(error(string_split_control_failed, _)) ),
    string_codes(Text, [97,0,98]), split_string(Text, ",", "", Parts),
    ( Parts == [Text] -> writeln(absent)
    ; Parts == ["a","b"] -> writeln(present)
    ; throw(error(unexpected_string_split_result(Parts), _)) ).
