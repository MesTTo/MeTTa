% Purpose: verify socket byte identity, endpoint metadata and resource lifetime.
% Guarantees: TCP and UDP cases use both IP families; generated datagrams exceed
% the host's default receive buffer, and concurrent readers preserve packets.
% [tested: lib_socket; commit=WORKTREE].
% Owns resources: fixtures close handles, cancel and join workers, restore
% wrapped predicates and release temporary execution spaces.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_socket/lib_socket').
:- use_module('../../../../lib/lib_file/lib_file',
              [known_file/2,adopt_file_stream/2,'file-close!'/2,
               'file-read-bytes!'/2,'file-read-bytes!'/3,'file-write-bytes!'/3]).
:- use_module(library(lists), [member/2,numlist/3]).
:- use_module(library(prolog_wrap), [wrap_predicate/4,unwrap_predicate/2]).
:- initialization(socket_suite_setup).

socket_suite_setup :-
    import_prolog_functions(['udp-bind!','tcp-listen!','tcp-accept!','socket-suite-answers',
                            'socket-suite-boom','socket-suite-buffer-boom','socket-suite-block',
                            'socket-suite-acquire-boom','socket-suite-acquire-wait',
                            'socket-suite-nested-acquire','socket-suite-open-more'],_).
'socket-suite-answers'(Handle,[Handle,N]) :- member(N,[1,2]).
'socket-suite-boom'(Handle,_) :- throw(error(socket_scope(Handle),_)).
'socket-suite-buffer-boom'(Handle,_) :-
    known_file(Handle,Stream),put_byte(Stream,42),throw(socket_buffered_cancelled).
'socket-suite-block'(Main,Operation,Handle,_) :-
    thread_self(Self),thread_send_message(Self,socket_observe_wait(Main,Handle)),
    call(Operation,Handle,_).
'socket-suite-acquire-boom'(_) :-
    'udp-bind!'([endpoint,ipv4,"127.0.0.1",0],A),
    'udp-bind!'([endpoint,ipv4,"127.0.0.1",0],B),throw(socket_acquisition_failed(A,B)).
'socket-suite-acquire-wait'(Main,_) :-
    'udp-bind!'([endpoint,ipv4,"127.0.0.1",0],Handle),thread_self(Self),
    thread_send_message(Main,socket_acquiring(Self,Handle)),thread_get_message(socket_never).
'socket-suite-nested-acquire'(Handle) :-
    'with-socket'(['udp-bind!',[endpoint,ipv4,"127.0.0.1",0]],'socket-suite-open-more',Handle).
'socket-suite-open-more'(_,Handle) :- 'udp-bind!'([endpoint,ipv4,"127.0.0.1",0],Handle).

:- begin_tests(lib_socket).
:- meta_predicate must_throw(0,?), with_udp(+,2), with_tcp(+,3), observing_waits(0),
                  reported_worker(+,0).

must_throw(Goal,Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error=Expected).
family(ipv4,"127.0.0.1").
family(ipv6,"::1").
handles(Handles) :- findall(H-S,lib_file:metta_file(H,S),Handles).
closed(Handle) :- assertion(\+ lib_file:metta_file(Handle,_)).
with_udp(Family,Goal) :-
    family(Family,Host),
    setup_call_cleanup('udp-bind!'([endpoint,Family,Host,0],Handle),
        ('socket-endpoint'(Handle,local,Address),call(Goal,Handle,Address)),
        'file-close!'(Handle,_)).
with_tcp(Family,Goal) :-
    family(Family,Host),
    setup_call_cleanup('tcp-listen!'([endpoint,Family,Host,0],8,Listener),
        ('socket-endpoint'(Listener,local,Address),
         setup_call_cleanup('tcp-connect!'(Address,Client),
            setup_call_cleanup('tcp-accept!'(Listener,Server),call(Goal,Listener,Client,Server),
                               'file-close!'(Server,_)),
            'file-close!'(Client,_))),
        'file-close!'(Listener,_)).
reap(Thread) :-
    call_cleanup(
        catch(thread_signal(Thread,throw(socket_fixture_cancelled)),error(existence_error(thread,_),_),true),
        catch(thread_join(Thread,_),error(existence_error(thread,_),_),true)).
payload(Length,Seed,Bytes) :-
    findall(B,(between(1,Length,I),B is (I*73+Seed) mod 256),Bytes).

test(socket_capability_is_declared) :-
    findall(Source,metta_engine:metta_platform_capability(socket,Source,_),Sources),
    assertion(Sources==[library(socket)]).

test(tcp_binary_identity_and_actual_endpoints_for_both_families) :-
    forall(family(Family,_),with_tcp(Family,tcp_exchange)).
tcp_exchange(Listener,Client,Server) :-
    'socket-kind'(Listener,LK),'socket-kind'(Client,CK),'socket-kind'(Server,SK),
    assertion(LK==listener),assertion(CK==tcp),assertion(SK==tcp),
    'socket-endpoint'(Listener,local,ListenAddress),
    'socket-endpoint'(Server,local,ServerAddress),
    'socket-endpoint'(Client,peer,ClientPeer),
    'socket-endpoint'(Server,peer,ServerPeer),'socket-endpoint'(Client,local,ClientAddress),
    assertion(ServerAddress==ListenAddress),assertion(ClientPeer==ListenAddress),
    assertion(ServerPeer==ClientAddress),ClientAddress=[endpoint,_,_,Port],assertion(Port>0),
    numlist(0,255,Bytes),'file-write-bytes!'(Client,Bytes,true),
    'file-read-bytes!'(Server,256,Actual),assertion(Actual==Bytes),
    'file-close!'(Listener,_),'file-write-bytes!'(Server,[255,0],true),
    'file-read-bytes!'(Client,2,Back),assertion(Back==[255,0]).

test(shutdown_flushes_output_and_keeps_the_other_direction) :-
    forall(family(Family,_),with_tcp(Family,shutdown_case)).
shutdown_case(_,Client,Server) :-
    known_file(Client,Stream),put_byte(Stream,42),
    'socket-shutdown!'(Client,write,true),'file-read-bytes!'(Server,Actual),
    assertion(Actual==[42]),'file-write-bytes!'(Server,[99],true),
    'file-read-bytes!'(Client,1,Back),assertion(Back==[99]),
    'socket-shutdown!'(Server,read,true),'socket-shutdown!'(Server,both,true),
    'socket-kind'(Client,tcp),'socket-kind'(Server,tcp).

test(udp_generated_packets_retain_every_byte_and_boundary) :-
    forall(family(Family,_),with_udp(Family,udp_generated)).
udp_generated(Handle,Address) :-
    forall(member(Length,[0,1,255,256,4097,32768,65000]),
           udp_case(Handle,Address,Length,0)),
    forall(between(1,100,Seed),
           (Length is (Seed*113) mod 8192,udp_case(Handle,Address,Length,Seed))),
    numlist(0,255,Bytes),'udp-send!'(Handle,Address,Bytes,true),
    'udp-receive!'(Handle,[datagram,From,Returned]),
    assertion(From==Address),assertion(Returned==Bytes).
udp_case(Handle,Address,Length,Seed) :-
    payload(Length,Seed,Bytes),'udp-send!'(Handle,Address,Bytes,true),
    'udp-receive!'(Handle,Packet),assertion(Packet==[datagram,Address,Bytes]).

test(udp_sender_is_the_other_socket_with_its_actual_port) :-
    forall(family(Family,_),with_udp(Family,second_sender(Family))).
second_sender(Family,Receiver,Destination) :-
    with_udp(Family,send_from(Receiver,Destination)).
send_from(Receiver,Destination,Sender,Source) :-
    'udp-send!'(Sender,Destination,[],true),'udp-receive!'(Receiver,Packet),
    assertion(Packet==[datagram,Source,[]]),assertion(Source\==Destination).

test(wait_preserves_order_duplicates_and_empty_sets) :-
    'socket-wait!'([],infinite,Empty),assertion(Empty==[]),
    with_udp(ipv4,wait_pair).
wait_pair(A,AA) :- with_udp(ipv4,wait_case(A,AA)).
wait_case(A,AA,B,BA) :-
    'socket-wait!'([A,B],0.001,None),assertion(None==[]),
    'udp-send!'(A,AA,[1],true),'socket-wait!'([B,A,B],0,One),assertion(One==[A]),
    'udp-send!'(B,BA,[2],true),'socket-wait!'([B,A,B],infinite,Both),assertion(Both==[B,A,B]),
    'udp-receive!'(A,_),'udp-receive!'(B,_).

test(listener_and_tcp_eof_are_readable) :- with_tcp(ipv4,eof_ready).
eof_ready(_,Client,Server) :-
    'socket-shutdown!'(Client,write,true),
    'socket-wait!'([Server],infinite,Ready),assertion(Ready==[Server]),
    'file-read-bytes!'(Server,Bytes),assertion(Bytes==[]).

test(invalid_or_oversized_datagrams_do_not_send_a_prefix) :-
    forall(family(Family,_),with_udp(Family,invalid_packets)).
invalid_packets(Handle,Address) :-
    forall(member(Bytes,[[1,256],[1,-1],[1,2.0],[1,x]]),
           must_throw('udp-send!'(Handle,Address,Bytes,_),error(_,_))),
    payload(70000,0,Huge),must_throw('udp-send!'(Handle,Address,Huge,_),error(_,_)),
    'socket-wait!'([Handle],0,Empty),assertion(Empty==[]),
    'udp-send!'(Handle,Address,[42],true),'udp-receive!'(Handle,Packet),
    assertion(Packet==[datagram,Address,[42]]).

test(scopes_close_after_exhaustion_cut_and_exception) :-
    handles(Before),Acquire=['udp-bind!',[endpoint,ipv4,"127.0.0.1",0]],
    findall(A,'with-socket'(Acquire,'socket-suite-answers',A),Answers),
    Answers=[[Handle,1],[Handle,2]],closed(Handle),
    once('with-socket'(Acquire,'socket-suite-answers',[Cut,_])),closed(Cut),
    catch('with-socket'(Acquire,'socket-suite-boom',_),error(socket_scope(Thrown),_),true),
    closed(Thrown),handles(After),assertion(After==Before).

test(invalid_acquired_file_kind_closes_the_owned_handle) :-
    handles(Before),open_string("owned",Stream),adopt_file_stream(Stream,Handle),
    must_throw('with-socket'([quote,Handle],'socket-suite-answers',_),error(_,_)),
    closed(Handle),assertion(\+ is_stream(Stream)),handles(After),assertion(After==Before).

test(exception_cleanup_discards_pending_output_and_releases_the_connection) :-
    with_tcp(ipv4,buffered_exception).
buffered_exception(_,Client,Server) :-
    must_throw('with-socket'([quote,Server],'socket-suite-buffer-boom',_),
               error(socket_cleanup(exception(socket_buffered_cancelled),
                                    [Server-error('file-operation-failed'('file-close!',_),_)]),_)),
    closed(Server),'file-read-bytes!'(Client,Bytes),assertion(Bytes==[]).

test(blocked_udp_and_accept_scopes_cancel_and_release) :-
    observing_waits(forall(member(Operation-Acquire,
                  ['udp-receive!'-['udp-bind!',[endpoint,ipv4,"127.0.0.1",0]],
                   'tcp-accept!'-['tcp-listen!',[endpoint,ipv6,"::1",0],8]]),
           cancellation_case(Operation,Acquire))).
cancellation_case(Operation,Acquire) :-
    handles(Before),thread_self(Main),
    Function=['socket-suite-block',[quote,Main],[quote,Operation]],
    setup_call_cleanup(thread_create(reported_worker(Main,'with-socket'(Acquire,Function,_)),Thread,[]),
        (expect_worker_event(Thread,waiting(Handle)),
         thread_signal(Thread,throw(socket_cancelled)),
         expect_worker_event(Thread,finished(exception(socket_cancelled))),thread_join(Thread,Status),
         assertion(Status==exception(socket_cancelled)),closed(Handle)),
        reap(Thread)),
    handles(After),assertion(After==Before).

observing_waits(Goal) :-
    setup_call_cleanup(
        wrap_predicate(system:wait_for_input(_,Ready,_),socket_wait_observer,Wrapped,
                       (call(Wrapped),report_empty_wait(Ready))),
        Goal,unwrap_predicate(system:wait_for_input(_,_,_),socket_wait_observer)).
report_empty_wait(Ready) :-
    thread_self(Self),
    ( Ready==[],thread_get_message(Self,socket_observe_wait(Main,Handle),[timeout(0)])
    -> thread_send_message(Main,socket_event(Self,waiting(Handle))) ; true ).
reported_worker(Main,Goal) :-
    setup_call_catcher_cleanup(true,Goal,Outcome,
        (thread_self(Self),thread_send_message(Main,socket_event(Self,finished(Outcome))))).
expect_worker_event(Worker,Expected) :-
    thread_get_message(socket_event(Worker,Actual)),assertion(Actual=Expected),Actual=Expected.

test(failed_acquisition_releases_every_new_socket_and_restores_context) :-
    handles(Before),lib_socket:acquisition_context(Context),
    forall(member(Acquire,[['socket-suite-acquire-boom'],
                          [let,_Collected,[collapse,['udp-bind!',[endpoint,ipv4,"127.0.0.1",0]]],
                           ['socket-suite-acquire-boom']]]),
        (must_throw('with-socket'(Acquire,'socket-suite-answers',_),socket_acquisition_failed(_,_)),
         handles(After),assertion(After==Before))),
    lib_socket:acquisition_context(Restored),
    assertion(Restored==Context).

test(arbitrary_acquisition_can_be_cancelled_before_returning_its_handle) :-
    handles(Before),thread_self(Main),
    setup_call_cleanup(thread_create(
        catch('with-socket'(['socket-suite-acquire-wait',[quote,Main]],'socket-suite-answers',_),
              socket_cancelled,
              (lib_socket:acquisition_context(Context),thread_send_message(Main,socket_restored(Context)))),
        Worker,[]),
        (thread_get_message(socket_acquiring(Worker,Handle)),
         thread_signal(Worker,throw(socket_cancelled)),thread_join(Worker,true),closed(Handle),
         thread_get_message(socket_restored(Restored)),assertion(Restored==none)),
        reap(Worker)),
    handles(After),assertion(After==Before).

test(nested_acquisition_transfers_the_returned_socket_to_its_parent) :-
    handles(Before),lib_socket:acquisition_context(Context),
    findall(A,'with-socket'(['socket-suite-nested-acquire'],'socket-suite-answers',A),Answers),
    Answers=[[Handle,1],[Handle,2]],closed(Handle),handles(After),assertion(After==Before),
    lib_socket:acquisition_context(Restored),assertion(Restored==Context).

test(scopes_evaluate_callbacks_in_the_calling_module) :-
    setup_call_cleanup('new-space'(Left),
        setup_call_cleanup('new-space'(Right),module_case(Left,Right),spaces:metta_release_space(Right)),
        spaces:metta_release_space(Left)).
module_case(Left,Right) :-
    filereader:metta_host_run_source("!(import! &self (library lib_socket))\n(: same-socket-callback (-> Number Number))\n(= (same-socket-callback $h) 11)",Left,[],_),
    filereader:metta_host_run_source("!(import! &self (library lib_socket))\n(: same-socket-callback (-> Number Number))\n(= (same-socket-callback $h) 22)",Right,[],_),
    spaces:space_module(Left,LM),spaces:space_module(Right,RM),
    Acquire=['udp-bind!',[endpoint,ipv4,"127.0.0.1",0]],
    with_metta_module(LM,'with-socket'(Acquire,'same-socket-callback',L)),
    with_metta_module(RM,'with-socket'(Acquire,'same-socket-callback',R)),
    assertion(L==11),assertion(R==22).

test(two_acceptors_race_one_connection_and_the_loser_remains_cancellable) :-
    handles(Before),
    setup_call_cleanup('tcp-listen!'([endpoint,ipv6,"::1",0],8,Listener),
                       observing_waits(acceptor_race(Listener)),
                       'file-close!'(Listener,_)),
    handles(After),assertion(After==Before).
acceptor_race(Listener) :-
    'socket-endpoint'(Listener,local,Address),thread_self(Main),
    setup_call_cleanup(thread_create(reported_worker(Main,accepting_worker(Main,Listener)),A,[]),
        setup_call_cleanup(thread_create(reported_worker(Main,accepting_worker(Main,Listener)),B,[]),
            (expect_worker_event(A,waiting(Listener)),expect_worker_event(B,waiting(Listener)),
             setup_call_cleanup('tcp-connect!'(Address,Client),
                (thread_get_message(socket_event(Winner,finished(Result))),assertion(Result==exit),
                 (Winner==A -> Loser=B ; Loser=A),
                 thread_signal(Loser,throw(socket_cancelled)),
                 expect_worker_event(Loser,finished(exception(socket_cancelled))),
                 thread_join(Loser,exception(socket_cancelled)),
                 thread_join(Winner,true)),
                'file-close!'(Client,_))),
            reap(B)),reap(A)).
accepting_worker(Main,Listener) :-
    thread_self(Self),thread_send_message(Self,socket_observe_wait(Main,Listener)),
    once('with-socket'(['tcp-accept!',Listener],'socket-suite-answers',_)).

test(concurrent_udp_readers_do_not_steal_or_duplicate_packets) :-
    with_udp(ipv4,concurrent_readers).
concurrent_readers(Handle,Address) :-
    known_file(Handle,Stream),thread_self(Main),
    setup_call_cleanup(
        wrap_predicate(lib_socket_native:receive(S,_,_,_,_),socket_receive_barrier,Wrapped,
                       (reader_barrier(S,Stream,Main),call(Wrapped))),
        setup_call_cleanup(thread_create(read_packet(Main,Handle),A,[]),
            setup_call_cleanup(thread_create(read_packet(Main,Handle),B,[]),
                (thread_get_message(socket_reader_ready(A)),thread_get_message(socket_reader_ready(B)),
                 'udp-send!'(Handle,Address,[1],true),
                 thread_send_message(A,socket_go),thread_send_message(B,socket_go),
                 thread_get_message(socket_packet(_,First)),assertion(First==[datagram,Address,[1]]),
                 'udp-send!'(Handle,Address,[2],true),
                 thread_get_message(socket_packet(_,Second)),assertion(Second==[datagram,Address,[2]]),
                 thread_join(A,SA),thread_join(B,SB),assertion(SA==true),assertion(SB==true)),
                reap(B)),reap(A)),
        unwrap_predicate(lib_socket_native:receive(_,_,_,_,_),socket_receive_barrier)).
reader_barrier(Stream,Target,Main) :-
    thread_self(Self),
    ( Stream==Target,thread_get_message(Self,socket_first_receive,[timeout(0)])
    -> thread_send_message(Main,socket_reader_ready(Self)),thread_get_message(socket_go)
    ; true ).
read_packet(Main,Handle) :-
    thread_self(Self),thread_send_message(Self,socket_first_receive),
    'udp-receive!'(Handle,Packet),thread_send_message(Main,socket_packet(Self,Packet)).

test(borrowed_stream_refuses_after_close) :-
    'udp-bind!'([endpoint,ipv4,"127.0.0.1",0],Handle),known_file(Handle,Stream),
    'file-close!'(Handle,_),closed(Handle),
    must_throw(lib_socket_native:endpoint(Stream,local,_,_,_),error(existence_error(stream,_),_)),
    must_throw('socket-kind'(Handle,_),error(existence_error(metta_file_handle,Handle),_)),
    with_udp(ipv4,stale_stream_case(Stream)).
stale_stream_case(Old,Handle,Address) :-
    must_throw(lib_socket_native:kind(Old,_),error(existence_error(stream,_),_)),
    'socket-endpoint'(Handle,local,Current),assertion(Current==Address).

test(native_errors_and_output_mismatch_release_stream_locks) :-
    with_udp(ipv6,native_lock_case).
native_lock_case(Handle,Address) :-
    known_file(Handle,Stream),
    must_throw(lib_socket_native:endpoint(Stream,peer,_,_,_),error(socket_native_error(getpeername,_,_),_)),
    assertion(\+ lib_socket_native:endpoint(Stream,local,wrong,_,_)),
    'udp-send!'(Handle,Address,[1],true),
    assertion(\+ lib_socket_native:receive(Stream,[999],_,_,_)),
    'udp-send!'(Handle,Address,[2],true),
    'udp-receive!'(Handle,Packet),assertion(Packet==[datagram,Address,[2]]).

test(failed_bind_and_connect_release_every_raw_descriptor,
     [condition(exists_directory('/proc/self/fd'))]) :-
    setup_call_cleanup('tcp-listen!'([endpoint,ipv4,"127.0.0.1",0],8,Listener),
        ('socket-endpoint'(Listener,local,Address),fd_count(Before),
         forall(between(1,30,_),must_throw('tcp-listen!'(Address,8,_),error(_,_))),
         fd_count(After),assertion(After==Before)),
        'file-close!'(Listener,_)),
    fd_count(BeforeConnect),
    forall(between(1,30,_),must_throw('tcp-connect!'(Address,_),error(_,_))),
    fd_count(AfterConnect),assertion(AfterConnect==BeforeConnect).
fd_count(Count) :- directory_files('/proc/self/fd',Names),length(Names,Count).

test(bound_output_is_refused_before_resource_acquisition) :-
    handles(Before),
    must_throw('udp-bind!'([endpoint,ipv4,"127.0.0.1",0],99),error(uninstantiation_error(99),_)),
    handles(After),assertion(After==Before).

test(adoption_cancellation_rolls_back_the_new_socket) :-
    handles(Before),
    setup_call_cleanup(
        wrap_predicate(lib_file:adopt_file_stream(Stream,_),socket_adopt_abort,Wrapped,
                       (call(Wrapped),throw(socket_adopt_cancelled(Stream)))),
        must_throw('udp-bind!'([endpoint,ipv4,"127.0.0.1",0],_),socket_adopt_cancelled(_)),
        unwrap_predicate(lib_file:adopt_file_stream(_,_),socket_adopt_abort)),
    handles(After),assertion(After==Before).

test(accept_owner_releases_foreign_outputs_and_post_return_exceptions,
     [condition(exists_directory('/proc/self/fd'))]) :-
    with_tcp(ipv4,accept_owner_failures).
accept_owner_failures(Listener,_,_) :-
    'socket-endpoint'(Listener,local,Address),known_file(Listener,Stream),
    forall(member(Failure,[input,output,exception]),
        setup_call_cleanup('tcp-connect!'(Address,Client),
            (fd_count(Before),
             setup_call_cleanup(lib_socket_native:accept_owner(Owner),
                 failed_native_accept(Failure,Owner,Stream),
                 lib_socket_native:finish_accept(Owner,false)),
             fd_count(After),assertion(After==Before)),
            'file-close!'(Client,_))).
failed_native_accept(input,Owner,Stream) :-
    assertion(\+ lib_socket_native:try_accept(Owner,Stream,wrong,_)).
failed_native_accept(output,Owner,Stream) :-
    assertion(\+ lib_socket_native:try_accept(Owner,Stream,_,wrong)).
failed_native_accept(exception,Owner,Stream) :-
    must_throw((lib_socket_native:try_accept(Owner,Stream,_,_),throw(accepted_then_failed)),
               accepted_then_failed).

test(accepted_file_publication_cancellation_removes_the_record_and_descriptor,
     [condition(exists_directory('/proc/self/fd'))]) :-
    with_tcp(ipv6,accept_publication_failure).
accept_publication_failure(Listener,_,_) :-
    'socket-endpoint'(Listener,local,Address),
    setup_call_cleanup('tcp-connect!'(Address,Client),
        (handles(Before),fd_count(FDs),
         setup_call_cleanup(
            wrap_predicate(lib_file:adopt_file_stream(_,_),socket_accept_abort,Wrapped,
                           (call(Wrapped),throw(accepted_publication_failed))),
            must_throw('tcp-accept!'(Listener,_),accepted_publication_failed),
            unwrap_predicate(lib_file:adopt_file_stream(_,_),socket_accept_abort)),
         handles(After),assertion(After==Before),fd_count(Remaining),assertion(Remaining==FDs)),
        'file-close!'(Client,_)).

test(transaction_refusals_precede_all_openers) :-
    Endpoint=[endpoint,ipv4,"127.0.0.1",0],handles(Before),
    forall(member(Goal,['udp-bind!'(Endpoint,_),'tcp-listen!'(Endpoint,8,_),
                       'tcp-connect!'(Endpoint,_),'tcp-accept!'(999,_),
                       'with-socket'([quote,999],'socket-suite-answers',_)]),
           must_throw(transaction(Goal),error(permission_error(open,transaction_socket,_),_))),
    handles(After),assertion(After==Before).

test(endpoint_timeout_and_kind_refusals_cover_complete_inputs) :-
    string_codes(NulHost,[97,0,98]),Cycle=[1|Cycle],
    forall(member(Endpoint,[[],[endpoint,unknown,"x",0],[endpoint,ipv4,"",0],
                           [endpoint,ipv4,NulHost,0],[endpoint,ipv4,"127.0.0.1",-1],
                           [endpoint,ipv4,"127.0.0.1",65536],
                           [endpoint,ipv4,"127.0.0.1",1.0]]),
           must_throw('udp-bind!'(Endpoint,_),error(_,_))),
    forall(member(Timeout,[-1,1.0Inf,1.5NaN,unknown]),
           must_throw('socket-wait!'([],Timeout,_),error(_,_))),
    must_throw('socket-wait!'([],_Timeout,_),error(instantiation_error,_)),
    must_throw('socket-wait!'(Cycle,0,_),error(type_error(list,_),_)),
    with_udp(ipv4,kind_refusals).
kind_refusals(Handle,Address) :-
    forall(member(Goal,['tcp-accept!'(Handle,_),'socket-shutdown!'(Handle,write,_),
                       'socket-endpoint'(Handle,unknown,_),
                       'udp-send!'(Handle,[endpoint,ipv6,"::1",1],[],_),
                       'udp-send!'(Handle,Address,[0|bad],_)]),must_throw(Goal,error(_,_))).

:- end_tests(lib_socket).
