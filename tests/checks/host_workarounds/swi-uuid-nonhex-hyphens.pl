% Purpose: detect hyphens accepted as UUID hexadecimal digits.
% Guarantees: valid and malformed controls distinguish a repaired validator.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].

:- use_module(library(uuid), [is_uuid/1]).

main :-
    ( is_uuid('cfbff0d1-9375-5685-968c-48ce8b15ae17'),
      \+ is_uuid('zfbff0d1-9375-5685-968c-48ce8b15ae17') -> true
    ; throw(error(uuid_validation_control_failed, _)) ),
    ( is_uuid('------------------------------------') -> writeln(present)
    ; writeln(absent) ).
