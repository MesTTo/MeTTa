% Purpose: detect conflation of separate short and long option namespaces.
% [tested: sh check.sh host-workarounds; commit=83b7589a6766210414ceca14dfb9846b28c2ef78].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    First=[opt(one),type(integer),shortflags([x])],
    opt_parse([First,[opt(two),type(integer),longflags([y])]],
              ['-x','1','--y','2'],Control,[],[]),
    (Control==[one(1),two(2)]->true;throw(control_failed(Control))),
    catch(opt_parse([First,[opt(two),type(integer),longflags([x])]],
                    ['-x','1','--x','2'],Actual,Rest,[]),Error,true),
    ( var(Error),Actual==[one(1),two(2)],Rest==[] -> writeln(absent)
    ; nonvar(Error),Error=error(domain_error(unique_atom,x),_) -> writeln(present)
    ; throw(unexpected_namespaces(Actual,Rest,Error)) ).
