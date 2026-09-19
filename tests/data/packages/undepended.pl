% Purpose: the artifact the packages suite's undepended case names.
% Guarantees: packages_undepended_double/2 is defined nowhere else, so an edge
%   naming it can only have come from this case's backing row.
packages_undepended_double(In, Out) :- Out is In * 2.
