% Purpose: the platform census read by two threads at once, each interleaving
%   of their first reads of one capability forced by wrap_predicate gates
%   rather than left to the scheduler.
% Assumes: the host runs threads; every test is conditional on them, since a
%   host without them has one reader and nothing to interleave. A capability
%   is made absent by answering its row's library walk with a library that
%   does not exist, and made undecided by setting its verdict flag back to 0
%   and restoring its reading clause, so the tests need no reduced build.
% Guarantees:
%   - two first reads of an absent capability both answer absent whichever
%     decides first, including where the second read began before the first
%     decision was recorded and where both reads missed the verdict before
%     either decided; the capability then keeps its reading clause and nothing
%     beside it, so an enumeration lists it once
%     [tested: a_second_decision_after_the_first_reads_absent,
%     two_decisions_released_together_list_it_once,
%     a_read_begun_while_the_first_decides_reads_absent]
%   - a present capability read while its decision is being recorded answers
%     present, and its reading clause is gone once the verdict is in
%     [tested: a_read_begun_before_the_clause_goes_reads_present]
%   - a load that loses its capability while a read waits is the verdict the
%     read returns; a load that finds a library a read did not makes the
%     capability present; and a load that loses a library a read found raises
%     [tested: a_read_waiting_on_a_losing_load_reads_absent,
%     a_load_that_finds_the_library_makes_it_present,
%     a_load_that_loses_a_present_library_raises]
%   - a verdict reached inside a transaction that rolls back stands, and the
%     capability reads the same outside it
%     [tested: a_verdict_reached_in_a_rolled_back_transaction_stands]
%   - every gate a test names was passed as often as the interleaving needs,
%     so no test passes by the scheduler never reaching the window
%     [tested: each test's gate count assertion]
% Fails when: a gate waits five seconds for a thread that never arrives. It
%   fails that thread rather than hanging the suite, and the test fails on
%   the reading that thread did not record.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap), [wrap_predicate/4, unwrap_predicate/2]).
:- use_module(library(apply), [include/3]).
:- use_module(library(lists), [member/2]).

:- dynamic reading/2.

%The census lives in the engine's module, which is not this unit's, so every
%read, plant and wrapper here names it.
engine(Engine) :-
    metta_engine_module(Engine).

%A capability nothing has decided: its verdict flag at 0, and its reading
%clause back.
undecided(Capability) :-
    engine(Engine),
    Engine:metta_platform_key(Capability, Key),
    set_flag(Key, 0),
    Engine:metta_platform_reading(Capability).

verdict(Capability, Verdict) :-
    engine(Engine),
    Engine:metta_platform_key(Capability, Key),
    get_flag(Key, Verdict).

%Absent here: the row's library walk answers one library, which does not
%exist, so a read's resolution and a load's use_module both fail on it.
make_absent(Capability) :-
    engine(Engine),
    Engine:metta_platform_capability(Capability, Requires, _),
    wrap_predicate(Engine:metta_platform_spec(Walked, Spec), census_threads_absent, Walk,
                   (   Walked == Requires
                   ->  Spec = library(platform_census_threads_absent)
                   ;   Walk
                   )).

%Every wrapper a test installs goes, and the capability is undecided again, so
%a later read in this process decides it truthfully.
restore(Capability) :-
    engine(Engine),
    forall(member(Head-Name,
                  [ metta_platform_spec(_, _)-census_threads_absent,
                    metta_platform_decide(_, _, _)-census_threads_gate,
                    metta_platform_status(_, _)-census_threads_gate,
                    metta_platform_conclude(_, _)-census_threads_gate,
                    metta_platform_retire(_)-census_threads_gate
                  ]),
           ignore(unwrap_predicate(Engine:Head, Name))),
    undecided(Capability),
    retractall(reading(_, _)),
    forall(member(Flag, [census_arrived, census_released, census_passed]),
           flag(Flag, _, 0)).

%A gate is a global flag and a bounded wait on it, as the probe that found the
%race used: five seconds is far past any interleaving here, and a wait that
%times out fails its thread instead of hanging the suite.
wait_flag(Flag, Value) :-
    get_time(Start),
    wait_flag(Flag, Value, Start).
wait_flag(Flag, Value, Start) :-
    (   flag(Flag, Value, Value)
    ->  true
    ;   get_time(Now), Now - Start < 5.0
    ->  sleep(0.001),
        wait_flag(Flag, Value, Start)
    ;   format(user_error, "census gate ~w never reached ~w~n", [Flag, Value]),
        fail
    ).

bump(Flag) :-
    flag(Flag, Old, Old + 1).

%One reader: the published read, through the reading clause when it is there.
read_capability(Capability) :-
    engine(Engine),
    thread_self(Me),
    (   Engine:metta_platform_absent(Capability)
    ->  Result = absent
    ;   Result = present
    ),
    assertz(reading(Me, Result)).

%Two readers, the second started once Start2 holds, both joined; Readings is
%what each read, first reader first.
two_readers(Capability, Start2, Readings) :-
    thread_create(read_capability(Capability), First, [alias(census_first)]),
    call(Start2),
    thread_create(read_capability(Capability), Second, [alias(census_second)]),
    thread_join(First, _),
    thread_join(Second, _),
    findall(Result, reading(census_first, Result), R1),
    findall(Result, reading(census_second, Result), R2),
    Readings = R1-R2.

listed(Capability, Count) :-
    engine(Engine),
    findall(Listed, Engine:metta_platform_absent(Listed), All),
    include(==(Capability), All, Mine),
    length(Mine, Count).

has_reading_clause(Capability) :-
    engine(Engine),
    clause(Engine:metta_platform_absent(Capability), _).

%What the first version got wrong by shape: an absent capability's clauses
%are exactly its reading clause, with no fact beside it for an enumeration to
%find a second time.
only_the_reading_clause(Capability) :-
    engine(Engine),
    findall(Body, clause(Engine:metta_platform_absent(Capability), Body), Bodies),
    Bodies == [metta_platform_status(Capability, absent)].

:- begin_tests(platform_census_threads,
               [ condition(current_prolog_flag(threads, true)) ]).

%Both readers are inside the reading clause and have missed the unlocked
%verdict before either decides; the first decides and records, and only then
%does the second take the lock. The first version answered present here: the
%second decision saw the first one's fact and failed, and its own call could
%never see that fact.
test(a_second_decision_after_the_first_reads_absent,
     [ setup(( undecided(yaml), make_absent(yaml) )),
       cleanup(restore(yaml)) ]) :-
    engine(Engine),
    wrap_predicate(Engine:metta_platform_decide(C, _, _), census_threads_gate, Decide,
                   (   C == yaml
                   ->  thread_self(Me),
                       bump(census_arrived), wait_flag(census_arrived, 2),
                       (   Me == census_first
                       ->  Decide, flag(census_released, _, 1)
                       ;   wait_flag(census_released, 1), Decide
                       ),
                       bump(census_passed)
                   ;   Decide
                   )),
    two_readers(yaml, true, Readings),
    assertion(Readings == [absent]-[absent]),
    assertion(flag(census_passed, 2, 2)),
    assertion(verdict(yaml, absent)),
    assertion(only_the_reading_clause(yaml)),
    assertion(listed(yaml, 1)).

%Both readers miss the unlocked verdict and are released into the decision at
%once. The first version let both pass its "no fact yet" check and assert, so
%an enumeration listed the capability twice.
test(two_decisions_released_together_list_it_once,
     [ setup(( undecided(json), make_absent(json) )),
       cleanup(restore(json)) ]) :-
    engine(Engine),
    wrap_predicate(Engine:metta_platform_decide(C, _, _), census_threads_gate, Decide,
                   (   C == json
                   ->  bump(census_arrived), wait_flag(census_arrived, 2),
                       Decide, bump(census_passed)
                   ;   Decide
                   )),
    two_readers(json, true, Readings),
    assertion(Readings == [absent]-[absent]),
    assertion(flag(census_passed, 2, 2)),
    assertion(verdict(json, absent)),
    assertion(only_the_reading_clause(json)),
    assertion(listed(json, 1)).

%The second read begins while the first holds the census lock with its
%decision computed and not yet recorded. The first version had already
%retracted the reading clause at that point, so the second read found no
%clause at all and answered present.
test(a_read_begun_while_the_first_decides_reads_absent,
     [ setup(( undecided(uri), make_absent(uri) )),
       cleanup(restore(uri)) ]) :-
    engine(Engine),
    wrap_predicate(Engine:metta_platform_conclude(C, _), census_threads_gate, Conclude,
                   (   C == uri, thread_self(census_first)
                   ->  flag(census_arrived, _, 1),
                       wait_flag(census_released, 1),
                       Conclude, bump(census_passed)
                   ;   Conclude
                   )),
    wrap_predicate(Engine:metta_platform_status(C2, _), census_threads_gate, Status,
                   (   C2 == uri, thread_self(census_second)
                   ->  flag(census_released, _, 1), Status
                   ;   Status
                   )),
    two_readers(uri, wait_flag(census_arrived, 1), Readings),
    assertion(Readings == [absent]-[absent]),
    assertion(flag(census_passed, 1, 1)),
    assertion(verdict(uri, absent)),
    assertion(only_the_reading_clause(uri)),
    assertion(listed(uri, 1)).

%A present capability: the first reader has recorded the verdict and not yet
%removed the reading clause when the second read begins, so the second runs
%that clause and must answer present from the verdict. Afterwards the clause
%is gone, which is what keeps a present capability's read one failing call.
test(a_read_begun_before_the_clause_goes_reads_present,
     [ condition(exists_source(library(uri))),
       setup(undecided(uri)),
       cleanup(restore(uri)) ]) :-
    engine(Engine),
    wrap_predicate(Engine:metta_platform_retire(C), census_threads_gate, Retire,
                   (   C == uri, thread_self(census_first)
                   ->  flag(census_arrived, _, 1),
                       wait_flag(census_released, 1),
                       Retire, bump(census_passed)
                   ;   Retire
                   )),
    wrap_predicate(Engine:metta_platform_status(C2, _), census_threads_gate, Status,
                   (   C2 == uri, thread_self(census_second)
                   ->  (   Status -> Answered = true ; Answered = false ),
                       flag(census_released, _, 1),
                       Answered == true
                   ;   Status
                   )),
    two_readers(uri, wait_flag(census_arrived, 1), Readings),
    assertion(Readings == [present]-[present]),
    assertion(flag(census_passed, 1, 1)),
    assertion(verdict(uri, present)),
    assertion(\+ has_reading_clause(uri)),
    assertion(listed(uri, 0)).

%A read that missed the verdict waits at the decision while a load of the
%capability loses its library and records the loss; the read then answers the
%load's verdict. The import list is the one lib_socket loads with, so the name
%the load could not publish is recorded against the capability as well.
test(a_read_waiting_on_a_losing_load_reads_absent,
     [ setup(( undecided(socket), make_absent(socket) )),
       cleanup(( restore(socket),
                 engine(Engine),
                 retractall(Engine:metta_platform_absent_name(socket_create, socket)) )) ]) :-
    engine(Engine),
    wrap_predicate(Engine:metta_platform_decide(C, _, _), census_threads_gate, Decide,
                   (   C == socket
                   ->  flag(census_arrived, _, 1),
                       wait_flag(census_released, 1),
                       Decide, bump(census_passed)
                   ;   Decide
                   )),
    thread_create(read_capability(socket), Reader, [alias(census_first)]),
    wait_flag(census_arrived, 1),
    Engine:metta_platform_load(socket, [socket_create/2]),
    flag(census_released, _, 1),
    thread_join(Reader, _),
    findall(Result, reading(census_first, Result), Readings),
    assertion(Readings == [absent]),
    assertion(flag(census_passed, 1, 1)),
    assertion(verdict(socket, absent)),
    assertion(only_the_reading_clause(socket)),
    assertion(listed(socket, 1)),
    assertion(Engine:metta_platform_absent_name(socket_create, socket)).

%A read found no library and decided absent; the library is there by the time
%a load asks, as one installed while the process runs would be. The load is
%what the refusal protects, so the capability is present from then on and
%its reading clause goes.
test(a_load_that_finds_the_library_makes_it_present,
     [ condition(exists_source(library(uri))),
       setup(( undecided(uri), make_absent(uri) )),
       cleanup(restore(uri)) ]) :-
    engine(Engine),
    assertion(Engine:metta_platform_absent(uri)),
    unwrap_predicate(Engine:metta_platform_spec(_, _), census_threads_absent),
    Engine:metta_platform_load(uri, []),
    assertion(\+ Engine:metta_platform_absent(uri)),
    assertion(verdict(uri, present)),
    assertion(\+ has_reading_clause(uri)),
    assertion(listed(uri, 0)).

%A read found every library and decided present, and a later load of the
%same capability finds one gone. Turning the capability absent would change
%an answer readers already acted on, so the load raises, naming what vanished,
%and the census stays as it was.
test(a_load_that_loses_a_present_library_raises,
     [ condition(exists_source(library(uri))),
       setup(undecided(uri)),
       cleanup(restore(uri)) ]) :-
    engine(Engine),
    assertion(\+ Engine:metta_platform_absent(uri)),
    make_absent(uri),
    catch(Engine:metta_platform_load(uri, []), Error, true),
    assertion(subsumes_term(error(metta_platform_vanished(uri, _), _), Error)),
    assertion(verdict(uri, present)),
    assertion(\+ has_reading_clause(uri)),
    assertion(\+ Engine:metta_platform_absent(uri)).

%A first read inside a transaction that rolls back, as a MeTTa (atomically
%...) that fails does. The verdict is not the transaction's, so it stands; the
%present capability's reading clause is left in place there, since a retract
%would be rolled back with it, and it answers present from the verdict.
test(a_verdict_reached_in_a_rolled_back_transaction_stands,
     [ condition(exists_source(library(uri))),
       setup(( undecided(uri), undecided(json), make_absent(json) )),
       cleanup(( restore(uri), restore(json) )) ]) :-
    engine(Engine),
    \+ transaction(( \+ Engine:metta_platform_absent(uri),
                     Engine:metta_platform_absent(json),
                     fail )),
    assertion(verdict(uri, present)),
    assertion(\+ Engine:metta_platform_absent(uri)),
    assertion(listed(uri, 0)),
    assertion(verdict(json, absent)),
    assertion(Engine:metta_platform_absent(json)),
    assertion(only_the_reading_clause(json)),
    assertion(listed(json, 1)).

:- end_tests(platform_census_threads).
