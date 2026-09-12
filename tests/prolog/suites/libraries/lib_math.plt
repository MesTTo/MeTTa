% Purpose: verify exact number identities, finite factor search and float boundaries.
% Guarantees: finite domains exercise signs, zero and arbitrary precision;
% conversion tests cover final subnormal ties, signed zero and saturation.
% [tested: lib_math; commit=4d17f1af15fe125e3b8cd488502ba1e0e688fb3e].
% Owns resources: arithmetic policy tests restore the host's rational flags.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_math/lib_math').
:- use_module(library(lists), [member/2]).

:- begin_tests(lib_math).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

test(gcd_and_lcm_identities) :-
    'math-gcd'([],G0), assertion(G0 == 0),
    'math-lcm'([],L0), assertion(L0 == 1),
    forall((between(-20,20,A),between(-20,20,B)),
           ('math-gcd'([A,B],G), 'math-lcm'([A,B],L),
            assertion(G >= 0), assertion(L >= 0),
            assertion(G*L =:= abs(A*B)),
            (G =:= 0 -> assertion(A =:= 0),assertion(B =:= 0)
            ; assertion(A mod G =:= 0),assertion(B mod G =:= 0)))),
    Huge is 1<<2000, Twice is Huge*2,
    'math-gcd'([Huge,Twice],G), assertion(G == Huge),
    'math-lcm'([Huge,Twice],L), assertion(L == Twice).

test(rational_reduction_and_signs) :-
    forall((between(-16,16,N),between(-16,16,D),D =\= 0),
           ('math-rational'(N,D,Q),assertion(rational(Q)),
            'math-ratio'(Q,[A,B]),assertion(B > 0),
            assertion(A*D =:= N*B),assertion(gcd(A,B) =:= 1))),
    'math-ratio'(0.1,Parts),
    assertion(Parts == [3602879701896397,36028797018963968]),
    'math-ratio'(-0.0,Zero), assertion(Zero == [0,1]).

test(rationalization_is_explicit) :-
    'math-rationalize'(0.1,Q), assertion(Q =:= 1 rdiv 10),
    Third is 1 rdiv 3, 'math-rationalize'(Third,Exact), assertion(Exact == Third),
    'math-rationalize'(-0.0,Zero), assertion(Zero == 0),
    Tiny is 2.0** -1074, 'math-rationalize'(Tiny,R),
    assertion(R =:= 1 rdiv (1<<1074)).

test(integer_root_identity_and_nearest_root) :-
    forall((between(1,9,Degree),between(-64,64,Value),
            (Value >= 0 ; Degree mod 2 =:= 1)),
           ('math-integer-root'(Degree,Value,[Root,Rest]),
            assertion(Root**Degree+Rest =:= Value),
            assertion(abs(Root)**Degree =< abs(Value)),
            assertion((abs(Root)+1)**Degree > abs(Value)))),
    Huge is 1<<2048, Expected is 1<<1024,
    'math-integer-root'(2,Huge,Parts), assertion(Parts == [Expected,0]).

test(modular_power_matches_finite_exact_powers) :-
    forall((between(-8,8,Base),between(0,7,Exponent),between(1,13,Modulus)),
           ('math-power-mod'(Base,Exponent,Modulus,Actual),
            Expected is (Base**Exponent) mod Modulus,assertion(Actual == Expected))),
    'math-power-mod'(2,1000000,65537,Large), assertion(Large == 1).

test(factor_stream_is_complete_ordered_and_unmirrored) :-
    forall(between(1,256,Value),
           (findall([A,B],(between(1,Value,A),0 is Value mod A,
                           B is Value div A,A =< B),Expected),
            findall(Pair,'math-factor-pairs'(Value,Pair),Actual),
            assertion(Actual == Expected))).

test(factor_stream_cut_leaves_no_constraints_or_state) :-
    once('math-factor-pairs'(360,First)), assertion(First == [1,360]),
    findall(Pair,'math-factor-pairs'(7,Pair),Again), assertion(Again == [[1,7]]).

test(final_subnormal_rounding_and_signs) :-
    Half is 1 rdiv (1<<1075), Below is ((1<<54)-1) rdiv (1<<1129),
    Above is ((1<<54)+1) rdiv (1<<1129), Tiny is 2.0** -1074,
    forall(member(Q-Expected,[Half-0.0,Below-0.0,Above-Tiny]),
           ('math-float'(Q,Actual),assertion(Actual == Expected),
            Negative is -Q, 'math-float'(Negative,Signed),
            assertion(Signed =:= -Expected),assertion(copysign(1.0,Signed) =:= -1.0))),
    'math-float'(-0.0,Zero), assertion(copysign(1.0,Zero) =:= -1.0).

test(float_saturation_and_classes) :-
    Huge is 1<<2000, Negative is -Huge,
    'math-float'(Huge,PositiveInf), assertion(PositiveInf == 1.0Inf),
    'math-float'(Negative,NegativeInf), assertion(NegativeInf == -1.0Inf),
    Q is 1 rdiv 3, Tiny is 2.0** -1074,
    forall(member(Value-Class,[1-integer,Q-rational,0.0-zero,-0.0-zero,
                              Tiny-subnormal,1.0-normal,1.0Inf-infinite,1.5NaN-nan]),
           ('math-class'(Value,Actual),assertion(Actual == Class))),
    'math-float'(1.5NaN,Nan), assertion(float_class(Nan,nan)).

test(real_catalog_covers_exactly_its_dispatch) :-
    Cases=[sinh-[0]-0.0,cosh-[0]-1.0,tanh-[0]-0.0,asinh-[0]-0.0,
           acosh-[1]-0.0,atanh-[0]-0.0,log10-[100]-2.0,erf-[0]-0.0,
           erfc-[0]-1.0,lgamma-[1]-0.0,atan2-[0,1]-0.0,
           copysign-[1,-0.0]-(-1.0),nexttoward-[1,2]-1.0000000000000002,
           float_integer_part-[-1.75]-(-1.0),float_fractional_part-[-1.75]-(-0.75),
           pi-[]-pi,e-[]-e,epsilon-[]-epsilon,inf-[]-inf,nan-[]-nan],
    findall(['math-function',Name,Arity],
            (member(Name-Args-_,Cases),length(Args,Arity)),Expected),
    'math-real-functions'(Catalog), assertion(Catalog == Expected),
    forall(member(Name-Args-Expression,Cases),
           ('math-real'(Name,Args,Value), Reference is Expression,
            (float_class(Reference,nan) -> assertion(float_class(Value,nan))
            ; assertion(Value == Reference)))).

test(complete_list_validation) :-
    must_throw('math-lcm'([0,bad],_),error(type_error(integer,bad),_)),
    must_throw('math-gcd'([1|bad],_),error(type_error(list(integer),_),_)),
    Cycle=[1|Cycle],
    must_throw('math-gcd'(Cycle,_),error(type_error(list(integer),_),_)),
    must_throw('math-real'(erf,[_],_),error(instantiation_error,_)).

test(refusals_identify_domains) :-
    must_throw('math-rational'(1,0,_),error(domain_error(nonzero_denominator,0),_)),
    forall(member(Value,[1.0Inf,-1.0Inf,1.5NaN]),
           (must_throw('math-ratio'(Value,_),error(domain_error(finite_number,_),_)),
            must_throw('math-rationalize'(Value,_),error(domain_error(finite_number,_),_)))),
    must_throw('math-integer-root'(0,7,_),error(type_error(positive_integer,0),_)),
    must_throw('math-integer-root'(2,-7,_),
               error(domain_error(odd_degree_for_negative_integer,2),_)),
    must_throw('math-power-mod'(2,-1,7,_),error(type_error(nonneg,-1),_)),
    must_throw('math-power-mod'(2,3,0,_),error(type_error(positive_integer,0),_)),
    must_throw('math-factor-pairs'(0,_),error(type_error(positive_integer,0),_)),
    must_throw('math-real'(missing,[],_),error(domain_error(math_real_function,missing),_)),
    must_throw('math-real'(atan2,[1],_),error(domain_error(math_real_arguments,[1]),_)),
    must_throw('math-real'(acosh,[0],_),error(evaluation_error(undefined),_)).

test(configured_approximation_refuses_exact_construction) :-
    (current_prolog_flag(max_rational_size,Size) -> true ; Size=infinite),
    current_prolog_flag(max_rational_size_action,Action),
    setup_call_cleanup(true,
        (set_prolog_flag(max_rational_size,1),set_prolog_flag(max_rational_size_action,float),
         must_throw('math-rational'(1,3,_),error(representation_error(exact_math_arithmetic),_))),
        (set_prolog_flag(max_rational_size,Size),set_prolog_flag(max_rational_size_action,Action))).

:- end_tests(lib_math).
