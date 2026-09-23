% Purpose: test whether library(unicode)'s unicode_nfkc_casefold/2 still keeps
% the default-ignorable code points Unicode's NFKC_Casefold removes.
% Guarantees: present when a soft hyphen survives the fold and a control's
% NFKC and case folding still happen; absent when it is removed as UCD 16.0.0
% maps it (DerivedNormalizationProps.txt, 00AD ; NFKC_CF, to nothing)
% [measured 2026-09-24: present on the native host before
% swi-unicode-nfkc-casefold-keeps-ignorables.patch was installed there, absent
% after; commit=4f71bdc87668db0b82ce750c6e8f471185530852].

:- use_module(library(unicode), [unicode_nfkc_casefold/2]).

main :-
    string_codes(Control, [0'S, 0xFB03]),
    unicode_nfkc_casefold(Control, ControlFolded),
    (   atom_codes(ControlFolded, [0's, 0'f, 0'f, 0'i])
    ->  true
    ;   throw(error(nfkc_casefold_control_failed(ControlFolded), _))
    ),
    string_codes(Text, [0'a, 0xAD, 0'b]),
    unicode_nfkc_casefold(Text, Folded),
    atom_codes(Folded, Codes),
    (   Codes == [0'a, 0xAD, 0'b] -> writeln(present)
    ;   Codes == [0'a, 0'b] -> writeln(absent)
    ;   throw(error(unexpected_nfkc_casefold(Codes), _))
    ).
