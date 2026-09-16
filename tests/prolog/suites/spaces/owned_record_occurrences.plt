% Purpose: verify retained identities from the shared owned-record reader.
% Assumes: owned_record_reads.plt supplies the layouts and snapshot fixtures.
% Owns resources: fixtures release their spaces; the concurrent test joins
%   its worker and removes its temporary wrapper.
% [source: engine/spaces/owned_records.pl:metta_owned_record_occurrences/3; commit=05fae56ad5b23baa140cb4e6454cb7b304c06f4f]

:- ensure_loaded('owned_record_reads.plt').

:- begin_tests(owned_record_occurrences).

test(retains_the_original_owner_and_value_occurrences,
     [forall((member(Kind, [entity, prototype, cell, proxy]),
              member(Species, [atomic, parametric]))),
      setup(plunit_owned_record_reads:fixture(Kind, Species, value(7), Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record))]) :-
    Record = record(Home, Owner, Storage, Prefix, _), append(Prefix, [7], Row),
    spaces:metta_native_pair(Home, ['owned-by', Owner], _, OwnerRef),
    spaces:metta_native_pair(Storage, Row, _, ValueRef),
    spaces:metta_owned_record_occurrences(Key, Owners, Rows),
    assertion(Owners == [OwnerRef]), assertion(Rows == [ValueRef-Row]),
    plunit_owned_records:write_value(Record, 7),
    spaces:metta_owned_record_occurrences(Key, OwnersAgain, [Replacement-Equal]),
    assertion(OwnersAgain == Owners), assertion(Replacement \== ValueRef), assertion(Equal == Row).

test(absence_is_available_to_an_allocation_producer,
     [setup(plunit_owned_record_reads:fixture(cell, atomic, empty, Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record))]) :-
    Record = record(Home, Owner, _, _, _),
    spaces:metta_owned_record_occurrences(Key, [_], []),
    metta_remove_atom(Home, ['owned-by', Owner], true),
    spaces:metta_owned_record_occurrences(Key, Owners, Rows),
    assertion(Owners == []), assertion(Rows == []),
    plunit_owned_records:outcome(spaces:'owned-record-read'(Key, _), Outcome),
    assertion(plunit_owned_records:conflict(Outcome, retired_owner)).

test(values_are_complete_data_rows,
     [forall(member(Value, [['Error', source, reason], ['+', 1, 2], [shared, X, X], false, 'None'])),
      setup(plunit_owned_record_reads:fixture(cell, atomic, value(Value), Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record))]) :-
    Record = record(_, _, _, Prefix, _), append(Prefix, [Value], Expected),
    spaces:metta_owned_record_occurrences(Key, [_], [_-Row]),
    assertion(Row =@= Expected).

test(original_nonground_keys_are_refused,
     [forall(member(Part, [owner, value])),
      setup(plunit_owned_record_reads:fixture(entity, atomic, empty, Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record)),
      throws(error(domain_error(ground_owned_record_key, _), _))]) :-
    Record = record(Home, Owner, _, _, _),
    ( Part == owner
    -> metta_remove_atom(Home, ['owned-by', Owner], true),
       metta_add_atom(Home, ['owned-by', ['Entity', _]], true)
    ; metta_add_atom(Home, [field, ['Entity', _], 7], true) ),
    spaces:metta_owned_record_occurrences(Key, _, _).

test(duplicate_or_retired_occurrences_use_the_shared_refusal,
     [forall(member(Problem, [multiple_owners, multiple_values, retired_owner])),
      setup(plunit_owned_record_reads:fixture(entity, atomic, value(7), Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record))]) :-
    Record = record(Home, Owner, _, _, _),
    ( Problem == multiple_owners -> metta_add_atom(Home, ['owned-by', Owner], true)
    ; Problem == multiple_values -> plunit_owned_records:add_value(Record, 7)
    ; metta_remove_atom(Home, ['owned-by', Owner], true) ),
    plunit_owned_records:outcome(spaces:metta_owned_record_occurrences(Key, _, _), Outcome),
    assertion(plunit_owned_records:conflict(Outcome, Problem)).

test(retains_checked_references_across_concurrent_replacement,
     [setup(plunit_owned_record_reads:fixture(cell, atomic, value(1), Record, Key)),
      cleanup(plunit_owned_record_reads:cleanup(Record))]) :-
    Record = record(_, _, Storage, Prefix, _), append(Prefix, [1], Before),
    spaces:metta_native_pair(Storage, Before, _, Original),
    plunit_owned_records:with_queues([Ready, Released],
        plunit_owned_record_occurrences:setup_call_cleanup(
            thread_create(plunit_owned_record_reads:snapshot_writer(Record, Ready, Released), Writer, []),
            ( setup_call_cleanup(
                wrap_predicate(spaces:metta_owned_key_problem(_, _, _, _, _), owned_occurrence_snapshot, Wrapped,
                    ( call(Wrapped), thread_send_message(Ready, read_checked),
                      thread_get_message(Released, written(Outcome)), assertion(Outcome == committed) )),
                spaces:metta_owned_record_occurrences(Key, [_], Rows),
                unwrap_predicate(spaces:metta_owned_key_problem(_, _, _, _, _), owned_occurrence_snapshot)),
              assertion(Rows == [Original-Before]),
              spaces:metta_owned_record_occurrences(Key, [_], [Current-_]),
              assertion(Current \== Original), Finished = true ),
            plunit_owned_records:worker_cleanup(Finished, Writer))).

:- end_tests(owned_record_occurrences).
