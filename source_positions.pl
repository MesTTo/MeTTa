% Purpose: attach concrete source spans to the parser's forms without changing atoms.
% Assumes: source_positions/3 receives forms parsed from the supplied source.
% Guarantees: offsets count Unicode codepoints, lines and columns start at one,
%   and ends are exclusive [tested: source_positions:unicode_nested_spans;
%   commit=df1367c75148ca6c7262134a8736b237e1150383].
% Guarantees: mismatched form text refuses instead of finding another occurrence
%   [tested: source_positions:mismatched_text_refuses; commit=df1367c75148ca6c7262134a8736b237e1150383].
% Decides: only LF advances a line, following filereader:source_layout//2
%   [tested: source_positions:comments_end_only_at_lf; commit=df1367c75148ca6c7262134a8736b237e1150383].

:- module(source_positions, [source_positions/2, source_positions/3]).

% Assumes: metta_engine:goal_expansion/2 is visible while clauses compile.
% Set the base before the clauses and their engine-dependent directives.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/expand.pl#L239; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- set_module(base(metta_engine)).
:- use_module(parser, [metta_token_boundary/2, string_state/3]).
:- use_module(library(error), [must_be/2]).

% SWI read_term/3 subterm_positions keeps positions beside the parsed term:
% https://www.swi-prolog.org/pldoc/man?predicate=read_term/3
% The same separation lets a loaded program retain maps while ordinary atoms
% and equality remain unchanged. /3 reuses parsing already done by the loader;
% in particular, host token constructors must not execute a second time.
% Children describe written syntax: a token constructor returning a list still
% has a leaf position, since that list's elements were not written subterms.
source_positions(Source, Positioned) :-
    filereader:parse_metta_source(Source, Parsed),
    source_positions(Source, Parsed, Positioned).

source_positions(Source, Parsed, Positioned) :-
    must_be(string, Source),
    must_be(list, Parsed),
    string_codes(Source, Codes),
    position_forms(Parsed, Codes, cursor(0, 1, 1), Positioned).

position_forms([], Codes0, Cursor0, []) :- !,
    position_layout(Codes0, Cursor0, Codes, Cursor),
    ( Codes == [] -> true
    ; position_marker(Codes, Cursor, Rest0, Next0),
      position_layout(Rest0, Next0, [], _)
    -> true
    ; position_mismatch(Cursor, trailing_source) ).
position_forms([Parsed|Forms], Codes0, Cursor0,
               [positioned(Kind, Text, Line, Column, Tree)|Positioned]) :-
    position_parts(Parsed, Kind, Text),
    position_layout(Codes0, Cursor0, Codes1, Cursor1),
    ( Kind == runnable
    -> ( position_marker(Codes1, Cursor1, Codes2, Cursor2)
       -> position_layout(Codes2, Cursor2, Codes, Cursor)
       ;  position_mismatch(Cursor1, runnable_marker) )
    ; Codes = Codes1, Cursor = Cursor1 ),
    Cursor = cursor(_, Line, Column),
    string_codes(Text, TextCodes),
    ( append(TextCodes, Rest, Codes),
      position_node(TextCodes, Cursor, [], Next, Tree)
    -> true
    ; position_mismatch(Cursor, Text) ),
    position_forms(Forms, Rest, Next, Positioned).

position_parts(parsed(Kind, Text, _), Kind, Text) :- !.
position_parts(parsed(Kind, Text, _, _), Kind, Text) :- !.
position_parts(Form, _, _) :-
    throw(error(type_error(parsed_source_form, Form),
                context(source_positions/3, 'pass the parser forms unchanged'))).

position_mismatch(cursor(Offset, Line, Column), Expected) :-
    throw(error(source_position_mismatch(Offset, Line, Column, Expected),
                context(source_positions/3,
                        'parse the same unchanged source before attaching positions'))).

position_advance(10, cursor(I,L,_), cursor(J,M,1)) :- !,
    J is I+1, M is L+1.
position_advance(_, cursor(I,L,C), cursor(J,L,D)) :-
    J is I+1, D is C+1.

position_span(cursor(I,L,C), cursor(J,M,D), span(I,J,L,C,M,D)).

position_layout([Code|Codes], Cursor0, Rest, Cursor) :-
    metta_token_boundary(Code, layout), !,
    position_advance(Code, Cursor0, Cursor1),
    position_layout(Codes, Cursor1, Rest, Cursor).
position_layout([0';|Codes], Cursor0, Rest, Cursor) :- !,
    position_advance(0';, Cursor0, Cursor1),
    position_comment(Codes, Cursor1, Tail, Next),
    position_layout(Tail, Next, Rest, Cursor).
position_layout(Codes, Cursor, Codes, Cursor).

position_comment([], Cursor, [], Cursor) :- !.
position_comment([Code|Codes], Cursor0, Rest, Cursor) :-
    position_advance(Code, Cursor0, Next),
    ( Code =:= 10
    -> Rest = Codes, Cursor = Next
    ; position_comment(Codes, Next, Rest, Cursor) ).

% Only (, layout or EOF can follow an execution marker. In particular !42,
% !$x and !;comment keep their ordinary symbol interpretation.
position_marker([0'!|Codes], Cursor0, Codes, Cursor) :-
    ( Codes == [] -> true
    ; Codes = [Code|_],
      ( Code =:= 0'( -> true ; metta_token_boundary(Code, layout) ) ),
    position_advance(0'!, Cursor0, Cursor).

position_node([0'(|Codes], Cursor0, Rest, Cursor, node(Span, Children)) :- !,
    position_advance(0'(, Cursor0, Cursor1),
    position_children(Codes, Cursor1, Rest, Cursor, Children),
    position_span(Cursor0, Cursor, Span).
position_node([0'"|Codes], Cursor0, Rest, Cursor, node(Span, [])) :- !,
    position_advance(0'", Cursor0, Cursor1),
    position_string(Codes, Cursor1, string, Rest, Cursor),
    position_span(Cursor0, Cursor, Span).
position_node([Code|Codes], Cursor0, Rest, Cursor, node(Span, [])) :-
    \+ metta_token_boundary(Code, _),
    position_advance(Code, Cursor0, Cursor1),
    position_word(Codes, Cursor1, Rest, Cursor),
    position_span(Cursor0, Cursor, Span).

position_children(Codes0, Cursor0, Rest, Cursor, Children) :-
    position_layout(Codes0, Cursor0, Codes, Cursor1),
    ( Codes = [0')|Tail]
    -> position_advance(0'), Cursor1, Cursor),
       Rest = Tail, Children = []
    ; position_node(Codes, Cursor1, Tail, Next, Child),
      Children = [Child|More],
      position_children(Tail, Next, Rest, Cursor, More) ).

position_string([Code|Codes], Cursor0, State0, Rest, Cursor) :-
    string_state(State0, Code, State),
    position_advance(Code, Cursor0, Next),
    ( State == outside
    -> Rest = Codes, Cursor = Next
    ; position_string(Codes, Next, State, Rest, Cursor) ).

position_word([Code|Codes], Cursor0, Rest, Cursor) :-
    \+ metta_token_boundary(Code, _), !,
    position_advance(Code, Cursor0, Next),
    position_word(Codes, Next, Rest, Cursor).
position_word(Codes, Cursor, Codes, Cursor).
