% Purpose: run the source-error example after a cold and an artifact engine boot.
% Owns resources: child processes are joined by process_create/3; each log is
%   closed and removed. This serial suite purges the checkout's governed QLFs.
% Guarantees: the second shipping runner preserves the observed arithmetic
%   while retaining the warmed engine and observer artifacts [tested:
%   source_observation_artifacts; commit=WORKTREE].
:- use_module(library(process)).
:- use_module(library(readutil), [read_file_to_string/3]).

:- begin_tests(source_observation_artifacts).

artifact_process(Root, Program, Arguments) :-
    setup_call_cleanup(
        tmp_file_stream(text, Log, Stream),
        ( catch(process_create(path(Program), Arguments,
                    [cwd(Root), stdout(stream(Stream)), stderr(stream(Stream))]),
                Error, true),
          flush_output(Stream),
          ( var(Error) -> true
          ; read_file_to_string(Log, Output, []),
            format(user_error, '~s', [Output]),
            throw(Error) ) ),
        ( close(Stream), delete_file(Log) )).

artifact_times(Root, EngineTime-ObserverTime) :-
    directory_file_path(Root, 'engine/metta.qlf', Engine),
    directory_file_path(Root, 'engine/source_observation.qlf', Observer),
    time_file(Engine, EngineTime),
    time_file(Observer, ObserverTime).

test(the_second_shipping_boot_preserves_observed_arithmetic) :-
    source_file(artifact_process(_, _, _), File),
    file_directory_name(File, Directory),
    absolute_file_name('../../../../', Root,
                       [relative_to(Directory), file_type(directory)]),
    artifact_process(Root, find, [engine, lib, '-name', '*.qlf', '-delete']),
    Example = 'examples/ch20-extending-the-engine/20-05-observing-execution/03-source-errors.metta',
    artifact_process(Root, sh, ['run.sh', Example]),
    artifact_times(Root, Warmed),
    artifact_process(Root, sh, ['run.sh', Example]),
    artifact_times(Root, Warmed).

:- end_tests(source_observation_artifacts).
