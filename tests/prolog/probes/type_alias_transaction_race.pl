% Purpose: drive two overlapping user transactions that each declare a
%   different alias for one name, and answer what the space is left holding
%   and how each transaction ended.
% Assumes: an engine is already loaded, or main/0 is given the checkout to
%   load one from, which is what lets the same orchestration run against a
%   tree with the commit constraint reverted.
% Guarantees: the interleaving is fixed by the driver rather than raced. Both
%   snapshots are open before either transaction writes, both writes are made
%   before either commits, and the commits happen in a stated order, so the
%   loser is decided here and not by the scheduler [tested:
%   structural_aliases:overlapping_transactions_leave_one_alias_and_name_the_loser;
%   commit=f5eb8775b78519c080da4ea7c6dff81f7be21ef9].
% Owns resources: one private space, one message queue and two worker threads,
%   all released on every outcome. Every receive carries a timeout and the
%   whole orchestration runs under call_with_time_limit/2, so a lost message
%   ends the run instead of hanging it, and a worker that is still running at
%   cleanup is detached rather than joined for the same reason.
% Fails when: the space ends up holding both declarations, which is what this
%   reproduces on a tree whose outer transaction does not re-validate at
%   commit.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- use_module(library(time), [call_with_time_limit/2]).

% How long one message may take to arrive, and how long the whole
% orchestration may take. Both are far above the milliseconds the fixed
% sequence actually costs; they are here so that a message nobody sends ends
% the run rather than parking a thread on it.
alias_race_message_timeout(10).
alias_race_run_timeout(60).

% The standalone arm. Root names the checkout whose engine to load.
main :-
    current_prolog_flag(argv, [Root]),
    directory_file_path(Root, 'engine/qlf_boot.pl', Boot),
    directory_file_path(Root, 'engine/metta.pl', Engine),
    ensure_loaded(Boot),
    ensure_loaded(Engine),
    overlapping_alias_declarations(Declarations, Outcomes),
    format('declarations=~q~n', [Declarations]),
    format('outcomes=~q~n', [Outcomes]),
    one_alias_survives(Declarations, Outcomes).

% What has to hold: one declaration stands rather than two, the transaction
% that committed first is the one that kept it, and the loser was refused by
% name rather than quietly dropped.
one_alias_survives(Declarations, Outcomes) :-
    Declarations == [['Alias', 'Number']],
    memberchk(a-committed, Outcomes),
    memberchk(b-threw(error(metta_type_alias_conflict(_, 'Count', 'Number', 'String'),
                            _)),
              Outcomes).

overlapping_alias_declarations(Declarations, Outcomes) :-
    alias_race_run_timeout(Limit),
    setup_call_cleanup(
        'new-space'(Space),
        call_with_time_limit(Limit, alias_race(Space, Declarations, Outcomes)),
        metta_release_space(Space)).

alias_race(Space, Declarations, Outcomes) :-
    setup_call_cleanup(
        message_queue_create(Inbox),
        alias_race_workers(Space, Inbox, Outcomes),
        message_queue_destroy(Inbox)),
    findall(Type, match_stored(Space, [':', 'Count', Type], Type, _), Declarations).

% One thread at a time, so a second thread_create/3 that raises cannot leave
% the first one running.
alias_race_workers(Space, Inbox, Outcomes) :-
    setup_call_cleanup(
        thread_create(alias_race_worker(a, Space, 'Number', Inbox), A, []),
        setup_call_cleanup(
            thread_create(alias_race_worker(b, Space, 'String', Inbox), B, []),
            alias_race_drive(A, B, Inbox, Outcomes),
            alias_race_release(B)),
        alias_race_release(A)).

% A worker reports each step and waits to be told the next one, so it holds
% its transaction open for exactly as long as the driver wants it open.
alias_race_worker(Tag, Space, RHS, Inbox) :-
    alias_race_message_timeout(Timeout),
    thread_self(Me),
    catch(( metta_transaction(( thread_send_message(Inbox, opened(Tag)),
                                thread_get_message(Me, declare, [timeout(Timeout)]),
                                metta_add_atom(Space, [':', 'Count', ['Alias', RHS]],
                                               true),
                                thread_send_message(Inbox, declared(Tag)),
                                thread_get_message(Me, commit, [timeout(Timeout)]) ))
          ->  Outcome = committed
          ;   Outcome = failed
          ),
          Error,
          Outcome = threw(Error)),
    thread_send_message(Inbox, done(Tag, Outcome)).

alias_race_drive(A, B, Inbox, [a-First, b-Second]) :-
    alias_race_message_timeout(Timeout),
    % Both snapshots open before either write: that is the overlap the
    % declaration-time check cannot see through, because each transaction
    % reads the state as of its own start.
    thread_get_message(Inbox, opened(a), [timeout(Timeout)]),
    thread_get_message(Inbox, opened(b), [timeout(Timeout)]),
    thread_send_message(A, declare),
    thread_get_message(Inbox, declared(a), [timeout(Timeout)]),
    thread_send_message(B, declare),
    thread_get_message(Inbox, declared(b), [timeout(Timeout)]),
    % One commit at a time, so a is the winner by construction.
    thread_send_message(A, commit),
    thread_get_message(Inbox, done(a, First), [timeout(Timeout)]),
    thread_send_message(B, commit),
    thread_get_message(Inbox, done(b, Second), [timeout(Timeout)]),
    thread_join(A, true),
    thread_join(B, true).

% Reached with the thread already joined on the ordinary path, where
% thread_property/2 raises and there is nothing to do. A worker that IS still
% running got there by not being driven to the end, so it is signalled and
% detached: joining it would wait for a message the driver is no longer going
% to send.
alias_race_release(Thread) :-
    (   catch(thread_property(Thread, status(_)), _, fail)
    ->  catch(thread_signal(Thread, throw(alias_race_abandoned)), _, true),
        catch(thread_detach(Thread), _, true)
    ;   true
    ).
