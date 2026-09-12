% Purpose: distinguish a missing-name refusal from the native archive crash.
% Guarantees: present requires a successful UTF8 name control before SIGSEGV;
% absent requires a decoded legacy name or its explicit representation refusal.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: the parent drains/closes output and joins its isolated child.

:- use_module(library(process), [process_create/3,process_wait/2]).
:- use_module(library(archive), [archive_open/4,archive_close/1,archive_next_header/2]).
:- use_module(library(filesex), [directory_file_path/3]).

main :-
    source_file(archive_null_pathname_child,Source),current_prolog_flag(executable,Swipl),
    setup_call_cleanup(process_create(Swipl,
        ['-q','-f',none,'-s',Source,'-g',archive_null_pathname_child,'-t',halt],
        [stdin(null),stdout(pipe(Output)),stderr(pipe(Output)),process(PID)]),
        read_string(Output,_,Log),(close(Output),process_wait(PID,Status))),
    (sub_string(Log,_,_,_,"unicode-control-passed")
    -> (Status==killed(11) -> writeln(present)
       ;Status==exit(0),sub_string(Log,_,_,_,"legacy-name-survived") -> writeln(absent)
       ;throw(error(unexpected_archive_null_result(Status,Log),_)))
    ;throw(error(archive_null_control_failed(Status,Log),_))).

archive_null_pathname_child :-
    (current_prolog_flag(windows,true) -> UTF8='.UTF8'
    ;current_prolog_flag(apple,true) -> UTF8='UTF-8';UTF8='C.UTF-8'),
    setlocale(ctype,_,UTF8),
    source_file(archive_null_pathname_child,Source),file_directory_name(Source,Directory),
    directory_file_path(Directory,
        '../../../../examples/ch08-data/08-03-the-shipped-libraries/_fixtures',Fixtures),
    directory_file_path(Fixtures,'compression-unicode.zip',Unicode),
    atom_codes(Expected,[99,97,102,233,47,960,128578]),
    archive_null_name(Unicode,Expected),writeln('unicode-control-passed'),flush_output,
    directory_file_path(Fixtures,'compression-legacy.zip',Legacy),
    catch(archive_null_name(Legacy,Name),Error,true),
    (var(Error),atom_codes(Name,[99,97,102,233]) -> true
    ;nonvar(Error),Error=error(representation_error(_),_) -> true
    ;throw(error(unexpected_legacy_archive_name(Name,Error),_))),
    writeln('legacy-name-survived').

archive_null_name(Path,Name) :-
    setup_call_cleanup(archive_open(Path,read,Archive,[]),
                       archive_next_header(Archive,Name),archive_close(Archive)).
