% Purpose: verify Vector arithmetic, dimension refusals and generator ownership.
% Guarantees: tests cover exact/mixed values, extreme ranges, IEEE signs,
% complete input validation and state restoration after error or cancellation.
% [tested: lib_vector_surface; commit=WORKTREE].
% Owns resources: each borrowed generator state and rational policy is restored
% by its cleanup, including an exception in the tested operation.
% [tested: lib_vector_surface; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_vector/lib_vector').
:- use_module(library(random), [getrand/1, setrand/1, random/1]).

:- begin_tests(lib_vector_surface).
:- meta_predicate with_seed(+, 0).

with_seed(Seed, Goal) :-
    setup_call_cleanup(getrand(State), (set_random(seed(Seed)), Goal), setrand(State)).

test(empty_vectors) :-
    dot([], [], 0.0), norm([], 0.0), 'vector-distance'([], [], 0.0),
    'vector-normalize'([], []), 'vector-fill'(0, 7, []),
    'vector-add'([], [], []), 'vector-subtract'([], [], []),
    'vector-multiply'([], [], []), 'vector-divide'([], [], []),
    'vector-scale'([], 3, []).

test(exact_scalar_types) :-
    Q is 1 rdiv 3, R is 2 rdiv 3,
    'vector-add'([Q,2], [R,4], [1,6]),
    'vector-subtract'([R,4], [Q,2], [Q,2]),
    'vector-multiply'([Q,2], [3,4], [1,8]),
    'vector-divide'([1,4], [3,2], [Q,2]),
    'vector-scale'([Q,2], 3, [1,6]), 'vector-fill'(3, Q, [Q,Q,Q]).

test(mixed_scalar_results_round_once) :-
    Large is (1<<53)+1,
    'vector-add'([Large], [-9007199254740992.0], [1.0]),
    'vector-subtract'([Large], [9007199254740992.0], [1.0]),
    'vector-multiply'([3], [0.5], [1.5]),
    'vector-divide'([1], [2.0], [0.5]).

test(dot_cancellation) :-
    dot([18014398509481984.0,1.0,-18014398509481984.0], [1,1,1], 1.0),
    A is 1+2.0** -27, B is 1-2.0** -27, Expected is -(2.0** -54),
    dot([A,1.0], [B,-1.0], Expected).

test(dot_avoids_intermediate_overflow_and_underflow) :-
    Large is 2.0**1000, Negative is -Large,
    dot([Large,Large], [Large,Negative], 0.0),
    Small is 2.0** -1074, dot([Small,Small], [0.5,0.5], Small).

test(subnormal_rounding_regression) :-
    AboveHalf is ((1<<54)+1) rdiv (1<<1129), Smallest is 2.0** -1074,
    dot([AboveHalf], [1], Smallest),
    BelowHalf is ((1<<54)-1) rdiv (1<<1129), dot([BelowHalf], [1], 0.0),
    Half is 1 rdiv (1<<1075), dot([Half], [1], 0.0).

test(norm_and_distance_keep_representable_range) :-
    norm([1.0e308], 1.0e308), norm([1.0e-300], 1.0e-300),
    'vector-distance'([1.0e308], [0], 1.0e308),
    'vector-distance'([1.0e-300], [0], 1.0e-300),
    Large is (1<<53)+1,
    'vector-distance'([Large], [9007199254740992.0], 1.0).

test(direction_survives_unrepresentable_norm) :-
    Huge is 1<<3000, Tiny is 1 rdiv Huge,
    norm([Huge], 1.0Inf), norm([Tiny], 0.0),
    'vector-normalize'([Huge], [1.0]), 'vector-normalize'([Tiny], [1.0]),
    cosine([Huge], [Tiny], 1.0),
    'vector-normalize'([1.0e308,1.0e308], [X,X]),
    assertion(abs(X-sqrt(0.5)) < 1.0e-16).

test(shortcut_stays_a_dot_product) :-
    'cosine-of-normalized'([3,4], [3,4], 25.0), cosine([3,4], [3,4], 1.0).

test(zero_directions_are_nan) :-
    cosine([], [], Empty), cosine([0,0], [1,2], Zero),
    maplist(is_nan, [Empty,Zero]),
    'vector-normalize'([0,-0.0], Normalized), maplist(is_nan, Normalized).

is_nan(Value) :- float_class(Value, nan).

test(nonfinite_reductions) :-
    norm([1.0Inf,7], 1.0Inf), norm([1.0Inf,1.5NaN], Nan), is_nan(Nan),
    dot([1.0Inf], [0], Undefined), is_nan(Undefined),
    'vector-distance'([1.0Inf], [1.0Inf], Same), is_nan(Same),
    'vector-distance'([-1.0Inf], [1.0Inf], 1.0Inf),
    cosine([1.0Inf], [1], Angle), is_nan(Angle).

test(normalization_preserves_zero_signs) :-
    'vector-normalize'([-0.0,3,4], [Zero,0.6,0.8]),
    assertion(copysign(1.0,Zero) =:= -1.0),
    Huge is 1<<3000, Negative is -Huge,
    'vector-normalize'([-0.0,Negative,1.0Inf], [A,B,C]),
    assertion(copysign(1.0,A) =:= -1.0),
    assertion(copysign(1.0,B) =:= -1.0), is_nan(C).

test(infinite_division_sign_regression) :-
    'vector-divide'([-0.0,-0.0,0.0,0.0], [-1.0Inf,1.0Inf,-1.0Inf,1.0Inf], Values),
    maplist(zero_sign, Values, [1.0,-1.0,-1.0,1.0]).

zero_sign(Value, Sign) :- Value =:= 0.0, Sign is copysign(1.0, Value).

test(exact_zero_division_refuses_whole_vector,
     [throws(error(evaluation_error(zero_divisor),context('vector-divide',_)))]) :-
    'vector-divide'([2,1], [1,0], _).

test(float_zero_division) :-
    'vector-divide'([1,-1,0.0], [0.0,0.0,0], [1.0Inf,-1.0Inf,Nan]), is_nan(Nan).

test(mismatched_dimensions,
     [forall(member(Name,[dot,cosine,'cosine-of-normalized','vector-add','vector-subtract',
                          'vector-multiply','vector-divide','vector-distance'])),
      throws(error(domain_error(vector_dimensions,[1,0]),context(Name,_)))]) :-
    call(Name, [1], [], _).

test(nonnumber_component,
     [throws(error(type_error(number,bad),context(norm,_)))]) :- norm([1,bad], _).

test(complete_validation_precedes_dimension_refusal,
     [throws(error(type_error(number,bad),context(dot,_)))]) :- dot([], [bad], _).

test(improper_list, [throws(error(type_error(list(number),_),context(norm,_)))]) :-
    norm([1|bad], _).

test(cyclic_list, [throws(error(type_error(list(number),_),context(norm,_)))]) :-
    Cycle = [1|Cycle], norm(Cycle, _).

test(unbound_component, [throws(error(instantiation_error,context(norm,_)))]) :- norm([_], _).

test(empty_scale_validates_factor,
     [throws(error(type_error(number,bad),context('vector-scale',_)))]) :-
    'vector-scale'([], bad, _).

test(empty_fill_validates_value,
     [throws(error(type_error(number,bad),context('vector-fill',_)))]) :-
    'vector-fill'(0, bad, _).

test(fill_invalid_count, [forall(member(Count,[-1,1.5])),
                        throws(error(type_error(nonneg,Count),context('vector-fill',_)))]) :-
    'vector-fill'(Count, 0, _).

test(random_fractional_count,
     [throws(error(type_error(integer,1.5),context('random-normal-vector',_)))]) :-
    'random-normal-vector'(1.5, _).

test(random_draw_order_and_state) :-
    with_seed(314159,
        ( getrand(Start), random(A), random(B), random(C), getrand(ExpectedState),
          'vector-normalize'([C,B,A,3,4], Expected),
          setrand(Start), 'random-normal-vector'(3, [3,4], Actual), getrand(ActualState),
          assertion(Actual == Expected), assertion(ActualState == ExpectedState) )).

test(random_nondrawing_cases_keep_state) :-
    with_seed(314159,
        ( getrand(Before), 'random-normal-vector'(0, []),
          'random-normal-vector'(-3, []), 'random-normal-vector'(-3, [3,4], [0.6,0.8]),
          'random-normal-vector'(0, [0,0], Zeros), maplist(is_nan, Zeros),
          getrand(After), assertion(After == Before) )).

test(random_invalid_input_draws_nothing) :-
    with_seed(314159,
        ( getrand(Before),
          catch('random-normal-vector'(3, [bad], _), error(type_error(number,bad),_), true),
          catch('random-normal-vector'(1.5, _), error(type_error(integer,1.5),_), true),
          getrand(After), assertion(After == Before) )).

test(random_results_are_positive_unit_vectors) :-
    with_seed(271828,
        forall(member(Size,[1,2,16,128]),
            ( 'random-normal-vector'(Size, Vector), length(Vector, Size),
              forall(member(Value,Vector), assertion(Value > 0.0)),
              norm(Vector, Length), assertion(abs(Length-1.0) < 1.0e-15) ))).

test(float_policies_restore) :-
    float_policies(Before),
    'vector-divide'([1.0,0.0], [0.0,0.0], [1.0Inf,Nan]), is_nan(Nan),
    dot([1.0Inf,-1.0Inf], [1,1], Sum), is_nan(Sum),
    float_policies(After), assertion(After == Before).

float_policies(flags(A,B,C)) :-
    current_prolog_flag(float_overflow,A), current_prolog_flag(float_zero_div,B),
    current_prolog_flag(float_undefined,C).

test(configured_approximation_refuses,
     [throws(error(representation_error(exact_vector_arithmetic),context('vector-divide',_)))]) :-
    ( current_prolog_flag(max_rational_size, Size) -> true ; Size = infinite ),
    current_prolog_flag(max_rational_size_action, Action),
    setup_call_cleanup(true,
        ( set_prolog_flag(max_rational_size,1), set_prolog_flag(max_rational_size_action,float),
          'vector-divide'([1], [3], _) ),
        ( set_prolog_flag(max_rational_size,Size), set_prolog_flag(max_rational_size_action,Action) )).

test(public_traversal_yields_to_cancellation) :-
    length(Vector,100000), maplist(=(1),Vector),
    call_with_inference_limit(dot(Vector,Vector,_),1000,Outcome),
    assertion(Outcome == inference_limit_exceeded), dot([3,4],[3,4],25.0).

test(output_mismatch_does_not_leak_an_answer, [fail]) :- dot([3],[4],0.0).

:- end_tests(lib_vector_surface).
