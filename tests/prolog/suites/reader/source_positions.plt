% Purpose: verify concrete source spans against the authoritative parser.
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../engine/source_positions').
:- use_module(library(readutil), [read_file_to_string/3]).

:- begin_tests(source_positions).

same_form(Parsed, positioned(Kind,Text,_,_,_)) :-
    arg(1,Parsed,Kind), arg(2,Parsed,Text).

node_slice(Source, node(span(Start,End,_,_,_,_),_), Text) :-
    Length is End-Start, sub_string(Source,Start,Length,_,Text).

test(unicode_nested_spans) :-
    Source = " ;intro\n! (λ\n  (β \"😀\\\";()\") $x)",
    source_positions(Source, [positioned(runnable, Text, 2, 3, Tree)]),
    Text == "(λ\n  (β \"😀\\\";()\") $x)",
    Tree = node(span(10,31,2,3,3,19), [Head,Nested,Variable]),
    Head == node(span(11,12,2,4,2,5), []),
    Nested = node(span(15,27,3,3,3,15), [Beta,Quoted]),
    Beta == node(span(16,17,3,4,3,5), []),
    Quoted == node(span(18,26,3,6,3,14), []),
    Variable == node(span(28,30,3,16,3,18), []),
    node_slice(Source,Quoted,"\"😀\\\";()\"").

test(markers_comments_and_bare_atoms_match_parser) :-
    Source = "!42 !$x !!(f) !;comment\n! ;comment\n42 ! \"a b\" !",
    filereader:parse_metta_source(Source, Parsed),
    source_positions(Source, Parsed, Positioned),
    maplist(same_form,Parsed,Positioned),
    length(Positioned,7).

test(comments_end_only_at_lf) :-
    Source = ";hidden\r(foo)\u0085(bar)\u2028(baz)\n\u00a0! (ok)",
    source_positions(Source, [positioned(runnable,"(ok)",2,4,
                                        node(span(_,_,2,4,2,8),_))]).

test(mismatched_text_refuses,
     [throws(error(source_position_mismatch(0,1,1,"(b)"),_))]) :-
    source_positions("(a) (b)",[parsed(expression,"(b)",[b])],_).

test(missing_forms_refuse,
     [throws(error(source_position_mismatch(0,1,1,trailing_source),_))]) :-
    source_positions("(a)",[],_).

test(missing_runnable_marker_refuses,
     [throws(error(source_position_mismatch(0,1,1,runnable_marker),_))]) :-
    source_positions("(a)",[parsed(runnable,"(a)",[a],[])],_).

test(empty_forms_and_trailing_marker) :-
    forall(member(Source,["", " ;comment", "!", "! ;comment"]),
           source_positions(Source, [])).

test(adjacent_strings_and_embedded_quotes) :-
    Source = "(\"a\"\"b\" x\"y\" $\"z\")",
    filereader:parse_metta_source(Source,Parsed),
    source_positions(Source,Parsed,[positioned(expression,Source,1,1,
                                             node(_,Children))]),
    maplist(node_slice(Source),Children,["\"a\"","\"b\"","x\"y\"","$\"z\""]).

test(every_shipped_valid_source_keeps_parser_form_text) :-
    expand_file_name('../../examples/*/*.metta', A),
    expand_file_name('../../examples/*/*/*.metta', B),
    expand_file_name('../../lib/*/*.metta', C),
    append([A,B,C], Files), length(Files,Count), Count > 200,
    forall(member(File,Files),
           (read_file_to_string(File,Source,[]),
            ( catch(filereader:parse_metta_source(Source,Parsed),_,fail)
            -> source_positions(Source,Parsed,Positioned),
               maplist(same_form,Parsed,Positioned)
            ; true ))).

test(parsed_kinds_survive_later_token_registry_changes,
     [cleanup(parser:'unregister-token!'("[0-9]+x", _))]) :-
    parser:'register-token!'("[0-9]+x", wrapped, true),
    Source = "(= (12x $x) $x)",
    filereader:parse_metta_source_prolog(Source, Parsed),
    Parsed = [parsed(expression, _, _)],
    parser:'unregister-token!'("[0-9]+x", true),
    source_positions(Source, Parsed, [positioned(expression,Source,1,1,_)]),
    filereader:parse_metta_source_prolog(Source, [parsed(function,_,_)]).

test(constructed_term_children_have_no_invented_spans,
     [cleanup(parser:'unregister-token!'("[0-9]+x", _))]) :-
    parser:'register-token!'("[0-9]+x", wrapped, true),
    Source = "(hold 12x)",
    filereader:parse_metta_source_prolog(Source,
                                        [parsed(expression,Source,Term)]),
    Term == [hold,[wrapped,"12x"]],
    source_positions(Source, [parsed(expression,Source,Term)],
                     [positioned(expression,Source,1,1,
                                 node(_,[_Head,Constructed]))]),
    Constructed == node(span(6,9,1,7,1,10),[]).

test(equal_sibling_terms_keep_distinct_written_locations) :-
    Source = "(f (g $x) (g $x))",
    source_positions(Source,
                     [positioned(expression,Source,1,1,
                                 node(_,[_Head,First,Second]))]),
    First = node(span(3,9,1,4,1,10),[_,FirstVar]),
    Second = node(span(10,16,1,11,1,17),[_,SecondVar]),
    FirstVar == node(span(6,8,1,7,1,9),[]),
    SecondVar == node(span(13,15,1,14,1,16),[]),
    node_slice(Source,First,"(g $x)"),
    node_slice(Source,Second,"(g $x)").

test(all_reader_layout_characters_preserve_coordinates) :-
    forall(parser:metta_token_boundary(Code,layout),
           (string_codes(Layout,[Code]),
            atomics_to_string([Layout,"!",Layout,"(a",Layout,"b)"],Source),
            filereader:parse_metta_source(Source,
                                         [parsed(runnable,_,Term,_)]),
            source_positions(Source,[positioned(runnable,_,_,_,Tree)]),
            check_tree(Source,Term,Tree))).

check_tree(Source, Term, Node) :-
    Node = node(span(Start,End,Line,Column,EndLine,EndColumn), Children),
    node_slice(Source, Node, Text),
    parser:sread_mode(shipped, Text, Read),
    Read =@= Term,
    reference_position(Source, Start, Line, Column),
    reference_position(Source, End, EndLine, EndColumn),
    ( is_list(Term) -> maplist(check_tree(Source),Term,Children)
    ; Children == [] ).

reference_position(Source, Offset, Line, Column) :-
    sub_string(Source, 0, Offset, _, Prefix),
    split_string(Prefix, "\n", "", Lines),
    length(Lines, Line), last(Lines, Last),
    string_length(Last, Width), Column is Width+1.

test(generated_tokens_and_layout_preserve_every_subterm) :-
    Leaves = ["plain", "$x", "42", "-1.2e3", "True", "λ", "\"😀 a\"",
              "\"escaped \\\" ; ()\"", "x\"y\"", "$\"z\""],
    Layouts = [" ", "\n", "\u00a0", "\t", ";comment ) \r hidden\n"],
    forall((member(Leaf,Leaves),member(Layout,Layouts)),
           (format(string(Source), ";prefix\n! (f~s~s (g~s~s))",
                   [Layout,Leaf,Layout,Leaf]),
            filereader:parse_metta_source(Source,[parsed(runnable,_,Term,_)]),
            source_positions(Source,[positioned(runnable,_,_,_,Tree)]),
            check_tree(Source,Term,Tree))).

scan_cost(Count, Inferences) :-
    length(Texts,Count), maplist(=("(a)\n"),Texts),
    atomics_to_string(Texts,Source),
    filereader:parse_metta_source(Source,Parsed),
    statistics(inferences,Before),
    source_positions(Source,Parsed,Positioned),
    statistics(inferences,After),
    Inferences is After-Before,
    length(Positioned,Count).

test(disjoint_form_walk_scales_linearly) :-
    scan_cost(1000,Small), scan_cost(8000,Large),
    Large > 6*Small, Large < 10*Small.

:- end_tests(source_positions).
