% Purpose: detect implicit NUL membership in the host's String splitter.
% Guarantees: a failed ordinary control or an unexpected result refuses a verdict.
% [tested: sh check.sh host-workarounds host-workarounds-selftest; commit=WORKTREE].

main :-
    ( split_string("a,b", ",", "", ["a","b"]) -> true
    ; throw(error(string_split_control_failed, _)) ),
    string_codes(Text, [97,0,98]), split_string(Text, ",", "", Parts),
    ( Parts == [Text] -> writeln(absent)
    ; Parts == ["a","b"] -> writeln(present)
    ; throw(error(unexpected_string_split_result(Parts), _)) ).
