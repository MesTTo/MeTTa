% Purpose: detect an abolished definition bypassing an available loader hook,
%   and a closure resolved as if it were that abolished definition.
% Assumes: plain SWI-Prolog without the repository engine or workaround.
% Owns resources: this process owns the probe modules and their clauses.
% Guarantees: a fresh-call control verifies loading; an open old call keeps
%   retired clauses observable independently of clause collection; a tabled
%   predicate declared ahead of its clause is called under the debugger, whose
%   call port resolves every definition it calls, the tabling closure included;
%   and the final line reports present or absent [tested:
%   sh check.sh host-workarounds; commit=540eb6ad437efe08b343e6b86e89ac7dcb63ffee]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=9d54ed2129cea9859779419d6120636486eb6585]
%   [measured 2026-09-17: the closure sample answers [ok] on 10.1.14 as shipped
%   and [] on 10.1.14 built with the patch's first shape, whose clause-count
%   test read a closure's copied count of 0 and resolved the closure through
%   its procedure, so the retained sample read absent while every tabled call
%   made with the debugger on or a signal pending lost its answers; [ok] again
%   with closures excluded from the count test; command=sh check.sh
%   host-workarounds; fixture=SWI-Prolog 10.1.14 with the patch; commit=WORKTREE].

:- dynamic ready/1, loaded/1.
:- multifile user:exception/3.

user:exception(undefined_predicate, Module:leaf/1, retry) :-
    ready(Module),
    assertz(loaded(Module)),
    assertz(Module:leaf(ok)).

% The tabling wrapper's closure (pl-wrap.c) is a copy of this definition
% taken by the directive, before the clause below exists, so the clause count
% it carries is 0 for the life of the process.
:- table swi_erased_closure/1.
swi_erased_closure(ok).

main :-
    probe(swi_erased_fresh, Fresh),
    ( Fresh == result([ok], [loaded]) -> true
    ; throw(error(failed_fresh_loader(Fresh), main/0)) ),
    assertz(swi_erased_retained:leaf(first)),
    assertz(swi_erased_retained:leaf(second)),
    swi_erased_retained:leaf(_),
    abolish(swi_erased_retained:leaf/1),
    probe(swi_erased_retained, Retained),
    closure_probe(Closure),
    format('fresh ~q; retained ~q; closure ~q~n', [Fresh, Retained, Closure]),
    ( Retained == result(undefined, []) -> writeln(present)
    ; Retained == result([ok], [loaded]), Closure == [] -> writeln(present)
    ; Retained == result([ok], [loaded]), Closure == [ok] -> writeln(absent)
    ; throw(error(unexpected_retired_call(Retained, Closure), main/0)) ),
    !.

probe(Module, result(Answers, Events)) :-
    assertz(ready(Module)),
    assertz((Module:caller(Value) :- Module:leaf(Value))),
    catch(findall(Value, call(Module:caller(Value)), Answers),
          error(existence_error(procedure, Module:leaf/1), _),
          Answers = undefined),
    findall(loaded, loaded(Module), Events).

% The debugger's call port resolves the definition of every call it makes,
% the closure start_tabling/3 receives included. A host that reads the
% closure's copied count as "no clauses" resolves it through the procedure,
% hands the tabling wrapper its own closure, and the variant table completes
% with no answer.
closure_probe(Answers) :-
    debug, leash(-all), visible(-all),
    findall(Value, swi_erased_closure(Value), Answers),
    nodebug.
