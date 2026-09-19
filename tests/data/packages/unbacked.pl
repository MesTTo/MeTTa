% Purpose: the artifact the packages suite's unbacked case names.
% Guarantees: packages_unbacked_double/2 is defined nowhere else, so its being
%   defined is exactly whether this case's backing row was performed.
packages_unbacked_double(In, Out) :- Out is In * 2.
