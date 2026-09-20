% Purpose: detect printed conversion context omitted from the actual exception.
% [tested: sh tools/check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Spec=[[opt(count),type(integer),longflags([count])]],
    opt_parse(Spec,['--count','7'],Control,[],[]),
    (Control==[count(7)]->true;throw(control_failed(Control))),
    with_output_to(string(Printed),
        catch(opt_parse(Spec,['--count','bad'],_,_,[]),Error,true)),
    (nonvar(Error)->true;throw(missing_value_error)),
    term_string(Error,Description),
    ( Printed=="",sub_string(Description,_,_,_,"count") -> writeln(absent)
    ; sub_string(Printed,_,_,_,"count"),\+sub_string(Description,_,_,_,"count")
    -> writeln(present)
    ; throw(unexpected_value_report(Printed,Description)) ).
