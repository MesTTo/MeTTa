% Purpose: hold the Prolog prelude to its MeTTa spec. tests/data/prelude-spec.metta
%   is the executable definition of the vocabulary engine/prelude.pl
%   implements; this suite loads the spec's declarations and equations into a
%   scratch space and proves that the engine and the spec answer the same bag
%   for the same call, head by head, over the cases the other suites exercise
%   and over adversarial ones.
% Assumes:
%   - the fixture is read from tests/prolog, which is where check.sh and
%     engine/test.sh run every suite from.
%   - the ENGINE side is measured BEFORE the scratch space exists. Defining a
%     derived form's name in any space withdraws the engine's translator
%     registration for it, by design, so a spec space that already held those
%     equations would be compared against an engine that no longer expands
%     them [source: engine/metta/registration.pl, register_fun_in/2].
% Guarantees:
%   - every ordinary head answers what its spec equation answers: the same
%     answer bag, the same printed output and the same raised ball
%     [tested: prelude_spec:every_head_agrees_with_its_spec_equation].
%   - every DERIVED head expands to what its spec equation expands to, and
%     that expansion evaluates to what the engine's rewritten call site
%     answers [tested: prelude_spec:every_head_agrees_with_its_spec_equation,
%     prelude_spec:a_spec_expansion_evaluates_to_the_engines_answers].
%   - the engine's shipped register and the fixture are the same 36 equations,
%     40 declarations, 36 documents, 4 cost claims and 8 rule registrations
%     [tested: prelude_spec:the_shipped_register_is_the_spec_fixture].
%   - the comparison can fail: a planted wrong equation is reported
%     [tested: prelude_spec_selftest:a_planted_divergence_is_reported].
% Fails when: a case writes to a space. Every case here is a read, so the two
%   sides can run in either order against the same store.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

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
%The binding the match makes flows into the branch, which is what makes this
%unification rather than equality.
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
%SPACE's higher-order definitions, and the spec space has thirty-six of them
%where &self has none, so it is a difference between the two spaces rather
%than between the two implementations [source: engine/specializer.pl:471].
prelude_spec_observed(Space, Text, observation(Answers, Output, Outcome)) :-
    sread(Text, Term),
    with_output_to(
        string(Raw),
        (   catch(findall(Answer, evalc(Term, Space, Answer), Produced),
                  Ball, true)
        ->  true
        ;   Produced = '$failed'
        )),
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

:- begin_tests(prelude_spec).

% -- the register and the fixture are one text ------------------------------

test(the_shipped_register_is_the_spec_fixture) :-
    prelude_spec_forms(Forms),
    findall(Name-Term,
            ( member(Form, Forms),
              parsed_form_parts(Form, function, _, Term),
              Term = [=, [Name|_], _] ),
            FromFixture),
    findall(Name-Term, prelude_shipped_equation(Name, Term), FromRegister),
    assertion(length(FromFixture, 36)),
    assertion(FromFixture =@= FromRegister).

test(the_declarations_are_the_spec_fixtures) :-
    prelude_spec_forms(Forms),
    findall(Name-Type,
            ( member(Form, Forms),
              parsed_form_parts(Form, expression, _, [':', Name, Type]),
              atom(Name) ),
            FromFixture),
    findall(Name-Type, prelude_declaration(Name, Type), FromRegister),
    assertion(length(FromFixture, 40)),
    assertion(FromFixture =@= FromRegister).

test(the_documents_are_the_spec_fixtures) :-
    prelude_spec_forms(Forms),
    findall(Name-Term,
            ( member(Form, Forms),
              parsed_form_parts(Form, expression, _, Term),
              Term = ['@doc', Name|_],
              atom(Name) ),
            FromFixture),
    findall(Name-Term, prelude_document(Name, Term), FromRegister),
    assertion(FromFixture =@= FromRegister).

test(the_cost_claims_are_the_spec_fixtures) :-
    prelude_spec_forms(Forms),
    findall([cost, Witness|Fields],
            ( member(Form, Forms),
              parsed_form_parts(Form, expression, _, [cost, Witness|Fields]) ),
            FromFixture),
    findall(Row, prelude_cost_claim(Row), FromRegister),
    assertion(FromFixture =@= FromRegister).

%The registrations are runnables in the fixture and rows in the register, so
%the two are compared by NAME: what the fixture says is that these eight names
%ship as compile-time rewrites, and what the register carries beside each name
%is the declaration the registration makes.
test(the_rule_registrations_are_the_spec_fixtures) :-
    prelude_spec_forms(Forms),
    findall(Name,
            ( member(Form, Forms),
              parsed_form_parts(Form, runnable, _, Runnable),
              Runnable = ['add-translator-rule!', Name|_] ),
            FromFixture),
    findall(Name, prelude_rule_registration(Name, _), FromRegister),
    assertion(length(FromFixture, 8)),
    assertion(FromFixture == FromRegister).

% -- the differential -------------------------------------------------------

%THE differential. Both sides are collected before either is judged, and the
%engine's side is collected FIRST, before the spec space exists: defining one
%of the eight derived names withdraws the engine's translator registration for
%it, so an engine measured after that would be a different engine.
test(every_head_agrees_with_its_spec_equation,
     [ setup(metta_host_set_silent(true)),
       cleanup(( catch(metta_release_space('&prelude-spec'), _, true),
                 metta_host_set_silent(false),
                 install_engine_prelude )) ]) :-
    findall(Head-Text-Observed,
            ( prelude_spec_case(Head, Text),
              prelude_spec_observed('&self', Text, Observed) ),
            Engine),
    findall(Head-Text-Expansions,
            ( prelude_spec_expansion_case(Head, Text),
              prelude_spec_engine_expansions(Text, Expansions) ),
            EngineExpansions),
    prelude_spec_install('&prelude-spec'),
    findall(Head-Text-Observed,
            ( prelude_spec_case(Head, Text),
              prelude_spec_observed('&prelude-spec', Text, Observed) ),
            Spec),
    findall(Head-Text-Answers,
            ( prelude_spec_expansion_case(Head, Text),
              prelude_spec_observed('&prelude-spec', Text,
                                    observation(Answers, _, answered)) ),
            SpecExpansions),
    findall(Head-Text-EngineSide-SpecSide,
            ( nth0(Index, Engine, Head-Text-EngineSide),
              nth0(Index, Spec, _-_-SpecSide),
              \+ prelude_spec_agrees(EngineSide, SpecSide) ),
            Divergences),
    assertion(Divergences == []),
    findall(Head-Text-Expansions-Answers,
            ( nth0(Index, EngineExpansions, Head-Text-Expansions),
              nth0(Index, SpecExpansions, _-_-Answers),
              \+ prelude_spec_bag_equal(Expansions, Answers) ),
            ExpansionDivergences),
    assertion(ExpansionDivergences == []).

%The other direction for a derived form: run the SPEC's expansion and the
%engine's rewritten call site has to answer the same. This is what makes the
%expansion comparison above about meaning rather than about syntax.
test(a_spec_expansion_evaluates_to_the_engines_answers,
     [ setup(metta_host_set_silent(true)),
       cleanup(( catch(metta_release_space('&prelude-expansion'), _, true),
                 metta_host_set_silent(false),
                 install_engine_prelude )) ]) :-
    findall(Text-Answers,
            ( prelude_spec_expansion_case(_, Text),
              prelude_spec_observed('&self', Text,
                                    observation(Answers, _, answered)) ),
            Engine),
    prelude_spec_install('&prelude-expansion'),
    findall(Text-Expansion,
            ( prelude_spec_expansion_case(_, Text),
              prelude_spec_observed('&prelude-expansion', Text,
                                    observation([Expansion|_], _, answered)) ),
            Expansions),
    findall(Text-Answers-Produced,
            ( nth0(Index, Engine, Text-Answers),
              nth0(Index, Expansions, _-Expansion),
              findall(Value, evalc(Expansion, '&self', Value), Produced),
              \+ prelude_spec_bag_equal(Answers, Produced) ),
            Divergences),
    assertion(Divergences == []).

%Every head the register ships is exercised, so a form added to the vocabulary
%without a case here fails rather than passing untested.
test(every_shipped_head_has_a_case) :-
    findall(Head,
            ( prelude_head(Head, _),
              \+ prelude_spec_case(Head, _),
              \+ prelude_spec_expansion_case(Head, _) ),
            Untested),
    assertion(Untested == []).

:- end_tests(prelude_spec).

%A lane that cannot fail is not a lane. The comparator is run against a space
%holding ONE deliberately wrong equation, and it has to refuse it.
:- begin_tests(prelude_spec_selftest).

test(a_planted_divergence_is_reported,
     [ setup(metta_host_set_silent(true)),
       cleanup(( catch(metta_release_space('&prelude-spec-planted'), _, true),
                 metta_host_set_silent(false) )) ]) :-
    Text = "(if-equal 1 2 yes no)",
    prelude_spec_observed('&self', Text, EngineSide),
    metta_add_atom('&prelude-spec-planted',
                   [':', 'if-equal',
                    [->, 'Atom', 'Atom', 'Atom', 'Atom', '%Undefined%']], _),
    metta_add_atom('&prelude-spec-planted',
                   [=, ['if-equal', _A, _B, Then, _Else], Then], _),
    prelude_spec_observed('&prelude-spec-planted', Text, PlantedSide),
    assertion(\+ prelude_spec_agrees(EngineSide, PlantedSide)),
    %And it agrees with itself, so the refusal above is about the planted
    %equation rather than about anything the comparator does to both sides.
    assertion(prelude_spec_agrees(EngineSide, EngineSide)).

%The bag comparison is a MULTISET one: order is ignored and multiplicity is
%not, which is the difference between it and a set comparison.
test(the_bag_comparison_keeps_multiplicity_and_ignores_order) :-
    assertion(prelude_spec_bag_equal([a, b], [b, a])),
    assertion(\+ prelude_spec_bag_equal([a, a, b], [a, b, b])),
    assertion(\+ prelude_spec_bag_equal([a], [a, a])),
    %Up to variable renaming, which is what an answer carrying a fresh
    %variable needs.
    assertion(prelude_spec_bag_equal([[f, _X]], [[f, _Y]])),
    assertion(\+ prelude_spec_bag_equal([[f, _P, _P]], [[f, _Q, _R]])).

%A difference in what a call PRINTED is a difference, which is what keeps
%trace! honest, and so is a difference in what it threw.
test(the_comparison_reads_output_and_the_raised_ball) :-
    assertion(\+ prelude_spec_agrees(observation([a], "", answered),
                                     observation([a], "printed\n", answered))),
    assertion(\+ prelude_spec_agrees(observation([], "", raised(one)),
                                     observation([], "", raised(two)))),
    assertion(prelude_spec_agrees(observation([], "", raised(same)),
                                  observation([], "", raised(same)))).

:- end_tests(prelude_spec_selftest).
