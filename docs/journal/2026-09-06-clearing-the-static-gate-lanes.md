# Clearing the static gate lanes after the query-planning and seam merges
Goal: take `prolog-static`, `dev-typed`, `cumulative-syntax`, `lib-surface`,
`pylint`, `refurb`, `bandit` and `evidence` from FAIL to green by repairing what
each one found, not by relaxing the lane.
Constraint: every finding is a real defect until shown otherwise; a lane may be
told a different rule only when the rule it holds is the wrong one, and then the
reason is written down here.

## 2026-09-06

Tried: the seven unbacked `evidence` tags. Five are `measured:` with no date and
came in with the query-planning merge; `git log -S` on each measurement's own
numbers names the commit that wrote it (`f8d70cd4` for the two foreign-match
counts, `0c9f4192` for the materialization load pair, `79c6b9f5` for the four
join families, `c38b5b0b` for the folding pair), all authored 2026-09-05, so
that is the date each tag now carries.

Rejected: rewriting the two `source:` tags as `[assumed:]`. Both name a real
upstream symbol and both had the URL that backs it sitting on the comment line
directly above the bracket, written by the same commit
(`acfa6e74`): CPython `graphlib.TopologicalSorter.done` and SWI's
`release_trie_ref` in `pl-trie.c`. The claim was sourced; only the grammar could
not see it, because `source_problems` reads the bracket body alone. Pulling the
URL inside the bracket is the shape `engine/metta/types.pl:121` and
`engine/metta/control.pl:462` already use.
