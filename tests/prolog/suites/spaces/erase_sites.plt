% Purpose: hold each engine erase site to the reason its spelling was chosen
%   for: a reference something else erased first must not fail the operation
%   that releases it, and a site that reads the erase as its answer must
%   answer for what it did.
% Assumes: a thread whose transaction opened before another thread committed
%   an erase still reads the rows naming that clause, and its own erase/1 of it
%   fails [tested 2026-09-25T19:33:07+10:00: host_transactions:a_row_naming_a_clause_another_thread_erased_is_released_only_by_try_erase].
% Guarantees: the executable and binding retirements, the fun_meta and typing
%   rule removals, an equation removal, a storage clear, the registration probe,
%   the arithmetic guard and the observers' teardown each finish when the
%   reference they release is already gone, and a clear journals only what it
%   erased [tested 2026-09-25T19:33:07+10:00: sh engine/test.sh suites/spaces/erase_sites.plt].
% Owns resources: each test releases its space, its fixture rows, its listener
%   and the reader thread and message queues from_an_older_view/3 makes.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- metta_ensure_source_observation.

:- begin_tests(erase_sites).
:- dynamic artifact/1.

% Run Site on a thread whose transaction opened BEFORE Eraser committed on this
% one: the view every site here has to survive, whose rows still name clauses
% the eraser has taken.
from_an_older_view(Site, Eraser, Outcome) :-
    message_queue_create(ToReader), message_queue_create(FromReader),
    thread_create(older_view(Site, ToReader, FromReader), Reader, []),
    thread_get_message(FromReader, opened),
    call(Eraser),
    thread_send_message(ToReader, committed),
    thread_get_message(FromReader, Outcome),
    thread_join(Reader, Status),
    message_queue_destroy(ToReader), message_queue_destroy(FromReader),
    assertion(Status == true).

older_view(Site, In, Out) :-
    catch(transaction(( thread_send_message(Out, opened),
                        thread_get_message(In, committed),
                        ( call(Site) -> Outcome = succeeded ; Outcome = failed ) )),
          Error, Outcome = raised(Error)),
    thread_send_message(Out, Outcome).

fixture(Refs) :-
    findall(Ref, ( member(Value, [first, second, third]),
                   assertz(artifact(Value), Ref) ), Refs).

test(a_stale_executable_list_retires_what_is_left,
     [cleanup(retractall(artifact(_)))]) :-
    fixture(Refs), Refs = [_, Taken, _],
    from_an_older_view(filereader:retire_translated_clauses(user, Refs),
                       erase(Taken), Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ artifact(_)).

test(a_stale_equation_binding_is_forgotten,
     [cleanup(( retractall(filereader:'$metta_equation_token'(_, _, erase_sites_key, _)),
                retractall(filereader:translated_equation_binding(_, _, erase_sites_key)) ))]) :-
    assertz(filereader:'$metta_equation_token'(erase_sites, f, erase_sites_key, token), Token),
    assertz(filereader:translated_equation_binding(erase_sites, f, erase_sites_key)),
    from_an_older_view(filereader:forget_translated_equation_binding(erase_sites_key),
                       erase(Token), Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ filereader:'$metta_equation_token'(_, _, erase_sites_key, _)),
    assertion(\+ filereader:translated_equation_binding(_, _, erase_sites_key)).

% A source rollback erases these rows outside '$metta_fun_metadata', and the
% remover below takes that mutex from inside its older transaction. Both the
% projected head, which drop_fun_meta_rows/5 releases through try_erase/1, and
% the types row, which drop_fun_meta_types/5 claims, are gone first.
test(a_stale_fun_meta_row_does_not_fail_the_removal,
     [cleanup(clear_fun_meta(_, 'erase-sites-meta'))]) :-
    translator:record_fun_meta('erase-sites-meta', [X], [left, X]),
    current_metta_module(Module),
    F = 'erase-sites-meta',
    once(clause(translator:fun_meta_clause(Module, F, _, [left, _]), true, Ref)),
    once(translator:fun_meta_projection(Module, F, Ref, HeadRef)),
    once(clause(translator:fun_meta_clause_types(Module, F, _, [left, _], _), true, TypesRef)),
    from_an_older_view(drop_fun_meta(Module, F, [P], [left, P]),
                       ( erase(HeadRef), erase(TypesRef) ), Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ translator:fun_meta_clause(Module, F, _, _)).

test(a_rule_removed_twice_is_removed_once,
     [setup(('new-space'(Space), space_module(Space, Module))),
      cleanup(metta_release_space(Space))]) :-
    with_metta_module(Module,
        'add-typing-rule!'('erase-sites-rule', metatype, _, 'EraseSitesType', 'Defer', _)),
    Remove = with_metta_module(Module, 'remove-typing-rule!'('erase-sites-rule', true)),
    from_an_older_view(Remove, Remove, Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ type_rules:typing_rule_entry(user, Module, 'erase-sites-rule', _, _, _, _)).

% The compiled clause goes the way retire_translated_clauses/2 takes it, so the
% older view still reads its provenance and names a clause that is gone; the
% removal takes the stored atom and answers for that.
test(an_equation_whose_clause_is_gone_is_still_removed,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    filereader:metta_host_run_source("(= (erase-sites-f) 1)\n!(erase-sites-f)",
                                      Space, [], _),
    space_module(Space, Module),
    once(( filereader:translated_from(Ref, [=, ['erase-sites-f'], _]),
           clause_property(Ref, module(Module)) )),
    from_an_older_view('remove-atom'(Space, [=, ['erase-sites-f'], 1], _),
                       filereader:retire_translated_clauses(Module, [Ref]), Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ metta_host_stored(Space, [=, ['erase-sites-f'], _])).

test(a_stale_clear_journals_only_what_it_erased,
     [cleanup(retractall(artifact(_)))]) :-
    fixture([First, Taken, Last]),
    msort([First, Last], Expected),
    from_an_older_view(( spaces:metta_retract_storage(plunit_erase_sites:artifact(_)),
                         findall(R, spaces:metta_receipt_erased(_, R), Journal0),
                         msort(Journal0, Journal),
                         Journal == Expected ),
                       erase(Taken), Outcome),
    assertion(Outcome == succeeded),
    assertion(\+ artifact(_)).

% A second thread's metta_host_drop_function/2 retracts every clause of the
% probed predicate, and a listener that erases the probe the moment it is
% asserted is that retraction landing between the probe's assert and its erase.
probe_taker(assertz, Clause) :- !, erase(Clause).
probe_taker(_, _).

test(a_probe_whose_clause_is_taken_still_proves_the_name_free,
     [setup(( metta_self_module(Base), dynamic(Base:'erase-sites-probe'/2),
              prolog_listen(Base:'erase-sites-probe'/2, plunit_erase_sites:probe_taker) )),
      cleanup(( prolog_unlisten(Base:'erase-sites-probe'/2, plunit_erase_sites:probe_taker),
                abolish(Base:'erase-sites-probe'/2) ))]) :-
    metta_engine:metta_host_probe_function('erase-sites-probe', 2),
    assertion(\+ clause(Base:'erase-sites-probe'(_, _), _)).

test(a_guard_already_taken_installs_nothing,
     [setup(assertz(artifact(taken), Ref)), cleanup(retractall(artifact(_)))]) :-
    erase(Ref),
    predicate_property(system:goal_expansion(_, _), number_of_clauses(Before)),
    metta_engine:guard_arithmetic_goal_expansion_clause(Ref),
    predicate_property(system:goal_expansion(_, _), number_of_clauses(After)),
    assertion(After == Before).

test(a_stale_observer_row_leaves_no_hook_behind,
     [cleanup(( retractall(source_observation:installed_hook(_)),
                retractall(artifact(_)) ))]) :-
    fixture([First, Second, Third]),
    forall(member(Ref, [First, Second, Third]),
           assertz(source_observation:installed_hook(Ref))),
    erase(First),
    source_observation:remove_exception_observers,
    assertion(\+ source_observation:installed_hook(_)),
    assertion(\+ artifact(_)).

:- end_tests(erase_sites).
