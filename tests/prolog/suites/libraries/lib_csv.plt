% Purpose: verify CSV spaces through the public provider seam and MeTTa match.
% Owns resources: temporary fixture files are removed by each test's cleanup.
% [tested: lib_csv; commit=504f8dddfa890ced97e795a13ab10e239b1de2ce]

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_csv/lib_csv.pl')).
:- use_module(library(filesex)).

:- begin_tests(lib_csv).

csv_fixture(Text, Path) :-
    tmp_file_stream(text, Path, Stream),
    setup_call_cleanup(true, write(Stream, Text), close(Stream)).

csv_rows(Path, Rows) :-
    'csv-space'(Path, Space),
    findall(Row, 'match'(Space, Row, Row, Row), Rows).

test(text_and_quoting,
     [setup(csv_fixture("id,amount\r\n001,\"a,b\"\r\n002,\"a\"\"b\"\r\n003,\"a\nb\"\r\n004,\r\n", Path)),
      cleanup(delete_file(Path))]) :-
    csv_rows(Path, Rows),
    assertion(Rows == [[row,"id","amount"], [row,"001","a,b"],
                       [row,"002","a\"b"], [row,"003","a\nb"], [row,"004",""]]).

test(empty_file,
     [setup(csv_fixture("", Path)), cleanup(delete_file(Path))]) :-
    csv_rows(Path, Rows), assertion(Rows == []).

test(duplicates_and_bound_matches,
     [setup(csv_fixture("a,1\na,1\nb,2\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-space'(Path, Space),
    findall(N, 'match'(Space, [row,"a",N], N, N), Numbers),
    assertion(Numbers == ["1","1"]).

test(repeated_variables,
     [setup(csv_fixture("a,a\na,b\nb,b\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-space'(Path, Space),
    findall(X, 'match'(Space, [row,X,X], X, X), Values),
    assertion(Values == ["a","b"]).

test(live_repeated_source,
     [setup(csv_fixture("before\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-space'(Path, Space),
    findall(X, seam:foreign_atoms(Space, X), Before),
    setup_call_cleanup(open(Path, write, Stream), write(Stream,"after\n"), close(Stream)),
    findall(X, seam:foreign_atoms(Space, X), After),
    assertion(Before == [[row,"before"]]),
    assertion(After == [[row,"after"]]).

test(missing_file,
     [setup((csv_fixture("", Path), delete_file(Path))),
      throws(error(csv_file_missing(_), _))]) :-
    'csv-space'(Path, _).

test(permission_denied,
     [setup((csv_fixture("x\n", Path), chmod(Path, 0))),
      cleanup((chmod(Path, 0o600), delete_file(Path))),
      throws(error(csv_permission_denied(_), _))]) :-
    'csv-space'(Path, _).

test(ragged_rows,
     [setup(csv_fixture("a,b\nc\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_malformed_row(_,2,width(2,1)),_))]) :-
    csv_rows(Path, _).

test(unterminated_quote,
     [setup(csv_fixture("a,\"b\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_malformed_row(_,1,invalid_quoting),_))]) :-
    csv_rows(Path, _).

test(write_refusal,
     [setup(csv_fixture("a,b\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_read_only(_,add),_))]) :-
    'csv-space'(Path, Space),
    'add-atom'(Space, [row,"c","d"], _).

test(unrelated_space_is_not_claimed) :-
    assertion(\+ seam:foreign_space('&csv:relative.csv')),
    assertion(\+ seam:foreign_space(['csv-rows', "relative.csv"])).

test(cut_and_error_release_the_stream,
     [setup(csv_fixture("a,b\nc\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-space'(Path, Space),
    once(seam:foreign_atoms(Space, _)),
    assertion(\+ (current_stream(_,read,S), stream_property(S,file_name(Path)))),
    catch(findall(X,seam:foreign_atoms(Space,X),_),error(csv_malformed_row(_,_,_),_),true),
    assertion(\+ (current_stream(_,read,S), stream_property(S,file_name(Path)))).

test(bounded_query_never_reads_the_malformed_tail,
     [setup(csv_fixture("a,b\nc\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-space'(Path, Space),
    once('match'(Space,[row,A,B],[A,B],Answer)),
    assertion(Answer == ["a","b"]).

test(swi_parser_differential,
     [setup(csv_fixture("", Path)), cleanup(delete_file(Path))]) :-
    Fields = ['', '001', 'a,b', 'a"b', 'line\nbreak', '  spaces  ', '\u03bb'],
    findall(row(A,B), (member(A,Fields), member(B,Fields)), Source),
    setup_call_cleanup(open(Path,write,Stream,[encoding(utf8)]),
                       csv_write_stream(Stream,Source,[]), close(Stream)),
    csv_rows(Path, Actual),
    findall([row,A,B],
            (member(row(X,Y),Source), atom_string(X,A), atom_string(Y,B)), Expected),
    assertion(Actual == Expected).

test(deletion_after_open_is_named,
     [setup(csv_fixture("x\n", Path)),
      throws(error(csv_file_missing(_),_))]) :-
    'csv-space'(Path, Space),
    delete_file(Path),
    once(seam:foreign_atoms(Space, _)).

test(clear_refusal,
     [setup(csv_fixture("a,b\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_read_only(_,clear),_))]) :-
    'csv-space'(Path, Space),
    spaces:metta_host_clear_space(Space).

% The snapshot door reads once into an ordinary space and keeps the record
% number, which is the thing csv-space's (row Field...) cannot carry.
snapshot_rows(Path, Rows) :-
    'csv-snapshot!'(Path, Space),
    findall(Row, 'get-atoms'(Space, Row), Unsorted),
    msort(Unsorted, Rows),
    spaces:metta_release_space(Space).

test(snapshot_rows_carry_their_record_number,
     [setup(csv_fixture("id,amount\n001,12.50\n002,9\n", Path)),
      cleanup(delete_file(Path))]) :-
    snapshot_rows(Path, Rows),
    assertion(Rows == [[row,1,"id","amount"], [row,2,"001","12.50"], [row,3,"002","9"]]).

% The differential the two doors owe each other: the same file must answer the
% same bag of records whichever door read it, or moving between them would
% change a program's answers. Duplicates included, since both keep them.
test(both_doors_answer_the_same_bag,
     [setup(csv_fixture("id,amount\n001,\"a,b\"\n002,9\n002,9\n004,\n", Path)),
      cleanup(delete_file(Path))]) :-
    csv_rows(Path, Streamed),
    snapshot_rows(Path, Numbered),
    findall(Fields, ( member([row,_|Fields], Numbered) ), Snapshot),
    findall(Fields, ( member([row|Fields], Streamed) ), View),
    msort(Snapshot, SortedSnapshot), msort(View, SortedView),
    assertion(SortedSnapshot == SortedView),
    assertion(length(SortedView, 5)).

% A snapshot is a snapshot: the view follows the file and this does not, which
% is what makes its record number an identity rather than a position in
% whatever the file currently says.
test(a_snapshot_does_not_move_when_the_file_does,
     [setup(csv_fixture("before\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-snapshot!'(Path, Space),
    'csv-space'(Path, View),
    setup_call_cleanup(true,
        ( setup_call_cleanup(open(Path, write, Stream), write(Stream, "after\n"),
                             close(Stream)),
          findall(X, 'get-atoms'(Space, X), Kept),
          findall(X, seam:foreign_atoms(View, X), Followed),
          assertion(Kept == [[row,1,"before"]]),
          assertion(Followed == [[row,"after"]]) ),
        spaces:metta_release_space(Space)).

% An ordinary space, so it takes the writes the view refuses.
test(a_snapshot_takes_writes,
     [setup(csv_fixture("a,1\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-snapshot!'(Path, Space),
    setup_call_cleanup(true,
        ( 'add-atom'(Space, [row,99,"derived","2"], _),
          findall(X, 'get-atoms'(Space, [row,99|X]), Added),
          assertion(Added == [["derived","2"]]) ),
        spaces:metta_release_space(Space)).

% Two snapshots of one file are two spaces, so one program's rows cannot land
% in another's.
test(two_snapshots_are_two_spaces,
     [setup(csv_fixture("a,1\n", Path)), cleanup(delete_file(Path))]) :-
    'csv-snapshot!'(Path, First),
    'csv-snapshot!'(Path, Second),
    setup_call_cleanup(true,
        ( assertion(First \== Second),
          'add-atom'(First, [row,99,"only here"], _),
          findall(X, 'get-atoms'(Second, X), Rows),
          assertion(Rows == [[row,1,"a","1"]]) ),
        ( spaces:metta_release_space(First),
          spaces:metta_release_space(Second) )).

% Every refusal is csv-space's, named for the door the program used.
test(snapshot_refusals_are_the_same_kinds,
     [setup(csv_fixture("a,b\nc\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_malformed_row(_,2,width(2,1)), context('csv-snapshot!', _)))]) :-
    snapshot_rows(Path, _).

test(snapshot_unterminated_quote,
     [setup(csv_fixture("a,\"b\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_malformed_row(_,1,invalid_quoting), context('csv-snapshot!', _)))]) :-
    snapshot_rows(Path, _).

test(snapshot_missing_file,
     [setup((csv_fixture("", Path), delete_file(Path))),
      throws(error(csv_file_missing(_), context('csv-snapshot!', _)))]) :-
    'csv-snapshot!'(Path, _).

% A failed read leaves no space behind, which is what the release arm is for.
test(snapshot_of_an_empty_file_is_an_empty_space,
     [setup(csv_fixture("", Path)), cleanup(delete_file(Path))]) :-
    snapshot_rows(Path, Rows), assertion(Rows == []).

% csv-space's own messages are unchanged by carrying the caller: this is the
% context the shipped door still names.
test(the_streaming_door_still_names_itself,
     [setup(csv_fixture("a,b\nc\n", Path)), cleanup(delete_file(Path)),
      throws(error(csv_malformed_row(_,2,_), context('csv-space', _)))]) :-
    csv_rows(Path, _).

test(effect_is_the_weakest_read_class) :-
    findall(Effect, metta_operation_effect('csv-space', Effect), Effects),
    assertion(Effects == [readOnlyLookup]).

% The snapshot allocates and fills a space, so it is a write like file-space!
% and file-metadata!, not a lookup.
test(the_snapshot_declares_that_it_writes) :-
    findall(Effect, metta_operation_effect('csv-snapshot!', Effect), Effects),
    assertion(Effects == [writesState]).

:- end_tests(lib_csv).
