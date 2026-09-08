% Purpose: the second half of plain_autoload_a.pl's control -- an autoload/2 in
%   a file with no module of its own. Consulted into the same module as
%   plain_autoload_a.pl, this file's directive REPLACES that one's table.
% Guarantees:
%   - after this file is consulted into the module plain_autoload_a.pl was
%     consulted into, only this file's row is left
%     [tested: engine_modules:a_plain_pair_still_replaces_one_autoload_table; commit=WORKTREE]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- autoload(library(base64), [base64/2]).
