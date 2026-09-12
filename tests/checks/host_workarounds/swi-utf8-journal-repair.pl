% Purpose: detect a UTF-8 term reader accepting noncanonical encoded input.
% Guarantees: a valid NUL control decodes first; present requires the overlong
% bytes to decode as the same String. [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: close the byte writer and reader and remove their temporary file.

:- use_module(library(apply), [maplist/2]).

main :-
    tmp_file(database_utf8_probe,Path),
    setup_call_cleanup(true,database_utf8_check(Path,Result),
                       (exists_file(Path)->delete_file(Path);true)),
    writeln(Result).
database_utf8_check(Path,Result) :-
    database_utf8_read(Path,[34,0,34,46],Control),string_codes(Control,[0]),
    catch(database_utf8_read(Path,[34,192,128,34,46],Text),Error,true),
    ( nonvar(Error) -> Result=absent
    ; Text==Control -> Result=present
    ; throw(error(database_utf8_probe_value(Text),_)) ).
database_utf8_read(Path,Bytes,Term) :-
    setup_call_cleanup(open(Path,write,Out,[type(binary)]),maplist(put_byte(Out),Bytes),close(Out)),
    setup_call_cleanup(open(Path,read,In,[encoding(utf8)]),read_term(In,Term,[]),close(In)).
