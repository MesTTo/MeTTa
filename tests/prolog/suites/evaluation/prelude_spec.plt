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
%   - the engine's shipped register and the fixture are the same 41 equations,
%     47 declarations, 47 documents, 4 cost claims and 8 rule registrations
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

:- ensure_loaded('../../prelude_model.pl').

:- begin_tests(prelude_spec).

test(aligned_equations_are_the_vendored_arbiter) :-
    read_file_to_string('../conformance/petta/lib/lib_he.metta', Source, []),
    parse_metta_source(Source, Forms),
    forall(member(Name, ['if-equal', 'if-equal2', 'match-types',
                         'match-type-or', 'return-on-error']),
           ( member(Form, Forms),
             parsed_form_parts(Form, function, _, Equation),
             Equation = [=, [Name|_], _],
             prelude_shipped_equation(Name, Shipped),
             assertion(Shipped =@= Equation) )).

% -- the register and the fixture are one text ------------------------------

test(the_shipped_register_is_the_spec_fixture) :-
    prelude_spec_forms(Forms),
    findall(Name-Term,
            ( member(Form, Forms),
              parsed_form_parts(Form, function, _, Term),
              Term = [=, [Name|_], _] ),
            FromFixture),
    findall(Name-Term, prelude_shipped_equation(Name, Term), FromRegister),
    assertion(length(FromFixture, 41)),
    assertion(FromFixture =@= FromRegister).

test(the_declarations_are_the_spec_fixtures) :-
    prelude_spec_forms(Forms),
    findall(Name-Type,
            ( member(Form, Forms),
              parsed_form_parts(Form, expression, _, [':', Name, Type]),
              atom(Name) ),
            FromFixture),
    findall(Name-Type, prelude_declaration(Name, Type), FromRegister),
    assertion(length(FromFixture, 47)),
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
    assertion(\+ prelude_spec_bag_equal([[f, P, P]], [[f, _Q, _R]])).

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
