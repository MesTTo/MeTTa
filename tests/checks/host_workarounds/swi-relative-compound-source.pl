% Purpose: detect relative compound imports reusing another directory's source.
% Guarantees: quoted pathname controls load both providers; present requires
% the same compound specification to load only its first provider.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: temporary source files are removed on every exit; their loaded
% modules and source-path cache belong to this isolated process until it exits.

:- use_module(library(filesex), [directory_file_path/3,make_directory_path/1,
                               delete_directory_and_contents/1]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(lists), [member/2]).

main :-
    tmp_file(relative_source,Directory),
    setup_call_cleanup(make_directory(Directory),
        ( relative_imports(Directory,atom,'support/native',Control),
          relative_imports(Directory,compound,support/native,Actual),
          format('atom=~q compound=~q~n',[Control,Actual]),
          ( Control\==[a,b] -> throw(error(relative_import_control_failed(Control),_))
          ; Actual==[a] -> writeln(present)
          ; Actual==[a,b] -> writeln(absent)
          ; throw(error(unexpected_relative_imports(Actual),_)) ) ),
        delete_directory_and_contents(Directory)).

relative_imports(Directory,Kind,Spec,Loaded) :-
    findall(Side,
        ( member(Side,[a,b]),
          atomic_list_concat([Kind,Side],'-',Name),
          directory_file_path(Directory,Name,Owner),
          directory_file_path(Owner,support,Support),make_directory_path(Support),
          directory_file_path(Support,'native.pl',Native),
          directory_file_path(Owner,'entry.pl',Entry),
          atom_concat(relative_owner_,Name,Module),
          atom_concat(relative_native_,Name,Provider),
          source_terms(Native,[(:- module(Provider,[]))]),
          source_terms(Entry,[(:- module(Module,[])),(:- use_module(Spec,[]))]),
          use_module(Entry,[]),module_property(Provider,file(_)) ),Loaded).

source_terms(Path,Terms) :-
    setup_call_cleanup(open(Path,write,Stream,[encoding(utf8)]),
                       maplist(write_source_term(Stream),Terms),close(Stream)).
write_source_term(Stream,Term) :-
    write_term(Stream,Term,[quoted(true),fullstop(true),nl(true)]).
