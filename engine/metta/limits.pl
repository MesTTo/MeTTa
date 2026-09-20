% Purpose: work around two SWI-Prolog defects that let an inference limit
%   leave the host's own state inconsistent for the rest of the process. Both
%   are host workarounds and nothing here is engine behaviour: each is keyed to
%   docs/host-workarounds.md, each lifts with its ledger entry, and the
%   host-workarounds lane runs the reproduction that says whether the host
%   still needs it. The first: a resolution of an undefined predicate that a
%   bound cuts leaves the predicate answering "Unknown procedure" from every
%   compiled call site although its library is loaded. The second: a findall
%   whose bag was pushed before its cleanup was registered leaves that bag on
%   the thread's bag stack, and every later answer of the enclosing findall
%   lands in it.
% Assumes:
%   - engine/metta.pl consults this plain file while its owning module is the
%     load context, after engine/metta/control.pl, whose
%     metta_host_inference_budget/3 is one of the bounded doors this covers
%   - SWI-Prolog 10.1.13, src/pl-prims.c raiseInferenceLimitException: a trip
%     landing on the call port of catch/3 restores the limit and does not
%     raise, so it raises at the next call port instead, which is inside the
%     catch. Every consistency argument below rests on that one host rule,
%     and the ledger names it.
%   - SWI-Prolog 10.1.13, src/pl-proc.c trapUndefined and autoLoader: the trap
%     for an undefined predicate runs system:'$undefined_procedure'/4 as a
%     query and installs the undefined supervisor when that query raises
%   - SWI-Prolog 10.1.13, boot/bags.pl cleanup_bag/2 and findnsols2/5: a bag
%     is pushed with '$new_findall_bag' and '$destroy_findall_bag' is
%     registered one call port later
% Guarantees:
%   - a bound that cuts a first-use resolution leaves the predicate callable
%     from the compiled call site that trapped, and the bounded call reports
%     the bound's own ball [tested: limits:a_bound_landing_anywhere_inside_a_first_use_resolution_leaves_the_predicate_callable; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
%   - a bound that cuts a nested findall, a findnsols or one of the engine's
%     own bounded doors leaves the enclosing findall's answers whole
%     [tested: limits:a_bound_landing_inside_a_nested_findall_keeps_the_enclosing_answers; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
%   - a predicate nothing defines still refuses with an existence error under
%     a bound, and afterwards [tested: limits:an_undefined_predicate_under_a_bound_still_refuses; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
% Fails when:
%   - a bound other than an inference limit lands on the two call ports of the
%     trap's own query that precede the wrapper's catch. The predicate then
%     stays undefined until something resolves it explicitly. Repairing that
%     case means reading the frame the ball surfaces at, and a time limit or an
%     interrupt can surface at an engine's outer query frame, which nothing may
%     mark (docs/host-workarounds.md, swi-query-frame-discarded-on-engine-destroy);
%     an inference limit cannot surface there, because a limit is armed inside
%     the goal it bounds and an engine counts its own inferences, so that one
%     case is repaired below and the others are the residue.
% Decides:
%   - what only a bound can need is installed by the first bound of the
%     process and stays: the findall and findnsols wrappers, one inference per
%     findall for the catch, and the exception hook, one inference per ball
%     raised. findnsols, whose loop yields and is cut, keeps a registered
%     cleanup and pays the recorded scope. The resolution wrapper is static,
%     one inference per first-use trap, because an alarm or an interrupt can
%     cut a resolution without any inference limit armed.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- use_module(library(prolog_wrap), [wrap_predicate/4, current_predicate_wrapper/4]).

%Installed once per process; a second consult finds the wrapper in place.
%Each site below is its own directive, so a wrap that the host refuses is
%reported on its own line and leaves the others standing.
metta_host_wrap_once(Head, Name, Wrapped, Body) :-
    (   current_predicate_wrapper(Head, Name, _, _)
    ->  true
    ;   wrap_predicate(Head, Name, Wrapped, Body)
    ).

%%%%%%%%%% A resolution the bound cut is finished before the ball goes on %%%%%%%%%%
%
%Workaround: swi-autoload-cut-installs-the-undefined-supervisor - run the
%trap's query under a catch, finish the resolution after a cut, and re-raise
%the ball from the next clean call port.
%
%SWI resolves an undefined predicate by running system:'$undefined_procedure'/4
%as a query from C and reading its answer, fail, error or retry. A query that
%RAISED has no answer, so the C trap installs the undefined supervisor on the
%definition and lets the ball go on, and every later compiled call that is not
%the last call of its clause runs that supervisor and never traps again: the
%predicate answers "Unknown procedure" for the rest of the process although
%its library is loaded. A last call, a meta-call, an explicit import and a
%defining assert do resolve it, which is why the symptom hides in library code
%and surfaces as an intermittent. A first-use resolution walks
%absolute_file_name/3 for hundreds of inferences, so an inference limit lands
%inside it whenever the bounded goal is the first to reach the predicate: a
%bounded first load poisoned ugraphs:append/3 for the seven materialisation
%tests after it on one pytest worker, and the 2026-09-07 prolog_wrap:member/2
%intermittent followed an inference-limited derivation the same way
%[measured 2026-09-11: swipl -q -f none -g "use_module(library(ugraphs)),
%catch(call_with_inference_limit(vertices_edges_to_ugraph([a],[a-b],_),60,_),_,true),
%vertices_edges_to_ugraph([a],[a-b],G)" -t halt raises
%existence_error(procedure, ugraphs:append/3), and a fresh module whose
%clause calls sum_list/2 before another goal is poisoned at every budget from
%1 to 64; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d].
%
%The wrapper catches the cut and runs the resolution again: the limit is
%disarmed once it has raised and an alarm fires once, so the second attempt
%completes. It answers what the second attempt answered and re-raises the
%ball through thread_signal/2, so the ball is thrown from the next call port,
%which is the first port of the resolved predicate. Throwing it from inside
%the query instead leaves the C trap to continue into the resolved predicate
%with the ball pending, where the first foreign call drops it and the bound
%is silently lost [measured 2026-09-11: 105 of 200 budgets returned `!` from
%a bounded goal that had tripped, with that shape; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]. The
%re-raise happens only when the second attempt resolved the predicate; a
%predicate nothing defines keeps the host's own existence error, which is
%what a bounded goal reaching it is owed either way. After a resolution that
%was not cut there is no call port before the wrapper returns, because a
%trip there would raise inside the query with the definition in place, which
%is the same silent loss.
%
%The trap's query has two call ports before this catch, its own entry and the
%closure wrap_predicate/4 interposes. A trip on either leaves the predicate
%poisoned with nothing run; the exception hook below repairs that case.
:- metta_host_wrap_once(system:'$undefined_procedure'(_, _, _, Action),
                        metta_host_resolution_finish,
                        Resolve,
                        ( catch(Resolve, Ball, true),
                          (   var(Ball)
                          ->  true
                          ;   metta_host_finish_resolution(Resolve, Action, Ball)
                          ) )).

%The second attempt, and the ball's onward journey. Its own cut is swallowed:
%the predicate is then poisoned exactly as the host would have left it, and
%the first ball is the one the catcher is owed.
metta_host_finish_resolution(Resolve, Action, Ball) :-
    catch(ignore(Resolve), _, true),
    (   Action == retry
    ->  thread_self(Me),
        thread_signal(Me, throw(Ball))
    ;   true
    ).

%Workaround: swi-autoload-cut-installs-the-undefined-supervisor - a cut on
%the trap query's own entry ports never reached the wrapper; repair the
%predicate from the next safe point.
%
%The ball surfaces at the frame of the predicate that trapped, and SWI calls
%prolog:prolog_exception_hook/5 there with that frame. The predicate is
%undefined at that moment, the resolution nothing ran, so the hook asks for
%the resolution again from the thread's next safe point, which is the first
%call port of the catcher's recovery, where the limit is still disarmed. The
%resolution does not run inside the hook: a hook runs with the ball pending,
%and a foreign predicate that returns inside a resolution there is reported
%as one that "did not clear exception". Only the inference limit's ball is
%handled, for the reason the header's `Fails when` gives: reading a frame
%marks it, and this is the one ball that cannot surface at an engine's outer
%query frame. The hook is consulted on every ball the process raises, one
%inference each, so it is installed by the first bound of the process with
%the bag scope below, and a process that never bounds never pays it
%[measured 2026-09-11: budgets 1 and 2 of a 200-budget sweep reached this
%hook and both left the predicate callable with the limit reported; the C
%seat's error-ball row rose 2,000 inferences while the hook was static;
%commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d].
:- multifile prolog:prolog_exception_hook/5.
:- dynamic prolog:prolog_exception_hook/5.

%What the first bound arms beside the bag scope: one clause of
%prolog:prolog_exception_hook/5 per row of this seam, its head matching
%the inference limit's ball and its body the row's goal, which may name the
%frame the ball surfaced at. A row's goal SCHEDULES and never works: it runs
%with the ball pending. Every unit whose listener a bound can cut writes its
%row beside that listener, so there is one wrapper on the host's limit
%predicate and one seam that says what a bound arms: this file's resolution
%repair, and engine/spaces/receipts.pl's reconciliation of a native
%transaction listener cut after its commit. Two wrappers on one predicate
%would be two tests on every bounded call [measured 2026-09-12: the Python
%seat's hundred guarded queries read 38,107 with one wrapper's test and
%38,407 with a second; command=extensions/python/bench.py --counter-only
%query-limit-guarded; commit=3a931690116abfa8a5a37ecba3fe179d826cd712].
:- multifile seam:bound_hook/2.
seam:kind(bound_hook/2, declaration).
seam:bound_hook(Frame, metta_host_repair_cut_resolution(Frame)).

metta_host_repair_cut_resolution(Frame) :-
    prolog_frame_attribute(Frame, predicate_indicator, Indicator),
    metta_host_indicator_head(Indicator, Head),
    \+ '$get_predicate_attribute'(Head, defined, 1),
    thread_self(Me),
    thread_signal(Me, metta_host_repair_resolution(Head)),
    fail.

metta_host_indicator_head(Module:Name/Arity, Module:Head) :-
    !,
    functor(Head, Name, Arity).
metta_host_indicator_head(Name/Arity, user:Head) :-
    functor(Head, Name, Arity).

metta_host_repair_resolution(Head) :-
    catch(ignore('$define_predicate'(Head)), _, true).

%%%%%%%%%% The bound's own exception hooks, installed on first use %%%%%%%%%%
%
%A process that bounds something wants seam:bound_hook/2's clauses reachable
%from prolog_exception_hook/5 when the limit trips. That costs one assert per
%hook and a process that never bounds should pay nothing, so the install rides
%on the first call_with_inference_limit/3 of the process. The wrapper stays,
%because unwrap_predicate/2 releases the closure blob another thread may be
%inside at that moment. The limit predicate is defined in '$syspreds' and only
%imported into system, and a wrapper goes on the definition; the deferral on
%its call port survives, because raiseInferenceLimitException compares
%definitions and wrapping keeps the definition.
%
%This used to install two MORE wrappers here, replacing '$bags':cleanup_bag/2
%and '$bags':findnsols2/5 to work around swi-findall-bag-push-window: on an
%unpatched host an inference limit that trips between findall's bag push and
%its cleanup registration unwinds with the bag still on the stack and no
%cleanup owed, so the enclosing findall collects a SHORT answer set.
%tests/checks/host_workarounds/swi-cleanup-window.patch closed that window by
%deferring the inference check past the atomic region, which is word for word
%the ledger's lift condition for that entry.
%
%They are lifted because on the patched host they had stopped being redundant
%and become WRONG. With them installed, a nested call_with_inference_limit
%inside a live evaluation emptied the enclosing collection -- the very
%short-answer-set symptom they exist to prevent, produced by the cure rather
%than the defect. A bounded call that never came close to its budget did it
%too, so this was the replacement bag discipline meeting the patched host's
%deferral, not a budget being spent
%[measured 2026-09-20: `!(test (grammar-parse (alt (integer) (lit "x")) "7") 7)`
%answers () under METTA_VERIFY_SPECIALIZATIONS with the wrappers installed and
%7 without them, unchanged at budgets from 100 to 20,000,000; and
%tests/checks/host_workarounds/swi-findall-bag-push-window.pl answers absent on
%this patched host and present on stock 10.1.13, so the patch is what closed it
%and the host-workarounds lane is what keeps a stock host from being used].
:- metta_host_wrap_once('$syspreds':call_with_inference_limit(_, _, _),
                        metta_host_first_bound,
                        Bounded,
                        ( metta_host_first_bound,
                          Bounded )).

:- dynamic metta_host_bound_seen/0.

metta_host_first_bound :-
    (   metta_host_bound_seen
    ->  true
    ;   with_mutex('$metta_host_first_bound', metta_host_first_bound_once)
    ).

metta_host_first_bound_once :-
    (   metta_host_bound_seen
    ->  true
        %The clause lands in `prolog`, which resolves no engine predicate, so
        %each body carries the module of the row that declared it:
        %strip_module/3 answers a row's own qualifier or, for an unqualified
        %goal, this file's own module. `assertz(prolog:(Head :- Body))` rather
        %than `assertz((prolog:Head :- Body))`, because the second wraps the
        %body in this module as well, and a row then reads as a clause of a
        %body nobody declared.
    ;   forall(( clause(seam:bound_hook(Frame, Goal), true),
                 strip_module(Goal, Owner, Plain) ),
               assertz(prolog:(prolog_exception_hook(inference_limit_exceeded, _, Frame, _, _) :-
                                   Owner:Plain))),
        assertz(metta_host_bound_seen)
    ).
