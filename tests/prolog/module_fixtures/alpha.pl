% Purpose: stand in for a shipped library whose Prolog half is a module, so a
%   suite can ask whether its helper is private. Its twin beta.pl defines a
%   helper of the SAME name with a different answer.
% Guarantees:
%   - plunit_module_answer/1 answers alpha, through a helper this module does
%     not export [tested: engine_modules:two_libraries_may_define_one_helper_name; commit=WORKTREE]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- module(plunit_module_alpha, [plunit_module_answer/1]).

%The engine core, the base every shipped library declares.
:- set_module(base(metta_engine)).

plunit_module_answer(X) :- plunit_module_helper(X).

plunit_module_helper(alpha).
