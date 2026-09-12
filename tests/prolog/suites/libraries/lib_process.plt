% Purpose: check that a run's exit code is a status rather than an error, that the
% pipes a captured run opens it closes, that a started process is watched, signalled
% and waited for through its identifier, and that a program which is not there is
% named.
% Guarantees: a nonzero exit and a signalled death both answer a Number, a run whose
% output is larger than a pipe's buffer completes and leaves no descriptor behind, a
% started process answers `running` until it is signalled and its code afterwards,
% and every refusal names what it was given [tested: lib_process; commit=WORKTREE].
% Owns resources: every process this suite starts it waits for, and every stream the
% library opens it closes; the suite checks the second by counting.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2]).
:- initialization(consult('../../lib/lib_process/lib_process.pl')).

:- begin_tests(lib_process).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

open_streams(Count) :-
    findall(Stream, current_stream(_, _, Stream), Streams),
    length(Streams, Count).

% library(process) is SWI's ext/clib pack and absent from a wasm build, so the
% census row is what refuses this library before it loads rather than leaving
% process_create/3 to the autoloader.
test(the_library_rests_on_a_declared_capability) :-
    % The census row is the engine's, so it is asked in the engine's module, which is
    % where metta_platform_capability/3 lives.
    assertion(metta_engine:metta_platform_capability(subprocess, library(process), _)).

% A program that ran and failed is not one that could not run: the code is data, and
% both streams come back whatever it was.
test(a_nonzero_exit_is_a_status) :-
    'process-run!'("sh", ["-c", "printf out; printf err >&2; exit 3"], Failed),
    assertion(Failed == ['process-result', 3, "out", "err"]),
    'process-run!'("sh", ["-c", "exit 0"], Quiet),
    assertion(Quiet == ['process-result', 0, "", ""]),
    % A program the shell kills reports the negative of its signal, which is the one
    % thing a single Number can carry and what every shell reports.
    'process-run!'("sh", ["-c", "kill -TERM $$"], Signalled),
    assertion(Signalled = ['process-result', -15, _, _]),
    % An argument is never a second command: a file named like one is a file name.
    'process-run!'("printf", ["%s", "; rm -rf /"], Literal),
    assertion(Literal == ['process-result', 0, "; rm -rf /", ""]),
    % A Symbol and a Number are argument text too, which is what lets a program
    % write (process-run! "seq" (1 3)).
    'process-run!'("seq", [1, 3], Counted),
    assertion(Counted == ['process-result', 0, "1\n2\n3\n", ""]).

% The decision the library records: both pipes are read to completion before the
% wait, so a program whose output is larger than a pipe's buffer does not deadlock
% against a wait that cannot return. 168894 bytes is well past Linux's 65536-byte
% pipe, and the stream count is the same before and after.
test(every_captured_stream_is_closed) :-
    open_streams(Before),
    'process-run!'("seq", ["1", "30000"], ['process-result', Code, Output, Error]),
    assertion(Code == 0), assertion(Error == ""),
    string_length(Output, Length), assertion(Length == 168894),
    open_streams(AfterLarge), assertion(AfterLarge == Before),
    % Ten runs, a fed one among them, leave the same count: nothing accumulates.
    forall(between(1, 10, _),
           ( 'process-run!'("true", [], _),
             'process-run-input!'("cat", [], "fed", _) )),
    open_streams(AfterMany), assertion(AfterMany == Before),
    % A refused launch opens nothing either.
    catch('process-run!'("no-such-program-for-this-suite", [], _), _, true),
    open_streams(AfterRefusal), assertion(AfterRefusal == Before).

% Input goes in and the stream is closed, which is what a program that reads to end
% of file needs and what a temporary file would otherwise be for.
test(the_input_is_written_and_its_stream_closed) :-
    'process-run-input!'("cat", [], "fed in", Echoed),
    assertion(Echoed == ['process-result', 0, "fed in", ""]),
    % wc -c answers only when its input ends, so a count proves the close.
    'process-run-input!'("wc", ["-c"], "1234567890", ['process-result', 0, Counted, ""]),
    split_string(Counted, "", " \n", [Trimmed]), assertion(Trimmed == "10").

% A started process is the caller's: it answers `running` until it ends, takes a
% signal, and has to be waited for. Waiting twice raises, because the host has
% already forgotten it.
test(a_started_process_is_watched_and_signalled) :-
    'process-start!'("sleep", ["30"], Process),
    assertion(integer(Process)),
    'process-status'(Process, Running), assertion(Running == running),
    'process-signal!'(Process, kill, Done), assertion(Done == true),
    'process-wait!'(Process, Killed), assertion(Killed == -9),
    must_throw('process-wait!'(Process, _), error(existence_error(process, Process), _)),
    must_throw('process-status'(Process, _), error(existence_error(process, Process), _)),
    % `term` asks and `kill` takes away; both are among the four the library names.
    'process-start!'("sleep", ["30"], Asked),
    'process-signal!'(Asked, term, _),
    'process-wait!'(Asked, Terminated), assertion(Terminated == -15),
    % A process that ended on its own answers its code to the poll, not `running`.
    'process-start!'("true", [], Quick),
    'process-wait!'(Quick, Zero), assertion(Zero == 0),
    % An identifier that was never started here is refused rather than waited for.
    must_throw('process-wait!'(-1, _), error(existence_error(process, -1), _)),
    must_throw('process-status'(-1, _), error(existence_error(process, -1), _)),
    must_throw('process-signal!'(-1, term, _), error(existence_error(process, -1), _)).

% The refusal names the program rather than the search form the library wrapped it
% in, because a caller wrote the name and reads the error.
test(a_program_that_is_not_there_is_named) :-
    must_throw('process-run!'("no-such-program-for-this-suite", [], _),
               error(existence_error(program, "no-such-program-for-this-suite"), _)),
    must_throw('process-run-input!'("no-such-program-for-this-suite", [], "in", _),
               error(existence_error(program, "no-such-program-for-this-suite"), _)),
    must_throw('process-start!'("no-such-program-for-this-suite", [], _),
               error(existence_error(program, "no-such-program-for-this-suite"), _)),
    % A name with a separator is a path and is not looked for on PATH.
    must_throw('process-run!'("./no-such-file-for-this-suite", [], _),
               error(existence_error(program, "./no-such-file-for-this-suite"), _)).

% Every signal the library sends is data, and one it does not know is refused with
% the four listed rather than handed to the host.
test(the_signals_are_data_and_an_unknown_one_is_refused) :-
    'process-signals'(Signals),
    assertion(Signals == [term, kill, int, hup]),
    'process-start!'("sleep", ["30"], Process),
    must_throw('process-signal!'(Process, sigkill, _),
               error(domain_error(process_signal, sigkill), _)),
    catch('process-signal!'(Process, sigkill, _), error(_, context(_, Listed)), true),
    assertion(Listed == Signals),
    forall(member(Signal, Signals), memberchk(Signal, [term, kill, int, hup])),
    'process-signal!'(Process, kill, _), 'process-wait!'(Process, _).

test(every_refusal_names_what_it_was_given) :-
    must_throw('process-run!'(7, [], _), error(type_error(string, 7), _)),
    must_throw('process-run!'("echo", notacollection, _),
               error(type_error(list, notacollection), _)),
    must_throw('process-run!'("echo", [[nested]], _),
               error(type_error(process_argument, [nested]), _)),
    must_throw('process-run-input!'("cat", [], 7, _), error(type_error(string, 7), _)),
    must_throw('process-start!'(7, [], _), error(type_error(string, 7), _)),
    must_throw('process-wait!'("not a process", _),
               error(type_error(integer, "not a process"), _)),
    must_throw('process-status'("not a process", _),
               error(type_error(integer, "not a process"), _)),
    must_throw('process-signal!'("not a process", term, _),
               error(type_error(integer, "not a process"), _)),
    % The refusal for a command line says where a shell comes from, because that is
    % the mistake it catches.
    catch('process-run!'("sh", "-c 'echo hi'", _), error(_, context(_, Advice)), true),
    assertion(sub_atom(Advice, _, _, _, 'process-run! "sh"')).

:- end_tests(lib_process).
