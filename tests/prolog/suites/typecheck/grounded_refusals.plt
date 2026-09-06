% Purpose: distinguish one grounded value's class witnesses from separate refusals.
% Guarantees: a grounded argument reports its concrete class once while all
%   inherited witnesses remain available to type checking
%   [tested: run_tests(grounded_refusals); commit=074dc0a88b1605c54824de677d586b6f60998bcf].
% Owns resources: each test releases its Python reference and local space.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(grounded_refusals).

test(a_grounded_class_chain_produces_one_refusal,
     [ setup(py_call(datetime:datetime(2020, 1, 1), Object)),
       cleanup(py_free(Object)) ]) :-
    findall(Type, 'get-type'(Object, Type), Types),
    assertion(Types == [datetime, date]),
    findall(Answer, eval(['*', Object, Object], Answer), Answers),
    assertion(Answers == [['Error', ['*', Object, Object],
                           ['BadArgType', 1, 'Number', datetime]]]).

test(an_accepted_base_class_does_not_blame_the_concrete_class,
     [ setup(( 'new-space'(Space),
               py_call(datetime:datetime(2020, 1, 1), Object),
               add_sexp(Space, [':', 'date-and-number',
                                ['->', date, 'Number', 'Number']]) )),
       cleanup((py_free(Object), metta_release_space(Space))) ]) :-
    space_module(Space, Module),
    with_metta_module(Module,
        findall(Answer,
                metta_operation_answer('date-and-number', [Object, "bad"], Answer),
                Answers)),
    assertion(Answers == [['Error', ['date-and-number', Object, "bad"],
                           ['BadArgType', 2, 'Number', 'String']]]).

:- end_tests(grounded_refusals).
