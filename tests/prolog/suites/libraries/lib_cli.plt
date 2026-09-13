% Purpose: verify typed argv parsing, declaration boundaries and decoder ownership.
% Guarantees: independent repeat models cover defaults and retained order;
% fixtures exercise literal tokens, refusal context and each decoder exit.
% [tested: lib_cli; commit=WORKTREE].
% Owns resources: fixtures release message queues and execution spaces.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_cli/lib_cli').
:- use_module(library(lists), [member/2,memberchk/2]).
:- use_module(library(apply), [maplist/3]).
:- initialization(cli_suite_setup).

cli_suite_setup :-
    import_prolog_functions(['cli-parse','cli-help','cli-types','cli-arguments!',
                            'cli-suite-decoder','cli-suite-binding'],_),
    filereader:metta_host_run_source("!(import! &self (library lib_string))\n!(import! &self (library lib_cli))",'&self',[],_).

'cli-suite-decoder'(Queue,Mode,Text,Value) :-
    call_cleanup(
        (thread_send_message(Queue,opened(Text)),
         cli_suite_answer(Mode,Text,Value),thread_send_message(Queue,visited)),
        thread_send_message(Queue,closed)).
cli_suite_answer(one,Text,Text).
cli_suite_answer(none,_,_) :- fail.
cli_suite_answer(many,_,Value) :- between(1,3,Value).
cli_suite_answer(raise,Text,_) :- throw(cli_decoder_failed(Text)).
cli_suite_answer(wrong,_,42).
cli_suite_answer(cyclic,_,Value) :- Value=[Value].
'cli-suite-binding'(Original,Text,Text) :- Original=bound.

:- begin_tests(lib_cli).
:- meta_predicate must_throw(0,?), with_queue(1).

must_throw(Goal,Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error=Expected).
with_queue(Goal) :-
    setup_call_cleanup(message_queue_create(Queue),call(Goal,Queue),
                       message_queue_destroy(Queue)).
messages(Queue,Values) :-
    ( thread_get_message(Queue,Value,[timeout(0)])
    -> Values=[Value|Rest],messages(Queue,Rest)
    ; Values=[] ).
spec([[[opt,n],[type,integer],[shortflags,[n]],[longflags,[number]],[default,10]],
      [[opt,text],[shortflags,[t]],[longflags,[text]],[default,"guest"]],
      [[opt,verbose],[type,boolean],[shortflags,[v]],[longflags,[verbose]],[default,false]]]).
scan(Args,Policy,Result) :- spec(Spec),'cli-parse'(Spec,Args,Policy,Result).
decoder(Queue,Mode,Type,[[[opt,value],[type,[parse,Type,['cli-suite-decoder',Queue,Mode]]],
                        [longflags,[value]]]]).

test(defaults_and_absence_have_distinct_representations) :-
    scan([],keepall,Result),assertion(Result==[[[n,10],[text,"guest"],[verbose,false]],[]]),
    'cli-parse'([[[opt,missing]],[[opt,symbol],[type,atom],[default,'_']],
                 [[opt,text],[default,"_"]]],[],keepall,Other),
    assertion(Other==[[[symbol,'_'],[text,"_"]],[]]).

test(repeated_options_match_an_independent_occurrence_model) :-
    forall((between(-2,2,A),between(-2,2,B),between(-2,2,C),
            member(Policy,[keepfirst,keeplast,keepall])),
        (format(string(X),'--number=~d',[A]),format(string(Y),'-n~d',[B]),
         format(string(Z),'--number=~d',[C]),
         scan([X,"--text=middle",Y,Z],Policy,[Actual,[]]),
         repeat_model(Policy,A,B,C,Expected),assertion(Actual==Expected))).
repeat_model(keepfirst,A,_,_,[[verbose,false],[n,A],[text,"middle"]]).
repeat_model(keeplast,_,_,C,[[verbose,false],[text,"middle"],[n,C]]).
repeat_model(keepall,A,B,C,[[verbose,false],[n,A],[text,"middle"],[n,B],[n,C]]).

test(literal_tokens_keep_empty_unicode_nul_and_equals) :-
    string_codes(Nul,[97,0,98]),
    forall(member(Text,["","π🙂",Nul,"a=b=c","--number","-","007"]),
        (string_concat("--text=",Text,Arg),scan([Arg],keepall,[Pairs,[]]),
         assertion(Pairs==[[n,10],[verbose,false],[text,Text]]))),
    scan(["--text",""],keepall,[Pairs,[]]),
    assertion(Pairs==[[n,10],[verbose,false],[text,""]]).

test(terminator_preserves_every_later_token) :-
    scan(["first","--","--number","3","--",""],keepall,[Pairs,Operands]),
    assertion(Pairs==[[n,10],[text,"guest"],[verbose,false]]),
    assertion(Operands==["first","--number","3","--",""]),
    'cli-parse'([],["-","-2","-1.5",""],keepall,[[],Values]),
    assertion(Values==["-","-2","-1.5",""]).

test(boolean_forms_emit_one_value_per_occurrence) :-
    scan(["--verbose=false","-vtrue","--no-verbose","-v","false","file"],keepall,Result),
    assertion(Result==[[[n,10],[text,"guest"],[verbose,false],[verbose,true],
                        [verbose,false],[verbose,false]],["file"]]),
    'cli-parse'([[[opt,v],[type,boolean],[longflags,[verbose]]],
                 [[opt,named],[longflags,['no-verbose']]]],
                ["--no-verbose","literal"],keepall,Named),
    assertion(Named==[[[named,"literal"]],[]]).

test(literal_names_and_namespaces_come_from_declarations) :-
    'cli-parse'([[[opt,short],[shortflags,[x]]],[[opt,long],[longflags,[x]]],
                 [[opt,digit],[shortflags,["2"]],[type,integer]],
                 [[opt,mark],[longflags,['9?']]]],
                ["-xleft","--x=right","-2","7","--9?=yes"],keepall,Result),
    assertion(Result==[[[short,"left"],[long,"right"],[digit,7],[mark,"yes"]],[]]).

test(there_is_no_fixed_alias_or_declaration_limit) :-
    findall(Name,(between(1,100,N),format(atom(Name),'count~d',[N])),Names),
    'cli-parse'([[[opt,n],[type,integer],[longflags,Names]]],
                ["--count100=7"],keepall,Result),assertion(Result==[[[n,7]],[]]),
    findall([[opt,Key],[type,integer],[default,N]],
            (between(1,100,N),format(atom(Key),'key~d',[N])),Spec),
    'cli-parse'(Spec,[],keepall,[Pairs,[]]),length(Pairs,100),
    assertion(memberchk([key100,100],Pairs)).

test(native_values_and_metta_syntax_stay_literal) :-
    'cli-parse'([[[opt,a],[type,atom],[longflags,[atom]]],
                 [[opt,f],[type,float],[longflags,[float]]],
                 [[opt,e],[type,metta],[longflags,[expr]]]],
                ["--atom=true","--float=1.5","--expr=(+ 1 2)"],keepall,Result),
    assertion(Result==[[[a,true],[f,1.5],[e,['+',1,2]]],[]]),
    'cli-parse'([[[opt,e],[type,metta],[longflags,[expr]]]],
                ["--expr=(row $x $x)"],keepall,[[[e,[row,A,B]]],[]]),
    assertion(var(A)),assertion(A==B).

test(missing_unknown_and_malformed_tokens_name_the_repair) :-
    forall(member(Args,[["--text"],["--text","--verbose"],["--unknown"],
                        ["--bad?"],["-n=3"],["-vn"],["--no-verbose=false"]]),
        must_throw(scan(Args,keepall,_),error(_,context('cli-parse',_)))).

test(native_conversion_retains_context_and_prints_nothing) :-
    with_output_to(string(Printed),
        must_throw(scan(["--number=bad","--number=3"],keeplast,_),
                   error(cli_value('--number=bad',integer,bad,error(syntax_error(_),_)),
                         context('cli-parse',_)))),
    assertion(Printed=="").

test(invalid_repeat_policy_refuses_even_for_empty_input) :-
    must_throw('cli-parse'([],[],unknown,_),error(domain_error(cli_duplicates,unknown),_)).

test(schema_refuses_duplicate_unknown_and_missing_fields) :-
    forall(member(Spec,[[[[opt,x]],[[opt,x]]],
        [[[opt,x],[type,integer],[type,integer]]],
        [[[opt,x],[longflags,[same]]],[[opt,y],[longflags,[same]]]],
        [[[opt,x],[longflags,[same,same]]]],[[[opt,x],[wat,1]]],[[[type,string]]],
        [[[opt,x],[type,unknown]]],[[[opt,x],[type,integer],[default,"bad"]]],
        [[[opt,x],[help,["first",symbol]]]],[[[opt,x],[meta,symbol]]]]),
        must_throw('cli-parse'(Spec,[],keepall,_),error(_,_))).

test(schema_refuses_malformed_names_and_structures) :-
    string_codes(Nul,[97,0,98]),
    forall(member(Name,["",'bad name','bad=name',Nul,"\n"]),
        must_throw('cli-parse'([[[opt,x],[longflags,[Name]]]],[],keepall,_),error(_,_))),
    forall(member(Name,['-',ab,12]),
        must_throw('cli-parse'([[[opt,x],[shortflags,[Name]]]],[],keepall,_),error(_,_))),
    Cycle=[Cycle],
    forall(member(Spec,[_Schema,a,[[opt,x]|tail],Cycle,[[[opt,x],[default,_]]]]),
        must_throw('cli-parse'(Spec,[],keepall,_),error(_,_))),
    forall(member(Args,[_Arguments,[symbol],["ok"|tail]]),
        must_throw('cli-parse'([],Args,keepall,_),error(_,_))).

test(decoder_single_answer_is_owned_and_quoted) :- with_queue(single_case).
single_case(Queue) :-
    decoder(Queue,one,'String',Spec),
    'cli-parse'(Spec,["--value=(+ 1 2)"],keepall,Result),
    assertion(Result==[[[value,"(+ 1 2)"]],[]]),messages(Queue,Events),
    assertion(Events==[opened("(+ 1 2)"),visited,closed]).

test(decoder_cardinality_stops_at_two_and_closes) :- with_queue(cardinality_case).
cardinality_case(Queue) :-
    forall(member(Mode-Expected,[none-[],many-[1,2]]),
        (decoder(Queue,Mode,'Number',Spec),
         must_throw('cli-parse'(Spec,["--value=x"],keepall,_),
             error(cli_option(value,error(domain_error(exactly_one_cli_answer,Expected),_)),_)),
         messages(Queue,Events),
         (Mode==none->assertion(Events==[opened("x"),closed]);
          assertion(Events==[opened("x"),visited,visited,closed])))).

test(decoder_exception_wrong_type_and_cycle_close_the_generator) :- with_queue(exit_case).
exit_case(Queue) :-
    forall(member(Mode,[raise,wrong,cyclic]),
        (decoder(Queue,Mode,'String',Spec),
         must_throw('cli-parse'(Spec,["--value=x"],keepall,_),error(cli_option(value,_),_)),
         messages(Queue,Events),assertion(memberchk(closed,Events)))),
    decoder(Queue,raise,'String',Spec),
    must_throw('cli-parse'(Spec,["--value=x"],keepall,_),
               error(cli_option(value,cli_decoder_failed("x")),_)).

test(syntax_validation_precedes_custom_effects) :- with_queue(syntax_case).
syntax_case(Queue) :-
    decoder(Queue,one,'String',Spec),
    must_throw('cli-parse'(Spec,["--value=x","--unknown"],keepall,_),error(_,_)),
    messages(Queue,Events),assertion(Events==[]).

test(custom_occurrences_convert_before_repeat_selection) :- with_queue(repeat_case).
repeat_case(Queue) :-
    decoder(Queue,one,'String',Spec),
    'cli-parse'(Spec,["--value=first","--value=last"],keeplast,Result),
    assertion(Result==[[[value,"last"]],[]]),messages(Queue,Events),
    assertion(Events==[opened("first"),visited,closed,opened("last"),visited,closed]).

test(custom_refinements_check_both_answers_and_defaults) :-
    Type=[parse,['Annotated','Number',['Gt',0]],'parse-number'],
    Spec=[[[opt,n],[type,Type],[longflags,[number]],[default,1]]],
    'cli-parse'(Spec,["--number=3"],keepall,Result),assertion(Result==[[[n,3]],[]]),
    must_throw('cli-parse'(Spec,["--number=0"],keepall,_),error(cli_option(n,_),_)),
    must_throw('cli-help'([[[opt,n],[type,Type],[default,0]]],_),error(cli_option(n,_),_)).

test(declarations_do_not_bind_the_callers_function_template) :-
    Spec=[[[opt,value],[type,[parse,'String',['cli-suite-binding',Original]]],
            [longflags,[value]]]],
    'cli-parse'(Spec,["--value=text"],keepall,Result),
    assertion(Result==[[[value,"text"]],[]]),assertion(var(Original)).

test(help_uses_validated_defaults_and_does_not_run_converters) :- with_queue(help_case).
help_case(Queue) :-
    decoder(Queue,raise,'String',Spec),'cli-help'(Spec,Help),
    assertion(sub_string(Help,_,_,_,"String")),messages(Queue,Events),assertion(Events==[]),
    'cli-help'([],Empty),assertion(Empty==""),
    'cli-help'([[[opt,hidden],[default,"value"]]],Hidden),assertion(Hidden==""),
    'cli-help'([[[opt,n],[type,integer],[shortflags,[n]],[longflags,[number]],
                  [meta,"N"],[default,1],[help,["First","Second"]]]],Described),
    forall(member(Text,["-n","--number","N:integer=1","First","Second"]),
           assertion(sub_string(Described,_,_,_,Text))).

test(converters_resolve_in_each_calling_module) :-
    setup_call_cleanup('new-space'(Left),
        setup_call_cleanup('new-space'(Right),context_case(Left,Right),
                           spaces:metta_release_space(Right)),
        spaces:metta_release_space(Left)).
context_case(Left,Right) :-
    filereader:metta_host_run_source("!(import! &self (library lib_cli))\n(= (cli-local $x) \"left\")",Left,[],_),
    filereader:metta_host_run_source("!(import! &self (library lib_cli))\n(= (cli-local $x) \"right\")",Right,[],_),
    spaces:space_module(Left,LM),spaces:space_module(Right,RM),
    Spec=[[[opt,value],[type,[parse,'String','cli-local']],[longflags,[value]]]],
    with_metta_module(LM,'cli-parse'(Spec,["--value=x"],keepall,L)),
    with_metta_module(RM,'cli-parse'(Spec,["--value=x"],keepall,R)),
    assertion(L==[[[value,"left"]],[]]),assertion(R==[[[value,"right"]],[]]).

test(raw_arguments_use_strings_in_host_order) :-
    current_prolog_flag(argv,Native),maplist(atom_string,Native,Expected),
    'cli-arguments!'(Actual),assertion(Actual==Expected),
    'cli-types'(Types),assertion(Types==[boolean,integer,float,atom,string,metta]).

:- end_tests(lib_cli).
