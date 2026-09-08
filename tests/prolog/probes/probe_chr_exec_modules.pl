% Purpose: measure CHR compilation, isolation and absence wakeup in execution modules.
% Assumes: engine/metta.pl and SWI-Prolog 10.1.13's library(chr).
% Guarantees: every printed result is checked, and a mismatch throws [measured:
%   2026-09-08, 12 checked results;
%   command=swipl -q -g main -t halt tests/prolog/probes/probe_chr_exec_modules.pl;
%   fixture=two native execution modules on SWI-Prolog 10.1.13; commit=8806bbf1f5fb8ff233e2ed4868190757d4fb7041].
% Owns resources: closes source streams, joins its worker, clears both constraint
%   stores, unloads both compiled programs and releases both spaces on exit.
% Decides: this is a module integration probe; it does not implement run-rules.
:- module(chr_exec_probe, [main/0]).
:- use_module('../../../engine/metta').

% The gcd simpagation uses the shipped CHR example's Euclidean remainder.
% https://github.com/SWI-Prolog/packages-chr/blob/08f42a653c0d2d13e6d7841fa8889113384f904c/Examples/gcd.chr
program("\
:- use_module(library(chr)).\n\
:- chr_constraint gcd/1, candidate/1, blocker/1, remove_blocker/1, scan/1, emitted/1, clear/0.\n\
gcd(0) <=> true.\n\
gcd(N) \\ gcd(M) <=> N =< M | L is M mod N, gcd(L).\n\
scan(_), candidate(X) ==> \\+ current_chr_constraint(blocker(X)) | emitted(X).\n\
remove_blocker(X), blocker(X) <=> true.\n\
clear \\ gcd(_) <=> true.\n\
clear \\ candidate(_) <=> true.\n\
clear \\ blocker(_) <=> true.\n\
clear \\ remove_blocker(_) <=> true.\n\
clear \\ scan(_) <=> true.\n\
clear \\ emitted(_) <=> true.\n\
clear <=> true.\n").

load_program(Space, Module) :-
    spaces:space_module(Space, Module),
    program(Text),
    setup_call_cleanup(open_string(Text, Stream),
                       load_files(Module:Module, [stream(Stream), silent(true)]),
                       close(Stream)).

expect(Name, Actual, Expected) :-
    ( Actual == Expected -> format('~w: ~q~n', [Name, Actual])
    ; throw(error(assertion_error(Name, Actual, Expected), main/0)) ).

rows(Module, Pattern, Rows) :-
    findall(Pattern, chr:current_chr_constraint(Module:Pattern), Bag),
    msort(Bag, Rows).

probe(A, B) :-
    load_program('&aq-chr-a', A),
    load_program('&aq-chr-b', B),
    call(A:gcd(18)), call(A:gcd(24)), call(A:gcd(18)),
    call(B:gcd(35)), call(B:gcd(14)),
    rows(A, gcd(_), GcdA), expect(gcd_a, GcdA, [gcd(6)]),
    rows(B, gcd(_), GcdB), expect(gcd_b, GcdB, [gcd(7)]),
    findall(gcd(N), chr:find_chr_constraint(gcd(N)), Global),
    msort(Global, SortedGlobal),
    expect(deprecated_enumerator_crosses_modules, SortedGlobal, [gcd(6),gcd(7)]),
    setup_call_cleanup(
        thread_create((rows(A, gcd(_), ThreadRows), ThreadRows == []), Thread, []),
        true,
        thread_join(Thread, Status)),
    expect(other_thread_store, Status, true),
    findall(X, spaces:'get-atoms'('&aq-chr-a', X), Native),
    expect(chr_is_not_native_storage, Native, []),
    call(A:blocker(a)), call(A:candidate(a)), call(A:scan(1)),
    rows(A, emitted(_), Blocked), expect(absence_blocked, Blocked, []),
    call(A:remove_blocker(a)),
    rows(A, emitted(_), Removed), expect(removal_does_not_wake, Removed, []),
    call(A:scan(2)),
    rows(A, emitted(_), Woken), expect(fresh_scan_wakes, Woken, [emitted(a)]),
    call(A:scan(3)),
    rows(A, emitted(_), Repeated),
    expect(new_scan_repeats_propagation, Repeated, [emitted(a), emitted(a)]),
    call(A:clear), call(B:clear),
    rows(A, _, LeftA), rows(B, _, LeftB),
    expect(cleanup_a, LeftA, []), expect(cleanup_b, LeftB, []).

cleanup(Space, Module) :-
    ( nonvar(Module)
    -> ( current_predicate(Module:clear/0) -> call(Module:clear) ; true ),
       unload_file(Module)
    ; true ),
    spaces:metta_release_space(Space).

main :-
    current_prolog_flag(version_data, Version), writeln(Version),
    setup_call_cleanup(
        (spaces:space_module('&aq-chr-a', A), spaces:space_module('&aq-chr-b', B)),
        probe(A, B),
        (cleanup('&aq-chr-a', A), cleanup('&aq-chr-b', B))),
    findall(M, (member(M,[A,B]), current_predicate(M:gcd/1)), Loaded),
    expect(unloaded_programs, Loaded, []).
