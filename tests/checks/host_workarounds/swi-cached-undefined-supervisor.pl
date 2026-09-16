% Purpose: expose a cached undefined call that bypasses a later loader hook.
% Assumes: plain SWI-Prolog, with no repository engine or workaround loaded.
% Owns resources: this process owns both probe modules and their clauses.
% Guarantees: a fresh-call control validates the loader before the last line
%   reports whether the cached call bypasses it
%   [tested: sh check.sh host-workarounds; commit=2d1289dafba121b7582a5cfcd49915d780745e4b]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-cached-undefined-supervisor.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=7e0b0ea3255455bb7db337cab55190c974ec64e1].

:- dynamic ready/1, loaded/1.
:- multifile user:exception/3.

user:exception(undefined_predicate, Module:leaf/1, retry) :-
    ready(Module),
    assertz(loaded(Module)),
    assertz(Module:leaf(ok)).

main :-
    probe(swi_undefined_fresh, Fresh, FreshEvents),
    require(Fresh-FreshEvents == [ok]-[loaded], fresh_loader_control),
    catch(swi_undefined_cached:leaf(_),
          error(existence_error(procedure, swi_undefined_cached:leaf/1), _),
          Missing = true),
    require(Missing == true, initial_call_was_undefined),
    probe(swi_undefined_cached, Cached, CachedEvents),
    format('fresh ~q; cached ~q; cached hook ~q~n',
           [Fresh, Cached, CachedEvents]),
    (   Cached-CachedEvents == undefined-[]
    ->  writeln(present)
    ;   Cached-CachedEvents == [ok]-[loaded]
    ->  writeln(absent)
    ;   throw(error(unexpected_cached_call(Cached, CachedEvents), main/0))
    ).

probe(Module, Answers, Events) :-
    assertz(ready(Module)),
    assertz((Module:caller(Value) :- Module:leaf(Value))),
    catch(findall(Value, call(Module:caller(Value)), Answers),
          error(existence_error(procedure, Module:leaf/1), _),
          Answers = undefined),
    findall(loaded, loaded(Module), Events).

require(Goal, Control) :-
    ( call(Goal) -> true ; throw(error(failed_control(Control), main/0)) ).
