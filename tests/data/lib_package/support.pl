% Purpose: supply observable claimant effects for package lifecycle tests.
% Guarantees: events record actual acquisition, release and preparation calls;
% preparation writes both its artifact and a persistent invocation counter.
% [tested: lib_package; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
% Owns resources: file streams close on all outcomes; events belong to the test
% process and survive source rollback so compensation remains observable.
% Guarded by: lp_events serializes event writes from concurrent setup threads.
:- module(lib_package_support,
          [lp_acquire/2, lp_release/3, lp_prepare/3, lp_return_space/2,
           lp_probe_lock/2, lp_process/3, lp_event/1, lp_reset/0, lp_install/0,
           lp_wait/2, lp_gate/3]).
:- use_module('../../../engine/metta.pl').
:- use_module(library(process)).
:- use_module(library(readutil)).
:- dynamic lp_event/1.
:- dynamic lp_gate/3.
:- '$notransact'(lp_event/1).

lp_reset :- retractall(lp_event(_)).
lp_note(Event) :- with_mutex(lp_events, assertz(lp_event(Event))).

lp_acquire(Id, [handle, Id]) :-
    lp_note(acquire(Id)),
    ( Id == fail -> throw(error(lp_acquire_failed, none)) ; true ).

lp_release(Id, [handle, Id], true) :-
    lp_note(release(Id)),
    ( Id == release_fail -> throw(error(lp_release_failed, none)) ; true ).

lp_prepare(File, Text, done) :-
    lp_note(prepare(File, Text)),
    atom_string(Path, File), atom_concat(Path, '.calls', Counter),
    setup_call_cleanup(open(Counter, append, Count), writeln(Count, run), close(Count)),
    ( Text == "fail" -> throw(error(lp_prepare_failed, none)) ; true ),
    setup_call_cleanup(open(Path, write, Out, [encoding(utf8)]),
                       format(Out, '~s', [Text]), close(Out)).

lp_return_space(Space, Space).

lp_wait(Id, true) :-
    lp_gate(Id, Ready, Continue),
    thread_send_message(Ready, entered), thread_get_message(Continue, continue).

% A child attempts the directory lock without waiting. This observes OS
% exclusion while the setup claimant runs, without scheduling or sleep races.
lp_probe_lock(Directory, Result) :-
    directory_file_path(Directory, '.package.lock', Lock),
    format(atom(Goal),
        'catch((open(~q,append,S,[lock(write),wait(false)]),close(S),writeln(unlocked)),error(permission_error(lock,source_sink,_),_),writeln(locked))', [Lock]),
    lp_process(path(swipl), ['-q','-f',none,'-g',Goal,'-t',halt], Output),
    normalize_space(atom(Result), Output), lp_note(os_lock(Result)).

lp_process(Executable, Arguments, Output) :-
    setup_call_cleanup(
        process_create(Executable, Arguments, [stdout(pipe(Stream)), process(Pid)]),
        read_string(Stream, _, Output),
        (close(Stream), process_wait(Pid, Status))),
    ( Status == exit(0) -> true
    ; throw(error(package_test_process(Executable, Arguments, Status, Output), none)) ).

lp_install :-
    filereader:metta_host_set_silent(true),
    metta_engine:metta_register_loader_claims,
    forall(member(Name, [lp_acquire, lp_release, lp_prepare, lp_return_space, lp_probe_lock, lp_wait]),
           metta_engine:import_prolog_function(Name, _)),
    filereader:process_loader_string(
        "(= (perform (lp-resource $id $heads)) (lp_acquire $id))\n\c
         (= (release (lp-resource $id $heads) $handle) (lp_release $id $handle))\n\c
         (= (perform (lp-prepare $path $text)) (lp_prepare $path $text))\n\c
         (= (perform (lp-space $space $heads)) (lp_return_space $space))\n\c
         (= (perform (lp-wait $id)) (lp_wait $id))\n",
        _, '&metta'),
    filereader:process_loader_string(
        "(= (perform (lp-lock $directory)) (lp_probe_lock $directory))",
        _, '&metta').
