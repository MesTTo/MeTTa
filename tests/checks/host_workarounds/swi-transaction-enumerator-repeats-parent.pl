% Purpose: detect repeated parent answers from current_transaction/1.
% Guarantees: the last line is present when two transactions produce a third
%   answer, absent when enumeration stops after the two active transactions
%   [tested: sh check.sh host-workarounds;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=0d35a802f4dcec1185798fd017db744ab3a3d66f].
% Owns resources: both empty transactions finish before the result is printed.

main :-
    transaction(transaction(once(findnsols(3, true, current_transaction(_), Rows)))),
    ( Rows == [true,true,true] -> writeln(present)
    ; Rows == [true,true] -> writeln(absent)
    ; throw(error(unexpected_transaction_enumeration(Rows), none)) ).
