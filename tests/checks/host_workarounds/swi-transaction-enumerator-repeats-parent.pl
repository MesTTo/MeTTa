% Purpose: detect repeated parent answers from current_transaction/1.
% Guarantees: the last line is present when two transactions produce a third
%   answer, absent when enumeration stops after the two active transactions
%   [tested: sh check.sh host-workarounds;
%   commit=WORKTREE].
% Owns resources: both empty transactions finish before the result is printed.

main :-
    transaction(transaction(once(findnsols(3, true, current_transaction(_), Rows)))),
    ( Rows == [true,true,true] -> writeln(present)
    ; Rows == [true,true] -> writeln(absent)
    ; throw(error(unexpected_transaction_enumeration(Rows), none)) ).
