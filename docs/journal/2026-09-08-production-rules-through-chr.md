<!-- Purpose: record the subtraction measurement and CHR integration boundary. -->
# Production rules through CHR

Goal: establish the non-blocking single-occurrence remover and the integration
requirements for production rules over spaces.
Constraint: the 2026-09-08 landing decision limits this change to subtraction
tests, examples and documentation, plus a CHR module probe. Storage tokens,
their history and effect handlers are separate prerequisites. The base remains
f0d33dcad438f91556459ba43c80212d9b46b760.

## 2026-09-08

### Subtraction already supplies the operation

Read: `engine/spaces/foreign.pl:'subtract-atom'/3` and
`metta_host_remove_reported/3`, `engine/spaces/lifecycle.pl:native_retract_one/2`,
`extensions/python/metta/_space.py:Space.remove`, the existing subtraction
example and `test_space_removal.py`. The baseline removal suite passes 23
tests: `sh extensions/python/test.sh -n 0
tests/ch04_spaces_and_matching/test_space_removal.py`, exit 0.

Tried: run `tests/prolog/probes/subtraction_names.metta` on this engine
and upstream PeTTa at ae66fa8e41dcd5539d614706bd4e5cfb34f9608d. Commands,
with an absolute path to the same input and each engine's checkout as cwd:

```
swipl --stack_limit=8g -q -s engine/main.pl -- <input> silent extensions
swipl --stack_limit=8g -q -s src/main.pl -- <input> silent
```

Both exit 0. The input stores `(dup 1)` twice, asks each remover and counts
the survivors after each request.

| observation | this engine | upstream at the pin |
|---|---|---|
| initial answers | `(1 1)` | `(1 1)` |
| subtract one | `true` | `(subtract-atom &self (dup 1))` |
| survivors | `(1)` | `(1 1)` |
| unknown remover | `(remove-one &self (dup 1))` | same unreduced call |
| survivors | `(1)` | `(1 1)` |
| drain | `true` | `true` |
| survivors | `()` | `()` |
| subtract when absent | `false` | `(subtract-atom &self (dup 1))` |

Tried: the MeTTa subtraction door inside a Python transaction with two copies,
for an expression and a scalar. Both return True and leave one copy; a miss
returns False. Removing that last copy through `Space.remove`, then missing,
then raising `ValueError` restores the copy. These cases are retained as
generated histories in
`extensions/python/tests/ch04_spaces_and_matching/test_subtraction.py`.
The focused command with `HYPOTHESIS_PROFILE=ci` passes five tests. The example
command `sh test.sh
examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/10-subtract_atom.metta`
passes all sixteen assertions, including transactional absence and rollback.

Decided: use `subtract-atom`; adding `remove-one` would duplicate the existing
operation. Native absence does not wait for another writer. This says nothing
about lock-free execution or a foreign provider's synchronous callback latency.
The operation retains its existing lookup and removal costs. No runtime
implementation, builtin registration or generated surface changes.

Rejected: use the blocking `Space.take` path inside transactions.
`lib_thread:space_wait_/6` calls `metta_refuse_wait_in_transaction/1` before
waiting, because the transaction cannot observe the awaited external write.
Revisit only if the transaction model itself changes.

### CHR compilation and stores

The implementation references are SWI's [CHR module contract](https://www.swi-prolog.org/pldoc/man?section=chr-embedding)
and [operational semantics](https://www.swi-prolog.org/pldoc/man?section=chr-semantics).
The gcd rule is the shipped [Euclidean-remainder example](https://github.com/SWI-Prolog/packages-chr/blob/08f42a653c0d2d13e6d7841fa8889113384f904c/Examples/gcd.chr).
`git ls-remote https://github.com/SWI-Prolog/packages-chr.git
'refs/tags/V10.1.13*'` resolves the release to that commit.
The installed `chr_runtime.pl:find_chr_constraint/1` explicitly enumerates
every CHR module, while `current_chr_constraint/1` takes a module-qualified
constraint. Its [release source](https://github.com/SWI-Prolog/packages-chr/blob/08f42a653c0d2d13e6d7841fa8889113384f904c/chr_runtime.pl#L205-L223)
names the former deprecated.

Tried: `swipl -q -g main -t halt
tests/prolog/probes/probe_chr_exec_modules.pl`, SWI 10.1.13, exit 0.
The probe streams one CHR program into each actual execution module obtained
from `spaces:space_module/2`, using distinct source identifiers. It verifies
each result and releases both programs and spaces.

| checked observation | result |
|---|---|
| gcd store A, input 18, 24, 18 | `[gcd(6)]` |
| gcd store B, input 35, 14 | `[gcd(7)]` |
| deprecated enumerator | `[gcd(6),gcd(7)]` |
| same compiled program, different thread | empty constraint store |
| native `get-atoms` after CHR writes | `[]` |
| candidate whose blocker exists | no emission |
| remove blocker without inserting a scan | no emission |
| insert a fresh scan | one emission |
| insert another fresh scan | two emissions in total |
| clear both constraint stores | both empty |
| unload both source identifiers | neither gcd predicate remains |

Two rejected probe forms provided failing controls. Passing a qualified term
to `chr:find_chr_constraint/1` produced
`assertion_error(gcd_a,[],[gcd(6)])`. Qualifying the call instead produced
`assertion_error(gcd_a,[gcd(6),gcd(7)],[gcd(6)])`. The corrected form is
`chr:current_chr_constraint(Module:Pattern)`. The shipped probe deliberately
retains the deprecated enumerator's cross-module result as a checked witness.

Decided: CHR can compile in execution modules, but its constraints are an
execution index over the authoritative space. They are not native atoms and
are not shared across threads. Every selected head must carry the storage
token of its occurrence; equal values cannot stand in for occurrence identity.
The compiled program and the active constraint store have separate lifetimes.
The future implementation must retain neither after its owning space dies.

Rejected: a process-wide enumeration for negative guards, or assuming deletion
automatically wakes a suspended guard. Affected absence checks need explicit
invalidation. A fresh scan alone is insufficient: it changes CHR's propagation
history key and repeats an already-fired head tuple. A firing identity must
therefore survive such scans. Revisit these decisions only if the CHR runtime
changes the measured behavior.

### Decisions for the relaunch

The analogous mechanisms separate obligations: CHR selects distinct head
occurrences; Petri-net read arcs distinguish observation from consumption;
transaction conflict checks include negative reads; incremental queries need
deletion invalidation; linear-resource semantics preserves duplicates; fair
queues require persistent candidate identities; replay requires stable operation
identity. The module probe establishes the CHR behavior, not the other systems'
integration or performance.

- Compile a complete rule set into one owned CHR source unit, rather than
  loading separate CHR files into the same module. SWI's embedding contract
  forbids the latter. Stream compilation avoids scratch source files.
- Keep the native store authoritative. Copying a space into CHR and replacing
  its contents afterward would discard occurrence identity, bypass ordinary
  write hooks and complicate concurrent-write validation.
- Validate rule rows and all refusals before any firing writes. A host call is
  not a decidable absence pattern. Pure arithmetic guards needed by the usual
  gcd and primes examples require an explicit interpretation: the supplied
  four-part grammar has no positive-guard position and does not specify whether
  `put` evaluates terms. That grammar question remains open; no new clause or
  implicit evaluator is invented here.
- Kept and taken head instances need distinct tokens within each CHR match.
  Taken tokens must still be live, kept tokens must still be readable, and
  absence must hold at the atomic firing boundary. A prior match followed by
  value-based subtraction is insufficient when duplicate instances race.
- Refuse the specified keep-only self-reproducing rule by its name and remedy.
  This local syntactic refusal is not a termination proof for arbitrary rule
  sets, which may cycle through several rules or grow without bound.
- Separate candidate discovery from selection, so scheduling can call the
  shared `choose` effect. Source-order CHR execution by itself does not provide
  an explicit fair schedule. Candidate identity and propagation history must
  survive selection across steps. No private scheduler is implemented here.
- The commutation property must compare final multisets for fixed enabled
  firing instances, and separately test confluent rule sets under each
  schedule. Read arcs allow shared reads, but consumption of the other firing's
  kept or taken token conflicts. A put matching the other's absence pattern
  also conflicts. A conservative rule-pair test may reject more pairs; it must
  not claim to decide arbitrary program confluence. Token allocation and
  journal order need not be identical for commuting content changes.
- A foreign space must supply `subscribe` before rules are admitted, as the
  package contract requires. Subscription alone does not establish occurrence
  identity, atomic multi-head consumption, or event completeness. The token
  and transaction capabilities must also support the operation rather than
  silently falling back to value-based removal.

### Required interfaces, with their current evidence status

These are inputs for the relaunch. They are not callable implementations in
this landing. The [substrate design](2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md#25-the-substrate-settled-by-probes)
is the dated source for the storage, log and handler contracts;
the relaunch must replace each planned assumption with the actual merged export
and test contract.

| needed call | source/status at this cut | obligation |
|---|---|---|
| `spaces:space_module/2` | implemented | obtain the owning execution module |
| `spaces:stored_atom_of_ref/4` | planned by tokens; only `/3` exists | decode space, atom and storage token for a selected reference |
| `spaces:native_atom_clause/4` | planned by tokens; only `/3` exists | derive the token-bearing storage clause without copying its layout |
| `metta_actor/1` | planned by tokens | expand a local integer token's actor identity |
| `spaces:metta_remove_atom_reference/1` | implemented for source withdrawal | removes a selected reference through hooks, but a dead reference currently succeeds without a verdict; do not treat it as a successful firing after a race |
| `metta_add_token/4` | named by the op-log design; absent | replay existing tokens through the write funnel; argument order and published module require confirmation |
| `metta_journal_replay/2` | named by the op-log design; absent | replay committed operations idempotently |
| `metta_perform/3` | planned by handlers; absent | `metta_perform(choose, Operation, Reply)` selects an enabled candidate; `Operation` and `Reply` grammar require confirmation |
| `metta_with_handler/5` | handler design sketch; absent | scope one schedule through the same family as other choice sites |
| `metta_with_handlers/2` | named by the handlers brief; absent | host entry uses the same installed-handler scope |
| `seam:foreign_capability/2` | implemented; `tokens` is planned | require stable occurrence identity and subscriptions |
| `seam:segment_committed/1` | implemented | invalidate only after committed space changes |

Still unnamed in the substrate design: an exported enumerate-with-token door
for foreign rows, an atomic exact-token removal with an explicit success
verdict, and a journal append service that associates a firing with its kept,
taken and newly minted tokens. No predicate names or arities are fabricated
for these missing services. The relaunch must obtain their actual contracts
from the token/history deliveries or add them through the ordinary seam with
their own verification.

The op-log design's proposed shapes, with identifiers elided, are:

```
actor(Actor).
op(1041, add, Space, Atom).
op(1090, remove, Space, 1041).
op(1091, remove, Space, t(OtherActor, 77)).
op(1092, commit, [range(1090, 1092), instant(Time), origin(host(python))]).
```

The first two operations are `op/4`; the shown commit is `op/3`, despite the
same design calling the schema `op/4`. The firing-specific origin payload and
journal append interface are unspecified. This inconsistency must be resolved
by the history package. Token storage alone does not supply firing history.
History-enabled spaces also need the actual `(history Space keep)` contract,
including its rollback and replay behavior, before any rule claims journaling.

The handler spelling is `(with-handler choose fair Body)`; `depth` is its
documented sequential choice and `fair` its round-robin choice. The future
library's `(run-rules Space (schedule sequential))` and `(schedule fair)` must
translate into these handlers. The `choose` operation payload and safe-site
contract are still unimplemented. In particular, a saved continuation must not
resume after its CHR store, token validation or transaction lifetime has ended.

Open: the production library, token-journaled firings, schedule integration,
classic-program examples, rule refusals and commutation/confluence properties
belong to the explicitly deferred relaunch after tokens, history and handlers.
No production-rule operation is advertised as shipped.

### Probe evidence integration

Tried: the provenance updater refused the initial nested `probes/rules/`
placement with `OUTSIDE the evidence gate's globs, so nothing reads this
file's claims and nothing would ever resolve them; add its glob to
check_evidence_tags.SOURCES`. The existing checked diagnostic location is
`tests/prolog/probes/*.pl`, so the probe now uses that location. Its evidence
is a dated measurement of an explicitly run command; it is not advertised as
an automatically collected gate. The adjacent MeTTa file is only input, and
its outcomes belong to the measurement above.

### Verification repairs

Tried: the first committed-tree gate run passed examples, parity (312/312),
PeTTa conformance (154/156, two recorded rulings, no blocking differences),
library surface, both llms lanes, evidence and the provenance updater selftest.
It failed cumulative syntax with six findings: the added chapter-4 transaction
section used `empty`, `progn` and `transaction` before their introductions.
Decided: retain the spaces chapter's ten assertions and move all six transaction
assertions to `ch15-writing-transactions-and-worlds/06-single_occurrence_subtraction.metta`.
The introduction table remains unchanged; the corpus counts are recomputed.
`check_llms_names.source_counts()` reports 318 programs;
`len(example_parity.corpus())` reports 313 runnable examples. The origins tool,
run against `PeTTa-base` at 43705f5d9ff8958ffe7f0aa6777fb8477f2401f2 with
`--write`, reports 143 derived and 193 original programs, 336 including fixtures.

Tried: `npm exec --prefix website -- vitepress build website` failed with
`[vitepress] 1 dead link(s) found.` The dead link was
`./../../docs/journal/2026-09-08-the-mork-pin-advanced` in
`extensions/mork/index.md`. A separate pristine worktree at the stated cut,
using the same installed dependencies and browser kit, failed identically.
`git blame` attributes the link to 6da518669c by MesTTo. The README is included
into the site, which resolves its relative journal path outside the site tree.
Decided: point that link to the repository journal at the cut. This preserves
the source destination in both renderers and repairs the required guide build.

The engine suite passed 2,475 tests and 1,501 sub-tests across 89 unit summaries.
The spaces and transaction directories passed 575 Python tests with
`HYPOTHESIS_PROFILE=ci`; the MORK seat ran all 25 tests and its three
missing-artifact controls. No runtime files changed after these runs.

The provenance updater also rejected a proposed new guide-header pin:
`website/guide/spaces.md: 1 pin(s) OUTSIDE the evidence gate's globs`.
The guide keeps its existing header; this journal and the delivery receipt
record the new build. The final provenance commit covers only the four
test and probe files in the scanner's existing source set.
