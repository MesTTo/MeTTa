% Purpose: detect conflation of a missing option value with an empty argument.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
:- use_module(library(optparse), [opt_parse/5]).
main :-
    Spec=[[opt(text),type(atom),longflags([text])]],
    opt_parse(Spec,['--text',''],Control,[],[]),
    (Control==[text('')]->true;throw(control_failed(Control))),
    catch(opt_parse(Spec,['--text'],Actual,Rest,[]),Error,true),
    ( nonvar(Error) -> writeln(absent)
    ; Actual==[text('')],Rest==[] -> writeln(present)
    ; throw(unexpected_missing_value(Actual,Rest)) ).
