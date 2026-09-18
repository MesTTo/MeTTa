% Purpose: per-predicate call counts of one engine benchmark case, written as
%   one TSV, so two trees can be diffed predicate by predicate. The inference
%   total is the VM counter around the same bench_work/3 the benchmark
%   measures; the profiler's own ports are not inferences, though its
%   presence moves the count, so the number is for diffing two profiled
%   trees, never for a pin.
% Assumes: argv is [Root, Case, Out]; Root holds engine/bench.pl; no DISPLAY,
%   or library(prolog_profile) opens its window.
% Guarantees: the first line of Out is `inferences<TAB>N`, every other line
%   `Calls<TAB>Module:Name/Arity`, calls descending.
:- use_module(library(prolog_profile)).
:- initialization(main, main).

main([Root, Case, Out]) :-
    directory_file_path(Root, 'engine/bench.pl', Bench), consult(Bench),
    metta_bench:bench_setup(Case, State),
    statistics(inferences, I0),
    profile(metta_bench:bench_work(Case, State, Result), [top(0)]),
    statistics(inferences, I1),
    Spent is I1 - I0,
    metta_bench:bench_check(Case, Result),
    profile_data(Data),
    get_dict(nodes, Data, Nodes),
    findall(Call-Pred, ( member(N, Nodes), get_dict(predicate, N, Pred),
                         get_dict(call, N, Call), Call > 0 ), Pairs),
    msort(Pairs, Sorted0), reverse(Sorted0, Sorted),
    setup_call_cleanup(open(Out, write, S),
        ( format(S, "inferences\t~d~n", [Spent]),
          forall(member(C-P, Sorted), format(S, "~d\t~q~n", [C, P])) ),
        close(S)),
    format("~w inferences ~d written ~w~n", [Case, Spent, Out]).
