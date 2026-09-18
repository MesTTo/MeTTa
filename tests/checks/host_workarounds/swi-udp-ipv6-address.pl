% Purpose: isolate the native IPv6 UDP address assertion from its parent process.
% Guarantees: an IPv4 control passes first; only the known unify_address abort
% gives present, while a complete IPv6 packet gives absent.
% [tested: sh check.sh host-workarounds; commit=781ee98e188c23ea7ef9298636d6e5e6c7fdc727].
% Owns resources: the parent closes the merged output pipe and joins its child;
% successful child cases close their sockets, and an abort releases process FDs.

:- use_module(library(process), [process_create/3,process_wait/2]).
:- use_module(library(socket),
              [socket_create/2,tcp_bind/2,tcp_close_socket/1,udp_send/4,udp_receive/4]).

main :-
    source_file(main,Source),current_prolog_flag(executable,Swipl),
    setup_call_cleanup(
        process_create(path(sh),
            ['-c','ulimit -c 0; exec "$@"',socket_reproduction,Swipl,
             '-q','-f',none,'-s',Source,'-g',udp_reproduction_child,'-t',halt],
            [stdin(null),stdout(pipe(Output)),stderr(pipe(Output)),process(PID)]),
        read_string(Output,_,Log),
        (close(Output),process_wait(PID,Status))),
    ( sub_string(Log,_,_,_,"ipv4-ok"),Status==killed(6),
      sub_string(Log,_,_,_,"unify_address"),sub_string(Log,_,_,_,"Assertion")
    -> writeln(present)
    ; Status==exit(0),sub_string(Log,_,_,_,"ipv6-ok") -> writeln(absent)
    ; throw(error(udp_ipv6_reproduction_failed(Status,Log),_)) ).

udp_reproduction_child :-
    datagram(inet,'127.0.0.1',ip(127,0,0,1)),writeln('ipv4-ok'),flush_output,
    datagram(inet6,'::1',ip(0,0,0,0,0,0,0,1)),writeln('ipv6-ok').
datagram(Domain,Host,ExpectedIP) :-
    setup_call_cleanup(socket_create(Socket,[domain(Domain),type(dgram)]),
        (tcp_bind(Socket,Host:Port),
         udp_send(Socket,[0,255],Host:Port,[as(codes),encoding(octet)]),
         udp_receive(Socket,Bytes,Peer,[as(codes),encoding(octet),max_message_size(65535)]),
         (Bytes==[0,255],Peer==ExpectedIP:Port -> true
         ; throw(error(udp_endpoint_mismatch(Bytes,Peer,ExpectedIP:Port),_)))),
        tcp_close_socket(Socket)).
