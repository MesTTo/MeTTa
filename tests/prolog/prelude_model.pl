% Purpose: share executable prelude cases and complete observations between
%   the prelude specification and shipped-library meaning gates.
% Assumes: the caller boots engine/metta.pl and runs from tests/prolog.
% Guarantees: answer comparison preserves multiplicity and ignores variable
%   renaming; output and raised balls remain observable
%   [tested: prelude_spec_selftest; commit=WORKTREE].
% Owns resources: each observation erases its assertion-message capture flag.
% Guarded by: the capture flag and message hook are local to the calling thread.

:- thread_local prelude_spec_capturing/0.
:- multifile user:thread_message_hook/3.

% Capture the assertion's report as part of the observation, before SWI counts
% it as an uncaught gate error. The raised ball is still caught below.
user:thread_message_hook(error(metta_assertion_failed(_,_,_),_), error, Lines) :-
    prelude_spec_capturing,
    print_message_lines(current_output, '', Lines).

%The helpers are file-level rather than unit-level because both units use
%them: a plunit unit is a module of its own, so a predicate defined inside
%begin_tests/end_tests is not the one the next unit can call.

prelude_spec_fixture('../data/prelude-spec.metta').

prelude_spec_forms(Forms) :-
    prelude_spec_fixture(Path),
    read_file_to_string(Path, Text, [encoding(utf8)]),
    parse_metta_source(Text, Forms).

%One case is one call, written as a program writes it. Every one is a READ, so
%the two sides run against the same store and neither disturbs the other.
prelude_spec_case('if-equal', "(if-equal 1 1 yes no)").
prelude_spec_case(only, "(only (a b) a)").
prelude_spec_case(only, "(only () a)").
prelude_spec_case(only, "(only (a a) a)").
prelude_spec_case(except, "(except (a b) a)").
prelude_spec_case(except, "(except (a b) c)").
prelude_spec_case(except, "(except () a)").
prelude_spec_case(prefix, "(prefix str- split)").
prelude_spec_case(prefix, "(let $map (prefix str-) ($map split))").
prelude_spec_case(rename, "(rename ((a b) (a c)) a)").
prelude_spec_case(rename, "(rename ((a b)) c)").
prelude_spec_case(rename, "(rename () c)").
prelude_spec_case(qualified, "(let $map (qualified lib_string) ($map split))").
prelude_spec_case('if-equal', "(if-equal 1 2 yes no)").
prelude_spec_case('if-equal', "(if-equal (f $x $x) (f $y $y) yes no)").
prelude_spec_case('if-equal', "(if-equal (f $x $x) (f $y $z) yes no)").
prelude_spec_case('if-equal', "(if-equal (+ 1 1) 2 yes no)").
prelude_spec_case('if-equal', "(collapse (if-equal 1 1 (superpose (a b)) no))").
prelude_spec_case('if-equal', "(if-equal (Error a b) (Error a b) yes no)").
prelude_spec_case('if-equal', "(if-equal () () yes no)").
prelude_spec_case('if-equal2', "(if-equal2 a b yes no)").
prelude_spec_case('if-equal2', "(if-equal2 (f $x $x) (f $y $y) yes no)").
prelude_spec_case('noreduce-eq', "(noreduce-eq (+ 1 1) 2)").
prelude_spec_case('noreduce-eq', "(noreduce-eq (+ 1 1) (+ 1 1))").
prelude_spec_case('noreduce-eq', "(noreduce-eq (f $x) (f $y))").
prelude_spec_case('noreduce-eq', "(noreduce-eq () ())").

prelude_spec_case(assertEqual, "(assertEqual (+ 1 1) 2)").
prelude_spec_case(assertEqual, "(assertEqual 1 2)").
prelude_spec_case(assertEqual, "(assertEqual (superpose (1 2)) (superpose (1 2)))").
prelude_spec_case(assertEqual, "(assertEqual (superpose (1 2)) (superpose (2 1)))").
prelude_spec_case(assertEqual, "(assertEqual (superpose (a a b)) (superpose (a b b)))").
prelude_spec_case(assertEqual, "(assertEqual (superpose ()) (superpose ()))").
prelude_spec_case(assertAlphaEqual, "(assertAlphaEqual (f $x $x) (f $y $y))").
prelude_spec_case(assertAlphaEqual, "(assertAlphaEqual 1 2)").
prelude_spec_case(assertEqualToResult, "(assertEqualToResult (superpose (1 2)) (1 2))").
prelude_spec_case(assertEqualToResult, "(assertEqualToResult (+ 1 1) ((+ 1 1)))").
prelude_spec_case(assertEqualToResult, "(assertEqualToResult (superpose (1 2)) (1 2 3))").
prelude_spec_case(assertEqualToResult, "(assertEqualToResult (superpose (a a b)) (a b b))").
prelude_spec_case(assertEqualToResult, "(assertEqualToResult (superpose ()) ())").
prelude_spec_case(assertAlphaEqualToResult,
                  "(assertAlphaEqualToResult (noeval (f $a)) ((f $b)))").
prelude_spec_case(assertAlphaEqualToResult,
                  "(assertAlphaEqualToResult (noeval (f $a)) ((g $b)))").
prelude_spec_case(assertIncludes, "(assertIncludes (superpose (1 2 3)) (2 1))").
prelude_spec_case(assertIncludes, "(assertIncludes (superpose (1 2)) (7))").
prelude_spec_case(assertEqualMsg, "(assertEqualMsg (+ 1 1) 2 ignored)").
prelude_spec_case(assertEqualMsg, "(assertEqualMsg (+ 1 2) 4 \"sums differ\")").
prelude_spec_case(assertAlphaEqualMsg, "(assertAlphaEqualMsg (f $x $x) (f $y $y) m)").
prelude_spec_case(assertEqualToResultMsg,
                  "(assertEqualToResultMsg (superpose (1 2)) (1 2) ignored)").
prelude_spec_case(assertEqualToResultMsg,
                  "(assertEqualToResultMsg (+ 1 2) (4) \"not the expected result\")").
prelude_spec_case(assertAlphaEqualToResultMsg,
                  "(assertAlphaEqualToResultMsg (noeval (f $a)) ((f $b)) ignored)").

prelude_spec_case('if-error', "(if-error (Error a b) yes no)").
prelude_spec_case('if-error', "(if-error 42 yes no)").
prelude_spec_case('if-error', "(if-error () yes no)").
prelude_spec_case('if-error', "(if-error (foo) yes no)").
prelude_spec_case('if-error', "(if-error Error yes no)").
%A nondeterministic argument: if-error is undeclared, so the operand evaluates
%first and the form runs once per answer.
prelude_spec_case('if-error',
                  "(collapse (if-error (superpose ((Error a b) 42)) yes no))").
%An error INSIDE an argument, which the operand's own evaluation produces.
prelude_spec_case('if-error', "(if-error (/ 1 0) yes no)").
prelude_spec_case(throw, "(throw plain-reason)").
prelude_spec_case(throw, "(throw (Error inner reason))").
prelude_spec_case('return-on-error', "(return-on-error 42 fallback)").
prelude_spec_case('return-on-error', "(return-on-error (Error a b) fallback)").
prelude_spec_case('return-on-error', "(collapse (return-on-error Empty fallback))").
prelude_spec_case('match-type-or', "(match-type-or unchanged A B)").
prelude_spec_case('type-cast', "(type-cast zz SomeType &self)").

prelude_spec_case('for-each-in-atom', "(for-each-in-atom (1 2 3) repr)").
prelude_spec_case('for-each-in-atom', "(for-each-in-atom () repr)").
prelude_spec_case('for-each-in-atom', "(for-each-in-atom ((+ 1 2)) repr)").
prelude_spec_case(atomically, "(atomically (+ 1 2))").
prelude_spec_case(atomically, "(collapse (atomically (superpose (1 2))))").
prelude_spec_case(atomically, "(collapse (atomically (superpose ())))").
prelude_spec_case(unquote, "(unquote (quote (+ 2 3)))").
prelude_spec_case(unquote, "(repr (unquote 42))").
prelude_spec_case(unquote, "(collapse (unquote (quote (superpose (1 2)))))").
prelude_spec_case(unquote, "(repr (unquote (quote (unquote $a))))").
prelude_spec_case(interpret, "(interpret (+ 1 2) %Undefined% &self)").
prelude_spec_case(interpret, "(interpret a Symbol &self)").
prelude_spec_case(interpret, "(collapse (interpret (superpose (1 2)) %Undefined% &self))").

prelude_spec_case('is-function', "(is-function (-> Number Number))").
prelude_spec_case('is-function', "(is-function Number)").
prelude_spec_case('is-function', "(is-function ())").
prelude_spec_case('is-function', "(is-function (->))").
prelude_spec_case('is-function', "(is-function ($x Number))").
prelude_spec_case('match-types', "(match-types A A t e)").
prelude_spec_case('match-types', "(match-types A B t e)").
prelude_spec_case('match-types', "(match-types %Undefined% B t e)").
prelude_spec_case('match-types', "(match-types B Atom t e)").
prelude_spec_case('match-types', "(match-types Atom B t e)").
prelude_spec_case('match-types', "(match-types A %Undefined% t e)").
prelude_spec_case('match-types', "(match-types (List $x) (List Number) t e)").
%Equality must leave the variable unbound and choose the unequal branch.
prelude_spec_case('match-types', "(match-types (List $x) (List Number) $x e)").
prelude_spec_case('match-types', "(collapse (match-types A A (superpose (1 2)) e))").
prelude_spec_case('match-type-or', "(match-type-or False A A)").
prelude_spec_case('match-type-or', "(match-type-or False A B)").
prelude_spec_case('match-type-or', "(match-type-or True A B)").
prelude_spec_case('type-cast-holds', "(type-cast-holds 2 Number &self)").
prelude_spec_case('type-cast-holds', "(type-cast-holds a Symbol &self)").
prelude_spec_case('type-cast-holds', "(type-cast-holds zz SomeType &self)").
prelude_spec_case('type-cast', "(type-cast a Symbol &self)").
prelude_spec_case('type-cast', "(type-cast zz SomeType &self)").
prelude_spec_case('type-cast', "(type-cast (+ 1 1) Number &self)").
prelude_spec_case('type-cast', "(type-cast 2 Number &self)").

%A DERIVED form's meaning is the term its call EXPANDS TO, not the answers a
%call to it as an ordinary function would produce: the engine rewrites the
%call site while it compiles and the expansion is what runs. So these are
%compared as expansions, and separately by running the spec's expansion
%against the engine's rewritten answers.
prelude_spec_expansion_case('and-then', "(and-then True yes)").
prelude_spec_expansion_case('and-then', "(and-then False yes)").
prelude_spec_expansion_case('or-else', "(or-else False fallback)").
prelude_spec_expansion_case('or-else', "(or-else True fallback)").
prelude_spec_expansion_case('trace!', "(trace! traced 7)").
prelude_spec_expansion_case(unique, "(unique (superpose (1 2 1)))").
prelude_spec_expansion_case(unique, "(unique (superpose ()))").
prelude_spec_expansion_case('alpha-unique',
                            "(alpha-unique (superpose ((f $x) (f $y) (g $z))))").
prelude_spec_expansion_case(union, "(union (superpose (1 2)) (superpose (2 3)))").
prelude_spec_expansion_case(union, "(union (superpose ()) (superpose (2 3)))").
prelude_spec_expansion_case(union, "(union 1 2)").
prelude_spec_expansion_case(intersection,
                            "(intersection (superpose (1 2)) (superpose (2 3)))").
prelude_spec_expansion_case(intersection, "(intersection 1 2)").
prelude_spec_expansion_case(subtraction,
                            "(subtraction (superpose (1 2)) (superpose (2 3)))").
prelude_spec_expansion_case(subtraction, "(subtraction 1 2)").

%What a call did, all of it: the answers it produced, whatever it printed, and
%the ball it threw. trace! prints and the assert family raises, so a
%comparison over answers alone would call two of these families equal without
%looking at what they are for.
%
%The specializer's own report is dropped from the captured output. It names a
%SPACE's higher-order definitions, which the spec space adds, so it reports a
%difference between the two spaces rather
%than between the two implementations [source: engine/specializer.pl:471].
prelude_spec_observed(Space, Text, Observation) :-
    sread(Text, Term),
    prelude_spec_observed_term(Space, Term, Observation).

prelude_spec_observed_term(Space, Term, observation(Answers, Output, Outcome)) :-
    setup_call_cleanup(asserta(prelude_spec_capturing, Ref), with_output_to(
        string(Raw),
        (   catch(findall(Answer, evalc(Term, Space, Answer), Produced),
                  Ball, true)
        ->  true
        ;   Produced = '$failed'
        )), erase(Ref)),
    prelude_spec_reportable_output(Raw, Output),
    (   nonvar(Ball)
    ->  Outcome = raised(Ball), Answers = []
    ;   Outcome = answered, Answers = Produced
    ).

prelude_spec_reportable_output(Raw, Output) :-
    split_string(Raw, "\n", "", Lines),
    exclude([Line]>>sub_string(Line, 0, _, _, "Not specialized "), Lines, Kept),
    atomics_to_string(Kept, "\n", Output).

%The expansions the engine's own body offers for a written call, in order: the
%same predicate, at the same arity, the translator calls to rewrite a call
%site [source: engine/translator/lowering.pl, apply_translator_rule_dl/7].
prelude_spec_engine_expansions(Text, Expansions) :-
    sread(Text, [Head|Arguments]),
    append(Arguments, [Expansion], Full),
    Goal =.. [Head|Full],
    findall(Expansion, call(prelude:Goal), Expansions).

%Multiset equality up to variable renaming. msort/2 would order two answers by
%the age of the variables in them, which is not a property either side
%controls, so each answer is consumed against a variant of itself instead.
prelude_spec_bag_equal([], []).
prelude_spec_bag_equal([Answer|Answers], Others) :-
    prelude_spec_select_variant(Answer, Others, Rest),
    prelude_spec_bag_equal(Answers, Rest).

prelude_spec_select_variant(Answer, [Other|Others], Others) :-
    Answer =@= Other, !.
prelude_spec_select_variant(Answer, [Other|Others], [Other|Rest]) :-
    prelude_spec_select_variant(Answer, Others, Rest).

prelude_spec_agrees(observation(EngineAnswers, Output, Outcome),
                    observation(SpecAnswers, Output, SpecOutcome)) :-
    Outcome =@= SpecOutcome,
    prelude_spec_bag_equal(EngineAnswers, SpecAnswers).

%The spec space holds the fixture's declarations and equations under their own
%names and NOTHING else. The runnables are skipped on purpose: a translator
%registration is global, so running the fixture's eight would point the
%engine's own compile-time rewriting at this space's equations.
prelude_spec_install(Space) :-
    prelude_spec_forms(Forms),
    forall(( member(Form, Forms),
             parsed_form_parts(Form, expression, _, Declaration),
             Declaration = [':', Name, _],
             atom(Name) ),
           metta_add_atom(Space, Declaration, _)),
    forall(( member(Form, Forms),
             parsed_form_parts(Form, function, _, Equation),
             Equation = [=, [Name|_], _],
             atom(Name) ),
           metta_add_atom(Space, Equation, _)).
