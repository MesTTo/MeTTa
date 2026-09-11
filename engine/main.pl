% Purpose: run the standalone MeTTa command-line entry point and display each
%   result from a requested MeTTa source file.
% Guarantees:
%   - a failed engine boot ends the standalone command before running a
%     program [tested: tests/shell/test_packaged_cli.sh; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
%   - command-line answers use sdisplay/2, so host-only values and non-finite
%     numbers remain printable presentation values without weakening
%     swrite/2's reader-inverse contract [tested:
%     test_non_finite_floats_print_the_arbiters_spellings; commit=c1eaa36c7a2089801fe9da3cbec3fc02833d66fe].
%   - the no-argument demo defines a MeTTa equation, calls it from Prolog
%     through the space's module, and runs every loaded backend selftest
%     [tested: test_the_bare_demo_runs_the_interop_example_and_backend_selftests;
%     commit=86222967a4198e11103e63a60ec8637c6ac9cb27].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%The engine loads through SWI's Quick Load Format: engine/qlf_boot.pl
%purges stale .qlf transitively first, then its qlf_load_engine/0 consults
%the umbrella under qcompile(auto), so every engine source compiles to a
%.qlf beside itself on the first boot and loads from it afterwards.
%Measured on this box: warm boot 0.08s against 0.19s from source,
%generation 0.24s once; the earlier study measured the same idiom at 2.37x
%in instructions with byte-identical output over 25 examples, re-checked
%2026-08-25 at 5/5 byte-identical either way. The .qlf files and
%engine/.qlf-stamp are build artifacts and .gitignored: a committed .qlf
%whose mtime beats its source would shadow edits silently, the exact
%hazard lib/lib_import/lib_import.pl's cascade documents.
%
%The load itself lives there rather than here because this file is not the
%only host that runs it: extensions/cmetta/cmetta.c consults the same two
%files in the same order, and used to spell the second one itself. That
%header carries the staleness story, the read-only fallback, the flag
%scoping and what the recovery does and does not cover.
% The entry point owns its clauses. Only the demonstration's Prolog function
% must reach the host tier so import_prolog_function/2 can register it.
% [tested: test_the_bare_demo_runs_the_interop_example_and_backend_selftests;
% commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- module(metta_main, [prologfunc/2]).
:- set_module(base(metta_engine)).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(listing), [listing/1]).
:- ensure_loaded(qlf_boot).
% SWI prints a directive exception and continues consulting. This standalone
% entry owns process termination; embedding hosts call qlf_load_engine/0 and
% receive its exception through their own query boundary.
:- catch((metta_qlf_boot:qlf_load_engine -> true ; halt(1)), Error,
         (print_message(error, Error), halt(1))).

%Tokens the engine reads for itself, which are therefore not the file to run.
%`extensions` asks engine/metta.pl to read every seat's control file and load
%what each declares; it is stripped here for the same reason the silent flags
%are, so that a bare `swipl -s engine/main.pl -- extensions` still means the
%demo rather than a file called "extensions".
is_engine_flag(silent).
is_engine_flag('--silent').
is_engine_flag('-s').
is_engine_flag(extensions).
is_engine_flag('--verbose').
is_engine_flag(Argument) :- atom_concat('--actor=', _, Argument).
is_engine_flag(Argument) :- atom_concat('--generation=', _, Argument).

strip_engine_flags([], []).
strip_engine_flags([Arg|Rest], Filtered) :-
        is_engine_flag(Arg),
        !,
        strip_engine_flags(Rest, Filtered).
strip_engine_flags([Arg|Rest], [Arg|Filtered]) :-
        strip_engine_flags(Rest, Filtered).

prologfunc(X,Y) :- Y is X+1.

%The equation compiles into &self's space module, so both the listing and the
%direct Prolog call name that module; the bare spellings stopped resolving when
%the space model moved &self out of user, and listing/1 was the goal that threw,
%because SWI DWIMs an unqualified name against the calling module.
prolog_interop_example :- import_prolog_function(prologfunc, _),
                          process_metta_string("(= (mettafunc $x) (prologfunc $x))", _),
                          space_module('&self', Space),
                          listing(Space:mettafunc),
                          call(Space:mettafunc, 30, R),
                          format("mettafunc(30) = ~w~n", [R]).

%The demo runs every loaded backend's own smoke test. It used to call
%mork_test/0 by name behind an `Args = [mork]` branch, which is why this file
%knew a backend existed at all; with no backend loaded the forall runs nothing
%and the demo is what it always was.
main :- current_prolog_flag(argv, RawArgs),
        strip_engine_flags(RawArgs, Args),
        ( Args = [] -> prolog_interop_example,
                       %forall/2 over the predicate's solutions cannot see a
                       %failing clause, so the demo walks the loaded clauses
                       %and a selftest that fails ends the run naming itself.
                       forall(clause(seam:backend_selftest, Selftest),
                              (   call(Selftest)
                              ->  true
                              ;   format(user_error,
                                         "backend selftest failed: ~p~n",
                                         [Selftest]),
                                  halt(1)
                              ))
        ; Args = [File|_] -> load_metta_file(File,Results),
                             maplist(sdisplay,Results,ResultsR),
                             maplist(format("~w~n"), ResultsR)
        ),
        halt.

:- initialization(main, main).
