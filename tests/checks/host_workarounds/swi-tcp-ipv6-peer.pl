% Purpose: compare native TCP peer addresses against IPv4 and IPv6 loopback.
% Guarantees: present identifies the IPv6 peer formatted as ip(0,0,0,0),
% and absent requires the complete IPv6 loopback address.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: cleanup closes listeners, clients and accepted sockets.

:- use_module(library(socket),
              [socket_create/2,tcp_bind/2,tcp_listen/2,tcp_connect/3,
               tcp_accept/3,tcp_close_socket/1]).

main :-
    peer(inet,'127.0.0.1',Control),
    ( Control==ip(127,0,0,1) -> true ; throw(error(tcp_ipv4_control(Control),_)) ),
    peer(inet6,'::1',Peer),
    ( Peer==ip(0,0,0,0,0,0,0,1) -> writeln(absent)
    ; Peer==ip(0,0,0,0) -> writeln(present)
    ; throw(error(unexpected_tcp_ipv6_peer(Peer),_)) ).

peer(Domain,Host,Peer) :-
    setup_call_cleanup(socket_create(Listener,[domain(Domain)]),
        (tcp_bind(Listener,Host:Port),tcp_listen(Listener,8),
         setup_call_cleanup(tcp_connect(Host:Port,Client,[domain(Domain),bypass_proxy(true)]),
            setup_call_cleanup(tcp_accept(Listener,Accepted,Peer),true,tcp_close_socket(Accepted)),
            close(Client))),
        tcp_close_socket(Listener)).
