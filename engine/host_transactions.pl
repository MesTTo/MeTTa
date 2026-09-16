% Purpose: run registered reconciliation after native transactions and snapshots return.
% Assumes: native transactions cross '$transaction'/2,3 and '$snapshot'/1,
%   the primitives behind transaction/1,2,3 and snapshot/1
%   [source: SWI-Prolog 10.1.14 boot/init.pl; commit=WORKTREE].
% Guarantees: host_transaction_on_exit/1 runs its registered reconciliation
%   after the native transaction returns and the parent registry is restored
%   [tested: host_transaction_completion; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Assumes: registered reconciliation is idempotent and succeeds; the host runs
%   the cleanup that walks it to completion [tested: host_transaction_completion;
%   commit=WORKTREE].
% Guarantees: one failed reconciliation cannot skip another registered goal;
%   the registry retains only failed goals after an ordinary completion
%   walk [tested: host_transaction_completion; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].
% Guarantees: host_transaction_on_exit/2 supplies the original native outcome,
%   independently of any later reconciliation error [tested:
%   host_transaction_completion; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].
% Owns resources: each transaction retains its completion registry until it
%   finishes; a nested engine or thread opens its own
%   [tested: host_transactions:a_nested_engine_keeps_its_own_registry; commit=WORKTREE].
% Guarded by: the registry is a SWI global variable, local to its engine and
%   thread [tested: host_transactions:concurrent_registries_keep_their_owners;
%   commit=WORKTREE].

:- module(host_transactions, [host_transaction_on_exit/1, host_transaction_on_exit/2]).
:- use_module(library(prolog_wrap), [wrap_predicate/4]).
% Declared, not left to the library index: the engine runs with autoload off
% (engine/check.sh lib-autoload and no-autoload), where an undeclared foldl/4
% or reverse/2 is an existence error at the first transaction that finalizes.
:- autoload(library(apply), [foldl/4]).
:- autoload(library(lists), [reverse/2]).
:- meta_predicate host_transaction_on_exit(0), host_transaction_on_exit(0, ?).

% Native transaction event callbacks run under SWI's global event-list mutex,
% so completion that can acquire an application lock belongs after the native
% call returns. The three primitives are wrapped so every transaction and
% snapshot carries its own completion registry, restored to the parent's when
% the primitive returns.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L418-L468
:- initialization(install_host_transaction_completion).

install_host_transaction_completion :-
    host_transaction_wrap(system:'$transaction'(_, _), Original,
                          host_transaction(Original, commit)),
    host_transaction_wrap(system:'$transaction'(_, _, _), Constrained,
                          host_transaction(Constrained, commit)),
    host_transaction_wrap(system:'$snapshot'(_), Snapshot,
                          host_transaction(Snapshot, discard)).

host_transaction_wrap(Head, Original, Body) :-
    % Replacing the same named wrapper preserves its position and returns
    % the original closure, including after a partial reinstall.
    wrap_predicate(Head, metta_host_transaction_completion, Original, Body).

% Setup opens the registry, trailed so a nested engine or a thread never
% inherits one, and the cleanup, which the host runs to completion, restores
% the parent's and runs what was registered.
host_transaction(Original, Policy) :-
    ( nb_current('$metta_host_completions', Parent) -> true ; Parent = none ),
    Registry = completions([]),
    setup_call_catcher_cleanup(
        b_setval('$metta_host_completions', Registry),
        call(Original),
        Catcher,
        host_transaction_leave(Parent, Registry, Catcher, Policy)).

host_transaction_leave(Parent, Registry, Catcher, Policy) :-
    nb_linkval('$metta_host_completions', Parent),
    host_transaction_finalize(Registry, Catcher, Policy).

% Native event callbacks run under SWI's global event-list mutex. Completion
% that can acquire an application lock belongs after the native call returns.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L418-L468
host_transaction_on_exit(Goal) :-
    host_transaction_on_exit(Goal, _).

host_transaction_on_exit(Goal, Outcome) :-
    (   nb_current('$metta_host_completions', Registry), Registry \== none
    ->  arg(1, Registry, Goals),
        nb_linkarg(1, Registry, [completion(Outcome, Goal)|Goals])
    ;   throw(error(context_error(transaction),
                    context(host_transaction_on_exit/1,
                            'register completion inside a native transaction')))
    ).

host_transaction_finalize(Registry, Catcher, Policy) :-
    host_transaction_outcome(Catcher, Policy, Outcome),
    arg(1, Registry, Goals),
    host_transaction_completions(Goals, Outcome, [], Failed0, [], Errors0),
    % The retained list is linked, not copied, so nothing inside it may depend
    % on a binding this frame's own throw will undo. Each accumulator cell is
    % built onto an already bound tail and reverse/2 rebuilds it the same way;
    % a list whose tails a recursion bound afterwards came back as [First|_]
    % when a cleanup re-read it after this frame's throw had undone the
    % bindings [measured 2026-09-16: two failing repairs, the re-read walked
    % one and rethrew the less urgent error].
    reverse(Failed0, Failed), reverse(Errors0, Errors),
    nb_linkarg(1, Registry, Failed),
    ( Errors = [First|Later]
    -> foldl(host_transaction_urgent, Later, First, Urgent), throw(Urgent)
    ; true ).

% Catcher describes the original native primitive. A repair failure can change
% what its wrapper returns, but cannot turn that earlier commit into rollback.
host_transaction_outcome(exit, commit, committed) :- !.
host_transaction_outcome(exit, discard, discarded) :- !.
host_transaction_outcome(exception(Error), _, threw(Error)) :- !.
host_transaction_outcome(external_exception(Error), _, threw(Error)) :- !.
host_transaction_outcome(_, _, failed).

% SWI's own exception ordering preserves a later urgent signal after an earlier
% ordinary repair error. The accumulator goes first so equal urgency retains
% the first error, as the host's cleanup contract does.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-prims.c#L6281-L6287
host_transaction_urgent(Later, Earlier, Chosen) :-
    system:'$urgent_exception'(Earlier, Later, Chosen).

% Raw native reconciliation remains idempotent and retryable. A foreign or
% physical callback scheduled by metta_after_foreign/2 retains its own attempt
% result and returns immediately when this native bookkeeping is retried.
host_transaction_completions([], _, Failed, Failed, Errors, Errors).
host_transaction_completions([Completion|Goals], Outcome, Failed0, Failed, Errors0, Errors) :-
    Completion = completion(Original, Goal),
    catch(( (Original = Outcome, call(Goal)) -> Result = ok
          ; Result = threw(error(goal_failed(Goal),
                                 context(host_transaction_on_exit/1,
                                         'transaction reconciliation must succeed'))) ),
          Error, Result = threw(Error)),
    ( Result == ok -> Failed1 = Failed0, Errors1 = Errors0
    ; Result = threw(Failure), Failed1 = [Completion|Failed0], Errors1 = [Failure|Errors0] ),
    host_transaction_completions(Goals, Outcome, Failed1, Failed, Errors1, Errors).

