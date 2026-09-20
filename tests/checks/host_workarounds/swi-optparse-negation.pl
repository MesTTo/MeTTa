% Purpose: detect duplicated values from one negated Boolean option.
% [tested: sh tools/check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Spec=[[opt(verbose),type(boolean),longflags([verbose])]],
    Options=[duplicated_flags(keepall)],
    opt_parse(Spec,['--verbose=false'],Control,[],Options),
    (Control==[verbose(false)]->true;throw(control_failed(Control))),
    opt_parse(Spec,['--no-verbose'],Actual,[],Options),
    ( Actual==[verbose(false)] -> writeln(absent)
    ; Actual==[verbose(false),verbose(false)] -> writeln(present)
    ; throw(unexpected_negation(Actual)) ).
