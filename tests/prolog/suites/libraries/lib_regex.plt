% Purpose: verify regex values, match progression, projections and native errors.
% Guarantees: the suite includes the pinned provider's upstream tests and the
% public library's Unicode, optional-capture and substitution regressions
% [tested: sh engine/test.sh suites/libraries/lib_regex.plt; commit=7dcfe83fcf74742a1e944db240aa918596c8d4b0].
% Owns resources: concurrent_maplist/2 joins its native matching workers
% [source: tests/prolog/suites/libraries/lib_regex.plt:compiled_values_support_concurrent_scans; commit=7dcfe83fcf74742a1e944db240aa918596c8d4b0].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_regex/vendor/tests/test_pcre', []).
:- use_module(library(thread), [concurrent_maplist/2]).
:- initialization(consult('../../lib/lib_regex/lib_regex.pl')).

:- begin_tests(lib_regex).

test(empty_unicode_matches_and_ranges) :-
    findall(M, 're-find'("", "é🦊", M), Matches),
    assertion(Matches == ["","",""]),
    findall(R, 're-ranges'("", "é🦊", R), Ranges),
    assertion(Ranges == [[0,0],[1,0],[2,0]]).

test(empty_subject) :-
    findall(M, 're-find'("", "", M), Matches),
    assertion(Matches == [""]),
    're-count'("", "", 1),
    're-split'("", "", ["","",""]),
    're-replace-all'("", "X", "", "X").

test(empty_then_nonempty_alternatives) :-
    findall(M, 're-find'("a*?", "aa", M), Matches),
    assertion(Matches == ["","a","","a",""]),
    're-count'("a*?", "aa", 5),
    're-replace-all'("a*?", "X", "aa", "XXXXX").

test(crlf_progress_follows_the_pattern_newline_mode) :-
    findall(R, 're-ranges'("(*CRLF)", "\r\n", R), Ranges),
    assertion(Ranges == [[0,0],[2,0]]).

test(global_anchor_uses_the_host_reference_progress_rule) :-
    findall(R, 're-ranges'("\\G", "éa", R), Ranges),
    assertion(Ranges == [[0,0],[1,0],[2,0]]).

test(end_offset_is_a_valid_character_boundary) :-
    lib_regex_pcre:re_matchsub("", "é", Dict, [start(1), capture_type(range)]),
    assertion(Dict == re_match{0:1-0}).

test(offset_after_end_raises, [error(domain_error(offset,2))]) :-
    lib_regex_pcre:re_matchsub("", "é", _, [start(2)]).

test(unset_capture_holes_are_omitted) :-
    regex_captures("((a)?b)", "b", Groups),
    assertion(Groups == [[0,"b"],[1,"b"]]),
    regex_captures("(?<first>(a))?(?<last>b)", "b", Named),
    assertion(Named == [[0,"b"],[last,"b"]]).

test(matched_empty_captures_are_retained) :-
    regex_captures("(a?)", "b", [[0,""],[1,""]]).

test(capture_ranges_can_visit_boundaries_out_of_order) :-
    regex_captures("(?<whole_R>é(?<last_R>🦊))", "xé🦊", Groups),
    assertion(Groups == [[0,"é🦊"],[last,[-,2,1]],[whole,[-,1,2]]]).

test(compound_captures_have_explicit_metta_structure) :-
    regex_captures("(?<term_T>.*)", "f(1-2,[g(a),b],[a,b|X],X,z())", Groups),
    Groups = [[0,_],[term,[f,[-,1,2],[[g,a],b],[cons,a,[cons,b,X]],X,[z]]]],
    assertion(var(X)).

test(cyclic_capture_refuses, [error(domain_error(acyclic_regex_capture,_))]) :-
    Cyclic = f(Cyclic),
    lib_regex:regex_pairs(re_match{0:Cyclic}, _).

test(compiled_values_work_for_every_pattern_consumer) :-
    're-compile'("(?<n_I>\\d+)", Pattern),
    assertion(blob(Pattern, metta_regex)),
    're-match'(Pattern, "x007 y8", true),
    're-fullmatch'(Pattern, "007", true),
    're-fullmatch'(Pattern, "x007", false),
    findall(M, 're-find'(Pattern, "x007 y8", M), Matches),
    assertion(Matches == ["007","8"]),
    're-captures'(Pattern, "x007", [[0,"007"],[n,7]]),
    findall(G, 're-scan'(Pattern, "x007 y8", G), Groups),
    assertion(Groups == [[[0,"007"],[n,7]],[[0,"8"],[n,8]]]),
    findall(R, 're-ranges'(Pattern, "x007 y8", R), Ranges),
    assertion(Ranges == [[1,3],[6,1]]),
    're-count'(Pattern, "x007 y8", 2),
    're-split'(Pattern, "x007 y8", ["x","007"," y","8",""]),
    're-replace'(Pattern, "[$n]", "x007 y8", "x[7] y8"),
    're-replace-all'(Pattern, "[$n]", "x007 y8", "x[7] y[8]").

test(full_match_anchors_every_alternative_without_renumbering) :-
    're-fullmatch'("a|ab", "ab", true),
    're-fullmatch'("a|ab", "abc", false),
    're-fullmatch'("(a)\\1", "aa", true),
    're-fullmatch'("a", "a\n", false).

test(parsed_minus_terms_are_values_not_ranges) :-
    're-replace'("(?<term_T>1-2)", "$term", "before 1-2 after", "before 1-2 after"),
    're-replace'("(?<term_T>f\\(a\\))", "$term", "f(a)", "f(a)").

test(parsed_atoms_retain_their_original_substitution_text) :-
    're-replace'("(?<term_T>'a b')", "$term", "'a b'", "a b"),
    're-replace'("(?<term_A>a b)", "$term", "a b", "a b").

test(unbound_substitution_refuses, [error(instantiation_error)]) :-
    're-replace'("(?<term_T>X)", "$term", "X", _).

test(count_and_ranges_do_not_parse_unused_capture_values) :-
    're-count'("(?<bad_T>\\()", "(", 1),
    findall(R, 're-ranges'("(?<bad_T>\\()", "(", R), Ranges),
    assertion(Ranges == [[0,1]]),
    're-split'("(?<bad_T>\\()", "(", ["","(",""]).

test(compile_and_match_embedded_nul) :-
    string_codes(Text, [97,0,98]),
    're-compile'(Text, Pattern),
    're-fullmatch'(Pattern, Text, true),
    're-captures'(Pattern, Text, [[0,Text]]),
    're-escape'(Text, Escaped),
    're-fullmatch'(Escaped, Text, true).

test(compiled_pattern_order_includes_text_after_nul) :-
    string_codes(Left, [97,0,98]),
    string_codes(Right, [97,0,99]),
    're-compile'(Left, A),
    're-compile'(Right, B),
    compare(<, A, B).

test(escaped_literals_cover_metacharacters_and_quote_terminators) :-
    forall(member(Text, ["", "a.*[x]$", "\\E", "\\E\\E", "a\\Eb", " # é🦊\n"]),
           ('re-escape'(Text, Pattern),
            're-fullmatch'(Pattern, Text, true),
            string_concat("(?x)", Pattern, Extended),
            're-fullmatch'(Extended, Text, true))).

test(no_match_has_no_capture_answer, [fail]) :-
    're-captures'("\\d+", "abc", _).

test(invalid_pattern_raises, [error(syntax_error(_))]) :-
    're-compile'("(", _).

test(invalid_pattern_type_raises, [error(type_error(text,42))]) :-
    're-match'(42, "abc", _).

test(partial_match_has_a_named_refusal, [error(domain_error(regex_match,_))]) :-
    lib_regex_pcre:re_match("ab", "a", [partial_soft(true)]).

test(non_character_capture_boundaries_raise,
     [error(representation_error(regex_character_boundary))]) :-
    're-ranges'("\\C", "é", _).

test(replacement_respects_execution_start_options) :-
    lib_regex_pcre:re_replace("a", "X", "aa", "aX", [start(1)]),
    lib_regex_pcre:re_replace("a"/g, "X", "aaa", "aXX", [start(1)]).

test(callback_errors_release_the_matching_state) :-
    forall(between(1, 100, _),
           catch(lib_regex_pcre:re_fold_ranges(plunit_lib_regex:throw_from_match, ".", "é🦊", 0, _, []),
                 callback_failed, true)),
    're-count'(".", "é🦊", 2).

test(large_count_uses_no_answer_collector) :-
    length(Codes, 100000),
    maplist(=(0'a), Codes),
    string_codes(Text, Codes),
    're-count'("a*?", Text, 200001).

test(compiled_values_support_concurrent_scans) :-
    're-compile'("(?<n_I>\\d+)", Pattern),
    length(Jobs, 8),
    concurrent_maplist(scan_shared_pattern(Pattern), Jobs).

test(literal_ranges_follow_unicode_character_positions) :-
    forall((between(0, 4, N), length(Chars, N), maplist(fixture_char, Chars)),
           (atomics_to_string(Chars, Text),
            findall([I,1], (nth0(I, Chars, C), C == "é"), Expected),
            findall(R, 're-ranges'("é", Text, R), Actual),
            assertion(Actual == Expected),
            're-split'("é", Text, Parts),
            atomics_to_string(Parts, Text))).

fixture_char("a").
fixture_char("é").
fixture_char("🦊").
fixture_char("\n").
throw_from_match(_, _, _) :- throw(callback_failed).

scan_shared_pattern(Pattern, _) :-
    forall(between(1, 100, _),
           ('re-fullmatch'(Pattern, "123", true),
            're-captures'(Pattern, "x007", [[0,"007"],[n,7]]),
            're-count'(Pattern, "é1 🦊22", 2),
            findall(R, 're-ranges'(Pattern, "é1 🦊22", R), Ranges),
            assertion(Ranges == [[1,1],[4,2]]))).

:- end_tests(lib_regex).
