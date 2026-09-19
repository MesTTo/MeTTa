% Purpose: the artifact the packages suite's absent case names.
% Guarantees: packages_absent_double/2 is defined nowhere else. The requires
%   case does not back anything with it; the file exists so every case reaches
%   package_fixture/3 the same way, with an artifact to name.
packages_absent_double(In, Out) :- Out is In * 2.
