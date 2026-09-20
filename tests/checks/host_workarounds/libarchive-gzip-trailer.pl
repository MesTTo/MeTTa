% Purpose: test whether libarchive verifies a gzip member's CRC trailer.
% Guarantees: present requires a valid control and the corrupted member's
% unchanged payload; absent requires refusal of only the corrupt member.
% [tested: sh tools/check.sh host-workarounds; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
% Owns resources: each input, archive and entry stream closes on every exit.

:- use_module(support/gzip_fixture, [gzip_fixture/3]).
:- use_module(library(archive),
              [archive_open/4,archive_close/1,archive_next_header/2,archive_open_entry/2]).
:- use_module(library(readutil), [read_stream_to_codes/2]).

main :-
    gzip_fixture(Data,Good,Bad),read_member(Good,Control),
    (Control==Data -> true;throw(error(gzip_control_failed,_))),
    catch(read_member(Bad,Result),Error,true),
    (var(Error),Result==Data -> writeln(present)
    ; nonvar(Error),(Error=error(archive_error(_,_),_);Error=error(io_error(_,_),_)) -> writeln(absent)
    ; throw(error(unexpected_gzip_result(Result,Error),_))).
read_member(Bytes,Data) :-
    string_codes(Text,Bytes),
    setup_call_cleanup(open_string(Text,Input),
        setup_call_cleanup(archive_open(stream(Input),read,Archive,
                                         [formats([raw]),close_parent(false)]),
            (archive_next_header(Archive,data),
             setup_call_cleanup(archive_open_entry(Archive,Entry),
                                read_stream_to_codes(Entry,Data),close(Entry)),
             \+archive_next_header(Archive,_)),archive_close(Archive)),close(Input)).
