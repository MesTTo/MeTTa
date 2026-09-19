% Purpose: the artifact the packages suite's backed case names.
% Guarantees: packages_backed_double/2 is defined nowhere else, so its being
%   defined is exactly whether this case's backing row was performed.
packages_backed_double(In, Out) :- Out is In * 2.
