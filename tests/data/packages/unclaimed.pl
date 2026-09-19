% Purpose: the artifact the packages suite's unclaimed case names.
% Guarantees: packages_unclaimed_double/2 is defined nowhere else, so its being
%   defined is exactly whether this case's backing row was performed.
packages_unclaimed_double(In, Out) :- Out is In * 2.
