% Purpose: the artifact the packages suite's restored case names.
% Guarantees: packages_restored_double/2 is defined nowhere else, so a caller
%   answering through it in a space is exactly whether that space's backing
%   and its caller both survived the first importer's release.
packages_restored_double(In, Out) :- Out is In * 2.
