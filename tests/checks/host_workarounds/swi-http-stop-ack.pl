% Purpose: detect an HTTP shutdown acknowledgement left in the caller mailbox.
% Guarantees: a real server stops before the verdict; the fixture forces the
% first native acknowledgement wait to take its timeout branch.
% [tested: sh check.sh host-workarounds; commit=0f22b69cfca5c108e4126bdd56ab9bb2e493744d].
% Owns resources: one native HTTP server and a temporary receive wrapper.

:- use_module(library(http/thread_httpd), [http_server/2,http_stop_server/2]).
:- use_module(library(prolog_wrap), [wrap_predicate/4,unwrap_predicate/2]).
:- use_module(library(lists), [memberchk/2]).

main :-
    thread_self(Main),flag(http_ack_probe,_,0),
    setup_call_cleanup(
        wrap_predicate(system:thread_get_message(Receiver,Message,Options),
            http_ack_probe,Wrapped,
            ( Receiver==Main,Message==http_stopped,memberchk(timeout(_),Options),
              flag(http_ack_probe,N,N+1),N=:=0
            -> fail ; call(Wrapped) )),
        ( http_server(writeln,[port('127.0.0.1':Port),workers(1),silent(true)]),
          http_stop_server(Port,[]),
          ( thread_get_message(Main,http_stopped,[timeout(0)])
          -> Verdict=present ; Verdict=absent ) ),
        unwrap_predicate(system:thread_get_message(_,_,_),http_ack_probe)),
    writeln(Verdict).
