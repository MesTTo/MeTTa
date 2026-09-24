"""Purpose: check that the evidence tags in obligation headers are backed by something.

A tested claim asserts that running what it names demonstrates the guarantee
above it, and thirteen of them named tests that had never existed in the tree's
history, including all four cited by the engine pool's Guarantees block. A
claim with nothing behind it is indistinguishable from the many that are real,
which is what makes it corrosive rather than untidy.

Guarantees: nested distribution modules, native library and suite support,
CMake recipes, vendor configuration headers and nested host reproductions participate in
the same evidence and pin checks as their callers
[tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py,
tests/checks/check_evidence_sites_selftest.py].

Reads files and the engine-free door grammar. Structured row assumptions,
guarantees, local refusals and evidence are checked through doorgen's contract
reader [tested: test_contract_checks_detect_signature_and_evidence_drift,
test_contract_checks_refuse_missing_coverage_and_unbacked_refusals;
commit=b615b5a33b43252ef9826e5387da7c9bd7f6b543].

Guarantees: MeTTa data fixtures carry checked citations and resolvable provenance
[tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py].

What each tag has to carry, and why only this much:

  tested    every name in it exists as a test, a plunit unit, a named check,
            a shell suite, an example, or a path in the tree; that target can
            report a failure; and a runner executes it
  measured  a YYYY-MM-DD date, so the claim can go stale
  source    a date or a reference
  any kind  a time after its date is the whole time `date -Iseconds` prints,
            YYYY-MM-DDTHH:MM:SS+HH:MM, the stamp every tag carries since the
            obligation-header rule of RULE_INSTANT; a tag from before it
            carries the date alone and is read as it always was
  written   on a line written since RULE_INSTANT, in any file git sees in the
  since     checkout or its components: a tag carries that whole stamp, and a
  the rule  pin says neither `commit=WORKTREE` nor a commit of its own repository

The last row is dated by line, as SonarQube dates its new code: a line is
written since the rule when `git blame -M -C` over the working tree gives it a
committer time at or after RULE_INSTANT, or none because it is not committed,
and every line of an untracked file is [source 2026-09-25T01:02:21+10:00:
https://docs.sonarsource.com/sonarqube-server/9.9/project-administration/defining-new-code,
lines "changed since the start date of the new code period are marked" by SCM
blame]. Blame follows a move where a diff's added lines do not: 0dcf53ea8
rewrote engine/bench-baseline.json in sorted key order and moved two tags
written at 23:06, before the rule, which its added lines and plain blame date
to 23:52 and `git blame -M` to 23:06 [measured 2026-09-25T01:16:56+10:00: lines
66 and 141, switch_to_build9_host_repin_comment]. A line from before the rule
is legacy and stays as it is until its evidence runs again, so a legacy
`commit=WORKTREE` is counted and never refused, RELEASE=1 or not.

Existence alone was the whole check until 2026-08-18, and it is the weakest of
the three. engine/translator.pl cited a tests/performance/reduce_dispatch.pl for
its operator-table guarantee: the file was real, its only failure path was a
cross-run hash comparison that said nothing about operator tables, and no
runner had ever opened it. So a tested claim now has to survive three
questions, not one. That citation names translator_operator_dispatch now and
the eight scripts under tests/performance/ are gone, each one a measurement
that printed a number and asserted nothing.

Can it fail? Language by language, because the answer is written differently
in each:

  .plt, .pl   a plunit test/1,2 clause, or the `main` of a script started by
              `:- initialization(main, main)`, which SWI exits 1 for when main
              fails; or, for a file with neither, one that loads it and has
              one, which is how surface_walk.pl's checks run under
              static_checks.pl.
  .py         a `def test*` pytest will collect, or, for a gate script cited
              whole, an exit path that can be nonzero. NOT the presence of an
              `assert`: that rule is SonarSource's S2699 and its documented
              false positive is the test that proves a call does not raise
              [source: https://github.com/openrewrite/rewrite-testing-
              frameworks/issues/121]. Both of this tree's two cases are that
              one, test_strict_accepts_a_pruned_branch_and_every_reduction and
              test_optional_surfaces_load_only_when_requested, so the rule
              would have been wrong twice and right never.
  .metta      a (test ...), (test-no-answer ...) or (assert* ...) form, which
              test/3 throws metta_test_failed for [source: engine/metta.pl:2283].
  .sh         an exit path that can be nonzero.
  .ts .mjs    a `test`, `it` or `describe` node --test registers, or, for a
  .js         PROGRAM rather than a suite, an exit status it sets itself.
  .c          a `static void test_<name>(...)` main() calls. A C suite has no
              collector: main() IS the runner, so a case it does not call is
              dead the way an uncollected pytest function is.

The last two name themselves in PROSE as well as in identifiers -- a node case
IS its sentence, and a C case carries a CASE("...") that the CHECK macro prints
beside a failure -- so a claim points at one by QUOTING it, and the quotes are
the delimiters. Everything IDENTIFIER rejected used to be answered with "this
token names nothing and nothing is wrong with that", which is right for the
prose a claim is written in and wrong for a name that is a sentence: a correct
citation of a case and a citation of one that had been renamed were accepted
for the same reason, that neither was read.

Does anything run it? evidence_runners.py answers that from the runners
themselves. A file only check.sh's REPORT tier reaches is named as such, since
a forgiven failure cannot back a claim.

The measured and source rules stop at the date deliberately. In this tree the
NUMBER a measurement claims almost always sits in the sentence the tag stamps,
not inside the brackets, and reading it out of surrounding prose would flag
correct headers far more often than wrong ones. The date is the part that is
unambiguous, and ageing is what the tag is for.

`assumed` is unchecked on purpose. It is the honest tag for a claim nobody has
verified, and demanding evidence for it would push authors back to stating
unverified claims in the same voice as measured facts.
Assumes:
  - evidence_runners.executed reports REPORT for a file only a forgiven lane
    runs [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
Guarantees:
  - a tested claim naming something absent fails the run, and a claim spanning
    several comment lines is read as one claim
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a tested claim naming a target that cannot fail, that no runner executes,
    or that only a REPORT lane runs, fails the run
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - the four command shapes a claim may name instead of a test are each
    resolved and each falsified: a check.sh lane, an npm script, a `make -C
    <seat> <target>`, and a `sh <script>` with environment assignments in
    front of it [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a path in a claim resolves from the repository root, from beside the
    citing file, and from the citing file's SEAT root, and one that resolves
    under none of the three is reported
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - reading a file's tags and requiring its Guarantees lines to carry one are
    separate scopes, so a class can clear the first without clearing the
    second; SOURCES is the first and GUARANTEE_SOURCES the second
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a name written as a SENTENCE resolves when it is quoted, against every
    suite in the tree rather than one directory's, and a quoted name the tree
    does not declare is reported rather than dropped in silence
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a C suite's two names for one case both resolve, the `test_` function and
    the `CASE(...)` prose inside it, and a CASE in a function main() never
    calls is as unbacked as the function
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a tag offering a path under the repository's scratch directory is
    reported, and the directory is read from the runner that allocates it, so
    a runner that stops declaring it is reported too
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - MORK's Python benchmark selftest carries checked evidence, and its pins
    are placed as prose or as code by its grammar
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - Python package claims remain checked after sources move into subpackages
    [tested: test_nested_package_evidence_rejects_a_missing_test; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e]
  - every walk reads the files git tracks or has staged, and the rule-era
    check the untracked files git does not ignore as well, so build output
    under an ignored directory is never read as a claim of the tree
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - nested example fixtures, C-embedded Prolog fixtures, root build hooks and
    component shell tests carry checked claims, and their comment pins are
    placed as prose and their code's as code
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py,
    tests/checks/check_evidence_sites_selftest.py]
  - a TOML configuration's pins are placed by the TOML parser, so a key or a
    value is never read as one
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - a tag's time is read whole in every kind: a `date -Iseconds` stamp is one
    token, so a tested tag's names are the words after it, and a time that is
    not a whole stamp is reported, an assumed tag's included
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - on a line written since RULE_INSTANT, in any file git sees in the checkout
    or a component, a tag without a whole stamp, a `commit=WORKTREE`, and a pin
    naming a commit of its own repository are each reported, and a pin naming
    another repository's commit is not; the same line before the instant is
    legacy and passes, a `commit=WORKTREE` there counted and never refused
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a line is dated by where blame follows it, so a legacy tag moved within
    its file, moved into another file, or carried by its file's rename after
    the instant stays legacy, while an uncommitted edit and every line of an
    untracked file are written since
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a commit dated after the instant is found beneath one backdated before it,
    and the lines it wrote are dated to it
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
  - a placeholder in a tracked file no glob reaches is reported, in the
    checkout and in its components
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_selftest.py]
Fails when:
  - asked whether a target tests the PARTICULAR guarantee it is cited for.
    Every rule here is necessary and none is sufficient: a script that runs
    and can fail still proves nothing if its failure does not depend on the
    claim. reduce_dispatch.pl is exactly that shape and only the runner
    question caught it.
  - asked whether the PREDICATE a claim names is the one that runs. That is a
    reachability question and Prolog does not answer it to a reader: goals
    live in a test's options and in begin_tests', a multifile hook is called
    by the engine, and assertz installs clauses at run time. A call graph
    tried here rejected 25 predicates that are all called. The file is the
    unit, and SWI answers the finer question with prolog_walk_code/1 against a
    loaded database, which static_checks.pl already does.
  - reading a plunit test that does not start in column 1, or a Python name
    bound by anything but a def. Both are how this tree is written and neither
    is how Prolog or Python must be written.
  - a commit's committer date is not when it was written. A line is dated by
    the committer time blame gives it, so a commit backdated before the
    instant makes its own lines legacy; one that is the rule's to hold is
    hidden only by backdating it.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import re
import subprocess
import sys
from bisect import bisect_left
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime
from functools import cache
from pathlib import Path

from evidence_runners import (
    LANE_PREFIX,
    ROOT,
    Execution,
    executed,
    gate_scripts,
    owned,
    prolog_loads,
    tracked,
)

#: Where BOTH obligations apply: a tag that names something must be backed,
#: and a Guarantees line must carry a tag at all. The second is the stricter
#: one and is the reason this list is smaller than SOURCES; CLAIM_SOURCES
#: below carries the classes that have cleared the first and not the second.
GUARANTEE_SOURCES = (
    "engine/*.pl",
    # The engine is mostly its SUBDIRECTORIES: 22 of its 42 Prolog files sit
    # one or two levels down, control.pl, space_hooks.pl, effects.pl and
    # translator/analysis.pl among them, and a single-level glob left every
    # claim and every commit pin in them unread.
    "engine/*/*.pl",
    "engine/*/*/*.pl",
    # The engine's benchmark driver is Python and makes the same kind of claim
    # its Prolog neighbours do. Without this line its tags were invisible: the
    # lane counted two placeholders in the tree where there were four.
    "engine/*.py",
    # The engine has C of its own -- the reader, the writer, the JSON codec
    # and the branch-return analysis -- whose headers make the same kind of
    # claim, and each seat's control file declares what that seat needs.
    "engine/*.c",
    "engine/*.h",
    "extensions/*/extension.pl",
    "lib/*/*.pl",
    "lib/*/support/*.pl",
    "lib/*/support/*.c",
    "lib/*/support/*.cpp",
    "lib/*/*.py",
    # A library's MeTTa half makes the same claims its Prolog half does,
    # and pin_provenance reported them as "OUTSIDE the evidence gate's
    # globs, so nothing reads this file's claims and nothing would ever
    # resolve them" when lib_pln2 arrived carrying one.
    "lib/*/*.metta",
    "extensions/python/metta/**/*.py",
    "extensions/python/metta/**/*.pl",
    # The Python seat's extension DISTRIBUTIONS: one module and one suite per
    # member under `ext/`. Each is hand-written code that
    # makes the same kind of claim the core's modules make, and each is where a
    # library's row now lives, so leaving them out would make the ruling of
    # 2026-09-08 the one change whose evidence nothing reads [measured
    # 2026-09-08 by tests/checks/pin_provenance.py: 24 placeholders in fourteen
    # files sat outside these globs before distribution sources were included].
    "ext/metta-*/**/*.py",
    # And the two files above them: the hook that puts a member on the path for
    # the suite, and the one implementation both it and the benchmark drivers
    # call.
    "ext/*.py",
    "extensions/python/examples/*.py",
    "extensions/mork/mork_ffi/*.pl",
    "extensions/mork/tests/*.py",
    "extensions/python/tools/*.py",
    "extensions/python/tools/*.pl",
    "tests/data/prologface/*.pl",
    "tests/data/prologface/*.metta",
    "tests/checks/*.py",
    # The Python suites carry 536 tags of their own, the largest block
    # the lane could not see.
    "extensions/python/tests/*/*.py",
    # And the seat's own conftest, which sits ABOVE them and makes claims
    # of the same kind: it collects the .metta example manifest and
    # registers the shipped fixture plugin. Its pins read as "OUTSIDE the
    # evidence gate's globs, so nothing reads this file's claims" until
    # this line existed [measured 2026-09-07 by
    # tests/checks/pin_provenance.py --check].
    "extensions/python/tests/*.py",
    # The plunit suites make the same claims their subjects do, in their
    # own headers, and 271 of them across 50 files went unread.
    "tests/prolog/suites/*/*.plt",
    # Shared suite helpers carry contracts even when they declare no test unit.
    "tests/prolog/suites/**/*.pl",
    # The module-boundary fixtures carry their own test-backed contracts
    # [source: tests/prolog/suites/seams/engine_modules.plt; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
    "tests/prolog/module_fixtures/*.pl",
    # Executable data fixtures state the semantics their differential suites check.
    "tests/data/**/*.metta",
    # Diagnostic probes carry measured claims even when no gate runs them.
    "tests/prolog/probes/*.pl",
    # A host-workaround reproduction is the same class, tracked so its
    # `present`/`absent` answer can be re-run; its header states what was
    # measured [source: docs/host-workarounds.md; commit=2bd6b250a22d9898ced449595c168a8dc3a78768].
    "tests/checks/host_workarounds/**/*.pl",
    "tests/checks/host_workarounds/**/*.sh",
    "tests/checks/host_workarounds/**/*.py",
    # And the Python half of the same class, which the seat grew on 2026-09-07.
    # A probe is where a measurement's reproduction is TRACKED rather than left
    # in a checkout, which is what the scratch rule below asks authors to do, so
    # the one directory holding those reproductions cannot be the one directory
    # whose own claims nothing reads. Four pins had to be written by hand
    # because pin_provenance refuses a placeholder outside these globs.
    "extensions/python/benchmarks/probes/*.py",
    # The example corpus is the semantics documentation and runs under the
    # gate, so an example that cites a test is making the same kind of
    # claim as the engine unit it demonstrates. Two levels, because the
    # chapters nest one deep for their sections.
    "examples/*/*.metta",
    "examples/*/*/*.metta",
    # Imported fixtures live below the corpus runner's example depths.
    "examples/**/_fixtures/**/*.metta",
    # The Node binding is TypeScript, and its sources make the same kind of
    # claim the Python ones do. Its Prolog half is here for the same reason
    # extensions/python/metta/**/*.pl is.
    "extensions/node/*.pl",
    "extensions/node/src/*.ts",
    "extensions/node/src/*/*.ts",
    # The seat's own suites and benchmarks make the same claims their subject
    # does, and _node_targets/1 was already harvesting names FROM these files
    # while nothing read the claims they carry. Same shape as the plunit and
    # Python suites above. `build/` stays out: it is tsc output, generated,
    # and its tags are copies of the ones here.
    "extensions/node/test/*.ts",
    "extensions/node/benchmarks/*.ts",
    # The site config states what its navigation guarantees, and the
    # TypeScript space example states the protocol it speaks, both in this
    # grammar and neither read by anything.
    "website/.vitepress/*.ts",
    "extensions/python/examples/integration/*/*.ts",
    "extensions/python/examples/integration/*/*.js",
    # The C seat, whose header IS its contract: 21 of its claims carried
    # commit pins and named tests while nothing read them, because C was the
    # one shipped language missing from this list. Its Prolog half joins for
    # the same reason the other two seats' halves are here.
    "extensions/cmetta/*.c",
    "extensions/cmetta/*.h",
    "extensions/cmetta/**/*.pl",
    # The site's runnable-fence machinery: the container that refuses a fence
    # that has drifted from the example it names, the component that runs one,
    # the client that holds the page's one engine, and the worker it holds it
    # in. `website/.vitepress/*.ts` was here and its `.mjs` neighbours were not,
    # so highlighting.mjs's claims went unread beside config.ts's.
    "website/.vitepress/*.mjs",
    "website/.vitepress/theme/*.js",
    "website/.vitepress/theme/*.vue",
    "website/public/metta/*.js",
    # The three classes pin_provenance's out-of-scope net caught on 2026-08-31,
    # each carrying a real pin that nothing read and nothing would ever resolve:
    # a seat's build file, the C program a seat's install lane compiles, and the
    # Node consumer that proves dist/. Written per-seat rather than per-file so a
    # seat that grows one of these grows its coverage with it, which is the rule
    # _c_targets already follows for the cases inside these same suites.
    "extensions/*/Makefile",
    "extensions/*/tests/*.c",
    "extensions/*/tools/*.mjs",
)

#: The classes whose TAGS this reads and whose Guarantees block it does not.
#: Measured before promoting each one, per glob, with the two obligations
#: separated: every glob here carries zero unbacked tags today, and the only
#: thing that kept them out was `untagged_guarantees`, which is a different
#: and stricter obligation on a burn-down of its own. Holding one file class
#: hostage to the other left 101 written claims unread across seventeen
#: classes, the shell runners among them, and the shell runners are where the
#: gate itself states what it guarantees [measured 2026-09-05: 4,875 claims
#: read before this split and 5,029 after, over 1,977 tracked files of which
#: 170 held a tag no glob reached].
#:
#: What is NOT here, and why, so the queue is a number rather than a shrug
#: [measured 2026-09-05, unbacked tags per glob with the command shapes below
#: in place]: `extensions/python/benchmarks/*.py` 22;
#: `extensions/mork/tests/*.plt` 8; `tests/prolog/*.pl` 8;
#: `extensions/python/examples/*/*.py` 6; `extensions/python/*.py` 3;
#: `tests/prolog/vendor/*.pl` 3; `tests/fixtures/*.pl` 2; `engine/*.metta` 1;
#: `extensions/cmetta/kit/*.c` 1; `tests/conformance/*.py` 1.
CLAIM_SOURCES = (
    # Native build recipes and their handwritten provider configuration.
    "**/CMakeLists.txt",
    "**/*.cmake",
    "lib/*/vendor/*.h",
    # Root build hooks state the resources their distributions contain.
    "*.py",
    # THE GATE'S OWN RUNNERS. Every shell script the repository ships, which
    # is where the gate states what it guarantees and where the largest single
    # block of unread claims sat: 63 tags across sixteen files. Three of them
    # were broken and the three are why this could not join sooner -- a lane
    # written across a line continuation, a `make -C <seat> <target>` whose
    # seat argument read as a missing file, and a measurement with no date.
    # The first two are fixed in the checker below and in evidence_runners;
    # the third was fixed in check.sh itself.
    "*.sh",
    # And `tools/`, which is where the gate's own runners now live. The line
    # above says "every shell script the repository ships" and it meant the
    # ROOT, so moving check.sh, test.sh, bounded.sh, build.sh, run.sh,
    # components.sh, worktree.sh and battery.sh one directory down took 23
    # tags out of this lane's view, 15 of them in check.sh itself. Nothing
    # went red: the lane read fewer files and reported on the ones it still
    # read, which is the failure this glob was written to end [measured
    # 2026-09-21: pin_provenance reported tools/battery.sh as "OUTSIDE the
    # evidence gate's globs, so nothing reads this file's claims and nothing
    # would ever resolve them", the same way metta_py.py was found;
    # commit=c6ed562a1a6f964aba906206f2558489b107dc24].
    "tools/*.sh",
    # And the Python beside them. The host-bundle build put canonicalise.py and
    # relocate.py under tools/pymetta-host/, where the .sh globs above could not
    # reach them, so four pins in files the gate never opened would have stayed
    # unresolvable [measured 2026-09-22: pin_provenance reported both as
    # "OUTSIDE the evidence gate's globs", the third time that net has named a
    # new file class before anyone noticed it].
    "tools/*.py",
    "tools/*/*.py",
    # And the shell and JavaScript beside them. tools/pymetta-host/ and
    # tools/wasm-host/ hold the two host builds, whose scripts state what the
    # build guarantees and pin the evidence, and the globs above stopped at
    # their Python [measured 2026-09-23: pin_provenance --check reported
    # assemble.sh, declare-host.sh, fetch-source.sh and patch-root.sh under
    # tools/pymetta-host/, and build.sh and host.mjs under tools/wasm-host/,
    # as "OUTSIDE the evidence gate's globs"].
    "tools/*/*.sh",
    "tools/*/*.mjs",
    "engine/*.sh",
    "extensions/*/*.sh",
    "extensions/*/tests/*.sh",
    "tests/shell/*.sh",
    "tests/checks/*.sh",
    # The Python seat's Prolog half, 26 claims. `extensions/python/metta/*.pl`
    # was globbed and the seat root beside it was not, so bridge.pl's whole
    # Guarantees block went unread.
    "extensions/python/*.pl",
    # And the seat root's PYTHON beside it, for the same reason and by the
    # same route the `lib/*/*.metta` line above records: pin_provenance
    # reported metta_py.py as "OUTSIDE the evidence gate's globs, so nothing
    # reads this file's claims and nothing would ever resolve them" the first
    # time it carried a placeholder. It is the Python half of the surface
    # bridge.pl is the Prolog half of, and it makes the same kind of claim.
    "extensions/python/*.py",
    "tests/prolog/*.py",
    "tests/conformance/*.pl",
    # The MORK seat's Rust, the one shipped language the list had never named.
    "extensions/mork/mork_ffi/src/*.rs",
    # A seat that grows benchmarks makes the same kind of claim its subject
    # does; four seats had, in three languages.
    "extensions/mork/benchmarks/*.py",
    "extensions/mork/benchmarks/*.pl",
    "extensions/cmetta/benchmarks/*.c",
    "extensions/cmetta/benchmarks/*.py",
    "extensions/node/benchmarks/*.py",
    # The C and Python an example ships beside its .metta, which the corpus
    # globs above reach only in their MeTTa half.
    "examples/ch19-*/*/*.c",
    "examples/ch18-*/*/*.py",
    "website/scripts/*.py",
    "website/scripts/*.mjs",
    # The stub file states the surface's types and cites what proves them.
    "extensions/python/metta/**/*.pyi",
)

# Commentless formats, scanned for PROVENANCE ONLY. A JSON baseline is exempt
# from the obligation header, which is why it is not in SOURCES, but a
# commentless format is not exempt from pinning its evidence: leaving these out
# made the lane blind to a whole file type, and RELEASE=1 reported zero
# placeholders on 2026-08-26 while baseline.json held four and
# extension-baseline.json two, all of which survived the 305-tag sweep in
# c918e7fd for exactly that reason.
#
# Only the commit half of the contract applies. Their re-pin comments are long
# measurement prose written for a reader, and running the claim analysis over
# it reads ordinary sentences as tags: scanning baseline.json under SOURCES
# reported "tested: names goes", "names red", "names against" and "names read"
# from one row's narrative. The pin check is a regex over commit= and cannot
# make that mistake.
# Discovered rather than named, the way evidence_runners finds a component's
# scripts: a seat that grows its own benchmarks grows its own baseline, and a
# hardcoded list would leave that seat's commit pins unchecked in the same
# silence this lane exists to end.
#
# The shell runners were here for the pin half and not for the claim half; they
# have since joined CLAIM_SOURCES, where their tags ARE read. They stay here
# too, and so does every other glob that has moved: this pass reads a `commit=`
# on ANY line, including the long re-pin prose no tag encloses, which is a
# wider net than the claim half's rather than a subset of it. Their Guarantees
# blocks remain a burn-down against GUARANTEE_SOURCES, which is a different
# obligation and is why the two lists are no longer one list.
PROVENANCE_SOURCES = (
    # Configuration headers carry provenance even where command citations
    # have not joined the claim grammar.
    "**/*.toml",
    # Provider suites qualify private engine probes and pin that boundary.
    "extensions/*/tests/*.plt",
    # Native corpus providers carry their own SWI import contracts.
    "examples/*/*/*.pl",
    # The twins and the suites, named by the out-of-glob net on 2026-08-31: a
    # twin's BUDGET carries a whole provenance history in comments and a
    # suite's Guarantees block carries its own claims, so both were writing
    # pins nothing read and nothing would resolve. They join the PIN half
    # only, the same staging the shell runners take below, because their claim
    # half is a burn-down rather than a gate: reading them as SOURCES reports
    # 414 unbacked tags over 4,770 claims, most of them citations left behind
    # by a rename [measured 2026-08-31].
    # The corpus nests two, three and four directories deep (ch09's twins sit
    # at chapter level, ch07's inside a section), so all three depths are
    # named; the out-of-glob net found the missing two on 2026-09-01, 46
    # files' pins unread.
    "extensions/python/examples/*/*/*.py",
    "extensions/python/examples/*/*/*/*.py",
    "extensions/python/examples/*/*/*/*/*.py",
    "extensions/python/tests/*/*.py",
    # And the seat's own conftest, which sits ABOVE them and makes claims
    # of the same kind: it collects the .metta example manifest and
    # registers the shipped fixture plugin. Its pins read as "OUTSIDE the
    # evidence gate's globs, so nothing reads this file's claims" until
    # this line existed [measured 2026-09-07 by
    # tests/checks/pin_provenance.py --check].
    "extensions/python/tests/*.py",
    "extensions/*/benchmarks/*.json",
    "engine/*.json",
    # The Prolog fixtures a suite DRIVES, which carry obligation headers of
    # their own: tests/data/package_laws/mutations.pl is the package-law
    # mutation harness engine/check.sh runs as the package-mutations GATE, and
    # its neighbours are the support it loads. tests/data/prologface/*.pl was
    # named one directory at a time in the claim half above; this glob is the
    # general one, so the next fixture directory is covered the first time it
    # carries a pin instead of the next time the out-of-glob net names it
    # [measured 2026-09-20 by tests/checks/pin_provenance.py --check, which
    # reported all three of package_laws's].
    "tests/data/**/*.pl",
    # The RECORD. agenticmind.json quotes evidence tags inside the reasons it
    # carries, because "MEASURED ...; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f" is the reason a status
    # was given, so it spells the placeholder in a commentless format exactly
    # as the baselines above do. It joins the PIN half only and never the
    # claim half: a record's reasons are an account of what was believed and
    # why, not source claims for the evidence gate to resolve
    # [measured 2026-09-20: 5 pins, and the net exits 1 on any file it cannot
    # reach, so an unreachable one blocks the release pass rather than only
    # the report]. It is listed so the net REACHES it and stops reporting it;
    # the pins themselves are declined by the classifier, because the file is
    # hash-chained and rewriting it in place destroys the record. The reason
    # lives once, on evidence_sites.UNPINNABLE_REASON.
    "agenticmind.json",
    # The ext component's runner and guide, the two files the out-of-glob net
    # found once it read the components as the gate's own walks do, each
    # holding a placeholder nothing read [measured 2026-09-25T01:17:45+10:00:
    # ext/check.sh:11 and ext/README.md:5]. The PIN half only, the staging this
    # list's entries take.
    "ext/*.sh",
    "ext/*.md",
    "*.sh",
    # The gate's own runners, for the reason given on CLAIM_SOURCES above.
    "tools/*.sh",
    "tools/*/*.sh",
    "tools/*/*.mjs",
    "engine/*.sh",
    "extensions/*/*.sh",
    # Three more the out-of-glob net named on 2026-09-05, each carrying pins
    # written by the annotated-arrow work that nothing read and nothing would
    # resolve: a seat's benchmark SUITE, which pins the measurements whose
    # numbers its neighbouring baseline.json already pins; the conformance
    # helpers, whose Guarantees block cites its own cases; and the upstream
    # parity baseline, a commentless format like the seat baselines above and
    # covered for the same reason. They join the PIN half only, the staging
    # this list's entries take.
    "extensions/python/benchmarks/*.py",
    "tests/conformance/*.pl",
    # Their PYTHON half, which had been writing pins nothing read since the
    # corpus lane was built: petta_capture.py and petta.py each carry a
    # Guarantees block with commit pins in it, and the census mode added a
    # third file's worth on 2026-09-07. The PIN half only, the staging this
    # list's entries take, because the claim half is a burn-down the queue in
    # CLAIM_SOURCES already counts at one unbacked tag.
    "tests/conformance/*.py",
    "tests/data/*.json",
    # The Prolog beside the suites, named by the out-of-glob net: layering.pl
    # states what the engine's module graph guarantees and pins it, and
    # nothing read that pin or would ever resolve it. The PIN half only,
    # because the claim half is a burn-down: reading these as SOURCES
    # reports 8 unbacked tags [measured 2026-09-05, recorded in
    # CLAIM_SOURCES' own queue above].
    "tests/prolog/*.pl",
    # The guides at the root cite sources and tests with commit pins written
    # into prose; the out-of-glob net named EXTENDING.md on 2026-09-09 with
    # three placeholders a merge reconciliation had written, and KERNEL.md
    # carries two pins of the same kind. The PIN half only, because a guide
    # spells its sources as prose ("engine/ext_points.pl, seam:pattern_modifier/3
    # and engine/translator.pl, lift_pattern_modifiers/3") the claim checker
    # does not parse.
    "EXTENDING.md",
    "KERNEL.md",
    # Website guides carry the same prose pins, including relocated sources.
    "website/**/*.md",
)

#: Every file whose evidence TAGS are read. Both halves, because a tag is a
#: tag wherever it is written.
SOURCES = GUARANTEE_SOURCES + CLAIM_SOURCES

# Where a name may be defined. metta/_compliance.py holds real tests, shipped
# for a provider author to inherit; they run here too, under each
# SpaceComplianceSuite subclass, which is why the package is walked at all.
#
# DISCOVERED for the seats rather than listed: a seat owns its own tests/
# directory and extensions/cmetta/tests/test_kit.py sits in one, so a claim
# naming a test defined there read as naming nothing while sanitize.sh ran it
# [measured 2026-09-05].
PYTHON_TREES = (
    "extensions/python/tests",
    "extensions/python/benchmarks",
    "extensions/python/metta",
    "tests",
    *sorted(
        str(path.relative_to(ROOT))
        for path in ROOT.glob("extensions/*/tests")
        if path.is_dir()
    ),
    # The Python seat's extension DISTRIBUTIONS, each with its own module and
    # its own tests beside it: a claim in metta_arrays.py names a test in
    # ext/metta-arrays/tests/, and the same glob reads both because a member
    # is one directory [discovered 2026-09-08 with the packages themselves].
    *sorted(
        str(path.relative_to(ROOT))
        for path in ROOT.glob("ext/metta-*")
        if path.is_dir()
    ),
)

# The tag and everything up to its closing bracket, across newlines: a claim
# listing three tests wraps, and a per-line scan reads the first line as an
# unterminated claim and skips it silently, which is how a checker for missing
# evidence comes to miss the evidence that is missing. The tag must also be
# FOLLOWED by a separator and a body, or the same pattern matches an ordinary
# Prolog variable spelled [Source] and the checker reports the file it reads.
# `assumed` is here for its COMMIT PIN and for nothing else. Its content stays
# unchecked, which is the whole reason the tag exists, but a pin it carries
# names a tree exactly as any other pin does and a dangling one is the same
# defect. 16 of this tree's 132 assumed tags carry one and none was read
# [measured 2026-09-07], and the scratch rule below sends more of them here:
# `assumed` naming what is missing is what a claim writes when its fixture is
# gone, and that should not cost its pin the scrutiny every other pin gets.
CLAIM = re.compile(
    r"\[(tested|measured|source|assumed)[:\s]([^\]]*)\]", re.IGNORECASE | re.DOTALL
)
# What a string literal's escapes spell. A GENERATOR holds its output's header
# in a literal -- extensions/python/tools/vocabgen.py holds the Node vocabulary
# table's whole contract block in one -- so a claim written there is read
# through that literal's escaping: `\'` for an apostrophe inside a
# single-quoted literal, and `\n` for the line break the OUTPUT has. Left raw,
# one claim answered two ways, `the engine\'s own` from the generator and `the
# engine's own` from the file it writes, and only the second could resolve. The
# generator is where a wrong name has to be fixed, because the next --write
# puts it back, so this is what lets the gate read it there.
ESCAPE = re.compile(r"\\([nrt'\"\\])")
UNESCAPED = {"n": "\n", "r": "\r", "t": "\t"}
# A `node --test` case names itself in prose: `test("...")`, `it("...")` and
# `describe("...")` each register one, which is what an evidence claim in a
# TypeScript source points at [source:
# https://nodejs.org/docs/latest-v22.x/api/test.html]. `test` is the module's
# own primary export and was missing here, so the 23 cases in
# extensions/node/tools/browser.test.mjs and the 15 in the TypeScript space
# example's suite -- every case in this tree written with it -- read as naming
# nothing.
#
# The closing quote is the one that OPENED, by backreference, and not whichever
# of the three comes first. A title is prose and prose has apostrophes: 21 of
# this seat's cases are named `"... the engine's own"` and every one of them was
# registered truncated at the apostrophe, so a citation spelling the case's real
# name matched nothing while a citation stopping mid-word would have passed.
NODE_TEST = re.compile(
    r"""^\s*(?:it|test|describe)\(\s*(?P<quote>["'`])(?P<name>.*?)(?<!\\)(?P=quote)""",
    re.MULTILINE,
)
# A C suite names its cases in identifiers, not in prose: `static void
# test_<name>(...)` defined at the top level. Being defined is not being run,
# which is why the caller set below matters as much as this pattern.
C_TEST = re.compile(r"^static\s+\w[\w *]*?\btest_(\w+)\s*\(", re.MULTILINE)
# And it names them a SECOND time, in prose. `CASE("...")` sets the harness's
# `current_case`, which the CHECK macro prints beside a failing check, so the
# sentence is what names the failure to a reader and what a citation points at:
# extensions/cmetta/cmetta.c cites one for the object-identity guarantee.
# 96 of them are written in test_cmetta.c against 45 case functions, so the
# prose name is the finer of the two and the only one a reader is shown
# [source: extensions/cmetta/tests/test_cmetta.c, the CASE and CHECK macros].
C_CASE = re.compile(r'^\s*(?:\{\s*)?CASE\(\s*"([^"]+)"', re.MULTILINE)
# main()'s body, which is the C suite's runner: a case reaches the binary only
# by being called from there.
C_MAIN = re.compile(r"^int\s+main\s*\([^)]*\)\s*\{(.*?)^\}", re.MULTILINE | re.DOTALL)
C_CALL = re.compile(r"\btest_(\w+)\s*\(")
# A Makefile target opens in column 1 and is followed by `:`, which `:=` is not:
# a variable assignment names sources without compiling them, and reading one as
# a target would put every source under whichever variable mentioned it.
MAKE_TARGET = re.compile(r"^([A-Za-z][\w.-]*)\s*:(?!=)")
# How a PROGRAM reports failure, as against a suite: it sets its own exit
# status. `throw` is deliberately not a signal, because every library source
# throws and reading that as evidence would back a claim naming any file at all;
# setting process.exitCode or calling process.exit is something only a program
# does, and extensions/node/tools/dist-consumer.mjs is one.
NODE_EXIT = re.compile(r"process\.exitCode\s*=\s*[1-9]|process\.exit\(\s*[1-9]")
# The C equivalent, read only where main() exists and the file declares no case,
# so a helper returning 1 in a suite cannot stand in for the suite running.
C_EXIT = re.compile(r"\breturn\s+[1-9]|\bexit\s*\(\s*[1-9]|\bEXIT_FAILURE\b")
# The other way a C program reports failure: an assert() in main(), which
# aborts with a nonzero status. It counts only where the file undefines NDEBUG
# before it includes <assert.h>, because a build defining NDEBUG compiles every
# assert to nothing and the binary would then pass whatever it computed; six of
# extensions/cmetta/tests' programs are written this way.
C_ASSERT = re.compile(r"\bassert\s*\(")
C_LIVE_ASSERTS = re.compile(r"^\s*#\s*undef\s+NDEBUG\b.*?^\s*#\s*include\s*<assert\.h>",
                            re.MULTILINE | re.DOTALL)
# A name written in prose, quoted so the splitter takes it whole. It may WRAP,
# because a claim sits in a comment and a comment is wrapped like any other
# prose, so the match spans newlines and the name's whitespace is normalised
# to the single spaces the test's own title carries.
QUOTED_NAME = re.compile(r'"([^"]{4,}?)"', re.DOTALL)
#`/` joins them for the `//` grammars. A tag that wraps in TypeScript
#carries the marker on its continuation line, and without it here the
#second half of a two-line test name reads as `// ...`, so four copies of
COMMENT_PREFIX = re.compile(r"^[ \t]*[%#*/]*[ \t]*", re.MULTILINE)
#: The instant of the obligation-header rule [source 2026-09-25T01:14:59+10:00:
#: ~/.claude/skills/obligation-headers/SKILL.md, "Stamping, validating and
#: refreshing a tag", sha256 ee67e55a49a4fdf1]. Since it a tag carries the
#: whole `date -Iseconds` stamp its evidence ran at, and no pin says
#: `commit=WORKTREE` or names a commit of its own repository; a line written
#: before it is legacy and stays as it is until its evidence runs again. The
#: second is the file's modification time when the rewrite was first read
#: [assumed 2026-09-25T01:14:59+10:00: the file was edited again at
#: 2026-09-25T00:31:33+10:00, so its time no longer shows the rewrite's].
RULE_INSTANT = "2026-09-24T23:27:42+10:00"
#: A tag's date, which is what lets a measured or source claim go stale.
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
#: A tag's time as written: its date and whatever is attached to it, one token,
#: so a time is judged whole. A tag carried the date alone until RULE_INSTANT
#: and carries the whole `date -Iseconds` stamp since.
TIME = re.compile(r"\d{4}-\d{2}-\d{2}(?:T[\w:+.-]*)?")
#: The whole of what `date -Iseconds` prints, and so the only time a tag may
#: carry after its date [source 2026-09-25T00:29:31+10:00: date(1), whose -I
#: option with FMT=seconds prints date and time to the second, its own example
#: being 2006-08-14T02:34:56-06:00].
STAMP = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}")
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?::[A-Za-z_][A-Za-z0-9_]*)*$")
#: What makes a token READ as a name rather than as the sentence around it.
#: A claim's prose sits in the same brackets as its names, and PROSE cannot
#: list every English word an author might use: one claim in
#: engine/metta/control.pl contributed "answers", "grow", "counter",
#: "creating", "grows" and "tenth", and one in extensions/cmetta/bridge.pl
#: contributed "reports", "row" and "present". A name in this tree carries an
#: underscore, a colon, a dot, a slash, a digit or a hyphen; a bare lowercase
#: word does not, and is read as prose UNLESS the tree defines it, which is
#: what keeps a single-word example name like `quiet` checkable and a
#: mistyped one the price.
NAME_SHAPED = re.compile(r"[_:./0-9-]")
#The last alternative is a MAN PAGE, `perf-stat(1)`, which this repository
#cites twelve times and which is as precise a reference as a URL: the
#section number picks the page. Eleven of the twelve passed only because
#they ran to three words; naming the form says why they are citations.
REFERENCE = re.compile(r"https?://|\w+\.\w+:\d+|\w+/[\w./-]+|\b[\w-]+\([1-8]\)")
SUFFIXES = (".py", ".pl", ".plt", ".metta", ".sh", ".c")
#: What node's own runner selects a suite by, and therefore what makes a file
#: one here [source: https://nodejs.org/docs/latest-v22.x/api/test.html].
NODE_SUITE = (".test.ts", ".test.mts", ".test.mjs", ".test.js", ".test.cjs")
#: Directories a build, an install or a scratch run writes into, which the
#: walk below does not enter. A suite under one is a COPY:
#: extensions/node/build/test/wire.test.js is tsc's output for
#: test/wire.test.ts and declares the same 30 names, so harvesting both would
#: hand a reader the generated copy to open. The census records the copy
#: because the lane runs it, and maps it back to the source through the seat's
#: own tsconfig; this is the other half of that.
#:
#: It is also what keeps the walk at milliseconds. These hold almost everything
#: on disk and almost nothing the repository wrote: the main checkout walks
#: 287,369 files entered and 2,268 skipping them, 1.14s against 0.01s, and this
#: checker promises to finish in well under a second [measured 2026-09-07].
#: The scratch root joins them at walk time, read from the runner that
#: allocates it rather than named twice.
NODE_GENERATED = frozenset({
    "node_modules", "build", "dist", "browser", "_runtime", "target", "__pycache__",
})

# `translator.plt:malformed_seam_is_refused` and
# `test_per_space.py::test_eval_uses_the_spaces_own_equations` name a file and
# a test inside it. Three claims are written this way and the identifier rule
# dropped all three without a word, which is a citation nobody checks.
QUALIFIED = re.compile(rf"^(\S+(?:{'|'.join(re.escape(s) for s in SUFFIXES)}))::?(\w+)$")

# Words that appear inside a claim's prose rather than naming anything.
PROSE = frozenset(
    """and or the a an in of with by at to for on end via plus then also
    through both all each every same test tests suite suites case cases
    e g eg ie i see also above below here there is are was were it its
    this that these those not no yes if when while as from into over
    under after before during than then rather instead but so because
    which what who whom whose how why where when whether""".split()
)

PROLOG_ENTRY = re.compile(r":-\s*initialization\(\s*(\w+)\s*,\s*main\s*\)")
# A plunit test clause starts in column 1, which is where SWI's own style puts
# every clause head. The looser `^\s*test\(` this replaced also matched the
# indented goal `test(1, 2, _)` in metta.plt and registered `1`, plus one
# `<unit>:1` per unit, as though they were tests.
PROLOG_TEST = re.compile(r"^test\(\s*(\w+)", re.MULTILINE)
# A MeTTa form whose failure stops the file: test/3 throws metta_test_failed.
METTA_ASSERTION = re.compile(r"\((?:test|test-no-answer|assert[\w-]*)[\s(]")
SHELL_FAILURE = re.compile(r"\bexit\s+[1-9]|\breturn\s+[1-9]|\|\|\s*exit\b|^set -e", re.MULTILINE)


@dataclass(frozen=True)
class Target:
    """One thing a claim can name, and the file whose execution backs it."""

    kind: str
    path: Path
    run_path: Path
    fails: str | None
    note: str = ""


@dataclass(frozen=True)
class Evidence:
    """What the tree offers a claim: names, the files behind them, and what runs."""

    targets: dict[str, list[Target]]
    runs: dict[Path, Execution]
    files: frozenset[str]
    reports: dict[Path, str]


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _python_files() -> list[Path]:
    return [path for tree in PYTHON_TREES for path in owned((ROOT / tree).rglob("*.py"), ROOT)]


def _unconditionally_skipped(node: ast.AST) -> bool:
    """`@pytest.mark.skip` with no condition. skipif is an environment, not a hole."""
    decorators = getattr(node, "decorator_list", [])
    return any(re.search(r"\bmark\.skip\b", ast.unparse(one)) for one in decorators)


def _scope_definitions(node: ast.AST) -> Iterator[ast.AST]:
    """Every def and class that lands in this scope's namespace.

    `if` and `try` included, because they do not open a scope. Three of this
    tree's property tests sit under a module-level `else:` that picks a
    hypothesis strategy, and pytest collects them like any other module
    attribute. Reading only Module.body lost all three.
    """
    for member in (
        getattr(node, "body", [])
        + getattr(node, "orelse", [])
        + getattr(node, "finalbody", [])
        + list(getattr(node, "handlers", []))
    ):
        if isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            yield member
        elif isinstance(member, (ast.If, ast.Try, ast.With, ast.For, ast.While, ast.ExceptHandler)):
            yield from _scope_definitions(member)


def _python_targets(runs: dict[Path, Execution]) -> dict[str, list[Target]]:
    """Every `def test*` pytest collects, and the file whose run reaches it.

    pytest collects a `test` prefixed function at module level, and one inside
    a `Test` prefixed class with no __init__; a class reached only through such
    a subclass is collected too, which is how the shipped compliance suites in
    metta/_compliance.py come to run [source:
    https://docs.pytest.org/en/stable/explanation/goodpractices.html].
    """
    trees: dict[Path, ast.Module] = {}
    for path in _python_files():
        try:
            trees[path] = ast.parse(_text(path))
        except SyntaxError:
            continue

    classes: dict[str, list[tuple[Path, ast.ClassDef]]] = {}
    for path, tree in trees.items():
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                classes.setdefault(node.name, []).append((path, node))

    # Which class bodies a collected test module drags in, and through which
    # file, since that file's execution is what backs a claim on an inherited
    # test.
    inherited: dict[int, Path] = {}

    def descend(node: ast.ClassDef, through: Path) -> None:
        for base in node.bases:
            name = ast.unparse(base).rsplit(".", maxsplit=1)[-1]
            for _, definition in classes.get(name, []):
                if id(definition) not in inherited:
                    inherited[id(definition)] = through
                    descend(definition, through)

    for path, tree in trees.items():
        if runs.get(path.resolve()) is None:
            continue
        for node in _scope_definitions(tree):
            if isinstance(node, ast.ClassDef) and node.name.startswith("Test"):
                inherited.setdefault(id(node), path)
                descend(node, path)

    targets: dict[str, list[Target]] = {}

    def collect(node: ast.AST, path: Path, run_path: Path | None, note: str) -> None:
        for member in _scope_definitions(node):
            if isinstance(member, ast.ClassDef) or not member.name.startswith("test"):
                continue
            fails = "pytest reports a failure"
            if run_path is None:
                fails, note = None, "pytest does not collect it"
            elif _unconditionally_skipped(member):
                fails, note = None, "it is skipped unconditionally"
            targets.setdefault(member.name, []).append(
                Target("pytest", path, run_path or path, fails, note)
            )

    for path, tree in trees.items():
        selected = runs.get(path.resolve()) is not None
        collect(tree, path, path if selected else None, "")
        for node in ast.walk(tree):
            if not isinstance(node, ast.ClassDef):
                continue
            through = inherited.get(id(node))
            initialised = any(
                isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef))
                and member.name == "__init__"
                for member in node.body
            )
            if through is None or initialised:
                collect(node, path, None, "")
            else:
                collect(node, path, through, f"through {node.name}")
    return targets


def _prolog_report(text: str) -> str:
    """How one Prolog file reports a failure, or "" when it cannot on its own."""
    if PROLOG_TEST.search(text):
        return "plunit reports a failing test"
    if PROLOG_ENTRY.search(text):
        return "the script exits 1 when its entry goal fails"
    return ""


def _prolog_suites() -> list[Path]:
    """Every Prolog file a suite could live in, seat-owned ones included.

    Rooted at tests/ alone until 2026-09-05, which left a seat's OWN plunit
    suite invisible: extensions/mork/tests/mork_seat.plt defines eight tests
    and cites all eight in its header, and every one of them read as naming a
    test that is not in the tree. Discovered per seat rather than listed, so a
    seat that grows a suite is covered without an edit here, which is the rule
    build.sh and check.sh already follow for a component.
    """
    found = owned((ROOT / "tests").rglob("*.pl*"), ROOT)
    for seat in sorted(ROOT.glob("extensions/*/tests")):
        found += owned(seat.rglob("*.pl*"), ROOT)
    return sorted(set(found))


def _prolog_reports() -> dict[Path, str]:
    """How each Prolog suite file reports a failure, or "" when it cannot.

    A FILE property, not a per-predicate one. Whether a particular predicate is
    reached cannot be decided by reading the text: plunit runs goals written in
    a test's options and in begin_tests' options, a multifile hook is called by
    the engine and never by the file that defines it, and assertz installs
    clauses at run time. A call graph built here rejected 25 predicates that
    are all called, and each pattern it learned uncovered another. SWI answers
    this question with prolog_walk_code/1 against a loaded database, which is
    what tests/prolog/static_checks.pl already does and what a reader cannot.
    """
    reports = {
        path.resolve(): _prolog_report(_text(path))
        for path in _prolog_suites()
    }
    # A file with no entry of its own still runs, and still fails, when one
    # that has an entry loads it. static_checks.pl reaches its published
    # surface check through `:- ensure_loaded(surface_walk)`, and nine of
    # surface_walk.pl's predicates read as unbacked without this.
    settled = False
    while not settled:
        settled = True
        for path, why in list(reports.items()):
            if not why:
                continue
            for loaded in prolog_loads(path):
                if reports.get(loaded) == "":
                    reports[loaded] = f"{path.name} loads it and reports its failure"
                    settled = False
    return reports


def _prolog_test_units(text: str) -> Iterator[tuple[str | None, str]]:
    """Every plunit test in a file, with the unit it is written inside.

    `None` for a test outside any unit, which plunit does not run and which
    stays reportable rather than silently attaching to whichever unit came
    first.
    """
    unit: str | None = None
    for line in text.splitlines():
        if opened := re.match(r"^:-\s*begin_tests\(\s*(\w+)", line):
            unit = opened.group(1)
        elif re.match(r"^:-\s*end_tests\(", line):
            unit = None
        elif started := re.match(r"^test\(\s*(\w+)", line):
            yield unit, started.group(1)


def _prolog_targets(reports: dict[Path, str]) -> dict[str, list[Target]]:
    """Plunit units and tests, and the named checks a Prolog script runs."""
    targets: dict[str, list[Target]] = {}
    for path in _prolog_suites():
        text = _text(path)
        run_path = path.resolve()
        why = reports[run_path]
        note = "" if why else "it has no plunit test, no entry goal, and nothing loads it"
        units = re.findall(r"begin_tests\(\s*(\w+)", text)
        named = [("plunit-unit", unit) for unit in units]
        # Each test paired with the unit it is ACTUALLY in, walked in order.
        # Registering the cross-product -- every test under every unit in the
        # file -- made `unit:name` resolve for any unit the file happens to
        # contain, so a citation could name the wrong one and pass. Four in
        # this tree did, and one written on 2026-08-31 was among them: a
        # reader who followed `shim_answer_form:one_variable_in_two_columns...`
        # would open the wrong unit and not find it.
        for unit, name in _prolog_test_units(text):
            named += [("plunit", name)]
            if unit is not None:
                named += [("plunit", f"{unit}:{name}")]
        # A check the gate runs as a script rather than as a plunit test is
        # evidence too: static_checks.pl is one, and its checks are named
        # predicates. A name worth registering carries arguments or a body.
        named += [("prolog", n) for n in re.findall(r"^([a-z]\w*)\s*(?::-|\()", text, re.MULTILINE)]
        for kind, name in named:
            targets.setdefault(name, []).append(Target(kind, path, run_path, why or None, note))
    return targets


def _node_suites() -> list[Path]:
    """Every JavaScript-family suite in the tree, generated copies aside.

    Rooted at extensions/node/test alone until 2026-09-07, which left three
    kinds of suite invisible: the Node seat's own browser suite one directory
    over in tools/, and the TypeScript space example's suite beside the server
    it drives, in both its source and its checked-in bundle. 45 citations named
    a case in one of them and every one of them read as naming nothing.

    Discovered by the naming convention node's own runner selects on rather
    than listed, which is the rule _prolog_suites and _c_targets already
    follow: a seat or an EXAMPLE that grows a suite is covered without an edit
    here.
    """
    scratch, _ = scratch_root()
    skipped = NODE_GENERATED | ({scratch} if scratch else frozenset())
    # The tracked files, not a walk: a generated bundle or a checked-out copy
    # under an ignored directory is not a suite of this tree.
    return [
        path for path in sorted(tracked(ROOT))
        if path.name.endswith(NODE_SUITE)
        and not any(part in skipped or part.startswith(".") for part in path.relative_to(ROOT).parts[:-1])
    ]


def _node_targets(runs: dict[Path, Execution]) -> dict[str, list[Target]]:
    """Every name a `node --test` suite declares: its describes, tests and its.

    A TypeScript suite names its cases in prose rather than in identifiers, so
    the name a claim points at is the STRING, and `describe`, `test` and `it`
    each register one. The file itself is a target too, which is what lets a
    claim name a whole suite the way one may name a Python test module.
    """
    targets: dict[str, list[Target]] = {}
    for path in _node_suites():
        resolved = path.resolve()
        fails = "node --test reports a failure" if resolved in runs else None
        note = "" if fails else "no lane runs it"
        for found in NODE_TEST.finditer(_text(path)):
            name = found.group("name")
            targets.setdefault(name, []).append(Target("node", path, resolved, fails, note))
        targets.setdefault(path.name, []).append(Target("node", path, resolved, fails, note))
    return targets


def _c_runner(makefile: str, source: Path) -> str:
    """The seat script that reaches this .c, read off the seat's own Makefile.

    A seat's tests/ holds more than its unit suite. extensions/cmetta/tests/
    holds test_cmetta.c, which `make test` builds through TESTS, and
    install_consumer.c, which ONLY `make install-check` compiles, from the
    c-install lane. Attributing both to the seat's test.sh said the consumer
    was covered by a lane that never opens it, so deleting c-install would have
    left its claim reading as backed [measured 2026-08-31: install_consumer.c
    resolved to test.sh with "the C suite exits nonzero", while
    `TESTS := tests/test_cmetta` is the whole of what the test target builds].

    A recipe line naming the source decides, because that is the line that
    compiles it; a source no recipe names is reached the ordinary way, through
    the test target, and stays with test.sh.
    """
    owner = None
    for line in makefile.splitlines():
        if matched := MAKE_TARGET.match(line):
            owner = matched.group(1)
        elif line.startswith("\t") and source.name in line:
            # Every seat lane other than the suite lives in the seat's check.sh,
            # which the root driver sources, so that is what runs this target.
            return "test.sh" if owner in (None, "test") else "check.sh"
    return "test.sh"


def _c_cases(text: str) -> Iterator[tuple[str, str]]:
    """Every CASE(...) in a C suite, with the test_ function it is written in.

    A C suite names its cases twice, and only the second name reaches a reader.
    `static void test_objects_cross(void)` is the unit main() dispatches;
    `CASE("the same C object is one engine identity across store, match and
    delete")` inside it is what the CHECK macro prints when a check fails. So a
    citation may name either, and the pairing is what decides the finer one's
    verdict: a CASE inside a function main() never calls is as dead as the
    function, and inherits its note rather than reading as backed on its own.
    """
    current = None
    for line in text.splitlines():
        if defined := C_TEST.match(line):
            current = defined.group(1)
        elif (named := C_CASE.match(line)) and current is not None:
            yield current, named.group(1)


def _c_verdict(
    function: str, called: set[str], run: Execution | None, reports: str
) -> tuple[str | None, str]:
    """What backs a case written in this function, or why nothing does."""
    if function not in called:
        return None, "main() does not call it, so the binary never runs it"
    return (reports, "") if run else (None, "no lane runs its suite")


def _c_targets(runs: dict[Path, Execution]) -> dict[str, list[Target]]:
    """Every case a seat's C suite declares, and whether main() runs it.

    C was the one shipped language missing from this lane, so the C seat's
    header carried claims naming its own tests and nothing read them. A C suite
    has no collector: `main()` IS the runner, so a `static void test_x(void)`
    that main does not call is dead in exactly the way an uncollected pytest
    function is, and is reported the same way.

    Discovered rather than named, the same way evidence_runners finds a
    component's scripts: a seat that grows a C suite grows its own cases.
    """
    targets: dict[str, list[Target]] = {}
    for path in owned(ROOT.glob("extensions/*/tests/*.c"), ROOT):
        text = _text(path)
        body = C_MAIN.search(text)
        called = set(C_CALL.findall(body.group(1))) if body else set()
        seat = path.parent.parent
        recipe = seat / "Makefile"
        runner = (seat / _c_runner(_text(recipe) if recipe.is_file() else "", path)).resolve()
        run = runs.get(runner)
        reports = (
            "the C suite exits nonzero on the first failing check"
            if runner.name == "test.sh"
            else "a failed lane makes check.sh exit nonzero"
        )
        for name in C_TEST.findall(text):
            targets.setdefault(f"test_{name}", []).append(
                Target("c", path, runner, *_c_verdict(name, called, run, reports))
            )
        for function, case in _c_cases(text):
            targets.setdefault(case, []).append(
                Target("c", path, runner, *_c_verdict(function, called, run, reports))
            )
        targets.setdefault(path.name, []).append(
            Target("c", path, runner, reports if run else None, "" if run else "no lane runs its suite")
        )
    return targets


def gather() -> tuple[Evidence, list[str]]:
    """Every name a claim may legitimately point at, and what backs it."""
    runs, problems = executed()
    reports = _prolog_reports()
    targets = _python_targets(runs)
    for name, found in _prolog_targets(reports).items():
        targets.setdefault(name, []).extend(found)
    for name, found in _node_targets(runs).items():
        targets.setdefault(name, []).extend(found)
    for name, found in _c_targets(runs).items():
        targets.setdefault(name, []).extend(found)
    for path in owned((ROOT / "examples").rglob("*.metta"), ROOT):
        targets.setdefault(path.stem, []).append(file_target(path, reports))
    for path in owned((ROOT / "tests").rglob("*.sh"), ROOT):
        targets.setdefault(path.stem, []).append(file_target(path, reports))
    files = {target.path.name for group in targets.values() for target in group}
    return Evidence(targets, runs, frozenset(files), reports), problems


def _node_file(path: Path, text: str, resolved: Path) -> Target:
    """A .ts or .mjs file's own way of failing: a declared case, or an exit.

    A seat ships both. test/*.test.ts declare cases node --test collects, while
    tools/dist-consumer.mjs is a PROGRAM whose whole body is the check and which
    reports by setting its exit status.
    """
    if NODE_TEST.search(text):
        return Target("node", path, resolved, "node --test reports a failure")
    if NODE_EXIT.search(text):
        return Target("node", path, resolved, "the program exits nonzero")
    return Target("node", path, resolved, None, "it declares no test and sets no exit status")


def _c_file(path: Path, text: str, resolved: Path) -> Target:
    """A .c file's own way of failing, the same two the .py branch models.

    A SUITE declares test_ cases and main() dispatches them, and a case main
    never calls is dead the way an uncollected pytest function is. A PROGRAM
    declares no cases at all: main() IS the check and it fails by exiting
    nonzero, which is what extensions/cmetta/tests/install_consumer.c does.
    Reading every .c as a suite said that consumer ran nothing, and contradicted
    _c_targets, which had already attributed it to the lane that compiles it, so
    one file answered two ways depending on how a claim spelled it
    [measured 2026-08-31].

    The exit is read from main()'s BODY, not the file, because a helper
    returning 1 is not the program reporting a failure. An assert() in that
    body is the program's other way of failing, and it is believed only where
    the file undefines NDEBUG before <assert.h>, so no build flag can compile
    the check away [tested: tests/checks/check_evidence_selftest.py;
    commit=WORKTREE].
    """
    body = C_MAIN.search(text)
    if body is not None and C_CALL.search(body.group(1)):
        return Target("c", path, resolved, "the C suite exits nonzero on the first failing check")
    if body is not None and not C_TEST.search(text) and C_EXIT.search(body.group(1)):
        return Target("c", path, resolved, "the program exits nonzero")
    if (body is not None and not C_TEST.search(text) and C_ASSERT.search(body.group(1))
            and C_LIVE_ASSERTS.search(text)):
        return Target("c", path, resolved, "an assert in main() aborts with a nonzero status")
    return Target("c", path, resolved, None,
                  "its main() calls no test_ case, so the binary runs none")


def file_target(path: Path, reports: dict[Path, str]) -> Target:
    """What a claim naming a whole file gets: the file's own way of failing."""
    text = _text(path)
    resolved = path.resolve()
    if path.suffix == ".metta":
        if METTA_ASSERTION.search(text):
            return Target("example", path, resolved, "a test form throws when it does not match")
        return Target("example", path, resolved, None, "it holds no (test ...) or (assert ...) form")
    if path.suffix == ".sh":
        if resolved in {script.resolve() for script in gate_scripts()}:
            # A component's check.sh is SOURCED by the root driver, never
            # executed, so it has no `exit` of its own: its lanes report through
            # `run`, and the root turns a failed lane into the gate's nonzero
            # exit. Reading it for an exit of its own declared every component
            # check file unable to fail, which is what left the first three
            # claims naming one unbacked [measured 2026-08-31].
            return Target("shell", path, resolved, "a failed lane makes check.sh exit nonzero")
        if SHELL_FAILURE.search(text):
            return Target("shell", path, resolved, "the suite exits nonzero")
        return Target("shell", path, resolved, None, "it never exits nonzero")
    if path.suffix in (".pl", ".plt"):
        why = reports.get(resolved, _prolog_report(text))
        return Target(
            "prolog", path, resolved, why or None,
            "it has no plunit test, no entry goal, and nothing loads it",
        )
    if path.suffix in (".ts", ".mjs"):
        return _node_file(path, text, resolved)
    if path.suffix == ".c":
        return _c_file(path, text, resolved)
    if path.suffix == ".py":
        if re.search(r"^\s*(?:async\s+)?def\s+test", text, re.MULTILINE):
            return Target("python", path, resolved, "pytest reports a failure")
        if re.search(r"raise SystemExit|sys\.exit\((?!0\))", text):
            return Target("python", path, resolved, "the script exits nonzero")
        return Target("python", path, resolved, None, "it has no test and no nonzero exit")
    return Target(
        "file", path, resolved, None, f"nothing here reads a {path.suffix} file for one"
    )


def target_problem(token: str, target: Target, known: Evidence) -> str | None:
    """Why this target does not back a claim, or None when it does."""
    where = target.path.relative_to(ROOT)
    at = "" if str(where) == token else f" in {where}"
    if target.fails is None:
        return f"names {token}{at}, which cannot report a failure: {target.note}"
    execution = known.runs.get(target.run_path)
    if execution is None:
        run_where = target.run_path.relative_to(ROOT)
        through = "" if run_where == where else f", reached only through {run_where}"
        return f"names {token}{at}{through}, which no runner executes"
    if execution.tier != "GATE":
        return (
            f"names {token}{at}, which only {execution.runner} runs, "
            f"a REPORT lane whose failure is forgiven"
        )
    return None


def _path_in(token: str, where: Path | None) -> Path | None:
    """The file a claim's path token names, from the root or from its own seat.

    A path is read the way its READER would read it. cmetta.h sits in
    extensions/cmetta/ and cites `tests/test_cmetta.c`, which is exactly the
    file beside it and exactly what a reader of that seat types; resolving only
    against the repository root called ten such citations unbacked on the day
    the C seat first came under this lane. Root first, so a repository-relative
    spelling keeps its meaning, the citing file's own directory second, and the
    SEAT root third: extensions/cmetta/kit/driver.c cites `tests/test_kit.py`,
    which is neither beside it nor at the repository root but is exactly what a
    reader standing in extensions/cmetta/ types, and
    extensions/python/tests/ch17_concurrency_and_the_loop/test_async_space.py
    cites its own path from extensions/python/ the same way [measured
    2026-09-05: three citations, all of them real files, all of them read as
    naming nothing].
    """
    candidate = ROOT / token
    if candidate.is_file():
        return candidate
    if where is None:
        return None
    beside = where.parent / token
    if beside.is_file():
        return beside
    return next(
        (seat / token for seat in _seat_roots(where) if (seat / token).is_file()),
        None,
    )


def _seat_roots(where: Path) -> Iterator[Path]:
    """The seat directories a file sits under, innermost first.

    A seat is a directory holding its own control file, which is the same test
    build.sh and check.sh apply when they DISCOVER a component, so nothing here
    is a second list of what the seats are.
    """
    for parent in where.resolve().parents:
        if parent == ROOT:
            return
        if (parent / "check.sh").is_file() or (parent / "build.sh").is_file():
            yield parent


def resolve(
    token: str, known: Evidence, where: Path | None = None, *, quoted: bool = False
) -> list[Target] | str:
    """The targets a claim's token names, or why it names none.

    `quoted` is the author declaring that the token IS a name. It has to be
    asked FIRST, because a name written as a sentence -- which is how a
    `node --test` case and a C `CASE` name themselves -- carries spaces and
    fails IDENTIFIER, and everything IDENTIFIER rejects was answered with the
    empty list, meaning "this token names nothing and nothing is wrong with
    that". So a correct citation of a case and a citation of one that had been
    renamed were accepted for the same reason: neither was read. Six written on
    2026-09-07 named renamed cases and passed
    [source: docs/journal/2026-09-07-the-textbook-runs-in-the-browser.md].

    The two silent returns below keep that meaning for an UNQUOTED token, where
    it is right: a claim's prose sits in the same brackets as its names, and
    reading every English word in it as a citation would report far more
    correct headers than wrong ones. Quoting is what separates the two, and it
    is the author's own mark rather than a guess made here.
    """
    if quoted and (found := known.targets.get(token)):
        return found
    qualified = QUALIFIED.match(token)
    if qualified is not None:
        spelling, name = qualified.groups()
        basename = Path(spelling).name
        found = [
            target
            for target in known.targets.get(name, [])
            if target.path.name == basename or target.path == _path_in(spelling, where)
        ]
        if found:
            return found
        if basename in known.files or _path_in(spelling, where) is not None:
            return f"names {name}, which is not in {spelling}"
        return f"names the path {spelling}, which is not in the tree"
    if "/" in token or token.endswith(SUFFIXES):
        path = _path_in(token, where)
        if path is None:
            return f"names the path {token}, which is not in the tree"
        return [file_target(path, known.reports)]
    if not IDENTIFIER.match(token):
        return _unread(token, quoted=quoted)
    # A `unit:test` whose UNIT the tree knows is answered by that pair alone.
    # Falling back to the bare name let a citation name the right test under
    # the wrong unit and pass, which sends a reader to a unit the test is not
    # in; four in this tree did. The fallback stays for every other colon
    # shape -- a module-qualified predicate, say -- where the prefix names no
    # unit.
    if ":" in token:
        unit, _, bare = token.rpartition(":")
        if any(target.kind == "plunit-unit" for target in known.targets.get(unit, [])):
            if paired := known.targets.get(token):
                return paired
            if bare in known.targets:
                return f"names {bare}, which is a test but not one in {unit}"
            return f"names {token}, which is not a test in the tree"
    found = known.targets.get(token) or known.targets.get(token.rsplit(":", maxsplit=1)[-1])
    if found:
        return found
    if not NAME_SHAPED.search(token):
        return _unread(token, quoted=quoted)
    return f"names {token}, which is not a test in the tree"


def _unread(token: str, *, quoted: bool) -> list[Target] | str:
    """Nothing, unless the author quoted it, in which case it names nothing."""
    if not quoted:
        return []
    return f"names {token!r}, which is not a test in the tree"


#: The obligation-header scheme documents a tested tag as carrying either a
#: test name or an exact gate command, and the gate command half is this. It is
#: the right evidence for a claim no single test can carry: the llms.txt
#: checker's claim is that every name, path and count in the file holds, and
#: what proves it is running the lane. Reading the command as a list of test
#: names reported `sh` and `llms` as missing tests, which is the checker
#: failing to know its own scheme.
GATE_COMMAND = re.compile(
    # tools/ is where the driver lives; the bare spelling stays because a
    # citation written before the move still names the same command, and
    # without the prefix this fell through to the path rule and ACCEPTED a
    # lane the gate does not run, because tools/check.sh is a file.
    r"\b(?:GATE_ONLY=1\s+)?sh\s+(?:tools/)?check\.sh\s+([a-z0-9-]+)"
)

#: The other shape an exact gate command takes: an interpreter, the script it
#: runs, and that script's own flags, as in
#: `python extensions/python/tools/phrasebook.py --gate`. The lane above names a
#: LANE; this names the SCRIPT, and what makes it evidence is the same thing,
#: that a GATE lane runs it.
#:
#: Without this the body was split into words, and the leading interpreter was
#: read as a test NAME. Two such claims passed for as long as they had been
#: written because `python` happened to be the stem of a shipped example, the
#: one now at examples/ch11-python-as-a-notation/01-python.metta, so a
#: phrasebook claim was backed by an unrelated MeTTa program; giving that file
#: its reading-order number is what exposed it [measured 2026-08-27].
SCRIPT_COMMAND = re.compile(
    r"\b(?:python3?|swipl|node)\s+((?:[\w.-]+/)*[\w.-]+\.(?:py|pl|mjs|ts))\b"
)

#: The third shape, and the one the JavaScript seats actually use. The Node
#: seat's suite IS `npm run test:source` and the site's build IS
#: `npm run docs:build`; neither the lane shape nor the interpreter shape
#: reaches them, so the body was split into words and the path inside the
#: command was read as a test that is not in the tree. The script name is
#: checked against the manifests the repository ships, the same way a lane name
#: is checked against check.sh, so a command naming a script nobody defines is
#: still a finding.
NPM_COMMAND = re.compile(r"\bnpm\s+run\s+([A-Za-z0-9:_-]+)")

#: A shell RUNNER, which is the fourth shape and the one this repository writes
#: most: `sh extensions/python/test.sh <suite>` and `sh tests/shell/<name>.sh`.
#: Without it the body was split into words and the ENVIRONMENT ASSIGNMENT in
#: front of the command was read as a path, so
#: `CHECK_PY=$VENV/bin/python sh extensions/python/test.sh ...` reported
#: `CHECK_PY=$VENV/bin/python` as a file that is not in the tree [measured
#: 2026-09-05]. The script is what makes the command evidence, exactly as the
#: interpreter shape above decides on its script.
SHELL_COMMAND = re.compile(r"\bsh\s+((?:[\w.$-]+/)*[\w.-]+\.sh)\b")

#: The fifth, and the one the C seat writes: `make -C <seat> <target>`. Its
#: `-C <dir>` argument contains a slash, so word-splitting read the SEAT
#: DIRECTORY as a file and reported it missing; extensions/cmetta/sanitize.sh
#: cited its own lane that way. A make claim is backed when the seat's Makefile
#: defines the target, which is the same question evidence_runners already asks
#: with MAKE_RULE when it models what a lane runs.
MAKE_COMMAND = re.compile(r"\bmake\b[^\n]*?-C\s+([\w./-]+)\s+(?:--?\S+\s+)*([a-z][\w-]*)")

#: A Makefile target opens in column 1 and is followed by `:`, which `:=` is
#: not: a variable assignment names sources without defining a target.
MAKE_RULE = re.compile(r"^([A-Za-z][\w.-]*)\s*:(?!=)")


def npm_scripts() -> frozenset[str]:
    """Every script name a shipped package.json defines, node_modules aside."""
    import json

    names: set[str] = set()
    for pattern in ("package.json", "*/package.json", "*/*/package.json"):
        for manifest in owned(ROOT.glob(pattern), ROOT):
            if "node_modules" in manifest.parts:
                continue
            try:
                names.update(json.loads(manifest.read_text()).get("scripts", {}))
            except (OSError, ValueError):
                continue
    return frozenset(names)


#: How check.sh names a lane, so a command naming a lane that does not exist is
#: still a finding.
CHECK_LANE = re.compile(LANE_PREFIX + r"(?:GATE|REPORT)\s+([a-z0-9-]+)", re.MULTILINE)


def gate_lanes() -> frozenset[str]:
    """Every lane name the gate runs, the root driver's and each component's.

    `sh tools/check.sh <lane>` still names all of them, because the root driver
    SOURCES every component's check.sh and its `run` filters on the argument
    list, so a lane's file says nothing about whether the command works.
    Reading the root file alone said otherwise the moment a lane moved into a
    component, and it said it about a lane the gate runs [measured 2026-08-28:
    `sh tools/check.sh mypy ty` in extensions/python/metta/_declare/rules.py:13 read as
    naming a lane check.sh does not run, one commit after mypy moved into
    extensions/python/check.sh].
    """
    return frozenset(
        lane for script in gate_scripts() for lane in CHECK_LANE.findall(_text(script))
    )


def make_targets(recipe: Path) -> frozenset[str]:
    """Every target one Makefile defines."""
    return frozenset(
        matched.group(1)
        for line in _text(recipe).splitlines()
        if (matched := MAKE_RULE.match(line))
    )


def gate_command_problems(
    body: str, known: Evidence, where: Path | None = None
) -> list[str] | None:
    """None when the body is not a gate command; otherwise what is wrong with it."""
    match = GATE_COMMAND.search(body)
    if match is not None:
        lane = match.group(1)
        if lane in gate_lanes():
            return []
        return [f"names the check.sh lane {lane}, which the gate does not run"]
    match = NPM_COMMAND.search(body)
    if match is not None:
        script = match.group(1)
        if script in npm_scripts():
            return []
        return [f"names the npm script {script}, which no package.json defines"]
    match = MAKE_COMMAND.search(body)
    if match is not None:
        seat, target = match.group(1), match.group(2)
        recipe = ROOT / seat / "Makefile"
        if not recipe.is_file():
            return [f"names make -C {seat}, which holds no Makefile"]
        if target in make_targets(recipe):
            return []
        return [f"names the {seat} make target {target}, which its Makefile does not define"]
    match = SHELL_COMMAND.search(body) or SCRIPT_COMMAND.search(body)
    if match is None:
        return None
    named = match.group(1)
    found = resolve(named, known, where)
    if isinstance(found, str):
        return [found]
    verdicts = [target_problem(named, target, known) for target in found]
    return [verdicts[0]] if verdicts and all(verdicts) else []


def tested_problems(body: str, known: Evidence, where: Path | None = None) -> list[str]:
    """What is wrong with one `tested` tag, or nothing when every name it gives holds up."""
    command = gate_command_problems(body, known, where)
    if command is not None:
        return command
    stripped = DATE.sub("", body)
    problems = []
    # A `node --test` case names itself in PROSE, so a claim that points at one
    # has to be able to quote it. The quoted segments are taken whole and
    # removed before the rest is split on whitespace, which is what keeps
    # "makes === structural" one name instead of three words that are none.
    quoted = [" ".join(found.split()) for found in QUOTED_NAME.findall(stripped)]
    for token in [*quoted, *re.split(r"[\s,;]+", QUOTED_NAME.sub(" ", stripped))]:
        # A quoted token is EXACT: the author's own quotes say where the name
        # begins and ends, and the sentence's punctuation is outside them. The
        # strip below is for a bare word the prose put a comma or a bracket
        # against, and applying it to a quoted name took the parentheses off
        # `"re-raises an unhandled step failure from settled()"`, which is the
        # case's real name, and reported the citation as naming nothing.
        was_quoted = token in quoted
        if not was_quoted:
            token = token.strip(" :.'\"`()")
        if not token or token.lower() in PROSE:
            continue
        found = resolve(token, known, where, quoted=was_quoted)
        if isinstance(found, str):
            problems.append(found)
            continue
        # A name can be defined more than once. One good definition backs the
        # claim, so only report when every one of them fails.
        verdicts = [target_problem(token, target, known) for target in found]
        if verdicts and all(verdicts):
            problems.append(verdicts[0])
    return problems


def time_problems(body: str) -> list[str]:
    """What is wrong with a tag's time, in any kind: a time after its date that is not a whole stamp.

    The stamp is how a claim is aged and how the tree it ran on is found, the
    first commit carrying it, so a time that cannot be read back as the moment
    the evidence ran leaves the claim unaged whatever it says. A date with no
    time is a tag from before the rule and is read as it always was.

    Nothing read a time before this. A malformed one passed in every kind, and
    a stamp glued to the name after it, `...+10:00:name`, hid the name: the two
    read as one token IDENTIFIER rejects, which resolve() answers with nothing,
    so a citation of a test that does not exist passed unread. A well-formed
    stamp followed by a space is left to that same rule, since no time is an
    IDENTIFIER, and the self-test's stamped citations pin it.
    """
    problems = []
    for found in TIME.finditer(body):
        written = found.group(0).rstrip(":.")
        if "T" in written and not _whole_stamp(written):
            problems.append(
                f"carries the time {written}, which is not a whole `date -Iseconds` "
                "stamp (YYYY-MM-DDTHH:MM:SS+HH:MM)"
            )
    return problems


def _whole_stamp(written: str) -> bool:
    """Whether a tag's time is the whole of what `date -Iseconds` prints, at a time that exists."""
    if not STAMP.fullmatch(written):
        return False
    try:
        datetime.fromisoformat(written)
    except ValueError:
        return False
    return True


def measured_problems(body: str, known: Evidence, where: Path | None = None) -> list[str]:
    """What is wrong with one `measured` tag, which needs a date so it can go stale."""
    problems = []
    if not DATE.search(body):
        problems.append("carries no YYYY-MM-DD date, so the claim cannot go stale")
    # A measurement often names the test that guards it, in the same brackets,
    # as "measured <date>: <numbers>; tested <name>". That name is a tested
    # claim wherever it sits, and reading only the outer tag let one of them
    # name nothing for as long as it had been written.
    nested = re.split(r"\btested\b", body, maxsplit=1)
    if len(nested) == 2:
        problems.extend(tested_problems(nested[1], known, where))
    return problems


def source_problems(body: str) -> list[str]:
    """What is wrong with one `source` tag, which needs a date, a reference or a name."""
    if DATE.search(body) or REFERENCE.search(body) or len(body.split()) >= 3:
        return []
    return ["carries neither a date, a reference, nor a named document"]


#: Where the gate allocates this repository's own scratch, and therefore what
#: a tag may not offer as its evidence. Read from the runner that declares it
#: rather than spelled here, so one fact has one authority, and reported rather
#: than guessed at when the assignment moves -- the rule evidence_runners'
#: collectors already follow, because a scratch root this cannot find is a
#: refusal that has silently stopped refusing.
SCRATCH_ANCHOR = "tests/checks/gate_scratch.sh"
SCRATCH_BASE = re.compile(r'METTA_GATE_SCRATCH_BASE="\$root/([\w.-]+)/')


def scratch_root() -> tuple[str | None, list[str]]:
    """The directory this repository's own scratch goes under, or why not."""
    where = ROOT / SCRATCH_ANCHOR
    found = SCRATCH_BASE.search(_text(where)) if where.is_file() else None
    if found is None:
        return None, [
            f"{SCRATCH_ANCHOR}: no METTA_GATE_SCRATCH_BASE assignment, so the "
            f"scratch directory a claim may not name cannot be read"
        ]
    return found.group(1), []


def scratch_problems(body: str, under: re.Pattern[str], root: str) -> list[str]:
    """Paths a tag offers as evidence that go with the checkout that wrote them.

    An untracked fixture makes a claim unfalsifiable: it was true for whoever
    ran it and there is nothing a reader can do about it either way. This tree
    carried 73 such tags, 65 measured and 8 source, and not one of the 64
    distinct paths in them still existed anywhere on the machine that wrote
    them [measured 2026-09-07].

    The rule is what a tag OFFERS, not where the word appears. Prose may name
    the convention -- .gitignore does, gate_scratch.sh's own Guarantees line
    does, DEVELOPING.md's `ai-tmp/check-runs` does -- because none of that is
    a tag. And an `assumed` tag may name one, because that is precisely where a
    claim records the fixture it lost; only the three tags that assert evidence
    are refused. So the exemption is a rule rather than a list of files.
    """
    return [
        f"names {token}, which is under {root}/, this repository's scratch: it "
        f"goes with the checkout that wrote it, so no reader can re-run the "
        f"claim. Track the fixture, or say `assumed` and name what is missing"
        for token in dict.fromkeys(under.findall(body))
    ]


COMMIT = re.compile(r"\bcommit=([0-9a-zA-Z]+)")

#: The in-progress spelling of a commit pin before RULE_INSTANT, spelled ONCE
#: here and referenced everywhere else, including by the self-tests, which
#: import it. A provenance sweep resolved every pin in the tree to an object
#: ID by replacing this word, and on 2026-08-31 one reached into the messages
#: below and into the self-test's planted fixture: the checker still tested
#: the word while the self-test planted an object ID, so the two halves
#: disagreed about what a placeholder is and the release rule went untested.
#: One occurrence of the word cannot desynchronise from itself. Since the rule
#: a tag carries its stamp instead, and the word stands only on legacy lines.
PLACEHOLDER = "WORKTREE"



#: git blame's object ID for a line no commit carries yet, as a SHA-1 or a
#: SHA-256 repository spells it.
UNCOMMITTED = re.compile(r"0{40}(?:0{24})?")
#: The object ID opening each line's entry in `git blame --line-porcelain`.
OBJECT = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
#: How far into a file git looks for a NUL before calling it binary, the test a
#: file has to pass to hold a tag at all [source 2026-09-25T01:14:53+10:00:
#: https://github.com/git/git/blob/67ad42147a7acc2af6074753ebd03d904476118f/xdiff-interface.c#L197-L203,
#: buffer_is_binary].
BINARY_PREFIX = 8000
#: One line of `git submodule status --recursive`: a status character, the
#: checked-out commit, the path, and git describe's answer in parentheses when
#: it has one. A status of `-` is a component that is not checked out, whose
#: files are not here to read [source 2026-09-25T01:14:47+10:00:
#: git-submodule(1), status].
SUBMODULE = re.compile(r"^(?P<status>[ +U-])[0-9a-f]+ (?P<path>.+?)(?: \(.*\))?$")


def _git(repository: Path, *arguments: str) -> str:
    """What one git command answers in `repository`, or a RuntimeError naming its refusal."""
    done = subprocess.run(
        ["git", *arguments], cwd=repository, capture_output=True,
        encoding="utf-8", errors="replace", check=False,
    )
    if done.returncode != 0:
        msg = f"git {arguments[0]} refused {repository}: {done.stderr.strip()}"
        raise RuntimeError(msg)
    return done.stdout


@cache
def _repositories() -> tuple[Path, ...]:
    """This checkout and every component repository checked out inside it, nested ones included.

    A component is a submodule, so its history is its OWN: a file under
    extensions/python cites a commit that `git cat-file` at the root cannot
    name, and resolving only at the root reported fifteen true citations in the
    Node seat and three in the Python one as unresolvable. A commit is pinned
    here if ANY repository in the checkout holds it, which is the permissive
    direction and the honest one, since a cross-cutting change is cited from a
    component just as a component's own change is.

    Asked of git rather than globbed. The `*/.git` and `*/*/.git` globs this
    replaced stopped two directories down, where the twins repository is a
    submodule of extensions/python four down, so its commits and its lines
    were out of reach, and they took in every worktree and test repository
    that happened to sit two down [measured 2026-09-25T01:39:33+10:00: on the
    shared checkout they answered 85 entries, 75 of them worktrees in its
    scratch directory and two test repositories under repos/, and neither the
    twins repository nor the one inside it; submodule status answers the nine
    components].
    """
    repositories = [ROOT]
    for line in _git(ROOT, "submodule", "status", "--recursive").splitlines():
        found = SUBMODULE.match(line)
        if found is None:
            msg = f"git submodule status answered a line this does not read: {line!r}"
            raise RuntimeError(msg)
        if found["status"] != "-":
            repositories.append(ROOT / found["path"])
    return tuple(repositories)


@cache
def _resolves_in(oid: str, repository: Path) -> bool:
    """Whether `repository` names OID as a commit."""
    answer = subprocess.run(
        ["git", "cat-file", "--batch-check"],
        cwd=repository,
        input=f"{oid}^{{commit}}\n",
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    return " commit " in f" {answer.strip()} "


def _resolves_anywhere(oid: str) -> bool:
    """Whether any repository in this checkout names OID as a commit."""
    return any(_resolves_in(oid, repository) for repository in _repositories())


def commit_problems(sites: list[tuple[Path, int, str, str]]) -> list[str]:
    """Check every pinned object ID, in every site the globs read.

    A tag's commit= names the repository state that produced its evidence. A
    commit that no longer resolves is an unbacked claim of the same kind the
    rest of this file refuses, so it is a finding. The placeholder names no
    object and placeholder_problems counts it instead.
    """
    wanted: dict[str, list[str]] = {}
    for path, line, tag, body in sites:
        for oid in COMMIT.findall(body):
            if oid != PLACEHOLDER:
                wanted.setdefault(oid, []).append(f"{path.relative_to(ROOT)}:{line}: {tag}")
    return [
        f"{site}: commit={oid} does not resolve to a commit"
        for oid, where in wanted.items()
        if not _resolves_anywhere(oid)
        for site in where
    ]


def reached() -> set[Path]:
    """Every file either half of the evidence globs reaches."""
    return {path for glob in (*SOURCES, *PROVENANCE_SOURCES) for path in owned(ROOT.glob(glob), ROOT)}


def placeholder_problems(files: set[Path]) -> tuple[set[tuple[Path, int]], list[str]]:
    """Every `commit=WORKTREE` pin in these files as (path, line), and what is wrong around them.

    Which occurrences ARE pins is lexical: one inside a string literal belongs
    to code that emits or matches pins, and one inside a hash-chained record is
    an account of what was believed rather than a source pin. evidence_sites
    decides that per file class and is the only place it is decided. A second
    model is what the release count once kept, and it had desynchronised
    twice: the provenance pass declined 93 occurrences while RELEASE=1 counted
    them, 85 in the record and one in the regex of the very checker that
    matches pins.

    Two findings come with the count: a file whose grammar cannot be read far
    enough to tell a pin from code, and a tracked file holding a pin that no
    glob reaches, so nothing reads the claims around it.

    Imported inside the function because evidence_sites imports this module for
    the tag grammar and the placeholder word. Deferring the one edge keeps each
    definition in the module that owns it rather than splitting the grammar
    readers across both.
    """
    from evidence_sites import UnclassifiableError, sites, unscanned

    pins: set[tuple[Path, int]] = set()
    findings: list[str] = []
    for path in sorted(files):
        text = _text(path)
        if PLACEHOLDER not in text:
            continue
        try:
            found = sites(path.relative_to(ROOT), text)
        except UnclassifiableError as error:
            findings.append(f"{error}; so its placeholders cannot be told from code")
            continue
        pins.update((path, line) for _at, line, reason in found if reason is None)
    findings.extend(
        f"{path.relative_to(ROOT)}: {count} pin(s) OUTSIDE the evidence gate's globs, "
        f"so nothing reads this file's claims; add its glob to check_evidence_tags.SOURCES"
        for path, count in unscanned(files, ROOT)
    )
    return pins, findings


def _names(listing: str) -> list[str]:
    """The paths a `-z` git listing answers."""
    return [name for name in listing.split("\0") if name]


def _history(repository: Path, instant: int) -> tuple[bool, bool]:
    """Whether a commit here is dated at or after the instant, and whether none before it descends from one.

    The second is what makes `git blame --since` exact. Blame hands a line from
    a commit to its parent until it reaches the commit that wrote it, and stops
    at the first commit dated before the bound, so it misdates a line only by
    meeting a commit dated before the instant on its way down from HEAD, and
    every commit on that way descends from the one that wrote the line.
    """
    dates: dict[str, int] = {}
    parents: dict[str, list[str]] = {}
    for row in _git(repository, "rev-list", "--timestamp", "--parents", "HEAD").splitlines():
        stamp, commit, *above = row.split()
        dates[commit] = int(stamp)
        parents[commit] = above
    after = any(date >= instant for date in dates.values())
    ordered = not any(
        dates[commit] < instant and any(dates.get(parent, 0) >= instant for parent in above)
        for commit, above in parents.items()
    )
    return after, ordered


def _written_since(repository: Path, name: str, lines: list[int], instant: int, *, bounded: bool) -> set[int]:
    """Which of these lines of `name`'s working-tree text git blame dates at or after the instant.

    One blame per file, over its tag and pin lines alone. -M follows a line
    moved within the file and -C one moved from a file the same commit
    changed. A line no commit carries has the all-zero object ID and the
    current time, and either makes it written since.
    """
    spans: list[list[int]] = []
    for line in sorted(set(lines)):
        if spans and spans[-1][1] + 1 == line:
            spans[-1][1] = line
        else:
            spans.append([line, line])
    arguments = ["blame", "-M", "-C", "--line-porcelain"]
    if bounded:
        arguments.append(f"--since={RULE_INSTANT}")
    for low, high in spans:
        arguments += ["-L", f"{low},{high}"]
    written: set[int] = set()
    line = 0
    for row in _git(repository, *arguments, "--", name).split("\n"):
        if row.startswith("\t"):
            continue
        head = row.split(" ")
        if len(head) >= 3 and OBJECT.fullmatch(head[0]):
            line = int(head[2])
            if UNCOMMITTED.fullmatch(head[0]):
                written.add(line)
        elif head[0] == "committer-time" and int(head[1]) >= instant:
            written.add(line)
    return written


def rule_era_problems() -> tuple[list[str], int, int, set[tuple[Path, int]], list[Path]]:
    """Every tag and pin on a line written since RULE_INSTANT that is not in the rule's form.

    Its domain is every file git sees in each repository of the checkout, not
    the evidence globs, so no file class escapes it: the files a commit dated
    since the instant touched, those carrying an uncommitted edit, and every
    untracked file git does not ignore. A line in one is written since when git
    blame dates it at or after the instant, and every line of an untracked file
    is. A tag or pin there that evidence_sites places in prose must be in the
    rule's form: a tag carries a whole stamp, in every kind, and a pin says
    neither `commit=WORKTREE` nor a commit its own repository names. Another
    repository's commit passes, since only a commit of its own repository
    cannot contain the claim that names it.

    `git log --since-as-filter` picks the files rather than --since, and the
    blame is bounded by --since only where _history says it is exact: --since
    stops at the first commit dated before the date, so a commit backdated on
    top of one dated after the instant hid that commit from `git log --since`
    and blamed its lines to itself under `git blame --since`
    [measured 2026-09-25T01:39:16+10:00: git 2.53.0, a commit dated
    2026-09-25T00:00:00+10:00 under one dated 2026-09-24T12:00:00+10:00; `git
    log --since` named neither, `--since-as-filter` named the first, and `git
    blame --since` blamed its line to the second as a boundary where plain
    blame gave the first].

    Answers the findings; how many tags and pins on lines written since were
    held to the rule, and in how many files; where a line written since says
    `commit=WORKTREE`, which the legacy count leaves out; and the repositories
    blamed over their whole history because their dates are out of order.

    Time, with R repositories, H commits in one's history, F files touched
    since the instant, uncommitted or untracked, and h the commits since the
    instant that touched one of them: per repository one `git rev-list
    --timestamp --parents` over its whole history, O(H), one `git log
    --since-as-filter`, which walks O(H) and lists O(F), one `git diff` and
    one `git ls-files`; then one `git blame -L` per file holding a tag or pin,
    over those lines alone, walking h commits under --since and the file's
    whole history when the dates are out of order. Blames run only on files
    touched since the instant, so the work is O(R * H + F * h) in date order
    [measured 2026-09-25T01:43:59+10:00: 0.71s at the least of three runs over
    the shared checkout, R = 10 repositories, F = 39 files holding 104 tags and
    pins on lines written since, the whole lane 9.17s against 8.35s before it].
    """
    from evidence_sites import UnclassifiableError, classify

    instant = int(datetime.fromisoformat(RULE_INSTANT).timestamp())
    findings: list[str] = []
    held = 0
    files = 0
    fresh: set[tuple[Path, int]] = set()
    unordered: list[Path] = []
    for repository in _repositories():
        after, ordered = _history(repository, instant)
        if not ordered:
            unordered.append(repository)
        names = set(_names(_git(repository, "diff", "HEAD", "--name-only", "-z")))
        if after:
            names.update(_names(_git(
                repository, "log", f"--since-as-filter={RULE_INSTANT}", "--format=",
                "--name-only", "--diff-merges=first-parent", "-z", "HEAD",
            )))
        untracked = set(_names(_git(repository, "ls-files", "--others", "--exclude-standard", "-z")))
        for name in sorted(names | untracked):
            path = repository / name
            if path.is_symlink() or not path.is_file():
                continue
            raw = path.read_bytes()
            if b"\0" in raw[:BINARY_PREFIX]:
                continue
            text = raw.decode("utf-8", errors="replace")
            breaks = [found.start() for found in re.finditer("\n", text)]
            placed = [
                (bisect_left(breaks, found.start()) + 1, bisect_left(breaks, found.end() - 1) + 1, found)
                for pattern in (CLAIM, COMMIT) for found in pattern.finditer(text)
            ]
            if not placed:
                continue
            lines = [line for first, last, _found in placed for line in range(first, last + 1)]
            era = set(lines) if name in untracked else _written_since(
                repository, name, lines, instant, bounded=ordered)
            chosen = [(first, found) for first, last, found in placed
                      if any(line in era for line in range(first, last + 1))]
            if not chosen:
                continue
            files += 1
            relative = path.relative_to(ROOT)
            try:
                sides = classify(relative, text, [found.start() for _first, found in chosen])
            except UnclassifiableError as error:
                findings.append(f"{error}; it holds a tag or pin on a line written since {RULE_INSTANT}")
                continue
            for (first, found), side in zip(chosen, sides, strict=True):
                if side is not None:
                    continue
                held += 1
                where = f"{relative}:{first}"
                if found.re is CLAIM:
                    if not any(_whole_stamp(time.group(0).rstrip(":.")) for time in TIME.finditer(found.group(2))):
                        findings.append(
                            f"{where}: {found.group(1).lower()}: written since {RULE_INSTANT} without a "
                            f"whole `date -Iseconds` stamp, which every tag written since carries"
                        )
                elif found.group(1) == PLACEHOLDER:
                    fresh.add((path, first))
                    findings.append(
                        f"{where}: commit={PLACEHOLDER} written since {RULE_INSTANT}, where a tag "
                        f"carries the time its evidence ran instead"
                    )
                elif _resolves_in(found.group(1), repository):
                    findings.append(
                        f"{where}: commit={found.group(1)} written since {RULE_INSTANT} names a commit "
                        f"of its own repository, {repository.relative_to(ROOT)}, where a tag carries "
                        f"the time its evidence ran instead"
                    )
    return findings, held, files, fresh, unordered


def provenance_sites() -> list[tuple[Path, int, str, str]]:
    """Commit pins in commentless formats, for the pin check and nothing else."""
    sites: list[tuple[Path, int, str, str]] = []
    for glob in PROVENANCE_SOURCES:
        for path in owned(ROOT.glob(glob), ROOT):
            text = _text(path)
            for line, body in enumerate(text.split("\n"), start=1):
                if "commit=" in body:
                    sites.append((path, line, "measured", body))
    return sites


def claim_sites() -> list[tuple[Path, int, str, str]]:
    """Every evidence tag the tree carries, as (path, line, kind, body)."""
    sites: list[tuple[Path, int, str, str]] = []
    for glob in SOURCES:
        for path in owned(ROOT.glob(glob), ROOT):
            text = _text(path)
            for match in CLAIM.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                # Escapes first, so a literal `\n` becomes the line break it
                # spells and the comment marker behind it is one COMMENT_PREFIX
                # can then strip. The other order leaves ` * ` in the middle of
                # a generator's claim.
                spelled = ESCAPE.sub(
                    lambda found: UNESCAPED.get(found.group(1), found.group(1)),
                    match.group(2),
                )
                sites.append((path, line, match.group(1).lower(),
                              COMMENT_PREFIX.sub(" ", spelled)))
    return sites


def untagged_guarantees() -> list[str]:
    """Guarantees carrying no evidence tag at all.

    The tags this file already checks are the ones somebody WROTE. A guarantee
    with no tag was reasoned to, and reads in the same voice as a measured
    fact: `lib_text`'s header stated one confidently while plunit was
    reporting eight tests succeeding with a choicepoint underneath it. Fourteen
    were found the first time this ran, and twelve of them turned out to have a
    test already, uncited.

    `[assumed <date>]` is a pass here, deliberately. It costs nothing to write
    and it is the only thing that makes an unverified claim visible as one.

    GUARANTEE_SOURCES rather than SOURCES, and the split is the point: this
    obligation is stricter than "a tag that names something must be backed",
    and coupling them meant a file class could only join the tag check by
    clearing this one first. Seventeen classes had already cleared the tag
    check and were held out by fifty untagged shell guarantees
    [measured 2026-09-05].
    """
    block = re.compile(
        r"Guarantees:\n(.*?)\n(?:%|#|\s)*?"
        r"(?:Guarded by|Owns|Decides|Open Obligations|Fails when|Assumes):",
        re.DOTALL,
    )
    findings: list[str] = []
    for glob in GUARANTEE_SOURCES:
        for path in owned(ROOT.glob(glob), ROOT):
            found = block.search(_text(path))
            if found is None:
                continue
            for item in re.split(r"\n\s*[%#]?\s*-\s", "\n" + found.group(1)):
                item = item.strip()
                if not item or re.search(r"\[(tested|measured|source|assumed)\b", item):
                    continue
                summary = " ".join(item.split())[:70]
                findings.append(
                    f"{path.relative_to(ROOT)}: guarantee with no evidence tag: {summary}"
                )
    return findings


def main() -> int:
    """Report every tag with nothing behind it, and say how many were read."""
    known, findings = gather()
    # The door table's contracts are evidence of the same kind, read through
    # its generator where the tree carries one. A tree without it (the
    # selftest's fixture trees, a checkout of the engine alone) has no door
    # rows to check, and says so in the summary rather than failing to
    # import: the gate crashing here printed no report at all, and a selftest
    # read every planted bad citation as accepted.
    tools = ROOT / "extensions/python/tools"
    if (tools / "doorgen.py").is_file():
        sys.path.insert(0, str(tools))
        from doorgen import contract_findings

        findings += contract_findings(root=ROOT)
        doors = "door contracts read through doorgen"
    elif (ROOT / "extensions/python/metta/doors/__init__.py").is_file():
        # The table without its generator is a seat with a piece missing, not
        # a tree without doors: refuse rather than read nothing.
        findings.append(
            "extensions/python/metta/doors/__init__.py: a door table with no "
            "extensions/python/tools/doorgen.py to read its contracts"
        )
        doors = "door table present, its generator absent"
    else:
        doors = "no door table in this tree, so no door contracts read"
    findings += untagged_guarantees()
    sites = claim_sites()
    findings += commit_problems(sites + provenance_sites())
    placeholders, trouble = placeholder_problems(reached())
    findings += trouble
    root, trouble = scratch_root()
    findings += trouble
    under = re.compile(rf"(?<![\w/-]){re.escape(root or 'ai-tmp')}/[\w./$-]*")
    checked = 0
    for path, line, tag, body in sites:
        # A tag's time is read in every kind: one that cannot be read back
        # leaves the claim unaged, whatever the claim is.
        problems = time_problems(body)
        # An assumed claim is otherwise unchecked on purpose: it is the honest
        # tag for a claim nobody has verified, and demanding evidence for it
        # would push authors back to stating unverified claims in the same
        # voice as measured facts. Its commit pin was read above, where the
        # word does not matter.
        if tag != "assumed":
            checked += 1
            if tag == "tested":
                problems += tested_problems(body, known, path)
            elif tag == "measured":
                problems += measured_problems(body, known, path)
            else:
                problems += source_problems(body)
            if root is not None:
                problems += scratch_problems(body, under, root)
        for problem in problems:
            findings.append(f"{path.relative_to(ROOT)}:{line}: {tag}: {problem}")
    era, held, touched, fresh, unordered = rule_era_problems()
    findings += era
    order = "".join(
        f", {repository.relative_to(ROOT)} blamed over its whole history since a "
        f"commit dated before the instant descends from one after it"
        for repository in unordered
    )
    for finding in findings:
        print(finding)
    print(
        f"{len(findings)} unbacked evidence tag(s) in {checked} claims, against "
        f"{len(known.targets)} known test names in {len(known.runs)} files a runner "
        f"executes; {held} tag(s) and pin(s) held to the stamp rule on lines written "
        f"since {RULE_INSTANT}, in {touched} file(s){order}; {len(placeholders - fresh)} "
        f"legacy commit={PLACEHOLDER} placeholder(s), which stay until their evidence "
        f"is re-run; {doors}"
    )
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
