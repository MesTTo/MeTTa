% Purpose: gate that no shipped library calls an engine predicate the engine
%     does not publish, the same contract a_backend_calls_only_published_surface
%     holds a backend to.
% Assumes:
%     - surface_walk.pl decides what published means, so this file and the
%       backend GATE in static_checks.pl cannot drift apart on the definition
% Guarantees:
%     - exits nonzero when a library reaches past the published surface, naming
%       the library predicate, the engine predicate and the remedy
%     - exits nonzero when the walk stops seeing a planted reach, so a clean
%       result is a claim this file has just tested rather than an assumption
%       [tested: scan_sees_every_planted_reach, one planted door per way a
%       call hides; commit=8fa9d546b3eebf3424ef1d667feab40c6b0f32ae]
%     - compares answer bags, output and raised errors for every reused engine
%       name; a missing case refuses and planted changed meanings are detected
%       [tested: planted_library_meaning_change_is_named,
%       planted_library_shadow_is_named; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427]
%     - an execution module resolves no name against SWI's library index, so a
%       deprecated library alias stays undefined in a space
%       [tested: library_lazy_import_differential; commit=25206c8416042991709423d6d4c2d51bc324ac93]
% Owns resources: each meaning arm releases its scratch space and restores
%     prelude translator registrations, including on failure.
% Fails when:
%     - a call is assembled at run time from a term no analysis can see,
%       `Goal =.. L, call(Goal)` being the shape. That is the residue this
%       shares with every other static walk in the tree.
% Decides:
%     - lib/ is in scope and extensions/python/metta/_binding/shim.pl is not. shim.pl is consulted
%       by _engine.py as the Python tier's own implementation, so it is
%       engine-internal by construction rather than an extension
%       [source: extensions/python/metta/_binding/runtime.py:1114, _consult_shim; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
% Open Obligations:
%     To Do: None
%     Hacks: None
%     Future Enhancements: None

% A REPORT until 2026-08-21, and the reason it stayed one was a decision nobody
% had made rather than a walk nobody trusted: whether the library tier is meant
% to be arm's length from the engine the way a backend is. Nineteen predicates
% were involved and they were not one kind of thing, so declaring them wholesale
% would have made `service` mean "whatever anyone happens to call", which
% enforces nothing. They are decided one at a time now, in engine/ext_points.pl,
% each with the contract it promises written beside it, and the queue is empty.
%
% What makes the declaration mean something is that it is no longer only a
% comment: a declared seam is EXPORTED by the engine's module, and
% published_surface/1 asks the module system for that export list rather than
% reading the declaration table a second time. So a seam declared and never
% defined is not exported and does not pass this gate either.

:- ensure_loaded(surface_walk).
:- ensure_loaded(prelude_model).
:- initialization(main, main).

library_directories(['../../lib']).

main :-
    consult('../../engine/qlf_boot.pl'),
    consult('../../engine/metta.pl'),
    library_lazy_import_differential,
    no_library_shadows_an_engine_function,
    forall(( expand_file_name('../../lib/*/*.pl', Files), member(File, Files) ),
           ensure_loaded(File)),
    library_directories(Directories),
    reaches_past_surface(Directories, Reaches0),
    findall(Callee-Caller, member(Caller-Callee, Reaches0), Reaches1),
    sort(Reaches1, Reaches),
    extension_clause_count(Directories, Examined),
    report(Reaches, Examined).

%%%% The .metta half: compare meanings, not head-pattern spellings %%%%

library_metta_source(File) :-
    tree_directory('../../lib', Directory),
    directory_member(Directory, File, [recursive(true), extensions([metta])]).

library_source_forms(File, Forms) :-
    filereader:read_metta_source(File, Source),
    parse_metta_source(Source, Forms).

library_definition_name(Form, Name) :-
    parsed_form_parts(Form, function, _, [=,Head,_]),
    ( atom(Head) -> Name = Head ; Head = [Name|_], atom(Name) ).

library_engine_name(Name) :- builtin_fun(Name), !.
library_engine_name(Name) :- translator:metta_special_form(Name).

% The shipped compatibility library is held to its vendored upstream model.
% Every other library keeps the engine's existing meaning at its old arities.
library_meaning_reference(File, Forms) :-
    same_file(File, '../../lib/lib_he/lib_he.metta'), !,
    library_source_forms('../conformance/petta/lib/lib_he.metta', Forms).
library_meaning_reference(_, []).

library_meaning_case(Name, Text) :- prelude_spec_case(Name, Text).
library_meaning_case(Name, Text) :- prelude_spec_expansion_case(Name, Text).
library_meaning_case(first, "(first (a b))").
library_meaning_case(first, "(first (1 2))").
library_meaning_case(first, "(first ())").
library_meaning_case(once, "(once (superpose (a b a)))").
library_meaning_case(once, "(once (superpose ()))").
library_meaning_case(once, "(once 3)").
library_meaning_case(once, "(once (trace! touched (superpose (a b))))").
library_meaning_case(unify, "(unify (a $x) (a 1) $x no)").
library_meaning_case(unify, "(unify (a $x) (b 1) $x no)").
library_meaning_case(unify, "(unify &self (absent $x) $x no)").
library_meaning_case(evalc, "(evalc (+ 1 2) &self)").
library_meaning_case('get-type-space', "(get-type-space &self 5)").
library_meaning_case('get-type-space', "(get-type-space &self a)").
library_meaning_case('add-reduct',
    "(let $r (add-reduct &self (= (meaning-added) (+ 1 2))) (observed $r (collapse (match &self (= (meaning-added) $v) $v))))").

library_meaning_cases(File, Names, Cases) :-
    forall(member(Name, Names),
           ( library_meaning_case(Name, _) -> true
           ; throw(error(existence_error(library_meaning_case, File:Name),
                         context(library_meaning_cases/3,
                                 'add engine answer cases before reusing this name'))) )),
    findall(Name-Text,
            (member(Name, Names), library_meaning_case(Name, Text)), Cases).

% Read declarations, equations and translator registrations in written order.
% Other initializers and service connections stay outside this name check.
% Both arms reuse one released scratch identity, so
% source-space names in values and errors are compared without renaming them.
library_meaning_observations(Forms, Cases, Observed) :-
    Space = '&library-meaning',
    setup_call_cleanup(space_module(Space, _),
        ( maplist(library_meaning_install(Space), Forms),
          maplist(library_meaning_observe(Space), Cases, Observed) ),
        (metta_release_space(Space), install_engine_prelude)).

library_meaning_install(Space, Form) :-
    parsed_form_parts(Form, Kind, _, Row),
    ( Kind == function -> metta_add_atom(Space, Row, _)
    ; Kind == expression, Row = [':',_,_] -> metta_add_atom(Space, Row, _)
    ; Kind == runnable, Row = ['add-translator-rule!'|_]
    -> once(evalc(Row, Space, _))
    ; true ).

library_meaning_observe(Space, Name-Text, Name-Text-Observation) :-
    sread(Text, Term),
    metta_substitute_self(Space, Term, Bound),
    prelude_spec_observed_term(Space, Bound, Observation).

library_meaning_differences(Cases, Expected, Actual, Differences) :-
    findall(Name-Text-Before-After,
            ( nth0(Index, Cases, Name-Text),
              nth0(Index, Expected, Name-Text-Before),
              nth0(Index, Actual, Name-Text-After),
              \+ prelude_spec_agrees(Before, After) ),
            Differences).

library_meaning_findings(File-Forms, Count-Findings) :-
    findall(Name,
            ( member(Form, Forms), library_definition_name(Form, Name),
              library_engine_name(Name) ), Names0),
    sort(Names0, Names),
    library_meaning_cases(File, Names, Cases), length(Cases, Count),
    ( Cases == [] -> Findings = []
    ; library_meaning_reference(File, Reference),
      library_meaning_observations(Reference, Cases, Expected),
      library_meaning_observations(Forms, Cases, Actual),
      library_meaning_differences(Cases, Expected, Actual, Differences),
      maplist(library_meaning_file(File), Differences, Findings) ).

library_meaning_file(File, Difference, File-Difference).

no_library_shadows_an_engine_function :-
    findall(File-Forms,
            (library_metta_source(File), library_source_forms(File, Forms)),
            Libraries),
    setup_call_cleanup(metta_host_set_silent(true),
        ( maplist(library_meaning_findings, Libraries, Reports),
          pairs_keys_values(Reports, Counts, FindingLists),
          sum_list(Counts, Checked), append(FindingLists, Findings),
          library_meaning_report(Findings, Checked) ),
        metta_host_set_silent(false)).

library_meaning_report([], Checked) :-
    !,
    ( planted_library_shadow_is_named,
      planted_library_meaning_change_is_named
    -> format("library surface: ~d engine-name cases preserve answer bags, \c
               output and raised errors; changed and duplicate equations \c
               are detected; the functional-pattern note and lazy-import \c
               cell pass~n", [Checked])
    ;  format(user_error,
              "library meaning differential missed a planted changed meaning~n", []),
       halt(1) ).
library_meaning_report(Findings, Checked) :-
    format(user_error,
           "library surface: changed meaning among ~d engine-name cases~n", [Checked]),
    forall(member(File-(Name-Text-Before-After), Findings),
           format(user_error,
                  "  ~w: ~w on ~s~n    expected ~q~n    actual   ~q~n",
                  [File, Name, Text, Before, After])),
    format(user_error,
           "Use a distinct library name for different engine meaning, or \c
            restore the declared reference equations.~n", []),
    halt(1).

% A wrong equation has no nested head pattern for the old note-based check to
% see. A duplicate has the same answers as a set and a different answer bag.
planted_library_meaning_change_is_named :-
    prelude_spec_fixture(File),
    prelude_declaration('if-equal', Type),
    prelude_shipped_equation('if-equal', Equation),
    Correct = [parsed(expression,0,[':','if-equal',Type]),
               parsed(function,0,Equation)],
    Wrong = [parsed(expression,0,[':','if-equal',Type]),
             parsed(function,0,[=,['if-equal',_,_,Then,_],Then])],
    append(Correct, [parsed(function,0,Equation)], Duplicate),
    library_meaning_findings(File-Correct, Count-[]),
    Count > 0,
    forall(member(Changed,[Wrong,Duplicate]),
           ( library_meaning_findings(File-Changed, Count-Findings),
             member(File-('if-equal'-_-_-_), Findings) )).

% Keep both note routes observable. Functional-pattern lowering once made the
% old defined_label-only scan miss precisely this planted Predicate collision.
planted_library_shadow_is_named :-
    sread("(= (metta-planted-shadow ((Evaluation (Predicate $x)) $t)) $x)", Form),
    setup_call_cleanup(
        retractall(translator:head_pattern_note(_, _, _, _, _)),
        ( translate_clause(Form, _),
          translator:head_pattern_note(_, 'metta-planted-shadow', _,
                                       'Predicate', Reason),
          engine_meaning_reason(Reason) ),
        retractall(translator:head_pattern_note(_, _, _, _, _))).

engine_meaning_reason(defined_label(_)).
engine_meaning_reason(functional_pattern).

% Run before any library is consulted. An execution module never resolves a
% name against SWI's library index (refuse_autoload_into_exec_modules/0), so
% the deprecated alias sumlist/2, which the index would supply from
% library(backcomp), stays undefined in a space: the shadow repair imports
% nothing for it and a call raises the existence error, while the library
% itself is never loaded.
library_lazy_import_differential :-
    Space = '&library-lazy-import',
    setup_call_cleanup(space_module(Space, Module),
        ( functor(Head, sumlist, 2),
          assertion(\+ current_predicate(backward_compatibility:sumlist/2)),
          spaces:metta_restore_inherited_predicate(Module, sumlist, 2),
          assertion(\+ predicate_property(Module:Head, imported_from(_))),
          catch(Module:sumlist([1,2,3], _), error(Formal, _), true),
          assertion(Formal == existence_error(procedure, Module:sumlist/2)),
          assertion(\+ current_predicate(backward_compatibility:sumlist/2)) ),
        metta_release_space(Space)).

report([], Examined) :-
    !,
    planted_internal(Internal),
    (   published_surface(Internal)
    ->  format(user_error,
               'the planted reach ~w is published surface, so it proves \c
                nothing; pick an engine predicate that is not~n', [Internal]),
        halt(1)
    ;   scan_sees_every_planted_reach(Total, Missed),
        (   Missed == []
        ->  format("library surface: no library reaches past the published \c
                    surface in ~d clauses, and the walk saw a planted reach by \c
                    each of ~d doors~n", [Examined, Total])
        ;   length(Missed, Blind),
            Seen is Total - Blind,
            format(user_error,
                   'the library surface walk saw ~d of ~d planted reaches, so \c
                    its clean result says nothing~nit is blind to: ~w~n',
                   [Seen, Total, Missed]),
            halt(1)
        )
    ).
report([First|Rest], Examined) :-
    Reaches = [First|Rest],
    findall(Callee, member(Callee-_, Reaches), Callees0),
    sort(Callees0, Callees),
    length(Callees, Count),
    format(user_error,
           "library surface: ~d engine predicates are called from lib/ \c
            without being published, over ~d clauses~n", [Count, Examined]),
    forall(member(Callee, Callees),
           ( findall(Caller, member(Callee-Caller, Reaches), Callers),
             format(user_error, "  ~w~t~34| ~w~n", [Callee, Callers]) )),
    format(user_error,
           "each is a decision: publish it with seam:kind(Name/Arity, \c
            service) in engine/ext_points.pl, or change the library not to need \c
            it~n", []),
    % halt/1 rather than failing, because a failed initialization goal prints
    % `user:main: false` over the report it just produced.
    halt(1).
