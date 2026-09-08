% Purpose: the control for autoload_module.pl -- an autoload/2 in a file with
%   no module of its own. Consulted beside plain_autoload_b.pl into one module
%   it proves that SWI's '$autoload'/3 table is one predicate per module, which
%   is the defect the module boundary removes.
% Guarantees:
%   - after plain_autoload_b.pl is consulted into the same module, this file's
%     row is gone [tested: engine_modules:a_plain_pair_still_replaces_one_autoload_table; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- autoload(library(sha), [sha_hash/3]).
