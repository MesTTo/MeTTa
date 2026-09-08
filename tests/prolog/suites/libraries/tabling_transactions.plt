% Purpose: hold shared table isolation at the tabled predicate entry.
% Guarantees: direct compiled callers refuse unsafe transactions and private
%   tables preserve commit, rollback and snapshot visibility
%   [tested: lib_tabling_transactions; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
% Owns resources: each test releases its space; thread_join/2 reclaims each
%   reader before the fixture is released.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_tabling/lib_tabling.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(lib_tabling_transactions).

fixture(Space, Module) :-
    gensym('&t0-tab-', Space),
    format(string(Source),
           '(= (t0-table-read $k) (match ~w (row $k $v) $v))\n\c
            (= (t0-table-caller $k) (t0-table-read $k))', [Space]),
    process_metta_string(Source, _, Space),
    'add-atom'(Space, [row, key, base], true),
    space_module(Space, Module),
    % Compile the caller before the table declaration exists.
    process_metta_string('!(t0-table-caller key)', _, Space),
    with_metta_module(Module,
                      metta_tabled_decl(['t0-table-read', _], true)).

rows(Module, Rows) :-
    findall(X, Module:'t0-table-caller'(key, X), Found),
    sort(Found, Rows).

private(Module) :-
    lib_tabling:metta_tabling_declare_checked(
        Module, 't0-table-read', 2, [incremental, private], call).

test(a_compiled_caller_refuses_a_shared_table_in_a_transaction,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space))]) :-
    rows(Module, [base]),
    catch(transaction(('add-atom'(Space, [row, key, uncommitted], true),
                       rows(Module, _))), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_tabling_policy_refused(
                                't0-table-read', shared_transaction), _)),
    message_to_string(Error, Text),
    sub_string(Text, _, _, _, '(incremental private)'),
    rows(Module, [base]),
    \+ 'get-atoms'(Space, [row, key, uncommitted]),
    !.

test(a_shared_table_refuses_a_snapshot,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space)),
      throws(error(metta_tabling_policy_refused(
                       't0-table-read', shared_transaction), _))]) :-
    snapshot(rows(Module, _)).

test(the_metta_transaction_and_speculation_doors_refuse,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space))]) :-
    forall(member(Door, [metta_transaction, metta_speculate]),
           ( Goal =.. [Door, rows(Module, _)],
             catch(call(Goal), Error, true),
             assertion(nonvar(Error)),
             assertion(Error = error(metta_tabling_policy_refused(
                                         't0-table-read', shared_transaction), _)) )).

test(a_private_table_commits_and_discards_nested_writes,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space))]) :-
    private(Module),
    rows(Module, [base]),
    transaction(('add-atom'(Space, [row, key, committed], true),
                 rows(Module, [base, committed]))),
    catch(transaction((transaction(
                           'add-atom'(Space, [row, key, abandoned], true)),
                       rows(Module, [abandoned, base, committed]),
                       throw(abandon))), abandon, true),
    rows(Module, [base, committed]),
    snapshot(('add-atom'(Space, [row, key, speculative], true),
              rows(Module, [base, committed, speculative]))),
    rows(Module, [base, committed]).

test(a_private_table_hides_uncommitted_answers_from_another_thread,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space))]) :-
    private(Module),
    rows(Module, [base]),
    catch(transaction((
              'add-atom'(Space, [row, key, hidden], true),
              rows(Module, [base, hidden]),
              thread_create((rows(Module, Other),
                             ( Other == [base] -> true
                             ; throw(visible_uncommitted(Other)) )), Id, []),
              thread_join(Id, Status),
              assertion(Status == true),
              throw(abandon))), abandon, true),
    rows(Module, [base]).

test(untabling_releases_the_transaction_guard,
     [setup(fixture(Space, Module)), cleanup(metta_release_space(Space))]) :-
    with_metta_module(Module,
                      metta_untabled_decl(['t0-table-read', _], true)),
    \+ current_predicate_wrapper(Module:'t0-table-read'(_, _),
                                  metta_tabling_transaction, _, _),
    transaction(rows(Module, [base])).

:- end_tests(lib_tabling_transactions).
