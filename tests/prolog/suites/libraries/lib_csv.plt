% Purpose: verify CSV spaces through the public provider seam and MeTTa match.
% Owns resources: temporary fixture files are removed by each test's cleanup.
% [tested: lib_csv; commit=WORKTREE]

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

test(effect_is_the_weakest_read_class) :-
    findall(Effect, metta_operation_effect('csv-space', Effect), Effects),
    assertion(Effects == [readOnlyLookup]).

:- end_tests(lib_csv).
