% Purpose: capture archive callbacks leaving a decoder exception pending.
% Guarantees: both versions refuse the corrupt input; present additionally
% requires the native archive_close protocol violation after a valid control.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: the parent drains/closes output and joins its child; the
% child closes input, decoder, archive and entry streams on each exit.

:- use_module(support/gzip_fixture, [gzip_fixture/3]).
:- use_module(library(process), [process_create/3,process_wait/2]).
:- use_module(library(zlib), [zopen/3]).
:- use_module(library(archive),
              [archive_open/4,archive_close/1,archive_next_header/2,archive_open_entry/2]).
:- use_module(library(readutil), [read_stream_to_codes/2]).

main :-
    source_file(main,Source),current_prolog_flag(executable,Swipl),
    setup_call_cleanup(process_create(Swipl,
        ['-q','-f',none,'-s',Source,'-g',archive_exception_child,'-t',halt],
        [stdin(null),stdout(pipe(Output)),stderr(pipe(Output)),process(PID)]),
        read_string(Output,_,Log),(close(Output),process_wait(PID,Status))),
    (Status==exit(0),sub_string(Log,_,_,_,"valid-input-passed"),
     sub_string(Log,_,_,_,"bad-input-refused")
    -> (sub_string(Log,_,_,_,"archive:archive_close/1 did not clear exception")
        -> writeln(present);writeln(absent))
    ; throw(error(archive_exception_reproduction_failed(Status,Log),_))).

archive_exception_child :-
    gzip_fixture(Data,Good,Bad),through_decoder(Good,Data),writeln('valid-input-passed'),
    catch(through_decoder(Bad,_),Error,true),
    (nonvar(Error),Error=error(io_error(_,_),_) -> writeln('bad-input-refused')
    ; throw(error(unexpected_archive_input_result(Error),_))).
through_decoder(Bytes,Data) :-
    string_codes(Text,Bytes),
    setup_call_cleanup(open_string(Text,Input),
        setup_call_cleanup(zopen(Input,Decoded,[format(gzip),multi_part(true),close_parent(false)]),
            setup_call_cleanup(archive_open(stream(Decoded),read,Archive,
                                             [formats([raw]),close_parent(false)]),
                (archive_next_header(Archive,data),
                 setup_call_cleanup(archive_open_entry(Archive,Entry),
                                    read_stream_to_codes(Entry,Data),close(Entry))),
                archive_close(Archive)),close(Decoded)),close(Input)).
