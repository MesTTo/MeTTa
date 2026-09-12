% Purpose: detect Latin-1 and NUL truncation at the OSSP UUID name boundary.
% Guarantees: the ASCII control and UTF-8/NUL vectors identify a corrected host.
% [tested: sh check.sh host-workarounds; commit=d5de00cc183b4b395b552f3aae7fca87752ef38c].

:- use_module(library(uuid), [uuid/2]).

main :-
    uuid(Control, [version(5), dns('example.com')]),
    ( Control == 'cfbff0d1-9375-5685-968c-48ce8b15ae17' -> true
    ; throw(error(uuid_name_control_failed(Control), _)) ),
    atom_codes(Nul, [97,0,98]),
    uuid(NulResult, [version(5), dns(Nul)]),
    atom_codes(AccentName, [233]),
    uuid(Accent, [version(5), dns(AccentName)]),
    ( NulResult == '0a63f66b-e02f-5d2d-9fd4-aad819cf5352',
      Accent == 'ebfe0af8-3997-5ade-b634-ba92cf69f557' -> writeln(absent)
    ; ( NulResult == '4f3f2898-69e3-5a0d-820a-c4e87987dbce'
      ; Accent == '61372fd7-1aa6-5e91-8e3e-c1e3ecc18450' ) -> writeln(present)
    ; throw(error(unexpected_uuid_name_results(NulResult, Accent), _)) ).
