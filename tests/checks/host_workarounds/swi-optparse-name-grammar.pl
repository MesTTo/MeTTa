% Purpose: detect declared names ignored and unknown dashed tokens accepted.
% [tested: sh tools/check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Spec=[[opt(count),type(integer),longflags([count,count2,'9?'])]],
    opt_parse(Spec,['--count=7'],Control,[],[]),
    (Control==[count(7)]->true;throw(control_failed(Control))),
    opt_parse(Spec,['--count2=7'],Digit,DigitRest,[]),
    opt_parse(Spec,['--9?=7'],Mark,MarkRest,[]),
    catch(opt_parse(Spec,['--bad?'],_,BadRest,[]),Unknown,true),
    ( Digit==[count(7)],DigitRest==[],Mark==[count(7)],MarkRest==[],nonvar(Unknown)
    -> writeln(absent)
    ; (DigitRest==['--count2=7'];MarkRest==['--9?=7'];
       var(Unknown),BadRest==['--bad?']) -> writeln(present)
    ; throw(unexpected_names(Digit,DigitRest,Mark,MarkRest,Unknown,BadRest)) ).
