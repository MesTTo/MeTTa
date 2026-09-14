% Purpose: detect an abolished definition bypassing an available loader hook.
% Assumes: plain SWI-Prolog without the repository engine or workaround.
% Owns resources: this process owns the probe modules and their clauses.
% Guarantees: a fresh-call control verifies loading; an open old call keeps
%   retired clauses observable independently of clause collection, and the
%   final line reports present or absent [tested:
%   sh check.sh host-workarounds; commit=WORKTREE].

:- dynamic ready/1, loaded/1.
:- multifile user:exception/3.

user:exception(undefined_predicate, Module:leaf/1, retry) :-
    ready(Module),
    assertz(loaded(Module)),
    assertz(Module:leaf(ok)).

main :-
    probe(swi_erased_fresh, Fresh),
    ( Fresh == result([ok], [loaded]) -> true
    ; throw(error(failed_fresh_loader(Fresh), main/0)) ),
    assertz(swi_erased_retained:leaf(first)),
    assertz(swi_erased_retained:leaf(second)),
    swi_erased_retained:leaf(_),
    abolish(swi_erased_retained:leaf/1),
    probe(swi_erased_retained, Retained),
    format('fresh ~q; retained ~q~n', [Fresh, Retained]),
    ( Retained == result(undefined, []) -> writeln(present)
    ; Retained == result([ok], [loaded]) -> writeln(absent)
    ; throw(error(unexpected_retired_call(Retained), main/0)) ),
    !.

probe(Module, result(Answers, Events)) :-
    assertz(ready(Module)),
    assertz((Module:caller(Value) :- Module:leaf(Value))),
    catch(findall(Value, call(Module:caller(Value)), Answers),
          error(existence_error(procedure, Module:leaf/1), _),
          Answers = undefined),
    findall(loaded, loaded(Module), Events).
