% A library's own control signal, contributed the way a library contributes
% to any of the engine's static multifile seams: by consulting a file. A
% runtime assertz raises "No permission to modify static procedure".
%
% Without this, a cancellation a library raises is swallowed by the first
% recovery catch it meets and the program continues as though nothing
% happened, which is what the engine's own limit signals used to do before
% control_exception/1 existed.
%
% metta_engine: is where the clause has to land, and naming it is what a
% library does now that the engine core is a module of its own:
% control_exception/1 is the one seam whose home is that core rather than
% `seam`, because the translator emits it into compiled bodies and
% protect_engine_emitted/1 imports it into every space's module from there
% [source: engine/ext_points.pl, kind(control_exception/1, declaration); commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
% Unqualified, this file's clause would land in whichever module consulted it
% and the engine's recovery sites would never read it.
:- multifile metta_engine:control_exception/1.

metta_engine:control_exception(plunit_seam_cancelled).
