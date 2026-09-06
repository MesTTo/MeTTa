% Purpose: register function names and arities, protect callable surface, and import host and backend builtins
% Assumes: engine/metta.pl consults this plain file while its owning module is the load context.
% Guarantees: every definition retains engine/metta.pl's implementation module and original load order.
%   builtin_fun/1 remains the only builtin name authority, while
%   builtin_implementation/2 records the exact callable or compiler facet
%   registered through that authority. Final boot rejects missing names,
%   arities, hooks, reverse-surface descriptions, and unreasoned exemptions
%   [tested: tests/prolog/suites/evaluation/builtin_facets.plt;
%   commit=90aa1e67c6d1cda45e27dbaa565f2c537f70ad40].
%   register_fun_in/2 lets a definition in any execution module take over a
%   prelude translator-rule name, and unregister_fun_in/2 retires a global rule
%   whose owning module lost its final body clause
%   [tested: prelude_derived_forms, translator_rule_module_home;
%   commit=d1318d20b5d89d33079c49d0e94aa29e12685664].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/evaluation/metta.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]

%%% Registration: %%%
:- dynamic fun/1, arity/2.
register_fun(N) :- must_be(atom, N),
                   ( fun(N) -> true
                   ; assertz(fun(N), Ref),
                     record_source_assertion(Ref),
                     repair_after_late_registration(N) ).

%The arities a loaded predicate is callable at, which is what a registration
%from Prolog has to record: every other route knows its arity from the
%equation head it just compiled and calls register_arity/2 with it directly.
%An operator's name answers current_predicate/1 at arities 1 and 2 whether or
%not a predicate of that name exists, so those two are not registrable.
%
%This walk used to live inside register_fun/1, guarded by "the name is new".
%A library registering 'norm'/3 for a name some space already defined at MeTTa
%arity 1 therefore recorded no arity at all, and incomplete_application_kind/3
%reads a missing arity as "not applied far enough", so (norm a b) compiled to a
%partial application. Reading it here instead means the arities are recorded
%for the registration that asked for them, whatever else knows the name
%[tested: a_registration_records_arities_for_a_name_that_is_already_a_function].
%Every arity the name is CALLABLE at, and callable means defined here rather
%than merely visible. The exclusion is not defensive: library(yall) exports
%//2 through //9 into user as its free-variables lambda, so probing
%current_predicate/1 alone recorded SEVEN arities for `/` where + and * have
%one. (/ 1 2 3) then compiled to a direct '/'(1,2,3,_) call, which is yall's
%lambda, and answered `type_error(lambda_free, 1)` where every other operator
%answers the engine's own function_input_arities naming the operator
%[tested: metta_registration_arities].
%
%imported_from/1 is the exact question, and the arity =< 2 clause below is the
%older half-answer to the same thing: it excluded 1/2 the TERM and nothing
%told it about 1/2 the lambda.
register_prolog_arities(N) :-
    forall(( current_predicate(N/Arity),
             \+ (current_op(_, _, N), Arity =< 2),
             \+ (current_op(_, _, N), imported_predicate(N, Arity)) ),
           register_arity(N, Arity)).

%%% Arities a predicate outside this tree lent a MeTTa name by accident %%%
%
%A predicate that shares a MeTTa operation's name but not its shape is a
%different predicate, and registering its arity made an UNDER-APPLIED call
%compile straight into it. `!(not)` reached SWI's own not/1, which is negation,
%and aborted the runnable with `not/1: Arguments are not sufficiently
%instantiated` instead of answering anything at all; the same held for
%`(append)`, `(assert)`, `(exists_file)` and `(sleep)`. Under-applying an
%operation is an ordinary MeTTa event -- this engine answers a partial
%application, `(sqrt-math)` is `(partial sqrt-math ())` -- and no MeTTa event
%may take the host down
%[tested: test_an_underapplied_operation_answers_instead_of_aborting].
%
%The operation's OWN description decides which arities are its, and it has two
%independent halves that are read together: an implementation facet, whose key
%is the MeTTa arity and whose Prolog predicate therefore has one more argument;
%and an arrow declaration, a chain of N links being the Prolog predicate of
%arity N. Either one claiming an arity keeps it. So `(: not (-> Bool Bool))`
%and `builtin_implementation(not/1, _)` both keep not/2 while nothing claims
%not/1, and `(: length (-> Expression Number))` keeps length/2 even though
%length/2 is a system predicate too.
%
%WHAT THIS DOES NOT ASK IS `built_in`, and that was the defect. built_in is a
%property of the BUILD rather than of the collision: swipl-wasm 8.0.6 defines
%sleep/1 in library(wasm), its JavaScript interop library, which is an ordinary
%module predicate and not built_in, so the pass kept arity(sleep, 1) there and
%the Node seat's every boot then failed the registration coverage check with
%`unregistered_builtin_spec(sleep/0)`, 44 of its 621 tests with it
%[measured 2026-09-06: `cd extensions/node && npm test` reads 44 failures
%before and 0 after; the same engine natively reads sleep/1 as system].
%A predicate this tree DEFINES is kept whatever a build calls it, which is the
%half built_in was standing in for, and it is asked the way the reverse
%coverage scan asks it, through the file the clauses came from.
%
%Measured on both builds and the two now agree ROW FOR ROW, which is the
%property the old spelling did not have: nine registrations go, append/1,
%assert/1, copy_term/3, copy_term/4, not/1, sleep/1, sort/4, term_hash/4 and
%throw/1, natively and under swipl-wasm alike. The native set is byte-identical
%to what the built_in spelling removed, so nothing this tree relies on changes
%[measured 2026-09-06: the same nine under `swipl -g` and inside the wasm
%engine the Node seat boots]. None of them is called by any example, test or
%library, and every library or engine-defined predicate is untouched because a
%facet claims it, its arrow declaration claims it, or its file is in this tree
%[tested: builtin_facets:a_foreign_predicate_lending_a_builtin_name_loses_its_arity,
%builtin_facets:the_pass_removes_a_foreign_arity_and_keeps_the_described_one,
%builtin_facets:a_tree_defined_arity_is_told_from_a_foreign_one,
%builtin_facets:the_retraction_set_is_the_same_nine_on_every_build;
%commit=7eff330776f703cb603d7eea03fc1166d9e08e5e].
%
%IT RUNS AFTER THE DECLARATIONS AND THE PRELUDE, not while the names register,
%and that ordering is the whole reason it is a separate pass:
%register_builtin_fun/1 runs at DIRECTIVE time while load_builtin_type_surface/0
%and load_engine_prelude/0 run at INITIALIZATION time, so a filter inside the
%registration sees an empty declaration table and drops the arities it exists to
%keep -- measured, it took length/2, sort/2 and msort/2 with it and turned
%`(length (1 2 3))` into a partial application. It is one pass over the registry
%rather than a test on the hot path, which is why the calls that read arity/2
%are untouched.
%
%Limitation: a host library or backend that registers a name AFTER the boot
%chain is not swept, because nothing re-runs this. Nothing in the tree does
%that today; a registration door that starts to would call this again.
%%%% What a builtin's clauses were when the engine finished booting %%%%
%
%A registration that asks for a name the engine ALREADY provides is satisfied,
%not refused. Upstream's lib_import.metta asks for
%(static-import! git-import! use-module!) in ONE call, and this engine ships
%git-import! itself in lib/lib_gitimport/lib_gitimport.pl, so that name already
%denotes the very predicate the caller is asking for and the registration would
%replace nothing. Refusing it stopped a library that asks for a superset of
%what it provides from loading at all
%[measured 2026-08-30: examples/prologimport.metta stopped at that refusal
%with every earlier test already passing].
%
%The question a reserved name has to answer is whether the clauses behind it
%are STILL the engine's, and the only exact answer is the file they came from.
%It is recorded once, here, after the boot chain has loaded every library the
%engine ships, and compared at the door. A file consulted later that redefines
%the name moves that file, and the refusal then fires on the replacement it
%exists to catch. This is import's ordinary idempotence: `import x` is a no-op
%once x is in sys.modules, and CREATE TABLE IF NOT EXISTS says the same of a
%name that already denotes what was asked for
%[tested: a_builtin_the_engine_still_backs_is_a_no_op,
%a_builtin_whose_clauses_moved_is_refused; commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
%
%A name registered AFTER this pass, by an extension or a host, has no row and
%is refused exactly as before: the engine cannot say a claim is idempotent
%when it never saw the original.
:- dynamic builtin_function_source/2.
%The ARITY comes from the registry rather than from current_predicate/1's
%enumeration. Asking `current_predicate(N/A)` with A unbound scans the
%module's predicate table for every one of the ~300 builtin names, and this
%pass runs on every boot: 26.4M instructions of a 1,065M boot, measured
%2026-08-30 by removing the pass. The registry already holds each name's
%arities because register_prolog_arities/1 put them there, so binding A first
%turns a scan into a lookup.
snapshot_builtin_function_sources :-
    finalize_builtin_implementations,
    validate_builtin_registry,
    forall(builtin_fun(N),
           (   builtin_function_source(N, _)
           ->  true
           ;   builtin_first_clause_file(N, Source),
               assertz(builtin_function_source(N, Source))
           )).

builtin_first_clause_file(N, Source) :-
    (   arity(N, Arity),
        functor(Head, N, Arity),
        nth_clause(Head, 1, Ref),
        clause_property(Ref, file(File))
    ->  Source = File
    ;   Source = unknown
    ).

%The SAME lookup the snapshot took, so the two cannot disagree about which
%arity they read.
builtin_clauses_unchanged(N) :-
    builtin_function_source(N, Booted),
    builtin_first_clause_file(N, Now),
    Booted == Now.

retract_unrelated_system_arities :-
    findall(N-Arity,
            ( arity(N, Arity), unrelated_system_predicate(N, Arity) ),
            Unrelated),
    forall(member(N-Arity, Unrelated), retractall(arity(N, Arity))).

%A name the engine says NOTHING about is not judged at all, which is what
%keeps the pass off a host's or a backend's own registrations. Saying something
%is either half of the description, and both halves are needed here: the core
%names carry facets as source clauses, while a prelude name like `throw` has
%only its arrow declaration until finalize_builtin_implementations/0 derives
%its facet, which happens in the NEXT boot step.
unrelated_system_predicate(N, Arity) :-
    builtin_described_name(N),
    \+ described_metta_arity(N, Arity),
    \+ declared_metta_arity(N, Arity),
    \+ builtin_tree_defined_arity(N, Arity).

builtin_described_name(N) :-
    (   builtin_implementation(N/_, _)
    ->  true
    ;   seam:builtin_type_declaration(N, _)
    ).

described_metta_arity(N, Arity) :-
    MettaArity is Arity - 1,
    MettaArity >= 0,
    builtin_implementation(N/MettaArity, _).

declared_metta_arity(N, Arity) :-
    seam:builtin_type_declaration(N, [->|Links]),
    length(Links, Arity).

%Currently no arity is kept by the declaration alone, and it is asked anyway:
%the two halves of the description are independent statements, and an arity a
%declaration claims with no facet behind it has to reach
%validate_builtin_registration_coverage/0 as drift rather than disappear here.
%The same holds for an arity this tree defines and has not described.
%
%The file question is the reverse coverage scan's, asked through the same two
%predicates, so "a predicate of ours" has one meaning in this file. A predicate
%with no source file at all -- every C-defined SWI builtin -- is not ours.
builtin_tree_defined_arity(N, Arity) :-
    metta_engine_module(Engine),
    current_predicate(Engine:N/Arity),
    functor(Head, N, Arity),
    predicate_property(Engine:Head, implementation_module(Owner)),
    current_predicate(Owner:N/Arity),
    source_file(Owner:Head, File),
    builtin_project_implementation_prefixes(Prefixes),
    builtin_project_implementation_file(Prefixes, File).

%Only for an OPERATOR, and the first attempt got that wrong: excluding every
%imported predicate dropped length/2, which is library(lists)'s and a
%perfectly good builtin, so (length ...) compiled to partial(length, [...])
%and four gates went red. An imported predicate is normal; an imported
%predicate whose name is also an OPERATOR is the collision.
imported_predicate(N, Arity) :-
    functor(Head, N, Arity),
    metta_engine_module(Engine),
    predicate_property(Engine:Head, imported_from(_)).

%Record each callable arity once, even when a function has many equations.
register_arity(N, Arity) :- ( arity(N, Arity) -> true
                            ; assertz(arity(N, Arity), Ref),
                              record_source_assertion(Ref) ).

%The module whose equations are in scope while a term is compiled or run. The
%default is &self's, which is where a program that names no space writes.
%
%The default is a fact read rather than a constant unified, one inference
%instead of none, because the alternative is writing '$metta_exec:&self' out
%here and having two places that decide the name
%[tested: metta_module_context:the_default_context_is_selfs_own_module].
current_metta_module(Module) :-
    ( nb_current('$metta_module', M) -> Module = M ; metta_self_module(Module) ).

%Skipping the switch when Module is already in force was tried and taken back
%out. It saved 4 inferences on every Python evaluation and cost 2 on every
%annotated typed call, which is the wrong side of that trade: the crossing
%happens once and the typed call happens in a loop. Measured 2026-08-16, the
%@m.define annotated tier of extensions/python/benchmarks/extension_cost.py went 20.00 to
%22.00 with the test in place, against m.fn 68.00 to 64.00.
%The argument is a MODULE, and refusing anything else is what keeps this
%honest now that a space and its module are different atoms. They used to be
%the same atom for every space but &self, so `with_metta_module('&pool', G)`
%worked by coincidence; today it would switch the context to a module nothing
%compiles into, every lookup would miss, and the goal would answer as if the
%space were empty. One indexed cache probe turns that into a refusal at the
%call [tested: metta_module_context:a_space_name_is_refused_where_a_module_is_asked].
with_metta_module(Module, Goal) :-
    (   metta_exec_module_known(_, Module)
    ->  true
    ;   throw(error(type_error(metta_execution_module, Module),
                    context(with_metta_module/2,
                            'space_module/2 maps a space to the module its \c
                             clauses are in; pass that, not the space')))
    ),
    current_metta_module(Previous),
    setup_call_cleanup(b_setval('$metta_module', Module),
                       Goal,
                       b_setval('$metta_module', Previous)).

%Control signals pass through every recovery catch: a caught abort, limit,
%alarm, or interrupt is a stopped program pretending it succeeded. This is
%the KeyboardInterrupt-outside-Exception design; a swallowed limit signal
%also DISARMS call_with_inference_limit for the rest of the call, measured
%as six million inferences spent under a thousand-inference budget when a
%recovery catch ate the signal mid-translation.
%
%The engine's own list. It is a SEAM, so a library that introduces its own
%cancellation or budget signal adds a clause instead of being swallowed by
%the first recovery catch it meets
%[tested: a_librarys_own_control_signal_is_not_recovered_from].
%
%Its multifile declaration is HERE and not with the other seams, which is the
%one exception seam_home/2 in engine/ext_points.pl exists to answer. The name
%is also an engine_emitted/1 one: the translator writes control_exception/1
%into compiled bodies and protect_engine_emitted/1 imports every emitted name
%into a space's execution module FROM THE ENGINE'S MODULE, so a copy living
%in the seam module would leave the import with nothing to find.
:- multifile control_exception/1.
control_exception(time_limit_exceeded).
control_exception(inference_limit_exceeded).
control_exception(metta_host_interrupted).
control_exception('$aborted').
%The reserved seam envelopes for the same two signals: the shim declares
%every metta_control_signal kind control on the Python side, and these two
%are thrown by the ENGINE's own bound forms (inferences, with-pragma!),
%so the CLI must agree or a program could catch its own budget there and
%disarm the counter.
control_exception(error(metta_control_signal(time_limit, _), _)).
control_exception(error(metta_control_signal(inference_limit, _), _)).
%A tabling restraint is a bound the program declared for one of its own
%tables, (cache f (max-answers N)) and its two size siblings, thrown by
%lib_tabling's tripwire when SWI trips it. It is the same kind of signal as
%the two above and reaches the host seats through the same classifier, so a
%MeTTa catch must not be able to disarm it either.
control_exception(error(metta_control_signal(restraint, _), _)).

%The reserved envelope renders its payload: a reader failure used to cross
%as a bare syntax_error and take SWI's own message with it, and wrapping
%it in the envelope must not trade "missing ')' ..." for an unknown-term
%dump on a host that shows message text.
:- multifile prolog:error_message//1.
prolog:error_message(metta_control_signal(syntax, Detail)) -->
    [ 'MeTTa syntax error: ~w'-[Detail] ].
%The two bound kinds had no rendering at all, so a program that spent its own
%(pragma! max-inferences N) printed `Unknown error term:
%metta_control_signal(inference_limit,500)` at the CLI [measured 2026-08-27 on
%!(with-pragma! ((max-inferences 500)) (spin 1000000)); commit=6da1b0dacc500fc7691a66722ba58f52ab2df081]. Every
%seat that shows message text reads these, the C binding included, so they say
%which bound stopped the work and what it was set to.
prolog:error_message(metta_control_signal(inference_limit, Limit)) -->
    [ 'the evaluation passed its ~w inference bound and was stopped'-[Limit] ].
prolog:error_message(metta_control_signal(time_limit, Seconds)) -->
    [ 'the evaluation passed its ~w second bound and was stopped'-[Seconds] ].
prolog:error_message(metta_control_signal(restraint, [Word, Bound, Call])) -->
    [ 'the (~w ~w) restraint declared for the table of ~w tripped and the \c
       evaluation was stopped'-[Word, Bound, Call] ].
control_exception(error(resource_error(_), _)).

%A result past binary64 SATURATES to the IEEE value instead of raising,
%which is upstream's arithmetic (plain Rust f64: "1e400".parse and 1e308*10
%both answer inf there) and the reader's own behaviour for literals, so the
%two halves of the numeric boundary agree: 1e400 reads as inf and
%(+ 1e400 1) answers inf. SWI's error mode rejects any non-finite RESULT,
%operands included, so without this an infinity the reader legally produced
%could not even carry through (+ inf 1). The flag is borrowed for the one
%retry and given back, parser.pl's metta_saturating_parse discipline on the
%evaluation side; the happy path pays nothing because this only runs from a
%catch recovery. The same discipline covers the whole IEEE family when a
%floating expression is present, including an explicit integer promotion:
%division by a float zero answers the signed infinity and the NaN class
%(0.0/0.0, inf - inf, sqrt of a negative, asin past one) answers NaN, which
%is what isnan-math and isinf-math exist to
%observe. Every fault outside metta_ieee_retry/1, integer division by zero
%first among them, reaches the operation-recovery funnel below; the retry's
%own catch is the net for faults the flags do not govern, none known for the
%shipped operations.
metta_saturating_recover(Operation, Expression, Result, Error) :-
    metta_ieee_saturable(Expression, Error),
    !,
    current_prolog_flag(float_overflow, WasOverflow),
    current_prolog_flag(float_zero_div, WasZeroDiv),
    current_prolog_flag(float_undefined, WasUndefined),
    catch(setup_call_cleanup(
              ( set_prolog_flag(float_overflow, infinity),
                set_prolog_flag(float_zero_div, infinity),
                set_prolog_flag(float_undefined, nan) ),
              Result is Expression,
              ( set_prolog_flag(float_overflow, WasOverflow),
                set_prolog_flag(float_zero_div, WasZeroDiv),
                set_prolog_flag(float_undefined, WasUndefined) )),
          Residual,
          rethrow_metta_operation_error(Operation, Residual)).
metta_saturating_recover(Operation, _, _, Error) :-
    metta_arithmetic_rethrow(Operation, Error).

%is/2 raises a BARE instantiation error for an operand it does not have, and
%that error names neither the operation's modes nor what to write instead: it
%is SWI's, not the language's. Every backward query the engine CAN answer is
%decided before an exception exists (metta_int_solve/5 for one unknown among
%integers, metta_clp_backward/4 for the integer relations past it), so what
%reaches here is a query outside both: a float operand, or an operation with
%no relation to solve. It refuses by name
%[tested: test_arithmetic_inverts_past_the_linear_case_or_refuses_with_the_reason].
metta_arithmetic_rethrow(Operation, error(instantiation_error, _)) :- !,
    metta_refuse_unsolved_arithmetic(Operation, unbound_operand).
metta_arithmetic_rethrow(Operation, Error) :-
    rethrow_metta_operation_error(Operation, Error).

%Float zero division belongs to the IEEE retry, while integer zero division
%is a contained language result. Test the IEEE class first so `/ 1.0 0.0`
%keeps its signed infinity and only the all-integer fault reaches the shared
%operation recovery.
metta_arithmetic_saturating_recovery(Operation, Arguments, Expression,
                                     Error, Result) :-
    (   metta_ieee_saturable(Expression, Error)
    ->  metta_saturating_recover(Operation, Expression, Result, Error)
    ;   metta_operation_recovery(Operation, Arguments, Error, Result)
    ).

%An operation fault is an answer when the language gives the fault a reason.
%LeaTTa pins both integer doors byte-exactly as (Error (<op> 7 0)
%DivisionByZero), while every other host error retains the raising path
%[source: LeaTTa tests/regression/division_convention.metta:82-90;
%tested: test_integer_division_by_zero_answers_what_d1_decides;
%commit=ecd792eacbfe1810645434ce406f79be3a9e03d1].
metta_operation_recovery(Operation, Arguments,
                         error(evaluation_error(zero_divisor), _), Answer) :-
    maplist(integer, Arguments), !,
    metta_error_atom(Operation, Arguments, 'DivisionByZero', Answer).
metta_operation_recovery(Operation, _, Error, _) :-
    metta_arithmetic_rethrow(Operation, Error).

%Which evaluation faults license the retry. Overflow retries
%unconditionally, because an ALL-INTEGER division can overflow in its float
%conversion and the saturated value is this engine's committed answer
%there. Zero division and the NaN family retry only when the expression has a
%float operand or an explicit float/1 promotion: upstream's float arm is raw
%f64 (1.0/0.0 is inf,
%0.0/0.0 and inf - inf are NaN, by construction), while its INTEGER
%division by zero answers a DivisionByZero Error atom, so an integer zero
%takes the operation-recovery funnel instead of this retry. The retry runs
%under all three IEEE flags at once rather
%than only the one that fired, because a compound expression can fault
%twice: log-math with base 1 overflows in log(0.0) and then divides the
%saturated -inf by log(1) = 0.0, and one-flag-at-a-time would error where
%the arbiter's arithmetic answers -inf.
metta_ieee_retry(float_overflow).
metta_ieee_retry(zero_divisor).
metta_ieee_retry(undefined).

%Whether a fault is in the retryable family at all, factored out so the
%chained recovery above can ask without committing to the retry.
metta_ieee_saturable(Expression, error(evaluation_error(Evaluation), _)) :-
    metta_ieee_retry(Evaluation),
    (   Evaluation == float_overflow
    ->  true
    ;   sub_term(Operand, Expression),
        (   float(Operand)
        ;   compound(Operand), functor(Operand, float, 1)
        )
    ).

%Keep the ISO Formal term because callers and the MeTTa catch form inspect it.
%Only the host context is replaced, so lists:min_list/3, is/2, and nb_setval/2
%cannot leak into a language-level diagnostic. Integer fast paths avoid the
%catch cost on valid arithmetic without letting float overflow escape, except
%division, whose all-integer case converts a non-divisible pair to float and
%can overflow doing it, so it pays the catch like the float arms. Over
%100,000 calls the guarded form used
%300,002 inferences against 300,003 directly, while an unconditional catch used
%400,002 [measured: guarded -1 and caught +99,999 inferences, 2026-08-15].
rethrow_metta_operation_error(_, Error) :- control_exception(Error), !,
                                            throw(Error).
rethrow_metta_operation_error(Operation, error(Formal, _)) :- !,
    throw(error(Formal,
                context(Operation, 'while evaluating MeTTa operation'))).
rethrow_metta_operation_error(_, Error) :- throw(Error).

throw_metta_type_error(Operation, Expected, Culprit) :-
    throw(error(type_error(Expected, Culprit),
                context(Operation, 'invalid MeTTa operation argument'))).

%The classification a host reads a builtin refusal through, beside the two
%throwers that produce the shape. The engine names the written MeTTa
%operation in the context, so a host reads the name from the term rather
%than from rendered text; only a type_error carries an expected type and a
%culprit, and any other formal reports its own functor with both parts
%ABSENT. Absence is an unbound part, which is the one marker no culprit can
%collide with; a host maps var-ness to its own None.
metta_host_operation_error(error(Formal, context(Operation, Message)),
                           Operation, Kind, Expected, Culprit) :-
    atom(Operation),
    nonvar(Message),
    metta_host_operation_message(Message),
    nonvar(Formal),
    metta_host_operation_formal(Formal, Kind, Expected0, Culprit0),
    metta_host_operation_part(Expected0, Expected),
    metta_host_operation_part(Culprit0, Culprit).

metta_host_operation_message('while evaluating MeTTa operation').
metta_host_operation_message('invalid MeTTa operation argument').

%is/2 reports an unevaluable term as a predicate indicator, Name/Arity. That
%is a Prolog artifact rather than anything the user wrote, and swrite would
%read the / as MeTTa and print (/ a 0). A zero-arity indicator is exactly
%the symbol the source wrote, so it crosses as that symbol.
metta_host_operation_formal(type_error(evaluable, Name/Arity), type_error,
                            evaluable, Culprit) :- !,
    ( Arity =:= 0 -> Culprit = Name
                   ; format(atom(Culprit), '~w/~w', [Name, Arity]) ).
metta_host_operation_formal(type_error(Expected, Culprit), type_error,
                            Expected, Culprit) :- !.
metta_host_operation_formal(Formal, Kind, _, _) :- functor(Formal, Kind, _).

%A wire carries atomics and lists of them; any other compound crosses as
%its written text, from swrite/2, the engine's own printer, so it reads
%back as the MeTTa the user wrote: a generic term writer would spell a
%variable _112 and a partial application partial(g,[1]), neither of which
%is MeTTa surface syntax. An unbound part stays unbound.
metta_host_operation_part(Term, Term) :- var(Term), !.
metta_host_operation_part(Term, Value) :- metta_host_operation_value(Term, Value).

metta_host_operation_value(Term, Term) :- atomic(Term), !.
metta_host_operation_value(Term, Value) :-
    is_list(Term), !,
    maplist(metta_host_operation_value, Term, Value).
metta_host_operation_value(Term, Text) :- swrite(Term, Text).

%The culprit in the message is the value the program wrote, so it reads as
%MeTTa: (State 5), not ['State',5]. The Formal term stays ISO, because
%callers and the MeTTa catch form inspect it, and the structured Python
%surface reads it too; only the rendering changes.
%
%prolog:message//1 is consulted before the formal-only
%prolog:error_message//1, and this clause matches the context MeTTa's own
%guards attach, so every other error SWI renders is untouched
%[source: SWI-Prolog 10.1 boot/messages.pl, translate_message/1]
%[tested: metta_operation_error_message].
%The context is matched in the body, not in the head: library(error) throws
%its type errors with an unbound context, which a head pattern would unify
%with and claim, renaming every unrelated type error in the process
%[tested: metta_operation_error_message:an_unrelated_type_error_is_untouched].
%metta_error_context(+Context, -Operation, +Detail) reads a context term
%WITHOUT writing to it. Matching context(Operation, Detail) in the head looks
%equivalent and is not: SWI's own errors carry context(PI, _) with the second
%argument UNBOUND, so unifying a detail atom into it succeeds and the clause
%then renders every ordinary error of that formal. This clause was hijacking
%all of them, which is where I16's "system:(is)/2: evaluable expected, found
%(/ foo 0)" came from: a library predicate's is/2 type error was being
%reported in MeTTa's operation vocabulary, naming an engine internal and a
%culprit the program never wrote [tested: metta_operation_errors,
%an_unrelated_type_error_keeps_swi_s_own_message].
metta_error_context(Context, Operation, Detail) :-
    nonvar(Context),
    Context = context(Operation, Actual),
    nonvar(Actual),
    Actual == Detail.

prolog:message(error(type_error(Expected, Culprit), Context)) -->
    { metta_error_context(Context, Operation, 'invalid MeTTa operation argument'),
      sdisplay(Culprit, CulpritText) },
    [ '~w: ~w expected, found ~w'-[Operation, Expected, CulpritText] ].
%The ISO formal stays existence_error(procedure, Name), so a program can catch
%it the standard way; only the wording changes, because SWI's default renders
%it as "procedure `f' does not exist", which says nothing about why a
%registration cares. What it costs is the reason worth printing: a name with
%no predicate records no arity, and incomplete_application_kind/3 then reads
%the missing arity as "not applied far enough", so the call compiles to a
%partial application instead of failing.
prolog:message(error(existence_error(procedure, Name), Context)) -->
    { metta_error_context(Context, _, 'no Prolog predicate of that name is loaded') },
    [ 'no predicate named ~w is loaded, so registering it would compile \c
       every call to it into a partial application rather than failing'-[Name] ].

%These builtins validate their own runtime inputs and provide their own error
%context. The translator may therefore bypass reflective input filtering when
%the builtin has not been overridden. Keep this list aligned with those guards.
runtime_type_guarded('+').
runtime_type_guarded('-').
runtime_type_guarded('*').
runtime_type_guarded('/').
runtime_type_guarded('%').
runtime_type_guarded('<').
%== and != are TERM equality and answer a Bool for any two operands, which is
%exactly what their declared type (-> $a $b Bool) states, so the typed
%dispatch has nothing left to check. They carried a comparable_operands/2
%guard for LeaTTa's one-variable declaration until 2026-08-30; upstream's
%declaration uses two independent variables and constrains nothing
%[source: PeTTa@ae66fa8 lib/lib_builtin_types.metta:17-18]. Classifying them
%here is what makes
%lib_builtin_types.metta affordable: with the file loaded, a workload calling
%== and != went from 102402 inferences to 181602, +77%, and back to 102402
%with these two lines [measured 2026-08-16]. Their own guard is cheaper than
%either, and free on two numbers: a thousand-iteration == loop is 4487.45
%inferences with and without it [measured 2026-08-19]. A user or named-space
%equation overriding either still gets the full typed dispatch, because
%runtime_guarded_builtin_call/1 requires the unmodified builtin.
%
%The declaration was (-> $a $b Bool), two independent variables, which
%constrained nothing and is why (== 1 "S") answered False. Upstream writes
%(-> $t $t Bool) [source: pinned stdlib.md via the arbiter, and measured from
%hyperon 0.2.10's own !(get-type ==) on 2026-08-19].
runtime_type_guarded('==').
runtime_type_guarded('!=').
runtime_type_guarded('>').
runtime_type_guarded('<=').
runtime_type_guarded('>=').
runtime_type_guarded(min).
runtime_type_guarded(max).
runtime_type_guarded(exp).
runtime_type_guarded('#+').
runtime_type_guarded('#-').
runtime_type_guarded('#*').
runtime_type_guarded('#div').
runtime_type_guarded('#//').
runtime_type_guarded('#mod').
runtime_type_guarded('#min').
runtime_type_guarded('#max').
runtime_type_guarded('#<').
runtime_type_guarded('#>').
runtime_type_guarded('#=').
runtime_type_guarded('#\\=').
runtime_type_guarded('#=<').
runtime_type_guarded('#>=').
runtime_type_guarded('pow-math').
runtime_type_guarded('bit-shift-left').
runtime_type_guarded('bit-shift-right').
runtime_type_guarded('sqrt-math').
runtime_type_guarded('abs-math').
runtime_type_guarded('log-math').
runtime_type_guarded('exp-math').
runtime_type_guarded('trunc-math').
runtime_type_guarded('ceil-math').
runtime_type_guarded('floor-math').
runtime_type_guarded('round-math').
runtime_type_guarded('sin-math').
runtime_type_guarded('cos-math').
runtime_type_guarded('tan-math').
runtime_type_guarded('asin-math').
runtime_type_guarded('acos-math').
runtime_type_guarded('atan-math').
runtime_type_guarded('isnan-math').
runtime_type_guarded('isinf-math').
runtime_type_guarded('min-atom').
runtime_type_guarded('max-atom').
runtime_type_guarded('random-int').
runtime_type_guarded('random-float').
runtime_type_guarded(and).
runtime_type_guarded(or).
runtime_type_guarded(not).
runtime_type_guarded(xor).
runtime_type_guarded(implies).

%The evaluator's catch-all: real errors take the recovery, control
%signals keep flying.
:- meta_predicate catch_recover(0, 0).
catch_recover(Goal, Recovery) :-
    catch(Goal, E, ( control_exception(E) -> throw(E) ; call(Recovery) )).

%Whether a symbol is callable from where we are: a process-wide function that
%no named equation module claims, a function this module defines, or one &self
%defines, since &self is shared. fun_scoped/1 summarizes non-user fun_in/2
%claims. A builtin or user-only function is therefore unambiguous in every
%space and avoids a current-module read in higher-order loops.
%fun_in/2 is only ever asserted by register_fun_in/2, which registers fun/1
%first, so fun_in implies fun. A name that is not a function therefore cannot
%be one here either, and one indexed lookup settles it: the old second clause
%went on to read current_metta_module/1 and two fun_in/2 facts before failing,
%for every non-function head the translator resolves
%[measured 2026-08-15: alpha-unique 4,050,778 to 3,750,772 inferences].
fun_here(F) :- fun(F),
               ( \+ fun_scoped(F) -> true
               ; current_metta_module(Module), fun_here_in(Module, F) ).

%The builtin fallback is what keeps (+ 1 2) working in &self after some other
%named space defines (= (+ $a $b) ...). fun_scoped(N) stops fun_here/1's first
%clause applying process-wide, and without this the name resolved nowhere: one
%named space turned + into inert data in every other space and in engines
%built afterwards [tested: metta_builtin_scoping].
fun_here_in(Module, F) :-
    (   fun_in(Module, F)
    ->  true
    ;   metta_restricted_exec_module(Module, _)
    ->  restricted_callable_name(F)
    ;   metta_exec_module_parent(Module, ParentModule)
    ->  fun_here_in(ParentModule, F)
    ;   metta_self_module(Self), Module \== Self, fun_in(Self, F)
    ->  true
    ;   builtin_fun(F)
    ).

%Register a function and record which module its clauses live in. fun/1 stays
%global because the translator consults it at compile time to decide whether a
%head is a call or data, and that decision has to hold wherever the term is
%compiled; fun_in/2 says where the clauses actually are, so a caller can ask
%whether *this* space defines a symbol rather than whether any space does.
:- dynamic fun_in/2, fun_scoped/1.
%A builtin is visible from every space, and stays visible when a named space
%defines its name. fun_in/2 cannot carry that: it means "an equation or a
%registered operation defines this here", which is exactly the test
%runtime_guarded_builtin_call/1 uses to decide a builtin was overridden. One
%fact for each meaning, so neither reading breaks the other.
:- dynamic builtin_fun/1.
:- dynamic builtin_implementation/2.
:- dynamic builtin_registration_exemption/2.
%The exemption is a DECLARATION seam and therefore lives in `seam`, the module
%every handler seam lives in, rather than beside its reader in the engine core.
%Declared unqualified here it was homed in the engine module, which
%seam_module:test_every_seam_is_reached_under_its_module rejects: the engine
%core holds control_exception/1 and nothing else, because the translator emits
%that one and a space's execution module has to import it from there.
:- multifile seam:builtin_implementation_exemption/2.
:- dynamic seam:builtin_implementation_exemption/2.
seam:kind(builtin_implementation_exemption/2, declaration).
register_builtin_fun(N) :- register_fun(N),
                           register_prolog_arities(N),
                           ( builtin_fun(N) -> true ; assertz(builtin_fun(N)) ).

register_fun_in(Module, N) :-
    must_be(atom, N),
    %Fold named-space eviction into register_fun/1's existing fun/1 question.
    %A fresh name takes no registry lookup; a prelude rule is already a
    %function and reaches the one additional test it needs.
    (   fun(N)
    ->  (   prelude_translator_rule(N)
        ->  evict_prelude_definition(N)
        ;   true
        )
    ;   assertz(fun(N), Ref),
        record_source_assertion(Ref),
        repair_after_late_registration(N)
    ),
    (   fun_in(Module, N)
    ->  true
    ;   assertz(fun_in(Module, N), FunInRef),
        record_source_assertion(FunInRef)
    ),
    (   metta_self_module(Module)
    ->  true
    ;   fun_scoped(N)
    ->  true
    ;   assertz(fun_scoped(N), ScopedRef),
        record_source_assertion(ScopedRef)
    ).

unregister_fun_in(Module, N) :-
    retractall(fun_in(Module, N)),
    %Withdraw the global name before repair can translate a dependent against
    %a missing body.
    translator_rules:retire_translator_rule_in(Module, N),
    metta_self_module(Self),
    (   fun_in(Other, N), Other \== Self
    ->  true
    ;   restricted_dispatch_name(N)
    ->  true
    ;   retractall(fun_scoped(N))
    ).

unregister_fun_everywhere(N) :- retractall(fun_in(_, N)),
                                retractall(fun_scoped(N)).
%A core declaration owns both the existing name registration and its exact
%implementation facet. Names therefore occur once: the directive below reads
%each facet and passes its name through register_builtin_fun/1 rather than
%maintaining a parallel name registry. The key uses MeTTa arity; ordinary
%implementations have one additional Prolog result argument. `engine` is
%symbolic because this plain file may be loaded into a different execution
%module, while named modules identify their actual predicate owner.
builtin_implementation(superpose/1, prolog(engine)).
builtin_implementation(empty/0, prolog(engine)).
builtin_implementation(let/3, compiler(translator, metta_special_form_head, 1)).
builtin_implementation('let*'/2, compiler(translator, metta_special_form_head, 1)).
builtin_implementation('+'/2, prolog(engine)).
builtin_implementation('-'/2, prolog(engine)).
builtin_implementation('*'/2, prolog(engine)).
builtin_implementation('/'/2, prolog(engine)).
builtin_implementation('%'/2, prolog(engine)).
builtin_implementation(min/2, prolog(engine)).
builtin_implementation(max/2, prolog(engine)).
builtin_implementation('new-state'/1, prolog(engine)).
builtin_implementation('change-state!'/2, prolog(engine)).
builtin_implementation('get-state'/1, prolog(engine)).
builtin_implementation('bind!'/2, prolog(engine)).
builtin_implementation('register-token!'/2, prolog(parser)).
builtin_implementation('unregister-token!'/1, prolog(parser)).
builtin_implementation('declare-pre-add!'/2, prolog(engine)).
builtin_implementation('undeclare-pre-add!'/1, prolog(engine)).
builtin_implementation('declare-post-add!'/2, prolog(engine)).
builtin_implementation('undeclare-post-add!'/1, prolog(engine)).
builtin_implementation('space-atom-count'/1, prolog(kernel)).
builtin_implementation('has-declared-type'/2, prolog(kernel)).
builtin_implementation('space-admission-verdict'/2, prolog(kernel)).
builtin_implementation('space-contains'/2, prolog(kernel)).
builtin_implementation('<'/2, prolog(engine)).
builtin_implementation('>'/2, prolog(engine)).
builtin_implementation('=='/2, prolog(engine)).
builtin_implementation('!='/2, prolog(engine)).
builtin_implementation('='/2, prolog(engine)).
builtin_implementation('=?'/2, prolog(engine)).
builtin_implementation('<='/2, prolog(engine)).
builtin_implementation('>='/2, prolog(engine)).
builtin_implementation(and/2, prolog(engine)).
builtin_implementation(or/2, prolog(engine)).
builtin_implementation(xor/2, prolog(engine)).
builtin_implementation(implies/2, prolog(engine)).
builtin_implementation(not/1, prolog(engine)).
builtin_implementation(exp/1, prolog(engine)).
builtin_implementation('first-from-pair'/1, prolog(engine)).
builtin_implementation('second-from-pair'/1, prolog(engine)).
builtin_implementation('car-atom'/1, prolog(engine)).
builtin_implementation('cdr-atom'/1, prolog(engine)).
builtin_implementation('unique-atom'/1, prolog(engine)).
builtin_implementation('alpha-unique-atom'/1, prolog(engine)).
builtin_implementation(repr/1, prolog(engine)).
builtin_implementation(repra/1, prolog(engine)).
builtin_implementation(parse/1, prolog(engine)).
builtin_implementation('pretty-atom'/1, prolog(engine)).
builtin_implementation('println!'/1, prolog(engine)).
builtin_implementation('readln!'/0, prolog(engine)).
builtin_implementation('read-form!'/0, prolog(engine)).
builtin_implementation('parse-command'/1, prolog(engine)).
builtin_implementation(test/2, prolog(engine)).
builtin_implementation('test-no-answer'/1, prolog(engine)).
builtin_implementation(assert/1, prolog(engine)).
builtin_implementation(atom_concat/2, prolog(system)).
builtin_implementation(atom_chars/1, prolog(system)).
builtin_implementation(copy_term/1, prolog(system)).
builtin_implementation(term_hash/1, prolog(system)).
builtin_implementation(foldl/4, prolog(apply)).
builtin_implementation(foldl/3, prolog(apply)).
builtin_implementation(foldl/5, prolog(apply)).
builtin_implementation(foldl/6, prolog(apply)).
builtin_implementation(first/1, prolog(engine)).
builtin_implementation(last/1, prolog(lists)).
builtin_implementation(append/2, prolog(lists)).
builtin_implementation(append/1, prolog(lists)).
builtin_implementation(length/1, prolog(system)).
builtin_implementation('size-atom'/1, prolog(engine)).
builtin_implementation(sort/1, prolog(system)).
builtin_implementation(msort/1, prolog(system)).
builtin_implementation(member/1, prolog(lists)).
builtin_implementation(member/2, prolog(engine)).
builtin_implementation('is-member'/2, prolog(engine)).
builtin_implementation('is-alpha-member'/2, prolog(engine)).
builtin_implementation('exclude-item'/2, prolog(engine)).
builtin_implementation(list_to_set/1, prolog(lists)).
builtin_implementation(maplist/3, prolog(apply)).
builtin_implementation(maplist/4, prolog(apply)).
builtin_implementation(maplist/1, prolog(apply)).
builtin_implementation(maplist/2, prolog(apply)).
builtin_implementation(eval/1, prolog(engine)).
builtin_implementation(evalc/2, prolog(engine)).
builtin_implementation(reduce/2, prolog(translator)).
builtin_implementation(reduce/1, prolog(translator)).
builtin_implementation('import!'/2, prolog(engine)).
builtin_implementation('git-import!'/3, prolog(engine)).
builtin_implementation('git-import!'/4, prolog(engine)).
builtin_implementation('git-import!'/2, prolog(engine)).
builtin_implementation('git-import!'/1, prolog(engine)).
builtin_implementation('require-extension!'/1, prolog(engine)).
builtin_implementation('add-atom'/2, prolog(spaces)).
builtin_implementation('remove-atom'/2, prolog(spaces)).
builtin_implementation('subtract-atom'/2, prolog(spaces)).
builtin_implementation('add-atoms'/2, prolog(spaces)).
builtin_implementation('add-reduct'/2, prolog(spaces)).
builtin_implementation('add-reducts'/2, prolog(spaces)).
builtin_implementation('get-atoms'/1, prolog(spaces)).
builtin_implementation(match/3, prolog(spaces)).
builtin_implementation('is-var'/1, prolog(engine)).
builtin_implementation('is-ground'/1, prolog(engine)).
builtin_implementation('is-expr'/1, prolog(engine)).
builtin_implementation('is-space'/1, prolog(engine)).
builtin_implementation(decons/1, prolog(engine)).
builtin_implementation('decons-atom'/1, prolog(engine)).
builtin_implementation('if-decons-expr'/5, prolog(engine)).
builtin_implementation(noeval/1, prolog(engine)).
builtin_implementation('new-space'/0, prolog(engine)).
builtin_implementation('new-space'/2, prolog(engine)).
builtin_implementation('new-space'/1, prolog(engine)).
builtin_implementation('get-type'/1, prolog(engine)).
builtin_implementation('get-type-space'/2, prolog(engine)).
builtin_implementation('get-metatype'/1, prolog(engine)).
builtin_implementation('=alpha'/2, prolog(engine)).
builtin_implementation(sread/1, prolog(parser)).
builtin_implementation(cons/2, prolog(engine)).
builtin_implementation(reverse/1, prolog(lists)).
builtin_implementation('get-doc'/2, prolog(engine)).
builtin_implementation('get-doc'/1, prolog(engine)).
builtin_implementation('get-doc-space'/2, prolog(engine)).
builtin_implementation('get-doc-atom'/2, prolog(engine)).
builtin_implementation('get-doc-single-atom'/2, prolog(engine)).
builtin_implementation('get-doc-function'/3, prolog(engine)).
builtin_implementation('get-doc-params'/3, prolog(engine)).
builtin_implementation('help!'/1, prolog(engine)).
builtin_implementation(documented/0, prolog(engine)).
builtin_implementation('documented-space'/1, prolog(engine)).
builtin_implementation('defined-name'/0, prolog(engine)).
builtin_implementation(undocumented/0, prolog(engine)).
builtin_implementation('undocumented-space'/1, prolog(engine)).
builtin_implementation('#+'/2, prolog(engine)).
builtin_implementation('#-'/2, prolog(engine)).
builtin_implementation('#*'/2, prolog(engine)).
builtin_implementation('#div'/2, prolog(engine)).
builtin_implementation('#//'/2, prolog(engine)).
builtin_implementation('#mod'/2, prolog(engine)).
builtin_implementation('#min'/2, prolog(engine)).
builtin_implementation('#max'/2, prolog(engine)).
builtin_implementation('#<'/2, prolog(engine)).
builtin_implementation('#>'/2, prolog(engine)).
builtin_implementation('#='/2, prolog(engine)).
builtin_implementation('#\\='/2, prolog(engine)).
builtin_implementation('#=<'/2, prolog(engine)).
builtin_implementation('#>='/2, prolog(engine)).
builtin_implementation('union-atom'/2, prolog(engine)).
builtin_implementation('cons-atom'/2, prolog(engine)).
builtin_implementation('intersection-atom'/2, prolog(engine)).
builtin_implementation('subtraction-atom'/2, prolog(engine)).
builtin_implementation('index-atom'/2, prolog(engine)).
builtin_implementation('atom-subst'/3, prolog(engine)).
builtin_implementation(id/1, prolog(engine)).
builtin_implementation(function/1, prolog(engine)).
builtin_implementation('collapse-bind'/1, prolog(engine)).
builtin_implementation('superpose-bind'/1, prolog(engine)).
builtin_implementation('pow-math'/2, prolog(engine)).
builtin_implementation('sqrt-math'/1, prolog(engine)).
builtin_implementation('sort-atom'/1, prolog(engine)).
builtin_implementation('abs-math'/1, prolog(engine)).
builtin_implementation('log-math'/2, prolog(engine)).
builtin_implementation('exp-math'/1, prolog(engine)).
builtin_implementation('trunc-math'/1, prolog(engine)).
builtin_implementation('ceil-math'/1, prolog(engine)).
builtin_implementation('floor-math'/1, prolog(engine)).
builtin_implementation('round-math'/1, prolog(engine)).
builtin_implementation('sin-math'/1, prolog(engine)).
builtin_implementation('cos-math'/1, prolog(engine)).
builtin_implementation('tan-math'/1, prolog(engine)).
builtin_implementation('asin-math'/1, prolog(engine)).
builtin_implementation('random-int'/2, prolog(engine)).
builtin_implementation('random-int'/3, prolog(engine)).
builtin_implementation('random-float'/3, prolog(engine)).
builtin_implementation('random-float'/2, prolog(engine)).
builtin_implementation('acos-math'/1, prolog(engine)).
builtin_implementation('atan-math'/1, prolog(engine)).
builtin_implementation('isnan-math'/1, prolog(engine)).
builtin_implementation('isinf-math'/1, prolog(engine)).
builtin_implementation('min-atom'/1, prolog(engine)).
builtin_implementation('max-atom'/1, prolog(engine)).
builtin_implementation('bit-shift-left'/2, prolog(engine)).
builtin_implementation('bit-shift-right'/2, prolog(engine)).
builtin_implementation('bit-and'/2, prolog(engine)).
builtin_implementation('bit-or'/2, prolog(engine)).
builtin_implementation('bit-xor'/2, prolog(engine)).
builtin_implementation('bit-not'/1, prolog(engine)).
builtin_implementation('floor-div'/2, prolog(engine)).
builtin_implementation('foldl-atom'/3, prolog(engine)).
builtin_implementation('map-atom'/2, prolog(engine)).
builtin_implementation('filter-atom'/2, prolog(engine)).
builtin_implementation('current-time'/0, prolog(engine)).
builtin_implementation('format-time'/1, prolog(engine)).
builtin_implementation('context-space'/0, prolog(engine)).
builtin_implementation(library/1, prolog(engine)).
builtin_implementation(library/2, prolog(engine)).
builtin_implementation(exists_file/1, prolog(engine)).
builtin_implementation(exists_file/0, prolog(engine)).
builtin_implementation('format-args'/2, prolog(engine)).
builtin_implementation('sort-strings'/1, prolog(engine)).
builtin_implementation(include/1, prolog(engine)).
builtin_implementation(include/2, prolog(apply)).
builtin_implementation(sleep/1, prolog(engine)).
builtin_implementation('pragma!'/2, prolog(engine)).
builtin_implementation(metta/3, prolog(engine)).
builtin_implementation('metta-thread'/3, prolog(engine)).
builtin_implementation(import_prolog_function/1, prolog(engine)).
builtin_implementation(check_prolog_function_names/2, prolog(engine)).
builtin_implementation(import_prolog_functions/1, prolog(engine)).
builtin_implementation('Predicate'/1, prolog(engine)).
builtin_implementation(callPredicate/1, prolog(engine)).
builtin_implementation(assertaPredicate/1, prolog(engine)).
builtin_implementation(assertzPredicate/1, prolog(engine)).
builtin_implementation(retractPredicate/1, prolog(engine)).
builtin_implementation('add-translator-rule!'/1, prolog(translator_rules)).
builtin_implementation('add-translator-rule!'/2, prolog(translator_rules)).
builtin_implementation('remove-translator-rule!'/1, prolog(translator_rules)).
builtin_implementation('add-typing-rule!'/5, prolog(type_rules)).
builtin_implementation('remove-typing-rule!'/1, prolog(type_rules)).
builtin_implementation(argv/1, prolog(engine)).
builtin_implementation(register_metta_library_path/2, prolog(engine)).
builtin_implementation(dif/1, prolog(dif)).
builtin_implementation(dif/2, prolog(duals)).
builtin_implementation('residual-goals'/1, prolog(duals)).

register_declared_builtin_name(Name) :-
    (   builtin_fun(Name)
    ->  true
    ;   register_builtin_fun(Name)
    ).

:- forall(builtin_implementation(Name/_, _),
          register_declared_builtin_name(Name)).

register_builtin_implementation(Key, Implementation) :-
    (   builtin_implementation(Key, Implementation)
    ->  true
    ;   assertz(builtin_implementation(Key, Implementation))
    ).
%An EXTENSION's own builtins -- a host bridge's and a backend's alike --
%register here, from that extension's own seam:extension_builtin/2 declarations
%rather than from a list here that would name it. This was two directives over
%two seams, seam:host_builtin/1 and seam:backend_builtin/2, which differed only
%in whether they carried an effect class; the merged seam carries one for
%everybody. Every extension loads earlier in this file's own load order, so its
%facts exist by the time this directive runs, and an engine with none loaded
%registers nothing.
%
%The NAMES are the extension's: it declares them in the file that DEFINES them,
%so they exist exactly when the predicates behind them do. That conditionality
%used to be an argv test in this file, which meant the engine had to know both
%that MORK had builtins and what they were called.
%
%Registering a name whose predicate is absent records no arity, and
%incomplete_application_kind/3 reads "no arity" as "not applied far enough":
%every call to it then compiled to a partial application, so (mm2-exec &mork 1)
%answered (partial mm2-exec (&mork 1)) instead of running or failing. Declaring
%the names beside the predicates is what makes that unable to happen again.
:- forall(seam:extension_builtin(Name, _), register_builtin_fun(Name)).

%%%% Exact implementation facets and bidirectional coverage %%%%

%Prelude equations and extensions already own their names in their source
%declarations. Materialise only their dependent implementation facets after
%the final arity cleanup, then validate the complete boot image. Refresh first
%so a repeated snapshot observes a replaced prelude or extension rather than
%retaining its earlier hooks.
finalize_builtin_implementations :-
    retractall(builtin_implementation(_, prelude(_))),
    retractall(builtin_implementation(_, extension(_))),
    forall(prelude_builtin_implementation(Key, Implementation),
           register_builtin_implementation(Key, Implementation)),
    forall(extension_builtin_implementation(Key, Implementation),
           register_builtin_implementation(Key, Implementation)).

prelude_builtin_implementation(Name/Arity, prelude(equation)) :-
    prelude_owned(Name),
    prelude_equation(Name, ['=', [Name|Arguments], _]),
    length(Arguments, Arity).

extension_builtin_implementation(Name/Arity, extension(ModuleRef)) :-
    seam:extension_builtin(Name, _),
    arity(Name, PrologArity),
    PrologArity > 0,
    Arity is PrologArity - 1,
    builtin_callable_module(Name, PrologArity, Module),
    builtin_module_reference(Module, ModuleRef).

builtin_callable_module(Name, Arity, Module) :-
    metta_engine_module(Engine),
    current_predicate(Engine:Name/Arity),
    functor(Head, Name, Arity),
    predicate_property(Engine:Head, implementation_module(Module)).

builtin_module_reference(Module, engine) :-
    metta_engine_module(Engine),
    Module == Engine, !.
builtin_module_reference(Module, self) :-
    metta_self_module(Self),
    Module == Self, !.
builtin_module_reference(Module, Module).

builtin_reference_module(engine, Module) :- !, metta_engine_module(Module).
builtin_reference_module(self, Module) :- !, metta_self_module(Module).
builtin_reference_module(Module, Module).

validate_builtin_registry :-
    validate_builtin_implementation_schema,
    validate_builtin_implementation_unique,
    validate_builtin_implementation_hooks,
    validate_builtin_exemptions,
    validate_builtin_registration_coverage,
    validate_builtin_implementation_coverage.

validate_builtin_implementation_schema :-
    forall(builtin_implementation(Key, Implementation),
           (   valid_builtin_implementation(Key, Implementation)
           ->  true
           ;   throw(error(invalid_builtin_implementation(Key, Implementation),
                           builtin_registry))
           )).

valid_builtin_implementation(Name/Arity, Implementation) :-
    atom(Name),
    integer(Arity),
    Arity >= 0,
    valid_builtin_implementation_descriptor(Implementation).

valid_builtin_implementation_descriptor(prolog(ModuleRef)) :-
    atom(ModuleRef).
valid_builtin_implementation_descriptor(prelude(equation)).
valid_builtin_implementation_descriptor(extension(ModuleRef)) :-
    atom(ModuleRef).
valid_builtin_implementation_descriptor(compiler(ModuleRef, Hook, Arity)) :-
    atom(ModuleRef),
    atom(Hook),
    integer(Arity),
    Arity >= 1.

validate_builtin_implementation_unique :-
    findall(Key, builtin_implementation(Key, _), Keys),
    msort(Keys, Sorted),
    (   first_duplicate(Sorted, Duplicate)
    ->  throw(error(duplicate_builtin_implementation_key(Duplicate),
                    builtin_registry))
    ;   true
    ).

first_duplicate([Key, Key|_], Key) :- !.
first_duplicate([_|Keys], Key) :- first_duplicate(Keys, Key).

validate_builtin_implementation_hooks :-
    forall(builtin_implementation(Key, Implementation),
           (   builtin_implementation_hook_exists(Key, Implementation)
           ->  true
           ;   throw(error(undefined_builtin_implementation_hook(
                               Key, Implementation),
                           builtin_registry))
           )).

builtin_implementation_hook_exists(Name/Arity, Implementation) :-
    builtin_callable_descriptor(Implementation, ModuleRef), !,
    PrologArity is Arity + 1,
    builtin_reference_module(ModuleRef, Module),
    current_predicate(Module:Name/PrologArity),
    functor(Head, Name, PrologArity),
    predicate_property(Module:Head, implementation_module(Actual)),
    Actual == Module.
builtin_implementation_hook_exists(Name/Arity, prelude(equation)) :- !,
    prelude_owned(Name),
    prelude_equation(Name, ['=', [Name|Arguments], _]),
    length(Arguments, Arity), !.
builtin_implementation_hook_exists(
        Name/_, compiler(ModuleRef, Hook, HookArity)) :-
    builtin_reference_module(ModuleRef, Module),
    functor(Head, Hook, HookArity),
    arg(1, Head, Name),
    current_predicate(Module:Hook/HookArity),
    once(call(Module:Head)).

builtin_callable_descriptor(prolog(ModuleRef), ModuleRef).
builtin_callable_descriptor(extension(ModuleRef), ModuleRef).

%The forward inventory deliberately ignores exemptions. It is the exact list
%to report before policy is applied: a name with no facet, or a callable arity
%whose exact key has no facet.
builtin_registration_coverage_inventory(Inventory) :-
    findall(Gap, builtin_registration_gap(Gap), Gaps),
    sort(Gaps, Inventory).

builtin_registration_gap(Name) :-
    builtin_fun(Name),
    \+ builtin_implementation(Name/_, _).
builtin_registration_gap(Name/Arity) :-
    builtin_fun(Name),
    arity(Name, PrologArity),
    PrologArity > 0,
    Arity is PrologArity - 1,
    \+ builtin_implementation(Name/Arity, _).

validate_builtin_registration_coverage :-
    forall(builtin_registration_gap(Gap),
           (   registration_gap_exempted(Gap)
           ->  true
           ;   throw(error(unregistered_builtin_spec(Gap), builtin_registry))
           )).

registration_gap_exempted(Gap) :-
    registration_gap_name(Gap, Name),
    builtin_registration_exemption(Name, _).

registration_gap_name(Name/_, Name) :- !.
registration_gap_name(Name, Name).

%The reverse inventory combines declared implementation facets with actual
%project predicates named by an independent surface. The surface union is what
%makes the scan useful: a predicate mentioned by typing, grounded-token,
%effect, semantic-operation, extension, or special-form metadata cannot hide
%merely because nobody added it to builtin_fun/1.
builtin_implementation_coverage_inventory(Inventory) :-
    findall(Gap, builtin_implementation_gap(Gap), Gaps),
    sort(Gaps, Inventory).

builtin_implementation_gap(description(Name/Arity, Implementation)) :-
    builtin_implementation(Name/Arity, Implementation),
    (   \+ builtin_fun(Name)
    ;   builtin_callable_descriptor(Implementation, _),
        PrologArity is Arity + 1,
        \+ arity(Name, PrologArity)
    ).
builtin_implementation_gap(predicate(Predicate)) :-
    builtin_surface_predicate(Predicate, _),
    \+ builtin_predicate_described(Predicate).

validate_builtin_implementation_coverage :-
    forall(builtin_implementation_gap(Gap),
           (   implementation_gap_exempted(Gap)
           ->  true
           ;   implementation_gap_subject(Gap, Subject),
               throw(error(unregistered_builtin_implementation(Subject),
                           builtin_registry))
           )).

implementation_gap_exempted(predicate(Predicate)) :-
    seam:builtin_implementation_exemption(Subject, _),
    builtin_exemption_predicate(Subject, Predicate).

implementation_gap_subject(description(Key, _), Key).
implementation_gap_subject(predicate(Predicate), Predicate).

builtin_predicate_described(Module:Name/PrologArity) :-
    Arity is PrologArity - 1,
    builtin_implementation(Name/Arity, Implementation),
    builtin_callable_descriptor(Implementation, ModuleRef),
    builtin_reference_module(ModuleRef, DescribedModule),
    DescribedModule == Module.

%Both modes are answered by the shape each is asked in. The scan enumerates
%the surface union once and walks it; a bound predicate, which is how the
%exemption liveness check asks, tests its own name against the seven sources
%directly. Synthesising the whole union to check one name cost 1,584
%inferences of setof plus a 385-element member/2 walk before the 81 of work
%each ask actually needs, which was 9,214 of a boot over five exemptions
%[tested: builtin_facets:a_bound_surface_question_does_not_synthesise_the_whole_union;
%commit=90aa1e67c6d1cda45e27dbaa565f2c537f70ad40].
builtin_surface_predicate(Module:Name/Arity, File) :-
    builtin_project_implementation_prefixes(Prefixes),
    builtin_surface_predicate_name(Name),
    current_predicate(Module:Name/Arity),
    Arity > 0,
    functor(Head, Name, Arity),
    predicate_property(Module:Head, implementation_module(Module)),
    source_file(Module:Head, File),
    builtin_project_implementation_file(Prefixes, File).

builtin_surface_predicate_name(Name) :-
    (   nonvar(Name)
    ->  once(( builtin_surface_name(Name), atom(Name) ))
    ;   setof(SurfaceName,
              ( builtin_surface_name(SurfaceName), atom(SurfaceName) ),
              Names),
        member(Name, Names)
    ).

builtin_surface_name(Name) :- metta_grounded_token(Name).
builtin_surface_name(Name) :- metta_effect_prolog_primitive(Name).
builtin_surface_name(Name) :- metta_builtin_effect_override(Name, _).
builtin_surface_name(Name) :- metta_semantic_effect(Name, _).
builtin_surface_name(Name) :- seam:builtin_type_declaration(Name, _).
builtin_surface_name(Name) :- seam:extension_builtin(Name, _).
%translator:embedded_operation_head/1 is NOT read here. It is the translator's
%own classification of which heads may hold a redex, is not on the module's
%export list, and the engine reaching it is what the layering contract refuses
%[tested: engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named].
%Nothing is lost while every one of its 47 heads is already named by one of
%the seven sources above, which the suite asserts rather than assuming
%[tested: builtin_facets:the_translators_embedded_operations_add_no_surface_name].
builtin_surface_name(Name) :- translator:metta_special_form_head(Name).

%The three prefixes are the same three atoms for every candidate, so they are
%built once per scan rather than once per candidate. Rebuilding them in place
%charged builtin_project_root/1 and three directory_file_path/3 and
%atom_concat/3 pairs at each of the 545 candidates a boot walks, against a
%member/2 over a list already in hand. That hoist and the mode fix above took
%validate_builtin_registry from 35,275 inferences to 19,796 and the boot case
%from 281,411 to 265,924, with the six other benchmark cases identical
%[measured 2026-09-06; command=swipl -g "metta_bench:bench_run(boot)" -t halt
%engine/bench.pl; fixture=three samples per arm, .qlf purged and warmed;
%commit=90aa1e67c6d1cda45e27dbaa565f2c537f70ad40].
builtin_project_implementation_prefixes(Prefixes) :-
    builtin_project_root(Root),
    findall(Prefix,
            % policy-inventory-exempt: mechanism-internal; reason=the three directories are this repository's own layout, the roots a shipped predicate can be defined under, not a policy a program chooses; evidence=engine/metta/registration.pl:builtin_project_root/1
            ( member(Directory, [engine, lib, extensions]),
              directory_file_path(Root, Directory, ProjectDirectory),
              atom_concat(ProjectDirectory, '/', Prefix) ),
            Prefixes).

builtin_project_implementation_file(Prefixes, File) :-
    member(Prefix, Prefixes),
    sub_atom(File, 0, _, _, Prefix), !.

builtin_project_root(Root) :-
    metta_engine_module(Engine),
    source_file(Engine:register_declared_builtin_name(_), RegistrationFile),
    file_directory_name(RegistrationFile, MettaDirectory),
    file_directory_name(MettaDirectory, EngineDirectory),
    file_directory_name(EngineDirectory, Root).

%%%% Reason-bearing coverage exemptions %%%%

validate_builtin_exemptions :-
    validate_builtin_exemption_schema,
    validate_builtin_exemption_unique,
    validate_builtin_exemption_liveness.

validate_builtin_exemption_schema :-
    forall(builtin_registration_exemption(Name, Reason),
           (   atom(Name), valid_builtin_exemption_reason(Reason)
           ->  true
           ;   throw(error(invalid_builtin_registration_exemption(Name, Reason),
                           builtin_registry))
           )),
    forall(seam:builtin_implementation_exemption(Subject, Reason),
           (   valid_builtin_implementation_exemption_subject(Subject),
               valid_builtin_exemption_reason(Reason)
           ->  true
           ;   throw(error(invalid_builtin_implementation_exemption(
                               Subject, Reason),
                           builtin_registry))
           )).

valid_builtin_exemption_reason(Reason) :-
    atom(Reason),
    Reason \== ''.

valid_builtin_implementation_exemption_subject(Subject) :-
    builtin_exemption_predicate(Subject, Module:Name/Arity),
    atom(Module),
    atom(Name),
    integer(Arity),
    Arity > 0.

builtin_exemption_predicate(ModuleRef:(Name/Arity), Module:Name/Arity) :- !,
    builtin_reference_module(ModuleRef, Module).
builtin_exemption_predicate(Name/Arity, Module:Name/Arity) :-
    metta_engine_module(Module).

validate_builtin_exemption_unique :-
    findall(Name, builtin_registration_exemption(Name, _), Registration),
    msort(Registration, SortedRegistration),
    (   first_duplicate(SortedRegistration, DuplicateRegistration)
    ->  throw(error(duplicate_builtin_registration_exemption(
                        DuplicateRegistration),
                    builtin_registry))
    ;   true
    ),
    findall(Predicate,
            ( seam:builtin_implementation_exemption(Subject, _),
              builtin_exemption_predicate(Subject, Predicate) ),
            Implementations),
    msort(Implementations, SortedImplementations),
    (   first_duplicate(SortedImplementations, DuplicateImplementation)
    ->  throw(error(duplicate_builtin_implementation_exemption(
                        DuplicateImplementation),
                    builtin_registry))
    ;   true
    ).

validate_builtin_exemption_liveness :-
    forall(builtin_registration_exemption(Name, _),
           (   builtin_registration_gap(Gap),
               registration_gap_name(Gap, Name)
           ->  true
           ;   throw(error(stale_builtin_registration_exemption(Name),
                           builtin_registry))
           )),
    forall(seam:builtin_implementation_exemption(Subject, _),
           (   builtin_exemption_predicate(Subject, Predicate),
               builtin_implementation_gap(predicate(Predicate))
           ->  true
           ;   throw(error(stale_builtin_implementation_exemption(Subject),
                           builtin_registry))
           )).
