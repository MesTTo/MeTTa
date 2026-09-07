% Purpose: which clock a trace event's `time` should read, and what each
%   costs. SWI's `statistics(cputime, X)` is thread-local, which a tracer that
%   records hyperpose WORKER events cannot use: the worker's reading starts
%   near zero beside the main thread's. `statistics(process_cputime, X)` is
%   monotone across threads, and `get_time/1` is the wall clock. This prints
%   both facts: a worker's two readings beside the main thread's, and the cost
%   of 200,000 reads of each.
% Run: cd <worktree> && swipl -q tests/prolog/probes/tracer/clock_cost.pl
% Measured 2026-09-07 on this box, loadavg 60-70: cputime is thread-local
%   (worker 0.000089 against main 0.048904), process_cputime 1712.5 ns a read,
%   cputime 378.8, get_time 476.7 and statistics(inferences) 708.4. The tracer
%   reads get_time/1: monotone across the threads it records from, cheapest of
%   the two that are, and what an OpenTelemetry span and a Perfetto row both
%   want [engine/tracer.pl, metta_trace_time/1].
:- initialization(main, main).

worker :-
    statistics(cputime, C), statistics(process_cputime, P),
    format("worker: cputime=~6f process_cputime=~6f~n", [C, P]),
    forall(between(1, 300000, _), _ is random_float),
    statistics(cputime, C2), statistics(process_cputime, P2),
    format("worker after work: cputime=~6f process_cputime=~6f~n", [C2, P2]).

bench(Goal, N, Ns) :-
    get_time(S),
    forall(between(1, N, _), call(Goal)),
    get_time(E),
    Ns is (E - S) / N * 1.0e9.

main :-
    forall(between(1, 300000, _), _ is random_float),
    statistics(cputime, C), statistics(process_cputime, P),
    format("main: cputime=~6f process_cputime=~6f~n", [C, P]),
    thread_create(worker, T, []), thread_join(T, _),
    bench(statistics(cputime, _), 200000, N1),
    format("cputime         ~1f ns~n", [N1]),
    bench(statistics(process_cputime, _), 200000, N2),
    format("process_cputime ~1f ns~n", [N2]),
    bench(statistics(inferences, _), 200000, N3),
    format("inferences      ~1f ns~n", [N3]),
    bench(get_time(_), 200000, N4),
    format("get_time        ~1f ns~n", [N4]).
