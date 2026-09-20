% Purpose: the artifact the packages suite's computed case names.
% Guarantees: packages_computed_double/2 is defined nowhere else, so its being
%   defined is exactly whether a COMPUTED row normalised and then performed.
packages_computed_double(In, Out) :- Out is In * 2.
