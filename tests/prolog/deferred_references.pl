% Purpose: hold, in one place, every name this tree reaches without defining,
%     with the reason each is deferred rather than missing, and run the
%     undefined-predicate walk that each lane enforcing undefined-ness shares,
%     so the fact is stated once instead of once per lane.
% Assumes:
%     - the caller has already put the tree it wants checked into the process
%       and set the autoload flag it wants checked under. This file loads
%       nothing of the tree itself, because the three callers load different
%       trees: engine/check.sh's `prolog` lane consults engine/main.pl
%       tokenless, tests/prolog/static_checks.pl consults engine/metta.pl and
%       runs a representative source, and tests/prolog/library_autoload.pl
%       consults lib/*/*.pl.
% Guarantees:
%     - undefined_findings/2 reports every undefined name no deferred_reference/3
%       row licenses, each with the file and line of the clause reaching it, and
%       reports a name a row DOES license but from a file the row does not name,
%       so widening a deferred call to a new caller is a finding rather than a
%       silent pass
%     - undefined_findings/2 also reports every row whose call site this process
%       actually loaded and whose name the walk did NOT report, so a row that
%       has stopped being needed fails the lane instead of sitting there. That
%       is the half every mature suppression mechanism ended up with -- mypy's
%       warn_unused_ignores, PHPStan's --fail-on-unused-baseline and Rust's
%       #[expect(...)], which warns when the lint does not fire -- and this
%       tree needed it: PROLOG_KNOWN_UNDEFINED carried mettafunc/2 long after
%       the walk stopped reporting it
%       [measured 2026-09-20: the raw walk over engine/main.pl with autoload
%       off reports lib_file:metta_staged_publish/2 and nothing else;
%       commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
%     - undefined_findings/2 throws rather than answering clean when the walk
%       failed to report a call this file planted, so "no findings" is a claim
%       the same pass has just tested
%       [tested: tests/prolog/deferred_references_selftest.pl; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
%     - undefined_verdict/0 prints both kinds and halts 0 or 1. It halts rather
%       than returning for the reason library_autoload.pl records: engine/main.pl
%       carries initialization(main, main) and would otherwise run its demo over
%       the verdict.
% Fails when:
%     - a call is assembled at run time from a term no analysis can see,
%       `Goal =.. L, call(Goal)` being the shape, which is the residue this
%       shares with every other static walk in the tree.
%     - a row names a call site no lane loads. Nothing then evaluates the row in
%       either direction, so it can neither exempt nor go stale. Rows are
%       checked against the files a lane actually read, never against a list of
%       lanes, which is what keeps a lane from being a column here.
% Decides:
%     - a row licenses a name only from the files it names. The scope of a row
%       is not written down: it is derived from those files against
%       source_file/1, the walker's own record of what it read.
% Open Obligations:
%     To Do: None
%     Hacks: None
%     Future Enhancements: None

:- module(deferred_references,
          [ deferred_reference/3,
            undefined_findings/2,
            unexpected_sites/2,
            stale_rows/2,
            undefined_report/0,
            report_stale/1,
            undefined_verdict/0
          ]).

% Explicit, because every caller runs with the autoload flag off: that is the
% configuration the walk exists to check, and an unimported name here would be
% a finding about this file rather than about the tree.
:- use_module(library(check), [list_undefined/0]).
:- use_module(library(lists), [member/2, memberchk/2]).

%!  deferred_reference(?PI, ?Files, ?Reason) is nondet.
%
%   A name the tree reaches without defining, the repo-relative files whose
%   clauses are licensed to reach it, and why that is correct rather than a
%   defect. Shrink this table, never grow it: a new row is a claim that a name
%   cannot be resolved where it is used, and that claim has to be argued.

deferred_reference(lib_file:metta_staged_publish/2,
                   ['engine/packages.pl'],
                   'package_laws is the bootstrap prelude: (package requires) runs \c
                    before any packaging library is merged, so the bootstrap \c
                    bottoms out at a library that requires nothing, and the \c
                    engine boot loads it eagerly at engine/metta/interop.pl. It \c
                    therefore resolves lib_file inside the clause that publishes, \c
                    with metta_engine:library/2 and use_module/2 on the line above \c
                    the call, which is what keeps lib_file out of the boot and \c
                    what forces the call to be module-qualified. The load-time \c
                    import was tried and measured wrong: it makes this walk clean \c
                    and breaks lib-surface with \c
                    unregistered_builtin_implementation(lib_file:\'append-file!\'/3) \c
                    and memory-scale-gate on the boot cost, because a library \c
                    loaded while the engine is coming up registers its builtins \c
                    too early. Deferring package_laws itself instead would move \c
                    the count from this one name to the five interop.pl already \c
                    calls qualified.').

deferred_reference(source_observation:observe_source/4,
                   ['lib/lib_observe/lib_observe.pl'],
                   'lib_observe calls metta_ensure_source_observation/0 first, \c
                    which is what loads engine/source_observation.pl: an engine \c
                    nobody asks for an observation pays nothing for one, so the \c
                    module is absent at load time on purpose.').

deferred_reference(user:py_call/2,
                   ['lib/lib_thread/lib_thread.pl'],
                   'janus\'s. Every lib_thread call site is guarded by \c
                    current_predicate(py_call/2) or current_predicate/1 on a \c
                    Python-seat predicate, and a tokenless engine has no Python \c
                    seat.').

deferred_reference(user:py_call/1,
                   ['lib/lib_thread/lib_thread.pl'],
                   'janus\'s, the call that discards its return: converting the \c
                    return of a host cleanup or cancellation callable raised on a \c
                    leaf Atom (docs/journal/2026-09-08-a-scope-owns-its-children.md), \c
                    so lib_thread calls those through py_call/1, and only for a \c
                    host(...) record a Python seat wrote; a tokenless engine has \c
                    no Python seat.').

deferred_reference(native_install:'$activate_static_extension'/1,
                   ['lib/_support/native_install.pl'],
                   'SWI\'s, and defined only on a host compiled with \c
                    O_STATIC_EXTENSIONS, the WebAssembly one (src/pl-load.c). \c
                    The one call runs under static_host/0, which tests for \c
                    this definition, as boot/syspred.pl does to choose its \c
                    static use_foreign_library/1; a host that loads shared \c
                    objects takes the other branch. That predicate is not the \c
                    route, because it runs the activation through \c
                    initialization(_, now), which prints a missing extension \c
                    instead of raising it.').

:- dynamic captured/1, capturing/0.

% Taking list_undefined's report as DATA rather than as text. The hook succeeds,
% which is what stops the message being printed, and the capturing/0 guard keeps
% it from swallowing a report raised by anything other than our own walk
% [source: SWI-Prolog 10.1 Reference Manual, message_hook/3; the same idiom and
% the same reason as tests/prolog/library_autoload.pl].
:- multifile user:message_hook/3.
user:message_hook(check(undefined_procedures, Rows), _Kind, _Lines) :-
    capturing,
    assertz(captured(Rows)).

%!  undefined_findings(-Unexpected:list, -Stale:list) is det.
%
%   Unexpected holds PI-Site atoms for every undefined name no row licenses from
%   that site. Stale holds the PI of every row whose files this process loaded
%   and whose name the walk did not report.
%
%   The walk proves its own eyesight in the SAME pass, by planting a clause that
%   calls a name this file owns and never defines and then requiring the walk to
%   report it, so a clean answer is a claim just tested rather than assumed.
%   Owning the name is what stops the proof passing vacuously: a plant chosen
%   from real library exports goes quiet the day something starts importing it,
%   which is why library_autoload.pl carries five candidates and has to move
%   between them. Planting before the single walk, rather than running a second
%   walk after it, keeps the cost at one traversal
%   [measured 2026-09-20: the walk over the 137 source files of a tokenless
%   engine boot costs about 4s, so a second pass would double it in all three
%   lanes; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].

undefined_findings(Unexpected, Stale) :-
    walk_proving_eyesight(Rows),
    unexpected_sites(Rows, Unexpected),
    stale_rows(Rows, Stale).

%!  unexpected_sites(+Rows, -Unexpected) is det.
%!  stale_rows(+Rows, -Stale) is det.
%
%   The two decisions, as functions of the walk's output and the database. They
%   are separate from the walk so each can be put a synthetic Rows and checked
%   in both directions without a four-second traversal or a second table
%   [tested: tests/prolog/deferred_references_selftest.pl; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].

unexpected_sites(Rows, Unexpected) :-
    probe(Probe),
    findall(PI-Site,
            ( member(PI-Callers, Rows),
              PI \== Probe,
              member(Caller, Callers),
              site_of(Caller, File, Site),
              \+ ( deferred_reference(PI, Licensed, _),
                   member(Relative, Licensed),
                   sub_atom(File, _, _, 0, Relative) ) ),
            Unexpected0),
    sort(Unexpected0, Unexpected).

stale_rows(Rows, Stale) :-
    findall(PI,
            ( deferred_reference(PI, Licensed, _),
              \+ already_defined(PI),
              member(Relative, Licensed),
              source_file(Loaded),
              sub_atom(Loaded, _, _, 0, Relative),
              \+ memberchk(PI-_, Rows) ),
            Stale0),
    sort(Stale0, Stale).

walk_proving_eyesight(Rows) :-
    retractall(captured(_)),
    setup_call_cleanup(
        assertz(user:(deferred_references_probe :- deferred_references_probe_target)),
        walk(Rows),
        retractall(user:deferred_references_probe)),
    probe(Probe),
    (   memberchk(Probe-_, Rows)
    ->  true
    ;   throw(error(deferred_references(the_walk_reported_nothing, Probe), _))
    ).

% A row is load-bearing only while the name it licenses is absent. A lane that
% loads the provider resolves the name and the walk rightly says nothing, so
% that silence is not staleness: tests/prolog/library_autoload.pl consults every
% lib/*/*.pl, lib_file included, while engine/check.sh's `prolog` lane consults
% a tokenless engine that never reaches it. Deriving scope from whether the
% predicate is DEFINED, rather than from which lane is running, is what keeps a
% lane from becoming a column in the table.
already_defined(Module:Name/Arity) :-
    functor(Head, Name, Arity),
    catch(predicate_property(Module:Head, defined), _, fail).

% The name the eyesight plant calls. This file owns it and never defines it, so
% the walk reporting it is a fact about the walk rather than about what the tree
% happens to import today.
probe(user:deferred_references_probe_target/0).

walk(Rows) :-
    setup_call_cleanup(assertz(capturing), list_undefined, retractall(capturing)),
    ( captured(Rows) -> true ; Rows = [] ).

% The walk reports a caller as a clause, in any of three shapes, so the file and
% line come from the clause reference rather than from the term. The three
% shapes are tests/prolog/library_autoload.pl's, which met them first; a clause
% whose file the database has forgotten still has to be reported, hence the
% fallback.
site_of(Location, File, Site) :-
    clause_reference(Location, Ref),
    clause_property(Ref, file(File)),
    clause_property(Ref, line_count(Line)),
    !,
    format(atom(Site), '~w:~d', [File, Line]).
site_of(Location, '', Site) :-
    format(atom(Site), '~w', [Location]).

clause_reference(clause_term_position(Ref, _), Ref) :- !.
clause_reference(clause(Ref), Ref) :- !.
clause_reference(Ref, Ref) :- blob(Ref, clause).

%!  undefined_report is semidet.
%!  undefined_verdict is det.
%
%   Run the walk and print both kinds of finding. undefined_report/0 then
%   succeeds when there was nothing to print, which is what a driver running
%   further checks after it needs; undefined_verdict/0 turns that into a process
%   status, which is what a lane whose whole job this is needs. The halt matters
%   there for the reason library_autoload.pl records: engine/main.pl carries
%   initialization(main, main) and would otherwise run its demo over the verdict.

undefined_verdict :-
    (   undefined_report
    ->  halt(0)
    ;   halt(1)
    ).

undefined_report :-
    undefined_findings(Unexpected, Stale),
    forall(member(PI-Site, Unexpected),
           format(user_error,
                  'undefined: ~q is referenced by ~w and no deferred_reference/3 \c
                   row licenses it there~n', [PI, Site])),
    report_stale(Stale),
    Unexpected == [],
    Stale == [].

%!  report_stale(+Stale:list) is det.
%
%   The staleness sentence, in one place, because it is about the table rather
%   than about the lane and reads the same everywhere. The unexpected half is
%   framed by each lane instead: the repair for an engine file and the repair
%   for a shipped library are different sentences.
report_stale(Stale) :-
    forall(member(PI, Stale),
           format(user_error,
                  'stale exemption: ~q has a deferred_reference/3 row, this \c
                   process loaded the file the row names, and the walk did not \c
                   report the name; remove the row~n', [PI])).
