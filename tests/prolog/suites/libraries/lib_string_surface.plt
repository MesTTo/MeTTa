:- encoding(utf8).

% Purpose: check complete String data, host equivalence and named refusals.
% Guarantees: the tests exercise NUL, supplementary scalars, overlap, empty
% inputs, layout, templates, native cancellation and distinct metrics.
% [tested: lib_string_surface; commit=WORKTREE].
% Owns resources: each cancellation alarm is removed on every outcome.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_string/lib_string').
:- use_module(collection_test_support).
:- load_collection_library(lib_string).
:- use_module(library(isub), [isub/4]).
:- use_module(library(strings), []).
:- use_module(library(time), [alarm/4, remove_alarm/1]).

:- begin_tests(lib_string_surface).

test(codepoints_round_trip) :-
    Codes = [0,0x1f98a,0x301,0x10ffff,97],
    'string-from-codes'(Codes, Text), 'string-codes'(Text, Back),
    assertion(Back == Codes), 'string-length'(Text, 5),
    'string-chars'(Text, Chars), assertion(length(Chars,5)),
    invoke('string-from-chars'(Chars, Text)).

test(invalid_scalars, [forall(member(Code,[-1,0xd800,0xdfff,0x110000])),
                      throws(error(domain_error(unicode_scalar_value,Code),_))]) :-
    'string-from-codes'([Code], _).

test(noninteger_code, [throws(error(type_error(integer,1.5),_))]) :-
    'string-from-codes'([1.5], _).

test(improper_codes, [throws(error(type_error(list,_),_))]) :-
    'string-from-codes'([1|bad], _).

test(embedded_nul_is_not_an_implicit_separator_or_padding) :-
    string_codes(Text, [97,0,98]),
    'string-split'(",", Text, [Text]), 'string-split'("", Text, [Text]),
    'string-trim'(Text, Text), 'string-lines'(Text, [Text]),
    'string-index-of'(Text, "b", 2), 'string-last-index-of'(Text, "b", 2),
    'string-edit-distance'(Text, "a", 2),
    'string-isub'(Text, "a", [['substring-threshold',0]], Score),
    assertion(abs(Score-0.55) < 1.0e-12),
    'string-wrap'(Text, 10, Text),
    string_codes(Null,[0]), 'string-split'(Null,Text,["a","b"]),
    'string-replace'(Text,Null,"-","a-b"),
    lib_string_native:split_text(Null,"",Null,[""]).

test(embedded_nul_survives_the_retained_text_operations) :-
    string_codes(Text,[97,0,98]), string_codes(Upper,[65,0,66]),
    'string-upper'(Text,Upper), 'string-lower'(Upper,Text),
    string_codes(Suffix,[0,98]), 'string-slice'(Text,1,3,Suffix),
    invoke('string-starts-with'(Text,"a",true)), invoke('string-ends-with'(Text,Suffix,true)),
    'string-join'("",["a",Suffix],Text), invoke('string-repeat'(Text,2,Repeated)),
    string_codes(Repeated,[97,0,98,97,0,98]),
    string_codes(Left,[120,97,0,98]), invoke('string-pad-left'(Text,4,"x",Left)),
    string_codes(Right,[97,0,98,120]), invoke('string-pad-right'(Text,4,"x",Right)).

test(literal_operations_keep_overlap_and_empty_rules) :-
    'string-index-of'("aaaa", "aa", 0), 'string-last-index-of'("aaaa", "aa", 2),
    'string-count'("aaaa", "aa", 2), 'string-count'("aaaa", "aa", true, 3),
    'string-count'("🦊a", "", 3), 'string-count'("", "", true, 1),
    'string-index-of'("🦊a", "", 0), 'string-last-index-of'("🦊a", "", 2),
    'string-last-index-of'("abc", "z", -1),
    'string-replace'("aaaaa", "aa", "X", "XXa"),
    'string-replace'("abc", "", "X", "abc"),
    'string-split-exact'("aa", "aaaaa", ["","","a"]),
    'string-split-exact'("::", "::a::::", ["","a","",""]).

test(empty_exact_separator, [throws(error(domain_error(non_empty_string,""),_))]) :-
    'string-split-exact'("", "text", _).

test(invalid_overlap, [throws(error(type_error(boolean,maybe),_))]) :-
    'string-count'("a", "a", maybe, _).

test(split_padding_matches_host) :-
    forall(( between(0,4,N), length(Codes,N), maplist(small_code,Codes),
             member(Sep-Pad,[","-"", ","-" ", ", "-" ", " "-" ", ""-" ", ",;"-";"]) ),
           ( string_codes(Text,Codes), split_string(Text,Sep,Pad,Expected),
             lib_string_native:split_text(Text,Sep,Pad,Actual),
             assertion(Actual == Expected) )).

small_code(C) :- member(C,[97,32,44,59]).

test(lines_and_indentation_match_host) :-
    forall(member(Text,["","\n","a","a\n","\n\n","  a\n  b\n",
                        " \t\n  x\n\t y", "   \n\t\n", "🦊\r\nend"]),
           ( strings:string_lines(Text,Lines), 'string-lines'(Text,Lines),
             strings:dedent_lines(Text,HostDedent,[]),
             split_string(HostDedent,"\n","",HostLines),
             maplist(blank_control,HostLines,Normalized), atomics_to_string(Normalized,"\n",Dedent),
             'string-dedent'(Text,Dedent),
             strings:indent_lines("> ",Text,Indented), 'string-indent'("> ",Text,Indented) )),
    'string-unlines'([], ""), 'string-unlines'(["a",""], "a\n\n").

blank_control(Line,Out) :-
    string_codes(Line,Codes),
    ( forall(member(Code,Codes),memberchk(Code,[32,9])) -> Out="" ; Out=Line ).

test(blank_dedent_lines_are_empty_for_any_common_prefix) :-
    'string-dedent'(" \na","\na"),
    'string-dedent'("    \n  a","\na"),
    'string-dedent'(" \t\n\ta","\na"),
    'string-dedent'("\r","\r").

test(nul_line_layout) :-
    string_codes(Text,[32,32,97,0,10,32,32,98,10]),
    string_codes(Expected,[97,0,10,98,10]),
    'string-dedent'(Text,Expected), 'string-lines'(Expected,[First,"b"]),
    string_codes(First,[97,0]), 'string-unlines'([First,"b"],Expected),
    'string-indent'(">",First,Indented), string_codes(Indented,[62,97,0]).

test(padding_contracts) :-
    invoke('string-center'("x", 6, "ab", "abxaba")),
    invoke('string-center'("🦊", 4, ".", ".🦊..")),
    invoke('string-center'("long", -1, "x", "long")),
    invoke('string-center'("x", 12, "", "x")),
    invoke('string-pad-left'("x", 4, "ab", "abax")),
    invoke('string-pad-right'("x", 4, "ab", "xaba")),
    invoke('string-repeat'("a", -9, "")),
    invoke('string-from-chars'(["ab",c,42,""], "abc42")).

test(wrapping_and_alignment) :-
    'string-wrap'("one two three",7,"one two\nthree"),
    'string-wrap'("  one\t\ntwo  ",7,"one two"),
    'string-wrap'("longword x",3,"longword\nx"),
    'string-wrap'("a bb",5,right," a bb"),
    'string-wrap'("a bb",6,center," a bb"),
    'string-wrap'("a b c d",4,justify,"a  b\nc d"),
    'string-wrap'(" \n\t",4,"").

test(wrap_bad_width, [throws(error(type_error(positive_integer,0),_))]) :-
    'string-wrap'("x",0,_).

test(wrap_bad_alignment, [throws(error(type_error(oneof(_),diagonal),_))]) :-
    'string-wrap'("x",4,diagonal,_).

test(template_uses_engine_rendering_and_host_grammar) :-
    'string-template'("Hello {Name}! {Other,default}",[['Name',"Ada"]],"Hello Ada! default"),
    'string-template'("{Value}",[['Value',[person,"Ada"]]],"(person \"Ada\")"),
    'string-template'("{lower} {@throw(no)}",[],"{lower} {@throw(no)}"),
    'string-template'("{{Name}}",[['Name',"Ada"]],"{Ada}"),
    string_codes(Null,[0]), 'string-template'("a{Value}b",[['Value',Null]],Result),
    string_codes(Result,[97,0,98]).

test(template_missing_name, [throws(error(existence_error(template_var,'Name'),_))]) :-
    'string-template'("{Name}",[],_).

test(template_duplicate, [throws(error(duplicate_key('Name'),_))]) :-
    'string-template'("{Name}",[['Name',1],['Name',2]],_).

test(template_bad_name, [throws(error(domain_error(template_name,lower),_))]) :-
    'string-template'("{lower}",[[lower,1]],_).

test(template_bad_pair, [throws(error(domain_error(template_binding,[a]),_))]) :-
    'string-template'("x",[[a]],_).

test(exact_edit_distance_and_similarity) :-
    'string-edit-distance'("kitten","sitting",3),
    'string-edit-distance'("é","é",2),
    'string-edit-distance'("🦊","🦊x",1),
    'string-edit-distance'("","abc",3),
    invoke('string-similarity'("","",1.0)), invoke('string-similarity'("","a",0.0)),
    invoke('string-similarity'("cat","cut",Score)), assertion(abs(Score-2/3) < 1.0e-12).

test(isub_matches_host) :-
    forall(( member(Left,["","a","ab","abc","aabac","E56.Language","éclair"]),
             member(Right,["","b","ab","cba","bacab","languange","école"]),
             member(Normalize,[false,true]), member(Zero,[false,true]), member(Threshold,[0,2,100]) ),
           % Workaround: swi-isub-variable-options - evaluate every oracle option at runtime.
           ( call(isub:isub,Left,Right,Expected,
                  [normalize(Normalize),zero_to_one(Zero),substring_threshold(Threshold)]),
             'string-isub'(Left,Right,[[normalize,Normalize],['zero-to-one',Zero],
                                      ['substring-threshold',Threshold]],Actual),
             assertion(abs(Actual-Expected) < 1.0e-12) )).

test(isub_threshold_has_no_machine_integer_limit) :-
    'string-isub'("same","same",[['substring-threshold',100]],Small),
    Huge is 1<<100, 'string-isub'("same","same",[['substring-threshold',Huge]],Large),
    assertion(Small =:= Large).

test(isub_unknown_option, [throws(error(domain_error(isub_option,[unknown,1]),_))]) :-
    'string-isub'("a","b",[[unknown,1]],_).

test(isub_duplicate_option, [throws(error(duplicate_key(normalize),_))]) :-
    'string-isub'("a","b",[[normalize,true],[normalize,false]],_).

test(isub_negative_threshold, [throws(error(type_error(nonneg,-1),_))]) :-
    'string-isub'("a","b",[['substring-threshold',-1]],_).

test(parse_number_does_not_hide_wrong_output_type,
     [throws(error(type_error(number,not_a_number),_))]) :-
    'parse-number'("3",not_a_number).

test(native_failed_output_unification_releases_call_state) :-
    forall(between(1,1000,_),
           ( \+ lib_string_native:split_exact("a,b",",",["wrong"]),
             \+ lib_string_native:replace_all("abc","b","x","wrong") )),
    'string-edit-distance'("abc","abc",0).

test(native_walk_delivers_cancellation) :-
    length(Copies,1000000), maplist(=("ab"),Copies), atomics_to_string(Copies,Text),
    setup_call_cleanup(
        alarm(0.001,throw(string_cancelled),Alarm,[]),
        catch((lib_string_native:count_matches(Text,"a",false,_),Outcome=completed),
              string_cancelled,Outcome=cancelled),
        remove_alarm(Alarm)),
    assertion(Outcome == cancelled),
    'string-count'("aa","a",2).

test(empty_construction_still_validates_complete_inputs) :-
    forall(member(Count,[_,1.0,1.5,true,"2"]),
           (refused('string-repeat'("",Count,_)),
            refused('string-center'("x",Count,"",_)))),
    forall(member(Value,[_,[code,1],[['+',1,2]]]),
           (refused('string-repeat'(Value,0,_)),
            refused('string-pad-left'("x",0,Value,_)),
            refused('string-from-chars'([Value],_)))).

test(large_empty_construction_does_not_enumerate_the_count) :-
    Huge is 1<<100,
    invoke('string-repeat'("",Huge,"")),
    invoke('string-center'("x",Huge,"","x")).

test(prefix_suffix_and_similarity_keep_coercions) :-
    invoke('string-starts-with'(123,12,true)),
    invoke('string-ends-with'(123,23,true)),
    invoke('string-ends-with'("ab","abc",false)),
    invoke('string-ends-with'("ab","",true)),
    invoke('string-center'(12,7,3,"3312333")),
    invoke('string-similarity'(12,'12',1.0)).

test(from_chars_refuses_open_and_cyclic_literal_data) :-
    Open=["a"|Tail], Cycle=["a"|Cycle],
    forall(member(Items,[Open,Cycle,["a"|bad]]), refused('string-from-chars'(Items,_))),
    assertion(var(Tail)).

test(repeat_equation_is_callable_data) :-
    once(eval_expr([match,'&self',['=',['string-repeat',Value,Count],Body],
                    [quote,['|->',[Value,Count],Body]]],Recipe)),
    once(eval_expr([eval,Recipe],Function)),
    once(eval_expr([Function,"ab",3],Text)), assertion(Text=="ababab").

:- end_tests(lib_string_surface).
