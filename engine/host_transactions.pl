% Purpose: own assertion rollback and reconciliation after native transactions.
% Assumes: Prolog assertions cross assert/1,2, asserta/1,2 or assertz/1,2;
%   native engine storage and compiled equations use these doors
%   [source: engine/spaces/catalog.pl:add_sexp_in/5,
%   engine/spaces/foreign.pl:assert_function_clause/3; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: failed transactions and snapshots retire their new clauses even
%   after a nested erase, while older clauses and nontransactional predicates
%   keep their host semantics [tested: host_transactions; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: each transaction retains its assertion references until its
%   outermost transaction finishes; empty child journals are removed on exit
%   [tested: host_transactions:empty_savepoints_do_not_accumulate; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarded by: the journal is a SWI global variable, local to its engine and
%   thread [tested: host_transactions:concurrent_journals_keep_their_owners;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: host_transaction_on_exit/1 runs its registered reconciliation
%   after the native transaction returns and the parent journal is restored
%   [tested: host_transaction_completion; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Assumes: registered reconciliation is idempotent and succeeds; cleanup may
%   repeat it after an inference cut [tested: host_transaction_completion;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: one failed reconciliation cannot skip another registered goal;
%   the cleanup retry retains only failed goals after an ordinary completion
%   walk [tested: host_transaction_completion; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].
% Guarantees: host_transaction_on_exit/2 supplies the original native outcome,
%   independently of any later reconciliation error [tested:
%   host_transaction_completion; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].

:- module(host_transactions, [host_transaction_on_exit/1, host_transaction_on_exit/2]).
:- use_module(library(prolog_wrap), [wrap_predicate/4]).
% Declared, not left to the library index: the engine runs with autoload off
% (engine/check.sh lib-autoload and no-autoload), where an undeclared foldl/4
% or reverse/2 is an existence error at the first transaction that finalizes,
% and an undeclared member/2 fails the install below at load.
:- autoload(library(apply), [foldl/4]).
:- autoload(library(lists), [member/2, reverse/2]).
:- meta_predicate host_transaction_on_exit(0), host_transaction_on_exit(0, ?).

% Workaround: swi-nested-retract-loses-outer-assert - retain assertion ownership outside SWI's transaction table.
% merge_clause_tables replaces an outer GEN_ASSERTZ/GEN_ASSERTA entry with
% GEN_NESTED_RETRACT. Its rollback restores the erased generation and leaves
% the aborted creation available to a later transaction. The journal below
% retains only newly asserted clause references, then erases them after the
% host rolls back. Nested savepoints, clause identity and duplicate answers
% remain ordinary engine behaviour; this extra ownership is a host workaround.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c#L417-L427
:- initialization(install_host_transaction_workaround).

install_host_transaction_workaround :-
    host_transaction_wrap(system:'$transaction'(_, _), Original,
                          host_transaction(Original, commit)),
    host_transaction_wrap(system:'$transaction'(_, _, _), Constrained,
                          host_transaction(Constrained, commit)),
    host_transaction_wrap(system:'$snapshot'(_), Snapshot,
                          host_transaction(Snapshot, discard)),
    % policy-inventory-exempt: mechanism-internal; reason=SWI's three assertion families are the host operations whose clause references this workaround journals; evidence=engine/host_transactions.pl:install_host_assertion_workaround/1
    forall(member(Name, [assert, asserta, assertz]),
           install_host_assertion_workaround(Name)).

host_transaction_wrap(Head, Original, Body) :-
    % Replacing the same named wrapper preserves its position and returns
    % the original closure, including after a partial reinstall.
    wrap_predicate(Head, metta_host_assertion_ownership, Original, Body).

% Workaround: swi-nested-retract-loses-outer-assert - journal each actual assertion, including assertions with no requested reference.
% Source ownership may adopt existing clauses. It cannot supply this journal,
% whose authority is the assertion itself. A caller's already bound reference
% is unified after recording, preserving the assertion if that unification
% fails. Nontransactional host caches are excluded by the host's own flag.
install_host_assertion_workaround(Name) :-
    compound_name_arguments(Referenced, Name, [Clause, Ref]),
    Assert = ( var(Ref), \+ attvar(Ref)
             -> Created = Ref, Original
             ;  Original = call(Closure),
                compound_name_arity(Closure, Primitive, 2),
                call(Primitive, Clause, Created) ),
    host_assertion_body(Clause, Created, Assert, Original, ReferencedBody),
    host_transaction_wrap(system:Referenced, Original,
                          (ReferencedBody, Ref = Created)),
    % assert/1 owns its fresh output, so it can call the original assert/2
    % directly. Only a caller-supplied reference needs the check above.
    compound_name_arguments(Unreferenced, Name, [Clause]),
    host_assertion_body(Clause, Ref, Original, OriginalOne, UnreferencedBody),
    host_transaction_wrap(system:Unreferenced, OriginalOne, UnreferencedBody).

host_assertion_body(Clause, Ref, Assert, Original, Body) :-
    Body = (
        (   nb_current('$metta_host_assertions', Journal), Journal \== none
        ->  Assert,
            % Workaround: swi-cleanup-window - an inference limit can land at the call port between the assertion and the record of its reference; catch/3 is exempt from the limit, so it fires inside the protected goal and the handler records before rethrowing.
            % Recording twice cannot lose Ref. sig_atomic/1 around the pair
            % closes the same window for one inference more per assertion, on
            % a path that asserts inside every evaluation [measured 2026-09-17:
            % constructors.plt's cold typed loop 1468 -> 1508 inferences;
            % command=swipl -g main ai_probe_scope_cost2.pl, old_pair 6 against
            % new_pair 7 per assertion]. The site goes with this wrapper when
            % swi-nested-retract-loses-outer-assert is patched in the host. The
            % goal is qualified because this body runs as system's wrapper, not
            % as a clause of this module.
            catch(host_transactions:host_record_assertion(Journal, Clause, Ref),
                  Ball,
                  ( host_transactions:host_record_assertion(Journal, Clause, Ref), throw(Ball) ))
        ;   Original
        )).

host_record_assertion(Journal, Clause, Ref) :-
    ( Clause = Module:Plain -> true ; strip_module(Clause, Module, Plain) ),
    ( Plain = (Head :- _) -> true ; Head = Plain ),
    (   '$get_predicate_attribute'(Module:Head, transact, 1)
    ->  arg(1, Journal, Entries), nb_linkarg(1, Journal, [ref(Ref)|Entries])
    ;   true
    ).

% A child is linked before it can assert anything, so unwinding cannot leave
% its committed assertions outside the parent's ownership: Setup links it and
% the cleanup, which the host runs to completion, retires it.
host_transaction(Original, Policy) :-
    ( nb_current('$metta_host_assertions', Parent) -> true ; Parent = none ),
    Journal = journal([], []),
    setup_call_catcher_cleanup(
        host_transaction_enter(Parent, Journal),
        call(Original),
        Catcher,
        host_transaction_leave(Parent, Journal, Catcher, Policy)).

host_transaction_enter(Parent, Journal) :-
    (   Parent == none
    ->  true
    ;   arg(1, Parent, Entries),
        nb_linkarg(1, Parent, [scope(Journal)|Entries])
    ),
    b_setval('$metta_host_assertions', Journal).

host_transaction_leave(Parent, Journal, Catcher, Policy) :-
    nb_linkval('$metta_host_assertions', Parent),
    (   Catcher == exit, Policy == commit
    ->  true
    ;   arg(1, Journal, Entries),
        host_erase_assertions(Entries),
        nb_linkarg(1, Journal, [])
    ),
    (   Parent \== none, arg(1, Journal, []),
        arg(1, Parent, [scope(Last)|Older]), Last == Journal
    ->  nb_linkarg(1, Parent, Older)
    ;   true
    ),
    host_transaction_finalize(Journal, Catcher, Policy).

% Native event callbacks run under SWI's global event-list mutex. Completion
% that can acquire an application lock belongs after the native call returns.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L418-L468
host_transaction_on_exit(Goal) :-
    host_transaction_on_exit(Goal, _).

host_transaction_on_exit(Goal, Outcome) :-
    (   nb_current('$metta_host_assertions', Journal), Journal \== none
    ->  arg(2, Journal, Goals),
        nb_linkarg(2, Journal, [completion(Outcome, Goal)|Goals])
    ;   throw(error(context_error(transaction),
                    context(host_transaction_on_exit/1,
                            'register completion inside a native transaction')))
    ).

host_transaction_finalize(Journal, Catcher, Policy) :-
    host_transaction_outcome(Catcher, Policy, Outcome),
    arg(2, Journal, Goals),
    host_transaction_completions(Goals, Outcome, [], Failed0, [], Errors0),
    % The retained list is linked, not copied, so nothing inside it may depend
    % on a binding this frame's own throw will undo. Each accumulator cell is
    % built onto an already bound tail and reverse/2 rebuilds it the same way;
    % a list whose tails a recursion bound afterwards came back as [First|_]
    % on the cleanup retry [measured 2026-09-16: two failing repairs, the
    % retry walked one and rethrew the less urgent error].
    reverse(Failed0, Failed), reverse(Errors0, Errors),
    nb_linkarg(2, Journal, Failed),
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

host_erase_assertions([]).
host_erase_assertions([ref(Ref)|Entries]) :-
    ( erase(Ref) -> true ; true ),
    host_erase_assertions(Entries).
host_erase_assertions([scope(Journal)|Entries]) :-
    arg(1, Journal, Nested),
    host_erase_assertions(Nested),
    host_erase_assertions(Entries).
