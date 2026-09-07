% Purpose: hold the (refusal ...) catalog rows to the engine's own kind table,
%   to one meaning per class, to the three closed vocabularies their ground and
%   remedy name, and to filling every hole a raised ball can fill.
% Assumes:
%   - engine/spaces/catalog.pl presets one row per metta_refusal_declaration/4
%     and engine/metta/registration.pl reads them back through
%     metta_host_refusal_row/4 and metta_host_refusal/6.
% Guarantees:
%   - the rows and metta_host_error_kind_row/3 name the same kinds, both ways,
%     and the `refusal-kind` vocabulary is that same set
%     [tested: the_refusal_rows_are_the_engines_own_kinds,
%     the_refusal_kind_vocabulary_is_the_rows]
%   - one class name per meaning, and the check is not vacuous
%     [tested: every_row_names_one_meaning,
%     the_duplicate_check_sees_a_planted_duplicate]
%   - every ground and remedy names an admitted word, a metta-law citation
%     names a law and an arbiter citation names the captured corpus, and the
%     check is not vacuous [tested: every_row_stands_on_an_admitted_authority,
%     the_authority_check_sees_a_planted_citation]
%   - a title's holes are fields that kind declares, so a rendered remedy
%     never shows a hole the engine could have filled
%     [tested: every_title_hole_is_a_declared_field,
%     the_hole_check_sees_a_planted_hole]
%   - a filled act carries the row's own applicability and an act with a hole
%     left in it stays prose [tested: a_filled_act_keeps_the_rows_applicability,
%     an_unfilled_act_is_prose]
%   - a kind whose row was removed answers no refusal while still classifying
%     [tested: a_kind_without_a_row_answers_no_refusal]
%   - a row for a kind the engine does not declare cannot be written at all,
%     because the row's first position is (one-of refusal-kind) and that
%     vocabulary is derived from the declarations
%     [tested: a_row_for_an_undeclared_kind_is_refused_at_the_door]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(catalog_refusal_rows).

rows(Rows) :-
    findall(row(Kind, Class, Ground, Remedy),
            metta_host_refusal_row(Kind, Class, Ground, Remedy),
            Rows).

%Two rows that give one class name are two spellings of one meaning, which is
%what "one Error per meaning" forbids. Written over a LIST so the plant below
%can hand it a list the catalog does not hold.
duplicate_meaning(Rows, Class) :-
    select(row(_, Class, _, _), Rows, Rest),
    memberchk(row(_, Class, _, _), Rest).

%The same reading tests/checks/check_refusal_grounds.py makes of a Python-side
%ground, over the rows: an admitted authority, and a citation that names the
%place rather than describing it.
grounded(row(_, _, [ground, Authority, Citation], _)) :-
    metta_vocabulary_value('ground-kind', Authority),
    grounded_citation(Authority, Citation).

grounded_citation('metta-law', Citation) :-
    sub_string(Citation, _, _, _, "HostLaws").
grounded_citation(arbiter, Citation) :-
    sub_string(Citation, _, _, _, "tests/conformance/petta").
%The engine names no host, so the authority is `host-reference` and the
%CITATION is the one place a host may appear: the Python seat cites its
%Language Reference, and a section number is what makes that checkable.
grounded_citation('host-reference', Citation) :-
    sub_string(Citation, _, _, _, "Language Reference section").

remedy_words(row(_, _, _, [remedy, _, Kind, Applicability|_])) :-
    metta_vocabulary_value('remedy-kind', Kind),
    metta_vocabulary_value(applicability, Applicability).

%Each <name> a title carries, as an atom.
title_hole(Title, Name) :-
    split_string(Title, "<", "", [_|Tails]),
    member(Tail, Tails),
    sub_string(Tail, Before, _, _, ">"),
    sub_string(Tail, 0, Before, _, Text),
    atom_string(Name, Text).

test(the_refusal_rows_are_the_engines_own_kinds) :-
    findall(Kind, metta_host_error_kind_row(Kind, _, _), Declared0),
    msort(Declared0, Declared),
    findall(Kind, metta_host_refusal_row(Kind, _, _, _), Rowed0),
    msort(Rowed0, Rowed),
    assertion(Declared == Rowed).

test(the_refusal_kind_vocabulary_is_the_rows) :-
    once(metta_catalog_row([vocabulary, 'refusal-kind'|Members])),
    findall(Kind, metta_host_refusal_row(Kind, _, _, _), Kinds),
    assertion(Members == Kinds).

test(every_row_names_one_meaning) :-
    rows(Rows),
    assertion(\+ duplicate_meaning(Rows, _)).

%A clean result above says nothing unless the check can go red: two rows given
%one class name are found, and the class it names is the shared one.
test(the_duplicate_check_sees_a_planted_duplicate) :-
    rows(Rows),
    Rows = [row(_, Class, Ground, Remedy)|_],
    assertion(duplicate_meaning([row(planted, Class, Ground, Remedy)|Rows], Class)).

test(every_row_stands_on_an_admitted_authority,
     [ forall(metta_host_refusal_row(Kind, Class, Ground, Remedy)) ]) :-
    Row = row(Kind, Class, Ground, Remedy),
    assertion(grounded(Row)),
    assertion(remedy_words(Row)).

test(the_authority_check_sees_a_planted_citation) :-
    assertion(\+ grounded(row(planted, 'X',
                              [ground, 'metta-law', "this engine says so"],
                              [remedy, "x", quickfix, prose]))),
    assertion(\+ grounded(row(planted, 'X',
                              [ground, arbiter, "upstream agrees"],
                              [remedy, "x", quickfix, prose]))),
    assertion(\+ grounded(row(planted, 'X',
                              [ground, hearsay, "HostLaws: anything"],
                              [remedy, "x", quickfix, prose]))).

%A title may only ask for what the ball can carry. An ACT's hole is the
%reader's own choice and is exempt: (pragma! max-time <seconds>) names a bound
%the engine has no opinion about, and leaving it is what keeps the remedy
%prose.
test(every_title_hole_is_a_declared_field,
     [ forall(metta_host_refusal_row(Kind, _, _, [remedy, Title|_])) ]) :-
    metta_host_error_kind_row(Kind, _, Fields),
    forall(title_hole(Title, Hole), assertion(memberchk(Hole, Fields))).

test(the_hole_check_sees_a_planted_hole) :-
    findall(Hole, title_hole("give <operation> a <expected>", Hole), Holes),
    assertion(Holes == [operation, expected]),
    metta_host_error_kind_row(assertion, _, Fields),
    assertion(\+ memberchk(expected, Fields)).

test(a_filled_act_keeps_the_rows_applicability) :-
    metta_host_refusal(
        error(metta_space_capability_required('&restricted', 'add-atom', process), none),
        capability, _, Class,
        [ground, 'metta-law', _],
        [remedy, Title, quickfix, Applicability, [edit, Edit]]),
    assertion(Class == 'SpaceCapabilityError'),
    assertion(Applicability == maybe),
    assertion(Edit == [grants, '&restricted', process]),
    assertion(\+ title_hole(Title, _)).

test(an_unfilled_act_is_prose) :-
    metta_host_refusal(
        error(metta_control_signal(time_limit, 0.05), context(metta, time_limit)),
        time_limit, _, 'TimeLimitError', _,
        [remedy, Title, quickfix, Applicability, [edit, Edit]]),
    %The row declares prose already, so the case that matters is the value the
    %hole DID fill beside the one it could not.
    assertion(Applicability == prose),
    assertion(Edit == ['pragma!', 'max-time', '<seconds>']),
    assertion(sub_string(Title, _, _, _, "0.05")).

%The `refusal` kind's first position is (one-of refusal-kind) and that
%vocabulary is derived from the declarations, so a row for a kind the engine
%does not declare cannot be written at all: the catalog's own door refuses it
%and names the argspec it missed. A program that means to add one widens the
%vocabulary first, which is the remove-then-redeclare loosening this catalog
%documents.
test(a_row_for_an_undeclared_kind_is_refused_at_the_door) :-
    catch(add_sexp('&metta',
                   [refusal, 'no-such-kind', 'ProbeError',
                    [ground, 'metta-law', "HostLaws: a planted row"],
                    [remedy, "do something", quickfix, prose]],
                   _),
          error(Formal, _), true),
    assertion(Formal = metta_declaration_malformed(_, 1,
                                                   ['one-of', 'refusal-kind'])),
    assertion(\+ metta_catalog_row([refusal, 'no-such-kind'|_])).

test(a_kind_without_a_row_answers_no_refusal,
     [ setup(metta_host_refusal_row(engine, Class, Ground, Remedy)),
       cleanup(add_sexp('&metta', [refusal, engine, Class, Ground, Remedy], _)) ]) :-
    remove_sexp('&metta', [refusal, engine, Class, Ground, Remedy]),
    Ball = error(type_error(metta_syntax_error, oops), none),
    assertion(\+ metta_host_refusal(Ball, _, _, _, _, _)),
    metta_host_error_kind(Ball, Kind, Fields),
    assertion(Kind == engine),
    assertion(Fields == []).

:- end_tests(catalog_refusal_rows).
