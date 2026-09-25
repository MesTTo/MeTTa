% Purpose: the artifact the packages suite's outlived case names.
% Guarantees: packages_outlived_double/2 is defined nowhere else, so its
%   answering in a space is exactly whether that space's backing still stands.
packages_outlived_double(In, Out) :- Out is In * 2.
