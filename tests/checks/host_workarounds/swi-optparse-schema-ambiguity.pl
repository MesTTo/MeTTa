% Purpose: detect acceptance of identical duplicate option declarations.
% [tested: sh check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Row=[opt(count),type(integer),longflags([count])],
    opt_parse([Row],['--count=7'],Control,[],[]),
    (Control==[count(7)]->true;throw(control_failed(Control))),
    catch(opt_parse([Row,Row],['--count=7'],Actual,Rest,[]),Error,true),
    ( nonvar(Error) -> writeln(absent)
    ; Actual==[count(7)],Rest==[] -> writeln(present)
    ; throw(unexpected_duplicates(Actual,Rest)) ).
