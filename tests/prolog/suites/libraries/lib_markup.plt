% Purpose: check the markup library against the host's own parser and xpath, the
% write-and-parse round trip over generated documents, and the refusals that turn
% the host's repairs and warnings into errors.
% Guarantees: a parse answers the host's DOM in this library's shape, every selector
% answers what the equivalent xpath term answers, writing an element parses back to
% it over generated documents, and a malformed document, an external entity and an
% unknown selector form are each refused by name [tested: lib_markup; commit=ed976b0e70c1176a7ef9feabb0359313105c786e].
% Owns resources: none; every value is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, nth1/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(sgml), [load_xml/3]).
:- use_module(library(xpath), [xpath/3]).
:- use_module(library(random), [random_between/3]).
:- initialization(consult('../../lib/lib_markup/lib_markup.pl')).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_markup).

% A random element tree, three levels deep at most, with attributes whose names
% include ones the engine knows as functions, and text with characters the writer
% has to escape.
random_element(Depth, [element, Name, Attributes, Children]) :-
    random_between(1, 4, Which), nth1(Which, [a, b, item, id], Name),
    random_between(0, 2, AttributeCount),
    length(Attributes, AttributeCount),
    maplist([[attr, AttrName, Value]]>>( random_between(1, 3, W), nth1(W, [id, class, n], AttrName),
                                        random_between(1, 3, V), nth1(V, ["1", "x y", "a&b"], Value) ),
            Attributes),
    random_between(0, 3, ChildCount),
    length(Children, ChildCount),
    maplist(random_child(Depth), Children).

random_child(Depth, Child) :-
    (   Depth > 0, random_between(0, 1, 1)
    ->  Deeper is Depth - 1, random_element(Deeper, Child)
    ;   random_between(1, 3, W), nth1(W, ["text", "<escaped>", "a&b"], Child)
    ).

% The shape against the host's own DOM: every element the host answers becomes
% (element Name Attributes Children) with tagged attributes and String text.
test(a_parse_is_the_hosts_dom_in_this_shape) :-
    Text = "<order id='7'><item sku='a'>apple</item><item sku='b'>pear</item><note/></order>",
    'markup-parse-xml'(Text, Element),
    assertion(Element == [element, order, [[attr, id, "7"]],
                          [[element, item, [[attr, sku, "a"]], ["apple"]],
                           [element, item, [[attr, sku, "b"]], ["pear"]],
                           [element, note, [], []]]]),
    load_xml(string(Text), [DOM], [space(preserve)]),
    shaped(DOM, Shaped), assertion(Shaped == Element),
    'markup-text'(Element, AllText), assertion(AllText == "applepear"),
    'markup-attribute'(Element, id, Id), assertion(Id == "7"),
    assertion(\+ 'markup-attribute'(Element, missing, _)).

shaped(element(Name, Attributes, Children), [element, Name, Rows, Parts]) :-
    !,
    maplist([N=V, [attr, N, S]]>>atom_string(V, S), Attributes, Rows),
    maplist(shaped, Children, Parts).
shaped(Atom, String) :- atom_string(Atom, String).

% Every selector against the xpath term it stands for, over the same document.
test(every_selector_answers_once_per_match) :-
    Text = "<d><a><i n='1'>one</i><i n='2'>two</i></a><i n='3'>three</i></d>",
    'markup-parse-xml'(Text, Element),
    load_xml(string(Text), [DOM], [space(preserve)]),
    forall(member(Selector-Spec,
                  [[descendant, i]-(//(i)),
                   [child, a]-a,
                   [[descendant, i], [text]]-(//(i(text))),
                   [[descendant, i], [attribute, n]]-(//(i(@(n)))),
                   [[descendant, i], [index, 2]]-(//(i(2))),
                   [[child, a], [child, i], [text]]-(a/i(text)),
                   [[descendant, a], [descendant, i]]-(//(a)/(//(i))),
                   [self, d]-(/(d)),
                   [descendant, missing]-(//(missing))]),
           ( findall(V, 'markup-select'(Element, Selector, V), Answers),
             findall(S, ( xpath(DOM, Spec, Found), selected(Found, S) ), Expected),
             assertion(Answers == Expected) )).

selected(Found, Shaped) :-
    (   Found = element(_, _, _) -> shaped(Found, Shaped)
    ;   atom(Found) -> atom_string(Found, Shaped)
    ;   Shaped = Found
    ).

% Writing then parsing gives back the element, over generated trees whose text and
% attribute values carry the characters the writer has to escape. The law is up to
% text MERGING: two adjacent text nodes are one run of characters in the markup, so
% they come back as one node, and an empty text node has no markup at all. Both
% sides are merged before the comparison, which is the strongest law an XML round
% trip has [measured 2026-09-12: (element a () ("a&b" "text")) writes as
% <a>a&amp;btext</a> and parses back with one child].
test(writing_and_parsing_round_trip) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_element(2, Element),
             'markup-write'(Element, Text),
             'markup-parse-xml'(Text, Again),
             merged(Element, Expected), merged(Again, Answered),
             assertion(Answered == Expected) )),
    'markup-write'([element, empty, [], []], Empty), assertion(Empty == "<empty/>"),
    'markup-write'([element, a, [[attr, n, 1], [attr, k, sym]], []], Typed),
    assertion(Typed == "<a n=\"1\" k=\"sym\"/>").

% An element with its adjacent text runs joined and its empty text nodes dropped,
% which is what markup can express.
merged([element, Name, Attributes, Children], [element, Name, Attributes, Merged]) :-
    !,
    maplist(merged, Children, Walked),
    merged_text(Walked, Merged).
merged(Other, Other).

merged_text([], []).
merged_text([Text, Next|Rest], Merged) :-
    string(Text), string(Next), !,
    string_concat(Text, Next, Joined),
    merged_text([Joined|Rest], Merged).
merged_text([Text|Rest], Merged) :-
    string(Text), Text == "", !,
    merged_text(Rest, Merged).
merged_text([Part|Rest], [Part|Merged]) :-
    merged_text(Rest, Merged).

% The host repairs a missing end tag, a stray close tag and stray text with a
% warning and a DOM; every one is a refusal here, and the message is the host's.
test(a_malformed_document_is_refused_rather_than_repaired) :-
    forall(member(Text, ["<a><b></a>", "<a>", "not markup at all", "", "<a></a><b></b>"]),
           ( catch('markup-parse-xml'(Text, _), Error, true),
             assertion(nonvar(Error)),
             assertion(( Error = error(syntax_error(markup(_)), _)
                       ; Error = error(domain_error(one_root_element, _), _) )) )),
    % HTML's own rules allow an omitted end tag, so that parses, while a stray close
    % tag is still a refusal.
    'markup-parse-html'("<p>one<p>two", Html),
    assertion(Html == [element, p, [], ["one", [element, p, [], ["two"]]]]),
    must_throw('markup-parse-xml'(7, _), error(type_error(string, 7), _)).

% An external SYSTEM entity is refused, and the file it names is never read: the
% host's default declines it with a warning and an empty element, and the warning
% is an error here.
test(an_external_entity_is_refused_and_never_fetched) :-
    must_throw('markup-parse-xml'("<!DOCTYPE d [<!ENTITY e SYSTEM '/etc/passwd'>]><d>&e;</d>", _),
               error(syntax_error(markup(_)), _)),
    must_throw('markup-parse-xml'("<!DOCTYPE d [<!ENTITY e SYSTEM 'http://example.invalid/x'>]><d>&e;</d>", _),
               error(syntax_error(markup(_)), _)),
    % An internal entity is data and is expanded.
    'markup-parse-xml'("<!DOCTYPE d [<!ENTITY e 'inner'>]><d>&e;</d>", Internal),
    assertion(Internal == [element, d, [], ["inner"]]).

% An unknown selector form, a modifier with nothing to modify and a value that is
% not an element are each refused by name.
test(an_unknown_selector_form_is_refused) :-
    'markup-parse-xml'("<d/>", Element),
    must_throw('markup-select'(Element, [nosuch, i], _),
               error(domain_error(markup_selector, [nosuch, i]), _)),
    must_throw('markup-select'(Element, [[text], [descendant, i]], _),
               error(domain_error(markup_selector, [text]), _)),
    must_throw('markup-select'(Element, [index, 1], _),
               error(domain_error(markup_selector, [index, 1]), _)),
    must_throw('markup-select'(Element, [index, 0], _),
               error(domain_error(markup_selector, [index, 0]), _)),
    catch('markup-select'(Element, [nosuch, i], _), error(_, context(_, Names)), true),
    assertion(memberchk(descendant, Names)), assertion(memberchk(self, Names)),
    must_throw('markup-text'(notanelement, _), error(type_error(markup_element, notanelement), _)),
    must_throw('markup-write'([nosuch], _), error(type_error(markup_element, [nosuch]), _)),
    must_throw('markup-write'([element, a, [[id, "7"]], []], _),
               error(type_error(markup_attribute, [id, "7"]), _)),
    must_throw('markup-attribute'(7, id, _), error(type_error(markup_element, 7), _)).

:- end_tests(lib_markup).
