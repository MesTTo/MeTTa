% Purpose: the DEVELOPMENT build, where a PlDoc mode line above a clause is a
%   checked type and `swipl -O` compiles the same clause to nothing extra.
%
%   Loading this file is the whole mechanism. It puts vendor/ on the library
%   path and imports mavis, whose expansion is a GLOBAL user:term_expansion, so
%   every file consulted AFTER it that carries a mode line gets `the/2` goals at
%   the head of its clause bodies. engine/*.pl gains no directive, no import and no
%   dependency: a production run never loads this file and never sees mavis, and
%   a mode line there is a comment like any other.
%
%   Two ways to use it, both from tests/prolog, which is where check.sh runs
%   every Prolog lane from:
%
%     swipl -q --on-error=status -g dev_typed_report -t 'halt(0)' dev_typed.pl
%       loads the engine typed and prints every predicate that gained checks.
%
%     swipl -q -g dev_typed_suites -t 'halt(0)' dev_typed.pl -- spaces.plt
%       runs existing plunit suites against the typed engine, which is what
%       says the annotations are TRUE of everything those suites do. The suites
%       come through argv rather than as further script files, because swipl
%       takes exactly one script file and treats the rest as arguments:
%       `swipl dev_typed.pl spaces.plt` loaded dev_typed.pl, put spaces.plt in
%       argv, and printed "No tests to run" [measured 2026-08-19].
%
%   The pack's own contract for a check is `when(ground(Value), must_be(Type,
%   Value))`, so a bound argument is checked at the call and an unbound one is
%   checked if and when it becomes ground. That is the whole reason the
%   annotated arguments are the ones that arrive GROUND, and it is a
%   correctness rule rather than a taste: a check on a non-ground value is a
%   when/2 coroutine, an ATTRIBUTE on every variable in that value, and a term
%   carrying one is no longer a VARIANT of the same term without one. The
%   engine compares stored terms with =@=/2, so annotating a term under
%   construction changes answers. Two suites said so
%   [measured 2026-08-19: translator_meta_store:function_store_keeps_newest_first
%   and specializer:compound_partial_key_has_stable_anonymous_variables].
% Assumes:
%   - the working directory is tests/prolog.
%   - mavis decides at LOAD time which half of itself to compile, reading
%     current_prolog_flag(optimise), so the two builds are two processes and
%     never one process choosing [source: vendor/mavis.pl, its
%     `:- if(current_prolog_flag(optimise,true)).`].
%   - vendor/quickcheck.pl declares has_type/2 multifile, and vendor/mavis.pl
%     drops its no-op checks with subsumes_term/2 and reads a structured
%     comment with string_codes/2. All three are changes this build needs and
%     all three are recorded where they were made; without the first, every
%     must_be/2 in the engine became a binding type INFERENCE
%     [measured 2026-08-19].
% Guarantees:
%   - the development build is TRANSPARENT: every plunit suite in this
%     directory passes under it, which is what dev_typed_suites/0 is for and
%     what says the annotations are TRUE rather than merely inserted
%     [measured 2026-08-19: 4,716ms for every suite typed against 4,113ms for
%     one untyped configuration, min of 3 each].
%   - dev_typed_report/0 fails the run if an annotated predicate gained NO
%     check, so a lane cannot pass because a mode line stopped parsing
%     [tested: test_the_engines_funnels_are_checked_in_the_development_build].
%   - dev_typed_selftest/0 prints `checked` or `stripped` for the planted
%     violation and never guesses which build it is in: it reads the same
%     optimise flag mavis reads
%     [tested: test_the_dev_build_checks_a_planted_type_violation_and_optimise_strips_it].
%   - expanding a mode line loads NO module, so a suite asking which modules
%     are resident reads the same answer under both builds. Both entry points
%     a lane runs check it, and it names the module and the remedy when it
%     fails [measured 2026-09-06: [] here, [backward_compatibility] with
%     vendor/mavis.pl's string_to_list/2 restored; command=swipl -q
%     --on-error=status -g dev_typed_selftest -t 'halt(0)' dev_typed.pl;
%     commit=60d6ca9089f50521bba869c3b7a87c92fd6a990f].
% Decides:
%   - the fixture lives here rather than in engine/, because a planted defect in
%     the engine's own source is a defect in the engine's own source.
%   - an argument that is a term under construction is left UNTYPED rather than
%     given a type that would both never be tested and change what the engine
%     stores. That is why the translation funnel carries one checked type and
%     three mode lines that record only modes.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- prolog_load_context(directory, Dir),
   atom_concat(Dir, '/vendor', Vendor),
   asserta(user:file_search_path(library, Vendor)).

:- use_module(library(mavis)).
:- use_module(library(apply), [maplist/3]).

% The mode-line vocabulary is MeTTa's; `must_be/2`'s is SWI's. They share a
% syntax and nothing joined them, so every `+Value:'Atom'` in the tree became a
% `must_be('Atom', Value)` that no clause could satisfy. `library(error)`'s
% `must_be/2` asks `has_type/2` and falls to `is_not/2` when it fails, and
% `is_not/2` raises `type_error(Type, Value)` without asking whether the type
% was ever defined -- so the tree reported a value as the wrong type when the
% truth was that the TYPE was unknown. Read alone the message accuses the
% value, which is why the backlog read as a pile of separate refusals rather
% than one missing bridge.
%
% What these clauses do, and what they do NOT do. Both sides are the same loop
% over the same 182 suites, the only difference being this block
% [measured 2026-09-21; commit=c6ed562a1a6f964aba906206f2558489b107dc24]:
%
%                  passed   failed   type errors
%     without        8615      363           150
%     with           8776      202            12
%
% 17 suites improve and none regresses. Every one of the 150 was a MeTTa name
% and not one of the 12 is -- 9 are `string' in suites/seams/lib_package.plt --
% so what is left are ordinary SWI type errors of the kind a mode line is FOR,
% findings this uncovered rather than residue it left.
%
% It does NOT make the lane green. 202 failures remain, of a different class:
% wrong answers and assertion mismatches rather than refused arguments, and
% nothing here addresses them.
%
% suites/libraries/lib_database.plt alone goes from 10 passed and 21 failed to
% 29 passed and 2 failed -- more than its 16 type errors, because a test that
% compares error TERMS also fails when the type error displaces the error the
% code meant to raise, and lib_database.plt:120 is exactly that. The two left
% there are typed-only and about variable sharing across a store-and-read round
% trip, not about types.
%
% Five MeTTa names are used this way, and two of them the engine already
% classifies, so those two ask it rather than restating its rules
% [measured 2026-09-21 over every mode line in every .pl outside vendor/:
% 'Atom' 84 uses, 'Symbol' 72, 'SpaceType' 28, 'Expression' 4, 'Number' 1].
% Counting lib/ and engine/ alone answered four and missed 'Number', which is
% an OUTPUT argument in a fixture and so defers until it is bound -- a use no
% suite currently reaches, and exactly the kind that would arrive later as
% another unexplained refusal.
:- multifile error:has_type/2.

% MeTTa's top type: an unevaluated term, which every term representing one is.
% The check is vacuous BY THE SEMANTICS rather than for convenience, and the
% annotation still earns its place by saying the argument is held rather than
% evaluated.
error:has_type('Atom', _).

%And therefore TOTAL: this clause accepts every term, so the deferred check
%decides nothing while its when/2 coroutine attaches to every variable in the
%argument and stops the term being a variant of itself. Saying so here keeps
%the two facts together: the clause that makes 'Atom' total and the
%declaration that it needs no runtime check.
:- multifile mavis:total_type/1.
mavis:total_type('Atom').

% A symptom of the syntax, not of the running program: `metatype_of/2` answers
% 'Grounded' for a name this engine holds a function for, so deriving from it
% would refuse `car-atom` where a mode line saying 'Symbol' means to accept it.
error:has_type('Symbol', Value) :- atom(Value).

% The engine's own two, asked rather than restated. `'is-expr'/2` is
% `list_shaped/1`, which accepts a partial list where `is_list/1` would not,
% and `'is-space'/2` takes a prefixed name or a handle. Both are pure
% semi-deterministic classifiers, so a type check pays nothing and changes
% nothing.
error:has_type('Expression', Value) :- metta_engine:'is-expr'(Value, true).
error:has_type('SpaceType', Value) :- metta_engine:'is-space'(Value, true).

% MeTTa's Number is Prolog's. Its one use is an OUTPUT argument, so it defers
% until bound and no suite reaches it today; it is here because the set is
% every MeTTa name a mode line uses, and leaving the unexercised one out is how
% the next reader meets this same refusal with no clue what it means.
error:has_type('Number', Value) :- number(Value).


% The expansion only sees SOURCE. engine/qlf_boot.pl leaves .qlf beside every
% engine unit, and an extensionless ensure_loaded resolves a fresh one
% (boot/init.pl '$qlf_file'/5), which skips term_expansion and reports every
% funnel as 0 inserted checks. The source flag is SWI's own bypass: its
% '$qlf_file' clause loads the .pl whenever the flag is true, no artifact
% deleted, nothing racing a concurrent warm boot.
:- set_prolog_flag(source, true).

%%%%%%%%%% The planted violation, and it is planted in BOTH directions %%%%%%%%%%

% Which modules are resident with mavis loaded and no mode line expanded yet.
% The pair of directives around the first annotated clause below measures what
% RUNNING the expansion adds, with the tooling's own libraries already in the
% Before set, so the difference is the expansion and nothing else.
%
% This is a transparency check, not bookkeeping. mavis's expansion runs inside
% every load this build performs, so a library IT reaches for is resident in a
% process the production build never puts it in, and the engine's own suites
% ask about resident modules: the vendored mode_declaration/2 called
% string_to_list/2, library(backcomp)'s deprecated spelling of string_codes/2,
% which autoloaded module backward_compatibility and failed
% translator_super:asking_whether_a_module_defines_a_name_loads_nothing --
% whose whole subject is that asking a module whether it defines a name loads
% nothing -- as though the engine had loaded it [measured 2026-09-06].
:- findall(Module, current_module(Module), Loaded),
   sort(Loaded, Before),
   nb_setval('$dev_typed_modules_before', Before).

% A mode line and a body that disagree with it the moment a caller passes a
% non-integer. Under the dev build the clause gains `the(integer, X)` before the
% body and the call is refused naming the type; under `swipl -O` the clause body
% is the body alone and the same call reaches the arithmetic, which reports a
% different error about a different thing.

%% dev_typed_planted_double(+Number:integer, -Doubled:integer) is det.
dev_typed_planted_double(Number, Doubled) :- Doubled is Number * 2.

% And a control with no mode line at all, so "the body changed" cannot be
% confused with "every body changed".
dev_typed_unannotated_double(Number, Doubled) :- Doubled is Number * 2.

:- findall(Module, current_module(Module), Loaded),
   sort(Loaded, After),
   nb_getval('$dev_typed_modules_before', Before),
   subtract(After, Before, Added),
   nb_setval('$dev_typed_expansion_modules', Added).

dev_typed_expansion_modules(Added) :-
    nb_getval('$dev_typed_expansion_modules', Added).

% The verdict on that measurement, called by BOTH entry points a lane runs, so
% neither the selftest nor the report can pass while the tooling drags a
% library into the process. Under -O the expansion is not compiled at all and
% the set is empty for that reason, which is the same answer for the other
% build's reason and is why this is not split by build.
dev_typed_expansion_is_transparent :-
    dev_typed_expansion_modules(Added),
    format("modules the first mode line loaded: ~q~n", [Added]),
    (   Added == []
    ->  true
    ;   format(user_error,
               "expanding a mode line loaded ~q, so the development build is \c
                not the production one: a suite that asks which modules are \c
                resident reads the tooling's load as the engine's. Find the \c
                autoloaded predicate the expansion in vendor/mavis.pl reaches \c
                for and spell it with the builtin it deprecates~n", [Added]),
        halt(1)
    ).

%%%%%%%%%% Reading the two builds apart %%%%%%%%%%

% Which build this process is, asked the way mavis asks it.
dev_typed_build(Build) :-
    (   current_prolog_flag(optimise, true)
    ->  Build = optimised
    ;   Build = development
    ).

% Whether a predicate's first clause body starts with inserted the/2 goals, and
% how many. This is the clause/2 comparison the whole item rests on: the
% question is not "did it raise" but "what did it compile to".
dev_typed_inserted_checks(Head, Count) :-
    clause(Head, Body),
    dev_typed_leading_checks(Body, 0, Count).

% Whether a goal IS an inserted check is mavis's fact, and checked_type/2 is
% where it lives. Spelling `subsumes_term(the(_, _), G)` here again was a second
% copy of it, and it silently under-counted the moment mavis grew the_out/2 for
% output arguments: this selftest read 1 check where the clause carried 2
% [measured 2026-09-21].
dev_typed_leading_checks((First, Rest), Seen, Count) :- !,
    (   mavis:checked_type(First, _)
    ->  Next is Seen + 1,
        dev_typed_leading_checks(Rest, Next, Count)
    ;   Count = Seen
    ).
dev_typed_leading_checks(Goal, Seen, Count) :-
    ( mavis:checked_type(Goal, _) -> Count is Seen + 1 ; Count = Seen ).

%%%%%%%%%% The selftest %%%%%%%%%%

% Run in both builds and the two outputs are the proof:
%   swipl -q --on-error=status -g dev_typed_selftest -t 'halt(0)' dev_typed.pl
%   swipl -O -q --on-error=status -g dev_typed_selftest -t 'halt(0)' dev_typed.pl
% The control is what makes this a differential rather than an assertion about
% one predicate. `dev_typed_unannotated_double/2` is the same body with no mode
% line above it, so under -O the two clauses must be the SAME clause and the two
% calls must give the SAME error. Reading only the annotated one would let
% "stripped" mean "raised something", and under -O the raw arithmetic raises a
% type_error too, just about a different thing.
dev_typed_selftest :-
    dev_typed_expansion_is_transparent,
    dev_typed_build(Build),
    dev_typed_inserted_checks(dev_typed_planted_double(_, _), Annotated),
    dev_typed_inserted_checks(dev_typed_unannotated_double(_, _), Control),
    dev_typed_bodies(Bodies),
    dev_typed_outcome(dev_typed_planted_double(abc, _), AnnotatedError),
    dev_typed_outcome(dev_typed_unannotated_double(abc, _), ControlError),
    format("build: ~w~n", [Build]),
    format("annotated clause checks: ~w~n", [Annotated]),
    format("unannotated clause checks: ~w~n", [Control]),
    format("clause bodies: ~w~n", [Bodies]),
    format("annotated call: ~q~n", [AnnotatedError]),
    format("unannotated call: ~q~n", [ControlError]),
    dev_typed_selftest_verdict(Build, Annotated, Control, Bodies,
                               AnnotatedError, ControlError).

dev_typed_outcome(Goal, Outcome) :-
    ( catch(Goal, Error, true) -> ( var(Error) -> Outcome = succeeded ; Outcome = Error )
    ; Outcome = failed ).

% The clause/2 comparison the item rests on: what the two clauses COMPILED to,
% not what they did when called.
dev_typed_bodies(Verdict) :-
    clause(dev_typed_planted_double(_, _), Annotated),
    clause(dev_typed_unannotated_double(_, _), Control),
    ( Annotated =@= Control -> Verdict = identical ; Verdict = different ).

dev_typed_selftest_verdict(development, Annotated, Control, Bodies,
                           AnnotatedError, ControlError) :-
    !,
    (   Annotated >= 2, Control =:= 0, Bodies == different,
        subsumes_term(error(type_error(integer, abc), _), AnnotatedError),
        subsumes_term(error(type_error(evaluable, abc/0), _), ControlError)
    ->  format("verdict: checked~n", [])
    ;   format(user_error,
               "the development build did not check the planted violation~n", []),
        halt(1)
    ).
dev_typed_selftest_verdict(optimised, Annotated, Control, Bodies,
                           AnnotatedError, ControlError) :-
    % The two errors agree on the FORMAL part and differ only in the context,
    % which names whichever predicate reported it and therefore must differ.
    (   Annotated =:= 0, Control =:= 0, Bodies == identical,
        AnnotatedError = error(Formal, _), ControlError = error(Formal, _),
        subsumes_term(type_error(evaluable, abc/0), Formal)
    ->  format("verdict: stripped~n", [])
    ;   format(user_error,
               "the optimised build did not strip the planted check~n", []),
        halt(1)
    ).

%%%%%%%%%% The report over the engine %%%%%%%%%%

% Every annotated predicate in the engine, and how many checks its first clause
% gained. A lane runs this: it consults the engine typed, which is itself the
% check that no annotation is malformed, and it FAILS if the total is zero,
% because a mode line that stopped parsing would otherwise read as success.
dev_typed_report :-
    dev_typed_expansion_is_transparent,
    dev_typed_engine,
    dev_typed_build(Build),
    format("build: ~w~n", [Build]),
    findall(Indicator-Clauses-Checks,
            ( dev_typed_annotated(Name, Arity),
              Indicator = Name/Arity,
              functor(Head, Name, Arity),
              findall(Count, dev_typed_inserted_checks(Head, Count), PerClause),
              length(PerClause, Clauses),
              sum_list(PerClause, Checks) ),
            Found),
    forall(member(Indicator-Clauses-Checks, Found),
           format("~w: ~w clause(s), ~w inserted check(s)~n",
                  [Indicator, Clauses, Checks])),
    maplist(dev_typed_checks, Found, Counts),
    sum_list(Counts, Total),
    length(Found, Predicates),
    format("typed: ~w predicates, ~w inserted checks~n", [Predicates, Total]),
    findall(Indicator, member(Indicator-_-0, Found), Unchecked),
    % A mode line has to be its own comment block: a `%%` line under a `%` line
    % is one comment starting with `%`, which is not a structured comment, and
    % PlDoc silently collects nothing. spaces:unstore_atom/3 was written that way and
    % reported 0 while every other funnel reported its checks [measured
    % 2026-08-19], so an annotation that stopped parsing FAILS the report
    % rather than quietly leaving one funnel unchecked.
    (   Build == development, Unchecked \== []
    ->  forall(member(Indicator, Unchecked),
               format(user_error,
                      "~w is listed as annotated and gained no check: its mode \c
                       line is not a structured comment, or the expansion \c
                       stopped firing~n", [Indicator])),
        halt(1)
    ;   true
    ).

dev_typed_checks(_-_-Checks, Checks).

%%%%%%%%%% Running the existing suites typed %%%%%%%%%%

% The report says the checks were INSERTED; this says they are TRUE. Every
% plunit suite named on argv is consulted here rather than passed as a further
% script file, because swipl takes exactly one of those.
dev_typed_suites :-
    current_prolog_flag(argv, Suites),
    (   Suites == []
    ->  format(user_error,
               "dev_typed_suites: name at least one .plt file after --~n", []),
        halt(2)
    ;   true
    ),
    %argv is BOTH this goal's input and the engine's, so the suite names are
    %read first and replaced with the token before any suite is consulted. A
    %suite's own load-time ensure_loaded of the engine is what boots it, and
    %the engine reads argv while it loads to decide whether to read the seats'
    %control files. Without this the typed run boots the pure kernel while the
    %plunit lane beside it boots under `-- extensions`, so the two disagree on
    %six suites for a reason that is the configuration rather than the types.
    set_prolog_flag(argv, [extensions]),
    forall(member(Suite, Suites), consult(Suite)),
    ( run_tests -> true ; halt(1) ).

% The engine, loaded once. A .plt used as the second file has already consulted
% it by the time an initialization goal runs, so this must not consult twice.
dev_typed_engine :-
    (   current_predicate(user:swrite/2)
    ->  true
    ;   consult('../../engine/qlf_boot.pl'),
        consult('../../engine/metta.pl')
    ).

% The funnels annotated so far. Named here rather than discovered, because
% "which predicates are supposed to be typed" is the thing a report should be
% able to be WRONG about: a predicate that lost its mode line shows up as zero
% checks instead of vanishing from the list.
dev_typed_annotated(metta_remove_atom, 3).
dev_typed_annotated(unstore_atom, 3).
dev_typed_annotated(remove_equation, 6).
dev_typed_annotated(translate_clause, 3).
