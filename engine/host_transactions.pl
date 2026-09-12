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

:- module(host_transactions, [host_transaction_on_exit/1]).
:- use_module(library(prolog_wrap), [wrap_predicate/4]).
:- meta_predicate host_transaction_on_exit(0).

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
            % Workaround: swi-cleanup-window - catch an inference cut before recording the just-created reference.
            % SWI defers a cut on catch/3's call port until inside its
            % protected goal. Retrying ownership cannot lose Ref.
            catch(host_record_assertion(Journal, Clause, Ref),
                  Ball,
                  ( host_record_assertion(Journal, Clause, Ref), throw(Ball) ))
        ;   Original
        )).

host_record_assertion(Journal, Clause, Ref) :-
    ( Clause = Module:Plain -> true ; strip_module(Clause, Module, Plain) ),
    ( Plain = (Head :- _) -> true ; Head = Plain ),
    (   '$get_predicate_attribute'(Module:Head, transact, 1)
    ->  arg(1, Journal, Entries), nb_linkarg(1, Journal, [ref(Ref)|Entries])
    ;   true
    ).

% Workaround: swi-cleanup-window - register cleanup before linking the journal and trail its active owner.
% A child is linked before it can assert anything, so unwinding cannot leave
% its committed assertions outside the parent's ownership. The cleanup is a
% catch term and can repeat retirement after an inference cut.
host_transaction(Original, Policy) :-
    ( nb_current('$metta_host_assertions', Parent) -> true ; Parent = none ),
    Journal = journal([], []),
    setup_call_catcher_cleanup(
        true,
        ( host_transaction_enter(Parent, Journal), call(Original) ),
        Catcher,
        catch(host_transaction_leave(Parent, Journal, Catcher, Policy),
              Ball,
              ( host_transaction_leave(Parent, Journal, Catcher, Policy),
                throw(Ball) ))).

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
    host_transaction_finalize(Journal).

% Native event callbacks run under SWI's global event-list mutex. Completion
% that can acquire an application lock belongs after the native call returns.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L418-L468
host_transaction_on_exit(Goal) :-
    (   nb_current('$metta_host_assertions', Journal), Journal \== none
    ->  arg(2, Journal, Goals), nb_linkarg(2, Journal, [Goal|Goals])
    ;   throw(error(context_error(transaction),
                    context(host_transaction_on_exit/1,
                            'register completion inside a native transaction')))
    ).

host_transaction_finalize(Journal) :-
    arg(2, Journal, Goals),
    forall(member(Goal, Goals),
           ( call(Goal) -> true
           ; throw(error(goal_failed(Goal),
                         context(host_transaction_on_exit/1,
                                 'transaction reconciliation must succeed'))) )),
    nb_linkarg(2, Journal, []).

host_erase_assertions([]).
host_erase_assertions([ref(Ref)|Entries]) :-
    ( erase(Ref) -> true ; true ),
    host_erase_assertions(Entries).
host_erase_assertions([scope(Journal)|Entries]) :-
    arg(1, Journal, Nested),
    host_erase_assertions(Nested),
    host_erase_assertions(Entries).
