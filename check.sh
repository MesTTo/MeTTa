# Purpose: the single gate. Runs every static check, both test trees, the
#   shell suites and the Prolog checks, and reports one table. Before this
#   script the entry points were scattered (test.sh, tests/*.sh,
#   tests/regression/, extensions/python/tests/, bench.sh) and nothing ran them all,
#   so "the entire suite passes" could not be stated from one command.
#
#   Two tiers. GATE checks must pass and a failure exits nonzero. REPORT
#   checks print their findings and never fail the run; they are the
#   burn-down surface, tracked in ai-code-organisation-and-fixes.md, and
#   each moves to GATE as its backlog clears. A REPORT tier is not a
#   softened gate: nothing here is silenced, everything is printed.
#
#   THREE WORDS, not two. A lane exiting 125 MEASURED NOTHING and reads
#   `skipped` rather than `ok`: 125 is what metta_benchmarking names
#   PERF_CONTROL_REFUSED, what bounded.sh refuses with when the process that
#   started a command had already exited, and what timeout(1) and
#   `git bisect run` both read as a failure in the wrapper rather than in the
#   command. A skip does not decide the run and does not change the exit
#   status, because a lane that could not measure neither proves nor disproves
#   the tree; the names are printed above the verdict so nobody has to read the
#   whole log to learn a lane had nothing to say.
#
#   Usage: sh check.sh [name ...]     names: ruff mypy ty pylint perflint
#                                            xenon refurb vulture slotscheck
#                                            bandit deptry audit interrogate
#                                            codespell imports imports-selftest
#                                            jscpd jscpd-prolog prolog
#                                            ciao-grade
#                                            qlf-freshness qlf-freshness-selftest
#                                            qlf-provenance
#                                            qlf-provenance-selftest
#                                            codec-doc petta parity-perf
#                                            face-sync pygments-sync
#                                            tokenisation
#                                            tokenisation-selftest kernel
#                                            parity-perf-selftest
#                                            parity-fuzz parity-fuzz-selftest
#                                            policy-inventory
#                                            policy-inventory-selftest
#                                            refusal-grounds
#                                            refusal-grounds-selftest snippets
#                                            refusal-sync
#                                            refusal-sync-selftest
#                                            door-sync door-coverage door-refusals
#                                            closed-sets
#                                            closed-sets-selftest
#                                            host-workarounds
#                                            host-workarounds-selftest
#                                            cumulative-syntax
#                                            cumulative-syntax-selftest
#                                            parity twins twins-selftest
#                                            pytest gallery benchmarks instructions
#                                            scaling
#                                            memory-scale memory-scale-gate
#                                            memo-advisor memo-advisor-selftest
#                                            shell examples
#                                            seat-layering seat-layering-selftest
#                                            no-packages
#                                            corpus-coverage
#                                            corpus-coverage-selftest
#                                            generated-artifacts
#                                            init-stub mypy-root-impl
#                                            mypy-algebra-surface
#                                            scratch-retention
#                                            process-bounds reaping
#                                            coverage verifytypes stubtest
#                                            mutation memray
#          METTA_MUTATION_TARGET=metta._atoms.factories.*        which mutants to test
#          METTA_MUTATION_TESTS='tests/...'           which tests judge them
#          CHECK_PY=/path/to/python   pick the interpreter
#          GATE_ONLY=1                skip the REPORT tier
#          METTA_CHILD_CEILING=3600   seconds any spawn may live (bounded.sh)
# Guarantees:
#   - door-sync checks every row projection, runs its planted discrimination
#     tests and executes every declared refusal witness [tested:
#     test_contract_checks_refuse_missing_coverage_and_unbacked_refusals,
#     test_contract_checks_refuse_a_handwritten_public_parameter_point;
#     commit=b615b5a33b43252ef9826e5387da7c9bd7f6b543].
#   - the runtime-derived policy inventory and its nine-case discrimination
#     selftest are GATE lanes [tested:
#     test_a_planted_closed_policy_list_is_reported_by_the_inventory_lane;
#     commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
#   - semantic refusals and the four-case planted discrimination selftest are
#     GATE lanes [tested: tests/checks/check_refusal_grounds.py,
#     tests/checks/check_refusal_grounds_selftest.py; commit=acb40f1912f131ae088083d1af29b4b283019bea].
#   - the seat's refusal table is a projection of the engine's own rows, with a
#     seven-case planted selftest over the classes, their fields and the
#     generated file [tested: extensions/python/tools/refusalgen.py,
#     tests/checks/check_refusal_sync_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58].
#   - every closed set in the Python seat states one of three answers adjacent
#     to it, with a nine-case planted selftest that includes a FOURTH answer
#     [tested: tests/checks/check_closed_sets.py,
#     tests/checks/check_closed_sets_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58].
#   - memory and scaling curves run once in REPORT-then-GATE order; GATE_ONLY
#     still takes a fresh measurement and promotes only deterministic pins
#     [tested: env CHECK_PY=../../.venv-pypetta/bin/python
#     GATE_ONLY=1 sh check.sh memory-scale-gate;
#     commit=d843bb6d17a525c36afd21cab077d63b34447535].
#   - the scaling lane gates the complexity CLASS of every declared family and
#     carries two planted negative controls that it fails without
#     [tested: test_the_planted_quadratic_fails_only_the_exponent_gate,
#     test_the_planted_constant_factor_fails_only_the_growth_gate;
#     commit=906a4057ac57a340a3544ad909e829f851f35af3].
#   - executable comments, bilingual doctests, and all six gallery programs
#     run together as a blocking lane [tested: test_a_gallery_program_runs,
#     test_the_gallery_is_exactly_the_six_ruled_programs,
#     test_translation_drift_is_rejected,
#     test_shown_output_drift_is_rejected,
#     test_answer_multisets_ignore_order_and_alpha_names_but_keep_multiplicity;
#     commit=8bfe05c3850776543ece25a85038242f10b1d841].
#   - Python import contracts block module-level core-to-satellite and
#     leaf-to-facade paths, and an adjacent scratch selftest plants
#     metta._binding.tokens -> metta._observe.trace and requires the same command to reject it
#     by name [tested: test_a_planted_module_level_import_is_rejected;
#     commit=350c0d9dbd3c78a4f779d6331e223e939b94c2c8].
#   - KERNEL.md's counts and both translator-head rosters are runtime-derived,
#     with independent planted count and omission failures [tested:
#     tests/checks/check_kernel_ledger_selftest.py; commit=d7a55be4e931732a02f2178013aed47bb9cde474].
#   - generated-artifacts derives selection, checks and dependency order from
#     the artifact manifest [tested:
#     tests/checks/check_generated_artifact_group_selftest.py; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
#   - the refusals page is the engine's own (refusal ...) rows rendered, and a
#     kind on one side of the shared list only is a finding rather than a
#     missing section [tested:
#     extensions/python/tests/repository/test_refusal_rows.py::test_the_refusals_page_is_generated,
#     ::test_the_page_check_sees_a_kind_on_one_side_only; commit=f33b7ab0200e6dc74c88fb4c7f827bf545a447ed].
#   - every lane inherits a repository-local scratch directory, and a later
#     run reclaims one left by SIGKILL without touching a concurrent run
#     [tested: scratch-retention; commit=c96093349e37cc7153f31b3dd9af10246a325301].
#   - every process a lane starts carries both a deadline and a link to the
#     process that started it, and the link is checked against a real orphan
#     rather than against the text that installs it
#     [tested: reaping, process-bounds; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136].
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/tests/checks/gate_scratch.sh"
metta_gate_scratch_open "$HERE" || exit $?
trap 'metta_gate_scratch_close' EXIT
# The interpreter, and the environment SWI's Janus bridge reads to find the
# same one. Both live in select-python.sh, sourced by every runner in the tree,
# because Janus follows VIRTUAL_ENV rather than the executable a script chose:
# an inherited environment from another tool made the shell and parity lanes
# load that tool's empty Python installation while their Python-side commands
# used $PY [measured 2026-08-20: py_numpy resolves numpy.absolute through numpy
# after alignment; command=sh check.sh no-autoload parity; fixture=inherited MCP
# VIRTUAL_ENV with CHECK_PY auto-selected;
# commit=d90a3c9620e56e42d3a2f5982b4353da8423e873].
METTA_ROOT="$HERE"
. "$HERE/select-python.sh"
[ -n "$PY" ] || { echo "check.sh: no python found (set CHECK_PY)" >&2; exit 2; }

PYDIR="$HERE/extensions/python"
# begin generated artifact selection
# Generated by extensions/python/tools/artifacts.py from ARTIFACTS.
GENERATED_ARTIFACT_LANES="layer-sync vocab-sync artifact-sync binding bounds-sync codec-doc example-origins face-sync pygments-sync refusal-sync aio-mirror fn-sync libdoc refusals init-stub door-sync ledger phrasebook reference"
WANT="$*"
case " $WANT " in
    *" generated-artifacts "*) WANT="$WANT $GENERATED_ARTIFACT_LANES" ;;
esac
for metta_artifact_lane in $GENERATED_ARTIFACT_LANES; do
    case " $WANT " in
        *" $metta_artifact_lane "*|*" generated-artifacts-selftest "*)
            WANT="$WANT $metta_artifact_lane-selftest" ;;
    esac
done
# end generated artifact selection
# Retain the previous names as selection aliases for the package layer checks.
case " $WANT " in *" seat-layering "*) WANT="$WANT layering" ;; esac
case " $WANT " in *" seat-layering-selftest "*) WANT="$WANT layering-selftest" ;; esac
FAILED=''
SKIPPED=''
SUMMARY=$(mktemp "${TMPDIR:-/tmp}/metta-check.XXXXXX")
MEMORY_SCALE_DATA=$(mktemp "${TMPDIR:-/tmp}/metta-memory-scale.XXXXXX")
MEMORY_SCALE_STATUS=$(mktemp "${TMPDIR:-/tmp}/metta-memory-scale-status.XXXXXX")
check_cleanup() {
    status=$?
    trap - EXIT
    rm -f "$SUMMARY" "$MEMORY_SCALE_DATA" "$MEMORY_SCALE_STATUS" || status=1
    metta_gate_scratch_close || status=1
    exit "$status"
}
trap check_cleanup EXIT

# The bound in the CHILD, for the lanes that cannot take a wrapper.
#
# `run()` below wraps a lane whose command word is an external program, and
# cannot wrap one that names a shell function: the wrapper execs, and a
# function is not on disk. 25 of the 33 lane functions spawn swipl, node or a
# Python of their own, so most of what this gate runs would otherwise carry no
# bound at all -- which is how two swipl children spawned under it spun for 122
# CPU-hours between 2026-09-01 and 2026-09-03 after the session that started
# them was killed.
#
# The body of the bound moved to bounded.sh on 2026-09-05, because a definition
# that lives inside this file reaches only this file's lanes: a hand-started
# `swipl ... materialization.plt` ran 7,540 seconds at 97.8% CPU that day with
# no bound at all, and test.sh, run.sh, engine/test.sh and every seat's test.sh
# each spawned outside it. bounded.sh is one file every runner and every person
# can call, and it adds the OWNER LINK this had no way to express: a deadline
# alone leaves an orphan burning a core until the deadline.
#
# Still a prefix rather than the script spelled out 25 times, so the ceiling has
# ONE definition and `tests/checks/check_process_bounds.py` can name the spawn
# that forgot it.
bounded() { sh "$HERE/bounded.sh" "$@"; }

# Which program holds the deadline, resolved ONCE for the whole run rather than
# per spawn: bounded.sh prefers a GNU `timeout` over the uutils reimplementation
# Ubuntu 25.10 installs over /usr/bin/timeout, and asking costs a `--version`
# exec that a gate making hundreds of spawns should not repeat.
METTA_TIMEOUT=${METTA_TIMEOUT:-$(sh "$HERE/bounded.sh" --enforcer)} || {
    echo "check.sh: no \`timeout\` on PATH; see bounded.sh" >&2
    exit 2
}
export METTA_TIMEOUT

# run TIER NAME COMMAND...
# A GATE failure is recorded; a REPORT failure is printed and forgiven.
run() {
    tier="$1"; name="$2"; shift 2
    if [ -n "$WANT" ]; then
        case " $WANT " in *" $name "*) ;; *) return 0 ;; esac
    fi
    [ "$tier" = REPORT ] && [ "${GATE_ONLY:-}" = 1 ] && return 0

    printf '\n=== %s [%s] ===\n' "$name" "$tier"
    # The bound belongs in a process that shares the LANE's fate, not this
    # driver's. A driver-side wait loop stops enforcing the moment the driver
    # is killed, and sessions here are killed routinely: two swipl children
    # spawned under this gate survived from 2026-09-01 to 2026-09-03, spinning
    # at 100% for 122 CPU-hours between them, because the only bound on them
    # lived in a parent that was gone. `bounded` puts the deadline in a process
    # of the lane's own and links the lane to THIS one, so a killed driver takes
    # its lanes with it instead of leaving them to the deadline.
    #
    # The ceiling is an orphan reaper, not a regression detector. test.sh's 290
    # is tight on purpose and catches a cost-class change; an hour is twelve
    # times the ENTIRE GATE_ONLY run [measured 2026-08-21: 286s on a quiet box],
    # so a lane can only reach it by hanging.
    #
    # 36 of the 106 lanes name a SHELL FUNCTION rather than a command, and a
    # wrapper cannot exec one: it execs, and a function is not on disk. Those
    # are counted and named at the end of the run instead of being quietly
    # skipped, because a guard that silently covers two thirds of what it
    # claims is the defect this repository has already been bitten by three
    # times. Their bound sits at the external command INSIDE the function,
    # written `bounded swipl ...`, and tests/checks/check_process_bounds.py is
    # what says every such spawn has one, so this branch is a division of
    # labour rather than a gap.
    lane_status=0
    case "$(command -v "$1" 2>/dev/null)" in
        /*) bounded "$@" || lane_status=$? ;;
        *)  "$@" || lane_status=$? ;;
    esac
    if [ "$lane_status" -eq 0 ]; then
        status=ok
    elif [ "$lane_status" -eq 125 ]; then
        # 125 is this tree's one word for "this run says nothing about the
        # tree", and the summary needs it as much as the lane's own output
        # does. bounded.sh refuses with it when the process that started a
        # command had already exited, metta_benchmarking names the same number
        # PERF_CONTROL_REFUSED for a measured window that never opened, and
        # timeout(1) and `git bisect run` both read it as a failure in the
        # wrapper rather than in the command.
        #
        # Without this word a lane that measured NOTHING reads `ok`, which is
        # the shape the comment above calls the defect this repository has been
        # bitten by three times: mork-bench reported `ok` on four of five full
        # runs of this gate while another session held the PMU and it compared
        # not one row. A skip is not a failure and does not stop the run, so
        # the exit status is unchanged; what changes is that the summary says
        # which lanes had nothing to say.
        status=skipped
        SKIPPED="$SKIPPED $name"
    else
        # A REPORT that exits nonzero has FINDINGS, which is its working state
        # and not a break. Calling both of them FAIL made a burn-down queue
        # read like a defect in the summary, and the two need different words
        # for the summary to mean anything.
        if [ "$tier" = GATE ]; then
            status=FAIL
            FAILED="$FAILED $name"
        else
            status=findings
        fi
    fi
    printf '%s\t%s\t%s\n' "$tier" "$name" "$status" >> "$SUMMARY"
}

in_py() { ( cd "$PYDIR" && bounded "$@" ); }

# The gate does not BUILD anything any more; it asks each component to build
# itself, through the same build.sh the repository's own build.sh drives. This
# file used to compile the chapter 19 C examples and engine/reader.so inline,
# which made a script named for checking the only way to produce two artifacts,
# and put a compiler invocation in the middle of a lane list.
#
# The split each component's script draws is the deciders' one: a toolchain that
# is ABSENT exits 0 with a note, because the engine falls back to the Prolog
# reader and writer and the C examples skip, and a build that is ATTEMPTED and
# FAILS exits nonzero. Only the second is a gate failure, and for the engine's
# own units it is fatal rather than recorded: the C reader and the C writer
# gate every lane below.
#
# DISCOVERED, and every component rather than two. It used to name the engine
# and the chapter 19 examples and nothing else, so a change to a component the
# gate does not build was TESTED AGAINST A STALE ARTEFACT: the Node seat's
# TypeScript is compiled by `npm ci` through the package's prepare script and by
# extensions/node/build.sh, neither of which any lane runs, so after the
# petta-to-metta rename the pytest lane at the top of this file ran the OLD
# compiled bridge against the NEW bridge.pl and failed, while the `build` lane
# 160 lines below rebuilt it and made the NEXT run pass. A gate whose verdict
# depends on how recently someone built by hand is not a gate.
#
# The same discovery build.sh uses, and the same order, because extensions/cmetta
# links against what the engine produces. Provisioning is deliberately NOT run
# here: build.sh clones the two pinned dependencies when they are absent, and a
# gate that reaches the network fails for reasons that are not the tree.
#
# Each build's output is CAPTURED and printed only when it fails. A successful
# cargo build alone emits 7,457 lines of warnings from a vendored dependency,
# which would bury the lane list under compiler noise about code this
# repository does not own; a FAILED build prints in full, because that is the
# one time the text is the answer.
for component in "$HERE/engine" \
                 "$HERE"/extensions/*/ \
                 "$HERE"/examples/ch19-*/; do
    script="${component%/}/build.sh"
    [ -f "$script" ] || continue
    name=$(printf '%s' "${component%/}" | sed "s|^$HERE/||")
    build_log=$(mktemp "${TMPDIR:-/tmp}/metta-build.XXXXXX")
    if ! bounded sh "$script" >"$build_log" 2>&1; then
        cat "$build_log" >&2
        # The engine's own units are fatal rather than recorded: the C reader
        # and the C writer gate every lane below. Everything else degrades to a
        # slower or absent configuration its own lanes already report on.
        if [ "$name" = engine ]; then
            echo "error: engine/reader.c or engine/writer.c failed to build; the C reader and writer gate every lane" >&2
            exit 1
        fi
        echo "note: $name failed to build; its lanes report against that" >&2
    fi
done

# ---------------------------------------------------------------- GATE tier
# Correctness. These must pass on every commit.

# One boot before any concurrent lane: the engine's Quick Load Format
# artifacts generate lazily on first boot, SWI's qcompile writes each .qlf
# in place, and four pytest workers first-booting a fresh tree at once
# would race those writes. Warmed once here, every lane loads a finished
# artifact set (engine/qlf_boot.pl carries the staleness and recovery
# story). `|| true` because a boot problem belongs to the lanes, which
# report it against their own expectations rather than at a warm-up.
bounded swipl -g halt -s "$HERE/engine/main.pl" -- extensions >/dev/null 2>&1 || true

# A git worktree of this repository silently runs one backend fewer than the
# checkout it was cut from: extensions/mork/mork_ffi/target/ and extensions/mork/mork_ffi/morklib.so are
# gitignored build output, and extensions/mork/extension.pl reads their absence as "this
# backend was not built" rather than as an error, which is right for a tree
# that never built it and wrong for a worktree of one that did. Every suite
# then passes while testing less. worktree.sh links them; this shows the
# difference in both directions [measured 2026-08-18: 0.21s].
run GATE worktree sh -c "cd '$HERE' && sh tests/shell/test_worktree_configuration.sh"

# build.sh itself, which nothing checked before: it had no `set -e`, resolved
# its paths against the CALLER's working directory, and ended by cloning
# faiss_ffi with no destination argument into extensions/mork/faiss_ffi, a path no
# ignore rule covers. So one run dirtied the tree and the next failed on
# "destination path already exists", and a failed cargo build still reached a
# line printing "Successfully built mork_ffi". The lane re-runs an already-built
# tree and skips when there is nothing built to re-run, so it costs a cargo
# fingerprint check rather than a compile [measured 2026-08-28: 5.0s warm].
run GATE build sh -c "cd '$HERE' && sh tests/shell/test_build_is_idempotent_and_anchored.sh"

# Every component's own lanes, DISCOVERED. A component is a directory with a
# check.sh, the same rule the engine applies to a control file and build.sh
# applies to a build; adding a seat needs no edit here, which is the defect
# ai-cmetta-c-constraints.md C4 filed as "a new seat is three registrations, not
# one folder".
#
# SOURCED rather than executed, deliberately. Executing them would make each
# component responsible for reporting its own status, and a driver that loses a
# child's exit code is exactly how a red lane reads green -- the pipeline hazard
# this repository already records. Sourcing keeps one `run`, one summary table
# and one exit status, and keeps every lane's text where the evidence gate can
# read it.
for component_check in "$HERE"/engine/check.sh \
                       "$HERE"/extensions/*/check.sh; do
    [ -f "$component_check" ] || continue
    . "$component_check"
done


# The execution plan carries 175 numbered items and no status column, so the
# integrator dispatched three already-completed items off it in one wave. This
# derives status by ASKING THE TREE for each item's checkable anchor.
#
# It decides 5 of 158 today, and that low number is the finding rather than a
# weak tool: 62 items name no checkable anchor at all. Three generous
# heuristics were tried and each produced CONFIDENT WRONG verdicts, all three
# recorded in the module's own docstring with the item that caught them, so
# UNKNOWN is reported wherever a guess would be needed.
run REPORT spec-status          "$PY" "$HERE/tests/checks/check_spec_status.py"
# Same split as evidence / prolog-reach: the report is forgiving, the proof
# that it still discriminates is not. 17 planted cases, plus a FIXED item whose
# file is deleted, confirmed OPEN, restored and confirmed FIXED again.
run GATE   spec-status-selftest "$PY" "$HERE/tests/checks/check_spec_status_selftest.py"

# Every engine decision axis is a live (policy axis knob default) row in
# &metta, joined here to the code seam that consumes it. The second lane plants
# an unowned list, all four allowed exemptions, two malformed exemptions and
# both authority-owned exclusions, so an empty report cannot pass vacuously.
run GATE policy-inventory "$PY" "$HERE/tests/checks/check_policy_inventory.py"
run GATE policy-inventory-selftest "$PY" "$HERE/tests/checks/check_policy_inventory_selftest.py"

# A semantic fence belongs to Python's data model or a named MeTTa law. The
# first lane checks the central structured ground and every owned source site;
# the second plants one omission in each mechanism so an empty scan cannot pass
# vacuously.
run GATE refusal-grounds "$PY" "$HERE/tests/checks/check_refusal_grounds.py"
run GATE refusal-grounds-selftest "$PY" "$HERE/tests/checks/check_refusal_grounds_selftest.py"

# A suite that loads engine/metta.pl reads the engine's COMPILED artifacts, and
# SWI's staleness check covers a .qlf's immediate source only. The engine's
# units are consulted by umbrellas, so engine/spaces/foreign.pl compiles into
# engine/spaces.qlf and an edit to it leaves that artifact fresh by mtime: the
# suite then passes against the previous compile. engine/qlf_boot.pl is the
# purge that defeats it, the warm-up above runs it for every lane here, and
# this gate is for the runs that do not come through here at all -- one suite
# by hand, or engine/test.sh on its own, which is how the hazard was found.
# The selftest plants a missing purge, a late one and a mismatched prefix.
run GATE qlf-freshness "$PY" "$HERE/tests/checks/check_qlf_freshness.py"
run GATE qlf-freshness-selftest "$PY" "$HERE/tests/checks/check_qlf_freshness_selftest.py"

# A .qlf records the directory it was written in, and SWI loads one found in
# another directory as MOVED: it rewrites every recorded source path and calls
# system:'$translated_source'/2 for each, in Prolog, so every process that
# loads it pays 8 inferences per source for where it was compiled. A test that
# linked the checkout's lib/ into a scratch tree wrote such artifacts here and
# the twins lane read +8 on two twins in three gates before anything named it
# (docs/journal/2026-09-11-the-end-of-wave-battery.md, 2026-09-12). This gate
# reads the header of every artifact under engine/ and lib/ and refuses one
# written anywhere else; the selftest plants one SWI compiled in one directory
# and found in another, an unreadable one, and an empty root.
run GATE qlf-provenance "$PY" "$HERE/tests/checks/check_qlf_provenance.py"
run GATE qlf-provenance-selftest "$PY" "$HERE/tests/checks/check_qlf_provenance_selftest.py"

# Conformance against the semantics arbiter. PeTTa is the arbiter, and
# tests/conformance/petta/ is upstream's example corpus beside the exact
# stdout upstream printed for each file, captured from a named commit. This
# replays every entry through this engine and diffs, which is the difference
# between "PeTTa is the oracle" as a habit and as a check.
#
# The pin is VENDORED rather than read out of a sibling checkout, so a
# neighbouring working tree cannot move this lane and CI gates on the same
# bytes a developer does.
#
# A GATE per FILE: an entry gates as soon as it agrees, and an entry recorded
# as diverging carries the difference it is allowed to have, so it cannot
# drift further without failing.
run GATE   petta        sh -c "cd '$HERE' && '$PY' tests/conformance/petta.py --gate --timeout 90 --show 12"

# Performance parity with the same upstream, over the same corpus, and the
# question the conformance lane above does not ask. instructions:u NET OF EACH
# ENGINE'S OWN NULL PROGRAM, median of three processes and of seven when the
# three disagree: engine/ holds 50,297 lines of Prolog against upstream's
# 1,229, so an empty program costs 1.048e9 instructions here against 0.257e9
# there, and a comparison that did not subtract it would report that constant
# on every small file instead of the work.
#
# It was NET OF EACH ENGINE'S OWN BOOT until 2026-09-06, measured by a second
# fixture that consulted the engine and stopped. That fixture reached neither
# engine's per-run setup and, being a different command line, did not even
# measure the same fixed cost: 4,594,811 instructions BELOW upstream's real
# one and 8,661,096 ABOVE ours, a 13.3M bias in this tree's favour on every
# row of the corpus [measured 2026-09-06;
# see docs/journal/2026-09-06-the-parity-floor.md].
#
# It pointed at PeTTa-base until 2026-08-30, an older upstream whose layout
# has no engine/metta.pl, so the guard inside fired and the lane passed
# without measuring anything. That guard then returned 0 EVERYWHERE, and
# .github/workflows/checks.yml never cloned upstream, so the lane ran on every
# push and measured nothing there while PERFORMANCE.md said it did. The
# workflow now checks the pinned upstream out and proves the counter is
# readable before the gate, and the lane refuses where CI=true, the same line
# check_docs_site draws below.
run GATE   parity-perf  sh -c "cd '$HERE' && '$PY' tests/checks/check_upstream_parity.py"

# and the plant that proves the lane above can fail: thirteen cases, one
# function each, one honest control the lane must stay green on and twelve
# defects it must catch, among them a control measured above its program run,
# one taken at the wrong path shape, a frozen negative net, a sampling
# excursion, an uncounted warm-up, a timed-out measurement that leaves a
# process behind, a dropped rebaseline note, an unmeasured run under CI and a
# denied counter. It replaces _perf, the lane's one process call, so no engine
# runs and the whole netting and verdict path is still the production one.
run GATE   parity-perf-selftest "$PY" "$HERE/tests/checks/check_upstream_parity_selftest.py"

# Generated programs on both engines, which is the question the two lanes above
# cannot ask: they replay upstream's 156 examples, so they find only what those
# examples happen to write. This draws programs from a CENSUS of the heads that
# corpus proves upstream reduces (tests/conformance/petta/HEADS.json, written by
# `petta_capture.py --census` and pinned to the same commit), runs each on both
# engines, and shrinks a disagreement to the smallest program that still shows
# it. A finding is a Markdown file under ai-tmp/parity-fuzz/ carrying the
# divergence issue template's own fields.
#
# REPORT, because the programs are drawn fresh: what it finds moves run to run,
# and a lane that blocks a push on a newly drawn program blocks it on the draw
# rather than on the change. A program the arbiter leaves unreduced is a hole in
# the census and is recorded as one, never reported as a divergence.
run REPORT parity-fuzz  sh -c "cd '$HERE' && '$PY' tests/checks/check_upstream_fuzz.py"

# and the plant that proves the lane above can fail: six cases against engines
# substituted at its one process call, among them an engine answering 4 for
# (+ 1 2) whose finding must shrink to a program every line of which the
# disagreement needs, an arbiter printing the query back, an arbiter that
# raises, the six-way classification over strings both engines really printed,
# and the strategy held to the census's own heads.
run GATE   parity-fuzz-selftest "$PY" "$HERE/tests/checks/check_upstream_fuzz_selftest.py"

# The obligation headers are the contract a library author reads, and a
# [tested X] tag is the strongest evidence in the scheme. Thirteen of them
# named tests that had never existed in the tree's history, including some
# cited by the engine pool's Guarantees block, and nothing anywhere would have
# said so: a claim with nothing behind it reads exactly like the many that are
# real. This is the linter the scheme has always implied. It reads only, needs
# no engine, and finishes in under a second, so it runs before anything that
# can hang.
#
# It also reads the commit= half of every tag, which was unchecked until
# 2026-08-26 because a token carrying an `=` never looked like a test name.
# One citation was pinned to a full object ID sharing eight characters with a
# real commit and nothing else. WORKTREE is the lawful in-progress spelling,
# since a commit cannot contain its own object ID, so the run counts those and
# RELEASE=1 refuses them: that is the cut-time check that a release does not
# ship evidence pointing at an uncommitted worktree.
# The cheat sheets against the tree and the engine they describe. llms.txt
# has always OPENED by claiming this lane, and the lane did not exist until
# 2026-09-01: the library roster drifted to 33 of 34 names behind the claim.
run GATE llms       "$PY" "$HERE/tests/checks/check_llms_names.py"
run GATE llms-selftest "$PY" "$HERE/tests/checks/check_llms_selftest.py"

# KERNEL.md's two rosters and six counts come from the running translator.
# The first lane rejects a head without a reason row and a stale row without a
# head; the second runs the production comparison over a planted bad count and
# a planted missing row, independently.
run GATE kernel-ledger "$PY" "$HERE/tests/checks/check_kernel_ledger.py"
run GATE kernel-ledger-selftest "$PY" "$HERE/tests/checks/check_kernel_ledger_selftest.py"

run GATE evidence   "$PY" "$HERE/tests/checks/check_evidence_tags.py"

# The evidence gate is itself a claim, so it is checked the same way. A fixture
# tree carries 17 planted citations, 8 that must be accepted and 9 that must be
# rejected, and the self-test asserts the exact line each finding lands on AND
# that nothing else is reported. Nine mutations, each disabling exactly one
# rule, were each caught with the right complaint and nothing else, which is
# what stops the fixture passing vacuously [measured 2026-08-18: 0.07s]. A
# second fixture is a real repository with one commit, carrying a live pin, a
# fabricated pin differing from it only in its tail, and a WORKTREE
# placeholder; disabling either commit rule was caught [measured 2026-08-26].
run GATE evidence-selftest "$PY" "$HERE/tests/checks/check_evidence_selftest.py"

# And whether those plants are still attached to anything. A green self-test
# answers "does the gate see this today", not "is this plant pinning the rule
# it was written for": a rule can be widened until a plant passes for a reason
# unrelated to why it exists, and the self-test reads the same either way. That
# is the mistake the gate itself exists to catch, one level up.
#
# So each rule is taken away in turn and the self-test has to go red. Nine
# mutations, one per rule the gate gained on 2026-09-07, plus an unmutated
# control, because without it a self-test broken to fail always would report
# every mutation as caught. It is mutation testing with a hand-written mutant
# set, the targeted form of what the `mutation` REPORT lane does to the Python
# package with a generated one, and it writes nothing outside a temporary
# directory: the self-test patches the COPY it makes of the checker.
run GATE evidence-mutations "$PY" "$HERE/tests/checks/check_evidence_mutations.py"

# The other half of the provenance rule. A commit cannot contain its own object
# ID, so the scheme writes the work as commit A and resolves every placeholder
# to A's ID in a provenance-only commit B. That resolution was a hand sweep
# until 2026-08-31, when one reached into twelve STRING LITERALS: the twin
# re-pin tool started writing a stale object ID into every twin it priced, and
# this lane's own neighbour stopped testing its RELEASE=1 rule because the
# self-test planted an ID where the gate tested for the word. Nothing said so,
# because a resolvable ID is exactly what the gate wants to see.
# tests/checks/pin_provenance.py is that pass, deciding per file class from
# each language's own grammar, and this lane plants one of every shape to prove
# it can tell a pin from the code that writes one.
run GATE provenance-pin-selftest "$PY" "$HERE/tests/checks/check_pin_provenance_selftest.py"

# `git diff --check` reports a leftover conflict marker and this repository runs
# it, but it reads a DIFF, so it sees one only while the change carrying it is
# uncommitted. A merge is where that gap opens: resolve, add, commit, and if the
# staged result was never checked the markers land, after which they appear in no
# later diff. 134 lines of unresolved conflict sat in CHANGELOG.md from
# 095366db on 2026-08-28 until 2026-09-03, through every gate run between. This
# asks the committed tree instead, and its selftest plants the setext heading
# underline that a matcher reading `=======` alone would report as a conflict.
run GATE conflict-markers "$PY" "$HERE/tests/checks/check_conflict_markers.py"
run GATE conflict-markers-selftest "$PY" "$HERE/tests/checks/check_conflict_markers_selftest.py"

# b54dea73 renamed the chapter-19 C artifacts on 2026-08-27 and left THREE
# consumers holding the old directory. Each was found separately by somebody
# noticing a test skip -- test_benchmarks.py and benchmarks/configuration.py
# under finding 26, and tests/.../test_c_handle_crossing.py under finding 35,
# which survived the repair of the other two because nothing asked in general.
# A grep cannot: examples/integration/c_extension was renamed while
# extensions/python/examples/integration/ still exists, so the same word is
# stale once and current seven times. So each expression is EVALUATED instead.
run GATE artifact-paths "$PY" "$HERE/tests/checks/check_artifact_paths.py"
run GATE artifact-paths-selftest "$PY" "$HERE/tests/checks/check_artifact_paths_selftest.py"

# A seat that asks "is this pandas?" in a branch cannot be extended by a second
# frame library without an edit here, which is a fork; EXTENDING.md promises
# the opposite and promised it only for the engine until the seats had a seam
# of their own. This asks whether any library name has crept back out of its
# registration, in all three seats, deriving the names from what the sources
# actually reach for rather than from a list that would go stale.
run GATE no-hardcoded-integration "$PY" "$HERE/tests/checks/check_hardcoded_integrations.py"
run GATE no-hardcoded-integration-selftest "$PY" "$HERE/tests/checks/check_hardcoded_integrations_selftest.py"

# The other half of the same ruling, and the half a name scan cannot see. The
# pass above says no library is NAMED in a seat's core; this one says the
# workspace's two layers hold: the core imports no extension distribution, and
# no distribution reaches the core's private names. Both are derived from the
# `[tool.uv.workspace] members` glob, so a package added under
# `extensions/python/ext/` is gated with no edit to either.
run GATE layering "$PY" "$HERE/tests/checks/check_layering.py"
run GATE layering-selftest "$PY" "$HERE/tests/checks/check_layering_selftest.py"

# A bound kept by the caller stops being kept when the caller is killed. Two
# swipl children spawned under this gate ran from 2026-09-01 to 2026-09-03,
# spinning at 100% for 122 CPU-hours between them, because
# `subprocess.run(timeout=)` and this driver's own wait are both enforced in a
# process that was gone. `run()` above wraps a lane whose command word is a
# program; the 25 lane functions that start swipl, node or a Python of their
# own carry `bounded` at that call instead, and this is what says every one of
# them still does. It reads the runner scripts too, because the spawn that ran
# 7,540 seconds at 97.8% CPU on 2026-09-05 was in none of these lanes. The
# selftest plants unbounded spawns and the shapes that must not be flagged.
run GATE process-bounds "$PY" "$HERE/tests/checks/check_process_bounds.py"
run GATE process-bounds-selftest "$PY" "$HERE/tests/checks/check_process_bounds_selftest.py"

# And the mechanism itself, against real processes rather than against the text
# that installs it. Every case starts a child that spins at 100% and ignores
# SIGTERM, kills the process that started it, and asks whether the child is
# still burning a core; the ceiling stays at an hour so that nothing but the
# owner link can explain a death. Run it with a wrapper argument to see the
# same cases fail: `sh tests/shell/test_bounded_reaping.sh timeout
# --preserve-status -k 10 3600` is the deadline-only bound this repository used
# until 2026-09-05, and it leaves all three orphans running.
run GATE reaping sh -c "cd '$HERE' && sh tests/shell/test_bounded_reaping.sh"

# begin generated artifact lanes
# Generated by extensions/python/tools/artifacts.py from ARTIFACTS.

run GATE layer-sync "$PY" "$HERE/extensions/python/tools/layergen.py"
artifact_layer_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_layout_projections.py" -k layergen || return $?
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_lazy_loading.py" || return $?
    bounded "$PY" "$HERE/tests/checks/check_layering_selftest.py" || return $?
}
run GATE layer-sync-selftest artifact_layer_sync_witnesses

run GATE vocab-sync "$PY" "$HERE/extensions/python/tools/vocabgen.py"
artifact_vocab_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k vocabulary || return $?
}
run GATE vocab-sync-selftest artifact_vocab_sync_witnesses

run GATE artifact-sync "$PY" "$HERE/tests/checks/check_generated_artifact_group.py"
artifact_artifact_sync_witnesses() {
    bounded "$PY" "$HERE/tests/checks/check_generated_artifact_group_selftest.py" || return $?
}
run GATE artifact-sync-selftest artifact_artifact_sync_witnesses

run GATE binding "$PY" "$HERE/extensions/python/tools/bindinggen.py"
artifact_binding_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_binding_interface.py" "$HERE/extensions/python/tests/repository/test_wire_tag_rows.py" "$HERE/extensions/python/tests/ch20_extending_the_engine/test_binding_evaluation.py" "$HERE/extensions/python/tests/ch18_performance/test_heartbeat_accounting.py" || return $?
}
run GATE binding-selftest artifact_binding_witnesses

run GATE bounds-sync "$PY" "$HERE/extensions/python/tools/boundsgen.py"
artifact_bounds_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_layout_projections.py" -k boundsgen || return $?
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/ch01_getting_started/test_config.py" || return $?
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k setting_configuration || return $?
}
run GATE bounds-sync-selftest artifact_bounds_sync_witnesses

run GATE codec-doc "$PY" "$HERE/extensions/python/tools/codecdoc.py"
artifact_codec_doc_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k codec_document || return $?
}
run GATE codec-doc-selftest artifact_codec_doc_witnesses

run GATE example-origins "$PY" "$HERE/extensions/python/tools/example_origins.py"
artifact_example_origins_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k example_origins || return $?
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_executable_docs.py" "$HERE/extensions/python/tests/repository/test_example_parity.py::test_example_parity_reports_a_planted_difference" || return $?
}
run GATE example-origins-selftest artifact_example_origins_witnesses

run GATE face-sync "$PY" "$HERE/extensions/python/tools/facegen.py"
artifact_face_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/ch11_python_as_a_notation/test_face.py" || return $?
}
run GATE face-sync-selftest artifact_face_sync_witnesses

run GATE pygments-sync "$PY" "$HERE/extensions/python/tools/pygmentsgen.py"
artifact_pygments_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k lexer || return $?
    bounded "$PY" "$HERE/tests/checks/check_tokenisation_parity.py" || return $?
    bounded "$PY" "$HERE/tests/checks/check_tokenisation_selftest.py" || return $?
}
run GATE pygments-sync-selftest artifact_pygments_sync_witnesses

run GATE refusal-sync "$PY" "$HERE/extensions/python/tools/refusalgen.py"
artifact_refusal_sync_witnesses() {
    bounded "$PY" "$HERE/tests/checks/check_refusal_sync_selftest.py" || return $?
}
run GATE refusal-sync-selftest artifact_refusal_sync_witnesses

run GATE aio-mirror "$PY" "$HERE/extensions/python/tools/aiogen.py"
artifact_aio_mirror_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_async_mirror.py" || return $?
}
run GATE aio-mirror-selftest artifact_aio_mirror_witnesses

run GATE fn-sync "$PY" "$HERE/extensions/python/tools/fngen.py"
artifact_fn_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/ch11_python_as_a_notation/test_mention_doors.py" "$HERE/extensions/python/tests/repository/test_doc_emission.py" || return $?
}
run GATE fn-sync-selftest artifact_fn_sync_witnesses

run GATE libdoc "$PY" "$HERE/extensions/python/tools/libdoc.py"
artifact_libdoc_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k library_document || return $?
}
run GATE libdoc-selftest artifact_libdoc_witnesses

run GATE refusals "$PY" "$HERE/extensions/python/tools/refusalsdoc.py"
artifact_refusals_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_refusal_rows.py" || return $?
}
run GATE refusals-selftest artifact_refusals_witnesses

run GATE init-stub "$PY" "$HERE/extensions/python/tools/rootgen.py"
artifact_init_stub_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k 'root or source_bindings' || return $?
}
run GATE init-stub-selftest artifact_init_stub_witnesses

run GATE door-sync "$PY" "$HERE/extensions/python/tools/doorgen.py"
artifact_door_sync_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_door_rows.py" "$HERE/extensions/python/tests/repository/test_door_marks.py" || return $?
    bounded "$PY" "$HERE/extensions/python/tools/doorgen.py" --refusals || return $?
}
run GATE door-sync-selftest artifact_door_sync_witnesses

run GATE ledger "$PY" "$HERE/extensions/python/tools/ledger.py"
artifact_ledger_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_artifact_projections.py" -k door_documents || return $?
}
run GATE ledger-selftest artifact_ledger_witnesses

run GATE phrasebook "$PY" "$HERE/extensions/python/tools/phrasebook.py" --gate
artifact_phrasebook_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_phrasebook.py" || return $?
}
run GATE phrasebook-selftest artifact_phrasebook_witnesses

run GATE reference "$PY" "$HERE/extensions/python/tools/reference.py"
artifact_reference_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_reference_projections.py" || return $?
}
run GATE reference-selftest artifact_reference_witnesses
# end generated artifact lanes

run GATE door-coverage "$PY" "$HERE/extensions/python/tools/doorgen.py" --coverage
run GATE door-refusals "$PY" "$HERE/extensions/python/tools/doorgen.py" --refusals
run GATE scratch-retention "$PY" "$HERE/tests/checks/check_gate_scratch_selftest.py"
run GATE tokenisation "$PY" "$HERE/tests/checks/check_tokenisation_parity.py"
run GATE tokenisation-selftest "$PY" "$HERE/tests/checks/check_tokenisation_selftest.py"
run GATE extension-scaffold sh "$HERE/tests/shell/test_python_extension_scaffold.sh"

# The census the two lanes above are instances of: every closed set in the
# Python seat says which of three answers it stands on -- generated with its
# sync lane, seam rows with their point, or a `Decides:` naming the policy and
# the row it reads -- adjacent to the set. Before it, seventy-seven tables sat
# in the seat with nothing saying which were the engine's rows restated;
# eleven were, and one of those listed six members where the engine derived ten.
run GATE closed-sets "$PY" "$HERE/tests/checks/check_closed_sets.py"
run GATE closed-sets-selftest "$PY" "$HERE/tests/checks/check_closed_sets_selftest.py"
run GATE host-workarounds "$PY" "$HERE/tests/checks/check_host_workarounds.py"
run GATE host-workarounds-selftest "$PY" "$HERE/tests/checks/check_host_workarounds_selftest.py"

# A GATE by the 2026-09-08 layout ruling ("reports until BINDING lands and
# gates after"): the 332 mixed, open and recursive boundaries it refuses on
# the current door graph are the measured form of "about ten doors cross
# where forty-six do", the debt the doors programme burns down, and the gate
# stays red until each is resolved at its body rather than baselined.
run GATE door-order "$PY" "$HERE/extensions/python/tools/doororder.py"
door_order_witnesses() {
    bounded env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_door_order.py"
}
run GATE door-order-selftest door_order_witnesses
run REPORT filesizes "$PY" "$HERE/extensions/python/tools/filesizes.py"
run GATE filesizes-selftest env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh" "$HERE/extensions/python/tests/repository/test_file_sizes.py"

# --------------------------------------------------------------- REPORT tier
# Known backlog. Each entry names its section in the ledger and becomes a
# GATE once that section is cleared.

# P0.26's website snippet provenance backlog is enumerated in
# website/scripts/snippet_backlog.tsv. The script reports the fixed baseline's
# remaining entries and calls anything outside it UNTRACKED, so the baseline
# cannot grow silently. Promote this lane when the remaining count reaches zero.
run REPORT snippets    "$PY" "$HERE/website/scripts/audit_snippets.py"
# trueagi-io/jupyter-petta-kernel, installed at a pinned commit and STARTED:
# against upstream PeTTa at the parity pin, which is its own configuration, and
# against this engine through the two calls it makes of its host. REPORT
# because it fetches from github.com and a gate that reaches the network fails
# for reasons that are not the tree; the kernel job in .github/workflows adds
# CI=true, where every missing prerequisite refuses instead of skipping. It
# also runs the launcher contract the journal thought the kernel rode on, which
# needs no network and is checked whatever the rest of this lane can reach.
run REPORT kernel      "$PY" "$HERE/tests/checks/check_jupyter_kernel.py"
# Python that lives OUTSIDE the Python seat. Every lint lane in
# extensions/python/check.sh runs with that directory as its root, so the
# benchmark drivers the other components grew -- engine/bench.py,
# extensions/node/benchmarks/, extensions/cmetta/benchmarks/ -- were shipping
# with no linter reaching them at all. Widening found eight real findings across
# three files, including an exception class with no Error suffix and five noqa
# directives naming rules this configuration does not enable.
#
# DISCOVERED rather than listed, the same rule the build and the component lanes
# follow: a component that grows a driver is covered without an edit here. ruff
# resolves the repository's own pyproject.toml by walking up from each file, so
# the seat's configuration decides, and the paths are literal so the evidence
# gate can model what this lane covers.
# TRACKED files, asked of git rather than walked. A walk finds vendored build
# output nothing here owns: extensions/mork/mork_ffi/target/ alone carries a
# generated jemalloc test script with five findings in it, and every ignore
# pattern that hides it is one more thing to keep true. What the repository
# tracks is the answer to what the repository is responsible for.
check_component_python() {
    found=$(cd "$HERE" && git ls-files -- 'engine/*.py' 'extensions/*/*.py' \
                'extensions/*/*/*.py' 'examples/ch19-*/*.py' 'tests/checks/*.py' |
            grep -v '^extensions/python/')
    [ -n "$found" ] || return 0
    # shellcheck disable=SC2086  -- the list is newline-separated paths this
    # tree owns, and word splitting is how they reach ruff as arguments.
    ( cd "$HERE" && bounded "$PY" -m ruff check $found )
}
run GATE   ruff-drivers check_component_python
# The site itself renders, which nothing ran before this: three config headers
# and every page's own header claim `[tested: npm run docs:build]` and no lane
# had ever run it. The build is what decides a dead internal link, and the
# engine section leans on two VitePress features a file check cannot see -- the
# @include that publishes EXTENDING.md, KERNEL.md, CODEC.md and DEVELOPING.md
# without a second copy, and the rewrites that publish them under this site's
# own lowercase spelling while the sources keep their own names so their
# relative links resolve.
#
# It does not fetch: a gate that reaches the network fails for a reason that is
# not the tree, which is the rule the Node lanes already follow. A developer
# without the site dependencies gets the install instruction and a local skip.
# GitHub Actions sets CI=true, where this lane is load-bearing, so a missing
# prerequisite refuses instead of turning an unbuilt site into a green gate.
# What it CANNOT skip locally is the structure:
# test_every_site_include_resolves and
# test_every_site_page_is_reachable_from_the_navigation run in the pytest lane
# on every machine, node or no node.
docs_prerequisite_missing() {
    if [ "${CI:-}" = true ]; then
        printf 'error: %s; refusing to pass the CI documentation gate without a build\n' \
            "$1" >&2
        return 1
    fi
    printf 'note: %s; the documentation site will not be built\n' "$1" >&2
    return 0
}

check_docs_site() {
    site="$HERE/website"
    if [ ! -d "$site" ]; then
        docs_prerequisite_missing "website directory not found"
        return
    fi
    if ! command -v npm >/dev/null 2>&1; then
        docs_prerequisite_missing "npm not found"
        return
    fi
    if [ ! -d "$site/node_modules/vitepress" ]; then
        docs_prerequisite_missing \
            "run 'npm ci --prefix website'; vitepress is not installed"
        return
    fi
    # The site SERVES the Node seat's browser build: a `::: run` fence boots it
    # in a Web Worker, and website/scripts/bundle-browser.mjs refuses the site
    # build when it is not there. That refusal is the right answer to a site
    # published without an engine and the wrong answer to a developer who has
    # not run one command, so the kit is BUILT here whenever this tree can build
    # it -- 3.2 seconds of esbuild and a copy -- rather than only when it is
    # absent. Same shape as check_node_dist, which builds dist/ inside the
    # `npm pack` its consumer program runs, and for the same reason: the
    # artefact is gitignored, so there is no committed state to compare a stale
    # one against and rebuilding is the only thing that ends one.
    if [ -d "$HERE/extensions/node/node_modules" ]; then
        bounded npm run build:browser --prefix "$HERE/extensions/node" || return 1
    elif [ ! -f "$HERE/extensions/node/_runtime/runtime.json" ]; then
        docs_prerequisite_missing \
            "run 'npm ci --prefix extensions/node'; the site serves the browser \
kit that seat's build makes and a gate does not reach the network"
        return
    else
        printf 'note: extensions/node/node_modules is absent, so the browser kit the \
site serves is whatever a previous build left; it cannot be refreshed here\n' >&2
    fi
    bounded npm run --prefix "$site" docs:build
}
run GATE   docs        check_docs_site
# Every source path the project ships, and clean, so this gates. It used to
# read the engine, lib and README alone, which left the docs and examples a reader
# meets first unchecked: widening it turned up 27 more spellings against the
# one in engine code. .codespellrc carries the skips and the words that only
# look wrong, and its entries are bare names because codespell prunes a walked
# directory by NAME, so a ./-prefixed skip stops matching the moment a runner
# passes explicit paths.
run GATE   codespell   sh -c "cd '$HERE' && '$PY' -m codespell_lib extensions/python/metta extensions/python/ext extensions/python/bench.py extensions/python/examples extensions/python/notebooks extensions/python/tests extensions/python/tools engine lib extensions/mork extensions/node extensions/cmetta examples tests website .github *.md"
# The remaining clones are small facade, protocol, and test-fixture mirrors;
# extracting them would couple layers or hide the local contract.
run REPORT jscpd       sh -c "cd '$HERE' && npx --yes jscpd --reporters ai --format python --min-lines 8 --ignore '**/__pycache__/**' extensions/python/metta extensions/python/tests"
# The same question of the PROLOG surface, which no duplication check reached:
# the lane above reads Python and vulture reads Python, so 54,000 lines of
# engine, library and seat Prolog had nothing looking for copies in them at all.
# It reports 12 [measured 2026-09-05], among them a cross-seat pair
# (extensions/cmetta/bridge.pl and extensions/python/metta/_binding/shim.pl) that only
# surfaces once comments are out of the comparison.
#
# `--format perl` because that is the format jscpd maps `.pl` to; `--format
# prolog` names an extension this tree does not use and analysed zero files.
# The tokenizer is therefore Perl's, which is why the comment rule is passed
# explicitly: `--skip-comments` drops `#` comments and leaves Prolog's `%`
# ones, and every obligation header in the tree then reads as a nine-line
# clone of every other. `--ignore-pattern` drops the `%` tail instead, at the
# price of also dropping one inside a quoted atom or string; that is a
# tolerable false-clone risk in a lane that prints and never fails.
#
# The GENERATED half of the engine is not text and cannot be read here: the
# translator asserts its clauses at run time. `prolog-reach` in
# engine/check.sh is what sees them, through prolog_walk_code/1 against a
# loaded database.
run REPORT jscpd-prolog sh -c "cd '$HERE' && npx --yes jscpd --reporters ai --format perl --min-lines 8 --skip-comments --ignore-pattern '%[^\\n]*' --ignore '**/vendor/**,**/_runtime/**' engine lib extensions tests/prolog"

# -------------------------------------------------------------------- report
printf '\n================ summary ================\n'
awk -F'\t' '{ printf "%-6s %-12s %s\n", $1, $2, $3 }' "$SUMMARY"

# Named before the verdict, and on every run, because the point of the word is
# that a reader scanning the last two lines learns a lane had nothing to say.
# A skip does not decide the run either way: the tree is neither proved nor
# disproved by a lane that could not measure.
if [ -n "$SKIPPED" ]; then
    printf '\nMEASURED NOTHING, so nothing here says the tree moved:%s\n' "$SKIPPED"
fi
if [ -n "$FAILED" ]; then
    printf '\nGATE FAILED:%s\n' "$FAILED"
    exit 1
fi
printf '\nall gate checks passed\n'
exit 0
