% Purpose: verify persistent multiset semantics and complete store ownership.
% Guarantees: generated operations agree with a list model; lifecycle tests
% exercise independent engines, aliases, cancellation, failed I/O and replay.
% [tested: lib_database; commit=060bea3199e9f504c6d425f60841f229fc96e861].
% Owns resources: fixtures close stores, join workers, release execution spaces,
% restore wrapped predicates and delete their temporary directories.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_file/lib_file', []).
:- use_module('../../../../lib/lib_database/lib_database').
:- use_module(library(filesex), [directory_file_path/3,delete_directory_and_contents/1,link_file/3]).
:- use_module(library(lists), [member/2,append/3,selectchk/3]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(thread), [concurrent/3]).
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

:- begin_tests(lib_database).
:- meta_predicate must_throw(0,?), with_directory(1), with_store(+,2).

must_throw(Goal,Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error=Expected).
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
    must_throw('database-query'(Handle,X,X,_),error(existence_error(database,Handle),_)),
    'database-close!'(Handle,true).
write_text(Path,Text) :-
    setup_call_cleanup(open(Path,write,Out,[encoding(utf8)]),write(Out,Text),close(Out)).
add_value(Handle,Value) :- 'database-add!'(Handle,Value,true).
reopen_rows(Directory,Expected) :-
    setup_call_cleanup('database-open!'(Directory,flush,Handle),
        ('database-query'(Handle,X,X,Rows),assertion(Rows==Expected)),
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
      'database-query'(Handle,X,X,Rows),assertion(Rows==Next),
      J is I+1,model_operations(J,Last,Handle,Next,After) ).

test(native_values_round_trip_without_changing_their_representation) :-
    with_store(close,native_values).
native_values(Directory,Handle) :-
    string_codes(Nul,[97,0,98]),Big is 1<<2000,Ratio is 1 rdiv Big,
    Values=[[],a,'',true,"",Nul,"π🙂",0,Big,Ratio,1.0,-0.0,1.0Inf,-1.0Inf,1.5NaN,
            ['+',1,2],[':=',a],[':seg',a],[':',x,'Type'],[row,[[],[a,b]]]],
    maplist(add_value(Handle),Values),'database-query'(Handle,X,X,Rows),
    assertion(Rows==Values),'database-close!'(Handle,true),reopen_rows(Directory,Values).

test(queries_share_core_numeric_gap_and_guard_semantics) :- with_store(none,matching).
matching(_,Handle) :-
    maplist(add_value(Handle),[[number,1],[number,1.0],[path,a,b,c],[same,a,a],[same,a,b]]),
    'database-query'(Handle,[number,1],hit,Numbers),assertion(Numbers==[hit,hit]),
    'database-remove!'(Handle,[number,1],true),
    'database-query'(Handle,[number,N],N,Remaining),assertion(Remaining==[1.0]),
    'database-query'(Handle,[path,[':seg',Left],[':seg',Right]],[Left,Right],Gaps),
    assertion(Gaps==[[[],[a,b,c]],[[a],[b,c]],[[a,b],[c]],[[a,b,c],[]]]),
    'database-query'(Handle,[same,X,X],X,Shared),assertion(Shared==[a]),
    'database-query'(Handle,[same,[':=',a],Y],Y,Equal),assertion(Equal==[a,b]),
    assertion(var(X)),assertion(var(Y)),assertion(var(N)).

test(query_errors_and_invalid_patterns_leave_the_store_open) :- with_store(none,query_errors).
query_errors(_,Handle) :-
    'database-add!'(Handle,a,true),
    must_throw('database-query'(Handle,[database_suite_guard],x,_),database_query_cancelled),
    Cycle=[x|Cycle],
    forall(member(Bad,[Cycle,[x|bad],compound(x)]),
           must_throw('database-query'(Handle,Bad,x,_),error(domain_error(persistent_pattern,_),_))),
    'database-query'(Handle,X,X,Rows),assertion(Rows==[a]),
    'database-add!'(Handle,b,true).

test(invalid_values_are_refused_before_mutation) :- with_store(none,invalid_values).
invalid_values(_,Handle) :-
    Cycle=[x|Cycle],
    setup_call_cleanup(open_string("resource",Stream),
        forall(member(Bad,[_Variable,[a,_],Cycle,[a|bad],compound(x),Stream,Handle]),
            (must_throw('database-add!'(Handle,Bad,_),error(domain_error(persistent_value,_),_)),
             must_throw('database-remove!'(Handle,Bad,_),error(domain_error(persistent_value,_),_)))),
        close(Stream)),
    'database-query'(Handle,X,X,Rows),assertion(Rows==[]).

test(independent_stores_keep_separate_schemas_and_locks) :- with_store(none,independent).
independent(Directory,First) :-
    directory_file_path(Directory,second,Other),
    setup_call_cleanup('database-open!'(Other,close,Second),
        (maplist(add_value(First),[a,a]),'database-add!'(Second,b,true),
         'database-query'(First,X,X,A),'database-query'(Second,Y,Y,B),
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
    'database-query'(Handle,X,X,Rows),length(Rows,400),sort(Rows,Unique),length(Unique,400),
    'database-close!'(Handle,true),reopen_rows(Directory,Rows).
write_worker(Handle,Worker) :-
    forall(between(1,100,I),
           ('database-add!'(Handle,[worker,Worker,I],true),
            'database-query'(Handle,[worker,Worker,I],I,[I]))).

test(concurrent_close_is_idempotent_and_other_requests_refuse) :- with_store(none,close_race).
close_race(_,Handle) :-
    findall(close_worker(Handle),between(1,16,_),Goals),concurrent(16,Goals,[]),closed(Handle).
close_worker(Handle) :-
    forall(between(1,100,_),
           ('database-close!'(Handle,true),
            catch('database-query'(Handle,X,X,[]),error(existence_error(database,Handle),_),true))).

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
    store_module(Directory,Module),journal(Directory,Journal),thread_self(Main),
    setup_call_cleanup(
        wrap_predicate(persistency:db_open_file(Path,_,_),database_open_barrier,Wrapped,
                       (call(Wrapped),(Path==Journal->thread_send_message(Main,opened),
                                       thread_get_message(database_continue);true))),
        setup_call_cleanup(thread_create('database-add!'(Handle,lost,_),Worker,[]),
            (thread_get_message(opened),thread_signal(Handle,throw(database_thread_cancelled)),
             thread_join(Worker,Status),assertion(Status==exception(database_thread_cancelled))),
            reap(Worker)),
        unwrap_predicate(persistency:db_open_file(_,_,_),database_open_barrier)),
    no_registration(Module,Journal),closed(Handle),reopen_rows(Directory,[]).
reap(Thread) :-
    call_cleanup(catch(thread_signal(Thread,throw(database_fixture_cancelled)),error(existence_error(thread,_),_),true),
                 catch(thread_join(Thread,_),error(existence_error(thread,_),_),true)).

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

:- end_tests(lib_database).
