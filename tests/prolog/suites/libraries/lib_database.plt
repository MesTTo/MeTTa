% Purpose: verify persistent multiset semantics and complete store ownership.
% Guarantees: generated operations agree with a list model; lifecycle tests
% exercise independent engines, aliases, cancellation, failed I/O and replay.
% Request completion interrupts a milestone wait even after early failure.
% [tested: lib_database; commit=b7866b4d874879ff0cb212eb1c6af60dddaa39c6].
% Owns resources: fixtures close stores and queues, join workers, release
% execution spaces, restore wrapped predicates and delete temporary directories.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_file/lib_file', []).
:- use_module('../../../../lib/lib_database/lib_database').
:- use_module(library(filesex), [directory_file_path/3,delete_directory_and_contents/1,link_file/3]).
:- use_module(library(lists), [member/2,append/3,selectchk/3,nth0/3]).
:- use_module(library(apply), [maplist/2,maplist/3]).
:- use_module(library(thread), [concurrent/3]).
:- use_module(library(dif), [dif/2]).
:- use_module(library(readutil), [read_file_to_string/3]).
:- use_module(library(prolog_wrap), [wrap_predicate/4,unwrap_predicate/2]).
:- initialization(database_suite_setup).

database_suite_setup :-
    import_prolog_functions(['database-suite-answers','database-suite-boom',
                            'database-suite-fail','database-suite-close'],_).
'database-suite-answers'(Handle,[Handle,N]) :- member(N,[1,2]).
'database-suite-boom'(Handle,_) :- throw(database_scope_cancelled(Handle)).
'database-suite-fail'(Handle,_) :- 'database-add!'(Handle,before_failure,true),fail.
'database-suite-close'(Handle,true) :- 'database-close!'(Handle,true).

:- multifile seam:pattern_modifier/3.
seam:pattern_modifier([Marker],_,throw(database_query_cancelled)) :-
    nonvar(Marker),Marker==database_suite_guard.

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_database).
:- meta_predicate with_directory(1), with_store(+,2), reported_request(+,0).

with_directory(Goal) :-
    tmp_file(database_suite,Directory),
    setup_call_cleanup(make_directory(Directory),call(Goal,Directory),
                       delete_directory_and_contents(Directory)).
with_store(Sync,Goal) :- with_directory(store_fixture(Sync,Goal)).
store_fixture(Sync,Goal,Directory) :-
    setup_call_cleanup('database-open!'(Directory,Sync,Handle),
                       call(Goal,Directory,Handle),'database-close!'(Handle,_)).
journal(Directory,Path) :- directory_file_path(Directory,'journal.pl',Path).
closed(Handle) :-
    must_throw('database-atoms'(Handle,_),error(existence_error(database,Handle),_)),
    'database-close!'(Handle,true).
write_text(Path,Text) :-
    setup_call_cleanup(open(Path,write,Out,[encoding(utf8)]),write(Out,Text),close(Out)).
add_value(Handle,Value) :- 'database-add!'(Handle,Value,true).
select_snapshot(Handle,Pattern,Template,Rows) :-
    'database-atoms'(Handle,Snapshot),current_metta_module(Module),
    Expression=[collapse,
                [let,[[':seg',_],Row,[':seg',_]],[quote,Snapshot],
                 [let,true,[unify,Pattern,Row,true,false],[quote,Template]]]],
    eval_metta_in_module(Module,Expression,Rows).
reopen_rows(Directory,Expected) :-
    setup_call_cleanup('database-open!'(Directory,flush,Handle),
        ('database-atoms'(Handle,Rows),assertion(Rows==Expected)),
        'database-close!'(Handle,_)).
store_module(Directory,Module) :- journal(Directory,Path),persistency:db_file(Module,Path,_,_,_).
no_registration(Module,Journal) :-
    assertion(\+ current_module(Module)),
    assertion(\+ persistency:persistent(Module,_,_)),
    assertion(\+ persistency:db_file(Module,_,_,_,_)),
    assertion(\+ persistency:db_stream(Module,_)),
    assertion(\+ persistency:db_option(Module,_)),
    assertion(\+ stream_property(_,file_name(Journal))).

test(persistency_capability_is_declared) :-
    findall(Source,metta_engine:metta_platform_capability(persistency,Source,_),Sources),
    assertion(Sources==[[library(persistency),library(shlib)]]).

test(generated_multiset_operations_agree_with_an_ordered_list) :-
    forall(member(Sync,[none,flush,close]),with_store(Sync,model_case)).
model_case(Directory,Handle) :-
    model_operations(1,500,Handle,[],Expected),
    'database-close!'(Handle,true),reopen_rows(Directory,Expected).
model_operations(I,Last,Handle,Before,After) :-
    ( I>Last -> After=Before
    ; Key is (I*73) mod 31,Value=[item,Key,[Key,"café"]],
      ( I mod 3=:=0
      -> (selectchk(Value,Before,Next)->Expected=true;Next=Before,Expected=false),
         'database-remove!'(Handle,Value,Removed),assertion(Removed==Expected)
      ; 'database-add!'(Handle,Value,true),append(Before,[Value],Next) ),
      'database-atoms'(Handle,Rows),assertion(Rows==Next),
      J is I+1,model_operations(J,Last,Handle,Next,After) ).

test(native_values_round_trip_without_changing_their_representation) :-
    with_store(close,native_values).
native_values(Directory,Handle) :-
    string_codes(Nul,[97,0,98]),Big is 1<<2000,Ratio is 1 rdiv Big,
    Values=[[],a,'',true,"",Nul,"π🙂",0,Big,Ratio,1.0,-0.0,1.0Inf,-1.0Inf,1.5NaN,
            ['+',1,2],[':=',a],[':seg',a],[':',x,'Type'],[row,[[],[a,b]]]],
    maplist(add_value(Handle),Values),'database-atoms'(Handle,Rows),
    assertion(Rows==Values),'database-close!'(Handle,true),reopen_rows(Directory,Values).

test(queries_share_core_numeric_gap_and_guard_semantics) :- with_store(none,matching).
matching(_,Handle) :-
    maplist(add_value(Handle),[[number,1],[number,1.0],[path,a,b,c],[same,a,a],[same,a,b]]),
    select_snapshot(Handle,[number,1],hit,Numbers),assertion(Numbers==[hit,hit]),
    'database-remove!'(Handle,[number,1],true),
    select_snapshot(Handle,[number,N],N,Remaining),assertion(Remaining==[1.0]),
    select_snapshot(Handle,[path,[':seg',Left],[':seg',Right]],[Left,Right],Gaps),
    assertion(Gaps==[[[],[a,b,c]],[[a],[b,c]],[[a,b],[c]],[[a,b,c],[]]]),
    select_snapshot(Handle,[same,X,X],X,Shared),assertion(Shared==[a]),
    select_snapshot(Handle,[same,[':=',a],Y],Y,Equal),assertion(Equal==[a,b]),
    assertion(var(X)),assertion(var(Y)),assertion(var(N)).

test(selection_errors_leave_the_store_open) :- with_store(none,query_errors).
query_errors(_,Handle) :-
    'database-add!'(Handle,a,true),
    must_throw(select_snapshot(Handle,[database_suite_guard],x,_),database_query_cancelled),
    'database-atoms'(Handle,Rows),assertion(Rows==[a]),
    'database-add!'(Handle,b,true).

test(invalid_values_are_refused_before_mutation) :- with_store(none,invalid_values).
invalid_values(_,Handle) :-
    Cycle=[x|Cycle],dif(Attributed,excluded),
    setup_call_cleanup(open_string("resource",Stream),
        forall(member(Bad,[Attributed,[a,Attributed],Cycle,[a|bad],compound(x),Stream,Handle]),
            (must_throw('database-add!'(Handle,Bad,_),error(domain_error(persistent_value,_),_)),
             must_throw('database-remove!'(Handle,Bad,_),error(domain_error(persistent_value,_),_)))),
        close(Stream)),
    'database-atoms'(Handle,Rows),assertion(Rows==[]).

test(independent_stores_keep_separate_schemas_and_locks) :- with_store(none,independent).
independent(Directory,First) :-
    directory_file_path(Directory,second,Other),
    setup_call_cleanup('database-open!'(Other,close,Second),
        (maplist(add_value(First),[a,a]),'database-add!'(Second,b,true),
         'database-atoms'(First,A),'database-atoms'(Second,B),
         assertion(A==[a,a]),assertion(B==[b]),
         store_module(Directory,AM),store_module(Other,BM),assertion(AM\==BM)),
        'database-close!'(Second,_)).

test(duplicate_owners_and_directory_aliases_are_refused,
     [condition(current_prolog_flag(unix,true))]) :- with_directory(alias_case).
alias_case(Directory) :-
    directory_file_path(Directory,store,Store),directory_file_path(Directory,alias,Alias),
    setup_call_cleanup('database-open!'(Store,none,Handle),
        (link_file(Store,Alias,symbolic),
         forall(member(Path,[Store,Alias]),
                must_throw('database-open!'(Path,flush,_),error(database_lock_failed(_, _),_))),
         'database-sync!'(Handle,true),
         must_throw('database-open!'(Alias,close,_),error(database_lock_failed(_,_),_))),
        'database-close!'(Handle,_)),reopen_rows(Alias,[]),delete_file(Alias).

test(sync_flushes_without_releasing_the_store_lock) :-
    forall(member(Sync,[none,flush,close]),with_store(Sync,sync_case)).
sync_case(Directory,Handle) :-
    'database-add!'(Handle,before,true),'database-sync!'(Handle,true),
    journal(Directory,Journal),read_file_to_string(Journal,Text,[]),
    assertion(sub_string(Text,_,_,_,"assert(row(before))")),
    must_throw('database-open!'(Directory,none,_),error(database_lock_failed(_,_),_)),
    'database-add!'(Handle,after,true),'database-close!'(Handle,true),
    reopen_rows(Directory,[before,after]).

test(writes_survive_caller_backtracking_and_native_transactions) :- with_store(close,transactions).
transactions(Directory,Handle) :-
    assertion(\+ ('database-add!'(Handle,backtracked,true),fail)),
    assertion(\+ transaction(('database-add!'(Handle,transaction_failed,true),fail))),
    must_throw(transaction(('database-add!'(Handle,transaction_thrown,true),throw(rollback))),rollback),
    'database-close!'(Handle,true),
    reopen_rows(Directory,[backtracked,transaction_failed,transaction_thrown]).

test(scopes_release_after_exhaustion_cut_failure_exception_and_early_close) :-
    with_directory(scope_case).
scope_case(Directory) :-
    findall(A,'with-database'(Directory,none,'database-suite-answers',A),Answers),
    Answers=[[Handle,1],[Handle,2]],closed(Handle),
    once('with-database'(Directory,none,'database-suite-answers',[Cut,_])),closed(Cut),
    catch('with-database'(Directory,none,'database-suite-boom',_),database_scope_cancelled(Thrown),true),
    assertion(nonvar(Thrown)),closed(Thrown),
    assertion(\+ 'with-database'(Directory,close,'database-suite-fail',_)),
    reopen_rows(Directory,[before_failure]),
    'with-database'(Directory,none,'database-suite-close',true).

test(scope_callbacks_evaluate_in_the_calling_execution_space) :- with_directory(module_case).
module_case(Directory) :-
    setup_call_cleanup('new-space'(Left),
        setup_call_cleanup('new-space'(Right),callback_spaces(Directory,Left,Right),
                           spaces:metta_release_space(Right)),
        spaces:metta_release_space(Left)).
callback_spaces(Directory,Left,Right) :-
    filereader:metta_host_run_source("!(import! &self (library lib_database))\n(: database-context (-> %Undefined% Number))\n(= (database-context $h) 11)",Left,[],_),
    filereader:metta_host_run_source("!(import! &self (library lib_database))\n(: database-context (-> %Undefined% Number))\n(= (database-context $h) 22)",Right,[],_),
    spaces:space_module(Left,LM),spaces:space_module(Right,RM),
    with_metta_module(LM,'with-database'(Directory,none,'database-context',L)),
    with_metta_module(RM,'with-database'(Directory,none,'database-context',R)),
    assertion(L==11),assertion(R==22).

test(concurrent_request_replies_preserve_every_worker_value) :- with_store(none,concurrent_writes).
concurrent_writes(Directory,Handle) :-
    findall(write_worker(Handle,I),between(1,4,I),Goals),concurrent(4,Goals,[]),
    'database-atoms'(Handle,Rows),length(Rows,400),sort(Rows,Unique),length(Unique,400),
    'database-close!'(Handle,true),reopen_rows(Directory,Rows).
write_worker(Handle,Worker) :-
    forall(between(1,100,I),
           ('database-add!'(Handle,[worker,Worker,I],true),
            select_snapshot(Handle,[worker,Worker,I],I,[I]))).

test(concurrent_close_is_idempotent_and_other_requests_refuse) :- with_store(none,close_race).
close_race(_,Handle) :-
    findall(close_worker(Handle),between(1,16,_),Goals),concurrent(16,Goals,[]),closed(Handle).
close_worker(Handle) :-
    forall(between(1,100,_),
           ('database-close!'(Handle,true),
            catch('database-atoms'(Handle,[]),error(existence_error(database,Handle),_),true))).

test(close_releases_module_source_schema_registration_and_streams) :- with_store(none,close_resources).
close_resources(Directory,Handle) :-
    'database-add!'(Handle,x,true),store_module(Directory,Module),
    source_file(Module:row(_),Source),journal(Directory,Journal),
    'database-close!'(Handle,true),no_registration(Module,Journal),assertion(\+ source_file(Source)),
    reopen_rows(Directory,[x]).

test(abandoned_engines_release_their_resources_after_atom_collection) :-
    with_directory(gc_case).
gc_case(Directory) :-
    journal(Directory,Journal),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            wrap_predicate(lib_database:finish_store(_,Path,_),database_gc_observer,Wrapped,
                           (call(Wrapped),(Path==Journal->thread_send_message(Queue,cleaned);true))),
            (thread_create(abandon_database(Directory),Creator,[]),thread_join(Creator,true),
             garbage_collect,garbage_collect_atoms,
             thread_get_message(Queue,cleaned),reopen_rows(Directory,[abandoned])),
            unwrap_predicate(lib_database:finish_store(_,_,_),database_gc_observer)),
        message_queue_destroy(Queue)).
abandon_database(Directory) :-
    'database-open!'(Directory,none,Handle),'database-add!'(Handle,abandoned,true).

test(failed_append_ends_the_attachment_and_keeps_the_old_journal) :- with_store(close,failed_append).
failed_append(Directory,Handle) :-
    'database-add!'(Handle,original,true),store_module(Directory,Module),journal(Directory,Journal),
    atom_concat(Journal,'.saved',Saved),rename_file(Journal,Saved),make_directory(Journal),
    call_cleanup(must_throw('database-add!'(Handle,lost,_),error(_,_)),delete_directory(Journal)),
    closed(Handle),no_registration(Module,Journal),rename_file(Saved,Journal),reopen_rows(Directory,[original]).

test(close_failure_drains_registration_before_propagating) :- with_store(flush,failed_close).
failed_close(Directory,Handle) :-
    'database-add!'(Handle,original,true),store_module(Directory,Module),journal(Directory,Journal),
    persistency:db_stream(Module,Stream),close(Stream),
    must_throw('database-close!'(Handle,_),
               error(database_cleanup(exit,[error(existence_error(stream,_),_)]),_)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[original]).

test(update_and_cleanup_errors_both_survive) :- with_store(flush,combined_failure).
combined_failure(Directory,Handle) :-
    'database-add!'(Handle,original,true),store_module(Directory,Module),journal(Directory,Journal),
    persistency:db_stream(Module,Stream),close(Stream),
    must_throw('database-add!'(Handle,lost,_),
               error(database_cleanup(exception(error(existence_error(stream,_),_)),
                                      [error(existence_error(stream,_),_)]),_)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[original]).

test(sync_failure_ends_the_attachment) :- with_store(flush,failed_sync).
failed_sync(Directory,Handle) :-
    'database-add!'(Handle,original,true),store_module(Directory,Module),journal(Directory,Journal),
    persistency:db_stream(Module,Stream),close(Stream),
    must_throw('database-sync!'(Handle,_),error(existence_error(stream,_),_)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[original]).

test(cancellation_before_stream_registration_recovers_the_open_stream) :-
    with_store(none,unregistered_stream).
unregistered_stream(Directory,Handle) :-
    store_module(Directory,Module),journal(Directory,Journal),
    setup_call_cleanup(
        wrap_predicate(persistency:db_open_file(Path,_,_),database_open_abort,Wrapped,
                       (call(Wrapped),(Path==Journal->throw(database_stream_cancelled);true))),
        must_throw('database-add!'(Handle,lost,_),database_stream_cancelled),
        unwrap_predicate(persistency:db_open_file(_,_,_),database_open_abort)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[]).

test(thread_cancellation_during_an_owned_request_releases_the_store) :-
    with_store(none,cancel_request).
cancel_request(Directory,Handle) :-
    store_module(Directory,Module),journal(Directory,Journal),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            wrap_predicate(persistency:db_open_file(Path,_,_),database_open_barrier,Wrapped,
                           (call(Wrapped),(Path==Journal->thread_send_message(Queue,opened),
                                           thread_get_message(database_continue);true))),
            setup_call_cleanup(thread_create(reported_request(Queue,'database-add!'(Handle,lost,_)),Worker,[]),
                (expect_request_event(Queue,opened),thread_signal(Handle,throw(database_thread_cancelled)),
                 expect_request_event(Queue,finished(exception(database_thread_cancelled))),
                 thread_join(Worker,Status),assertion(Status==exception(database_thread_cancelled))),
                reap(Worker)),
            unwrap_predicate(persistency:db_open_file(_,_,_),database_open_barrier)),
        message_queue_destroy(Queue)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[]).
reported_request(Queue,Goal) :-
    setup_call_catcher_cleanup(true,Goal,Outcome,thread_send_message(Queue,finished(Outcome))).
expect_request_event(Queue,Expected) :-
    thread_get_message(Queue,Actual),
    ( Actual=Expected -> true
    ; throw(error(database_request_event(Expected,Actual),_)) ).
reap(Thread) :-
    call_cleanup(catch(thread_signal(Thread,throw(database_fixture_cancelled)),error(existence_error(thread,_),_),true),
                 catch(thread_join(Thread,_),error(existence_error(thread,_),_),true)).

test(request_exit_before_a_milestone_is_reported,
     [forall(member(Goal-Outcome,[true-exit,fail-fail,
                                 throw(database_request_failed)-exception(database_request_failed)]))]) :-
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(thread_create(reported_request(Queue,Goal),Worker,[]),
            must_throw(expect_request_event(Queue,opened),
                       error(database_request_event(opened,finished(Outcome)),_)),
            reap(Worker)),
        message_queue_destroy(Queue)).

test(invalid_journals_are_refused_in_full_and_preserved) :- with_directory(invalid_journals).
invalid_journals(Directory) :-
    journal(Directory,Journal),
    forall(member(Text,["invented(corruption).\n","assert(row(x)).\ninvented(corruption).\n",
                       "created(0).\ncreated(1).\n","assert(row(_)).\n",
                       "assert(row(compound(x))).\n","assert(row([x|bad])).\n",
                       "assert(row(x)","end_of_file.\nassert(row(x)).\n",
                       ":- assertz(unwanted).\n","assert(row({|invented||payload|})).\n",
                       "retractall(row(x),1).\n","asserta(row(x)).\n"]),
        (write_text(Journal,Text),
         must_throw('database-open!'(Directory,none,_),error(database_journal(Journal,_),_)),
         read_file_to_string(Journal,After,[]),assertion(After==Text),
         assertion(\+ stream_property(_,file_name(Journal))))),
    write_text(Journal,"assert(row(repaired)).\n"),reopen_rows(Directory,[repaired]).

test(empty_and_headerless_journals_reopen) :- with_directory(empty_journals).
empty_journals(Directory) :-
    journal(Directory,Journal),
    forall(member(Text,[""," \n/* comment */\n","created(0).\n"]),
           (write_text(Journal,Text),reopen_rows(Directory,[]))),
    write_text(Journal,"assert(row(x)).\nassert(row(x)).\nretract(row(x)).\n"),
    reopen_rows(Directory,[x]).

test(invalid_arguments_and_bound_outputs_do_not_leave_an_owner) :- with_directory(invalid_arguments).
invalid_arguments(Directory) :-
    directory_file_path(Directory,invalid,Path),
    forall(member(Sync,[invented,0,"none",_]),must_throw('database-open!'(Path,Sync,_),error(_,_))),
    assertion(\+ exists_directory(Path)),
    must_throw('database-open!'("",none,_),error(domain_error(database_directory,_),_)),
    string_codes(Suffix,[0,98]),string_concat(Path,Suffix,Nul),
    must_throw('database-open!'(Nul,none,_),error(domain_error(database_directory,_),_)),
    forall(member(Handle,[none,0,"handle",[],_]),
           must_throw('database-close!'(Handle,_),error(domain_error(database_handle,_),_))),
    must_throw('database-open!'(Path,none,wrong),error(_,_)),reopen_rows(Path,[]).

test(variable_sharing_is_local_to_each_occurrence_and_snapshot) :-
    with_store(close,variable_values).
variable_values(Directory,Handle) :-
    Shared=[pair,X,X],Separate=[pair,Y,Z],Literal=['$metta_database_variable',0],
    maplist(add_value(Handle),[Shared,Shared,Separate,_Plain,Literal]),
    assertion(var(X)),assertion(var(Y)),assertion(var(Z)),
    'database-atoms'(Handle,[First,Second,Third,Plain,Literal]),
    assertion(First =@= Shared),assertion(Second =@= Shared),
    assertion(First \== Second),assertion(Third =@= Separate),
    assertion(var(Plain)),First=[pair,bound,bound],
    'database-atoms'(Handle,[Fresh|_]),assertion(Fresh =@= Shared),
    'database-remove!'(Handle,[pair,Renamed,Renamed],true),
    'database-remove!'(Handle,[pair,Other,Other],true),
    'database-remove!'(Handle,[pair,Last,Last],false),
    'database-remove!'(Handle,_Any,true),
    'database-remove!'(Handle,_Absent,false),
    'database-close!'(Handle,true),
    setup_call_cleanup('database-open!'(Directory,flush,Reopened),
        ('database-atoms'(Reopened,Rows),
         assertion(Rows =@= [Separate,Literal])),
        'database-close!'(Reopened,true)).

test(variable_graphs_round_trip_and_reject_nonidentical_removal) :-
    forall(between(1,80,Seed),with_store(close,variable_graph(Seed))).
variable_graph(Seed,Directory,Handle) :-
    length(Variables,7),
    findall(Index,(between(0,30,I),Index is (I*Seed+I*I) mod 7),Indices),
    maplist(index_variable(Variables),Indices,Occurrences),
    Value=[graph,Occurrences,Variables],
    'database-add!'(Handle,Value,true),
    'database-close!'(Handle,true),
    setup_call_cleanup('database-open!'(Directory,close,Reopened),
        ('database-atoms'(Reopened,[Copy]),assertion(Copy =@= Value),
         'database-remove!'(Reopened,[graph,_Unshared,_AlsoUnshared],false),
         'database-remove!'(Reopened,Copy,true),
         'database-atoms'(Reopened,Empty),assertion(Empty==[])),
        'database-close!'(Reopened,true)).
index_variable(Variables,Index,Variable) :-
    nth0(Index,Variables,Variable).

test(noncanonical_variable_journals_refuse_without_repair) :-
    with_directory(noncanonical_variables).
noncanonical_variables(Directory) :-
    journal(Directory,Journal),
    Huge is 1<<2000,
    forall(member(Value,[
        '$metta_database_variable'(-1),
        '$metta_database_variable'(Huge),
        '$metta_database_variable'(1),
        '$metta_database_variable'(name),
        ['$metta_database_variable'(1),'$metta_database_variable'(0)],
        '$VAR'(0)]),
        (format(string(Text),'assert(row(~q)).~n',[Value]),write_text(Journal,Text),
         must_throw('database-open!'(Directory,close,_),error(database_journal(Journal,_),_)),
         read_file_to_string(Journal,After,[]),assertion(After==Text))).

:- end_tests(lib_database).
