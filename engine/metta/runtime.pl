% This source holds non-ASCII text, and the encoding is declared HERE, ahead
% of it, rather than inherited from the ambient locale: SWI decodes the file as
% a stream, so a directive placed after the first non-ASCII byte is already too
% late. A boot under LC_ALL=C warned `Illegal multibyte Sequence` without it,
% which is every perf-measured child, because measure_instructions builds its
% environment from a small allowlist carrying no locale.
:- encoding(utf8).

% Purpose: provide test diagnostics, assertions, formatting, timing, and bounded execution helpers
% Guarantees: Rest-arrow reporting and documentation inspect metta_runtime_type/2
%   while the reported declaration retains its written type
%   [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Assumes: engine/metta.pl consults this plain file while its owning module is the load context.
% Guarantees:
%   - every definition retains engine/metta.pl's implementation module and original load order
%     [tested: tests/prolog/suites/evaluation/metta.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
%   - assert/2 reports a failed assertion through print_message/2, so it lands on user_error and
%     an embedded host's stdout carries only that host's own writes; test/3's
%     is/should line is the one diagnostic here that stays on current_output,
%     because it prints on success too [tested:
%     test_a_failing_assertion_stays_off_the_hosts_stdout in
%     extensions/python/tests/ch10_errors_and_refusals/test_engine_diagnostics.py,
%     test_the_c_binding_suite_passes in
%     extensions/python/tests/ch21_another_language_at_the_seam/test_c_binding.py,
%     tests/shell/test_example_runner_surfaces_failures.sh;
%     commit=b7eb5734f476f8a8f5b6f16c1e71a67c72a57478]
%   - metta_assertion_failed/3 carries the failing form and the two directed
%     bag differences, unbound where the form computed neither, and the
%     message prints one labelled line per bag; assert-answers/5 is the door
%     that computes them, on the failing path only, from the same
%     subtraction-atom/3 an assertEqualToResult verdict is built from
%     [tested: metta_assertions:an_assertion_ball_carries_the_two_bags,
%     metta_assertions:an_assertion_message_prints_both_bags,
%     prelude:assertEqual_failure_carries_both_bags; commit=71de27a76dd16684941e3e090de0d17299d96493]
%   - metta_assertion_failure/6 converts the two parts a host cannot otherwise
%     receive, so a false claim over answers carrying a VARIABLE arrives as an
%     assertion failure rather than as a classifier that could not run
%     [tested: metta_assertions:an_assertion_over_terms_with_variables_still_classifies,
%     metta_assertions:a_failing_test_classifies_its_two_values_unchanged;
%     commit=ef5b91d7950594a49e177d972a954841a6b8d6e0]
%   - absence is per bag, so assert-includes-answers/5 reports the answers
%     missing from a containment and leaves the excess side ABSENT, where a
%     two-sided report would name legal answers as a reason for the failure
%     [tested: metta_assertions:a_one_sided_ball_carries_the_missing_bag_alone,
%     metta_assertions:a_one_sided_message_prints_the_missing_line_alone,
%     prelude:assertIncludes_failure_carries_the_missing_bag_alone;
%     commit=48ec57e6df02e05ad3b5da50157dea321969bc48]
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.

%%% Diagnostics / Testing: %%%
:- multifile prolog:error_message//1.
:- multifile prolog:message//1.

prolog:error_message(metta_test_failed(Actual, Expected)) -->
    [ 'MeTTa test failed: ~p does not match ~p'-[Actual, Expected] ].
%The form is a MeTTa term, so it is rendered as MeTTa text. ~p on the Prolog
%list prints `[==,[collapse,[eval,[+,1,1]]],[collapse,[eval,3]]]`, which is the
%engine's storage and not what the program wrote. A bare `assert` reaches here
%with its operand already reduced, so the form it renders is a verdict; the
%bag-comparing forms hand assert-answers/5 their call AS WRITTEN and that is
%the list this renders.
%
%Missing and Excess are the two directed bag differences the failing form
%already computed on its way to a verdict, and carrying them is the whole
%reason this ball has three arguments: a comparison that keeps only the
%emptiness of a difference makes every reader recompute by hand what the
%engine held. Absence is PER BAG, not per pair: each stays UNBOUND where the
%failing form's own verdict did not depend on it, and the line below is then
%absent for that bag alone. Both are absent for bare `assert`, whose operand
%is a value, and for the alpha forms, whose relation is alpha-equivalence
%rather than bag difference; Excess alone is absent for `assertIncludes`,
%whose excess answers are LEGAL, so naming them would blame a bag that is not
%a reason for the failure. A one-sided verdict gets a one-sided report, which
%is the split a standard library already draws between the same two relations
%[measured 2026-09-07 on CPython 3.11.15: assertCountEqual([1,2],[2,3])
%reports `First has 1, Second has 0: 1` AND `First has 0, Second has 1: 3`,
%while assertIn(3, [1,2]) reports `3 not found in [1, 2]` and says nothing
%about the members of the list that were not asked for].
%
%hyperon-experimental reports the same pair from the same subtraction and
%spells them `Missed results` and `Excessive results`; the labels here are
%`missing` and `excess` instead, so the message and the Python fields a
%harness reads say one word each
%[source: hyperon-experimental hyperon-common/src/assert.rs:71-79, the diff
%branch of compare_vec_no_order; commit=71de27a76dd16684941e3e090de0d17299d96493].
prolog:error_message(metta_assertion_failed(Goal, Missing, Excess)) -->
    { sdisplay(Goal, Written) },
    [ 'MeTTa assertion failed: ~w'-[Written] ],
    assertion_bag_difference(Missing, Excess).

%One line per bag the verdict depended on, in the order a reader asks the two
%questions: what did I want that never came, then what came that I never
%wanted. Each bag is asked for itself rather than as a pair, so a one-sided
%verdict prints one line and a two-sided one prints two; the pair test this
%replaced could only print both or neither.
assertion_bag_difference(Missing, Excess) -->
    assertion_bag_line(missing, Missing),
    assertion_bag_line(excess, Excess),
    assertion_permutation_note(Missing, Excess).

assertion_bag_line(_, Bag) -->
    { var(Bag) },
    !,
    [].
assertion_bag_line(Label, Bag) -->
    { sdisplay(Bag, Written) },
    [ nl, '  ~w: ~w'-[Label, Written] ].

%Two empty bags beside a failure is not a puzzle, it is the diagnosis: the
%answers agree as multisets with their multiplicities, so a permutation is
%the only difference left. assertEqual is the one form that reaches it,
%because its verdict is term equality over the collapsed tuples while the
%difference above is multiplicity-aware and order-blind
%[measured 2026-09-06 on this tree: (assertEqual (superpose (1 2)) (superpose
%(2 1))) fails while (assertEqualToResult (superpose (1 2)) (2 1)) answers
%true].  Saying so costs one clause and saves the reader the inference.
%
%The two bags are compared with ==, not matched as [] in the head. A head
%match BINDS an absent bag to the empty list and then reports that the answers
%agree, which is the opposite of what absence means: it happened to be
%unreachable only while the pair test above cut every absent case out before
%this clause, and stopped being so the moment each bag was asked for itself
%[tested: metta_assertions:a_non_list_operand_leaves_the_bags_absent, which is
%what caught it].
assertion_permutation_note(Missing, Excess) -->
    { Missing == [], Excess == [] },
    !,
    [ nl, '  the two answer bags agree, so the answers differ only in order' ].
assertion_permutation_note(_, _) --> [].

%The three formals above are the program saying something FALSE, which is a
%different event from the engine breaking, and a harness has to be able to
%tell them apart without reading the sentence. This is the classifier that
%lets it: Form is the MeTTa operation that failed, Actual what it got and
%Expected what it wanted, both unbound where the form carries no such value.
%
%It lives beside the throwers rather than in the Python shim because the
%formals are the ENGINE's, so the two cannot drift: adding a fourth assertion
%form and forgetting this predicate leaves that form unclassified here, where
%it is read, rather than in a file the engine never loads [tested:
%extensions/python/tests/ch12_testing/test_assertion_failures.py].
%
%Actual and Expected cross through metta_host_operation_part/2, the same
%conversion the operation classifier beside this one applies: an atomic and a
%list of them as themselves, any other compound as the MeTTa text swrite/2
%writes, so a caller reads (a $x) rather than a Prolog term.
%
%They used to be handed out as the raw terms, on the reading that converting
%belongs to the host boundary rather than to the engine. That reading is not
%REACHABLE from a host: a term carrying a free variable never arrives to be
%converted, because the crossing itself refuses it. Every failing assertion
%whose answers held a variable therefore reported
%`the assertion classifier failed: Arguments are not sufficiently
%instantiated` and arrived as an EngineError, which says the interpreter broke
%where the truth was that the program's claim was false -- the one distinction
%AssertionFailure exists to draw [measured 2026-09-07 on this tree:
%!(assertEqualToResult (superpose ((f $x))) ((f $y))) raised EngineError; the
%operation classifier had no such hole because metta_host_operation_error/5
%already converts, which is what this now matches]
%[tested: metta_assertions:an_assertion_over_terms_with_variables_still_classifies,
%extensions/python/tests/ch12_testing/test_assert_answers.py].
%
%Missing and Excess are the same absence convention one level out: the two
%directed bag differences where the failing form computed them, unbound
%where it did not, so a consumer tells "the bags agree" (both `()`) from
%"there is no bag comparison here" (both absent) without reading prose. They
%need no conversion here, because each element is an ANSWER and every host
%already has an answer codec; only these two parts had none.
metta_assertion_failure(error(metta_test_failed(Actual0, Expected0), _),
                        test, Actual, Expected, _, _) :-
    metta_host_operation_part(Actual0, Actual),
    metta_host_operation_part(Expected0, Expected).
metta_assertion_failure(error(metta_assertion_failed(Goal0, Missing, Excess), _),
                        assert, Goal, _, Missing, Excess) :-
    metta_host_operation_part(Goal0, Goal).

prolog:error_message(metta_not_a_prolog_module(File)) -->
    [ '~w is not a Prolog module, so its exports cannot be imported under \c
       other names. Add :- module(name, [pred/arity, ...]) at its top, or \c
       register it without renaming.'-[File] ].
prolog:error_message(metta_not_exported(Module, Name, Exports)) -->
    [ '~w does not export ~w, so it cannot be imported under another name. \c
       It exports ~q.'-[Module, Name, Exports] ].
%The two names a Prolog registration cannot take, thrown by
%refuse_reserved_registration/1 below and rendered here so every
%prolog:error_message//1 clause in this file stays together.
prolog:error_message(permission_error(register, metta_builtin, Name)) -->
    [ '~w is a builtin, so registering a Prolog predicate under that name \c
       would replace the engine\'s own for every space in the process. A \c
       named space compiles its own clauses, so an equation there shadows \c
       the builtin for that space alone.'-[Name] ].
prolog:error_message(permission_error(register, metta_special_form, Name)) -->
    [ '~w is a special form, which the translator compiles directly, so a \c
       registration under that name could never be reached. Pick another \c
       name, or reach the predicate with (call (~w ...)), which needs no \c
       registration.'-[Name, Name] ].
prolog:error_message(metta_extension_api_mismatch(Name, Wanted, Ours)) -->
    [ '~w was written against extension seam ~w and this engine offers ~w. \c
       A major version differs, or the extension needs a hook this engine \c
       does not have yet.'-[Name, Wanted, Ours] ].
%Thrown by refuse_untypable_declaration/3 above. The type is written back
%through swrite/2 so the author sees the MeTTa they wrote rather than its
%Prolog list.
prolog:error_message(metta_untypable_declaration(Name, Type)) -->
    { sdisplay(Type, Written) },
    [ '(: ~w ~w) is not an arrow, so it types the symbol ~w and not a call \c
       to it: every (~w ...) compiles with no check at all, and a wrong \c
       argument surfaces wherever it finally breaks instead of here. Write \c
       (: ~w (-> ...)), or (: ~w %Undefined%) to say ~w is deliberately \c
       untyped.'-[Name, Written, Name, Name, Name, Name, Name] ].
prolog:error_message(metta_export_form(Text)) -->
    [ 'this is not an export declaration: ~w. An export is (: name (-> ...)) \c
       or (export name arity).'-[Text] ].
prolog:error_message(metta_load_failed(Summary)) -->
    [ 'the Prolog source did not load cleanly: ~w'-[Summary] ].
prolog:error_message(metta_name_owned_by_source(Name, Owner)) -->
    [ '~w is already registered from ~w. Two libraries defining one name \c
       destroy each other\'s predicate, because a consulted file REPLACES a \c
       static one of the same name and SWI only warns. Rename yours, or \c
       unregister the extension that owns it first.'-[Name, Owner] ].
prolog:error_message(permission_error(register, metta_function, Name)) -->
    [ '~w is already registered by another extension tier. Unregister it \c
       there first, or pick another name: two tiers sharing one name leaves \c
       whichever registered second in place and the other one\'s registry \c
       still claiming it.'-[Name] ].

%The value laid out for reading: (pretty-atom $x) answers the multi-line
%string swrite_pretty produces, so (println! (pretty-atom $big)) is the
%readable dump. Data in, data out; the printing stays println!'s job.
'pretty-atom'(Term, String) :- swrite_pretty(Term, String).

%An operation that ran for its EFFECT answers `true`, the engine's convention
%for the whole family: add-atom, remove-atom, bind!, change-state!, import!,
%git-import! and the translator-rule pair all answer it.
%tests/prolog/suites/spaces/spaces.plt's an_effectful_operation_answers_true
%holds the list, so an operation joining the family without answering `true`
%fails there rather than drifting quietly; the effect PROFILES are inventoried
%separately in tests/prolog/suites/evaluation/effects.plt.
%
%This is upstream PeTTa's answer and it is also what this tree's OWN catalogue
%already declared: `(: println! (-> %Undefined% Bool))` in
%lib/lib_builtin_types/lib_builtin_types.metta said Bool while the clause here
%answered unit, so the two disagreed until now
%[source: PeTTa@ae66fa8 src/metta.pl:212, `'println!'(Arg, true)`]
%[tested: spaces_arbitrary_atoms:an_effectful_operation_answers_true;
%commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
'println!'(Arg, true) :- sdisplay(Arg, RArg),
                         format('~w~n', [RArg]).

%One line, one form. A form spanning two lines is a syntax error here, which
%is why 'read-form!'/1 exists beside it.
'readln!'(Out) :- read_line_to_string(user_input, Str),
                  sread(Str, Out).

%A whole form, however many lines it takes. Reads until the brackets balance,
%so a console accepts (= (f $x)<enter>(+ $x 1)) the way every other language's
%does, and an empty line re-prompts instead of erroring.
%
%This is CPython's InteractiveConsole half: the buffering and prompting sit
%here, and the decision, sread_command/2, is in the reader with no I/O at all,
%so a Jupyter kernel or an editor integration uses the same answer without
%this loop [source: CPython, the code module's split between
%InteractiveInterpreter and InteractiveConsole]
%[tested: parser_reads_a_form_across_lines].
'read-form!'(Out) :- read_form_lines([], read_form_state(0, outside, false), Out).

%The decision on its own, with no I/O: (complete Term), incomplete, or a
%raise. A console that does its own reading asks this and keeps its own
%buffer.
%
%sread_command/2 answers the Prolog compound complete(Term), which is the
%right shape for a Prolog caller and the wrong one for a MeTTa program: it
%would arrive as an opaque term rather than as an expression to match on.
'parse-command'(Text, _) :- var(Text), !, refuse_unbound_input('parse-command', 1).
'parse-command'(Text, Result) :-
    sread_command(Text, Answer),
    ( Answer = complete(Term) -> Result = [complete, Term] ; Result = Answer ).

%A form may span lines, and each new line used to be appended to the whole
%buffered text and ALL of it handed back to sread_command/2: string_codes/2 over
%it, the content scan over it, the balance scan over it, once per line. That is
%Theta(L^2) in the form's total length. One form of 1,600 lines spent
%132,673,790,292 instructions where the SAME text on one line spent
%1,484,324,191, and the cost quadrupled per doubling
%[measured 2026-08-23].
%
%command_balance/5 already carries its (Depth, State) from one call to the next,
%so the same question can be asked of one LINE with that state carried, which is
%Theta(L) over the whole form, and the lines are joined once when it completes.
read_form_lines(Reversed, State0, Out) :-
    read_line_to_string(user_input, Line),
    (   Line == end_of_file
    ->  (   Reversed == []
        ->  Out = end_of_file
        ;   read_form_text(Reversed, Text),
            sread(Text, Out)
        )
    ;   Buffered = [Line|Reversed],
        read_form_step(Line, State0, State, Answer),
        (   Answer == complete
        ->  read_form_text(Buffered, Text),
            sread(Text, Out)
        %Malformed, so the reader's own error is the answer, exactly as it was
        %when the whole text reached sread_command/2's last clause.
        ;   Answer == malformed
        ->  read_form_text(Buffered, Text),
            sread(Text, _)
        ;   read_form_lines(Buffered, State, Out)
        )
    ).

%One line's worth of the scan sread_command/2 runs over a whole text, carrying
%what it learned. The line BREAK belongs to the scan and not only to the text:
%it is what ends a comment, so the state has to cross it. A closing bracket too
%many is MALFORMED rather than incomplete, which is why command_balance/5 fails
%on it and no amount of further typing repairs it.
read_form_step(Line, State0, State, Answer) :-
    State0 = read_form_state(Depth0, Scan0, Content0),
    string_codes(Line, Codes),
    (   command_balance(Codes, Depth0, Scan0, Depth, AfterLine)
    ->  string_state(AfterLine, 0'\n, Scan),
        (   Content0 == true
        ->  Content = true
        ;   command_content(Codes, Scan0)
        ->  Content = true
        ;   Content = false
        ),
        State = read_form_state(Depth, Scan, Content),
        (   read_form_settled(Content, Depth, Scan)
        ->  Answer = complete
        ;   Answer = incomplete
        )
    ;   State = State0,
        Answer = malformed
    ).

read_form_settled(true, 0, Scan) :-
    % policy-inventory-exempt: mechanism-internal; reason=string and escaped are internal states of the reader state machine; evidence=engine/metta/runtime.pl:read_form_settled/3
    \+ memberchk(Scan, [string, escaped]).

read_form_text(Reversed, Text) :-
    reverse(Reversed, Lines),
    atomic_list_concat(Lines, '\n', Joined),
    atom_string(Joined, Text).

test(A,B,true) :- (A =@= B -> E = '✅' ; E = '❌'),
                  sdisplay(A, RA),
                  sdisplay(B, RB),
                  format("is ~w, should ~w. ~w ~n", [RA, RB, E]),
                  ( A =@= B -> true
                  ; throw(error(metta_test_failed(A, B),
                                context(test, 'MeTTa test values differ'))) ).

%ZERO ANSWERS COMPARE AS `()`, which is upstream's own shape: its test form is
%`findall(Val, Conj, Results), (Results = [Actual] -> true ; Actual = Results)`,
%and `[] = [Actual]` fails, so an expression that answered nothing is compared
%as the empty expression [source: PeTTa@ae66fa8 src/translator.pl:146-152].
%This engine threw metta_test_no_answer here instead, which made
%`!(test (f T3in) ())` unwritable -- and that line is upstream's
%examples/types_nondet.metta, where a type mismatch is SUPPOSED to answer
%nothing and the test says so. Nothing is lost by not throwing: a test whose
%expression answers nothing when a value was wanted still prints
%`is (), should <value>. ❌` and still fails the run.
%test-no-answer/2 stays, and is not a synonym for `(test X ())`: it compares
%the raw answer LIST, so it distinguishes zero answers from one answer that is
%itself the empty expression, which this predicate deliberately conflates
%exactly as upstream conflates them.
test_answer_value([], []) :- !.
test_answer_value([Actual], Actual) :- !.
test_answer_value(Results, Results).

'test-no-answer'(Results, Out) :-
    test(Results, [], Out).

%The operand arrives EVALUATED. `(: assert (-> %Undefined% (->)))` is the
%declaration this engine carries, aligned to upstream PeTTa in 975b07ae, so
%what reaches here is the verdict and never the comparison:
%`!(assert (== 1 2))` reports `false`, not `(== 1 2)`
%[measured 2026-09-06 on this tree; the declaration is
%lib/lib_builtin_types/lib_builtin_types.metta and it is upstream's].
%
%A form that wants its CALL in the report therefore has to hand it over, which
%is what the assert family does through assert-answers/5 below; only that
%caller still holds what the program wrote.
%
%The eval below stays, and the paragraph after this one says what it is for.
%Calling the operand as a Prolog GOAL is what this used to do instead, and an
%operand that arrived as a LIST made SWI read it as a consult list:
%`!(assertEqual (+ 1 1) 3)` printed `source_sink '==' does not exist` three
%times and then answered true for a false assertion.
%
%eval/2 resolves in the calling space's module, which is what the old
%call(Module:Goal) was for: the form may name a function the space itself
%defines and those clauses are in that module and nowhere else. It is also
%nondeterministic in the operand's answers, so a form with several answers is
%checked once per answer, which is what the caller's own argument evaluation
%did before.
%
%The failure is REPORTED through print_message/2 and then thrown. It used to
%be `format("Assertion failed: ~w~n", [Written])`, which upstream wrote when
%this predicate ended in halt(1) and the print was the only report there would
%ever be (2cd191b0). 12232d25 replaced the halt with the throw below and left
%the format behind, so from then on the report went to current_output -- for a
%host that embeds SWI in its own process, that host's stdout, which it cannot
%suppress and must not have written to (CMeTTa C12; ai-cmetta-c-constraints.md).
%print_message/2 puts it on user_error, renders it through the ONE
%prolog:error_message//1 clause at the top of this file rather than a second
%spelling of the same sentence, and makes it interceptable: a host that wants
%only the ball takes the message with message_hook/3.
%
%Reporting AND throwing is deliberate, and is what SWI's own assertion/1 does
%[source: SWI-Prolog 10.1.13 library/debug.pl:391-397,
%prolog_debug:assertion_failed/2, which calls print_message(error,
%assertion_failed(Reason, G)) and then throws]. A ball can be
%swallowed by any catch/3 up the stack, and an assertion that says nothing
%when that happens is not an assertion. When the ball IS reported the two
%lines say the same thing, which is the price.
%
%The is/should line stays test/3's alone. That one prints on success too, so
%it is a trace of a check that RAN rather than a failure report, and tests/
%test_example_runner_surfaces_failures.sh reads the difference: a failing
%assert is now diagnosed on stderr only, exactly like a syntax error.
assert(Form, true) :-
    current_metta_module(Module),
    eval_metta_in_module(Module, Form, Produced),
    metta_boundary_result(Form, Produced, Value),
    (   Value == true
    ->  true
    ;   report_failed_assertion(assert, Form, _, _)
    ).

%The report every assertion door reaches, so the ball, the sentence and the
%classifier stay ONE shape however the verdict was reached. Reporting and then
%throwing is assert/2's decision, recorded above; this predicate is where it
%now happens for all of them. Missing and Excess are passed per bag and each
%may be left unbound, which is how a door with a one-sided verdict reports the
%one difference its verdict depended on.
%
%Culprit is the MeTTa HEAD the program wrote -- assert, test, assertEqual,
%assertIncludes -- and never the Prolog predicate that raised. SWI prefixes an
%uncaught error with its context's first argument
%[source: SWI-Prolog 10.1.13 boot/messages.pl, swi_location//1 over
%context(ContextPI, _)], so what a reader saw was
%`'assert-answers'/5: MeTTa assertion failed: ...`, an engine-internal name and
%arity in a sentence about the program's own claim, with no head of that name
%anywhere in the source. Naming the written MeTTa operation in the context is
%the convention the engine already holds every OTHER user-facing refusal to
%[source: engine/metta/registration.pl, metta_host_operation_error/5, whose
%first condition is atom(Operation) over that same position;
%commit=e9851ae5542263936f11590e059d1e1576d2ce7b], and the two message clauses there render from it. Nothing
%else reads this position: the classifier below matches the context as `_` and
%takes its own operation word from the FORMAL.
report_failed_assertion(Culprit, Form, Missing, Excess) :-
    print_message(error, error(metta_assertion_failed(Form, Missing, Excess), _)),
    throw(error(metta_assertion_failed(Form, Missing, Excess),
                context(Culprit, 'MeTTa assertion failed'))).

%assert with the two answer bags carried, so a failed comparison over answers
%says WHICH answers differ instead of only that they did. The four arguments
%are the verdict, the call to report as the program wrote it, the answers
%produced, and the answers expected.
%
%The VERDICT stays the caller's and this door never decides it. That is what
%keeps assertEqual's term equality over the collapsed tuples and
%assertEqualToResult's multiset equality exactly the comparisons they were:
%the change carries evidence into the failure and moves no verdict
%[tested: prelude:assertEqual_failure_carries_both_bags,
%prelude:assertEqualToResult_failure_carries_both_bags].
%A user's own assertion over answer bags reaches the same report by handing
%over its own verdict, which is why this is vocabulary rather than a private
%helper.
%
%The difference is computed HERE and only on the failing path. assertEqual's
%verdict is one ==, so computing its bags where the arguments are built would
%charge every passing assertion in the corpus two subtractions for a
%diagnostic nobody reads; assertEqualToResult's verdict already holds them and
%recomputing two small subtractions once, on a run that is about to stop, is
%not worth a second door shape.
%
%subtraction-atom is the engine's own multiplicity-preserving difference and
%the very operation an assertEqualToResult verdict is built from, so what a
%failure reports and what a verdict tested cannot drift. It wants proper lists
%on both sides: collapse answers one and a written expected set is one, but a
%hand-written call may pass anything, and an unbound or partial operand would
%either make subtraction-atom refuse or bind the caller's variable. Either
%would replace the assertion failure with a different error, so the bags stay
%absent there and the message degrades to the form alone.
'assert-answers'(Verdict, _, _, _, true) :- Verdict == true, !.
'assert-answers'(_, Form, Actual, Expected, true) :-
    written_assertion_culprit(Form, 'assert-answers', Culprit),
    (   is_list(Actual), is_list(Expected)
    ->  'subtraction-atom'(Expected, Actual, Missing),
        'subtraction-atom'(Actual, Expected, Excess),
        report_failed_assertion(Culprit, Form, Missing, Excess)
    ;   report_failed_assertion(Culprit, Form, _, _)
    ).

%The head of the call a door was handed, which is the MeTTa operation the
%program wrote: these two doors take that call AS WRITTEN, so its head is
%exactly what a reader has to look for in the source. Only a form with an
%atom head has one, and a caller may hand over anything, so a form that is not
%an application falls back to the DOOR's own MeTTa name -- which is then the
%head the program wrote, since it called the door directly.
%
%This reads the reported form for a DIAGNOSTIC and decides nothing.
%Dispatching a comparison on that head was rejected on 2026-09-06 for making
%the reported form load-bearing for semantics
%[source: docs/journal/2026-09-06-the-bag-diff-an-assertion-already-computes.md;
%commit=e9851ae5542263936f11590e059d1e1576d2ce7b]; a culprit changes no verdict, no bag and no ball.
written_assertion_culprit(Form, _, Head) :-
    nonvar(Form),
    Form = [Head|_],
    atom(Head),
    !.
written_assertion_culprit(_, Door, Door).

%The same door for a CONTAINMENT over answers: the expectation is a lower
%bound rather than the whole answer set, so exactly one of the two directed
%differences is a reason for the failure. Its arguments are assert-answers'
%four, in the same order and with the same meanings, and the verdict is still
%the caller's; what differs is that only Expected minus Actual is computed and
%the excess side stays ABSENT rather than being reported as empty. An excess
%answer is legal under this relation, so a line naming one would invite the
%reader to fix something that is not broken -- the failure mode a two-sided
%report of a one-sided verdict has, and the reason assertIncludes had no
%report at all until this door existed
%[source: docs/journal/2026-09-06-the-bag-diff-an-assertion-already-computes.md,
%"assertIncludes is OUT ... revisit when a one-sided assertion door is
%wanted"; commit=48ec57e6df02e05ad3b5da50157dea321969bc48].
%
%TWO doors rather than one door taking the relation as an argument. A mode
%argument is a closed value set no lane can check, which the same thread
%rejected it for, and dispatching on the reported form's head would make that
%form load-bearing for semantics; two named doors are checkable vocabulary and
%each says in its own name which report it gives.
'assert-includes-answers'(Verdict, _, _, _, true) :- Verdict == true, !.
'assert-includes-answers'(_, Form, Actual, Expected, true) :-
    written_assertion_culprit(Form, 'assert-includes-answers', Culprit),
    (   is_list(Actual), is_list(Expected)
    ->  'subtraction-atom'(Expected, Actual, Missing),
        report_failed_assertion(Culprit, Form, Missing, _)
    ;   report_failed_assertion(Culprit, Form, _, _)
    ).

%%% The running space: %%%
% (context-space) answers the space whose module the current goal runs in,
% so a program loaded into a named space reaches its own atoms the way a
% program in &self writes (match &self ...); outside any named space the
% answer is &self.
'context-space'(Space) :- ( current_metta_space(Space) -> true ; Space = '&self' ).

%get-type, run with the SELECTED space as the context: upstream's
%get-type-space (pinned stdlib.md:849-868). The library stub this
%replaces matched the literal &self and answered nothing for any named
%space; the engine's type machinery is module-parameterized already, so
%selection is one with_metta_module/2 around the ordinary get-type.
%A name that is not a space is refused here as it is at every other space
%door, and in the same shape, an ANSWER rather than a throw:
%`(Error (get-type-space not-a-space scoped-atom) get-type-space expects a
%space as the first argument)` is what a scoped type lookup reads back through
%this operation [tested: space_argument_refusals]. Without it, space_module/2
%made a module for the name and the lookup answered &self's own declarations
%through it.
'get-type-space'(Space, _, _) :- var(Space), !,
                                 refuse_unbound_input('get-type-space', 1).
%Both clauses guard themselves rather than leaning on a cut, for the reason
%match/4's last clause records: a proof walk enumerates clauses and calls each
%body, where an earlier cut prunes nothing.
'get-type-space'(Space, X, T) :- \+ metta_space_name(Space), !,
                                 space_argument_error('get-type-space',
                                                      [Space, X], T).
'get-type-space'(Space, X, T) :-
    metta_space_name(Space),
    reported_scoped_type_answers(Space, X, Types),
    (   var(T)
    ->  member(T, Types)
    ;   member(Actual, Types),
        space_module(Space, Module),
        typing_rule_accepts(Module, witness, '$metta_resolved_type'(Actual), T)
    ).

%get-type-space is the other reporting observer. Its underlying scoped answer
%function stays unchanged because scoped_has_type/4 is a classifier consumer.
reported_scoped_type_answers(_, X, [['->']]) :- X == [], !.
reported_scoped_type_answers(Space, [F], [Result]) :-
    nonvar(F),
    (   space_module(Space, Module),
        scoped_type_declaration(Space, Module, F, Raw),
        metta_runtime_type(Raw, [->, ['%Rest%', _], Result])
    *-> true
    ;   seam:builtin_type_declaration(F, [->, ['%Rest%', _], Result])
    ),
    !.
reported_scoped_type_answers(Space, X, Types) :-
    scoped_type_answers(Space, X, Types).

%%% Documentation, HE's vocabulary, first class %%%
%
%The design stays lib_doc's, which was already the right one:
%documentation is ATOMS IN A SPACE, (@doc name (@desc ...) ...) is data
%a program writes and can reason about, and retrieval is a match. What
%promotion adds is reach and a second tier: these are builtins now, no
%import, they resolve against the CURRENT context rather than literal
%&self, each has a -space twin selecting any space, and get-doc falls
%back to the engine's own register, where the prelude documents its
%vocabulary, so help! answers for engine forms too.
%
%The tier split is deliberate and asymmetric. RESOLVERS (get-doc,
%help!) consult the register, because "what does this name mean" wants
%an answer wherever the name comes from. ENUMERATORS (documented,
%defined-name, undocumented) are program-scoped and skip builtins,
%because "what have I documented" and "what did I forget" are questions
%about the program, and an engine that padded the answer with its own
%vocabulary would bury the user's gap under noise.
%
%The register branch comes FIRST in get-doc for the same determinism
%reason type_declaration_in orders its tiers: a first-arg-indexed miss
%is fast for ordinary names, and the disjunction is exhausted when
%match/4 ends, so raw first-solution callers keep match's own
%choicepoint profile.
:- dynamic prelude_doc_atom/2.

'get-doc'(Name, Doc) :- current_metta_space(Space),
                        'get-doc-space'(Space, Name, Doc).

%Upstream's two-input operation. The unary overload above remains the raw-doc
%convenience MeTTa already shipped; this arity is the formal family and follows
%the pinned stdlib equations field for field.
'get-doc'(Space, _, _) :- var(Space), !,
                          refuse_unbound_input('get-doc', 1).
'get-doc'(Space, Atom, Doc) :-
    metatype_of(Atom, 'Expression'), !,
    'get-doc-atom'(Space, Atom, Doc).
'get-doc'(Space, Atom, Doc) :-
    'get-doc-single-atom'(Space, Atom, Doc).

%A document now carries a kind plus as many parameter, return, and example
%fields as its source owns. Enumerate first and inspect the proper stored list;
%an open-tailed matcher pattern does not match the engine's list store.
doc_shape(Name, ['@doc', Name|Fields]) :- Fields = [_|_].

%match_stored/4, not the door: the door answers an error atom for a name that
%is not a space, and the slot it would land in here is discarded, so the doc
%shape would come back unbound as though a document had been found.
'get-doc-space'(Space, Name, Doc) :-
    (   prelude_doc_atom(Name, Doc)
    ;   'get-atoms'(Space, Doc)
    ),
    doc_shape(Name, Doc).

%Documentation used by the formal family comes from the selected space. The
%engine's prelude register is the fallback only for the current context, where
%it represents the vocabulary that space can call. A foreign space with no
%matching atom cannot acquire ambient prose.
formal_doc_atom(Space, Name, Pattern) :-
    (   \+ \+ match_stored(Space, Pattern, Pattern, _)
    ->  match_stored(Space, Pattern, Pattern, _)
    ;   current_metta_space(Space),
        prelude_doc_atom(Name, Stored),
        Stored = Pattern
    ).

doc_type_error(['Error'|_]).

'get-doc-single-atom'(Space, _, _) :- var(Space), !,
                                      refuse_unbound_input('get-doc-single-atom', 1).
%A function's document does not have to carry the parameter block.
%get-doc-function builds the four-field shape and matches only
%['@doc', Name, Desc, ['@params', _], _], so committing an arrow-typed name to
%it made the whole branch FAIL for a portable ['@doc', Name, ['@desc', _]]:
%the door answered nothing and the Python doc() raised, while the unary
%get-doc answered the same document from the same space. A downstream
%integration documents 47 arrow-typed callables that way and every one of them
%was invisible [measured 2026-09-04, one stored row, one unary answer, and
%EngineError from the scoped door].
%
%The short shape keeps the description it carries and says @kind function,
%which is what the name IS; get-doc-atom would answer it as an atom. A name
%with NO document still fails here, so doc() keeps raising for one that was
%never written, and formal_doc_atom stays the only reader so a non-space
%acquires no documentation and two stored documents remain two answers.
'get-doc-single-atom'(Space, Atom, Doc) :-
    'get-type-space'(Space, Atom, Type),
    (   doc_type_error(Type)
    ->  Doc = Type
    ;   metta_runtime_type(Type, [->|_])
    ->  (   \+ \+ formal_doc_atom(Space, Atom,
                                  ['@doc', Atom, _, ['@params', _], _])
        ->  'get-doc-function'(Space, Atom, Type, Doc)
        ;   formal_doc_atom(Space, Atom, ['@doc', Atom, Description]),
            Doc = ['@doc-formal', ['@item', Atom], ['@kind', function],
                   ['@type', Type], Description]
        )
    ;   'get-doc-atom'(Space, Atom, Doc)
    ).

'get-doc-atom'(Space, _, _) :- var(Space), !,
                               refuse_unbound_input('get-doc-atom', 1).
'get-doc-atom'(Space, Atom, Doc) :-
    'get-type-space'(Space, Atom, Type),
    (   doc_type_error(Type)
    ->  Doc = Type
    ;   \+ \+ formal_doc_atom(Space, Atom, ['@doc', Atom, _])
    ->  formal_doc_atom(Space, Atom, ['@doc', Atom, Description]),
        Doc = ['@doc-formal', ['@item', Atom], ['@kind', atom],
               ['@type', Type], Description]
    ;   'get-doc-function'(Space, Atom, '%Undefined%', Doc)
    ).

'get-doc-function'(Space, _, _, _) :- var(Space), !,
                                      refuse_unbound_input('get-doc-function', 1).
'get-doc-function'(Space, Name, Type, Doc) :-
    formal_doc_atom(Space, Name,
                    ['@doc', Name, Description, ['@params', Params], Return]),
    doc_function_types(Type, Params, Types),
    doc_params(Params, Return, Types, FormalParams, FormalReturn),
    Doc = ['@doc-formal', ['@item', Name], ['@kind', function],
           ['@type', Type], Description, ['@params', FormalParams],
           FormalReturn].

doc_function_types('%Undefined%', Params, Types) :- !,
    length(Params, ParameterCount),
    TypeCount is ParameterCount + 1,
    length(Types, TypeCount),
    maplist(=('%Undefined%'), Types).
doc_function_types(Raw, _, Types) :- metta_runtime_type(Raw, [->|Types]).

'get-doc-params'(Params, _, Types, _) :-
    (   var(Params)
    ->  refuse_unbound_input('get-doc-params', 1)
    ;   var(Types)
    ->  refuse_unbound_input('get-doc-params', 3)
    ;   fail
    ), !.
'get-doc-params'(Params, Return, Types, [FormalParams, FormalReturn]) :-
    doc_params(Params, Return, Types, FormalParams, FormalReturn).

doc_params([], ['@return', Description], [Type|_], [],
           ['@return', ['@type', Type], ['@desc', Description]]).
doc_params([['@param', Description]|Params], Return, [Type|Types],
           [['@param', ['@type', Type], ['@desc', Description]]|FormalParams],
           FormalReturn) :-
    doc_params(Params, Return, Types, FormalParams, FormalReturn).

'help!'(Name, []) :-
    (   \+ 'get-doc'(Name, _)
    ->  swrite(Name, S),
        format("No documentation for ~w~n", [S])
    ;   forall('get-doc'(Name, Doc),
               ( swrite(Doc, DS), format("~w~n", [DS]) ))
    ).

documented(Name) :- current_metta_space(Space),
                    'documented-space'(Space, Name).

'documented-space'(Space, Name) :- 'get-atoms'(Space, Doc),
                                   doc_shape(Name, Doc).

%The library's exact semantics: every head of an equation THE SPACE
%HOLDS, once each. Enumerating the space's own atoms is what excludes
%builtins, engine-generated lambdas, and registered operations without
%any filter list: none of them stores an equation atom here.
'defined-name'(Name) :- current_metta_space(Space),
                        distinct(Name,
                                 ( get_native_atom(Space, [=, [Name|_], _]),
                                   atom(Name) )).

undocumented(Name) :- current_metta_space(Space),
                      'undocumented-space'(Space, Name).

'undocumented-space'(Space, Name) :-
    distinct(Name,
             ( get_native_atom(Space, [=, [Name|_], _]),
               atom(Name) )),
    \+ 'get-doc-space'(Space, Name, _).

%%% Time Retrieval: %%%
'current-time'(Time) :- get_time(Time).
'format-time'(Format, _) :- var(Format), !, refuse_unbound_input('format-time', 1).
'format-time'(Format, TimeString) :- get_time(Time), format_time(atom(TimeString), Format, Time).

%%% Filesystem tests: %%%
%
%SWI's exists_file/1 is a TEST, and the engine reads a registered predicate's
%LAST argument as the output, so registering the name bare made its only
%argument the answer slot: a path could never be passed in, and
%(exists_file "run.sh") raised function_input_arities(exists_file,[0]) while
%(exists_file) alone raised "Arguments are not sufficiently instantiated". A
%declared type for it, (-> %Undefined% Bool), said it took a path all the same.
%
%That silence is already on the record from the other side. lib_import.metta
%notes removing a former guard because "It made a missing file fail SILENTLY,
%with no answer", which is exactly what a zero-input registration does: the
%call site went and the registration stayed.
%
%The wrapper is sleep/2's shape below, and it answers false rather than
%FAILING, because a test that fails is indistinguishable from a test that was
%never reached, which is what made the original symptom so hard to read
%[tested: builtin_exists_file].
'exists_file'(Path, Result) :-
    (   ( atom(Path) ; string(Path) )
    ->  ( system:exists_file(Path) -> Result = true ; Result = false )
    ;   throw_metta_type_error(exists_file, 'a path as a symbol or string', Path)
    ).

%The ZERO-INPUT spelling is the same test read backwards. The engine takes a
%registered predicate's LAST argument as the output, so (exists_file) hands its
%only argument back, and a let* binding whose pattern variable already holds a
%path passes that path IN:
%
%  (let* (($file "./data.txt") ($file (exists_file))) $file)
%
%That is how lib_import.metta guards a file before consulting it, and it is the
%only spelling upstream has, because there the name reaches SWI's own
%exists_file/1 and nothing declares a second arity
%[source: PeTTa-upstream/lib/lib_import.metta:3, commit=57f21ba9edf94bcf28cde11f938bce2c241a3709].
%
%Defining it HERE rather than inheriting SWI's is what keeps both properties at
%once. Inheriting it made `!(exists_file)` abort the whole runnable with
%exists_file/1: Arguments are not sufficiently instantiated, measured on this
%tree, which is the host-abort that
%test_an_underapplied_operation_answers_instead_of_aborting exists to forbid;
%the engine's own clause answers instead. The arity is ours, so
%retract_unrelated_system_arities/0 leaves it alone: its test is
%predicate_property(built_in), and a redefined predicate is not built_in
%[tested: builtin_exists_file_reverse_mode; commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
%
%An UNBOUND slot is the under-applied call rather than the reverse-mode one,
%and it answers the same partial application every other under-applied
%operation answers, because the output slot is the only argument there is
%[tested: test_an_underapplied_operation_answers_instead_of_aborting].
:- redefine_system_predicate(exists_file(_)).
'exists_file'(Path) :- var(Path), !, Path = partial(exists_file, []).
'exists_file'(Path) :- 'exists_file'(Path, true).

%%% Time control: %%%
%Suspend this evaluation. In a thread, only this thread waits.
'sleep'(Seconds, _) :- var(Seconds), !, refuse_unbound_input(sleep, 1).
'sleep'(Seconds, true) :- must_be(number, Seconds), sleep(Seconds).

%Bound a goal by wall clock, keeping every answer.
%
%call_with_time_limit/2 runs its goal as once/1, so wrapping the goal directly
%would collapse a three-answer expression to one, the trap with_mutex/2 sets.
%The findall INSIDE the limit is what avoids that: the whole enumeration is
%bounded as one unit and member/2 hands the answers back.
%
%Do not be tempted to replace this with a raw alarm/4 around the goal to get
%lazy answers. It crashes: alarm/4 with throw/1 around a deeply recursive goal
%took SIGSEGV where call_with_time_limit/2 on the identical goal unwound
%cleanly [measured 2026-08-15]. The cost of doing this
%safely is that answers are collected before the first is yielded, which for a
%deadline-bounded call is what you want anyway.
%
%A wall-clock bound is also the only one that survives concurrency. The
%inference limit counts the calling thread only, so it does not stop work a
%hyperpose branch or a spawned future is doing [measured 2026-08-15: a 50,000
%inference limit did not stop two branches spending six million].
%
%Expiry throws rather than failing, so a partial answer set is never mistaken
%for the whole one. time_limit_exceeded is already a control exception here.
:- meta_predicate metta_timeout(+, 0, ?),
                  metta_inferences(+, 0, ?),
                  metta_elapsed(0, ?, ?),
                  metta_with_pragmas(+, 0, ?),
                  metta_host_with_stack_limit(+, 0).
%Why these helpers: a runnable's goals run as call(Module:G), so a goal a
%special form passes to a HELPER used to lose the module on the way in,
%and the helper's findall called it back in user: every one of these
%forms was silently unusable in a named space, which is every space the
%Python surface creates ("Unknown procedure" for a function the space
%plainly defines). meta_predicate makes the call site wrap the goal
%argument as Module:Goal, the manual's own maplist example.
%metta_transaction/1 takes its declaration beside its clause in
%space_hooks.pl; metta_take/2 and metta_top/3 do the same in spaces.pl,
%because a meta_predicate directive above a predicate defined
%in another file warns that it has no clauses. Baking the
%qualification at translate time was measured as the alternative and
%costs MORE where wrapper forms are retranslated per run
%(annotated-relation +2498 baked against +996 wrapped, over 500
%named-space evaluations); the wrap is free in user because an
%already-plain goal in a user-context call needs no module hop
%[source: SWI-Prolog 10.1 manual, ch. 6 defining a meta-predicate;
%measured 2026-08-18; tested spaces:wrapper_forms_run_in_named_spaces].

%The platform check comes FIRST, before the operand is even type-checked: on a
%build without library(time) there is no bound to apply, and the alternative
%is existence_error(procedure, call_with_time_limit/2) raised from here, which
%names a Prolog predicate a MeTTa author never wrote
%[tested: platform_capabilities_reduced:a_bounded_form_refuses_by_name_when_deadlines_are_absent].
%The alarm stops the work and the deadline check decides the outcome, the one
%wall-clock rule every door here holds: a form that finished only because its
%alarm arrived late still ran past the bound it was given, so it refuses
%rather than answering [source: engine/metta/control.pl, run_under_pragmas/1].
metta_timeout(Seconds, Goal, Value) :-
    metta_require_platform('(timeout N Expr)', deadlines),
    must_be(number, Seconds),
    metta_host_time_budget(findall(Value, Goal, Values), Seconds, Bounded),
    call_with_time_limit(Seconds, Bounded),
    member(Value, Values).

%timeout's deterministic twin, the kwarg vocabulary at the language tier:
%(inferences N Expr) bounds Expr by engine steps, the same limit
%m.run(inferences=) applies one level up, so a program bounds its own
%subexpression and the bound stops at the same step on every machine.
%The whole answer set is computed under the bound, timeout's own rule, so
%a partial set is never mistaken for the whole one; expiry throws the
%reserved resource envelope the Python tier already classifies.
%The limiter stops the work and the cumulative read decides, timeout's own
%rule one line up and for a sharper reason here: SWI disarms the limit before
%raising its bare `inference_limit_exceeded` atom inside the goal, so a
%recovery catch anywhere under Expr eats the ball and the limiter then
%reports success for a subexpression that never stopped
%[source: docs/journal/2026-09-04-bounded-trace-keeps-its-events.md;
%tested: inference_budget:a_swallowed_ball_still_refuses_at_the_language_form].
metta_inferences(Limit, Goal, Value) :-
    must_be(positive_integer, Limit),
    metta_host_inference_budget(findall(Value, Goal, Values), Limit, Bounded),
    call(Bounded),
    member(Value, Values).

%Time one answer and report what it cost, as (Value Seconds). Each answer is
%timed from the start of the call, so backtracking into a later answer reports
%the total spent reaching it rather than restarting the clock.
metta_elapsed(Goal, Value, [Value, Seconds]) :-
    get_time(Start),
    Goal,
    get_time(End),
    Seconds is End - Start.
