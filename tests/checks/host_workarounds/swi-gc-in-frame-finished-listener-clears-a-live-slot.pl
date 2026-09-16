% Purpose: expose collection clearing the completed first-var slot of an
%   instruction whose call under the debugger returns to the instruction's end.
% Assumes: a plain SWI process; no repository engine or workaround is loaded;
%   optimise is set before the samples load, so `is/2` compiles to A_ADD_FC.
% Owns resources: the trace and frame-finished listener end with the probe.
% Guarantees: a lost value in any sample answers present; otherwise absent
%   [tested: sh check.sh host-workarounds;
%   commit=6f634f6705fc1e40e0c2e3970d4156ee574ab70d].
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=WORKTREE]
:- set_prolog_flag(optimise, true).
:- use_module(library(lists), [append/3]).

user:prolog_trace_interception(Port, Frame, _, continue) :-
    ( Port == call, nb_current(reference_frames, true),
      prolog_frame_attribute(Frame, pc, _)
    -> true
    ; true ).

finished(_) :- garbage_collect.

% Each sample writes a first var in one instruction that the debugger routes
% through a call of =/2, arg/3 or is/2: B_UNIFY_FV, B_UNIFY_VF, B_UNIFY_FF,
% B_UNIFY_FC, B_ARG_CF, B_ARG_VF and A_ADD_FC (vm_list/1 shows the else
% branches). The if-then-else keeps the var a first var of its branch, and
% the final unification reads the slot the collector cleared.
sample(unify_fv, Input, Output) :-
    ( Input == yes -> I = [] ; I = Input ),
    Output = [I].
sample(unify_vf, Input, Output) :-
    ( Input == yes -> I = [] ; Input = I ),
    Output = [I].
sample(unify_ff, Input, Output) :-
    ( Input == yes -> I = [] ; I = J, J = Input ),
    Output = [I].
sample(unify_fc, Input, Output) :-
    ( Input == yes -> I = [] ; I = arithmetic ),
    Output = [I].
sample(arg_cf, Input, Output) :-
    T = f(Input),
    ( Input == yes -> I = [] ; arg(1, T, I) ),
    Output = [I].
sample(arg_vf, Input, Output) :-
    T = f(Input), N = 1,
    ( Input == yes -> I = [] ; arg(N, T, I) ),
    Output = [I].
sample(add_fc, Input, Output) :-
    ( Input == yes -> I = 0 ; I is Input + 1 ),
    Output = [I].

case(unify_fv, arithmetic, [arithmetic]).
case(unify_vf, arithmetic, [arithmetic]).
case(unify_ff, arithmetic, [arithmetic]).
case(unify_fc, arithmetic, [arithmetic]).
case(arg_cf, arithmetic, [arithmetic]).
case(arg_vf, arithmetic, [arithmetic]).
case(add_fc, 1, [2]).

observed(Reference, Name, Input, Output) :-
    setup_call_cleanup(
        nb_setval(reference_frames, Reference),
        ( trace, sample(Name, Input, Output) ),
        ( notrace, nb_delete(reference_frames) )).

lost(Reference, Name) :-
    case(Name, Input, Expected),
    observed(Reference, Name, Input, Output),
    Output \== Expected.

main :-
    forall(case(Name, Input, Expected), sample(Name, Input, Expected)),
    setup_call_cleanup(
        prolog_listen(frame_finished, finished),
        ( findall(Name, lost(false, Name), Controls),
          findall(Name, lost(true, Name), Lost) ),
        prolog_unlisten(frame_finished, finished)),
    ( Controls \== [] -> format("control_lost ~w~n", [Controls]), halt(1)
    ; Lost == [] -> writeln(absent)
    ; format("lost ~w~n", [Lost]), writeln(present) ).
