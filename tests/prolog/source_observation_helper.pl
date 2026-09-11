% Purpose: compare source observations in an explicitly owned execution context.
% Guarantees: retain program output, answers, coverage and every source error
%   frame; compare serialized host exceptions by variable identity
%   [tested: source_runnable_envelope, compiled_typing_rules; commit=WORKTREE].
% Owns resources: release the fixture space and restore loader output and the
%   optional host backtrace flag after success, failure or an exception.

:- module(source_observation_helper, [source_run_observation/4]).
:- use_module(library(prolog_stack), []).

source_run_observation(Label, Source, Rows, Output) :-
    metta_engine:metta_ensure_source_observation,
    current_prolog_flag(backtrace, Backtrace),
    setup_call_cleanup(
        (spaces:'new-space'(Space), spaces:space_module(Space, Module),
         asserta(filereader:silent(true), Silent),
         set_prolog_flag(backtrace, false)),
        with_output_to(string(Output),
            metta_engine:with_metta_module(Module,
                ( source_observation:observe_source(Space, Label, Source, Raw),
                  maplist(source_observation_helper:observation_term, Raw, Rows) ))),
        (spaces:metta_release_space(Space), erase(Silent),
         set_prolog_flag(backtrace, Backtrace))).

% Host backtraces contain allocation addresses and stack depths. The optional
% host backtrace is disabled above; MeTTa source frames remain in the rows.
% Serialized exception variables still need the same variant comparison as
% answer terms, rather than a comparison of their printed allocation numbers.
observation_term(['source-error', Id, Text], ['source-error', Id, Term]) :-
    string(Text), !, term_string(Term, Text).
observation_term(['observation-exception', Text], ['observation-exception', Term]) :-
    !, term_string(Term, Text).
observation_term(Row, Row).
