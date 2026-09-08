% Purpose: stand in for a library that introduces a seam of its own, loaded
%   after the engine has finished booting.
% Assumes:
%   - consulted from a test, never from the engine's own load list, because
%     the whole point is that it arrives late
% Guarantees:
%   - declaring seam:kind/2 for a predicate this file defines publishes
%     that predicate, which is what engine/ext_points.pl's listener on the
%     multifile declaration is for
%     [tested: a_seam_declared_in_a_later_file_is_exported; commit=8fa9d546b3eebf3424ef1d667feab40c6b0f32ae]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%A MODULE, because a shipped library is one: the publication machinery exports
%a declared seam out of whichever module IMPLEMENTS it (seam_home/2 in
%engine/ext_points.pl asks implementation_module/1), and a file consulted into
%`user` implements it there, where an export list is not what makes a name
%reachable -- every space already resolves through `user` at the bottom of its
%chain. So the stand-in has to be shaped like the thing it stands in for.
:- module(plunit_seam_late, []).

%The engine core, the same base every shipped library declares.
:- set_module(base(metta_engine)).

% The definition comes first deliberately: a declaration for a predicate that
% does not exist yet is skipped rather than exported, so a file that declares
% before it defines relies on the engine's boot sweep instead, which a library
% loaded at run time has already missed.
plunit_late_declared_service(reached).
:- multifile seam:kind/2.
seam:kind(plunit_late_declared_service/1, service).
