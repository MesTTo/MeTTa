% Purpose: test native owned-record declarations at the outer commit boundary.
% Assumes: engine/spaces/owned_records.pl is loaded by the space umbrella.
% Owns resources: fixtures withdraw their exact declaration occurrences, release
%   native spaces, join every worker, and remove temporary observation hooks.
% Decides: overlapping transactions use queues to select both snapshots and
%   commit order; no timing delay determines an expected outcome
%   [source: tests/prolog/suites/spaces/owned_records.plt:overlap/4; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap), [wrap_predicate/4, unwrap_predicate/2]).

:- dynamic owned_record_foreign_space/1.
:- multifile seam:foreign_space/1.
seam:foreign_space(Space) :- user:owned_record_foreign_space(Space).

:- begin_tests(owned_records).

layout(entity, Home, Id, ['Entity', Id], Home, [field, ['Entity', Id]]).
layout(prototype, _, Id, ['Prototype', Id], Id, [field]).
layout(cell, Home, Id, ['Cell', Home, Id], Home, ['cell-value', ['Cell', Home, Id]]).
layout(proxy, Home, Id, ['Entity', Id], Home, ['_python-proxy', ['Entity', Id]]).

fixture(Kind, Initial, Declared, Record) :-
    fixture(Kind, atomic, Initial, Declared, Record).

fixture(Kind, Species, Initial, Declared, record(Home, Owner, Storage, Prefix, Schema)) :-
    native_space(Species, Home),
    ( Kind == prototype -> native_space(Species, Id) ; Id = 1 ),
    layout(Kind, Home, Id, Owner, Storage, Prefix),
    layout(Kind, Home, _, OwnerPattern, StoragePattern, PrefixPattern),
    Schema = ['@owned-record', Home, OwnerPattern, StoragePattern, PrefixPattern],
    metta_add_atom(Home, ['owned-by', Owner], true),
    ( Declared == yes -> metta_add_atom('&metta', Schema, true) ; true ),
    seed(Initial, record(Home, Owner, Storage, Prefix, Schema)).

native_space(atomic, Space) :- 'new-space'(Space).
native_space(parametric, Space) :-
    gensym(owned_record_space_, Id), Space = [owned_record_space, Id],
    metta_declare_parametric_space(Space).

seed(empty, _).
seed(value(Value), Record) :- add_value(Record, Value).

cleanup_record(record(Home, _, Storage, _, _)) :-
    findall(Ref,
            spaces:metta_native_pair('&metta', ['@owned-record', Home, _, _, _], _, Ref),
            Refs),
    maplist(spaces:metta_remove_atom_reference, Refs),
    ( Storage == Home -> true ; release_live(Storage) ), release_live(Home).

release_live(Space) :-
    ( spaces:native_storage_module_cache(Space, _) -> metta_release_space(Space) ; true ).

add_value(record(_, _, Storage, Prefix, _), Value) :-
    append(Prefix, [Value], Row), metta_add_atom(Storage, Row, true).

remove_value(record(_, _, Storage, Prefix, _)) :-
    append(Prefix, [_], Row), metta_remove_atom(Storage, Row, _).

write_value(Record, Value) :- remove_value(Record), add_value(Record, Value).

values(record(_, _, Storage, Prefix, _), Values) :-
    append(Prefix, [Value], Row),
    findall(Value, spaces:metta_native_pair(Storage, Row, _, _), Values).

retire(Record, Action) :-
    Record = record(Home, Owner, Storage, _, _),
    ( Action == drop -> metta_release_space(Storage) ; remove_value(Record) ),
    metta_remove_atom(Home, ['owned-by', Owner], true).

declaration_ref(record(_, _, _, _, Schema), Ref) :-
    once(spaces:metta_native_pair('&metta', Schema, _, Ref)).

withdraw(Record) :-
    declaration_ref(Record, Ref), spaces:metta_remove_atom_reference(Ref).

declare(record(_, _, _, _, Schema)) :- metta_add_atom('&metta', Schema, true).

outcome(Goal, Outcome) :-
    catch(( call(Goal) -> Outcome = committed ; Outcome = failed ),
          Error, Outcome = threw(Error)).

conflict(threw(error(metta_owned_record_conflict(_, Problem), _)), Problem).

assert_conflict(Outcome, Problem) :-
    assertion(conflict(Outcome, Problem)),
    Outcome = threw(Error), message_to_string(Error, Message),
    assertion(sub_string(Message, _, _, _, "retry the outer transaction")).

% Both workers open their snapshots before either body writes. The parent
% receives an early failure instead of waiting for a stage that cannot occur.
worker(Tag, Goal, Commands, Events) :-
    outcome(metta_transaction(
                ( thread_send_message(Events, event(Tag, opened)),
                  thread_get_message(Commands, begin), call(Goal),
                  thread_send_message(Events, event(Tag, written)),
                  thread_get_message(Commands, commit) )), Result),
    thread_send_message(Events, event(Tag, done(Result))).

stage(Events, Tag, Expected) :-
    thread_get_message(Events, event(Tag, Actual)),
    ( Actual == Expected -> true
    ; throw(error(owned_record_worker_stage(Tag, Expected, Actual), none)) ).

worker_cleanup(Finished, Thread) :-
    ( var(Thread) -> true
    ; Finished == true
    -> thread_join(Thread, Status), assertion(Status == true)
    ; catch(( thread_property(Thread, status(running))
            -> thread_signal(Thread, throw(owned_record_test_abandoned))
            ; true ), error(existence_error(thread, _), _), true),
      catch(thread_join(Thread, _), error(existence_error(thread, _), _), true) ).

with_queues([], Goal) :- call(Goal).
with_queues([Queue|Queues], Goal) :-
    setup_call_cleanup(message_queue_create(Queue), with_queues(Queues, Goal),
                       message_queue_destroy(Queue)).

overlap(FirstGoal, SecondGoal, FirstCommit, Results) :-
    with_queues([Events, First, Second],
        setup_call_cleanup(
            true,
            ( thread_create(worker(first, FirstGoal, First, Events), A, []),
              thread_create(worker(second, SecondGoal, Second, Events), B, []),
              stage(Events, first, opened), stage(Events, second, opened),
              thread_send_message(First, begin), stage(Events, first, written),
              thread_send_message(Second, begin), stage(Events, second, written),
              ( FirstCommit == first
              -> Ahead = first-First, Behind = second-Second
              ; Ahead = second-Second, Behind = first-First ),
              Ahead = AheadTag-AheadQueue, Behind = BehindTag-BehindQueue,
              thread_send_message(AheadQueue, commit),
              thread_get_message(Events, event(AheadTag, done(AheadResult))),
              thread_send_message(BehindQueue, commit),
              thread_get_message(Events, event(BehindTag, done(BehindResult))),
              keysort([AheadTag-AheadResult, BehindTag-BehindResult], Results),
              Finished = true ),
            ( worker_cleanup(Finished, A), worker_cleanup(Finished, B) ))).

test(one_writer_commits_per_key,
     [forall((member(Kind, [entity, prototype, cell, proxy]),
              member(Species, [atomic, parametric]),
              member(Initial, [empty, value(0)]), member(Second, [1, 2]))),
      setup(fixture(Kind, Species, Initial, yes, Record)), cleanup(cleanup_record(Record))]) :-
    overlap(write_value(Record, 1), write_value(Record, Second), first,
            [first-First, second-Loser]),
    assertion(First == committed), assert_conflict(Loser, multiple_values),
    values(Record, Values), assertion(Values == [1]).

test(disjoint_owners_and_fields_both_commit,
     [forall(member(Dimension, [owner, field])),
      setup(fixture(entity, empty, yes, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, _, Schema),
    ( Dimension == owner
    -> OtherOwner = ['Entity', 2], OtherPrefix = [field, OtherOwner]
    ; OtherOwner = ['Entity', 1], OtherPrefix = [other, OtherOwner],
      Schema = ['@owned-record', Home, Pattern, Home, _],
      metta_add_atom('&metta', ['@owned-record', Home, Pattern, Home, [other, Pattern]], true) ),
    Other = record(Home, OtherOwner, Home, OtherPrefix, Schema),
    ( Dimension == owner -> metta_add_atom(Home, ['owned-by', OtherOwner], true) ; true ),
    overlap(write_value(Record, 1), write_value(Other, 2), first, Results),
    assertion(Results == [first-committed, second-committed]),
    values(Record, [1]), values(Other, [2]).

test(repeated_writes_validate_one_derived_key,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    setup_call_cleanup(
        ( flag('$owned_record_key_checks', _, 0),
          wrap_predicate(spaces:metta_owned_validate_key(_, _), owned_record_count,
                         Wrapped, (flag('$owned_record_key_checks', N, N+1), call(Wrapped))) ),
        ( metta_transaction(forall(between(1, 512, Value), write_value(Record, Value))),
          flag('$owned_record_key_checks', Calls, Calls), assertion(Calls == 1),
          values(Record, Values), assertion(Values == [512]) ),
        unwrap_predicate(spaces:metta_owned_validate_key(_, _), owned_record_count)).

test(values_preserve_variables_and_error_data,
     [forall(member(Value, [_, ['Error', stored, data], false, 'None'])),
      setup(fixture(cell, empty, yes, Record)), cleanup(cleanup_record(Record))]) :-
    metta_transaction(write_value(Record, Value)), values(Record, [Stored]),
    assertion(Stored =@= Value).

test(a_variable_in_an_owned_key_refuses_before_commit,
     [setup(fixture(entity, empty, yes, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, _, _),
    outcome(metta_transaction(metta_add_atom(Home, [field, ['Entity', _], value], true)), Result),
    assertion(Result = threw(error(domain_error(ground_owned_record_key, _), _))),
    values(Record, Values), assertion(Values == []).

test(new_declaration_checks_original_keys_before_query_unification,
     [forall(member(RowKind, [value, owner])),
      setup(fixture(entity, empty, no, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, _, _),
    ( RowKind == value -> Row = [field, ['Entity', _], data]
    ; Row = ['owned-by', ['Entity', _]] ),
    metta_add_atom(Home, Row, true),
    outcome(metta_transaction(declare(Record)), Result),
    assertion(Result = threw(error(domain_error(ground_owned_record_key, _), _))),
    assertion(\+ declaration_ref(Record, _)).

test(declaration_syntax_and_variable_identity_are_checked_before_storage,
     [forall(member(Invalid, [ ['@owned-record', _, owner, '&native', [field]],
                               ['@owned-record', '&native', owner, '&native', []],
                               ['@owned-record', '&native', owner, '&native', [_]],
                               ['@owned-record', '&native', owner, '&native', [field|_]],
                               ['@owned-record', '&native', ['Owner', _], '&native', [field, _]],
                               ['@owned-record', '&native', owner] ]))]) :-
    outcome(metta_add_atom('&metta', Invalid, true), Result),
    assertion(Result = threw(error(domain_error(native_owned_record_declaration, _), _))).

test(foreign_storage_is_refused_at_admission,
     [setup(assertz(user:owned_record_foreign_space('&owned-record-foreign'), Ref)),
      cleanup(erase(Ref))]) :-
    Schema = ['@owned-record', '&native', owner, '&owned-record-foreign', [field]],
    outcome(metta_add_atom('&metta', Schema, true), Result),
    assertion(Result = threw(error(permission_error(declare, native_owned_record, _), _))).

test(withdrawing_the_kind_does_not_disable_intrinsic_declaration_validation) :-
    outcome(metta_transaction(
                ( metta_remove_atom('&metta', [kind, '@owned-record', term, term, term, term], _),
                  metta_add_atom('&metta', ['@owned-record', '&native', owner], true) )), Result),
    assertion(Result = threw(error(domain_error(native_owned_record_declaration, _), _))),
    assertion(metta_contract_fact([kind, '@owned-record', term, term, term, term])).

test(an_empty_record_allows_deletion_but_not_duplicate_owners,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    metta_transaction(remove_value(Record)), values(Record, Values), assertion(Values == []),
    Record = record(Home, Owner, _, _, _),
    outcome(metta_transaction(metta_add_atom(Home, ['owned-by', Owner], true)), Result),
    assert_conflict(Result, multiple_owners).

test(retirement_and_writes_conflict_in_both_commit_orders,
     [forall((member(Kind-Action, [entity-remove, cell-remove, prototype-remove, prototype-drop]),
              member(Species, [atomic, parametric]),
              member(Initial, [empty, value(0)]), member(Order, [first, second]))),
      setup(fixture(Kind, Species, Initial, yes, Record)), cleanup(cleanup_record(Record))]) :-
    overlap(write_value(Record, 1), retire(Record, Action), Order,
            [first-Writer, second-Retirer]),
    Record = record(Home, Owner, _, _, _),
    ( Order == first
    -> assertion(Writer == committed), assert_conflict(Retirer, retired_owner),
       values(Record, Values), assertion(Values == [1]),
       assertion(spaces:metta_native_pair(Home, ['owned-by', Owner], _, _))
    ; assertion(Retirer == committed), assert_conflict(Writer, retired_owner),
      values(Record, Values), assertion(Values == []),
      assertion(\+ spaces:metta_native_pair(Home, ['owned-by', Owner], _, _)) ).

test(nested_rollback_leaves_no_check_for_discarded_changes,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    metta_transaction(
        ( \+ metta_transaction((add_value(Record, discarded), fail)),
          write_value(Record, 1),
          findall(Error, metta_transaction(
                            (add_value(Record, discarded), Error = ['Error', child, failed]),
                            Error), Errors),
          assertion(Errors == [['Error', child, failed]]) )),
    values(Record, Values), assertion(Values == [1]).

test(outer_error_rolls_back_values_and_declaration_changes,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    declaration_ref(Record, Before),
    findall(Error,
            metta_transaction((write_value(Record, 1), withdraw(Record),
                               Error = ['Error', outer, failed]), Error), Errors),
    assertion(Errors == [['Error', outer, failed]]),
    declaration_ref(Record, After), assertion(After == Before),
    values(Record, Values), assertion(Values == [0]).

test(other_transaction_withdrawal_refuses_an_observed_writer,
     [setup(fixture(entity, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    overlap(write_value(Record, 1), withdraw(Record), second,
            [first-Writer, second-Withdrawal]),
    assertion(Withdrawal == committed), assert_conflict(Writer, withdrawn),
    values(Record, Values), assertion(Values == [0]).

test(equal_source_replacement_has_a_new_occurrence,
     [setup(fixture(entity, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    declaration_ref(Record, Before),
    overlap(write_value(Record, 1), (withdraw(Record), declare(Record)), second,
            [first-Writer, second-Replacement]),
    assertion(Replacement == committed), assert_conflict(Writer, withdrawn),
    declaration_ref(Record, After), assertion(After \== Before),
    values(Record, Values), assertion(Values == [0]).

test(a_surviving_observed_duplicate_keeps_the_contract,
     [setup(fixture(entity, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    declare(Record),
    overlap(write_value(Record, 1), withdraw(Record), second, Results),
    assertion(Results == [first-committed, second-committed]),
    values(Record, Values), assertion(Values == [1]).

test(a_literal_variable_functor_does_not_merge_distinct_source_contracts,
     [setup(fixture(entity, empty, yes, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, _, _),
    Owner = ['Entity', '$VAR'(0)], Prefix = [field, Owner],
    Fixed = ['@owned-record', Home, Owner, Home, Prefix],
    Actual = record(Home, Owner, Home, Prefix, Fixed),
    metta_add_atom(Home, ['owned-by', Owner], true), declare(Actual),
    overlap(write_value(Actual, 1), withdraw(Record), second,
            [first-Writer, second-Withdrawal]),
    assertion(Withdrawal == committed), assert_conflict(Writer, withdrawn),
    values(Actual, Values), assertion(Values == []).

test(own_withdrawal_keeps_the_invariant_through_its_commit,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    outcome(metta_transaction((withdraw(Record), add_value(Record, 1))), Rejected),
    assert_conflict(Rejected, multiple_values), assertion(declaration_ref(Record, _)),
    metta_transaction(withdraw(Record)),
    metta_transaction(add_value(Record, 1)), values(Record, Values), assertion(Values == [0,1]).

test(concurrent_withdrawal_does_not_hide_own_removed_contract,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    overlap((withdraw(Record), add_value(Record, 1)), withdraw(Record), second,
            [first-Writer, second-Withdrawal]),
    assertion(Withdrawal == committed), assert_conflict(Writer, multiple_values),
    values(Record, Values), assertion(Values == [0]),
    assertion(\+ declaration_ref(Record, _)).

test(source_rewrite_validates_the_newly_covered_population,
     [setup(fixture(entity, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, Owner, _, _, Schema),
    Other = record(Home, Owner, Home, [other, Owner], Schema),
    add_value(Other, 1), add_value(Other, 2),
    Schema = ['@owned-record', Home, OwnerPattern, Home, _],
    Replacement = ['@owned-record', Home, OwnerPattern, Home, [other, OwnerPattern]],
    outcome(metta_transaction((withdraw(Record), metta_add_atom('&metta', Replacement, true))), Result),
    assert_conflict(Result, multiple_values), assertion(declaration_ref(Record, _)),
    assertion(\+ spaces:metta_native_pair('&metta', Replacement, _, _)).

test(concurrent_declaration_addition_checks_both_visibility_orders,
     [forall(member(Order, [first, second])),
      setup(fixture(entity, empty, no, Record)), cleanup(cleanup_record(Record))]) :-
    overlap((add_value(Record, 1), add_value(Record, 2)), declare(Record), Order,
            [first-Writer, second-Declaration]),
    ( Order == first
    -> assertion(Writer == committed), assert_conflict(Declaration, multiple_values),
       assertion(\+ declaration_ref(Record, _)), values(Record, [1,2])
    ; assertion(Declaration == committed), assert_conflict(Writer, multiple_values),
      assertion(declaration_ref(Record, _)), values(Record, []) ).

test(concurrent_owner_and_declaration_addition_keep_native_storage_requirement,
     [setup(fixture(prototype, empty, no, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, Owner, _, _, _),
    metta_remove_atom(Home, ['owned-by', Owner], true),
    overlap(metta_add_atom(Home, ['owned-by', Owner], true), declare(Record), second, Results),
    assertion(Results == [first-committed, second-committed]).

test(an_unallocated_prototype_storage_refuses_with_a_named_key_error,
     [setup(fixture(prototype, empty, no, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(_, _, Storage, _, _), metta_release_space(Storage),
    outcome(metta_transaction(declare(Record)), Result),
    assertion(Result = threw(error(domain_error(native_owned_record_storage, Storage), _))),
    assertion(\+ declaration_ref(Record, _)).

test(ordinary_relations_keep_multivalued_snapshot_semantics,
     [forall(member(Second, [1,2])),
      setup(fixture(entity, value(0), no, Record)), cleanup(cleanup_record(Record))]) :-
    overlap(write_value(Record, 1), write_value(Record, Second), first, Results),
    assertion(Results == [first-committed, second-committed]),
    values(Record, Values), msort(Values, Sorted), msort([1,Second], Expected),
    assertion(Sorted == Expected).

test(ordinary_removal_drains_only_its_snapshot,
     [setup(fixture(entity, value(0), no, Record)), cleanup(cleanup_record(Record))]) :-
    overlap(add_value(Record, 1), remove_value(Record), first, Results),
    assertion(Results == [first-committed, second-committed]),
    values(Record, Values), assertion(Values == [1]).

test(a_variable_head_in_ordinary_catalog_data_is_not_a_declaration,
     [setup(fixture(entity, empty, no, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, _, _),
    setup_call_cleanup(
        spaces:add_sexp('&metta', [_, Home, one, two, three], _, Ref),
        metta_transaction(write_value(Record, 1)),
        spaces:metta_remove_atom_reference(Ref)),
    values(Record, Values), assertion(Values == [1]).

with_wrappers([], Goal) :- call(Goal).
with_wrappers([wrapper(Head, Name, Wrapped, Body)|Wrappers], Goal) :-
    setup_call_cleanup(wrap_predicate(Head, Name, Wrapped, Body),
                       with_wrappers(Wrappers, Goal), unwrap_predicate(Head, Name)).

check_lock(Expected) :-
    thread_self(Thread),
    ( catch(mutex_property('$metta_materialization', status(locked(Thread, _))),
            error(existence_error(mutex, _), _), fail)
    -> Actual = held ; Actual = free ),
    ( Expected == Actual -> true
    ; throw(error(owned_record_lock_phase(Expected, Actual), none)) ).

test(preparation_precedes_the_mutex_and_validation_never_calls_a_foreign_provider,
     [setup(fixture(cell, value(0), yes, Record)), cleanup(cleanup_record(Record))]) :-
    Wrappers = [
        wrapper(spaces:metta_prepare_owned_records(_), owned_record_prelock, Prepare,
                (check_lock(free), call(Prepare))),
        wrapper(spaces:metta_validate_owned_records(_), owned_record_commit, Validate,
                setup_call_cleanup((check_lock(held), nb_setval('$owned_record_validating', true)),
                                   call(Validate), nb_delete('$owned_record_validating'))),
        wrapper(seam:foreign_space(_), owned_record_no_host, Foreign,
                ( nb_current('$owned_record_validating', true)
                -> throw(error(owned_record_foreign_query_in_constraint, none))
                ; call(Foreign) )) ],
    with_wrappers(Wrappers,
                  ( metta_transaction(write_value(Record, 1)),
                    values(Record, Values), assertion(Values == [1]),
                    setup_call_cleanup(
                        nb_setval('$owned_record_validating', true),
                        outcome(seam:foreign_space('&owned-record-positive-control'), Guard),
                        nb_delete('$owned_record_validating')),
                    assertion(Guard == threw(error(owned_record_foreign_query_in_constraint, none))) )).

:- dynamic observed/1.

observers(Home, [Added, Removed, Segment]) :-
    assertz((seam:atom_added(Home, Row) :-
                 assertz(plunit_owned_records:observed(added(Row)))), Added),
    assertz((seam:atom_removed(Home, Row) :-
                 assertz(plunit_owned_records:observed(removed(Row)))), Removed),
    assertz((seam:segment_committed(Spaces) :-
                 ( memberchk(Home, Spaces)
                 -> assertz(plunit_owned_records:observed(segment)) ; true )), Segment).

test(a_refused_writer_publishes_no_native_observation_segment,
     [setup(fixture(cell, empty, yes, Record)), cleanup(cleanup_record(Record))]) :-
    Record = record(Home, _, _, Prefix, _),
    setup_call_cleanup(
        observers(Home, Refs),
        ( overlap(write_value(Record, 1), write_value(Record, 2), first,
                  [first-committed, second-Loser]),
          assert_conflict(Loser, multiple_values), append(Prefix, [1], Written),
          findall(Event, observed(Event), Events), assertion(Events == [added(Written), segment]) ),
        ( maplist(erase, Refs), retractall(observed(_)) )).

:- end_tests(owned_records).
