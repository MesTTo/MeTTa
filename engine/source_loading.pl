/* Purpose: turn printed Prolog load failures into exceptions at every engine
   loading boundary, including before the engine itself has loaded.
   Assumes: SWI's message hook and source-module accessors are available even
   with autoload disabled [tested: sh check.sh no-autoload;
   commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
   Guarantees: nested loads collect their own diagnostics without losing the
   outer load's errors; ordinary warnings and plain goal failure retain their
   meaning; the source module is restored before QLF replay resumes and load
   errors have a readable message before the engine runtime unit is loaded
   [tested: tests/prolog/suites/seams/source_loading.plt,
   tests/shell/test_packaged_cli.sh; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
   Owns resources: each loading_loudly/1 call erases its diagnostic records and
   watching clause on success, failure or exception.
   Guarded by: watching/0 and diagnostic/2 are thread-local; clause references
   distinguish nested calls on the same thread.
*/
:- module(metta_source_loading, [loading_loudly/1]).

:- thread_local watching/0, diagnostic/2.
:- multifile user:thread_message_hook/3.
:- multifile prolog:error_message//1.

% Extension entries load before engine/metta/runtime.pl. Keep this error's
% renderer beside its thrower so an early refusal already has its message.
prolog:error_message(metta_load_failed(Summary)) -->
    [ 'the Prolog source did not load cleanly: ~w'-[Summary] ].

% A printed error may be swallowed by the consult machinery. Failed directive
% and initialization warnings likewise mean the requested load did not finish.
% Backtracking records each active scope once, then fails so SWI still prints
% the diagnostic and runs other hooks. No load scope means no diagnostic work.
user:thread_message_hook(Term, Kind, _) :-
    clause(watching, true, Ref),
    load_failure(Term, Kind),
    message_to_string(Term, Text),
    assertz(diagnostic(Ref, Text)),
    fail.

load_failure(_, error).
load_failure(goal_failed(directive, _), warning).
load_failure(initialization_failure(_, _), warning).

% Workaround: swi-qlf-failed-include-source-module - restore the source module
% before a failed nested consult returns to the enclosing QLF loader.
% SWI's $consult_file restores it only on success. With qcompile(auto), a
% failed include can leave user as the source module; loadPredicate then
% dereferences a null lookupProcedureToDefine result for a strong import.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-qlf.c#L1423;
% commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d]
:- meta_predicate loading_loudly(0).
loading_loudly(Goal) :-
    '$current_source_module'(Module),
    setup_call_cleanup(
        assertz(watching, Ref),
        ( setup_call_cleanup(
              true,
              ( call(Goal) -> Succeeded = true ; Succeeded = false ),
              '$set_source_module'(Module)),
          findall(Text, diagnostic(Ref, Text), Diagnostics),
          (   Diagnostics == []
          ->  Succeeded == true
          ;   atomic_list_concat(Diagnostics, '; ', Summary),
              throw(error(metta_load_failed(Summary),
                          context(loading_loudly/1, Goal)))
          ) ),
        ( erase(Ref), retractall(diagnostic(Ref, _)) )).
