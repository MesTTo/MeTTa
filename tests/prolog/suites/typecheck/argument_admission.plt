% Purpose: pin what the engine answers a host that asks whether a value would
%   be admitted for a declared parameter type under a space's typing policy.
% Assumes: each case owns a fresh space and releases it.
% Guarantees:
%   - the wildcards admit everything, a metatype admits by the value's own
%     metatype, and an ordinary type admits by the value's reported type
%     [tested: argument_admission:the_wildcards_admit_everything,
%     argument_admission:a_metatype_admits_by_the_values_metatype,
%     argument_admission:an_ordinary_type_admits_by_the_reported_type;
%     commit=e492f2a5bb995b6c2b86bdeb90cb1d2f27282b07]
%   - a user typing rule declared in the space reaches the answer, widening
%     one pair and refusing another [tested:
%     argument_admission:a_user_rule_reaches_the_answer; commit=e492f2a5bb995b6c2b86bdeb90cb1d2f27282b07]
% Owns resources: setup/cleanup releases each space; no file is written.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(argument_admission).

context(Space) :- 'new-space'(Space).

release_quietly(Space) :- catch(metta_release_space(Space), _, true).

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

test(the_wildcards_admit_everything,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    assertion(metta_argument_admitted(S, 3, 'Atom')),
    assertion(metta_argument_admitted(S, "s", '%Undefined%')),
    assertion(metta_argument_admitted(S, [f, 1], 'Atom')),
    assertion(metta_argument_admitted(S, 3, _)).

test(a_metatype_admits_by_the_values_metatype,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    assertion(metta_argument_admitted(S, foo, 'Symbol')),
    assertion(\+ metta_argument_admitted(S, 3, 'Symbol')),
    assertion(metta_argument_admitted(S, [f, 1], 'Expression')),
    assertion(\+ metta_argument_admitted(S, 3, 'Expression')),
    assertion(metta_argument_admitted(S, 3, 'Grounded')),
    assertion(metta_argument_admitted(S, _, 'Variable')).

test(an_ordinary_type_admits_by_the_reported_type,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    run_in(S, "(: b Bespoke)", _),
    assertion(metta_argument_admitted(S, 3, 'Number')),
    assertion(\+ metta_argument_admitted(S, "s", 'Number')),
    assertion(metta_argument_admitted(S, b, 'Bespoke')),
    assertion(\+ metta_argument_admitted(S, 3, 'Bespoke')),
    assertion(metta_argument_admitted(S, undeclared, 'Bespoke')).

test(a_user_rule_reaches_the_answer,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    run_in(S, "(: b Bespoke) !(add-typing-rule! widen ordinary String Bespoke Accept) !(add-typing-rule! deny ordinary Number Number (Refuse denied))", _),
    assertion(metta_argument_admitted(S, "s", 'Bespoke')),
    assertion(\+ metta_argument_admitted(S, 3, 'Number')).

:- end_tests(argument_admission).
