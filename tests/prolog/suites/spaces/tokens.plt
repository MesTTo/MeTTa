% Purpose: pin occurrence identity, ordering, rollback and provider refusals.
% Guarantees: occurrence-output writes bind their own identity and reject
%   bound outputs or unsupported providers before storing a row
%   [tested: spaces_tokens; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: ordinary bags omit tokens; exact removal preserves later arrivals
%   [tested: sh engine/test.sh suites/spaces/tokens.plt; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
% Owns resources: each fixture releases its space and joins its minting threads.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(apply)).
:- use_module(library(lists)).

:- multifile seam:foreign_space/1, seam:foreign_capability/2,
             seam:foreign_token/3.
seam:foreign_space('&t0-token-provider').
seam:foreign_capability('&t0-token-provider', tokens).
seam:foreign_token('&t0-token-provider', [row, value], t(z, 7)).
seam:foreign_token('&t0-token-provider', [row, value], t(a, 7)).
seam:foreign_token('&t0-token-provider', [row, value], t(z, 6)).

:- begin_tests(spaces_tokens).

tokens(Space, Tokens) :-
    findall(Token, spaces:metta_native_pair(Space, _, Token, _), Tokens).

test(minting_order_and_reference_decode,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    add_sexp(Space, [row, value], First, Ref),
    add_sexp(Space, [row, value], Second, _),
    assertion(integer(First)), assertion(Second =:= First+1),
    stored_atom_of_ref(Ref, FoundSpace, FoundAtom, FoundToken),
    assertion(FoundSpace-FoundAtom-FoundToken == Space-[row,value]-First),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[row,value], [row,value]]),
    metta_actor(Actor),
    metta_host_blame(Space, [row, value], Blame),
    assertion(Blame == [[t,Actor,First], [t,Actor,Second]]).

test(all_storage_shapes_decode,
     [setup('new-space'(Named)),
      cleanup((metta_release_space(Named), metta_release_space([t0, tokens])))]) :-
    Parametric = [t0, tokens], metta_declare_parametric_space(Parametric),
    forall(( member(Space, [Named, Parametric]),
             member(Atom, [[row], [row,X,X], [_,a], scalar, 17, [], "text", _]) ),
           ( add_sexp(Space, Atom, Token, Ref),
             stored_atom_of_ref(Ref, Space, Read, Token),
             assertion(Read =@= Atom),
             clause_property(Ref, module(Module)), clause(Module:Head, true, Ref),
             native_atom_clause(Space, Atom, Token, Expected),
             assertion(Head =@= Expected) )).

test(public_and_bulk_writes_preserve_tokens_and_duplicate_bags,
     [setup(('new-space'(Named),
             metta_declare_parametric_space([t0, write_funnel]))),
      cleanup((metta_release_space(Named),
               metta_release_space([t0, write_funnel])))]) :-
    Atoms = [[row], [row,a,a], scalar, 17, [], "text"],
    append(Atoms, Atoms, Twice), msort(Twice, Expected),
    forall(member(Space, [Named, [t0, write_funnel]]),
           ( forall(member(Atom, Atoms), 'add-atom'(Space, Atom, true)),
             metta_add_atoms(Space, Atoms),
             tokens(Space, Tokens), sort(Tokens, Unique),
             assertion(same_length(Twice, Tokens)),
             assertion(same_length(Tokens, Unique)),
             findall(Read, 'get-atoms'(Space, Read), Bag), msort(Bag, Sorted),
             assertion(Sorted == Expected) )).

test(storage_constructor_matches_specification) :-
    forall(between(0, 1000, Width),
           ( length(Fields, Width), maplist(=(shared(X)), Fields),
             metta_storage_term(row, Fields, X, Native),
             spaces:metta_storage_term_prolog(row, Fields, X, Expected),
             assertion(Native == Expected),
             metta_storage_term(Name, Decoded, Token, Native),
             assertion(Name == row), assertion(Decoded == Fields),
             assertion(Token == X) )).

test(parametric_open_enumeration_includes_scalar_storage,
     [setup(metta_declare_parametric_space([t0, scalar_enumeration])),
      cleanup(metta_release_space([t0, scalar_enumeration]))]) :-
    Atoms = [[row], scalar, 17, [], "text"],
    metta_add_atoms([t0, scalar_enumeration], Atoms),
    findall(Atom, 'get-atoms'([t0, scalar_enumeration], Atom), Found),
    msort(Atoms, Expected), msort(Found, Actual),
    assertion(Actual == Expected).

test(storage_constructor_refuses_a_partial_list,
     [throws(error(instantiation_error, _))]) :-
    metta_storage_term(row, [a|_], 1, _).

test(storage_constructor_refuses_an_improper_list,
     [throws(error(type_error(list, _), _))]) :-
    metta_storage_term(row, [a|b], 1, _).

test(storage_constructor_refuses_a_cyclic_list,
     [throws(error(type_error(list, _), _))]) :-
    List = [a|List], metta_storage_term(row, List, 1, _).

test(storage_constructor_refuses_an_atomic_head,
     [throws(error(type_error(compound, _), _))]) :-
    metta_storage_term(_, _, _, row).

test(commit_preserves_identity,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    transaction(add_sexp(Space, [committed], Token, Ref)),
    stored_atom_of_ref(Ref, Space, [committed], After),
    assertion(After == Token).

test(snapshot_discards_identity_without_reusing_its_generation,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    snapshot((add_sexp(Space, [discarded], Token, Ref),
              stored_atom_of_ref(Ref, Space, [discarded], Token))),
    assertion(\+ stored_atom_of_ref(Ref, _, _, _)),
    add_sexp(Space, [later], Later, _), assertion(Later > Token),
    tokens(Space, [Later]).

test(nested_rollback_discards_inner_commit,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    add_sexp(Space, [kept], Kept, _),
    flag('$metta_generation', Before, Before),
    assertion(\+ transaction((add_sexp(Space, [outer], _, _),
                              transaction(add_sexp(Space, [inner], _, _)), fail))),
    tokens(Space, [Kept]),
    flag('$metta_generation', After, After), assertion(After >= Before+2).

test(subtraction_uses_token_order_rather_than_clause_order,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    forall(member(Token, [t(z,7), t(a,7), t(z,6)]),
           add_sexp(Space, [row, value], Token, _)),
    'subtract-atom'(Space, [row, value], true),
    tokens(Space, First), assertion(First == [t(z,7), t(a,7)]),
    'subtract-atom'(Space, [row, value], true),
    tokens(Space, Second), assertion(Second == [t(z,7)]).

test(removal_consumes_a_generation,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    add_sexp(Space, [row], Token, _),
    'subtract-atom'(Space, [row], true),
    add_sexp(Space, [next], Next, _), assertion(Next >= Token+2).

test(draining_removes_every_observed_pair,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    forall(between(1, 5, _), add_sexp(Space, [row, value])),
    'remove-atom'(Space, [row, value], true),
    tokens(Space, []),
    metta_host_blame(Space, [row, value], []).

test(draining_keeps_an_equal_pair_added_by_a_removal_callback,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    add_sexp(Space, [row, value]), add_sexp(Space, [row, value]),
    nb_setval('$t0_removed_once', false),
    setup_call_cleanup(
        asserta((spaces:metta_remove_atom(Space, [row,value], Removed) :- !,
                    spaces:metta_remove_atom_raw(Space, [row,value], Removed),
                    ( nb_current('$t0_removed_once', false)
                    -> nb_setval('$t0_removed_once', true), add_sexp(Space, [row,value])
                    ; true )), Hook),
        'remove-atom'(Space, [row,value], true),
        (erase(Hook), nb_delete('$t0_removed_once'))),
    tokens(Space, Remaining), assertion(length(Remaining, 1)).

test(equation_tokens_survive_recompilation_and_exact_subtraction,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    forall(between(1, 3, _), metta_add_atom(Space, [=,[t0_identity,X],X], true)),
    space_module(Space, Module),
    findall(Token, spaces:metta_native_pair(Space, [=,[t0_identity,_],_], Token, _),
            Stored),
    findall(T, filereader:'$metta_equation_token'(Module, t0_identity, _, T), Before),
    assertion(Before == Stored),
    filereader:recompile_function_impl_in(Module, t0_identity),
    findall(T, filereader:'$metta_equation_token'(Module, t0_identity, _, T), Rebuilt),
    assertion(Rebuilt == Stored),
    'subtract-atom'(Space, [=,[t0_identity,Y],Y], true),
    Stored = [_|Remaining],
    findall(T, filereader:'$metta_equation_token'(Module, t0_identity, _, T), After),
    assertion(After == Remaining),
    findall(R, Module:t0_identity(42, R), Answers), assertion(Answers == [42,42]).

test(foreign_token_order_is_generation_then_actor) :-
    metta_host_blame('&t0-token-provider', [row,value], Tokens),
    assertion(Tokens == [[t,z,6], [t,a,7], [t,z,7]]).

test(receipt_advances_the_lamport_clock) :-
    flag('$metta_generation', Before, Before), Remote is Before+100,
    metta_token_receive(t(remote,Remote), Stored), assertion(Stored == t(remote,Remote)),
    flag('$metta_generation', Next, Next), assertion(Next > Remote),
    metta_actor(Actor), metta_token_receive(t(Actor,Next), Local),
    assertion(Local == Next).

test(mork_refuses_tokens_with_a_native_overlay_remedy,
     [condition(metta_extension_loaded(mork))]) :-
    catch(metta_host_blame('&mork:t0-tokens', [row,_], _), Error, true),
    assertion(Error = error(metta_foreign_tokens_required('&mork:t0-tokens',blame),_)),
    message_to_string(Error, Message),
    assertion(sub_string(Message, _, _, _, "native overlay")),
    assertion(sub_string(Message, _, _, _, "stable provider identities")),
    metta_host_refusal(Error, capability, _, Class, _, Remedy),
    assertion(Class == 'SpaceCapabilityError'),
    assertion(Remedy = [remedy,_,quickfix,prose]).

test(concurrent_minting_is_unique,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    ensure_native_storage_module(Space, _),
    setup_call_cleanup(
        thread_create(forall(between(1,100000,_), add_sexp(Space, [mint])), Left, []),
        setup_call_cleanup(
            thread_create(forall(between(1,100000,_), add_sexp(Space, [mint])), Right, []),
            true, (thread_join(Right, RightStatus), assertion(RightStatus == true))),
        (thread_join(Left, LeftStatus), assertion(LeftStatus == true))),
    tokens(Space, Minted), length(Minted, Count), sort(Minted, Unique),
    assertion(Count == 200000), assertion(length(Unique, 200000)).

test(an_atom_can_contain_its_own_occurrence_token,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    Atom = ['owned-by', ['Account', Token]],
    findall(Token-R, 'add-atom'(Space, Atom, Token, R), Answers),
    Answers = [Portable-true], Portable = [t, Actor, Generation],
    metta_actor(Actor),
    findall(Stored-Row, spaces:metta_native_pair(Space, Row, Stored, _), Rows),
    assertion(Rows == [Generation-['owned-by', ['Account', Portable]]]).

test(the_language_binder_is_shared_with_the_stored_atom,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    findall(Out, evalc([chain,
                        ['add-atom', Space, [owned, Token], Token], _, Token],
                       Space, Out), [Portable]),
    metta_host_blame(Space, [owned, Portable], Tokens),
    assertion(Tokens == [Portable]).

test(a_bound_occurrence_output_refuses_before_mutation,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    catch('add-atom'(Space, [unwritten, row], already_bound, _), Error, true),
    assertion(Error = error(uninstantiation_error(already_bound), _)),
    tokens(Space, Tokens), assertion(Tokens == []).

test(a_foreign_occurrence_output_names_the_native_overlay_remedy) :-
    catch('add-atom'('&t0-token-provider', [unwritten, row], _, _), Error, true),
    assertion(Error == error(metta_native_occurrence_binder_required('&t0-token-provider'), none)),
    message_to_string(Error, Message),
    assertion(sub_string(Message, _, _, _, "native overlay")).

test(a_rolled_back_binder_never_reuses_its_generation,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    snapshot('add-atom'(Space, [owned, First], First, true)),
    tokens(Space, Gone), assertion(Gone == []),
    'add-atom'(Space, [owned, Second], Second, true),
    First = [t, Actor, Before], Second = [t, Actor, After],
    assertion(After > Before).

test(a_parametric_space_keeps_its_occurrence_output,
     [setup(metta_declare_parametric_space([class, binder])),
      cleanup(metta_release_space([class, binder]))]) :-
    'add-atom'([class, binder], [owned, Token], Token, true),
    metta_host_blame([class, binder], [owned, Token], Tokens),
    assertion(Tokens == [Token]).

:- end_tests(spaces_tokens).

:- begin_tests(spaces_token_images).

hash_header(Code, Size, Hash, Cost) :-
    length(Codes, Size), maplist(=(Code), Codes), string_codes(Hash, Codes),
    string_concat("\t", Hash, Prefix), string_concat(Prefix, "\n", Input),
    setup_call_cleanup(open_string(Input, In),
        ( statistics(inferences, Before),
          filereader:metta_host_fast_expect_hash(In, token_hash, Hash),
          statistics(inferences, After), Cost is After-Before ),
        close(In)).

test(hash_header_keeps_the_lowercase_hexadecimal_language) :-
    findall(Code,
            ( between(0, 255, Code),
              catch(hash_header(Code, 64, _, _),
                    error(metta_fast_integrity_header(_), _), fail) ), Accepted),
    string_codes("0123456789abcdef", Expected),
    assertion(Accepted == Expected),
    forall(member(Code-Size, [0'0-0, 0'a-63, 0'f-65, 1632-64, 65296-64]),
           assertion(\+ catch(hash_header(Code, Size, _, _),
                              error(metta_fast_integrity_header(_), _), fail))).

test(hash_header_cost_is_content_independent) :-
    forall(member(Code, [0'0, 0'9, 0'a, 0'f]), hash_header(Code, 64, _, _)),
    findall(Cost, (member(Code, [0'0, 0'9, 0'a, 0'f]),
                   hash_header(Code, 64, _, Cost)), Costs),
    sort(Costs, Distinct),
    assertion(Distinct = [_]).

:- meta_predicate with_image(3).
with_image(Goal) :-
    tmp_file(t0_image, File), atom_concat(File, '.copy', Copy),
    setup_call_cleanup(
        ('new-space'(Source), 'new-space'(Target)),
        ( add_sexp(Source, [row,1]),
          metta_host_save_fast(File, Source, saved(1)), copy_file(File, Copy),
          call(Goal, Target, File, Copy) ),
        ( metta_release_space(Source), metta_release_space(Target),
          (exists_file(File) -> delete_file(File) ; true),
          (exists_file(Copy) -> delete_file(Copy) ; true) )).

image_tokens(Space, Tokens) :- metta_host_blame(Space, [row,1], Tokens).

reservations_released :-
    assertion(\+ spaces:metta_receipt_pending(_,_,_,_)),
    assertion(\+ spaces:metta_receipt_marker(_,_)),
    assertion(\+ spaces:metta_receipt_erased(_,_)),
    assertion(\+ spaces:metta_receipt_reserved(_)),
    assertion(\+ nb_current('$metta_occurrence_transaction', _)).

test(batch_receipts_preserve_noncolliding_tokens,
     [forall(member(Count, [0,1,2,17]))]) :-
    tmp_file(t0_batch_image, File),
    setup_call_cleanup(
        ('new-space'(Source), 'new-space'(Target)),
        ( forall(between(1, Count, I),
                 add_sexp(Source, [batch,I], t(t0_batch_actor,I), _)),
          metta_host_save_fast(File, Source, saved(Count)),
          forall((between(1, Count, I), 0 is I mod 2),
                 add_sexp(Target, [batch,I], t(t0_batch_actor,I), _)),
          metta_host_load_fast(File, Target),
          forall(between(1, Count, I),
                 ( metta_host_blame(Target, [batch,I], Tokens),
                   ( 0 is I mod 2
                   -> metta_actor(Actor),
                      Tokens = [[t,t0_batch_actor,I],[t,Actor,Fresh]],
                      assertion(Fresh > Count)
                   ; assertion(Tokens == [[t,t0_batch_actor,I]]) ) )),
          reservations_released ),
        ( metta_release_space(Source), metta_release_space(Target),
          (exists_file(File) -> delete_file(File) ; true) )).

test(parent_clear_and_nested_load_preserve_the_empty_destinations_tokens) :-
    with_image(check_parent_clear).

check_parent_clear(Space, File, Copy) :-
    metta_host_load_fast(File, Space), image_tokens(Space, Original),
    transaction((clear_native_atoms(Space),
                 transaction(metta_host_load_fast(Copy, Space)),
                 image_tokens(Space, Inside), assertion(Inside == Original))),
    image_tokens(Space, After), assertion(After == Original), reservations_released.

test(snapshot_and_nested_rollback_release_tokens_for_a_later_load) :-
    with_image(check_image_rollback).

check_image_rollback(Space, File, Copy) :-
    snapshot((metta_host_load_fast(File, Space), image_tokens(Space, Expected))),
    image_tokens(Space, []), reservations_released,
    assertion(\+ transaction((transaction(metta_host_load_fast(File, Space)), fail))),
    image_tokens(Space, []), reservations_released,
    metta_host_load_fast(Copy, Space), image_tokens(Space, Actual),
    assertion(Actual == Expected), reservations_released.

% Every worker reports failure as a message, so a failed assertion or load
% cannot leave the coordinator waiting for a success message that never comes.
image_worker(Space, File, Queue, Outcome) :-
    thread_self(Self),
    catch(
        ( ( transaction((thread_send_message(Queue, ready(Self)),
                         thread_get_message(load), metta_host_load_fast(File, Space),
                         thread_send_message(Queue, loaded(Self)),
                         thread_get_message(finish), Outcome == commit))
          -> Result = commit ; Result = rollback ),
          thread_send_message(Queue, finished(Self, Result)) ),
        Error, (thread_send_message(Queue, failed(Self, Error)), throw(Error))).

expect_image_event(Queue, Expected) :-
    thread_get_message(Queue, Event),
    ( Event = Expected -> true
    ; throw(error(unexpected_image_event(Event, Expected), none)) ).

finish_image_worker(Thread, Catcher) :-
    ( memberchk(Catcher, [exit, !])
    -> thread_join(Thread, Status), assertion(Status == true)
    ; ( thread_property(Thread, status(running))
      -> thread_signal(Thread, throw(t0_fixture_cleanup)) ; true ),
      thread_join(Thread, _) ).

test(overlapping_transactions_preserve_bags_and_distinct_tokens,
     [forall(member(Timing-Outcome, [pending-commit, committed-commit,
                                    committed-rollback]))]) :-
    with_image(check_image_overlap(Timing, Outcome)).

check_image_overlap(Timing, Outcome, Space, File, Copy) :-
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_catcher_cleanup(
            thread_create(image_worker(Space, File, Queue, Outcome), First, []),
            ( expect_image_event(Queue, ready(First)),
              setup_call_catcher_cleanup(
                  thread_create(image_worker(Space, Copy, Queue, commit), Second, []),
                  run_image_overlap(Timing, Outcome, Queue, Space, First, Second),
                  SecondCatcher, finish_image_worker(Second, SecondCatcher)) ),
            FirstCatcher, finish_image_worker(First, FirstCatcher)),
        message_queue_destroy(Queue)),
    reservations_released.

run_image_overlap(Timing, Outcome, Queue, Space, First, Second) :-
    expect_image_event(Queue, ready(Second)),
    thread_send_message(First, load), expect_image_event(Queue, loaded(First)),
    ( Timing == committed
    -> thread_send_message(First, finish), expect_image_event(Queue, finished(First, Outcome))
    ; true ),
    thread_send_message(Second, load), expect_image_event(Queue, loaded(Second)),
    ( Timing == pending
    -> thread_send_message(First, finish), expect_image_event(Queue, finished(First, Outcome))
    ; true ),
    thread_send_message(Second, finish), expect_image_event(Queue, finished(Second, commit)),
    image_tokens(Space, Tokens), sort(Tokens, Distinct),
    ( Outcome == commit -> Count = 2 ; Count = 1 ),
    assertion(length(Tokens, Count)), assertion(length(Distinct, Count)).

test(inner_rollback_releases_its_claim_while_the_outer_transaction_stays_open) :-
    with_image(check_inner_claim_release).

check_inner_claim_release(Space, File, Copy) :-
    setup_call_cleanup('new-space'(Control),
        ( metta_host_load_fast(File, Control), image_tokens(Control, Expected),
          transaction((
              assertion(\+ transaction((metta_host_load_fast(File, Space), fail))),
              setup_call_cleanup(
                  thread_create(metta_host_load_fast(Copy, Space), Writer, []),
                  thread_join(Writer, Status), true),
              assertion(Status == true) )),
          image_tokens(Space, Actual), assertion(Actual == Expected) ),
        metta_release_space(Control)),
    reservations_released.

test(failed_restore_releases_tokens_before_the_outer_transaction_finishes) :-
    with_image(check_failed_restore).

check_failed_restore(Space, File, Copy) :-
    setup_call_cleanup('new-space'(Control),
        ( metta_host_load_fast(File, Control), image_tokens(Control, Expected),
          transaction((
              setup_call_cleanup(
                  ( assertz((seam:atom_added(Space, _) :- throw(t0_restore_fault)), Hook),
                    seam:enable_atom_hook(added) ),
                  catch(metta_host_load_fast(File, Space), Error, true),
                  (erase(Hook), seam:sync_atom_hook(added))),
              assertion(Error == t0_restore_fault), image_tokens(Space, []),
              setup_call_cleanup(
                  thread_create(metta_host_load_fast(Copy, Space), Writer, []),
                  thread_join(Writer, Status), true),
              assertion(Status == true) )),
          image_tokens(Space, Actual), assertion(Actual == Expected) ),
        metta_release_space(Control)),
    reservations_released.

:- end_tests(spaces_token_images).
