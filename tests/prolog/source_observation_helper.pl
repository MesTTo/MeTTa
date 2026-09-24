% Purpose: compare source observations in an explicitly owned execution context.
% Guarantees: retain program output, answers, coverage and every source error
%   frame; two observations of one source compare equal row for row with
%   library(prolog_stack) loaded and its backtraces on, because the observer
%   stores each error and exception as raised, its variables numbered
%   [tested 2026-09-25T04:02:23+10:00: source_runnable_envelope, compiled_typing_rules].
% Owns resources: release the fixture space and restore loader output after
%   success, failure or an exception.

:- module(source_observation_helper, [source_run_observation/4]).
% Loaded so every comparison runs with prolog_stack's exception hook present,
% the state NO_AUTOLOAD=1 and any printed backtrace leave a process in.
:- use_module(library(prolog_stack), []).

source_run_observation(Label, Source, Rows, Output) :-
    metta_engine:metta_ensure_source_observation,
    setup_call_cleanup(
        (spaces:'new-space'(Space), spaces:space_module(Space, Module),
         asserta(filereader:silent(true), Silent)),
        with_output_to(string(Output),
            metta_engine:with_metta_module(Module,
                source_observation:observe_source(Space, Label, Source, Rows))),
        (spaces:metta_release_space(Space), erase(Silent))).
