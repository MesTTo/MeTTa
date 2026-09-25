% Purpose: show whether a transaction still sees a dynamic predicate's row,
%   erased after the transaction started, when its call reads through a
%   clause index built after the erase: the first index on an argument, and
%   one rebuilt after the predicate grew past its resize bound, each after a
%   plain erase and after a committed transaction's erase.
% Assumes: engines. The erase and the index build run in a second engine the
%   transaction drives, and each engine has a transaction of its own, so both
%   are global the way another thread's are; a host without threads answers
%   too.
% Guarantees: the last line is present only when the transaction's indexed
%   call misses the erased row in all four cases, and absent only when it
%   finds it in all four; in every case the second engine's own indexed call
%   must miss the row and the transaction's walk of the clause list
%   (nth_clause/3 with '$clause'/4) must still admit it, and anything else
%   throws
%   [measured 2026-09-25T12:59:17+10:00: present on SWI-Prolog 10.1.14 as
%   shipped (/usr/bin/swipl, compiled Aug 30 2026, 09:21:19) and with the
%   ledger's earlier patches (compiled Sep 24 2026, 16:08:19); absent with
%   those and
%   tests/checks/host_workarounds/swi-index-built-after-erase-hides-older-views.patch
%   (compiled Sep 25 2026, 12:27:40); from 12:59:33 on the WebAssembly host,
%   present on build 9 (compiled Sep 24 2026, 06:12:34) and absent on build
%   10 (compiled Sep 25 2026, 02:32:38); three runs each;
%   command=swipl -q -f none -s FILE -g main -t halt].
% Owns resources: each case's second engine, destroyed when its goal
%   answers; the fixture rows, withdrawn after each case.

:- dynamic view_row/2.
:- use_module(library(lists), [member/2]).

main :-
    findall(Result,
            ( member(Build, [first, rebuilt]),
              member(Erase, [plain, transaction]),
              check(Build, Erase, Result) ),
            Results),
    sort(Results, Unique),
    (   Unique = [Result]
    ->  writeln(Result)
    ;   throw(error(inconsistent_index_view_results(Results), none))
    ).

check(Build, Erase, Result) :-
    setup_call_cleanup(
        forall(between(1, 16, I), assertz(view_row(I, I))),
        observe(Build, Erase, Result),
        retractall(view_row(_, _))).

observe(Build, Erase, Result) :-
    (   Build == rebuilt
    ->  \+ view_row(_, 0)                % an argument-2 index exists at the erase
    ;   true
    ),
    transaction(( in_engine(erase_and_index(Build, Erase)),
                  findall(I, view_row(I, 8), Indexed),
                  findall(I, ( nth_clause(view_row(_, _), _, Ref),
                               '$clause'(view_row(I, 8), true, Ref, _) ),
                          Walked) )),
    (   Walked == [8]
    ->  true
    ;   throw(error(snapshot_retention_changed(Build, Erase, Walked), none))
    ),
    (   Indexed == [8]
    ->  Result = absent
    ;   Indexed == []
    ->  Result = present
    ;   throw(error(unexpected_indexed_rows(Build, Erase, Indexed), none))
    ).

% The second engine's work. Its erase finds row 8 by argument 1, so it builds
% no argument-2 index; its call after the erase builds one.
erase_and_index(Build, Erase) :-
    once(clause(view_row(8, 8), true, Ref)),
    erase_row(Erase, Ref),
    (   Build == rebuilt                 % past resize_above, which deletes it
    ->  forall(between(17, 64, I), assertz(view_row(I, I)))
    ;   true
    ),
    (   view_row(_, 8)
    ->  throw(error(erase_not_seen_by_eraser(Build, Erase), none))
    ;   true
    ).

erase_row(plain, Ref) :-
    erase(Ref).
erase_row(transaction, Ref) :-
    transaction(erase(Ref)).

in_engine(Goal) :-
    setup_call_cleanup(engine_create(done, Goal, Engine),
                       engine_next(Engine, done),
                       engine_destroy(Engine)).
