---
topic: battery-ab-restores-from-the-index
date: 2026-09-19
status: current
pinned-at: 10da82e4ae59d44ddedef27c76d7d095c5517b27
sources:
  - ai-tmp/ai-classes-receipts/ai-ab-remedy-2.log
basis: measured
---

An A/B in a battery worktree that reverts files with `git checkout <rev> -- <file>`
moves the index to `<rev>` for those files. `git checkout -- .` afterwards restores
the working tree FROM THE INDEX, so the files stay reverted, and every later round
measures the same tree while its log says otherwise. A following
`git checkout --detach <sha>` carries them along as local modifications when the
files are identical between the two commits.

Measured 2026-09-19: round two of the counters A/B read both "halves" at the base
values (translate 326,473,095 and 326,417,810, the same tree twice), and the repairs
lanes run after it read every seat row at its old pin on a tree whose ledgers held the
new ones.

Restore between runs with `git checkout HEAD -- .` or `git reset --hard`, and print
`git status --short` into the log before each run so a dirty tree is visible in the
receipt.
