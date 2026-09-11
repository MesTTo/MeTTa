% Purpose: provide native signatures and answer bags for the face generator.
% Guarantees: fixture behavior is checked through the generated MeTTa face
% [tested: tests/checks/check_prologface_selftest.py; commit=WORKTREE].

:- module(lib_face_fixture,
          ['face-add'/3, 'face-choice'/2, 'face-count'/2, 'face-count'/3,
           'face-zero'/1, host_service/0]).
:- set_module(base(metta_engine)).
:- use_module(library(lists), [member/2]).

%! 'face-add'(+Left:number, +Right:number, -Sum:number) is det.
%
% Add Left and Right; unbound arithmetic operands raise.

'face-add'(Left, Right, Sum) :- Sum is Left + Right.

%! 'face-choice'(+Items:list, -Item:any) is nondet.
%
% Enumerate Items in order, retaining duplicate answers; an empty list fails.

'face-choice'(Items, Item) :- member(Item, Items).

%! 'face-count'(+Items:list, -Count:integer) is det.
%! 'face-count'(+Items:list, +Extra:integer, -Count:integer) is det.
%
% Count Items, optionally adding Extra.

'face-count'(Items, Count) :- length(Items, Count).
'face-count'(Items, Extra, Count) :- length(Items, Length), Count is Length + Extra.

%! 'face-zero'(-Zero:'Number') is det.
%
% Return zero without any input argument.

'face-zero'(0).

%! host_service is det.
%
% @private This exported host service has no MeTTa calling convention.

host_service.
