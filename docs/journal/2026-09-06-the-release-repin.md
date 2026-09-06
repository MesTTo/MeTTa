# The release re-pin
Goal: bring every committed benchmark pin back onto the tree that ships as
pymetta 0.8.0, with each move attributed to the change that caused it, so the
release gate is green for a reason rather than by a widened band.
Constraint: inferences decide and are deterministic; instruction counts are the
minimum of three to five samples with the load recorded; a baseline row is
append-only, so a resolved row is re-pinned with prose naming its number,
mechanism, commit and date, and a row nothing attributes says so in those
words rather than being pinned quietly.

## 2026-09-06

Tried: `node-dist` on a checkout with no `extensions/node/ai-tmp/`. It fails
with `ENOENT: no such file or directory, mkdtemp
'<checkout>/extensions/node/ai-tmp/consumer-XXXXXX'` from
`tools/dist-consumer.mjs:53`. The directory is gitignored, so it exists only
where somebody has already put a scratch file in it: the lane was green in the
main checkout and red in every fresh clone and in CI, and the lane's own
premise was the defect rather than anything in `dist/`.
Decided: create the directory before `mkdtempSync`, which is the line the
seat's two other repository-local scratch sites already carry
(`test/coverage.test.ts` `packageTree`, `test/coverage-gaps.test.ts`'s
manifest case). Reproduced red, then green from the same directory-free state.

Tried: pinning instruction counts from the agent worktree this pass runs in.
Rejected: the boot rows are checkout-path sensitive, which
`engine/bench-baseline.json:measurement.checkout_location` already measures at
2.51% between a 72-character worktree path and the 30-character repository
root, and `ai-todo.md` prices for the C seat at about 0.045% per character.
This worktree sits at 71 characters against the main checkout's 29, so a boot
pin taken here would describe this worktree and read as a 2% improvement
wherever the gate actually runs. Every number below was therefore measured in
a clone at `/home/user/Dev/PyPeTTa1/repin`, which is character-for-character
as long as the main checkout, provisioned with the same native artifacts and a
freshly warmed `.qlf` set.

Measured: the non-boot rows are not path sensitive, which is the control that
says only the boot rows need that care. Same commit, same command, worktree
against the same-length clone: engine `parse` instructions 112,721,690 against
112,720,140 (0.0014%), `parse-prolog` 1,798,025,509 against 1,798,038,432
(0.0007%), and every inference count identical to the last digit. The
instruction window is opened around the measured region through perf's control
descriptors, so a non-boot case never carries the boot whose cost the path
length moves.
