% Purpose: detect native option parsing after the argument terminator.
% [tested: sh tools/check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Spec=[[opt(text),type(atom),longflags([text])]],
    opt_parse(Spec,['--text',literal],Control,[],[]),
    (Control==[text(literal)]->true;throw(control_failed(Control))),
    opt_parse(Spec,['--','--text',literal],Actual,Rest,[]),
    ( Rest==['--text',literal],Actual=[text(Value)],var(Value) -> writeln(absent)
    ; Actual==[text(literal)],Rest==['--'] -> writeln(present)
    ; throw(unexpected_separator(Actual,Rest)) ).
