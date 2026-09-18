% Purpose: create a native gzip control and the same member with a corrupt CRC.
% Owns resources: memory and encoder streams close before the byte lists return.
% [tested: sh check.sh host-workarounds; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].

:- module(gzip_host_fixture, [gzip_fixture/3]).
:- use_module(library(zlib), [zopen/3]).
:- use_module(library(memfile),
              [new_memory_file/1,free_memory_file/1,open_memory_file/4,memory_file_to_codes/3]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(lists), [append/3]).

gzip_fixture(Data,Good,Bad) :-
    findall(Byte,(between(0,32767,Index),Byte is Index mod 256),Data),
    setup_call_cleanup(new_memory_file(Memory),
        (setup_call_cleanup(open_memory_file(Memory,write,Output,[encoding(octet)]),
            setup_call_cleanup(zopen(Output,Z,[format(gzip),close_parent(false)]),
                               maplist(put_byte(Z),Data),close(Z)),close(Output)),
         memory_file_to_codes(Memory,Good,octet)),free_memory_file(Memory)),
    length(Trailer,8),append(Prefix,Trailer,Good),Trailer=[CRC|Rest],Altered is CRC xor 1,
    append(Prefix,[Altered|Rest],Bad).
