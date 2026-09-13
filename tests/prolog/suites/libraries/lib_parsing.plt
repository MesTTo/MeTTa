% Purpose: check callable MeTTa grammars against independent DCGs over the same
% text, check the combinators' algebra, and check that a malformed grammar is
% refused before any text is read.
% Guarantees: each primitive answers what its dcg/basics or hand-written
% counterpart answers over generated text, a whole parse is the prefix parse whose
% rest is empty, the combinator laws hold over generated grammars, a grammar may
% recurse through ref, the classes are ASCII under any locale, and every malformed
% form is named [tested: lib_parsing; commit=WORKTREE].
% Owns resources: none; every value is a term.

:- use_module(collection_test_support).
:- use_module(library(lists), [member/2, memberchk/2, nth1/3, append/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(dcg/basics), [integer/3, number/3]).
:- use_module(library(random), [random_between/3]).
:- load_collection_library(lib_parsing).

:- begin_tests(lib_parsing).
% Keep the independent oracle loops separate from the public execution fixture.
'grammar-parse'(Grammar, Text, Value) :-
    collection_answers('grammar-parse'(Grammar, Text, Value)).
'grammar-parse-prefix'(Grammar, Text, Value) :-
    collection_answers('grammar-parse-prefix'(Grammar, Text, Value)).
'grammar-is'(Grammar, Verdict) :- invoke('grammar-is'(Grammar, Verdict)).
'grammar-forms'(Forms) :- invoke('grammar-forms'(Forms)).

must_name(Grammar, Bad) :-
    catch(invoke('grammar-parse'(Grammar, "a", _)), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_assertion_failed(
        [assertEqualMsg,false,true,[quote,['grammar-parser',
          "use a well-formed grammar from grammar-forms",Bad]]],_,_),_)).

% Random text over an alphabet that every primitive has something to say about:
% digits, letters, a comma, a quote, a minus, a space and a non-ASCII letter.
random_text(Text) :-
    random_between(0, 10, Length),
    length(Codes, Length),
    maplist([Code]>>( random_between(1, 9, Which),
                      nth1(Which, [0'1, 0'2, 0'a, 0'b, 0',, 0'", 0'-, 0' , 0'é], Code) ),
            Codes),
    string_codes(Text, Codes).

% The four primitives the host also has, against the host's own DCG over the same
% codes: a whole-text parse is phrase/2 and the library adds the string wrapping.
test(the_primitives_agree_with_dcg_basics) :-
    set_random(seed(20260912)),
    forall(between(1, 300, _),
           ( random_text(Text), string_codes(Text, Codes),
             findall(V, 'grammar-parse'([number], Text, V), Numbers),
             findall(N, phrase(number(N), Codes), ExpectedNumbers),
             assertion(Numbers == ExpectedNumbers),
             findall(V, 'grammar-parse'([integer], Text, V), Integers),
             findall(I, phrase(integer(I), Codes), ExpectedIntegers),
             % dcg/basics' integer//1 accepts a leading plus where this library's
             % does not, so the answers agree except on that one shape.
             (   sub_string(Text, 0, 1, _, "+")
             ->  assertion(Integers == [])
             ;   assertion(Integers == ExpectedIntegers)
             ),
             findall(V, 'grammar-parse'([rest], Text, V), [Rest]),
             assertion(Rest == Text),
             findall(V, 'grammar-parse'([eos], Text, V), Eos),
             ( Text == "" -> assertion(Eos == [[]]) ; assertion(Eos == []) ) )).

% A whole parse is exactly a prefix parse whose rest is empty, which is phrase/2
% against phrase/3 and the one law the two doors owe each other.
test(whole_and_prefix_parses_agree_with_phrase) :-
    set_random(seed(20260912)),
    Grammars = [[digits], [nonblanks], [many, [any]], ['sep-by', [digits], [lit, ","]],
                [cat, [digits], [lit, ","], [digits]], [alt, [digits], [nonblanks]],
                [many, ['char-in', "ab12"]], [optional, [digits]]],
    forall(between(1, 200, _),
           ( random_text(Text),
             forall(member(Grammar, Grammars),
                    ( findall(V, 'grammar-parse'(Grammar, Text, V), Whole),
                      findall(V, ( 'grammar-parse-prefix'(Grammar, Text, Pair),
                                   Pair=[V,Rest], Rest=="" ), Prefixed),
                      assertion(Whole == Prefixed) )) )).

% The algebra: alt of one branch is that branch, many is optional over many1,
% many1 is one then many, a cat of one part answers that part's value in a
% one-element collection, and sep-by with a separator the text never holds is
% one part or none.
test(the_combinators_obey_their_algebra) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_text(Text),
             Part = ['char-in', "ab12"],
             findall(V, 'grammar-parse'([alt, Part], Text, V), OneBranch),
             findall(V, 'grammar-parse'(Part, Text, V), Bare),
             assertion(OneBranch == Bare),
             findall(V, 'grammar-parse'([many, Part], Text, V), Many),
             findall(V, ( 'grammar-parse'([alt, [many1, Part], [cat]], Text, Raw),
                          ( Raw == [] -> V = [] ; V = Raw ) ), ManyOrNothing),
             assertion(Many == ManyOrNothing),
             findall(V, 'grammar-parse'([many1, Part], Text, V), Many1),
             findall([First|More], 'grammar-parse'([cat, Part, [many, Part]], Text,
                                                   [First, More]), Unrolled),
             assertion(Many1 == Unrolled),
             findall(V, 'grammar-parse'([cat, Part], Text, V), Cat1),
             findall([V], 'grammar-parse'(Part, Text, V), Wrapped),
             assertion(Cat1 == Wrapped),
             findall(V, 'grammar-parse'(['sep-by', Part, [lit, "#"]], Text, V), Separated),
             findall(V, ( 'grammar-parse'([alt, Part, [cat]], Text, Raw2),
                          ( Raw2 == [] -> V = [] ; V = [Raw2] ) ), SingleOrNone),
             assertion(Separated == SingleOrNone) )).

% skip contributes nothing to a cat and map and as reshape a value, which is what
% makes a grammar answer a parse tree.
test(skip_map_and_as_shape_the_value) :-
    invoke('grammar-parse'([cat, [digits], [skip, [lit, "-"]], [digits]], "12-34", Skipped)),
    assertion(Skipped == ["12", "34"]),
    invoke('grammar-parse'([skip, [digits]], "12", Alone)), assertion(Alone == []),
    invoke('grammar-parse'([as, amount, [integer]], "7", Tagged)), assertion(Tagged == [amount, 7]),
    invoke('grammar-parse'([between, [lit, "("], [digits], [lit, ")"]], "(5)", Inner)),
    assertion(Inner == "5"),
    invoke('grammar-parse'([token, [digits]], "  5 ", Token)), assertion(Token == "5"),
    % A quoted string keeps its escapes' meaning rather than their text.
    invoke('grammar-parse'([quoted], "\"a\\nb\"", Quoted)), assertion(Quoted == "a\nb"),
    invoke('grammar-parse'([quoted], "\"\"", Empty)), assertion(Empty == ""),
    invoke('grammar-parse'([quoted], "\"a\\\"b\"", Escaped)), assertion(Escaped == "a\"b").

% A grammar may name itself through ref, which evaluates a MeTTa function when the
% parse reaches it, so a nested language is expressible; the depth is the text's.
test(a_grammar_may_recurse_through_ref) :-
    process_metta_string("!(import! &self (library lib_parsing))", _),
    process_metta_string("(= (nested) (alt (digits) (between (lit \"(\") (ref nested) (lit \")\"))))", _),
    forall(member(Text-Expected, ["7"-"7", "(7)"-"7", "((7))"-"7", "(((7)))"-"7"]),
           ( 'grammar-parse'([ref, nested], Text, Value),
             assertion(Value == Expected) )),
    findall(V, 'grammar-parse'([ref, nested], "(7", V), Unbalanced),
    assertion(Unbalanced == []),
    % A ref whose function answers something that is not a grammar is refused
    % where the parse reaches it, naming what it found.
    process_metta_string("(= (notagrammar) (nosuch))", _),
    must_name([ref, notagrammar], [nosuch]).

% The classes are ASCII and defined here, so they do not move with the locale,
% which is what makes a grammar portable; a Unicode class is (char-if F).
test(the_classes_are_ascii_and_locale_free) :-
    Cases = ["123"-[digits]-"123", " \t\n"-[blanks]-" \t\n", "ab"-[nonblanks]-"ab",
             "é"-[nonblanks]-"é"],
    setup_call_cleanup(
        setlocale(ctype, Old, 'C'),
        forall(member(Text-Grammar-Expected, Cases),
               ( 'grammar-parse'(Grammar, Text, Value), assertion(Value == Expected) )),
        setlocale(ctype, _, Old)),
    forall(member(Text-Grammar-Expected, Cases),
           ( 'grammar-parse'(Grammar, Text, Value), assertion(Value == Expected) )),
    % A non-ASCII digit is not a digit here, which is the standard's own answer
    % for what a DCG's digit means, and the Unicode question is a different one.
    findall(V, 'grammar-parse'([digits], "١٢", V), ArabicIndic),
    assertion(ArabicIndic == []).

% Every malformed grammar is refused before any text is read, and the refusal
% names the innermost form that is wrong with the vocabulary beside it.
test(a_malformed_grammar_is_refused_before_parsing) :-
    must_name([nosuch], [nosuch]),
    must_name([cat, [digits], [nosuch]], [nosuch]),
    must_name([many], [many]),
    must_name([lit, 7], [lit, 7]),
    must_name(notalist, notalist),
    % Choice's empty expression is valid and has no alternatives.
    'grammar-is'([alt], true),
    findall(V, 'grammar-parse'([alt], "a", V), []),
    once(eval_expr(['grammar-parse',[digits],7], BadText)),
    assertion(BadText == ['Error',['grammar-parse',[digits],7],
                         ['BadArgType',2,'String','Number']]),
    % The same question without the refusal, and the vocabulary as data.
    'grammar-is'([cat, [digits], [eos]], true),
    'grammar-is'([lit, 7], false),
    'grammar-is'([many], false),
    'grammar-is'(7, false),
    'grammar-is'([ref, anything], true),
    'grammar-forms'(Forms), length(Forms, Count), assertion(Count == 26),
    assertion(memberchk([cat,*], Forms)), assertion(memberchk([ref,1], Forms)),
    forall(member([Name, Arity], Forms), ( atom(Name), ( integer(Arity) ; Arity == * ) )).

test(decimal_prefixes_agree_with_the_host_lexer) :-
    forall(member(Text,["+1!","-0!","1.","1.e3","1e","1e+","1E-2!",
                         "01!","0x12","-.1","+2.50e+2z","1e-300!","1e300!",
                         "9007199254740993!","1.234567890123456789!"]),
        (string_codes(Text,Codes),
         findall([N,Rest],(phrase(number(N),Codes,Tail),string_codes(Rest,Tail)),Expected),
         findall(Value,'grammar-parse-prefix'([number],Text,Value),Actual),
         assertion(Actual==Expected))),
    findall(V,'grammar-parse'([integer],"+1",V),[]).

test(quoted_strings_decode_only_the_four_literal_escapes) :-
    forall(member(Text-Expected,["\"\\\"\\\\\\n\\t\""-"\"\\\n\t",
                                  "\"\u0000😀\""-"\u0000😀"]),
        (invoke('grammar-parse'([quoted],Text,Actual)),assertion(Actual==Expected))),
    forall(member(Text,["\"\\r\"","\"\\u0041\"","\"unfinished","\"x\\"]),
        findall(V,'grammar-parse'([quoted],Text,V),[])).

test(answer_order_keeps_duplicates_and_shorter_prefixes) :-
    findall(V,'grammar-parse-prefix'([many,[any]],"ab",V),Many),
    assertion(Many==[[["a","b"],""],[["a"],"b"],[[],"ab"]]),
    findall(V,'grammar-parse-prefix'([optional,[lit,""]],"x",V),Optional),
    assertion(Optional==[[[""],"x"],[[],"x"]]),
    findall(V,'grammar-parse'([alt,[digits],[digits],[nonblanks]],"12",V),
            ["12","12","12"]),
    findall(V,'grammar-parse'(['sep-by',[until,","],[lit,","]],"",V),[[""],[]]).

test(skipped_and_arbitrary_literal_contributions_are_distinct) :-
    forall(member(Value,['$skip','Empty',['Error',data,code],['+',1,2]]),
        (Callback=['|->',[_Token],[quote,Value]],
         invoke('grammar-parse'([map,Callback,[digits]],"12",Actual)),
         assertion(Actual==Value),
         invoke('grammar-parse'([cat,[map,Callback,[digits]]],"12",Wrapped)),
         assertion(Wrapped==[Value]))),
    invoke('grammar-parse'([many,[skip,[lit,"x"]]],"xx",[[],[]])),
    Callback=['|->',[_Input],[quote,[X,Y,X]]],
    invoke('grammar-parse'([map,Callback,[digits]],"12",Shared)),
    assertion(Shared==[X,Y,X]), assertion(var(X)), assertion(var(Y)), assertion(X\==Y).

test(repeated_success_must_consume_input) :-
    forall(member(Grammar,[[many,[cat]],[many1,[lit,""]],
                            ['sep-by',[cat],[cat]]]),
        (catch(invoke('grammar-parse'(Grammar,"",_)),Error,true),
         assertion(nonvar(Error)),
         assertion(Error=error(metta_assertion_failed(
            [assertEqualMsg,_,true,[quote,['grammar-parser',
              "a repeated parser must consume input; change the repeated part or its separator",_]]],_,_),_)))).

test(checking_a_grammar_does_not_run_its_callbacks) :-
    process_metta_string("(= (parsing-must-not-run) (assertEqual False True))",_),
    forall(member(Grammar,[[ref,'parsing-must-not-run'],
                           [map,'parsing-must-not-run',[digits]],
                           ['char-if','parsing-must-not-run'],
                           [as,[nosuch],[digits]]]),
        invoke('grammar-is'(Grammar,true))).

test(callable_parsers_and_literal_tokens_keep_caller_identity) :-
    invoke('grammar-parser'([any],Parser)),
    invoke('apply-to'(Parser,[[X,Y]],Answer)),
    assertion(Answer==[[X],[Y]]), assertion(var(X)), assertion(var(Y)), assertion(X\==Y),
    invoke('apply-to'(Parser,[[['+',1,2],['Error',data,code]]],Literal)),
    assertion(Literal==[[['+',1,2]],[['Error',data,code]]]).

test(variadic_grammar_forms_have_no_fixed_limit) :-
    forall(member(Count,[0,1,2,12,24]),
        (length(Parts,Count),maplist(=([lit,""]),Parts),
         invoke('grammar-parse'([cat|Parts],"",Values)),length(Values,Count),
         findall(V,'grammar-parse'([alt|Parts],"",V),Answers),length(Answers,Count))).

test(host_injected_open_improper_and_cyclic_values_refuse) :-
    Open=[any|Tail], Cycle=[many,Cycle],
    forall(member(Grammar,[Open,[any|bad],Cycle]),
        refused('grammar-parser'(Grammar,_))),
    assertion(var(Tail)),
    invoke('grammar-parser'([any],Parser)),
    CyclicInput=[a|CyclicInput],
    forall(member(Input,[[a|Tail],[a|bad],CyclicInput]),
        refused('apply-to'(Parser,[Input],_))),
    assertion(var(Tail)).

:- end_tests(lib_parsing).
