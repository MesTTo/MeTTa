% Purpose: preserve MeTTa answer bags while rolling back Error-valued work.
% Guarantees: failure, exception and Error results all roll back writes;
%   successful bags retain order, duplicates and external variable bindings
%   [tested: classes_transaction_results; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: each test releases its private native space.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(classes_transaction_results).

test(error_answers_keep_the_whole_bag_but_discard_every_write,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    Expected = [1, ['Error', failed, reason], 1, 2],
    findall(Out,
            metta_transaction(
                ( member(Out, Expected), 'add-atom'(Space, [attempt, Out], true) ),
                Out), Answers),
    assertion(Answers == Expected),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == []).

test(successful_answers_commit_duplicates_and_preserve_bindings,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    findall(Key-Out,
            metta_transaction(
                ( member(Key-Out, [a-1, a-1, b-2]),
                  'add-atom'(Space, [entry, Key, Out], true) ), Out), Answers),
    assertion(Answers == [a-1, a-1, b-2]),
    findall(Row, 'get-atoms'(Space, Row), Rows),
    assertion(Rows == [[entry,a,1], [entry,a,1], [entry,b,2]]).

test(error_data_stored_under_a_successful_result_is_ordinary_data,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    Error = ['Error', record, payload],
    findall(R, metta_transaction('add-atom'(Space, [held, Error], R), R), Answers),
    assertion(Answers == [true]),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == [[held,Error]]).

test(an_empty_result_rolls_back,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    findall(R, metta_transaction(('add-atom'(Space, [held, gone], true), fail), R), Answers),
    assertion(Answers == []),
    assertion(\+ 'get-atoms'(Space, _)).

test(a_host_exception_is_rethrown_after_rollback,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    catch(metta_transaction(('add-atom'(Space, [held, gone], true),
                             throw(class_constructor_exception)), _), Error, true),
    assertion(Error == class_constructor_exception),
    assertion(\+ 'get-atoms'(Space, _)).

test(a_nested_error_can_be_handled_by_a_successful_outer_transaction,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    metta_transaction(
        ( 'add-atom'(Space, [outer, before], true),
          findall(Error, metta_transaction(
                            ('add-atom'(Space, [inner, gone], true),
                             Error = ['Error', inner, failed]), Error), Errors),
          assertion(Errors == [['Error',inner,failed]]),
          'add-atom'(Space, [outer, after], true) )),
    findall(Row, 'get-atoms'(Space, Row), Rows),
    assertion(Rows == [[outer,before], [outer,after]]).

test(an_outer_error_discards_a_successful_inner_commit,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    findall(Error,
            metta_transaction(
                ( metta_transaction('add-atom'(Space, [inner, gone], R), R),
                  Error = ['Error', outer, failed] ), Error), Answers),
    assertion(Answers == [['Error',outer,failed]]),
    assertion(\+ 'get-atoms'(Space, _)).

test(a_language_raise_discards_its_private_space,
     [setup('new-space'(Home)), cleanup(metta_release_space(Home))]) :-
    findall(Space, spaces:native_storage_module_cache(Space, _), Before),
    Expr = [transaction,
            [chain, ['new-space'], Private,
             [chain, ['add-atom', Private, [held, data]], _,
              [throw, ['Error', constructor, refused]]]]],
    findall(R, evalc(Expr, Home, R), Answers),
    assertion(Answers == [['Error',constructor,refused]]),
    findall(Space, spaces:native_storage_module_cache(Space, _), After),
    assertion(After == Before).

test(the_goal_only_transaction_keeps_its_prolog_success_contract,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    metta_transaction(('add-atom'(Space, [held, yes], true),
                       Value = ['Error', ordinary, data])),
    assertion(Value == ['Error',ordinary,data]),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == [[held,yes]]).

test(typed_results_preserve_errors_and_filter_other_mismatches,
     [setup('new-space'(Home)), cleanup(metta_release_space(Home))]) :-
    process_metta_string(
        "(: typed-results (-> Number Number))
         (= (typed-results $x) (superpose (3 (Error rejected $x) \"wrong\"
                                          (Error rejected $x) 5)))", _, Home),
    findall(R, evalc(['typed-results', 7], Home, R), Answers),
    assertion(Answers == [3, ['Error',rejected,7], ['Error',rejected,7], 5]).

test(a_typed_error_rolls_back_the_callers_transaction,
     [setup('new-space'(Home)), cleanup(metta_release_space(Home))]) :-
    process_metta_string(
        "(: typed-error (-> Number Number))
         (= (typed-error $x) (throw (Error rejected $x)))", _, Home),
    Expr = [transaction, [chain, ['add-atom', Home, [attempt, 7]], _,
                           ['typed-error', 7]]],
    findall(R, evalc(Expr, Home, R), Answers),
    assertion(Answers == [['Error',rejected,7]]),
    assertion(\+ match(Home, [attempt, _], true, true)).

test(a_rolled_back_class_home_can_be_declared_again,
     [setup(('new-space'(Caller), gensym('&class-rollback-', Home))),
      cleanup((metta_release_space(Caller), metta_release_space(Home)))]) :-
    \+ metta_transaction(
        ( metta_declare_space_equation_home(Home, '&self'),
          metta_add_atom(Home, ['=', ['class-rollback-value', X], X], _),
          metta_add_atom(Caller, [from, Home], _), fail )),
    assertion(\+ spaces:native_storage_module_cache(Home, _)),
    metta_declare_space_equation_home(Home, '&self'),
    metta_add_atom(Home, ['=', ['class-rollback-value', X], X], _),
    findall(R, evalc(['class-rollback-value', 7], Home, R), Answers),
    assertion(Answers == [7]).

:- end_tests(classes_transaction_results).
