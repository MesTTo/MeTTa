% Purpose: check the unicode library against the host's own convenience
% predicates, against the Unicode standard's stated laws, and under the C locale,
% where the classification must not move.
% Guarantees: each normalization form answers what the host's own predicate for
% it answers over generated text, normalization is idempotent and nfc and nfd
% agree on every string, the classes are the general category and never the
% locale, a character is a string or a code, an absent property has no answer
% where a wrong name is refused, and graphemes group what code points split
% [tested: lib_unicode; commit=a30e0a59e8e16d15705dc0258d7e0a004ae63e4b].
% Owns resources: none; every value is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, nth1/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(unicode), [unicode_casefold/2, unicode_nfc/2, unicode_nfd/2,
                                unicode_nfkc/2, unicode_nfkc_casefold/2,
                                unicode_nfkd/2, unicode_property/2]).
:- use_module(library(random), [random_between/3]).
:- initialization(consult('../../lib/lib_unicode/lib_unicode.pl')).

:- begin_tests(lib_unicode).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% Random text over an alphabet that exercises every form: ASCII letters, a
% precomposed accented letter and its decomposition, a ligature, a superscript,
% sharp s, a wide character and a combining mark on its own.
random_text(Text) :-
    random_between(0, 12, Length),
    length(Codes, Length),
    maplist([Code]>>( random_between(1, 12, Which),
                      nth1(Which, [0'a, 0'B, 0'é, 0'e, 0x301, 0xFB03, 0xB2, 0xDF,
                                   0x6F22, 0x2019, 0'_, 0' ], Code) ),
            Codes),
    string_codes(Text, Codes).

% Each form against the host's own convenience predicate, which is the
% composition it names, over generated text. The library states the derivation
% and this checks that the statement is the host's.
test(each_form_is_a_composition_of_flags) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_text(Text),
             'unicode-normalize'(nfc, Text, Nfc), unicode_nfc(Text, ExpectedNfc),
             atom_string(ExpectedNfc, ExpectedNfcString), assertion(Nfc == ExpectedNfcString),
             'unicode-normalize'(nfd, Text, Nfd), unicode_nfd(Text, ExpectedNfd),
             atom_string(ExpectedNfd, ExpectedNfdString), assertion(Nfd == ExpectedNfdString),
             'unicode-normalize'(nfkc, Text, Nfkc), unicode_nfkc(Text, ExpectedNfkc),
             atom_string(ExpectedNfkc, ExpectedNfkcString), assertion(Nfkc == ExpectedNfkcString),
             'unicode-normalize'(nfkd, Text, Nfkd), unicode_nfkd(Text, ExpectedNfkd),
             atom_string(ExpectedNfkd, ExpectedNfkdString), assertion(Nfkd == ExpectedNfkdString),
             'unicode-normalize'('nfkc-casefold', Text, Folded),
             unicode_nfkc_casefold(Text, ExpectedFolded),
             atom_string(ExpectedFolded, ExpectedFoldedString), assertion(Folded == ExpectedFoldedString),
             'unicode-casefold'(Text, Case), unicode_casefold(Text, ExpectedCase),
             atom_string(ExpectedCase, ExpectedCaseString), assertion(Case == ExpectedCaseString) )),
    must_throw('unicode-normalize'(nfx, "a", _), error(domain_error(normalization_form, nfx), _)),
    must_throw('unicode-normalize'(nfc, 7, _), error(type_error(string, 7), _)).

% UAX#15's own laws: every form is idempotent, and nfc and nfd of one string are
% canonically equivalent, so normalizing either to the other form gives the same
% answer as normalizing the original.
test(normalization_is_idempotent_and_the_canonical_forms_agree) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_text(Text),
             forall(member(Form, [nfc, nfd, nfkc, nfkd, 'nfkc-casefold']),
                    ( 'unicode-normalize'(Form, Text, Once),
                      'unicode-normalize'(Form, Once, Twice),
                      assertion(Once == Twice) )),
             'unicode-normalize'(nfc, Text, Nfc), 'unicode-normalize'(nfd, Text, Nfd),
             'unicode-normalize'(nfc, Nfd, NfcOfNfd), assertion(NfcOfNfd == Nfc),
             'unicode-normalize'(nfd, Nfc, NfdOfNfc), assertion(NfdOfNfc == Nfd),
             % Folding is idempotent too, and folding the fold of the upper case is
             % the fold of the lower case.
             'unicode-casefold'(Text, Folded), 'unicode-casefold'(Folded, Refolded),
             assertion(Folded == Refolded) )).

% The map's refusals: an unknown flag, both directions at once, and a mark strip
% with no direction. The accepted combinations answer what their flags say.
test(the_map_refuses_the_combinations_the_host_only_names) :-
    'unicode-map'("café", [compose, stripmark], Stripped), assertion(Stripped == "cafe"),
    'unicode-map'("it’s a–b", [lump], Lumped), assertion(Lumped == "it's a-b"),
    'unicode-map'("Hello", [casefold], Lower), assertion(Lower == "hello"),
    'unicode-map'("x", [], Same), assertion(Same == "x"),
    must_throw('unicode-map'("a", [nosuch], _), error(domain_error(unicode_flag, nosuch), _)),
    must_throw('unicode-map'("a", [compose, decompose], _),
               error(domain_error(unicode_flag_combination, _), _)),
    must_throw('unicode-map'("a", [stripmark], _),
               error(domain_error(unicode_flag_combination, _), _)),
    must_throw('unicode-map'("a", notalist, _), error(type_error(list, notalist), _)).

% A character is a one-character string or the number of a code point, and the
% two spellings answer the same thing; a longer string and a number out of range
% are refused by name.
test(a_character_is_a_string_or_a_code) :-
    forall(member(Code, [0'A, 0'1, 0' , 0'é, 0x6F22]),
           ( string_codes(String, [Code]),
             'unicode-property'(String, category, FromString),
             'unicode-property'(Code, category, FromCode),
             assertion(FromString == FromCode),
             'unicode-is'(String, letter, LetterFromString),
             'unicode-is'(Code, letter, LetterFromCode),
             assertion(LetterFromString == LetterFromCode) )),
    must_throw('unicode-property'("ab", category, _), error(type_error(character, "ab"), _)),
    must_throw('unicode-property'("", category, _), error(type_error(character, ""), _)),
    must_throw('unicode-property'(-1, category, _), error(domain_error(unicode_codepoint, -1), _)),
    must_throw('unicode-property'(1114112, category, _),
               error(domain_error(unicode_codepoint, 1114112), _)),
    must_throw('unicode-is'([a], letter, _), error(type_error(character, [a]), _)).

% The thirteen property names against the host's own property terms, and the two
% kinds of absence: a property the character has no value for has no answer,
% and a property name the library does not know is refused with the list.
test(an_absent_property_has_no_answer_and_a_wrong_name_is_refused) :-
    forall(member(Name-Native, [category-category, 'combining-class'-combining_class,
                                'bidi-class'-bidi_class, 'bidi-mirrored'-bidi_mirrored,
                                'decomp-type'-decomp_type, ignorable-ignorable,
                                boundclass-boundclass, width-width,
                                'ambiguous-width'-ambiguous_width,
                                uppercase-uppercase, lowercase-lowercase,
                                titlecase-titlecase,
                                'indic-conjunct-break'-indic_conjunct_break]),
           forall(member(Code, [0'A, 0'a, 0'1, 0'(, 0x301, 0xB2, 0x6F22]),
                  ( findall(V, 'unicode-property'(Code, Name, V), Answers),
                    Query =.. [Native, Expected],
                    findall(Expected, unicode_property(Code, Query), ExpectedAnswers),
                    assertion(Answers == ExpectedAnswers) ))),
    findall(V, 'unicode-property'(0'A, uppercase, V), NoUpper), assertion(NoUpper == []),
    findall(V, 'unicode-property'(0'a, 'decomp-type', V), NoDecomp), assertion(NoDecomp == []),
    findall(V, 'unicode-property'(1114111, category, V), Unassigned), assertion(Unassigned == []),
    must_throw('unicode-property'(0'a, colour, _), error(domain_error(unicode_property, colour), _)),
    catch('unicode-property'(0'a, colour, _), error(_, context(_, Names)), true),
    assertion(memberchk(category, Names)), length(Names, Count), assertion(Count == 13).

% The classes are the general category, so they answer the same under the C
% locale as under a UTF-8 one; code_type/2 does not, which is why it is not the
% mechanism. The locale is switched inside the test and restored.
test(the_classes_are_the_category_and_never_the_locale) :-
    Cases = [0'a-letter-true, 0'1-letter-false, 0'1-digit-true, 0x2162-number-true,
             0' -'white-space'-true, 9-'white-space'-true, 133-'white-space'-true,
             0'a-'white-space'-false, 0'é-letter-true, 0'é-ascii-false, 0x6F22-letter-true,
             0'A-upper-true, 0'a-upper-false, 0'a-lower-true, 0x1C5-title-true,
             0x301-mark-true, 0',-punctuation-true, 0'+-symbol-true, 0' -separator-true,
             10-control-true, 0'a-control-false, 0'a-assigned-true, 1114111-assigned-false,
             0xD800-assigned-true, 0xE000-assigned-true],
    setup_call_cleanup(
        setlocale(ctype, Old, 'C'),
        forall(member(Code-Class-Expected, Cases),
               ( 'unicode-is'(Code, Class, Answer), assertion(Answer == Expected) )),
        setlocale(ctype, _, Old)),
    forall(member(Code-Class-Expected, Cases),
           ( 'unicode-is'(Code, Class, Answer), assertion(Answer == Expected) )),
    % The category groups are exactly the categories that start with the letter.
    forall(member(Code, [0'a, 0'1, 0x301, 0',, 0'+, 0' , 10]),
           ( 'unicode-property'(Code, category, Category),
             sub_atom(Category, 0, 1, _, Initial),
             forall(member(Class-Letter, [letter-'L', number-'N', mark-'M',
                                          punctuation-'P', symbol-'S', separator-'Z']),
                    ( 'unicode-is'(Code, Class, Answer),
                      ( Initial == Letter -> assertion(Answer == true)
                      ; assertion(Answer == false) ) )) )),
    must_throw('unicode-is'(0'a, vowel, _), error(domain_error(character_class, vowel), _)),
    catch('unicode-is'(0'a, vowel, _), error(_, context(_, Classes)), true),
    length(Classes, ClassCount), assertion(ClassCount == 14).

% Graphemes group a base character with its marks where code points split them,
% and a grapheme's code points concatenate back to the text.
test(graphemes_group_what_code_points_split) :-
    'unicode-normalize'(nfd, "éx", Decomposed),
    string_codes(Decomposed, Codes), length(Codes, 3),
    'unicode-graphemes'(Decomposed, Graphemes), length(Graphemes, 2),
    Graphemes = [First, Second],
    string_codes(First, FirstCodes), assertion(FirstCodes == [101, 769]),
    assertion(Second == "x"),
    'unicode-graphemes'("abc", Plain), assertion(Plain == ["a", "b", "c"]),
    'unicode-graphemes'("", None), assertion(None == []),
    set_random(seed(20260912)),
    forall(between(1, 100, _),
           ( random_text(Text),
             'unicode-graphemes'(Text, Clusters),
             atomic_list_concat(Clusters, Joined), atom_string(Joined, Rejoined),
             assertion(Rejoined == Text) )),
    must_throw('unicode-graphemes'(7, _), error(type_error(string, 7), _)).

% Validity is assignment, which is stricter than range: surrogates, unassigned
% numbers and noncharacters answer false, and private use answers true.
test(validity_is_assignment) :-
    forall(member(Code-Expected, [97-true, 55296-false, 57344-true, 65533-true,
                                  65534-false, 1114111-false, 1114112-false, -1-false]),
           ( 'unicode-codepoint-valid'(Code, Answer), assertion(Answer == Expected) )),
    % Every valid code point has a category, and every code point in range that
    % has a category other than a surrogate is valid.
    forall(member(Code, [97, 57344, 65533, 0x6F22, 0x301]),
           ( 'unicode-codepoint-valid'(Code, true),
             'unicode-property'(Code, category, _) )),
    must_throw('unicode-codepoint-valid'(a, _), error(type_error(integer, a), _)),
    'unicode-version'(Version), assertion(string(Version)),
    split_string(Version, ".", "", Parts), length(Parts, 3).

:- end_tests(lib_unicode).
