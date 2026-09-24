% Purpose: the engine's refusal taxonomy, tested from the balls themselves:
%   every kind it declares, classified out of a ball that raises it, with the
%   fields that kind carries.
% Assumes:
%   - tests/data/error-kinds.json is the list both host seats read; this suite
%     resolves it against its own directory, because a load-time directive is
%     file-relative while a suite runs with tests/prolog as its working
%     directory.
% Guarantees:
%   - the fixture and the engine declare the same kinds with the same fields,
%     in both directions [tested: the_fixture_lists_exactly_the_declared_kinds]
%   - every declared kind classifies from a real ball, with exactly its own
%     fields and their values
%     [tested: every_declared_kind_classifies_from_its_own_ball]
%   - the check is not vacuous: a ball checked against the wrong row fails
%     [tested: the_check_sees_a_planted_mismatch]
%   - every declared kind's ball renders a message of its own, and a signal
%     renders without the envelope's framing, its sentence when its detail is
%     one [tested 2026-09-25T05:48:06+10:00: every_declared_kind_renders_a_message_of_its_own,
%     a_sentence_signal_renders_as_its_sentence]
%   - a ball the engine did not shape is the `engine` kind rather than a
%     misreading of a name nested inside it
%     [tested: a_signal_name_nested_in_another_term_is_not_a_signal]
%   - a bound that expired in a nested query names its resource and no number
%     [tested: a_nested_bound_names_no_number]
%   - a stack ceiling is the one that was IN FORCE, read from the ball, not
%     the flag's current value
%     [tested: the_stack_ceiling_is_the_one_the_ball_recorded]
%   - EVERY declared platform capability classifies with field values a wire
%     can carry, which the fixture's one ball per kind cannot reach: three of
%     them name a LIST of libraries rather than one
%     [tested: every_declared_platform_capability_crosses_as_atomics]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../engine/json_codec').

:- dynamic error_kind_fixture/4.

%The codec's own option list. The reader wants every literal named, so the
%three sentinels are spelled here the way json_codec.plt spells them.
fixture_options([shape(dicts), true(@(true)), false(@(false)), null(@(none))]).

fixture_row(Name-Row, fixture(Name, Fields, Ball, Expected)) :-
    get_dict(fields, Row, Wire),
    maplist(atom_string, Fields, Wire),
    get_dict(ball, Row, Ball),
    get_dict(expects, Row, Expects),
    dict_pairs(Expects, _, Expected).

:- prolog_load_context(directory, Here),
   absolute_file_name('../../../../tests/data/error-kinds.json', Path,
                      [relative_to(Here), access(read)]),
   read_file_to_string(Path, Text, []),
   fixture_options(Options),
   json_codec_read(Text, Json, Options),
   get_dict(kinds, Json, Kinds),
   dict_pairs(Kinds, _, Rows),
   maplist(fixture_row, Rows, Parsed),
   forall(member(fixture(N, F, B, E), Parsed),
          assertz(error_kind_fixture(N, F, B, E))).

:- begin_tests(error_kinds).

%What the engine answers for one ball, with its fields rendered the way a
%reader sees them. A seat's own wire renders them its own way and its own
%suite checks that; this checks the classification and the values.
classification(BallText, Kind, Fields, Values) :-
    term_string(Ball, BallText),
    metta_host_error_kind(Ball, Kind, Pairs),
    pairs_keys_values(Pairs, Fields, Raw),
    maplist(written, Raw, Values).

written(Value, Text) :- format(string(Text), '~w', [Value]).

test(the_fixture_lists_exactly_the_declared_kinds) :-
    findall(Kind-Fields, metta_host_error_kind_row(Kind, _, Fields), Declared0),
    msort(Declared0, Declared),
    findall(Kind-Fields, error_kind_fixture(Kind, Fields, _, _), Listed0),
    msort(Listed0, Listed),
    assertion(Declared == Listed).

test(every_declared_kind_classifies_from_its_own_ball,
     [ forall(error_kind_fixture(Kind, Fields, Ball, Expected)) ]) :-
    classification(Ball, Answered, Names, Values),
    assertion(Answered == Kind),
    %The declared fields are a JSON ARRAY and keep the order the row declares;
    %the expected values are a JSON OBJECT, which the reader hands back sorted
    %by key, so the carried pairs are sorted to meet them.
    assertion(Names == Fields),
    pairs_keys_values(Carried, Names, Values),
    msort(Carried, Sorted),
    assertion(Sorted == Expected).

%Every kind's ball renders a message of its own rather than SWI's `Unknown
%error term` dump, which is what every seat that shows message text printed for
%the value, type and interrupted signals until 2026-09-24. A signal renders as
%what it says, without the envelope's framing: SWI's `metta:` location and the
%`(kind)` comment are not part of the refusal. The kinds come from the fixture,
%so a kind added to the table is checked from its own ball the day it is added.
test(every_declared_kind_renders_a_message_of_its_own,
     [ forall(error_kind_fixture(Kind, _, BallText, _)) ]) :-
    term_string(Ball, BallText),
    rendered(Ball, Text),
    assertion(Text \== ""),
    assertion(\+ sub_string(Text, _, _, _, "Unknown")),
    (   metta_host_error_kind_row(Kind, signal, _)
    ->  assertion(\+ sub_string(Text, 0, _, _, "metta:")),
        format(string(Comment), "(~w)", [Kind]),
        assertion(\+ sub_string(Text, _, _, 0, Comment))
    ;   true
    ).

%A signal whose detail is a sentence renders as that sentence, whichever kind
%it is: the codec's value and type refusals say what JSON cannot carry.
test(a_sentence_signal_renders_as_its_sentence,
     [ forall(member(Kind, [value, type])) ]) :-
    Ball = error(metta_control_signal(Kind, "JSON cannot carry the term"),
                 context(metta, Kind)),
    rendered(Ball, Text),
    assertion(Text == "JSON cannot carry the term").

%The message a seat reads for one ball: the translation print_message/2 makes,
%through the predicate it calls [source 2026-09-25T05:48:17+10:00:
%https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/boot/messages.pl#L2483-L2521,
%print_message/2 calls translate_message/3], laid out as it lays it, without
%the trailing newline.
rendered(Ball, Text) :-
    '$messages':translate_message(Ball, Lines, []),
    with_output_to(string(Laid), print_message_lines(current_output, '', Lines)),
    split_string(Laid, "", "\n", [Text]).

%The fixture carries ONE ball per kind, so it reaches one shape of a field
%that has two. A platform requirement is library(thread) for most capabilities
%and a LIST for markup, persistency and fast-cache, and a list took a
%different branch of the reducer. Driving every capability the engine declares
%covers both, and covers a capability added later that nobody remembers to
%plant. The law is what a wire carries: atomics, so a compound that reached a
%field unreduced is caught here rather than at a seat's crossing.
test(every_declared_platform_capability_crosses_as_atomics,
     [ forall(metta_engine:metta_platform_capability(Capability, Requires, Costs)) ]) :-
    Ball = error(metta_platform_required('(probe)', Capability,
                                         Requires, Costs), none),
    metta_host_error_kind(Ball, Kind, Fields),
    assertion(Kind == platform),
    pairs_values(Fields, Values),
    assertion(forall(member(Value, Values), atomic(Value))).

%A clean result above says nothing unless the check can go red, so the syntax
%envelope is checked against the restraint row and has to fail.
test(the_check_sees_a_planted_mismatch) :-
    error_kind_fixture(syntax, _, Ball, _),
    classification(Ball, Kind, Names, _),
    assertion(Kind \== restraint),
    assertion(Names \== [restraint, bound, call]).

%The reader's line rides in the envelope's context slot; an envelope that
%names no line carries no line field rather than a guessed one.
test(a_syntax_envelope_carries_its_line) :-
    metta_host_control_signal_line(
        error(metta_control_signal(syntax, 'missing'),
              context(metta, metta_source_line(7))), Line),
    assertion(Line == 7),
    \+ metta_host_control_signal_line(
        error(metta_control_signal(syntax, 'missing'), context(metta, syntax)), _),
    \+ metta_host_control_signal_line(
        error(metta_control_signal(time_limit, 1), context(metta, time_limit)), _),
    metta_host_error_kind(
        error(metta_control_signal(syntax, 'missing'), context(metta, syntax)),
        syntax, Fields),
    assertion(Fields == []).

%A name that merely APPEARS inside another term is not the signal it names.
test(a_signal_name_nested_in_another_term_is_not_a_signal,
     [ forall(member(Sentinel, [metta_syntax_error, metta_host_interrupted,
                                inference_limit_exceeded])) ]) :-
    metta_host_error_kind(error(type_error(Sentinel, oops), none), Kind, Fields),
    assertion(Kind == engine),
    assertion(Fields == []).

%SWI's own resource ball, which reaches a seat unenveloped when the goal that
%spent the budget was a nested query: it names the resource and cannot name
%the number, so the field is absent rather than zero.
test(a_nested_bound_names_no_number) :-
    metta_host_error_kind(inference_limit_exceeded, inference_limit, Inferences),
    assertion(Inferences == []),
    metta_host_error_kind(time_limit_exceeded, time_limit, Seconds),
    assertion(Seconds == []).

%The ceiling that was in force when the stack ran out, not the one in force
%when the classifier runs: a scope that raised the limit and unwound has
%already put the flag back.
test(the_stack_ceiling_is_the_one_the_ball_recorded) :-
    current_prolog_flag(stack_limit, Now),
    metta_host_error_kind(error(resource_error(stack), stack_overflow{stack_limit: 4096}),
                          stack, [limit-Recorded]),
    assertion(Recorded == 4194304),
    assertion(Recorded \== Now),
    %A resource ball with no dict to read falls back to the flag rather than
    %answering no ceiling at all.
    metta_host_error_kind(error(resource_error(stack), none), stack, [limit-Fallback]),
    assertion(Fallback == Now).

:- end_tests(error_kinds).
