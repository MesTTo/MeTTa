% Purpose: detect pathname canonicalization dropping a NUL and its suffix.
% Guarantees: a normal relative-path control remains intact; present requires
% truncation to that control. [tested: sh check.sh host-workarounds; commit=WORKTREE].

:- use_module(library(lists), [memberchk/2]).

main :-
    absolute_file_name("plain",Control,[expand(false)]),sub_atom(Control,_,5,0,plain),
    string_codes(Text,[112,108,97,105,110,0,115,117,102,102,105,120]),
    catch(absolute_file_name(Text,Actual,[expand(false)]),Error,true),
    ( nonvar(Error) -> writeln(absent)
    ; Actual==Control -> writeln(present)
    ; atom_codes(Actual,Codes),memberchk(0,Codes) -> writeln(absent)
    ; throw(error(absolute_path_nul_probe(Actual),_)) ).
