---
outline: [2, 3]
---

<!--
Purpose: publish the repository's PERFORMANCE.md as a site page without copying
  it.
Assumes: the page carries the source file's own name, the way the four beside it
  do, so any relative link the document writes to a sibling resolves here too.
Guarantees: the page includes the committed PERFORMANCE.md. That page separates
  the frozen corpus baseline from the current waiver measurements and names
  failed or skipped upstream operations before reporting comparisons
  [tested: test_every_site_include_resolves; commit=WORKTREE]
-->

<!--@include: ../../PERFORMANCE.md-->
