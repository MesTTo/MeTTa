% Purpose: expose an aborted assertion revived by a later transaction.
% Assumes: plain SWI-Prolog, with no repository engine or workaround loaded.
% Guarantees: the last line is present exactly when the aborted row returns
%   [tested: sh check.sh host-workarounds; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
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
