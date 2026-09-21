% Purpose: verify complete compression members and owned archive publication.
% Guarantees: malformed input, path collisions and injected close failures leave
% destination data and the process stream set unchanged.
% [tested: lib_compression; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
% Owns resources: fixtures remove their trees; close wrappers and random state
% are restored on every exit. The cancellation fixture joins its encoder thread
% and destroys its message queue after observing the owned-stream barrier.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_compression/lib_compression').
:- use_module('../../../../lib/lib_file/lib_file', ['temp-dir!'/2]).
:- use_module(library(archive)).
:- use_module(library(lists), [member/2, numlist/3, append/3, reverse/2]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(filesex)).
:- use_module(library(readutil), [read_file_to_codes/3]).
:- use_module(library(random), [getrand/1, setrand/1, random_between/3]).
:- use_module(library(prolog_wrap)).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_compression).
:- meta_predicate with_directory(1).

with_directory(Goal) :-
    setup_call_cleanup('temp-dir!'("compression-suite",Directory),
                       call(Goal,Directory),delete_directory_and_contents(Directory)).
write_bytes(Path,Bytes) :-
    setup_call_cleanup(open(Path,write,Stream,[type(binary)]),
                       maplist(put_byte(Stream),Bytes),close(Stream)).
stream_set(Streams) :-
    findall(S,stream_property(S,mode(_)),Found),sort(Found,Streams).
directory_contents(Directory,Names) :- directory_files(Directory,Found),sort(Found,Names).

make_archive(Path,Format,Rows) :-
    setup_call_cleanup(archive_open(Path,write,Archive,[format(Format)]),
                       maplist(write_entry(Archive),Rows),archive_close(Archive)).
write_entry(Archive,entry(Name,Type,Bytes)) :-
    archive_next_header(Archive,Name),
    ( Type=link(Target)
    -> archive_set_header_property(Archive,filetype(link)),
       archive_set_header_property(Archive,link_target(Target))
    ; archive_set_header_property(Archive,filetype(Type)) ),
    length(Bytes,Size),archive_set_header_property(Archive,size(Size)),
    archive_set_header_property(Archive,mtime(0)),
    setup_call_cleanup(archive_open_entry(Archive,Output),
                       maplist(put_byte(Output),Bytes),close(Output)).

test(capabilities_and_envelopes) :-
    'compression-formats'(Formats),assertion(Formats==[gzip,zlib]),
    forall(member(Name-Source,['compressed-sources'-library(zlib),
                              'memory-files'-library(memfile),archive-library(archive)]),
           (findall(S,metta_engine:metta_platform_capability(Name,S,_),Sources),
            assertion(Sources==[Source]))).

test(every_octet_and_empty_member_at_every_level) :-
    numlist(0,255,Octets),
    forall((member(Format,[gzip,zlib]),between(0,9,Level),member(Data,[[],Octets])),
           ('compress-bytes'(Format,Level,Data,Packed),assertion(Packed\==[]),
            'decompress-bytes'(Format,Packed,Again),assertion(Again==Data))).

test(generated_binary_round_trips) :-
    setup_call_cleanup(getrand(State),
        (set_random(seed(41)),forall(between(0,127,Index),
            (Size is Index*17,length(Data,Size),maplist(random_between(0,255),Data),
             Level is Index mod 10,
             forall(member(Format,[gzip,zlib]),
                    ('compress-bytes'(Format,Level,Data,Packed),
                     'decompress-bytes'(Format,Packed,Again),assertion(Again==Data)))))),
        setrand(State)).

test(concatenation_checks_every_member) :-
    forall(member(Format,[gzip,zlib]),
        ('compress-bytes'(Format,6,[0,255],One),'compress-bytes'(Format,0,[],Empty),
         append(One,Empty,Prefix),append(Prefix,One,Joined),
         'decompress-bytes'(Format,Joined,Data),assertion(Data==[0,255,0,255]),
         append(Joined,[42],Junk),must_throw('decompress-bytes'(Format,Junk,_),error(_,_)),
         append(Joined,[0,0],Padding),must_throw('decompress-bytes'(Format,Padding,_),error(_,_)))).

test(every_truncated_prefix_and_bad_checksum_is_refused) :-
    forall(member(Format,[gzip,zlib]),
        ('compress-bytes'(Format,6,[0,1,128,255],Packed),
         forall((append(Prefix,Rest,Packed),Rest\==[]),
                must_throw('decompress-bytes'(Format,Prefix,_),error(_,_))),
         reverse(Packed,[Last|Tail]),BadLast is Last xor 1,reverse([BadLast|Tail],Bad),
         must_throw('decompress-bytes'(Format,Bad,_),error(_,_)))).

test(arguments_and_envelope_mismatch_are_refused) :-
    forall(member(Format,[gzip,zlib]),
        (forall(member(Data,[[256],[-1],[1.0],[bad],[0|bad]]),
                must_throw('compress-bytes'(Format,6,Data,_),error(_,_))),
         Cycle=[0|Cycle],must_throw('decompress-bytes'(Format,Cycle,_),error(type_error(_,_),_)),
         forall(member(Level,[-1,10,1.0]),
                must_throw('compress-bytes'(Format,Level,[],_),error(_,_))))),
    must_throw('compress-bytes'(invented,6,[],_),error(domain_error(compression_format,_),_)),
    'compress-bytes'(gzip,6,[],Gzip),'compress-bytes'(zlib,6,[],Zlib),
    must_throw('decompress-bytes'(gzip,Zlib,_),error(_,_)),
    must_throw('decompress-bytes'(zlib,Gzip,_),error(_,_)).

test(file_round_trips_allow_in_place_replacement) :- with_directory(file_round_trip).
file_round_trip(Directory) :-
    directory_file_path(Directory,data,Path),numlist(0,255,Bytes),write_bytes(Path,Bytes),
    forall(member(Format,[gzip,zlib]),
        ('compress-file!'(Format,9,Path,Path,true),read_file_to_codes(Path,Packed,[type(binary)]),
         'decompress-bytes'(Format,Packed,Decoded),assertion(Decoded==Bytes),
         'decompress-file!'(Format,Path,Path,true),read_file_to_codes(Path,Restored,[type(binary)]),
         assertion(Restored==Bytes))),
    directory_contents(Directory,Names),assertion(Names==['.','..',data]).

test(file_failures_preserve_destination_and_remove_staging) :- with_directory(file_failures).
file_failures(Directory) :-
    directory_file_path(Directory,source,Source),directory_file_path(Directory,destination,To),
    write_bytes(Source,[31,139]),write_bytes(To,[42]),
    must_throw('decompress-file!'(gzip,Source,To,_),error(_,_)),
    directory_file_path(Directory,missing,Missing),
    must_throw('compress-file!'(gzip,6,Missing,To,_),error(_,_)),
    read_file_to_codes(To,Kept,[type(binary)]),assertion(Kept==[42]),
    directory_file_path(Directory,'missing/out',NoParent),
    must_throw('compress-file!'(gzip,6,To,NoParent,_),error(_,_)),
    must_throw('compress-file!'(gzip,6,To,Directory,_),publication_refused(_,_)),
    directory_contents(Directory,Names),assertion(Names==['.','..',destination,source]).

test(final_output_close_failure_prevents_publication) :- with_directory(close_failure).
close_failure(Directory) :-
    directory_file_path(Directory,source,Source),directory_file_path(Directory,destination,To),
    write_bytes(Source,[1,2,3]),write_bytes(To,[42]),stream_set(Before),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream),compression_output_close,Wrapped,
            ( (stream_property(Stream,mode(write)),stream_property(Stream,file_name(File)),
               file_base_name(File,contents))
              -> call(Wrapped),throw(error(compression_close_error,injected))
              ; call(Wrapped) )),
        must_throw('compress-file!'(gzip,6,Source,To,_),error(compression_close_error,_)),
        unwrap_predicate(system:close(_),compression_output_close)),
    stream_set(After),assertion(After==Before),
    read_file_to_codes(To,Kept,[type(binary)]),assertion(Kept==[42]),
    directory_contents(Directory,Names),assertion(Names==['.','..',destination,source]).

test(archive_ordinals_preserve_duplicates) :- with_directory(ordinal_case).
ordinal_case(Directory) :-
    directory_file_path(Directory,archive,Path),
    make_archive(Path,gnutar,[entry(root,directory,[]),entry('same',file,[0,255]),entry('same',file,[])]),
    'archive-entries!'(Path,Entries),
    Entries=[['archive-entry',0,"root/",DirectoryProps],
             ['archive-entry',1,"same",FileProps],['archive-entry',2,"same",EmptyProps]],
    assertion(memberchk([filetype,directory],DirectoryProps)),
    assertion(memberchk([size,2],FileProps)),assertion(memberchk([size,0],EmptyProps)),
    'archive-read!'(Path,1,Bytes),assertion(Bytes==[0,255]),'archive-read!'(Path,2,Empty),assertion(Empty==[]),
    must_throw('archive-read!'(Path,0,_),error(domain_error(regular_archive_entry,_),_)),
    must_throw('archive-read!'(Path,3,_),error(existence_error(archive_entry(3),_),_)),
    must_throw('archive-read!'(Path,-1,_),error(type_error(nonneg,_),_)).

test(extraction_accepts_repeated_directories_and_normalized_relative_names) :-
    with_directory(extract_case).
extract_case(Directory) :-
    directory_file_path(Directory,archive,Path),directory_file_path(Directory,output,To),
    make_archive(Path,gnutar,[entry('./',directory,[]),entry('sub/',directory,[]),
                             entry('sub/',directory,[]),entry('./sub//./data',file,[0,128,255]),
                             entry('.hidden',file,[])]),
    make_directory(To),'archive-extract!'(Path,To,true),
    directory_file_path(To,'sub/data',Data),read_file_to_codes(Data,Bytes,[type(binary)]),
    assertion(Bytes==[0,128,255]),directory_file_path(To,'.hidden',Hidden),size_file(Hidden,0),
    must_throw('archive-extract!'(Path,To,_),publication_refused(_,_)),
    read_file_to_codes(Data,Kept,[type(binary)]),assertion(Kept==Bytes),
    directory_contents(Directory,Names),assertion(Names==['.','..',archive,output]).

test(path_collisions_and_special_kinds_never_publish) :- with_directory(conflict_case).
conflict_case(Directory) :-
    directory_file_path(Directory,archive,Path),directory_file_path(Directory,output,To),
    forall(member(Rows,[[entry(x,file,[]),entry(x,file,[1])],
                        [entry(x,file,[]),entry('x/y',file,[1])],
                        [entry('x/y',file,[]),entry(x,file,[1])],
                        [entry(x,link('../outside'),[])],[entry(x,fifo,[])]]),
        (make_archive(Path,gnutar,Rows),stream_set(Before),
         must_throw('archive-extract!'(Path,To,_),error(_,_)),stream_set(After),
         assertion(After==Before),assertion(\+exists_directory(To)),
         directory_contents(Directory,Names),assertion(Names==['.','..',archive]))).

test(portable_path_policy_covers_control_codes_and_device_products) :-
    forall((between(0,31,Code),string_codes(Name,[97,Code,98])),
           must_throw(lib_compression:extraction_path(Name,file,"stage",_),error(domain_error(_,_),_))),
    forall((member(Stem,["CON","prn","AuX","NUL","CONIN$","CONOUT$","CLOCK$",
                        "COM1","com9","LPT1","lpt9","COM¹","LPT²","COM³"]),
            member(Suffix,["",".txt"," .txt"]),string_concat(Stem,Suffix,Name)),
           must_throw(lib_compression:extraction_path(Name,file,"stage",_),error(domain_error(_,_),_))),
    forall(member(Name,["a/../b","/a","C:/a","a\\b","a:b","a*b","a?b","a<b","a>b",
                       "a|b","a\"b","a.","a "," a","", ".","./"]),
           must_throw(lib_compression:extraction_path(Name,file,"stage",_),error(domain_error(_,_),_))),
    forall(member(Name,["COM10","LPT0",".env","café/π","x..y","a b","..x"]),
           (lib_compression:extraction_path(Name,file,"stage",Path),
            directory_file_path("stage",Name,Expected),assertion(Path==Expected))).

test(gzip_wrapped_seekable_archives_retain_every_entry) :- with_directory(seekable_case).
seekable_case(Directory) :-
    directory_file_path(Directory,archive,Path),directory_file_path(Directory,packed,Packed),
    forall(member(Format,[zip,'7zip']),
        (make_archive(Path,Format,[entry(data,file,[0,128,255]),entry(empty,file,[])]),
         'archive-entries!'(Path,Entries),'compress-file!'(gzip,9,Path,Packed,true),
         'archive-entries!'(Packed,Again),assertion(Again==Entries),
         'archive-read!'(Packed,0,Bytes),assertion(Bytes==[0,128,255]))).

test(visitor_exception_closes_entry_and_archive_streams) :- with_directory(visitor_case).
visitor_case(Directory) :-
    directory_file_path(Directory,archive,Path),make_archive(Path,gnutar,[entry(data,file,[1,2])]),
    stream_set(Before),must_throw(lib_compression:fold_file(Path,
        plunit_lib_compression:throw_visitor,[],_),error(compression_visitor_error,_)),
    stream_set(After),assertion(After==Before),
    'archive-read!'(Path,0,Bytes),assertion(Bytes==[1,2]).
throw_visitor(_,_,_,_) :- throw(error(compression_visitor_error,injected)).

test(archive_scope_releases_failed_acquisitions) :- with_directory(acquisition_case).
acquisition_case(Directory) :-
    directory_file_path(Directory,archive,Path),write_bytes(Path,[42]),stream_set(Before),
    must_throw('archive-entries!'(Path,_),error(archive_error(_,_),_)),
    setup_call_cleanup(open(Path,read,Input,[type(binary)]),
        (must_throw(lib_compression_native:with_archive(stream(Input),[formats([invented])],_,true),
                    error(domain_error(_,_),_)),
         assertion(stream_property(Input,mode(read))),seek(Input,0,bof,_),get_byte(Input,42)),
        close(Input)),
    make_archive(Path,gnutar,[entry(data,file,[42])]),
    assertion(\+lib_compression_native:with_archive(Path,[],_,fail)),
    must_throw(lib_compression_native:with_archive(Path,[],_,throw(archive_scope_error)),
               archive_scope_error),
    stream_set(After),assertion(After==Before),
    'archive-read!'(Path,0,Bytes),assertion(Bytes==[42]).

test(cancellation_after_encoder_acquisition_releases_streams) :-
    stream_set(Before),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            wrap_predicate(system:put_byte(_Stream,_Byte),compression_cancel,Wrapped,
                (thread_send_message(Queue,ready),thread_get_message(Queue,proceed),call(Wrapped))),
            setup_call_cleanup(thread_create(cancelled_encoder(Queue),Worker,[]),
                (thread_get_message(Queue,First),assertion(First==ready),
                 thread_signal(Worker,throw(compression_cancelled)),
                 thread_get_message(Queue,Finished),assertion(Finished==finished(error(compression_cancelled)))),
                thread_join(Worker,true)),
            unwrap_predicate(system:put_byte(_,_),compression_cancel)),
        message_queue_destroy(Queue)),
    stream_set(After),assertion(After==Before),
    'compress-bytes'(gzip,6,[1],Packed),'decompress-bytes'(gzip,Packed,Again),assertion(Again==[1]).
cancelled_encoder(Queue) :-
    catch(('compress-bytes'(gzip,6,[42],_),Status=success),Error,Status=error(Error)),
    thread_send_message(Queue,finished(Status)).

:- end_tests(lib_compression).
