% Purpose: expose an aborted assertion revived by a later transaction.
% Assumes: plain SWI-Prolog, with no repository engine or workaround loaded.
% Guarantees: the last line is present exactly when the aborted row returns
%   [tested: sh tools/check.sh host-workarounds; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.patch;
%   command=sh tools/check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=7ead07e090b85ad2b541fc271dd59b4d8faaf636].
:- dynamic row/1, clock/1.

main :-
    (   transaction(( assertz(row(aborted), Ref),
                      transaction(erase(Ref)),
                      fail ))
    ->  throw(error(unexpected_transaction_commit, main/0))
    ;   true
    ),
    findall(X, row(X), Outside),
    ( Outside == [] -> true ; throw(error(unexpected_visible_rows(Outside), main/0)) ),
    transaction(( forall(between(1, 100, N), assertz(clock(N))),
                  findall(X, row(X), Inside) )),
    (   Inside == [aborted]
    ->  writeln(present)
    ;   Inside == []
    ->  writeln(absent)
    ;   throw(error(unexpected_visible_rows(Inside), main/0))
    ).
