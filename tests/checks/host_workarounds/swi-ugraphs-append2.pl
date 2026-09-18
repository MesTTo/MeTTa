% Purpose: detect top_sort/2's missing append/2 import with autoload disabled.
% Guarantees: only the missing import counts as present; the explicit import
% must restore the independently known topological order.
% [tested: sh check.sh host-workarounds; commit=95ed74d83453b1fa3a24629ca914656b76d610b4].

:- use_module(library(ugraphs), [top_sort/2]).

main :-
    set_prolog_flag(autoload, false),
    Graph = [a-[b], b-[]],
    catch(top_sort(Graph, Order), Error, true),
    (   var(Error)
    ->  ( Order == [a,b] -> writeln(absent)
        ; throw(error(unexpected_topological_order(Order), _)) )
    ;   Error = error(existence_error(procedure,ugraphs:append/2),_)
    ->  ugraphs:use_module(library(lists), [append/2]),
        top_sort(Graph, Fixed),
        ( Fixed == [a,b] -> writeln(present)
        ; throw(error(unexpected_topological_order(Fixed), _)) )
    ;   throw(Error)
    ).
