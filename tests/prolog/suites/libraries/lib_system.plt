% Purpose: check the environment doors against the host's own, the platform keys
% against the host's flags, and the working directory against what the process says.
% Guarantees: a write is visible to every reader and an unset variable has no answer,
% the environment relation holds exactly what the host's environ/1 holds,
% platform-info answers the host's own flags and refuses an unknown key with every
% key listed, and the working directory is absolute with no trailing separator
% [tested: lib_system; commit=b109f59a8095add8ecf264b011e683184274acbb].
% Owns resources: every variable this suite writes it removes again, and it changes
% no directory.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2]).
:- initialization(consult('../../lib/lib_system/lib_system.pl')).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_system).

% env-all rests on library(unix)'s environ/1, which is SWI's ext/clib pack: the
% census load above the clauses records its absence, and the head refuses by name
% where the capability is lost rather than raising an unknown procedure.
test(the_listing_rests_on_a_declared_capability) :-
    % The census row is the engine's, so it is asked in the engine's module, which
    % is where metta_platform_capability/3 lives.
    assertion(metta_engine:metta_platform_capability('environment-listing', library(unix), _)),
    (   current_predicate(lib_system:environ/1)
    ->  'env-all'(Rows), assertion(is_list(Rows))
    ;   must_throw('env-all'(_), error(_, _))
    ).

% Unset and empty are different states, which is the whole reason the read has no
% answer rather than an empty String.
test(an_unset_variable_has_no_answer) :-
    assertion(\+ 'env-get'("NO_SUCH_VARIABLE_FOR_THIS_SUITE", _)),
    setup_call_cleanup(
        'env-set!'("LIB_SYSTEM_SUITE", "", _),
        ( 'env-get'("LIB_SYSTEM_SUITE", Empty), assertion(Empty == "") ),
        'env-unset!'("LIB_SYSTEM_SUITE", _)),
    assertion(\+ 'env-get'("LIB_SYSTEM_SUITE", _)).

% What a write puts in, every reader sees; what an unset removes, none of them does.
% The relation is checked against the host's own environ/1 over the same process.
test(a_write_is_visible_to_every_reader) :-
    setup_call_cleanup(
        'env-set!'("LIB_SYSTEM_SUITE", "written", _),
        ( 'env-get'("LIB_SYSTEM_SUITE", Value), assertion(Value == "written"),
          getenv('LIB_SYSTEM_SUITE', HostValue), assertion(HostValue == written),
          'env-all'(Variables),
          assertion(memberchk(["LIB_SYSTEM_SUITE", "written"], Variables)),
          environ(HostPairs),
          findall([Name, HostText],
                  ( member(Raw = RawValue, HostPairs),
                    atom_string(Raw, Name), atom_string(RawValue, HostText) ),
                  Expected),
          assertion(Variables == Expected),
          % Every row is a pair, which is what makes the answer a lib_pairs relation.
          forall(member(Row, Variables), ( Row = [Key, Text], string(Key), string(Text) )) ),
        'env-unset!'("LIB_SYSTEM_SUITE", _)),
    'env-all'(After),
    assertion(\+ memberchk(["LIB_SYSTEM_SUITE", _], After)),
    % Unsetting a variable that is not set is silent.
    'env-unset!'("NO_SUCH_VARIABLE_FOR_THIS_SUITE", Done), assertion(Done == true).

% Every key against the host's own flag or predicate, and the refusal naming all of
% them.
test(platform_info_is_the_hosts_own_flags) :-
    'platform-keys'(Keys), length(Keys, Count), assertion(Count == 10),
    forall(member(Key, Keys), ( 'platform-info'(Key, _) )),
    'platform-info'(architecture, Architecture),
    current_prolog_flag(arch, Arch), atom_string(Arch, ArchText),
    assertion(Architecture == ArchText),
    'platform-info'(pid, Pid), current_prolog_flag(pid, HostPid),
    assertion(Pid == HostPid),
    'platform-info'(cores, Cores), current_prolog_flag(cpu_count, HostCores),
    assertion(Cores == HostCores),
    'platform-info'('bounded-integers', Bounded),
    current_prolog_flag(bounded, HostBounded), assertion(Bounded == HostBounded),
    % The family is the one platform flag that is true, and the version text is
    % the three numbers.
    'platform-info'(family, Family),
    assertion(memberchk(Family, ["unix", "windows", "apple", "emscripten", "unknown"])),
    'platform-info'(version, Version), 'platform-info'('version-numbers', Numbers),
    Numbers = [Major, Minor, Patch],
    format(atom(Rebuilt), '~w.~w.~w', [Major, Minor, Patch]),
    atom_string(Rebuilt, RebuiltText), assertion(Version == RebuiltText),
    current_prolog_flag(version_data, swi(Major, Minor, Patch, _)),
    must_throw('platform-info'(nosuch, _), error(domain_error(platform_key, nosuch), _)),
    catch('platform-info'(nosuch, _), error(_, context(_, Listed)), true),
    assertion(Listed == Keys).

% The directory is the process's, absolute and without a trailing separator, and a
% path that is not a directory is refused without moving.
test(the_working_directory_is_the_processs_own) :-
    'working-directory'(Path),
    assertion(string(Path)),
    string_concat("/", _, Path),
    assertion(\+ string_concat(_, "/", Path)),
    working_directory(Host, Host), atom_string(Host, HostText),
    string_concat(Path, "/", HostText),
    must_throw('change-directory!'("/no/such/directory/for/this/suite", _),
               error(existence_error(directory, _), _)),
    'working-directory'(Unchanged), assertion(Unchanged == Path),
    % Entering a directory that exists works and is undone here.
    setup_call_cleanup(
        'change-directory!'("/", _),
        ( 'working-directory'(Root), assertion(Root == "/") ),
        'change-directory!'(Path, _)),
    'working-directory'(Restored), assertion(Restored == Path).

test(every_refusal_names_what_it_was_given) :-
    must_throw('env-get'(7, _), error(type_error(string, 7), _)),
    must_throw('env-set!'(7, "v", _), error(type_error(string, 7), _)),
    must_throw('env-set!'("A", [nosuch], _), error(type_error(string, [nosuch]), _)),
    must_throw('env-unset!'(7, _), error(type_error(string, 7), _)),
    must_throw('change-directory!'(7, _), error(type_error(string, 7), _)).

:- end_tests(lib_system).
