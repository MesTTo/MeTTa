/* Purpose: verify the shared source loader's diagnostics, nested scopes and
   restoration on every exit, independently of an engine boot.
   Guarantees: errors remain visible to enclosing loads and other threads do
   not contaminate a successful load [tested: source_loading; commit=WORKTREE].
   Owns resources: each test joins its worker and destroys its message queue;
   the suite checks that loading_loudly/1 leaves no diagnostic scope behind.
*/
:- use_module('../../../../engine/source_loading').

:- begin_tests(source_loading).

test(the_load_error_has_a_message_without_the_runtime_unit) :-
    message_to_string(error(metta_load_failed('missing.pl'), _), Message),
    assertion(sub_string(Message, _, _, _,
                         "the Prolog source did not load cleanly: missing.pl")).

test(success_and_plain_failure_keep_their_meaning) :-
    loading_loudly(X = ready),
    assertion(X == ready),
    assertion(\+ loading_loudly(fail)).

test(direct_exceptions_keep_their_identity, [throws(planted_load_error)]) :-
    loading_loudly(throw(planted_load_error)).

test(a_printed_error_is_reported_even_when_the_goal_fails,
     [throws(error(metta_load_failed(_), _))]) :-
    loading_loudly((print_message(error, error(existence_error(source_sink,
                                            'missing-source.pl'), _)), fail)).

test(failed_directives_and_initializers_are_load_failures,
     [forall(member(Message, [goal_failed(directive, fail),
                             initialization_failure(fail, 'entry.pl':1)])),
      throws(error(metta_load_failed(_), _))]) :-
    loading_loudly(print_message(warning, Message)).

test(ordinary_warnings_are_not_load_failures) :-
    loading_loudly(print_message(warning, singletons('warning.pl', ['Unused']))).

test(a_caught_inner_error_is_still_the_outer_loads_error) :-
    Error = error(existence_error(source_sink, 'inner.pl'), _),
    message_to_string(Error, Text),
    atom_string(Expected, Text),
    catch(loading_loudly(
              ( catch(loading_loudly(print_message(error, Error)),
                      error(metta_load_failed(Inner), _), true),
                assertion(Inner == Expected) )),
          error(metta_load_failed(Outer), _), true),
    assertion(Outer == Expected).

test(source_module_is_restored_on_success_failure_and_exception,
     [forall(member(Exit, [true, fail, throw(planted_load_error)]))]) :-
    '$current_source_module'(Before),
    ( catch(loading_loudly(('$set_source_module'(source_loading_probe), Exit)),
            planted_load_error, true) -> true ; true ),
    '$current_source_module'(After),
    assertion(After == Before).

test(other_threads_diagnostics_are_not_collected) :-
    setup_call_cleanup(
        message_queue_create(Queue),
        setup_call_cleanup(
            thread_create((thread_get_message(Queue, start),
                           print_message(error, error(existence_error(
                               source_sink, 'other-thread.pl'), _)),
                           thread_send_message(Queue, done)), Worker, []),
            loading_loudly((thread_send_message(Queue, start),
                            thread_get_message(Queue, done))),
            (thread_send_message(Queue, start), thread_join(Worker, Status),
             assertion(Status == true))),
        message_queue_destroy(Queue)).

test(all_load_scopes_are_released) :-
    assertion(\+ metta_source_loading:watching),
    assertion(\+ metta_source_loading:diagnostic(_, _)).

:- end_tests(source_loading).
