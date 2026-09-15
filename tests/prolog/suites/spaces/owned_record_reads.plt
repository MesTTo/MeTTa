% Purpose: verify original-occurrence reads of native owned records.
% Assumes: owned_records.plt supplies the native layouts and cleanup fixtures.
% Owns resources: every fixture releases its native spaces; the snapshot race
%   joins its worker and removes its temporary predicate wrapper.
% Guarantees: tests distinguish empty records, stored data, malformed original
%   keys and concurrent replacement without selecting a surviving row by chance
%   [source: tests/prolog/suites/spaces/owned_record_reads.plt; commit=WORKTREE].

:- ensure_loaded('owned_records.plt').

:- begin_tests(owned_record_reads).

fixture(Kind, Species, Initial, Record, Key) :-
    plunit_owned_records:fixture(Kind, Species, Initial, no, Record),
    Record = record(Home, Owner, Storage, Prefix, _),
    Key = ['@owned-record', Home, Owner, Storage, Prefix].

cleanup(Record) :- plunit_owned_records:cleanup_record(Record).

read_record(Key, Rows) :- spaces:'owned-record-read'(Key, Rows).

test(empty_and_singleton_records_keep_their_layout,
     [forall((member(Kind, [entity, prototype, cell, proxy]),
              member(Species, [atomic, parametric]))),
      setup(fixture(Kind, Species, empty, Record, Key)), cleanup(cleanup(Record))]) :-
    read_record(Key, Empty), assertion(Empty == []),
    plunit_owned_records:add_value(Record, 7),
    Record = record(_, _, _, Prefix, _), append(Prefix, [7], Row),
    read_record(Key, Rows), assertion(Rows == [Row]).

test(values_remain_data_under_the_public_atom_mask,
     [forall(member(Value, [['Error', source, reason], ['+', 1, 2], [shared, X, X], false, 'None'])),
      setup(fixture(cell, atomic, value(Value), Record, Key)), cleanup(cleanup(Record))]) :-
    Record = record(_, _, _, Prefix, _), append(Prefix, [Value], Row),
    metta_self_module(Module),
    findall(Rows, eval_metta_in_module(Module, ['owned-record-read', Key], Rows), Answers),
    assertion(Answers =@= [[Row]]).

test(original_variable_keys_are_not_hidden_by_matching,
     [forall(member(Part, [owner, value])),
      setup(fixture(entity, atomic, empty, Record, Key)), cleanup(cleanup(Record)),
      throws(error(domain_error(ground_owned_record_key, _), _))]) :-
    Record = record(Home, Owner, _, _, _),
    ( Part == owner
    -> metta_remove_atom(Home, ['owned-by', Owner], true),
       metta_add_atom(Home, ['owned-by', ['Entity', _]], true)
    ; metta_add_atom(Home, [field, ['Entity', _], 7], true) ),
    read_record(Key, _).

test(equal_duplicates_are_distinct_occurrences,
     [forall(member(Part, [owner, value])),
      setup(fixture(entity, atomic, value(7), Record, Key)), cleanup(cleanup(Record))]) :-
    Record = record(Home, Owner, _, _, _),
    ( Part == owner
    -> metta_add_atom(Home, ['owned-by', Owner], true), Problem = multiple_owners
    ; plunit_owned_records:add_value(Record, 7), Problem = multiple_values ),
    plunit_owned_records:outcome(plunit_owned_record_reads:read_record(Key, _), Outcome),
    assertion(plunit_owned_records:conflict(Outcome, Problem)).

test(retired_owners_are_refused_with_or_without_a_remaining_value,
     [forall(member(Initial, [empty, value(7)])),
      setup(fixture(entity, atomic, Initial, Record, Key)), cleanup(cleanup(Record))]) :-
    Record = record(Home, Owner, _, _, _),
    metta_remove_atom(Home, ['owned-by', Owner], true),
    plunit_owned_records:outcome(plunit_owned_record_reads:read_record(Key, _), Outcome),
    assertion(plunit_owned_records:conflict(Outcome, retired_owner)).

test(a_read_observes_its_callers_uncommitted_writes,
     [setup(fixture(cell, atomic, value(1), Record, Key)), cleanup(cleanup(Record))]) :-
    Record = record(_, _, _, Prefix, _), append(Prefix, [2], Row),
    plunit_owned_records:outcome(plunit_owned_record_reads:metta_transaction((
        plunit_owned_records:write_value(Record, 2), read_record(Key, Rows),
        assertion(Rows == [Row]), throw(owned_read_rollback))), Outcome),
    assertion(Outcome == threw(owned_read_rollback)),
    plunit_owned_records:values(Record, Values), assertion(Values == [1]).

test(unallocated_storage_is_refused,
     [setup(fixture(prototype, atomic, empty, Record, Key)), cleanup(cleanup(Record)),
      throws(error(domain_error(native_owned_record_storage, _), _))]) :-
    Record = record(_, _, Storage, _, _), metta_release_space(Storage), read_record(Key, _).

test(foreign_storage_is_refused_before_any_provider_read,
     [setup(fixture(entity, atomic, empty, Record, Key)), cleanup(cleanup(Record)),
      throws(error(permission_error(declare, native_owned_record, _), _))]) :-
    Record = record(Home, _, _, _, _),
    setup_call_cleanup(assertz(user:owned_record_foreign_space(Home), Ref),
                       read_record(Key, _), erase(Ref)).

test(a_ground_owner_expression_is_held_as_data,
     [setup(fixture(entity, atomic, empty, Record, _)), cleanup(cleanup(Record))]) :-
    Record = record(Home, _, _, _, _),
    Owner = ['+', 1, 2], Prefix = [field, Owner],
    metta_add_atom(Home, ['owned-by', Owner], true),
    metta_add_atom(Home, [field, Owner, 9], true),
    metta_self_module(Module),
    eval_metta_in_module(Module, ['owned-record-read', ['@owned-record', Home, Owner, Home, Prefix]], Rows),
    assertion(Rows == [[field, Owner, 9]]).

snapshot_writer(Record, Ready, Released) :-
    thread_get_message(Ready, read_checked),
    plunit_owned_records:outcome(
        metta_transaction(plunit_owned_records:write_value(Record, 2)), Outcome),
    thread_send_message(Released, written(Outcome)).

test(a_read_keeps_the_checked_occurrence_after_concurrent_replacement,
     [setup(fixture(cell, atomic, value(1), Record, Key)), cleanup(cleanup(Record))]) :-
    Record = record(_, _, _, Prefix, _), append(Prefix, [1], Before), append(Prefix, [2], After),
    plunit_owned_records:with_queues([Ready, Released],
        plunit_owned_record_reads:setup_call_cleanup(
            thread_create(snapshot_writer(Record, Ready, Released), Writer, []),
            ( setup_call_cleanup(
                wrap_predicate(spaces:metta_owned_checked_key(_, _, _, _), owned_read_snapshot, Wrapped,
                    ( call(Wrapped), thread_send_message(Ready, read_checked),
                      thread_get_message(Released, written(Outcome)),
                      assertion(Outcome == committed) )),
                read_record(Key, Rows),
                unwrap_predicate(spaces:metta_owned_checked_key(_, _, _, _), owned_read_snapshot)),
              assertion(Rows == [Before]), read_record(Key, Current), assertion(Current == [After]),
              Finished = true ),
            plunit_owned_records:worker_cleanup(Finished, Writer))).

test(source_and_compiled_effects_report_the_mutable_read,
     [setup(fixture(cell, atomic, empty, Record, Key)), cleanup(cleanup(Record))]) :-
    metta_self_module(Module),
    Term = ['owned-record-read', Key],
    with_metta_module(Module, (translator:translate_cached_expr(Term, Goals, _),
                              translator:goals_list_to_conj(Goals, Compiled))),
    metta_host_goal_effect_plan(Module, (metta_effect_source_term(Term), Compiled), Operations, Effect),
    assertion(Effect == readOnlyLookup), assertion(Operations == [['owned-record-read', readOnlyLookup]]),
    metta_engine_module(Engine),
    Engine:metta_effect_classify(Module, 'owned-record-read'(Key, _), []-[], Queue-Reads),
    assertion(Queue == []),
    Key = ['@owned-record', Home, Owner, Storage, Prefix], append(Prefix, [_], Row),
    assertion(Reads =@= [read('owned-record-read', Home, ['owned-by', Owner]),
                        read('owned-record-read', Storage, Row)]).

:- end_tests(owned_record_reads).
