% Purpose: stand in for a shipped library that declares an autoload/2 of its
%   own, so a suite can ask whether the engine's declarations survive it.
% Guarantees:
%   - its '$autoload'/3 table is its own, and neither engine/metta.pl's
%     library(uuid) row nor lib/lib_tabling/lib_tabling.pl's library(wfs) row
%     is disturbed by it
%     [tested: engine_modules:a_librarys_autoload_table_is_its_own; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- module(plunit_module_autoload, []).

:- set_module(base(metta_engine)).

:- autoload(library(sha), [sha_hash/3]).
