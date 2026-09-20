% Purpose: answer whether library(ugraphs) still reaches append/2 through the
%   library index alone: top_sort/2 calls append/2 while the file declares only
%   append/3 as its lists dependency. Prints `present` while it does and
%   `absent` once ugraphs declares or imports append/2.
% Assumes:
%   - run as `swipl -q -f none -s FILE -g main -t halt` by the host-workarounds
%     lane, which reads the last line printed
% Guarantees:
%   - `present` iff top_sort/2 raises existence_error(procedure, ugraphs:append/2)
%     with autoload off, the engine's no-autoload configuration
%     [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14, ugraphs.pl:460;
%     command=sh tools/check.sh host-workarounds; fixture=SWI-Prolog 10.1.13;
%     commit=b7d85e1d7e2ce7ea6d56a4a67ac7344ef2826750]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with tests/checks/host_workarounds/swi-ugraphs-implicit-append.patch;
%   command=sh tools/check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=213559ecd8e8ec1f2f44ab16ea06a197c734bb81].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

main :-
    use_module(library(ugraphs)),
    set_prolog_flag(autoload, false),
    catch(( top_sort([a-[b], b-[]], _), Verdict = absent ),
          error(existence_error(procedure, ugraphs:append/2), _),
          Verdict = present),
    format("~w~n", [Verdict]).
