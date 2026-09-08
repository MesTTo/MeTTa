% Purpose: gate that no shipped library calls a name only SWI's library-index
%     autoloader would find, the same question engine/check.sh's `prolog` lane
%     asks of the engine, asked of lib/.
% Assumes:
%     - the autoload flag is already false when this file loads, which is why
%       the directive below is the FIRST one: a -g goal runs after every -s/-l
%       file has finished loading, so a flag set there is set too late for the
%       engine's own load-time directives
%       [source: tests/fixtures/no_autoload_boot.pl, which records the same
%       measurement for the corpus lane; commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3].
% Guarantees:
%     - exits nonzero naming every undefined name a shipped library's clauses
%       reach, with the file and line of the clause that reaches it, and the
%       two spellings that fix it
%     - exits nonzero when the walk stops seeing a planted call to an
%       autoloadable name, so a clean result is a claim this file has just
%       tested rather than an assumption
%       [tested: prove_eyesight/0, which plants a call to the first library
%       export this tree does not import; commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3]
%     - allows exactly the names in allowed/2, each with the reason it is
%       deferred rather than missing, and nothing else
% Fails when:
%     - a call is assembled at run time from a term no analysis can see,
%       `Goal =.. L, call(Goal)` being the shape. That is the residue this
%       shares with every other static walk in the tree.
% Decides:
%     - lib/*/*.pl and nothing else. A backend and a seat are arm's length by
%       construction and have their own lanes; the shipped libraries load into
%       the engine's own process and are the tier the `prolog` lane's consult
%       of engine/main.pl never reaches, because import! loads them on demand.
% Open Obligations:
%     To Do: None
%     Hacks: None
%     Future Enhancements: None

% The engine's `prolog` lane already runs list_undefined with the autoloader
% off, and its comment says why that is the discriminating configuration: "with
% autoload on, such a name resolves at the first call and the check says
% nothing; the no-autoload GATE below does catch it, but only when some example
% happens to reach that call, one name per run of a corpus that takes minutes".
% The libraries were the tier that sentence did not reach. Two were live when
% this lane was written and only one of them was reachable from the corpus:
% lib_tabling's call_delays/2, which stopped the no-autoload lane on
% 16-cache_policy_restraints.metta, and lib_crypto's hex_bytes/2, which no
% example calls at all and which nothing would have found
% [measured 2026-09-07: both reported in one run of this file, 4.0s wall at
% loadavg 68; command=swipl -q --on-error=status -g library_autoload_gate -t
% halt tests/prolog/library_autoload.pl; commit=e52b9b2eeb4b303b57c93e6e6844664a25ce0da3].

:- set_prolog_flag(autoload, false).
:- use_module(library(check), [list_undefined/0]).
% The checker runs in user, which imports only the engine's public interface.
% [tested: sh check.sh lib-autoload; commit=WORKTREE]
:- use_module(library(lists), [member/2, memberchk/2]).
:- use_module(library(apply), [exclude/3]).
:- ensure_loaded('../../engine/main.pl').

library_glob('../../lib/*/*.pl').

% A name a library reaches that is deferred by design rather than missing.
% Each row carries the reason, and a row with no reason is a row that should be
% a repair instead.
allowed(source_observation:observe_source/4,
        'lib_observe calls metta_ensure_source_observation/0 first, which is \c
         what loads engine/source_observation.pl: an engine nobody asks for an \c
         observation pays nothing for one, so the module is absent at load \c
         time on purpose').
allowed(user:py_call/2,
        'janus\'s, and every lib_thread call site is guarded by \c
         current_predicate(py_call/2) or current_predicate/1 on a Python-seat \c
         predicate; a tokenless engine has no Python seat').

% Candidates for the eyesight plant: library exports the engine and its
% libraries do not import, so a call to one is undefined exactly when the
% autoloader is off. Several, because a later engine change may legitimately
% start importing any one of them, and the plant then moves to the next rather
% than passing vacuously.
plant_candidate(top_sort/2).
plant_candidate(list_to_assoc/2).
plant_candidate(rb_new/1).
plant_candidate(varnumbers/2).
plant_candidate(dicts_to_same_keys/3).

:- dynamic reported/2.
:- multifile user:message_hook/3.
% Taking the message as DATA and suppressing the print: list_undefined's own
% warning is a page of text per name, and this lane runs it twice, so a clean
% run would bury its own verdict under the two names it allows. The hook
% succeeds, which is what stops the message being printed
% [source: SWI-Prolog 10.1 Reference Manual, message_hook/3].
user:message_hook(check(undefined_procedures, Rows), _Kind, _Lines) :-
    forall(member(PI-Locations, Rows), assertz(reported(PI, Locations))).

% halt/1 on the way out, both ways, because engine/main.pl carries
% initialization(main, main) and would otherwise run its demo over this lane's
% verdict once the goal returns.
library_autoload_gate :-
    load_shipped_libraries,
    prove_eyesight,
    undefined_names(Names),
    exclude(is_allowed, Names, Findings),
    report(Findings),
    halt(0).

load_shipped_libraries :-
    library_glob(Glob),
    expand_file_name(Glob, Files),
    forall(member(File, Files),
           catch(consult(File), Error,
                 ( print_message(error, Error),
                   format(user_error,
                          'library autoload: ~w did not load, so its clauses \c
                           were not read~n', [File]),
                   halt(1) ))).

undefined_names(Names) :-
    retractall(reported(_, _)),
    list_undefined,
    findall(PI, reported(PI, _), Names0),
    sort(Names0, Names).

is_allowed(PI) :- allowed(PI, _).

% A clean answer has to be a tested claim. The plant is a clause calling a
% library export nothing here imports, which is undefined only because the
% autoloader is off, so seeing it is the exact eyesight this lane needs.
prove_eyesight :-
    (   plant_candidate(Name/Arity), \+ current_predicate(Name/Arity)
    ->  true
    ;   format(user_error,
               'library autoload: every plant candidate is already defined, so \c
                the walk could not be tested; add one this tree does not \c
                import to plant_candidate/1~n', []),
        halt(1)
    ),
    functor(Goal, Name, Arity),
    assertz((user:'$library_autoload_plant' :- Goal), Ref),
    undefined_names(WithPlant),
    erase(Ref),
    (   memberchk(user:Name/Arity, WithPlant)
    ->  true
    ;   format(user_error,
               'library autoload: the walk did not see a planted call to ~w, \c
                so a clean result would say nothing~n', [Name/Arity]),
        halt(1)
    ).

% The clause references list_undefined hands back locate the caller exactly,
% which is what turns a name into an edit.
finding_site(PI, Site) :-
    reported(PI, Locations),
    member(Location, Locations),
    clause_reference(Location, Ref),
    clause_property(Ref, file(File)),
    clause_property(Ref, line_count(Line)),
    format(atom(Site), '~w:~d', [File, Line]),
    !.
finding_site(_, 'location unavailable').

clause_reference(clause_term_position(Ref, _), Ref) :- !.
clause_reference(clause(Ref), Ref) :- !.
clause_reference(Ref, Ref) :- blob(Ref, clause).

report([]) :-
    library_glob(Glob),
    expand_file_name(Glob, Files),
    length(Files, Count),
    findall(PI, allowed(PI, _), Allowed),
    length(Allowed, AllowedCount),
    format("library autoload: no shipped library reaches a name only the \c
            autoloader would find, over ~d files, with ~d allowed by name~n",
           [Count, AllowedCount]).
report([First|Rest]) :-
    Findings = [First|Rest],
    length(Findings, Count),
    format(user_error,
           'library autoload: ~d name(s) a shipped library calls resolve only \c
            through SWI\'s library index, so the call raises wherever the \c
            autoloader is off~n', [Count]),
    forall(member(PI, Findings),
           ( finding_site(PI, Site),
             format(user_error, '  ~w~t~34| ~w~n', [PI, Site]) )),
    format(user_error,
           'each is one declaration: `:- autoload(library(L), [Name/Arity]).` \c
            for a core library, or the capability\'s own \c
            metta_platform_load/2 import list for an optional one. Add a row \c
            to allowed/2 in tests/prolog/library_autoload.pl only when the \c
            name is deferred by design, with the reason~n', []),
    % halt/1 rather than failing, because a failed initialization goal prints
    % `user:main: false` over the report it just produced.
    halt(1).
