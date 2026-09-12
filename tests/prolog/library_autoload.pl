% Purpose: gate that a shipped library's calls and its published names both
%     reach what the library means: no call that only SWI's library-index
%     autoloader would find, which is engine/check.sh's `prolog` lane asked of
%     lib/, and no published head that a tier above the libraries answers
%     instead.
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
%     - exits nonzero naming every head a library face registers that a module
%       above the libraries in the execution chain answers instead, with the
%       module that answers it, because a MeTTa call reaches a registered head by
%       NAME through that chain and the library's own clauses are reached last
%     - exits nonzero when that walk stops seeing a planted published head whose
%       name a tier already answers, so a clean result is again a tested claim
%       [tested: prove_shadow_eyesight/0, which publishes a library name the
%       engine module imports from library(lists); commit=WORKTREE]
% Fails when:
%     - a call is assembled at run time from a term no analysis can see,
%       `Goal =.. L, call(Goal)` being the shape. That is the residue this
%       shares with every other static walk in the tree.
%     - a name is occupied above the libraries only LATER, by an engine path
%       that autoloads it after this lane's own load. What the shadow half sees
%       is every name a tier holds once the engine and every library are loaded,
%       which covers each name the engine imports outright, library(lists)
%       included, and every name its boot already autoloaded.
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
% [tested: sh check.sh lib-autoload; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- use_module(library(lists), [member/2, memberchk/2]).
:- use_module(library(apply), [exclude/3]).
:- use_module(library(readutil), [read_file_to_string/3]).
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
allowed(user:py_call/1,
        'janus\'s, the call that discards its return: converting the return of \c
         a host cleanup or cancellation callable raised on a leaf Atom \c
         (docs/journal/2026-09-08-a-scope-owns-its-children.md), so lib_thread \c
         calls those through py_call/1, and only for a host(...) record a \c
         Python seat wrote; a tokenless engine has no Python seat').

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

% A name a tier above the libraries answers, and no library publishes, so a
% published head of that name proves the shadow walk can see one. Several,
% because a later change may legitimately publish any single one of them.
shadow_candidate(subtract/3).
shadow_candidate(delete/3).
shadow_candidate(permutation/2).
shadow_candidate(list_to_set/2).
shadow_candidate(max_member/2).

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
    load_face_registrations,
    prove_shadow_eyesight,
    prove_shadow_enumeration,
    shadowed_heads(Shadowed),
    report(Findings),
    report_shadowed(Shadowed),
    (   Findings == [], Shadowed == []
    ->  halt(0)
    ;   halt(1)
    ).

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
            name is deferred by design, with the reason~n', []).

% ------------------------------- what a published name resolves to -------------

% The name a library face registers is the name a MeTTa call compiles to, so the
% registration forms are the authority on what a library publishes and
% metta_registration_names/2 is the engine's own reader for all four of their
% spellings. The arity comes from the module's export list, which is also what
% the face generator reads.
published_head(Module, Name, Arity) :-
    planted_head(Module, Name, Arity).
published_head(Module, Name, Arity) :-
    face_registered(Directory, Name),
    library_module_in(Directory, Module),
    module_property(Module, exports(Exports)),
    memberchk(Name/Arity, Exports).

% module_property/2 answers an absolute path and the glob above yields a
% relative one, so both sides are canonicalised before they are compared; the
% first version compared them as written and the join was empty, which is the
% failure the enumeration self-test below now catches.
library_module_in(Directory, Module) :-
    module_property(Module, file(File)),
    file_directory_name(File, ModuleDirectory),
    same_directory(ModuleDirectory, Directory).

same_directory(One, Two) :-
    absolute_file_name(One, Canonical),
    absolute_file_name(Two, Canonical).

% Read and parse each face ONCE. The walk asks what a face registers for every
% candidate name and again for every published head, and re-parsing the faces
% under each question cost more than the whole rest of the lane.
:- dynamic face_registered/2.

load_face_registrations :-
    retractall(face_registered(_, _)),
    expand_file_name('../../lib/*/*.metta', Faces),
    forall(member(Face, Faces),
           ( read_file_to_string(Face, Text, [encoding(utf8)]),
             parse_metta_source(Text, Forms),
             file_directory_name(Face, Directory),
             forall(( member(Form, Forms),
                      parsed_form_parts(Form, runnable, _, Term),
                      metta_registration_names(Term, Names),
                      member(Name, Names) ),
                    ( face_registered(Directory, Name)
                    -> true
                    ;  assertz(face_registered(Directory, Name)) )) )).

% The module a MeTTa call in a space reaches for a name, walked the way SWI
% walks it. The chain is system -> the engine's module -> prelude -> a space's
% own module, so a library's clauses, which consult_global/1 imports into `user`,
% are reached LAST: anything a tier holds answers first, and a published head of
% that name never runs [source: engine/spaces/lifecycle.pl,
% metta_exec_module_base/2 and its chain comment]. The two primitives are the
% ones the engine's own shadow bookkeeping uses, so this asks the module table
% rather than resolving through the trap [source: engine/spaces/lifecycle.pl,
% metta_existing_import/3].
resolved_owner(Name, Arity, Owner) :-
    functor(Head, Name, Arity),
    default_module(prelude, Module),
    '$c_current_predicate'(_, Module:Head),
    (   '$get_predicate_attribute'(Module:Head, imported, Source)
    ->  Owner = Source
    ;   Owner = Module
    ),
    !.

shadowed_head(Module, Name/Arity, Owner) :-
    published_head(Module, Name, Arity),
    resolved_owner(Name, Arity, Owner),
    Owner \== Module.

shadowed_heads(Shadowed) :-
    findall(Module-PI-Owner, shadowed_head(Module, PI, Owner), Shadowed0),
    sort(Shadowed0, Shadowed).

:- dynamic planted_head/3.

% The plant publishes a name a tier already answers, from a module of its own,
% and requires the walk to report it. Without this a clean verdict would only
% mean the walk found nothing, which is also what a broken walk finds.
prove_shadow_eyesight :-
    (   shadow_candidate(Name/Arity),
        \+ published_head(_, Name, Arity),
        resolved_owner(Name, Arity, Occupant),
        Occupant \== '$library_shadow_plant'
    ->  true
    ;   format(user_error,
               'library autoload: every shadow candidate is already published by \c
                a library, so the walk could not be tested; add one no library \c
                publishes to shadow_candidate/1~n', []),
        halt(1)
    ),
    Plant = '$library_shadow_plant',
    functor(Head, Name, Arity),
    Plant:assertz(Head),
    Plant:export(Name/Arity),
    assertz(planted_head(Plant, Name, Arity)),
    (   shadowed_head(Plant, Name/Arity, Occupant)
    ->  true
    ;   format(user_error,
               'library autoload: the walk did not see a planted head named ~w, \c
                which ~w answers, so a clean result would say nothing~n',
               [Name/Arity, Occupant]),
        halt(1)
    ),
    retractall(planted_head(Plant, Name, Arity)),
    abolish(Plant:Name/Arity).

% The plant above proves the RESOLUTION half. This proves the ENUMERATION half,
% which the plant cannot: every library directory whose face registers a name
% and whose module is loaded must contribute at least one published head. The
% first version of the join compared a relative directory with the absolute one
% module_property/2 answers, so it enumerated nothing and reported every head
% clean over an empty set.
prove_shadow_enumeration :-
    findall(Directory,
            ( face_registered(Directory, _), library_module_in(Directory, _) ),
            Directories0),
    sort(Directories0, Directories),
    (   Directories \== []
    ->  true
    ;   format(user_error,
               'library autoload: no library face registers a name this walk can \c
                join to a loaded module, so the published-head check is \c
                vacuous~n', []),
        halt(1)
    ),
    forall(member(Directory, Directories),
           (   library_module_in(Directory, Module), published_head(Module, _, _)
           ->  true
           ;   format(user_error,
                      'library autoload: ~w registers names its own module does \c
                       not export, so the published-head check cannot see \c
                       them~n', [Directory]),
               halt(1)
           )).

report_shadowed([]) :-
    findall(Module-Name/Arity, published_head(Module, Name, Arity), Heads0),
    sort(Heads0, Heads), length(Heads, Count),
    format("library autoload: every published library head resolves to its own \c
            library, over ~d heads~n", [Count]).
report_shadowed([First|Rest]) :-
    Shadowed = [First|Rest],
    length(Shadowed, Count),
    format(user_error,
           'library autoload: ~d published library head(s) are answered by a \c
            module above the libraries in the execution chain, so the \c
            library\'s own clauses never run and nothing is said~n', [Count]),
    forall(member(Module-Name/Arity-Owner, Shadowed),
           format(user_error, '  ~w:~w~t~34| answered by ~w~n',
                  [Module, Name/Arity, Owner])),
    format(user_error,
           'give the head a name of its own, as the shipped libraries do with \c
            their hyphenated, domain-qualified spellings: a registered head is \c
            reached by name, and the name has to be free in every tier above \c
            lib/~n', []).
