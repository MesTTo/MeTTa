% Purpose: measure CSV traversal storage against retained-answer and append controls.
% Guarantees: every mode consumes the same fixed records and reports its
% checksum, inferences and peak sampled live storage after collection.
% [tested: swipl --on-error=status -q -s tests/prolog/lib_csv_stream_bench.pl; commit=bd027d8b7a9ef1d96fb4cdb160c9b3eb4157d52e].
% Owns resources: the fixture and writer lock are removed on exit; the append
% observation wrapper and linked statistics are released after measurement.
% Decides: 1000, 10000 and 100000 records separate constant auxiliary storage
% from the materialized control's output-proportional storage. CPU time is
% descriptive; collection and instrumentation belong to the measured window.

:- ensure_loaded('../../engine/qlf_boot.pl').
:- ensure_loaded('../../engine/metta.pl').
:- use_module('../../lib/lib_csv/lib_csv.pl').
:- use_module(library(filesex)).
:- use_module(library(prolog_wrap)).
:- initialization(main, main).

main :-
    getenv('TMPDIR', Parent), tmp_file(csv_scaling, Temporary), file_base_name(Temporary, Base),
    directory_file_path(Parent, Base, Directory),
    setup_call_cleanup(make_directory(Directory),
        ( directory_file_path(Directory, records, File),
          writeln('mode,records,file_bytes,inferences,cpu_seconds,live_global_bytes,local_bytes,checksum'),
          forall(member(N,[1000,10000,100000]),
                 ( fixture(File,N), measure(stream,File,N),
                   measure(materialized,File,N), measure(append,File,N) )) ),
        delete_directory_and_contents(Directory)).

fixture(File,N) :-
    setup_call_cleanup(open(File,write,Stream,[encoding(utf8),newline(posix)]),
                       forall(between(1,N,_),format(Stream,'001,"é🦊,value"\r\n',[])),close(Stream)).

measure(Mode,File,N) :-
    size_file(File,Bytes), garbage_collect,
    statistics(globalused,G0), statistics(localused,L0),
    Stats=stats(0,0,0,0), statistics(inferences,I0), statistics(cputime,T0),
    consume(Mode,File,Stats,G0,L0),
    statistics(cputime,T1), statistics(inferences,I1),
    Stats=stats(Count,Checksum,Global,Local),
    term_hash(["001","é🦊,value"],Hash), Expected is N*Hash,
    ( Count =:= N, Checksum =:= Expected -> true
    ; throw(error(csv_benchmark_mismatch(Mode,N,Stats),context(measure/3,_))) ),
    I is I1-I0, T is T1-T0,
    format('~w,~d,~d,~d,~6f,~d,~d,~d~n',[Mode,N,Bytes,I,T,Global,Local,Checksum]).

consume(stream,File,Stats,G0,L0) :-
    forall('csv-read!'(File,Fields),observe(Fields,Stats,G0,L0)).
consume(materialized,File,Stats,G0,L0) :-
    findall(Fields,'csv-read!'(File,Fields),Rows),
    sample(Stats,G0,L0),
    forall(member(Row,Rows),accumulate(Row,Stats)).
consume(append,File,Stats,G0,L0) :-
    setup_call_cleanup(
        nb_linkval('$csv_bench_stats',Stats),
        setup_call_cleanup(
            wrap_predicate(lib_csv:csv_record(_,_,_,_,_,_,_,Fields),csv_bench,Wrapped,
                           (call(Wrapped),user:observe_append(Fields,G0,L0))),
            'csv-append!'(File,[],true),
            unwrap_predicate(lib_csv:csv_record(_,_,_,_,_,_,_,_),csv_bench)),
        nb_delete('$csv_bench_stats')).

observe_append(Fields,G0,L0) :-
    nb_getval('$csv_bench_stats',Stats), observe(Fields,Stats,G0,L0).

observe(Row,Stats,G0,L0) :-
    accumulate(Row,Stats), arg(1,Stats,N),
    (N=:=1;0 is N mod 1000), !, sample(Stats,G0,L0).
observe(_,_,_,_).
accumulate(Row,Stats) :-
    term_hash(Row,H), arg(1,Stats,N0), N is N0+1, nb_setarg(1,Stats,N),
    arg(2,Stats,C0), C is C0+H, nb_setarg(2,Stats,C).
sample(Stats,G0,L0) :-
    garbage_collect, statistics(globalused,G), statistics(localused,L),
    arg(3,Stats,OldG), PeakG is max(OldG,G-G0), nb_setarg(3,Stats,PeakG),
    arg(4,Stats,OldL), PeakL is max(OldL,L-L0), nb_setarg(4,Stats,PeakL).
