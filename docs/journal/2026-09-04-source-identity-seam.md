# A record made during a compile needs the source it belongs to
Goal: give anything that files a record alongside a compile - a diagnostic, a
warning, a coverage row - the identity and revision of the source that produced
it, so a reload of that source replaces the old set instead of accumulating a
second one.
Constraint: the loader must not learn the name of a consumer. Whatever it
answers has to agree with the journal that actually withdraws the record, or a
record names one file and dies with another.

## 2026-09-04
Asked for: `current_typecheck_source(-SourceKey, -Revision)` exported from
`engine/filereader.pl`, reading the active non-pin `source_load_digest/3` during
compilation and falling back to `interactive(Module)` outside a load.

Rejected: the name. `engine/filereader.pl` reads MeTTa source; a predicate there
called `current_typecheck_source` writes one consumer into the loader and the
next consumer either reuses a misleading name or adds a second seam beside it.
Shipped as `current_source_identity/2`.

Rejected: `interactive(Module)` plus a definition digest. There is no
definition-level revision in the engine to read. Inventing a counter is
bookkeeping nothing else needs, and a fabricated revision is worse than none
because a caller cannot tell it apart from a real one. Outside every load the
answer is `immediate` / `none`, which are `support_recompile_pending/3`'s and
`journal_load_now/1`'s existing words for the same absence. A caller that needs
replace-on-change for an interactive definition has to key it on the definition;
nothing about a source can supply it.

Rejected: reading `source_load_digest/3` alone, which is what was asked for. The
row is written at the load's own read and retracted in the load's cleanup, so it
answers only while the file is compiling. An ownership pin carries a CLOSED
load - that is what a pin is for, a deferred equation compiled when something
first calls it, possibly inside an unrelated import - and for those the digest
lives in the published `metta_source_load/4` row instead. Control: replacing the
second branch with `fail` turns
`filereader_source_identity:a_pinned_owner_names_its_own_file_after_that_load_closed`
and `..:the_identity_and_the_journal_charge_name_the_same_load` red and leaves
the other two green, so the branch carries the pinned case and only it.

Decided: the charge is `record_source_assertion/1`'s, pin unwrapped, reusing
`journal_load_now/1` rather than spelling the policy a fourth time. That is the
load-bearing part. A record journalled through `record_source_assertion/1` is
withdrawn when the OWNING file reloads, so an identity that named the forcing
file would print a path that outlives the record.
`the_identity_and_the_journal_charge_name_the_same_load` pins the agreement.

Open: the withdrawal half needs no new mechanism at all. A record asserted
during a load and journalled with `record_source_assertion/1` is already
withdrawn transactionally by reload and by rollback, which is stronger than
comparing a stored key, and it needs no key to stay stable. The identity is for
NAMING the source in a message and for answering "what is on file for X" from
outside. A consumer that uses the identity as its withdrawal key instead of the
journal has rebuilt the weaker half by hand.
