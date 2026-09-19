# Package lifecycle library

`lib/lib_package` implements the default package interpreter. The engine reads
only the current source's package argument record, performs requirements first,
dispatches `perform` by unification, and enforces normalization's reads ceiling
and inference budget. A required library can replace `package-load`. The
default interpreter owns coverage, catalogs, native contracts, setup, boot,
receipts, locks and retirement.

The engine publishes the prelude's evaluator, dispatch, source-locator and
activation services through `seam:kind/2`; the source reader exports its indexed
package-row query. The library-surface check finds no unpublished engine calls,
the engine layering check passes, and all 13 `metta_published_surface` and
`engine_layering` tests pass. After consolidating the policy module, the
library-surface command exits 0: 78 meaning comparisons pass, 2,466 clauses
contain no unpublished engine calls, and all four planted reaches are seen.

The contract is laws 6–13 and “the package is an argument record and the engine
knows four things” in
`docs/journal/2026-09-09-packages-are-equations.md`. Engine package-section
ownership resolved the earlier implementation block. `agenticmind.json` is
held by its owner; this record supplies the construction and evidence for
approach a31.2 without editing that file.

## Construction and evidence

The existence claim is discharged through the ordinary import, replacement,
withdrawal and setup doors. Counterexamples exercise validation before effects,
selection, source ownership, failed activation and failed cleanup. The MeTTa
fixture `lib/lib_package/fixtures/policy.metta` predicts selection, receipt
multiplicity and reverse retirement; its tests cover four claimant combinations
and 36 lifecycle length/failure-position combinations. The mutation runner
requires a disabling mutation for every library test and refuses nonexistent
witnesses. Whole-gate attribution requires identical unrelated source bytes,
Git identities and build configuration in the candidate and control.

The latest focused run passed all 22 `packages` tests and 69 `lib_package`
tests, followed by all 78 disabling mutations. The consolidated module's
result is `ai-tmp/ai-package-consolidation-tests.log`. Its first surface
invocation used the wrong working directory and raised
`source_sink '../conformance/petta/lib/lib_he.metta' does not exist`;
rerunning from `tests/prolog` passed. The shipped
`07-scopes_and_captured_calls.metta` example also passed. The earlier
no-autoload lane failed; its attribution and the final whole comparison remain
open. Its output is `ai-tmp/ai-package-focused-88-and-noautoload.log`.

## Law accounting

| Law | Built behavior | Executable evidence |
|---|---|---|
| 6 | Claimed backings are selected by head in source order. Unclaimed rows are skipped only when equations or selected backings cover every named head. Ground, variable and segment signatures derive arities from native or ordinary `package-contract` rows. Arrow disagreement and same-arity tier collisions refuse before native directives. Unused alternatives need not exist. Partial overlap installs only fresh heads. | `uncovered_backing_refuses_by_head`, `unclaimed_backing_is_skipped_when_equations_cover_it`, `first_claimed_backing_wins_and_alternative_remains_visible`, `partially_overlapping_backings_only_merge_their_unselected_heads`, the variable/segment/export cases, `contracts_refuse_before_native_directives`, both equation/native arity cases and `ordinary_contract_equations_describe_an_attached_claimant`. |
| 7 | The seam compiles the claimant; execution carries the source home. Native registration belongs to that home, including explicit imports into `&self`. Returned spaces merge selected heads through FROM. Deferred repairs run before the next source runnable can call a newly backed wrapper. | `backing_lives_and_retires_in_its_home`, `backing_in_self_retires_registration_without_unloading_the_host`, `backing_answer_spaces_merge_through_from`, `backing_repairs_preceding_equations_before_the_next_runnable`, and the shipped scopes example. |
| 8 | Only `setup!` prepares, transitively. Ordered normalized setup rows fingerprint the receipt, preserving duplicates. Missing receipts, changed rows and missing artifacts rerun setup. A directory mutex plus OS write lock excludes concurrent publication. Successful results publish atomically. Boot runs in source order; every answer is owned and released in reverse on withdrawal, replacement, space release or failure. Every release is attempted. Lazy and background admission refuse boot before submission. | The receipt reuse/change/duplicate/artifact/failure cases; `setup_holds_an_os_lock_until_its_claimant_finishes` uses a competing process; the boot order, multiplicity, failure, replacement and 36-case lifecycle sweep; `from_refuses_boot_before_lazy_or_background_submission`. |
| 9 | Import resolves existing artifacts and pins without running setup or fetching. Missing requirements/artifacts name `setup!`. Explicit setup may use the existing pinned Git importer. Native loading avoids the loader path that may invoke a compiler child. | `import_never_runs_setup`, `missing_artifact_names_setup_as_the_remedy`, `offline_git_requires_a_lock`, `setup_pins_git_and_a_fresh_import_spawns_nothing`. The last case prepares a local Git repository, then imports in a fresh process with process creation disabled. |
| 10 | Names query catalogs, relative paths resolve against the requiring source, and Git requirements require full pins. Requirements load before local activation through existing source single-flight. Equal-digest aliases collapse; differing identities refuse. Conflicting pins name both requirers. Pending dependency edges remain visible outside transactions so a concurrent cycle is detected before waiting on another source flight. | Relative ordering, cycle, pending-edge, catalog insertion/space, equal/different alias and conflicting-pin tests. |
| 11 | `(performed row answer)` records every actual answer at home. Setup persists these rows. The top package's lock records transitive resolved requirements, including Git pins. | Backing receipt, multiple-answer, setup receipt, transitive lock and fresh-process pinned Git tests; the boundary diagnostic observes backing and boot receipts. |
| 12 | Source withdrawal removes native MeTTa registrations and releases owned answers. Host clauses remain loaded. Persistent setup receipts remain on disk. A failed replacement restores the previous source and its handles; a failed parent preserves a successfully loaded dependency. | Both home/`&self` withdrawal cases, both replacement cases, `a_failed_parent_preserves_a_successful_dependency`, `failure_with_a_failed_release_still_withdraws_the_source`, `space_release_closes_its_package_handles`. |
| 13 | The MeTTa/engine half is built: an application can load its package in `&self`; every normalized local boot row is checked for a claimant and against available derived arrow declarations before any local effect, then handles follow law 8. | `all_boot_rows_are_validated_before_any_effect`, `boot_types_are_checked_before_effects`, computed-row multiplicity and lifecycle cases. The Python half is not built; see below. |

Law 13's Python half requires edits to
`extensions/python/metta/manifest.py`, the `metta.boot` implementation,
the held door marks in `extensions/python/metta/doors/`, and their generated
face. It must derive a bootable vocabulary and `boot.metta` from door marks,
bind connection and serve-policy rows, normalize the serve guard, and connect
Python context exit/failure to reverse handle closure. Those changes were
explicitly excluded when the task assigned this library and engine section.
The existing Python manifest has not been presented as implementing these laws.

## Bootstrap and home ownership

The isolated Python reproduction was:

```sh
cd extensions/python
python -m pytest tests/ch08_data/test_file_lib.py::test_normalize_agrees_with_posixpath \
  -q -p no:cacheprovider -p no:randomly
```

Before the bootstrap repair it failed as item 1 of 1:

```text
EngineError: package: package_backing `['collections-expression']' does not exist
(unclaimed([prolog,[library,_support/collections_data.pl],[collections-expression]],available_claims([])))
```

The cached ready flag was asserted before importing `lib_import`. Coverage
could therefore run before the default claim existed; source rollback could
also remove a claim while leaving the flag. `available_claims([])` diagnosed
an unpopulated registry, not an unsupported shipped backing. Readiness now
comes from the actual default seam equation. Installation has no source owner
and no `lib_import` bootstrap dependency. The isolated Python case then passed
(`1 passed in 5.71s`).
`default_claim_recovers_after_withdrawal_and_failed_activation` removes the
claim, fails an import, then checks native execution and the restored claim's
absence from every source journal. Its mutation reinstates the stale ready
flag behavior.

Evaluating the whole call in the library home loses the seam claimant. The
engine instead compiles in the seam and executes with the home in force.
Native clauses have process lifetime; native MeTTa registrations are local
source artifacts. Three older package cases used direct unqualified Prolog
calls, which required global host registration. They now call their public
MeTTa heads and inspect the explicit importing module. This follows law 7.

The whole comparison found an additional namespace leak:

```text
math-float with 1 arguments is one of Prolog's protected core predicates,
which no space can redefine, &self included.
```

`load_files(Module:File, ...)` imported every module export, including names
the backing had not selected. The native loader now uses a process-owned
artifact namespace and `imports([])`, then imports only selected predicate
indicators into the home. Plain Prolog sources receive a namespace derived
from their canonical path; already-loaded sources reuse SWI's source context.
`unselected_native_exports_leave_equation_heads_free` failed before this fix
and now passes for both module and plain sources. The math example also exits
0 with `METTA_VERIFY_SPECIALIZATIONS=1`.

Two further law 6 counterexamples now pass. A declared export boundary refuses
private names instead of falling back to inferred clause heads. Partial-overlap
selection records the unused heads as available while performing the fresh
heads. The selection partition retains O(h log h) cost. Both refusals/property
observations have disabling mutations.

A variable signature for a non-Prolog claimant formerly unified with the empty
signature clause before its contract was read. The empty case now requires an
actual empty list. The ordinary contract test includes a private artifact head
and proves that only declared heads merge. Contract equations return computed
values through `%Undefined%`; literal lists of declarations use `quote`.
`a_claimed_backing_cannot_succeed_without_installing_its_heads` proves that a
claimant returning `true` without publishing its named head refuses with
`existence_error(package_export, 'lp-missing-export')` and rolls back the source.

The policy lives in one Prolog module. Included units one directory below it
escaped the boot's `lib/*/*.pl` freshness inventory: an already-written QLF
kept running the old contract code. Moving those units beside the umbrella
made freshness work, but the library-surface gate loaded them independently
and reported weak-import overrides. Included clauses had also escaped that
gate's source attribution; the full scan exposed six unpublished engine calls.
Consolidating the units into `lib_package.pl` gives compilation and surface
checking the same source boundary. Their six engine services are published
through the existing seam.

Law 6 also supersedes the old
`a_backing_no_claimant_answers_installs_nothing` test: accepting an uncovered
head contradicted its required named refusal. The replacement is
`an_uncovered_backing_without_a_claimant_refuses`. Covered unclaimed
alternatives still load. An unreduced computed backing also refuses by name.

## Decisions and costs

Inspecting unused native alternatives before selection wrongly rejected an
absent artifact that would never be loaded. Inspection now follows selection
for ground signatures. Variable and segment signatures must inspect their
artifact to discover the heads they name. Native inspection reads Prolog terms
without executing directives. Module exports and `metta_export` declarations
bound the exported arities; explicit MeTTa input arities add one result slot.
Each declared arrow matches its own artifact arity, and a MeTTa equation at a
different arity may coexist with the native head.

The old writesState ceiling admitted mutations. The revised ceiling admits
nondeterministic reads and checks every source-planned operation, including
operations inside `match` bodies. Complete answer collection preserves
normalization multiplicity and applies the inference budget to the whole row.

An explicit drain of queued source repairs was initially added for wrappers
compiled before a backing arrived. Moving every registration through the
existing home registration door made that drain redundant: its disabling
mutation still passed both the wrapper test and all eight assertions in the
shipped scope example. The drain was removed; the home-registration mutation
now tests the wrapper's actual dependency.

The source reader retains the native indexed lookup for the reserved package
head followed by the source-ownership join. No load-path walk or decode of
unrelated stored atoms was added. Selection uses an assoc over named heads;
cycle detection shares a visited assoc across its frontier. Acquired handles
and pending dependency edges deliberately survive Prolog transaction rollback:
external resources still need cleanup and concurrent flights must see edges
before waiting.

The latest memory-scale run completed without a regression line, after the
claim bootstrap, native namespace and published-service repairs:

```text
load-metta: inferences [1147, 3847, 30847, 300847]; fit=linear expected=linear nrms=0.0000 noise=+/-0
load-fast: inferences [2371, 7771, 61771, 601771]; fit=linear expected=linear nrms=0.0000 noise=+/-0
```

These are 83 inferences above each 10,000-atom pin, within allowances 15,039
and 30,085. `ai-tmp/ai-package-boundary-memory-surface-final.log` records these
values, all required boundary observations, 13 passing publication/layering
tests and the llms check with zero findings.

## Prior art

[Cargo fingerprints](https://github.com/rust-lang/cargo/blob/8814ead110e36ed8fdcf1fdd4009baf82bd78523/src/compiler/fingerprint/mod.rs)
separate changed inputs, missing outputs and publication after success. Setup
tests exercise those conditions independently; the receipt fingerprint retains
source order and duplicate rows.

[SWI open/4](https://www.swi-prolog.org/pldoc/doc_for?object=open/4) supplies
blocking fcntl locks. The existing `lib_csv` pattern keeps the lock inode while
publishing separately. `lib_file:metta_staged_publish/2` removes abandoned
stages. `owned_resources:with_outcome_cleanup/3` preserves the primary failure
during compensation. No new dependency was introduced.

## Verification still being completed

The mutation runner passed all 78 witnesses: 69 library cases and seven changed
package cases, with additional mutations for partial-overlap availability and
variable contract selection. Each fresh-process control exited 0 and each disabling
mutation exited 1. The focused run also passes all 91 cases without choicepoint
warnings, and jscpd reports zero clones. The complete result is
`ai-tmp/ai-package-mutations-78.log`.
Whole-gate results from batteries without their own Git identity are invalid.
An earlier control also retained a stale detached HEAD and an empty
`lib_package` directory after an orphan QLF prevented removal; it cannot
supply the required comparison. Batteries 11 and 12 now run plain `sh check.sh`
from a frozen candidate/control pair. Both detached HEADs and all eight
component identities were aligned to the source revisions without changing
working bytes. The source manifest `ai-tmp/ai-package-gate-pair.json` records
3,079 identical source files, 16 package-change paths and no unrelated
differences. The common superproject revision is
`9f2a240cc329397b1c17edf8c3521bc0c5440833`.

The latest no-autoload run reports missing SWI `library(unicode)`,
`library(archive)` and `library(yaml)`, plus the class-dispatch example error:

```text
MeTTa test failed: ['area-of',[area,['Square',3]]] does not match ['area-of',9]
```

The build also reports:

```text
error: failed to get `mork` as a dependency of package `mork_ffi`
failed to read `.../ai-tmp/MORK/kernel/Cargo.toml`
```

The class-dispatch example also fails in the source-matched control with the
same expected/actual values (`ai-package-class-control.log` in battery 12).
The other failures require comparison; they are not labeled pre-existing
merely because they concern another component. No whole-gate completion is
claimed.

The comparison also exposed consumers of the old global native imports.
`lib_thread_scope.plt` calls native predicates without a Prolog module import;
Python `_binding/operations.pl` calls `metta_async_future_new/2` and its helper
family unqualified. These helpers are not the named MeTTa backing heads in
`lib_thread.metta`. Their consumers must name `lib_thread` now that a package
publishes selected heads in its home. The native-shadow regression remains
open: `engine_modules:removing_a_local_shadow_restores_a_library_export` raises
`metta_builtin_redefinition('string-upper',1,'&plunit_module_library_shadow')`.
The shadow-repair code treats a local native registration as a local equation
and leaves its static import attached. The affected engine and consumer files
are outside the assigned package section; ownership or repairs were requested.

The generated Python fn face now includes `setup!` and `package-prolog`.
The Node wire-catalog test initially failed with
`Error [ERR_MODULE_NOT_FOUND]: Cannot find module '.../extensions/node/node_modules/esbuild/lib/main.js'`.
In battery 13, `npm ci` installed the dependencies declared by the Node seat,
then the unchanged test passed (`1 passed in 0.15s`). This failure was an absent
build dependency, not a change to the wire catalog.
The complete random-library suite plus the atom-reclamation case pass after
native export isolation (`36 passed in 4.77s`, battery 13). Their earlier
whole-run failures were checked individually rather than hidden by an already
failing Python lane.

## Repaired integration and tooling failures

The implementation corrected these observed errors:

```text
duplicate_builtin_implementation_key('get-property'/1)
existence_error(procedure,metta_engine:replacing_previous_load_/4)
existence_error(procedure,metta_engine:package_argument_type/2)
forall/2: Unknown procedure: filereader:package_loader_source/1
Unknown procedure: lib_package:debug/3
plunit_packages:'unit body'/2: Unknown procedure: plunit_packages:packages_undepended_double/2
```

The fixes are an arity-specific builtin facet, explicit meta-call modules,
an explicit debug import and public MeTTa observations of locally registered
heads. Other intermediate failures and exact unsuccessful tool invocations
remain in the retained integration and mutation logs under `ai-tmp`.
