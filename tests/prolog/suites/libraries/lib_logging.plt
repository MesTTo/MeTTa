% Purpose: verify structured host routing, explicit handlers and topic state.
% Guarantees: hooks keep their precedence, complete payloads remain held,
% handler failures propagate and concurrent topic changes keep one registry row.
% [tested: lib_logging; commit=cf6b111ffad74477d9fa7169b215379dcabe721c].
% Owns resources: the host owns concurrent workers; test topic names remain
% registered but disabled. Each test clears its thread-local observed messages.
% Guarded by: observed/3 is thread-local; topic changes use the library's mutex.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_logging/lib_logging').
:- use_module(library(lists), [member/2]).
:- use_module(library(thread), [concurrent/3]).
:- use_module(library(debug), [debugging/2]).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_logging).
:- thread_local observed/3.
:- multifile user:message_hook/3, user:thread_message_hook/3.

% This observer is after the library hook. A True handler consumes before it;
% a False handler and a default message reach it with their original structure.
user:message_hook(metta_library_log(_,['log-event',"suite-host",Level,Payload]),
                  Kind, Lines) :-
    assertz(observed(Level-Payload,Kind,Lines)).
user:thread_message_hook(metta_library_log(_,['log-event',"suite-before",Level,Payload]),
                         Kind, Lines) :-
    assertz(observed(Level-Payload,Kind,Lines)).

quiet(Topic) :- 'log-topic!'(Topic,false,_), retractall(observed(_,_,_)).

test(unknown_topics_do_not_register) :-
    'log-topics'(Before),
    'log-enabled'("suite-unknown",Enabled), assertion(Enabled == false),
    'log-to!'(missing,"suite-unknown",error,['/',1,0],Unit), assertion(Unit == []),
    'log-topics'(After), assertion(After == Before).

test(topic_state_is_shared_with_host_and_exact,
     [cleanup((quiet("suite-topic"),quiet("suite-topic.child")))]) :-
    'log-topic!'("suite-topic",true,Unit), assertion(Unit == []),
    assertion(debugging(metta_log("suite-topic"),true)),
    'log-enabled'("suite-topic.child",Child), assertion(Child == false),
    'log-topic!'("suite-topic.child",false,_),
    'log-topics'(Rows), assertion(member(['log-topic',"suite-topic",true],Rows)),
    assertion(member(['log-topic',"suite-topic.child",false],Rows)),
    'log-topic!'("suite-topic",false,_),
    'log-enabled'("suite-topic",Disabled), assertion(Disabled == false).

test(every_level_reaches_the_host_with_structure,[cleanup(quiet("suite-host"))]) :-
    'log-topic!'("suite-host",true,_),
    'log-levels'(Levels), assertion(Levels == [debug,informational,warning,error]),
    forall(member(Level,Levels),
           ('log!'("suite-host",Level,[payload,42],Unit),assertion(Unit == []))),
    findall(Level-Payload-Kind,observed(Level-Payload,Kind,_),Rows),
    assertion(Rows == [debug-[payload,42]-debug(metta_log("suite-host")),
                       informational-[payload,42]-informational,
                       warning-[payload,42]-warning,error-[payload,42]-error]).

test(handlers_preserve_runnable_and_complete_payloads,[cleanup(quiet("suite-host"))]) :-
    'log-topic!'("suite-host",true,_), string_codes(Nul,[97,0,98]),
    forall(member(Payload,[[],['+',1,2],['empty'],['superpose',[1,2]],Nul,42,true]),
           (Expected=['log-event',"suite-host",warning,Payload],
            Handler=['|->',[Event],['==',[quote,Event],[quote,Expected]]],
            'log-to!'(Handler,"suite-host",warning,Payload,Unit),
            assertion(Unit == []))),
    assertion(\+ observed(_,_,_)).

test(false_verdict_delegates_and_first_true_consumes,[cleanup(quiet("suite-host"))]) :-
    'log-topic!'("suite-host",true,_),
    'log-to!'(['|->',[_],false],"suite-host",warning,delegated,_),
    assertion(observed(warning-delegated,warning,_)),
    retractall(observed(_,_,_)),
    'log-to!'(['|->',[_],['superpose',[true,false]]],"suite-host",warning,consumed,_),
    assertion(\+ observed(_,_,_)).

test(earlier_thread_hook_keeps_precedence,[cleanup(quiet("suite-before"))]) :-
    'log-topic!'("suite-before",true,_),
    'log-to!'(missing,"suite-before",warning,captured,_),
    assertion(observed(warning-captured,warning,_)).

test(handler_refusals_and_exceptions_are_not_swallowed,[cleanup(quiet("suite-host"))]) :-
    'log-topic!'("suite-host",true,_),
    must_throw('log-to!'(['|->',[_],7],"suite-host",debug,x,_),
               error(domain_error(log_handler_verdict,7),_)),
    must_throw('log-to!'(['|->',[_],['empty']],"suite-host",debug,x,_),
               error(existence_error(log_handler_answer,_),_)),
    must_throw('log-to!'(missing,"suite-host",debug,x,_),
               error(domain_error(log_handler_verdict,_),_)),
    must_throw('log-to!'(['|->',[_],['/',1,0]],"suite-host",debug,x,_),
               error(domain_error(log_handler_verdict,['Error',[/,1,0],'DivisionByZero']),_)),
    process_metta_string("!(import! &self (library lib_logging))",_),
    must_throw('log-to!'(['|->',[_],['log-format',"suite-host",fatal,x]],
                         "suite-host",debug,x,_),
               error(domain_error(log_level,fatal),_)),
    assertion(\+ observed(_,_,_)).

test(formatting_is_pure_and_matches_the_host_translation,[cleanup(quiet("suite-host"))]) :-
    'log-topics'(Before),
    'log-format'("suite-format",debug,['+',1,2],Text),
    assertion(Text == "suite-format [debug] (+ 1 2)"),
    'log-topics'(After), assertion(After == Before),
    'log-topic!'("suite-host",true,_),
    'log!'("suite-host",warning,[payload,"text"],_),
    observed(_,_,Lines), print_message_lines(atom(Printed),'',Lines),
    'log-format'("suite-host",warning,[payload,"text"],Formatted),
    atom_string(Printed,PrintedString),
    string_concat(Formatted,"\n",PrintedString).

flip_topic(Name) :-
    forall(between(1,32,_),('log-topic!'(Name,true,_),'log-topic!'(Name,false,_))),
    'log-topic!'(Name,true,_).

test(concurrent_changes_do_not_duplicate_topics,
     [cleanup((quiet("suite-race-a"),quiet("suite-race-b")))]) :-
    findall(plunit_lib_logging:flip_topic(Name),
            (between(1,4,_),member(Name,["suite-race-a","suite-race-b"])),Goals),
    concurrent(4,Goals,[]),
    forall(member(Name,["suite-race-a","suite-race-b"]),
           (findall(State,debugging(metta_log(Name),State),States),
            assertion(States == [true]))).

test(refusals_identify_repair) :-
    must_throw('log-topic!'(42,true,_),error(type_error(string,42),_)),
    must_throw('log-topic!'("suite-invalid",7,_),error(type_error(boolean,7),_)),
    must_throw('log!'("suite-invalid",fatal,x,_),
               error(domain_error(log_level,fatal),context('log!',choose_one_of(_)))),
    must_throw('log-format'("suite-invalid",fatal,x,_),error(domain_error(log_level,fatal),_)).

:- end_tests(lib_logging).
