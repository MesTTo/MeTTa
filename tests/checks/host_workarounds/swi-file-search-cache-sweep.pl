% Purpose: detect the file-search cache sweep on the first library load after expiry.
% Assumes: SWI-Prolog exposes its boot/init.pl cache timestamps so expiry can
%   be forced without waiting or changing the lookup being measured.
% Guarantees: compares the next lookup after the aged load with two warm
%   lookups; an unequal warm control or a reversed difference is a broken
%   reproduction [tested: sh check.sh host-workarounds; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with tests/checks/host_workarounds/swi-file-search-cache-sweep.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=c01a874d38c31236c22dbe2f30fab689ec5bc510].
% Owns resources: this fresh process's cache timestamps and loaded libraries;
%   neither survives process exit.

:- use_module(library(apply), []).

main :-
    set_prolog_flag(file_search_cache_time, 1000000000),
    lookup(_),
    age_cache,
    use_module(library(heaps), []),
    lookup(Expired), lookup(Warm), lookup(Control),
    format('after_expired_load=~d warm=~d warm_control=~d~n',
           [Expired, Warm, Control]),
    ( Warm =\= Control -> throw(error(unstable_warm_lookup(Warm, Control), _))
    ; Expired > Warm -> writeln(present)
    ; Expired =:= Warm -> writeln(absent)
    ; throw(error(reversed_lookup_cost(Expired, Warm), _)) ).

lookup(Cost) :-
    statistics(inferences, Before),
    absolute_file_name(library(apply), _, [file_type(prolog), access(read)]),
    statistics(inferences, After),
    Cost is After-Before.

% boot/init.pl's zero-timeout clause bypasses insertion and the sweep. Keep
% a positive timeout and age the state the ordinary first load consults.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L1531-L1564
age_cache :-
    get_time(Now),
    current_prolog_flag(file_search_cache_time, Timeout),
    Old is Now-Timeout-1,
    findall(Key-Path, system:'$search_path_file_cache'(Key, _, Path), Entries),
    retractall(system:'$search_path_file_cache'(_, _, _)),
    forall(member(Key-Path, Entries),
           assertz(system:'$search_path_file_cache'(Key, Old, Path))),
    retractall(system:'$search_path_gc_time'(_)),
    assertz(system:'$search_path_gc_time'(Old)).
