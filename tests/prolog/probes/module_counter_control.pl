% Purpose: measure one added module-resolution link over the shipped workload.
% Assumes: one measure_module_lookup/2 call per process after provisioning the engine artifacts
% [source: engine/bench.pl:bench_setup/2; commit=WORKTREE].
% Decides: extra_link adds one empty base between metta_engine and user
% [source: tests/prolog/probes/module_counter_control.pl:module_counter_perturb/1; commit=WORKTREE].
:- module(module_counter_control, [measure_module_lookup/2]).
:- use_module('../../../engine/bench', []).

measure_module_lookup(Case, Mode) :-
    metta_bench:bench_setup(Case, State),
    module_counter_perturb(Mode),
    metta_bench:bench_timed(Case, State, Result, Inferences, Cpu, Wall),
    metta_bench:bench_check(Case, Result),
    format('~w ~w inferences=~d cpu=~f wall=~f~n',
           [Case, Mode, Inferences, Cpu, Wall]).

module_counter_perturb(unchanged).
module_counter_perturb(extra_link) :-
    set_module(module_counter_padding:base(user)),
    set_module(metta_engine:base(module_counter_padding)).
