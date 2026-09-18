% Purpose: verify JSON object ownership, graph conversion, paths and file I/O.
% Guarantees: fault injection checks rollback and close-before-publication;
% codec and UTF-8 checks cover ordinary values and malformed boundary inputs
% [tested: lib_json_surface; commit=bd027d8b7a9ef1d96fb4cdb160c9b3eb4157d52e].
% Owns resources: fixtures remove their directories; suite cleanup releases
% object spaces created by these tests and restores every wrapped predicate.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_json/lib_json.pl').
:- use_module(library(prolog_wrap)).
:- use_module(library(thread), [concurrent_maplist/2]).
:- use_module(library(ordsets), [ord_subtract/3]).
:- use_module(library(readutil)).
:- use_module(library(filesex)).

:- begin_tests(lib_json_surface,
               [setup(metta_space_names(Before)), cleanup(release_added(Before))]).

:- meta_predicate must_throw(0, ?), with_directory(1).

release_added(Before) :-
    metta_space_names(After), ord_subtract(After, Before, Added),
    maplist(spaces:metta_release_space, Added).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true),
    assertion(nonvar(Error)), assertion(Error = Expected).

with_directory(Goal) :-
    getenv('TMPDIR', Parent), tmp_file(json_surface, Name), file_base_name(Name, Base),
    directory_file_path(Parent, Base, Dir),
    setup_call_cleanup(make_directory(Dir), call(Goal, Dir),
                       delete_directory_and_contents(Dir)).

write_bytes(File, Bytes) :-
    setup_call_cleanup(open(File, write, Stream, [type(binary)]),
                       maplist(put_byte(Stream), Bytes), close(Stream)).

write_text(File, Text) :- string_bytes(Text, Bytes, utf8), write_bytes(File, Bytes).

file_text(File, Text) :- read_file_to_string(File, Text, [encoding(utf8)]).

no_stage(Dir) :-
    directory_files(Dir, Files), msort(Files, Sorted),
    assertion(Sorted == ['.', '..', document]).

json_term(Text, Expected) :-
    json_codec:json_codec_read(Text, Term,
        [shape(classic), true(@(true)), false(@(false)), null(@(null))]),
    assertion(Term == Expected).

test(empty_objects_are_registered_and_nested_arrays_remain_arrays) :-
    'json-decode'("[{},[],[{}]]", [A, [], [B]]),
    assertion(metta_space_operand(A)), assertion(metta_space_operand(B)),
    assertion(A \== B),
    'json-encode'([A, [], [B]], Text), json_term(Text, [json([]), [], [json([])]]).

test(duplicate_fields_preserve_order_and_multiplicity) :-
    'json-decode'("{\"a\":1,\"a\":2,\"a\":1}", Object),
    findall(Key, 'get-keys'(Object, Key), Keys), assertion(Keys == [a, a, a]),
    findall(Value, 'get-value'(Object, a, Value), Values), assertion(Values == [1, 2, 1]),
    'json-encode'(Object, Text), assertion(Text == "{\"a\":1,\"a\":2,\"a\":1}").

test(special_keys_are_data_in_both_constructors) :-
    'dict-space'([[from, []], [internal, []], [42, "numeric"], ["a", 7]], Object),
    findall(X, 'get-value'(Object, from, X), From), assertion(From == [[]]),
    findall(X, 'get-value'(Object, internal, X), Internal), assertion(Internal == [[]]),
    findall(X, 'get-value'(Object, 42, X), Numeric), assertion(Numeric == ["numeric"]),
    assertion(\+ 'get-value'(Object, a, _)),
    'json-decode'("{\"from\":[],\"internal\":{}}", Decoded),
    'json-encode'(Decoded, Text), json_term(Text, json([from=[], internal=json([])])).

test(later_invalid_pair_does_not_allocate) :-
    metta_space_names(Before),
    must_throw('dict-space'([[a, 1], [invalid]], _), error(type_error(key_value_pair, _), _)),
    metta_space_names(After), assertion(After == Before).

test(partial_pair_is_not_instantiated_or_allocated) :-
    metta_space_names(Before), Pair = [a|Tail],
    must_throw('dict-space'([Pair], _), error(type_error(key_value_pair, _), _)),
    assertion(var(Tail)), metta_space_names(After), assertion(After == Before).

test(unbound_pair_is_not_invented) :-
    must_throw('dict-space'([Pair], _), error(type_error(key_value_pair, _), _)),
    assertion(var(Pair)).

test(occupied_generated_name_keeps_its_data) :-
    flag('$metta_json_space', Previous, Previous), Next is Previous + 1,
    atom_concat('&json-', Next, Existing), add_sexp(Existing, [sentinel, 42]),
    'dict-space'([[new, 7]], Object), assertion(Object \== Existing),
    findall(Row, 'get-atoms'(Existing, Row), Rows), assertion(Rows == [[sentinel, 42]]).

make_empty(Object) :- 'dict-space'([], Object).
test(concurrent_allocation_reserves_distinct_registered_names) :-
    length(Objects, 40), concurrent_maplist(make_empty, Objects),
    sort(Objects, Unique), assertion(same_length(Objects, Unique)),
    maplist(metta_space_operand, Objects).

test(failed_output_unification_releases_every_decoded_object) :-
    metta_space_names(Before),
    assertion(\+ 'json-decode'("{\"a\":[{},{}]}", impossible)),
    assertion(\+ 'dict-space'([[a, 1]], impossible)),
    metta_space_names(After), assertion(After == Before).

test(write_failure_releases_previous_siblings_and_root) :-
    metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:add_sexp(Space, Atom), json_surface_write, Wrapped,
            ( call(Wrapped),
              ( Atom = [explode, _]
              -> throw(error(json_injected_write(Space), _))
              ; true ) )),
        must_throw('json-decode'("{\"a\":{},\"b\":[{}, {\"explode\":1}]}", _),
                   error(json_injected_write(_), _)),
        unwrap_predicate(spaces:add_sexp(_, _), json_surface_write)),
    metta_space_names(After), assertion(After == Before).

test(cleanup_attempts_all_releases_and_retains_the_primary_outcome) :-
    metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:metta_release_space(Space), json_surface_release, Wrapped,
            ( call(Wrapped), throw(error(json_injected_release(Space), _)) )),
        ( catch('json-decode'("{\"a\":[{},{}]}", impossible), Error, true),
          assertion(nonvar(Error)),
          Error = error(json_space_cleanup_failed(Errors), context(lib_json, fail)),
          assertion(length(Errors, 3)) ),
        unwrap_predicate(spaces:metta_release_space(_), json_surface_release)),
    metta_space_names(After), assertion(After == Before).

test(cleanup_retains_a_write_exception_beside_release_failures) :-
    metta_space_names(Before),
    setup_call_cleanup(
        wrap_predicate(spaces:add_sexp(_Space, Atom), json_primary_write, Write,
            ( call(Write), ( Atom = [explode, _]
                          -> throw(error(json_injected_write, _)) ; true ) )),
        setup_call_cleanup(
            wrap_predicate(spaces:metta_release_space(_), json_secondary_release, Release,
                           (call(Release), throw(error(json_injected_release, _)))),
            ( catch('json-decode'("{\"child\":{},\"explode\":1}", _), Error, true),
              assertion(nonvar(Error)),
              assertion(Error = error(json_space_cleanup_failed([_,_]),
                  context(lib_json, exception(error(json_injected_write, _))))) ),
            unwrap_predicate(spaces:metta_release_space(_), json_secondary_release)),
        unwrap_predicate(spaces:add_sexp(_, _), json_primary_write)),
    metta_space_names(After), assertion(After == Before).

test(self_reference_raises_a_named_finite_error,
     [throws(error(representation_error(cyclic_json_value), _))]) :-
    'dict-space'([], Object), add_sexp(Object, [self, Object]), 'json-encode'(Object, _).

test(mutual_reference_raises_a_named_finite_error,
     [throws(error(representation_error(cyclic_json_value), _))]) :-
    'dict-space'([], A), 'dict-space'([[a, A]], B), add_sexp(A, [b, [B]]),
    'json-encode'(A, _).

test(cyclic_expression_raises_without_serializing_the_error_payload,
     [throws(error(representation_error(cyclic_json_value), _))]) :-
    Value = [Value], 'json-encode'(Value, _).

test(repeated_aliases_are_valid_and_snapshot_once) :-
    'dict-space'([[value, 1]], Shared), 'dict-space'([[a, Shared], [b, Shared]], Root),
    flag(json_surface_reads, _, 0),
    setup_call_cleanup(
        wrap_predicate(spaces:'get-atoms'(Space, _Atom), json_surface_reads, Wrapped,
            ( ( Space == Shared -> flag(json_surface_reads, N, N+1) ; true ), call(Wrapped) )),
        'json-encode'(Root, Text),
        unwrap_predicate(spaces:'get-atoms'(_, _), json_surface_reads)),
    json_term(Text, json([a=json([value=1]), b=json([value=1])])),
    flag(json_surface_reads, Count, Count), assertion(Count == 1).

test(non_pair_fields_are_refused,
     [forall(member(Atom, [stray, [a], [a, b, c]])),
      throws(error(type_error(json_object_field, _), _))]) :-
    'dict-space'([[valid, 1]], Object), add_sexp(Object, Atom), 'json-encode'(Object, _).

test(unbound_values_are_refused, [throws(error(instantiation_error, _))]) :-
    'json-encode'([_], _).

test(unsupported_compounds_are_refused, [throws(error(type_error(json_value, f(a)), _))]) :-
    'json-encode'(f(a), _).

test(rational_numbers_retain_the_native_codec_policy) :-
    Rational is 1 rdiv 3, 'json-encode'(Rational, Text), 'json-decode'(Text, Number),
    assertion(Number =:= float(Rational)).

test(parametric_spaces_are_objects_before_expressions) :-
    Object = [json_surface, 1], metta_declare_parametric_space(Object),
    add_sexp(Object, [a, [7, 8]]),
    'json-encode'(Object, Text), json_term(Text, json([a=[7, 8]])),
    findall(X, 'json-at'(Object, [a, 1], X), Values), assertion(Values == [8]).

test(structural_paths_preserve_duplicate_alternatives) :-
    'json-decode'("{\"a\":[{\"x\":1}],\"a\":[{\"x\":2}]}", Object),
    findall(X, 'json-at'(Object, [a, 0, x], X), Values), assertion(Values == [1, 2]),
    assertion(\+ 'json-at'(Object, [a, 9], _)),
    assertion(\+ 'json-at'(Object, [missing], _)),
    'json-at'(Object, [], Same), assertion(Same == Object),
    'json-at'(42, [], Scalar), assertion(Scalar == 42).

test(array_path_refuses_invalid_indexes,
     [forall(member(Index, [-1, 1.5, a])), throws(error(type_error(nonneg, Index), _))]) :-
    'json-at'([1, 2], [Index], _).

test(path_refuses_scalar_traversal, [throws(error(type_error(json_container, 7), _))]) :-
    'json-at'([7], [0, a], _).

test(path_requires_a_proper_list, [throws(error(type_error(list, _), _))]) :-
    'json-at'([7], [0|bad], _).

test(pretty_default_explicit_width_and_compact_width) :-
    'json-pretty'([1, 2], Pretty), assertion(Pretty == "[1, 2 ]"),
    'json-pretty'([1, 2], 1, Narrow), assertion(Narrow == "[\n  1,\n  2\n]"),
    'json-pretty'([1, 2], 0, Compact), 'json-encode'([1, 2], Encoded),
    assertion(Compact == Encoded), assertion(\+ sub_string(Compact, _, _, _, "\n")).

test(lines_accept_all_value_kinds_and_preserve_duplicate_records) :-
    findall(X, 'json-lines-decode'("1\r\ntrue\nnull\n[2]\n\"é\"\n1", X), Values),
    assertion(Values == [1, true, 'Null', [2], "é", 1]),
    'json-lines-encode'(Values, Text),
    findall(X, 'json-lines-decode'(Text, X), Again), assertion(Again == Values),
    assertion(sub_string(Text, _, 1, 0, "\n")).

test(empty_lines_input_and_empty_record_list) :-
    assertion(\+ 'json-lines-decode'("", _)), 'json-lines-encode'([], Text), assertion(Text == "").

test(lines_refuse_blank_records_with_position,
     [forall(member(Text, ["1\n\n2", "1\n \r\n2", "1\n\n"])),
      throws(error(json_line(2, error(syntax_error(_), _)), _))]) :-
    findall(X, 'json-lines-decode'(Text, X), _).

test(lines_refuse_bom_with_position,
     [throws(error(json_line(1, error(syntax_error(_), _)), _))]) :-
    'json-lines-decode'("\ufeff1\n", _).

test(line_errors_render_the_position_cause_and_remedy) :-
    catch(findall(X, 'json-lines-decode'("1\n\n", X), _), Error, true),
    assertion(nonvar(Error)), message_to_string(Error, Message),
    assertion(sub_string(Message, _, _, _, "JSON Lines record 2")),
    assertion(sub_string(Message, _, _, _, "Each line must contain")),
    assertion(\+ sub_string(Message, _, _, _, "Unknown error term")).

test(unicode_line_separators_inside_strings_are_data) :-
    Value = "a\u2028b\u2029c\nend", 'json-lines-encode'([Value], Text),
    findall(X, 'json-lines-decode'(Text, X), Values), assertion(Values == [Value]).

test(cutting_lines_retains_the_returned_object) :-
    once('json-lines-decode'("{\"a\":1}\ninvalid", Object)),
    findall(X, 'get-value'(Object, a, X), Values), assertion(Values == [1]).

test(file_round_trip_and_empty_lines_file) :- with_directory(file_round_trip).
file_round_trip(Dir) :-
    directory_file_path(Dir, document, File),
    'dict-space'([[from, "é🦊"], [values, [true, 'Null', 7]]], Object),
    'json-write!'(File, Object, Written), assertion(Written == true),
    'json-read!'(File, Again), 'json-encode'(Again, Text),
    json_term(Text, json([from="é🦊", values=[@(true), @(null), 7]])),
    'json-lines-write!'(File, [Object, 9], true),
    findall(X, 'json-lines-read!'(File, X), [First, 9]),
    'json-encode'(First, FirstText), assertion(FirstText == Text),
    'json-lines-write!'(File, [], true), file_text(File, Empty), assertion(Empty == ""),
    assertion(\+ 'json-lines-read!'(File, _)), no_stage(Dir).

test(lines_file_closes_on_cut_and_error) :- with_directory(lines_file_cleanup).
lines_file_cleanup(Dir) :-
    directory_file_path(Dir, document, File), write_text(File, "{\"a\":1}\ninvalid\n"),
    once('json-lines-read!'(File, Object)),
    assertion(\+ stream_property(_, file_name(File))),
    assertion(metta_space_operand(Object)),
    must_throw(findall(X, 'json-lines-read!'(File, X), _), error(json_line(2, _), _)),
    assertion(\+ stream_property(_, file_name(File))).

test(cancelling_a_reader_closes_the_file_and_keeps_returned_objects) :-
    with_directory(cancel_reader).
cancel_reader(Dir) :-
    directory_file_path(Dir, document, File), write_text(File, "{\"a\":1}\n2\n"),
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            thread_create(catch(( 'json-lines-read!'(File, Object),
                                  thread_send_message(Queue, ready(Object)),
                                  thread_get_message(continue) ),
                                json_surface_stop, true), Thread, []),
            ( thread_get_message(Queue, ready(Returned)),
              assertion(stream_property(_, file_name(File))) ),
            ( thread_signal(Thread, throw(json_surface_stop)), thread_join(Thread, Status) )),
        message_queue_destroy(Queue)),
    assertion(Status == true), assertion(\+ stream_property(_, file_name(File))),
    findall(X, 'get-value'(Returned, a, X), Values), assertion(Values == [1]).

invalid_utf8([0xc0, 0x80]).
invalid_utf8([0xc3]).
invalid_utf8([0xc3, 0x28]).
invalid_utf8([0xed, 0xa0, 0x80]).
invalid_utf8([0xf4, 0x90, 0x80, 0x80]).
invalid_utf8([0x80]).
invalid_utf8([0xff]).
test(file_refuses_invalid_utf8,
     [forall(invalid_utf8(Bytes))]) :- with_directory(invalid_utf8_file(Bytes)).
invalid_utf8_file(Bytes, Dir) :-
    directory_file_path(Dir, document, File), append([0'"|Bytes], [0'"], Document),
    write_bytes(File, Document), must_throw('json-read!'(File, _), error(representation_error(_), _)),
    append([0'1, 10|Document], [10], Lines), write_bytes(File, Lines),
    must_throw(findall(X, 'json-lines-read!'(File, X), _),
               error(json_line(2, error(representation_error(_), _)), _)),
    assertion(\+ stream_property(_, file_name(File))).

test(file_refuses_bom_and_trailing_content) :- with_directory(invalid_file).
invalid_file(Dir) :-
    directory_file_path(Dir, document, File),
    forall(member(Text, ["\ufeff1", "1 2", ""]),
           ( write_text(File, Text), must_throw('json-read!'(File, _), error(syntax_error(_), _)),
             assertion(\+ stream_property(_, file_name(File))) )).

test(failed_record_conversion_preserves_destination) :- with_directory(failed_conversion).
failed_conversion(Dir) :-
    directory_file_path(Dir, document, File), write_text(File, "old"),
    must_throw('json-lines-write!'(File, [1, f(invalid)], _), error(type_error(json_value, _), _)),
    file_text(File, Text), assertion(Text == "old"), no_stage(Dir).

test(failed_close_preserves_destination) :- with_directory(failed_close).
failed_close(Dir) :-
    directory_file_path(Dir, document, File), write_text(File, "old"),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream), json_surface_close, Wrapped,
            ( ( stream_property(Stream, mode(write)),
                stream_property(Stream, file_name(Name)), file_base_name(Name, contents) )
              -> call(Wrapped), throw(error(io_error(close, Stream), injected))
              ;  call(Wrapped) )),
        must_throw('json-write!'(File, [1, 2], _), error(io_error(close, _), injected)),
        unwrap_predicate(system:close(_), json_surface_close)),
    file_text(File, Text), assertion(Text == "old"), no_stage(Dir).

test(failed_publication_removes_staging) :- with_directory(failed_publication).
failed_publication(Dir) :-
    directory_file_path(Dir, document, File), make_directory(File),
    must_throw('json-write!'(File, [1], _), error(_, _)),
    assertion(exists_directory(File)), no_stage(Dir).

write_one(File-Value) :- 'json-write!'(File, [Value, Value, Value], true).
test(concurrent_writers_publish_one_complete_document) :- with_directory(concurrent_writers).
concurrent_writers(Dir) :-
    directory_file_path(Dir, document, File),
    findall(File-N, between(1, 12, N), Jobs), concurrent_maplist(write_one, Jobs),
    'json-read!'(File, Values), Values = [N, N, N], assertion(between(1, 12, N)), no_stage(Dir).

test(missing_file_raises, [throws(error(existence_error(source_sink, _), _))]) :-
    'json-read!'('json-surface-missing-file', _).

:- end_tests(lib_json_surface).
