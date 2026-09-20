% Purpose: test whether native archive names depend on the process locale.
% Guarantees: present requires the UTF8 control to read the exact Unicode name
% and the C locale alone to raise its character-conversion error.
% [tested: sh tools/check.sh host-workarounds; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
% Owns resources: archive handles close and this isolated process's original
% character locale is restored on every exit.

:- use_module(library(archive), [archive_open/4,archive_close/1,archive_next_header/2]).
:- use_module(library(filesex), [directory_file_path/3]).

main :-
    source_file(archive_locale_name(_,_),Source),file_directory_name(Source,Directory),
    directory_file_path(Directory,
        '../../../examples/ch08-data/08-03-the-shipped-libraries/_fixtures/compression-unicode.zip',Fixture),
    (current_prolog_flag(windows,true) -> UTF8='.UTF8'
    ;current_prolog_flag(apple,true) -> UTF8='UTF-8';UTF8='C.UTF-8'),
    atom_codes(Expected,[99,97,102,233,47,960,128578]),
    setup_call_cleanup(setlocale(ctype,Before,UTF8),
        (archive_locale_name(Fixture,Control),
         (Control==Expected -> true;throw(error(archive_locale_control_failed(Control),_))),
         setlocale(ctype,_,'C'),catch(archive_locale_name(Fixture,Name),Error,true),
         (var(Error),Name==Expected -> writeln(absent)
         ;nonvar(Error),Error=error(archive_error(84,_),_) -> writeln(present)
         ;throw(error(unexpected_archive_locale_result(Name,Error),_)))),
        setlocale(ctype,_,Before)).

archive_locale_name(Path,Name) :-
    setup_call_cleanup(archive_open(Path,read,Archive,[]),
                       archive_next_header(Archive,Name),archive_close(Archive)).
