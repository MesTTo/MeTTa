% Purpose: check the decode against the host's own reader, the round trip in both
% directions, and the four refusals the library makes where the host is silent.
% Guarantees: every value the library decodes encodes back to text that decodes to
% the same value, the mapping shape is lib_json's, and a multi-document stream, an
% unknown tag, a duplicate key and malformed text are each refused by name
% [tested: lib_yaml; commit=672e5be181839a8301ba70bc6ead69678f3735bd].
% Owns resources: the mappings a decode answers are spaces the test releases.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, nth0/3]).
:- use_module(library(yaml), [yaml_read/2]).
:- initialization(consult('../../lib/lib_yaml/lib_yaml.pl')).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_yaml).

% Every scalar shape the host's reader can answer, against what the library makes
% of it: the library's job over a scalar is the type mapping and nothing else.
test(the_scalars_are_the_hosts_own_values) :-
    forall(member(Text-Expected, ["7\n"-7, "1.5\n"-1.5, "text\n"-"text",
                                  "true\n"-true, "false\n"-false, "null\n"-'Null',
                                  "~\n"-'Null', "\"no\"\n"-"no", "no\n"-"no",
                                  ""-'Null', "   \n"-'Null',
                                  "# only a comment\n"-'Null']),
           ( 'yaml-decode'(Text, Value), assertion(Value == Expected) )),
    % A sequence is an expression, nested all the way down.
    'yaml-decode'("- 1\n- - 2\n  - 3\n", Nested),
    assertion(Nested == [1, [2, 3]]),
    'yaml-decode'("[]\n", Empty), assertion(Empty == []).

% A mapping is a space of (Key Value) atoms, which is lib_json's shape, and the
% keys are the host's own symbols: the check is against the reader's dict.
test(a_mapping_is_a_space_of_pairs) :-
    Text = "a: 1\nb: two\nc:\n  d: 3\n",
    'yaml-decode'(Text, Space),
    setup_call_cleanup(open_string(Text, Stream), yaml_read(Stream, Dict), close(Stream)),
    dict_pairs(Dict, _, Pairs),
    findall(Key, member(Key-_, Pairs), Keys), msort(Keys, SortedKeys),
    findall(Key, 'get-atoms'(Space, [Key, _]), Answered), msort(Answered, SortedAnswered),
    assertion(SortedAnswered == SortedKeys),
    'get-atoms'(Space, [a, One]), assertion(One == 1),
    'get-atoms'(Space, [b, Two]), assertion(Two == "two"),
    'get-atoms'(Space, [c, Inner]),
    'get-atoms'(Inner, [d, Three]), assertion(Three == 3),
    % An omitted value is the empty string and not null, which is the host's own
    % divergence from YAML 1.2 and the reason a document that means null writes ~.
    'yaml-decode'("k:\n", Omitted), 'get-atoms'(Omitted, [k, Value]),
    assertion(Value == ""),
    'yaml-decode'("k: ~\n", Explicit), 'get-atoms'(Explicit, [k, Null]),
    assertion(Null == 'Null').

test(an_omitted_value_is_the_empty_string_and_not_null) :-
    'yaml-decode'("note:\n", Space), 'get-atoms'(Space, [note, Value]),
    assertion(Value == ""),
    setup_call_cleanup(open_string("note:\n", Stream), yaml_read(Stream, Dict), close(Stream)),
    get_dict(note, Dict, Raw), assertion(Raw == "").

% The round trip in both directions over every value the library can make, which
% is the one law an encoder and a decoder owe each other.
test(decoding_and_encoding_round_trip) :-
    forall(member(Text, ["7\n", "1.5\n", "text\n", "true\n", "null\n",
                         "- 1\n- 2\n", "a: 1\nb: two\n", "a:\n  b:\n    c: 1\n",
                         "- a: 1\n- b: 2\n", "[]\n"]),
           ( 'yaml-decode'(Text, Value),
             'yaml-encode'(Value, Written),
             'yaml-decode'(Written, Again),
             same_value(Value, Again) )),
    % Encoding a value the library did not decode works the same way, because the
    % shapes are the language's own.
    'yaml-encode'([1, 2, 'Null', true], Sequence),
    assertion(Sequence == "- 1\n- 2\n- null\n- true\n"),
    'yaml-encode'("text", Scalar), assertion(Scalar == "text\n"),
    'yaml-encode'('Null', Null), assertion(Null == "null\n"),
    'yaml-encode'([one, two], Symbols), assertion(Symbols == "- one\n- two\n").

% Two decoded values are the same when their scalars are equal, their sequences
% agree element by element, and their mappings hold the same pairs: a space has no
% other equality, because two decodes of one document are two different spaces.
same_value(Left, Right) :-
    (   is_list(Left)
    ->  assertion(is_list(Right)),
        length(Left, Count), length(Right, Count),
        forall(nth0(Index, Left, LeftItem),
               ( nth0(Index, Right, RightItem), same_value(LeftItem, RightItem) ))
    ;   space_pairs(Left, LeftPairs)
    ->  space_pairs(Right, RightPairs),
        same_pairs(LeftPairs, RightPairs)
    ;   assertion(Left == Right)
    ).

space_pairs(Value, Sorted) :-
    metta_space_operand(Value),
    findall(Pair, 'get-atoms'(Value, Pair), Pairs),
    msort(Pairs, Sorted).

same_pairs([], []).
same_pairs([[Key, LeftValue]|Left], [[Key, RightValue]|Right]) :-
    same_value(LeftValue, RightValue),
    same_pairs(Left, Right).

% The host's reader FAILS on a stream with more than one document, whatever markers
% it carries, so the library refuses naming the marker rather than answering the
% first document or nothing at all.
test(a_multi_document_stream_is_refused_by_name) :-
    forall(member(Text, ["a: 1\n---\nb: 2\n", "---\na: 1\n---\nb: 2\n",
                         "a: 1\n...\n---\nb: 2\n"]),
           must_throw('yaml-decode'(Text, _), error(domain_error(one_yaml_document, _), _))),
    % A single document with explicit markers is not a multi-document stream.
    'yaml-decode'("---\na: 1\n", Explicit), 'get-atoms'(Explicit, [a, One]),
    assertion(One == 1),
    'yaml-decode'("a: 1\n...\n", Ended), 'get-atoms'(Ended, [a, Also]),
    assertion(Also == 1),
    % The host really does fail rather than answer, which is what this refusal is
    % for: a silent failure would have read as an empty document.
    assertion(\+ setup_call_cleanup(open_string("a: 1\n---\nb: 2\n", Stream),
                                    yaml_read(Stream, _),
                                    close(Stream))).

% An unsupported tag is refused naming the tag, where the host answers a tag/2
% term no MeTTa form can read; the standard tags are values and not refusals.
test(an_unknown_tag_is_refused_by_name) :-
    must_throw('yaml-decode'("k: !foo 1\n", _), error(domain_error(yaml_tag, '!foo'), _)),
    must_throw('yaml-decode'("!bar 1\n", _), error(domain_error(yaml_tag, '!bar'), _)),
    forall(member(Text-Key-Expected, ["k: !!str 7\n"-k-"7", "k: !!int 7\n"-k-7,
                                      "k: !!binary aGk=\n"-k-"hi"]),
           ( 'yaml-decode'(Text, Space), 'get-atoms'(Space, [Key, Value]),
             assertion(Value == Expected) )).

% Malformed text carries the host's own line number, and a duplicate key is
% refused rather than silently keeping one of the two.
test(malformed_text_is_refused_with_its_line) :-
    must_throw('yaml-decode'("a: [1,\n", _), error(syntax_error(yaml(_, _)), _)),
    catch('yaml-decode'("a: 1\n b: 2\n  c: 3\n", _), error(syntax_error(yaml(Line, _)), _), true),
    assertion(integer(Line)),
    must_throw('yaml-decode'("dup: 1\ndup: 2\n", _), error(duplicate_key(dup), _)),
    must_throw('yaml-decode'(7, _), error(type_error(string, 7), _)),
    % An encode refuses a space that is not a mapping, naming the atom that is not
    % a pair, and a value it has no shape for.
    'new-space'(Space),
    'add-atom'(Space, [a, 1, 2], _),
    must_throw('yaml-encode'(Space, _), error(type_error(key_value_pair, [a, 1, 2]), _)).

:- end_tests(lib_yaml).
