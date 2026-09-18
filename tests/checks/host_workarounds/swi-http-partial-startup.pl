% Purpose: detect workers and queues retained after an HTTP server startup error.
% Guarantees: only the deliberately occupied accept-thread alias triggers the
% verdict; every fixture resource is released before present or absent prints.
% [tested: sh check.sh host-workarounds; commit=0f22b69cfca5c108e4126bdd56ab9bb2e493744d].
% Owns resources: a bound socket, alias-holder thread and any leaked worker queue.

:- use_module(library(http/thread_httpd), [http_server/2,http_stop_server/2]).
:- use_module(library(socket), [tcp_socket/1,tcp_bind/2,tcp_listen/2,tcp_close_socket/1]).

main :-
    setup_call_cleanup(tcp_socket(Socket),
        ( tcp_bind(Socket,'127.0.0.1':Port),tcp_listen(Socket,5),
          format(atom(Alias),'http@~d',[Port]),
          format(atom(Queue),'httpd@127.0.0.1:~d',[Port]),
          setup_call_cleanup(thread_create(thread_get_message(stop),Thread,[alias(Alias)]),
              startup(Socket,Port,Alias,Queue,Verdict),
              (thread_send_message(Thread,stop),thread_join(Thread,true))) ),
        close_socket(Socket)),
    writeln(Verdict).

startup(Socket,Port,Alias,Queue,Verdict) :-
    setup_call_cleanup(true,
        ( catch(http_server(writeln,[port('127.0.0.1':Port),tcp_socket(Socket),
                                     workers(1),silent(true)]),Error,true),
          ( var(Error)
          -> http_stop_server(Port,[]),throw(error(unexpected_http_startup_success,_))
          ; Error=error(permission_error(create,thread,Alias),_) -> true
          ; throw(Error) ),
          findall(W,thread_httpd:queue_worker(Queue,W),Workers),
          ( Workers\==[] -> Verdict=present
          ; queue_exists(Queue) -> Verdict=present ; Verdict=absent ) ),
        cleanup_queue(Queue)).

cleanup_queue(Queue) :-
    ( queue_exists(Queue)
    -> thread_httpd:resize_pool(Queue,0),
       retractall(thread_httpd:queue_options(Queue,_)),message_queue_destroy(Queue)
    ; true ),
    ( thread_httpd:queue_worker(Queue,_) -> throw(error(http_worker_cleanup_failed,_))
    ; true ).

queue_exists(Queue) :-
    catch(message_queue_property(Queue,size(_)),
          error(existence_error(message_queue,Queue),_),fail).

close_socket(Socket) :-
    catch(tcp_close_socket(Socket),error(existence_error(socket,Socket),_),true).
