% Purpose: run ONE reference-loading case in a tight loop until it fails, so an
%   intermittent that needs minutes through plunit is reproduced in seconds.
%   The case is the suspended background qualified query: a source holding
%   `(from "<dependency>" (qualified q))` loaded under the background policy
%   from inside an SWI engine, which is what
%   reference_loading:a_suspended_background_qualified_query_survives_release
%   drives once per forall generator.
% Assumes: argv is [Count]; run from tests/prolog, where the relative loads
%   below resolve. It reuses the suite's own fixture helpers rather than
%   copying them, so the case cannot drift from the test it reproduces.
% Guarantees:
%   - stops at the FIRST failure and prints the iteration and the error, or
%     reports the count when every iteration passed
%     [measured 2026-09-20: on the unfixed tree it printed `iteration 421
%     raised:` and stopped, and on the fixed tree `6000 iterations, no
%     failure`; commit=WORKTREE].
%   - a failure that raises and a failure that merely fails are reported
%     apart, because this defect has produced both. Only the raising branch has
%     been observed here; the other is read from the code
%     [source: main/1's forall prints `failed without raising` where
%     iteration/1's catch_with_backtrace prints `raised:`; commit=WORKTREE].
% Fails when: the failure needs state from the other 37 tests in the suite.
%   It does not: measured 2026-09-20, one test alone failed 1 run in 20 through
%   plunit, and this loop reaches the same refusal within a few hundred
%   iterations, about a second.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- use_module(library(lists), [member/2]).
:- ensure_loaded('../../engine/qlf_boot.pl').
:- ensure_loaded('../../engine/metta.pl').
:- ensure_loaded('../suites/reader/reference_loading.plt').
:- initialization(main, main).

case :-
    plunit_reference_loading:loading_fixture(Path, Home, A, _),
    plunit_reference_loading:loading_aux_file(metta, "(= (loading-value) 42)\n", Dependency),
    format(string(Source), "(from \"~w\" (qualified q))\n", [Dependency]),
    plunit_reference_loading:loading_write(Path, Source),
    plunit_reference_loading:loading_option(A, load, background),
    setup_call_cleanup(
        engine_create(ready,
            ( metta_add_atom(A, [from, Path], _),
              metta_engine:metta_reference_wait(Home),
              plunit_reference_loading:loading_answers(A, ['q.loading-value'], [42]),
              engine_yield(ready) ), Engine),
        engine_next(Engine, ready),
        engine_destroy(Engine)).

iteration(N) :-
    plunit_reference_loading:loading_setup(""),
    catch_with_backtrace(
        setup_call_cleanup(true, case, plunit_reference_loading:loading_cleanup),
        Error,
        ( format(user_error, "iteration ~w raised:~n", [N]),
          print_message(error, Error),
          throw(stopped) )).

main([CountAtom]) :-
    atom_number(CountAtom, Count),
    catch(( forall(between(1, Count, N),
                   ( iteration(N) -> true
                   ; format(user_error, "iteration ~w failed without raising~n", [N]),
                     throw(stopped) )),
            format(user_error, "~w iterations, no failure~n", [Count]) ),
          stopped,
          true).
