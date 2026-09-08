% Purpose: the second half of alpha.pl's control. See plain_alpha.pl.
% Guarantees:
%   - its plunit_module_plain_helper/1 replaces plain_alpha.pl's when both are
%     consulted into one module
%     [tested: engine_modules:a_plain_pair_still_replaces_one_helpers_clauses; commit=WORKTREE]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

plunit_module_plain_answer_beta(X) :- plunit_module_plain_helper(X).

plunit_module_plain_helper(beta).
