% Purpose: verify lossless CSV syntax, dialects, streaming and atomic writes.
% Guarantees: failure injection exercises snapshot and file ownership;
% generated boundary cases cover Unicode, widths and independent cursors.
% [tested: lib_csv_surface; commit=bd027d8b7a9ef1d96fb4cdb160c9b3eb4157d52e].
% Owns resources: fixtures remove their directories, suite cleanup releases
% added native spaces, and each fault injection restores its wrapped predicate.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_csv/lib_csv.pl').
:- use_module('../../../../lib/_support/owned_resources.pl').
:- use_module('../../scratch.pl').
:- use_module(library(prolog_wrap)).
:- use_module(library(thread), [concurrent_maplist/2, concurrent_maplist/3]).
:- use_module(library(ordsets), [ord_subtract/3]).
:- use_module(library(readutil)).
:- use_module(library(filesex)).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_csv_surface,
               [setup(metta_space_names(Before)), cleanup(release_added(Before))]).
:- meta_predicate with_file(1), records_in(1, +).

release_added(Before) :-
    metta_space_names(After), ord_subtract(After, Before, Added),
    maplist(spaces:metta_release_space, Added).

with_file(Goal) :- with_scratch_directory(csv_surface, records_in(Goal)).

records_in(Goal, Directory) :-
    directory_file_path(Directory, records, File), call(Goal, File).

write_bytes(File, Bytes) :-
    setup_call_cleanup(open(File, write, Stream, [type(binary)]),
                       maplist(put_byte(Stream), Bytes), close(Stream)).
write_text(File, Text) :- string_bytes(Text, Bytes, utf8), write_bytes(File, Bytes).
file_bytes(File, Bytes) :- read_file_to_codes(File, Bytes, [type(binary)]).
file_text(File, Text) :- file_bytes(File, Bytes), string_bytes(Text, Bytes, utf8).

no_stage(File) :-
    file_directory_name(File, Directory), directory_files(Directory, Names),
    sort(Names, Sorted), assertion(Sorted == ['.', '..', records, 'records.metta-csv.lock']).
no_stream(File) :- assertion(\+ stream_property(_, file_name(File))).

test(resource_guard_refuses_nondeterministic_operations) :-
    Outcome = received(none),
    must_throw(with_outcome_cleanup(true, member(_, [a,b]), capture_outcome(Outcome)),
               error(nondet_resource_operation,_)),
    arg(1,Outcome,Stored), assertion(Stored = exception(error(nondet_resource_operation,_))).
capture_outcome(Holder, Outcome) :- nb_setarg(1,Holder,Outcome).

test(text_preserves_strings_quotes_unicode_nul_and_newlines) :-
    Text = "001,\"é🦊\r\n\r\n\u0000\"\"end\"\r\n002,  text  \r\n",
    'csv-parse'(Text, Rows),
    assertion(Rows == [["001", "é🦊\r\n\r\n\u0000\"end"], ["002", "  text  "]]),
    'csv-encode'(Rows, Encoded), 'csv-parse'(Encoded, Again), assertion(Again == Rows).

test(zero_one_and_multiple_empty_fields_are_distinct) :-
    Options = [[width,any]], Rows = [[], [""], ["", ""], []],
    'csv-encode'(Rows, Options, Text), assertion(Text == "\r\n\"\"\r\n,\r\n\r\n"),
    'csv-parse'(Text, Options, Again), assertion(Again == Rows),
    'csv-parse'("", Empty), assertion(Empty == []), 'csv-encode'([], Encoded), assertion(Encoded == "").

test(unquoted_quotes_are_literal_after_the_first_character) :-
    'csv-parse'("a\"b,\"c\"\"d\"\n", Rows), assertion(Rows == [["a\"b", "c\"d"]]).

test(unicode_delimiter_and_quote_share_the_native_grammar) :-
    Options = [[separator,"🦊"], [quote,"λ"], [newline,"\n"]],
    Rows = [["a🦊b", "λquotedλ"], ["é\r\nx", ""]],
    'csv-encode'(Rows, Options, Text),
    assertion(Text == "λa🦊bλ🦊λλλquotedλλλ\nλé\r\nxλ🦊\n"),
    'csv-parse'(Text, Options, Actual), assertion(Actual == Rows).

test(record_terminators_are_orthogonal_to_quoted_newlines,
     [forall(member(Ending, ["\r\n", "\n", "\r"]))]) :-
    Rows = [["x\r\ny"]], Options = [[newline,Ending]],
    'csv-encode'(Rows, Options, Text),
    string_concat("\"x\r\ny\"", Ending, Expected), assertion(Text == Expected),
    'csv-parse'(Text, Actual), assertion(Actual == Rows).

test(quoting_can_be_disabled_without_discarding_data) :-
    Options = [[quote,""]],
    'csv-parse'("a\"b,c\n", Options, Rows), assertion(Rows == [["a\"b", "c"]]),
    'csv-encode'(Rows, Options, Text), assertion(Text == "a\"b,c\r\n"),
    forall(member(Bad, [[[""]], [["a,b"]], [["a\nb"]]]),
           must_throw('csv-encode'(Bad, Options, _), error(domain_error(csv_unquoted_field,_),_))).

test(width_modes_validate_every_consumed_record) :-
    'csv-parse'("\n\n", [[width,0]], Zeros), assertion(Zeros == [[],[]]),
    'csv-parse'("a,b\nc\n", [[width,any]], Ragged), assertion(Ragged == [["a","b"],["c"]]),
    must_throw('csv-parse'("a,b\nc\n", _), error(csv_malformed_row(text,2,width(2,1)),_)),
    must_throw('csv-parse'("a,b\n", [[width,1]], _), error(csv_malformed_row(text,1,width(1,2)),_)),
    must_throw('csv-encode'([["a"],["b","c"]], _), error(csv_malformed_row(text,2,width(1,2)),_)).

test(skipped_headers_establish_width_and_keep_logical_positions) :-
    'csv-parse'("id,name\na,b\na,b\n", [[skip,1]], Rows),
    assertion(Rows == [["a","b"],["a","b"]]),
    must_throw('csv-parse'("id,name\na\n", [[skip,1]], _),
               error(csv_malformed_row(text,2,width(2,1)),_)),
    'csv-parse'("a\n", [[skip,20]], None), assertion(None == []),
    'csv-encode'([["a"]], [[skip,20]], Written), assertion(Written == "a\r\n").

bad_options([[unknown,1]]).
bad_options([[separator,","] ,[separator,";"]]).
bad_options([[separator,""]]).
bad_options([[separator,"ab"]]).
bad_options([[separator,"\n"]]).
bad_options([[quote,"\r"]]).
bad_options([[separator,"x"],[quote,"x"]]).
bad_options([[newline,""]]).
bad_options([[width,-1]]).
bad_options([[skip,1.5]]).
bad_options([bad]).
bad_options([[skip|_]]).
bad_options([_]).
bad_options([[separator,_]]).
bad_options([[width,_]]).
test(invalid_options_raise, [forall(bad_options(Options))]) :-
    must_throw('csv-parse'("a\n", Options, _), error(_,_)).

test(cyclic_and_improper_rows_raise_before_publication) :-
    Rows = [[]|Rows], must_throw('csv-encode'(Rows, _), error(type_error(list,_),_)),
    must_throw('csv-encode'([["a"]|bad], _), error(type_error(list,_),_)),
    forall(member(Value, [42, symbol, f(a)]),
           must_throw('csv-encode'([[Value]], _), error(type_error(string,_),_))),
    must_throw('csv-encode'([[_]], _), error(instantiation_error,_)).

test(malformed_quoted_fields_never_become_eof,
     [forall(member(Text,["a\n\"broken", "a\n\"b\"x\n", "a\n\"\"\"\n"]))]) :-
    must_throw('csv-parse'(Text, _), error(csv_malformed_row(text,2,invalid_quoting),_)).

test(bom_is_text_and_other_unicode_line_separators_are_data) :-
    'csv-parse'("\ufeffa,\u2028\u2029\n", Rows), assertion(Rows == [["\ufeffa","\u2028\u2029"]]).

invalid_utf8([0xc0,0x80]).
invalid_utf8([0xc3]).
invalid_utf8([0xc3,0x28]).
invalid_utf8([0xed,0xa0,0x80]).
invalid_utf8([0xf4,0x90,0x80,0x80]).
invalid_utf8([0x80]).
invalid_utf8([0xff]).
test(utf8_errors_are_deferred_to_the_consumed_record,
     [forall(invalid_utf8(Bytes))]) :- with_file(bad_utf8(Bytes)).
bad_utf8(Bytes, File) :-
    append([0'a,10,0'"|Bytes], [0'",10], Document), write_bytes(File, Document),
    once('csv-read!'(File, First)), assertion(First == ["a"]), no_stream(File),
    must_throw(findall(Row,'csv-read!'(File,Row),_), error(csv_malformed_row(_,2,_),_)),
    no_stream(File).

test(buffer_boundaries_preserve_quote_delimiter_and_utf8_sequences,
     [forall(between(4088,4102,Padding))]) :- with_file(boundary(Padding)).
boundary(Padding, File) :-
    length(Codes, Padding), maplist(=(0'a), Codes), string_codes(Prefix, Codes),
    string_concat(Prefix, "🦊λ\r\nλ\u0000tail", Field),
    Options = [[separator,"🦊"],[quote,"λ"]], Rows = [[Field,"é"],["last","é"]],
    'csv-write!'(File, Rows, Options, true),
    findall(Row, 'csv-read!'(File, Options, Row), Actual), assertion(Actual == Rows), no_stage(File).

test(large_fields_have_no_fixed_size_limit) :-
    length(Codes, 150000), maplist(=(0'x), Codes), string_codes(Text, Codes),
    'csv-encode'([[Text]], Encoded), 'csv-parse'(Encoded, Rows), assertion(Rows == [[Text]]).

test(configured_descriptors_are_canonical_values) :- with_file(descriptors).
descriptors(File) :-
    write_text(File, "id;name\na;b\na;b\n"),
    'csv-space'(File, [[separator,";"],[skip,1]], A),
    'csv-space'(File, [[skip,1],[separator,";"]], B), assertion(A == B),
    assertion(metta_space_operand(A)), assertion(seam:foreign_capability(A,enumerate)),
    findall(Row, seam:foreign_atoms(A,Row), Rows),
    assertion(Rows == [[row,"a","b"],[row,"a","b"]]),
    must_throw('add-atom'(A,[row,"c","d"],_), error(csv_read_only(_,add),_)),
    'csv-space'(File, Default), atom_concat('&csv:', File, Default),
    'csv-space'(File, [[separator,","]], Explicit), assertion(Explicit == Default),
    atom_concat(A, '. ignored', Forged),
    must_throw(seam:foreign_space(Forged), error(csv_invalid_descriptor(_),_)).

test(malformed_descriptors_are_named,
     [forall(member(Name,['&csv-v1:broken(', '&csv-v1:csv(X,Y)', '&csv-v1:[]']))]) :-
    must_throw(seam:foreign_space(Name), error(csv_invalid_descriptor(_),_)).

test(filtered_out_rows_still_validate_width) :- with_file(filtered_width).
filtered_width(File) :-
    write_text(File, "a,b\nc\n"),
    must_throw(findall(hit,'csv-read!'(File,["unmatched","value"]),_),
               error(csv_malformed_row(_,2,width(2,1)),_)), no_stream(File).

test(independent_queries_keep_independent_positions) :- with_file(independent_queries).
independent_queries(File) :-
    write_text(File, "a\nb\n"),
    findall(A-B, ('csv-read!'(File,A),'csv-read!'(File,B)), Pairs),
    assertion(Pairs == [["a"]-["a"],["a"]-["b"],["b"]-["a"],["b"]-["b"]]), no_stream(File).

test(cancelling_a_reader_closes_its_stream) :- with_file(cancel_reader).
cancel_reader(File) :-
    write_text(File, "a\nb\n"),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            thread_create(catch(('csv-read!'(File,Row), thread_send_message(Queue,ready(Row)),
                                 thread_get_message(continue)), csv_stop, true), Thread, []),
            ( thread_get_message(Queue,ready(["a"])), assertion(stream_property(_,file_name(File))) ),
            ( thread_signal(Thread,throw(csv_stop)), thread_join(Thread,Status) )),
        message_queue_destroy(Queue)),
    assertion(Status == true), no_stream(File).

test(snapshot_keeps_header_positions_and_field_data) :- with_file(snapshot_positions).
snapshot_positions(File) :-
    write_text(File, "id;name\nfrom;internal\nfrom;internal\n"),
    'csv-snapshot!'(File, [[separator,";"],[skip,1]], Space),
    findall(Row,'get-atoms'(Space,Row),Rows0), msort(Rows0,Rows),
    assertion(Rows == [[row,2,"from","internal"],[row,3,"from","internal"]]).

test(occupied_snapshot_names_keep_their_data) :- with_file(occupied_snapshot).
occupied_snapshot(File) :-
    write_text(File, "a\n"), flag('$metta_csv_snapshot', Previous, Previous), Next is Previous+1,
    atom_concat('&csv-snapshot-', Next, Existing), add_sexp(Existing,sentinel),
    'csv-snapshot!'(File, Space), assertion(Space \== Existing),
    findall(Row,'get-atoms'(Existing,Row),Rows), assertion(Rows == [sentinel]).

test(snapshot_failure_and_output_mismatch_release_owned_spaces) :- with_file(snapshot_rollback).
snapshot_rollback(File) :-
    metta_space_names(Before), write_text(File,"a\nb,c\n"),
    must_throw('csv-snapshot!'(File,_),error(csv_malformed_row(_,2,_),_)),
    write_text(File,"a\n"), assertion(\+ 'csv-snapshot!'(File,impossible)),
    metta_space_names(After), assertion(After == Before), no_stream(File).

test(snapshot_creation_failure_is_owned_before_the_hook) :- with_file(creation_failure).
creation_failure(File) :-
    write_text(File,"a\n"), metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:ensure_native_storage_module(Space,_),csv_create,Wrapped,
            ( call(Wrapped),
              ( atom(Space), atom_concat('&csv-snapshot-',_,Space)
              -> throw(error(csv_injected_creation,_)) ; true ) )),
        must_throw('csv-snapshot!'(File,_),error(csv_injected_creation,_)),
        unwrap_predicate(spaces:ensure_native_storage_module(_,_),csv_create)),
    metta_space_names(After), assertion(After == Before).

test(snapshot_write_failure_rolls_back_the_completed_prefix) :- with_file(write_failure).
write_failure(File) :-
    write_text(File,"a\nb\n"), metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:add_sexp(_Space,Atom),csv_store,Wrapped,
            (call(Wrapped), ( Atom = [row,2|_] -> fail ; true ))),
        must_throw('csv-snapshot!'(File,_),error(csv_snapshot_write_failed(_),_)),
        unwrap_predicate(spaces:add_sexp(_,_),csv_store)),
    metta_space_names(After), assertion(After == Before), no_stream(File).

test(snapshot_release_failure_keeps_the_primary_outcome) :- with_file(release_failure).
release_failure(File) :-
    write_text(File,"a\nb,c\n"), metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:metta_release_space(_),csv_release,Wrapped,
                       (call(Wrapped),throw(error(csv_injected_release,_)))),
        must_throw('csv-snapshot!'(File,_),error(csv_snapshot_cleanup_failed(_,
                   exception(error(csv_malformed_row(_,2,_),_)),error(csv_injected_release,_)),_)),
        unwrap_predicate(spaces:metta_release_space(_),csv_release)),
    metta_space_names(After), assertion(After == Before).

test(concurrent_snapshots_allocate_independent_spaces) :- with_file(concurrent_snapshots).
concurrent_snapshots(File) :-
    write_text(File,"a\nb\n"), length(Files,16), maplist(=(File),Files),
    concurrent_maplist('csv-snapshot!',Files,Spaces), sort(Spaces,Unique),
    length(Unique,16),
    forall(member(Space,Spaces),
           (findall(Row,'get-atoms'(Space,Row),Rows), assertion(Rows == [[row,1,"a"],[row,2,"b"]]))).

test(cancelling_a_snapshot_releases_its_stream_and_owned_space) :- with_file(cancel_snapshot).
cancel_snapshot(File) :-
    write_text(File,"a\nb\n"), metta_space_names(Before),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            wrap_predicate(lib_csv:csv_store_row(_,_),csv_cancel_snapshot,Wrapped,
                (call(Wrapped),thread_send_message(Queue,ready),thread_get_message(continue))),
            setup_call_cleanup(
                thread_create(catch('csv-snapshot!'(File,_),csv_stop,true),Thread,[]),
                thread_get_message(Queue,ready),
                (thread_signal(Thread,throw(csv_stop)),thread_join(Thread,Status))),
            unwrap_predicate(lib_csv:csv_store_row(_,_),csv_cancel_snapshot)),
        message_queue_destroy(Queue)),
    assertion(Status == true), no_stream(File),
    metta_space_names(After), assertion(After == Before).

test(failed_snapshot_input_close_releases_the_space_and_names_the_io_error) :- with_file(snapshot_close).
snapshot_close(File) :-
    write_text(File,"a\n"), metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream),csv_snapshot_close,Wrapped,
            ( stream_property(Stream,file_name(File)), stream_property(Stream,mode(read))
            -> call(Wrapped),throw(error(io_error(close,Stream),injected))
            ; call(Wrapped) )),
        must_throw('csv-snapshot!'(File,_),error(csv_io_error(File,close),_)),
        unwrap_predicate(system:close(_),csv_snapshot_close)),
    metta_space_names(After), assertion(After == Before), no_stream(File).

test(append_preserves_existing_bytes_and_terminates_a_valid_last_record) :- with_file(append_bytes).
append_bytes(File) :-
    Original = "\"a\";\"é\r\n\u0000\"", write_text(File,Original),
    'csv-append!'(File,[["b","λ"]],[[separator,";"],[newline,"\n"]],true),
    string_concat(Original,"\nb;λ\n",Expected), file_text(File,Actual), assertion(Actual == Expected),
    findall(Row,'csv-read!'(File,[[separator,";"]],Row),Rows),
    assertion(Rows == [["a","é\r\n\u0000"],["b","λ"]]), no_stage(File).

test(empty_append_and_missing_file_creation) :- with_file(empty_append).
empty_append(File) :-
    'csv-append!'(File,[],true), file_bytes(File,Empty), assertion(Empty == []),
    write_text(File,"\"a\""), 'csv-append!'(File,[],true), file_text(File,Same), assertion(Same == "\"a\""),
    'csv-write!'(File,[],true), file_bytes(File,Written), assertion(Written == []), no_stage(File).

test(append_width_and_existing_syntax_errors_preserve_the_original) :- with_file(append_refusals).
append_refusals(File) :-
    forall(member(Original,["a,b\n", "a,b\nc\n", "a,b\n\"broken"]),
        ( write_text(File,Original),
          must_throw('csv-append!'(File,[["one"]],true),error(csv_malformed_row(_,_,_),_)),
          file_text(File,Actual), assertion(Actual == Original), no_stage(File) )).

test(invalid_later_output_keeps_the_destination) :- with_file(invalid_output).
invalid_output(File) :-
    write_text(File,"old"),
    must_throw('csv-write!'(File,[["valid"],[42]],true),error(type_error(string,42),_)),
    file_text(File,Actual), assertion(Actual == "old"), no_stage(File).

test(failed_output_unification_performs_no_file_mutation) :- with_file(output_mismatch).
output_mismatch(File) :-
    assertion(\+ 'csv-write!'(File,[["a"]],false)),
    assertion(\+ 'csv-append!'(File,[["a"]],false)),
    file_directory_name(File,Dir), directory_files(Dir,Names), sort(Names,Sorted), assertion(Sorted == ['.','..']).

test(failed_close_preserves_destination_and_releases_the_writer_lock) :- with_file(close_failure).
close_failure(File) :-
    write_text(File,"old\n"),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream),csv_close,Wrapped,
            ( ( stream_property(Stream,mode(write)), stream_property(Stream,file_name(Name)),
                file_base_name(Name,contents) )
            -> call(Wrapped),throw(error(io_error(close,Stream),injected))
            ; call(Wrapped) )),
        must_throw('csv-write!'(File,[["new"]],true),error(csv_io_error(_,close),_)),
        unwrap_predicate(system:close(_),csv_close)),
    file_text(File,Actual), assertion(Actual == "old\n"), no_stage(File),
    'csv-append!'(File,[["after"]],true).

test(publication_failure_removes_staging) :- with_file(publication_failure).
publication_failure(File) :-
    make_directory(File), must_throw('csv-write!'(File,[["a"]],true),error(_,_)),
    assertion(exists_directory(File)), no_stage(File).

test(cleanup_errors_report_whether_the_file_was_published) :- with_file(cleanup_outcomes).
cleanup_outcomes(File) :-
    write_text(File,"old"),
    setup_call_cleanup(
        wrap_predicate(files_ex:delete_directory_and_contents(_),csv_cleanup,Wrapped,
                       (call(Wrapped),throw(error(csv_injected_cleanup,_)))),
        ( must_throw('csv-write!'(File,[["new"]],true),
                     error(csv_staging_cleanup_failed(_,true,exit,error(csv_injected_cleanup,_)),_)),
          file_text(File,New), assertion(New == "new\r\n"),
          must_throw('csv-write!'(File,[[42]],true),
                     error(csv_staging_cleanup_failed(_,false,exception(_),error(csv_injected_cleanup,_)),_)),
          file_text(File,Still), assertion(Still == New) ),
        unwrap_predicate(files_ex:delete_directory_and_contents(_),csv_cleanup)),
    no_stage(File).

append_one(File-Number) :- number_string(Number,Text), 'csv-append!'(File,[[Text]],true).
test(concurrent_appends_keep_every_row_once) :- with_file(concurrent_appends).
concurrent_appends(File) :-
    findall(File-N,between(1,16,N),Jobs), concurrent_maplist(append_one,Jobs),
    findall(N,('csv-read!'(File,[Text]),number_string(N,Text)),Numbers),
    msort(Numbers,Sorted), numlist(1,16,Expected), assertion(Sorted == Expected), no_stage(File).

test(cancelling_a_writer_rolls_back_and_releases_its_lock) :- with_file(cancel_writer).
cancel_writer(File) :-
    write_text(File,"old\n"),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            wrap_predicate(lib_csv:csv_write_rows(_,_,_,_,_,_,_),csv_cancel,Wrapped,
                (call(Wrapped),thread_send_message(Queue,ready),thread_get_message(continue))),
            setup_call_cleanup(
                thread_create(catch('csv-write!'(File,[["new"]],true),csv_stop,true),Thread,[]),
                thread_get_message(Queue,ready),
                (thread_signal(Thread,throw(csv_stop)),thread_join(Thread,Status))),
            unwrap_predicate(lib_csv:csv_write_rows(_,_,_,_,_,_,_),csv_cancel)),
        message_queue_destroy(Queue)),
    assertion(Status == true), file_text(File,Text), assertion(Text == "old\n"), no_stage(File),
    'csv-append!'(File,[["after"]],true).

%A failure injected into an operation releases what that operation owns and
%leaves the destination as it was. Six helpers above already assert it, one per
%injection point, and counting which OPERATION each names showed the family had
%grown lopsided: csv-snapshot! carried five of them and csv-write! five, while
%csv-read! appeared nine times in this suite inside no refusal at all, csv-space
%four times inside none, and csv-append! eight times inside one
%[measured 2026-09-21]. These three close that, at the same injection points the
%existing helpers use, so the law is asserted of every effectful operation the
%library ships rather than of the two it was easiest to write.

test(a_failed_read_close_names_the_error_and_releases_the_stream) :- with_file(read_close_failure).
read_close_failure(File) :-
    write_text(File,"a\nb\n"),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream),csv_read_close,Wrapped,
            ( stream_property(Stream,file_name(File)), stream_property(Stream,mode(read))
            -> call(Wrapped),throw(error(io_error(close,Stream),injected))
            ; call(Wrapped) )),
        must_throw(findall(Row,'csv-read!'(File,Row),_),error(_,_)),
        unwrap_predicate(system:close(_),csv_read_close)),
    no_stream(File).

test(an_unreadable_source_refuses_the_view_and_leaves_no_stream) :- with_file(space_input_failure).
%csv-space builds a DESCRIPTOR and reads the input to validate it; it allocates
%no space of its own, which is why an injected creation failure finds nothing to
%fail and the refusal has to come from the input [source: lib_csv.pl:53-56,
%csv_with_input then csv_descriptor, no ensure_native_storage_module].
space_input_failure(File) :-
    make_directory(File),
    must_throw('csv-space'(File,_),error(csv_io_error(_,read),context('csv-space',_))),
    no_stream(File).

test(a_failed_append_close_preserves_the_file_and_leaves_no_staging) :- with_file(append_close_failure).
append_close_failure(File) :-
    write_text(File,"old\n"),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream),csv_append_close,Wrapped,
            ( ( stream_property(Stream,mode(write)), stream_property(Stream,file_name(Name)),
                file_base_name(Name,contents) )
            -> call(Wrapped),throw(error(io_error(close,Stream),injected))
            ; call(Wrapped) )),
        must_throw('csv-append!'(File,[["new"]],true),error(_,_)),
        unwrap_predicate(system:close(_),csv_append_close)),
    file_text(File,Actual), assertion(Actual == "old\n"), no_stage(File).

:- end_tests(lib_csv_surface).
