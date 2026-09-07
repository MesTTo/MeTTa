# A citation of a sentence is read
Goal: the evidence gate checks a citation of a `node --test`, browser or C
case instead of accepting it for the wrong reason, and no tag offers a fixture
that goes with the checkout that wrote it.
Constraint: the checker reads only. No engine, no imports from the package, so
it runs on a tree that does not boot and finishes in well under a second.

## 2026-09-07

Tried: the browser-textbook branch's experiment, re-run on this trunk -- move
the quoted lookup ahead of `IDENTIFIER` in `resolve/3` and see what the lane
says -> 41 quoted names reported, against the 45 that branch recorded; the tree
has moved through four wave merges since. 201 further quoted tokens already
resolved, so the mechanism was never the whole of it.

Decided: the silent drop is right for an UNQUOTED token and wrong for a quoted
one. A claim's prose sits in the same brackets as its names and `PROSE` cannot
list every English word an author might use, so a bare word the tree does not
define stays unread. Quoting is the author saying "this is a name", and it is
the author's own mark rather than a guess made here, so a quoted token that
resolves against nothing is a finding. `resolve/3` takes `quoted` and the two
silent returns answer it.

Tried: reading the 41 as renames -> most were not. Three defects in the
HARVESTER accounted for 34 of them.

  - `NODE_TEST` matched `it(` and `describe(` and not `test(`, which is
    `node:test`'s own primary export and the only shape
    `tools/browser.test.mjs` and the TypeScript space example's suite use. 38
    cases, none of them registered.
  - Its closing quote was whichever of `"`, `'` or `` ` `` came first rather
    than the one that opened. 21 of the Node seat's cases are named
    `"... the engine's own"` and every one was registered truncated at the
    apostrophe, so a citation spelling the real name matched nothing while one
    stopping mid-word would have passed. Fixed with a backreference.
  - `tested_problems` stripped `` :.'`() `` off every token. For a bare word
    that is the prose's punctuation; for a quoted name the quotes are already
    the delimiters, and the strip turned
    `"re-raises an unhandled step failure from settled()"` into a citation of
    nothing.

Decided: the harvester discovers suites the way `_prolog_suites` and
`_c_targets` already discover theirs. `extensions/node/test/*.test.ts` was one
glob and the tree has suites in three places; the rule is now node's own naming
convention -- `*.test.ts`, `*.test.mjs`, `*.test.js` and their module variants
-- over the whole tree with build output pruned, so a seat or an EXAMPLE that
grows a suite is covered without an edit.

Decided: a C suite names each case twice and both names resolve. `static void
test_objects_cross(void)` is the unit `main()` dispatches; the `CASE("...")`
inside it sets `current_case`, which the CHECK macro prints when a check fails,
so the sentence is the name a reader is actually shown. 96 of them in
`test_cmetta.c` against 45 case functions. A CASE inherits its function's
verdict, so one inside a function `main()` never calls is as dead as the
function.

Tried: the runner census as it stood, against what the manifests say ->
`npm run test|typecheck|kit` was modelled as "every `<package>/test/*.test.ts`".
It attributed 35 files to `typecheck`, which compiles and runs nothing, and saw
none of `tools/browser.test.mjs`, which `.github/workflows/checks.yml` runs as
`npm run test:browser --prefix extensions/node`.
Rejected: widening the glob, because the glob was the mistake. The manifest's
`scripts` map is the seat's own declaration of what each name runs, exactly as
check.sh's `run` lines are the gate's and a Makefile's targets are the C seat's,
and `make_requests` already reads one rather than guessing.
Decided: expand `npm run` through the manifest, transitively, and read
`node --test`'s selection out of the result.

Tried: `--prefix` handled by stopping at the script name -> the workflow's own
call reads as running in whatever package the lane's path reached first. npm
takes its flags on either side of the name, so the whole call is scanned for
the prefix and the first bare word is the script.

Tried: resolving `node --test "build/test/*.test.js"` by globbing it -> right
here, wrong on a fresh clone, where `build/` does not exist and all 35 suites
would read as run by nothing. Measured by moving `extensions/node/build` aside:
37 suites still recorded, 0 problems.
Decided: translate the PATTERN through the project file's `outDir` and
`rootDir` rather than the files it matches. The build is part of the same
command, so the files are there when node opens them.

Tried: the lane over the whole tree with the quoted lookup in place -> 0
unbacked tags in 6,075 claims, against 11,090 known names in 871 files a runner
executes, from 10,949 in 833 before.

## 2026-09-07, the audit

Six citations survived the harvester fixes and each was decided on its own.

| where | cited | outcome |
|---|---|---|
| `extensions/node/src/lint.ts:11` | `"changes nothing it looks at"` | a fragment; the case is `"finds what it carries rules for, and changes nothing it looks at"` |
| `extensions/node/src/tokens.ts:14` | `"replaces a pattern's meaning"` | renamed; the case gained `", for future parses only"` |
| `extensions/node/src/define/facts.ts:15` | `"reads a definition's own facts without defining it"` | a describe and an it read as one sentence; now cites both |
| `extensions/node/src/define/facts.ts:20` | `"joins the effect of every head the body reaches"` | renamed to `"names every head the body reaches, and joins their effects"` |
| `extensions/node/src/wire.ts:324` | `"writes a wide integer as a JSON number after the engine has booted"` | named no case at all; the case was written |
| `tests/checks/check_pin_provenance_selftest.py:184` | `', f'` | a fixture line wrote `[tested:` literally, against that file's own convention, and the tag ran across two lines of Python quoting |

Decided: `wire.ts`'s claim gets the test rather than an `assumed` tag. The
hazard is real and cheap to pin -- `JSON.stringify` asks a value for `toJSON`
before it reaches a replacer, and booting this seat's engine installs
`BigInt.prototype.toJSON`, so a replacer never sees the bigint and the gateway
wrote `["n", "1"]` for the integer 1. The case lives in `remote.test.ts`,
where every test already runs after an engine has booted, and it asserts the
precondition too, so a runtime that stops installing `toJSON` says so instead
of passing quietly.

Tried: reading `extensions/python/tools/vocabgen.py`'s claims -> two copies of
one name, `the engine\'s own` and a `\n`-wrapped variant, because the generator
holds its output's whole contract block in a Python string literal and the
gate read the literal's escaping. The generator is where a wrong name has to be
fixed, since the next `--write` puts it back, so the claim is unescaped before
it is read and the two copies now answer as the one name the generated file
carries.

## 2026-09-07, the scratch fixtures

Tried: `git grep -n 'ai-tmp/'` over tracked files -> 149 lines. Of those, 73
sat inside an evidence tag, naming 64 distinct paths.
Tried: looking for those 64 anywhere on the machine that wrote them -> 0 found.
Every one had gone with its checkout.

Rejected: refusing any IGNORED path inside a tag, which is the general form of
the rule. It fires on 126 tags across three unrelated classes -- the workspace's
`ai-*.md` ledgers, a dependency's own source under `node_modules/`, a build
artefact like `engine/reader.so` -- and conflates "the workspace keeps its
ledgers outside the repository" with "the fixture is gone". Revisit if the
ledger convention changes.
Decided: the refusal is on the SCRATCH root, read from
`tests/checks/gate_scratch.sh`, which is where the gate declares it, so one
fact has one authority and a runner that stops declaring it is reported rather
than silently accepted. `assumed` is exempt, because that is where a claim
records a fixture it lost, and prose outside a tag is untouched, which is what
makes `.gitignore`, `check.sh`'s report directory and DEVELOPING's
`ai-tmp/check-runs` exempt by a rule rather than by a list.

Tried: retagging all 65 `measured` claims as `assumed` -> wrong, and the tree
had already said so. `082f0e70`, committed the same day, reworded three tags of
exactly this shape to cite the reproduction rather than the scratch file it ran
in. Reading the 65 with their surrounding prose, every one already states its
own reproduction: the forms run and the answers on both engines, the counter
and the workload, the two arms and their numbers. The path was the only part
nobody could use.
Decided: delete the scratch citation and leave the claim `measured`. Two
mechanical passes were written and both reverted before the third landed -- the
first left the text after a tag unwrapped and did not know Python's `#:`
comment prefix, the second pulled C code into a comment by rewrapping past a
`*/` -- so the 73 were applied as explicit per-site replacements instead.

Decided: the four citations of Rw-Prolog get an upstream pin. It is a public
project and the clone lived in scratch only because that is where clones go, so
the citation becomes `github.com/cbarrick/Rw-Prolog` at
`634ad2577ca778e3436d8a596e0d35e0cf0785d2`. Every claim was re-read at that
commit before the pin was written: `redex/3` calls `subsumes_term/2` on either
side of its condition at `src/rewrite.pl:48-50`, its rule shape is
`Pattern:=Template:-Condition` at `:40`, and `call_rw/2`'s own comment says the
control predicates "cannot be overridden by rewrite rules" at `:151-152`.

## 2026-09-07, the example suite nothing ran

Tried: `node --test space_server.test.js` in
`extensions/python/examples/integration/typescript_space` -> 15 passed, 0.92 s,
no network. The example ships a server, a client and a checked-in bundle of its
suite, and no lane opened any of it; four of the example's own files cite one
of those 15 cases.
Rejected: retagging those four `assumed`. A shipped suite nothing runs is the
`reduce_dispatch.pl` shape this lane exists to end, and the suite passes with
node alone.
Rejected: running the `.ts` source under node's type stripping.
`node -p process.config.variables.node_use_amaro` answers false on this box's
node v22.22.1, which is the Debian and Ubuntu build, and
`node --test space_server.test.ts` then fails to load the file at all.
Rejected: compiling it with esbuild first. esbuild is a dependency of the Node
seat and not of this one, and a gate that reaches for a bundler fails for a
reason that is not the tree.
Decided: the `ts-space` lane runs the checked-in bundle, which is what the two
pytest files beside it already do with the server bundle
[measured 2026-09-07: 15 cases, 0 failures, min 1.58 s over three runs at
loadavg 97].
Open: nothing checks that `space_server.test.js` is current with
`space_server.ts`, because checking needs the bundler this deliberately does
not have.

## 2026-09-07, proving the plants

Tried: running the selftest and reading it -> not evidence. It answers "does
the gate see this today" and not "is this plant pinning the rule it was written
for", which is the same shape of green the gate itself exists to distrust. Nine
mutations were applied to the checker instead, one per rule added here, each
re-running the selftest: the quoted lookup, the finding a quoted miss produces,
`test` in the registration shapes, the exactness of a quoted token, the widened
suite discovery, the C `CASE` harvest, the check that `main()` calls a case,
the scratch refusal, and the tsconfig hop. All nine caught, none accepted.

Rejected: leaving that as a one-off in a throwaway harness. The measurement
would name a file no clone holds, which is the very thing the rest of this
thread went and removed 65 of.
Decided: the harness ships as the `evidence-mutations` lane. It is mutation
testing with a hand-written mutant set -- one mutant per guarantee, each naming
the rule it removes -- which is the targeted form of what the `mutation` REPORT
lane already does to the Python package with a generated set.

Tried: patching the repository's own checker and restoring it in a `finally`
-> rejected before it was written. One SIGKILL leaves a mutated gate committed.
Decided: `METTA_EVIDENCE_MUTATION` names a JSON file, and the self-test applies
it while COPYING the checker into its fixture, so nothing outside a temporary
directory is ever written.

Tried: the lane against two planted defects of its own -> removing the
renamed-case citation from the self-test reports "the self-test still passes
without the finding a quoted miss produces", and moving the text one mutation
searches for reports that its plant is untested until the mutation follows it.
Both exit 1; the unmutated control exits 0
[measured 2026-09-07: 10 self-test runs, about 12 s at loadavg 68].

Open: `browser.test.mjs` builds one case name from a template literal,
`` `names a missing ${asset} before instantiating wasm` ``. It registers with
the interpolation in it, so the four names it actually runs under cannot be
cited exactly. Nothing cites them today.

## 2026-09-07, the tracked probes

Tried: `pin_provenance.py --check` after the seat grew
`extensions/python/benchmarks/probes/` -> the four probes there read as "1 pin(s)
OUTSIDE the evidence gate's globs, so nothing reads this file's claims and
nothing would ever resolve them", and their pins had been written by hand.

Decided: the glob joins GUARANTEE_SOURCES beside `tests/prolog/probes/*.pl`,
which is the same class one language over. It is also the exact directory the
scratch rule above sends an author to: a probe is where a reproduction is
TRACKED when the fixture is worth having, so the one place holding those
reproductions cannot be the one place whose own claims nothing reads.

Tried: the lane with the glob in -> 6,091 claims read against 6,087, and all
four probes' citations resolve. A plant proves it: a fixture probe citing a test
the pytest lane collects is accepted, one citing a name the tree does not define
is reported, and a tenth mutation removes the glob and the self-test goes red.
