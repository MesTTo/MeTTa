% Purpose: the control for alpha.pl -- the SAME library with no module
%   declaration, which is how every shipped library's Prolog half was written
%   before 2026-09-08. Consulted beside plain_beta.pl it proves the collision
%   the module boundary removes, so the test that asserts the boundary works is
%   not vacuous.
% Guarantees:
%   - consulted into one module beside plain_beta.pl, exactly one
%     plunit_module_plain_helper/1 survives, and it is the second file's
%     [tested: engine_modules:a_plain_pair_still_replaces_one_helpers_clauses; commit=WORKTREE]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

plunit_module_plain_answer_alpha(X) :- plunit_module_plain_helper(X).

plunit_module_plain_helper(alpha).
