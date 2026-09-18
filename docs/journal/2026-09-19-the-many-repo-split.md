# The many-repo split, and the branches it has to absorb first
Goal: the tree is published as one repo per component, engine, lib, the four seats, the two example sets and the integration distributions, held together for work as one monorepo of submodules; and no committed work is stranded by the split.
Constraint: a split that runs before an unmerged branch lands strands that branch's work in a repo nobody will re-split. Three branches are outstanding against `petta` (feat/a-standard-library-for-a-language, 108 commits; fix/audit-acceptance-tests-and-repairs, 40; feat/door-bodies-compose-the-primitive-doors, 16), so they merge first. Each component's history is preserved rather than restarted, because this tree's evidence is its history: every pin cites the commit that measured it.
Plan:
1. Merge the three outstanding branches into `petta`, oldest first, each gated before the next. Established by the gate.
2. Split each component with its own history and rewrite the monorepo to carry them as submodules. Established by comparing the split repo's tree against the monorepo's subtree at the same commit.
3. The two example sets: the .metta corpus is one repo, and the Python twins are a second whose chapters sit at its root and which carries the corpus as a submodule (user, 2026-09-19).

 ## 2026-09-19
Found: the standard-library branch conflicts on 52 files, of which 31 are twins whose hunks hold two divergent cost chains from one ancestor: both branches re-pinned the same twins, the standard-library line tripling several of them by deriving their work in MeTTa (regex_lib 28,947 to 108,199 against the classes line's 35,787). Neither number is the merged tree's.
Decided: the twin conflicts resolve mechanically (ai-tmp/ai_resolve_twin_conflicts.py): every paragraph of both chains is kept, each line contiguous rather than date-interleaved because their numbers do not follow each other, the other branch's line first and this tree's last, and this tree's BUDGET stands as the placeholder the corpus re-pin replaces. The 21 remaining conflicts are resolved by hand.
