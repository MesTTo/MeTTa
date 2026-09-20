# The MORK pin advanced
Goal: build the storage seat on the latest published MORK and compatible PathMap, preserve PeTTa answers, and pin the cost of every workload including a native-versus-MORK conjunctive size sweep.
Constraint: keep shared dependency checkouts unchanged, retain the default join dispatch, measure retired instructions under the existing two-sided bands, and land functional work before its provenance pin.

## 2026-09-08

Tried: `git ls-remote https://github.com/trueagi-io/MORK.git refs/heads/main` and the corresponding PathMap `refs/heads/master` lookup. The published tips are `ed57c6716d8c510296fb5fbb8be6fbfe2df241d7` and `0010dbbd52d13fad67e9a7dabfdadb1cfea71fe1`. The old pins are `dd224fd7ced92ca9cfdacd399398dabb609e8faa` and `4c84a8b40c7b6a7ecb54e009a70f0c5abbc1b60f`. All 60 MORK and 118 PathMap intervening commit subjects were read.

Tried: build the unchanged bridge against both tips with `sh extensions/mork/build.sh`, using its own release target directory. Cargo compiled both dependencies, then exited 101: `error[E0277]: the trait bound Vec<_>: ItemSink is not satisfied`, at the two expression-application calls in `src/lib.rs`. This establishes compatibility of the dependency pair and the bridge's concrete API break.

Decided: follow MORK's own `Space::dump_sexpr` application mechanism. Commit `312a0486138cc2378ade61d89486f10db8771b24` replaces coroutine output through `std::io::Write` with `ItemSink`; use `VecSink` for the template. Commit `f17d3d0d4c3a48baba5acf4844ba18c1fc5ff9b1` specializes the discarded pattern pass as `pattern_cycles_and_intros`; retain its cycle refusal and original/new variable counts. Compare it against full pattern application over ground and schematic fixtures. Both use the existing demand-grown output allocation and registry lock.

The zipper API changed in MORK `ac172d5ea6445f7a26e06c3b729737f7b6af0eed`, merged by PR 153, after PathMap PRs 59 and 60 split path retention from movement. The bridge constructs `ProductZipper` and calls `Space::query_multi_raw`; it does not implement movement methods, so no local movement shim is needed. The published default remains the product join. The optional `leapfrog` feature is not enabled by this seat.

Rejected: calling `Space::dump_sexpr` or `Space::query_multi` directly. Those still reserve fixed four-gibibyte buffers at the new pin. The bridge's existing bounded-allocation contract remains necessary. Revisit when the upstream entry points allocate in proportion to their requests.

Rejected: treating the pin bump as permission to change routing. A feature switch would confound the dependency comparison and change which join serves the workload. The sweep will expose that choice to later routing work.

### Design fixed before implementation

The new workload is a two-edge path join over exactly N unique atoms, `edge(I, I+1)`, at 100, 400, 1600 and 3200. Both stores receive the same facts and answer `(edge X Y), (edge Y Z)`, with N-1 projected triples. Setup builds the store, flushes MORK, warms the query, and compares the complete sorted answer list with the generated expected triples. The measured operation counts the same query through `match/4`. Setup and teardown stay outside perf's window. A selftest plants wrong answer counts and altered instruction pins in both directions.

The existing thirty-one rows retain their workload sizes and sample policy. Eight additional rows measure one complete join each. Retired instructions decide both sides, Prolog inferences and process CPU are recorded beside them, and the four minima fit an exponent through least squares over logarithms. This is a measured growth estimate, not a proof over unmeasured sizes. The approach follows the existing size-sweep harness and the fitting discipline in [Google Benchmark's complexity implementation](https://github.com/google/benchmark/blob/v1.9.4/src/complexity.cc); Python's standard-library regression supplies the fit.

Every row records load beside its samples. One reviewed update writes the new pins; out-of-band changes receive old-pin controls from a second worktree at the cut. The current baseline's counter-policy prose incorrectly says that inferences decide the foreign work, so the driver will own and write the instruction policy explicitly. Its configuration stamp will include the actual loaded seats, because the same workload boots all installed seats.

The MORK check file currently requires sourcing by the root driver. Direct invocation will delegate to that driver so both documented entry points run the same lanes. The new benchmark selftest joins those lanes. The root gate also rebuilds Node, so the provisioned Node build symlink must become a local build directory before any gate can write through it.

Open: the rebuilt behavioral gates, row measurements and controls, fitted exponents, and committed-tree verification.

### Controls exposed the workload boundary

Tried: the first complete `sh extensions/mork/bench.sh --update` exited 0 with all thirty-one original rows and the proposed eight path-graph rows. The one-minute load fell from 13.98 to 12.58 on a 32-CPU machine. Each recorded number is the minimum of three valid samples. One `mork-match-last` window at 8000 did not arm; the existing retry discarded the refusal and obtained three valid samples. No instruction band changed.

Tried: the same driver and workload over a second detached checkout at `c0481b2d528a5bd513abf516e97f901d35371f08`, provisioned with the same engine artifacts and three seats, but built against the old pair. Both path-graph sweeps are linear: native exponent 0.9952 at both pairs, MORK 1.0072 at the old pair and 1.0086 at the new pair. At 3200, MORK falls from 148,748,932 to 126,449,079 instructions. This does not reproduce the ledger's quadratic family.

Rejected: keeping the path graph as the requested cost-class instrument. The original engine performance triage's L089 finding uses a skewed empty join. Its 199-answer path query proves whole-query dispatch, not quadratic cost. The path-graph measurements remain evidence of that distinction; they are not shipped as the eight sweep pins.

Decided: use the skewed triangle family described in `engine/spaces/native_matching.pl`. For H = floor(N/2), N unique atoms are `edge(I,0)` for 1 <= I <= H and `edge(0,J)` for H < J <= N. The triangle query has no answers, but MORK's product enumerates the incoming/outgoing pairs. A throwaway probe at N=100,400,1600,3200 measured MORK CPU 0.000363911, 0.005287922, 0.068017566, 0.341891779 seconds, while native inferences were 1479, 5679, 22479, 44879. These establish the family before writing its final fixture; retired instructions will decide the rows.

The corrected setup plants `edge(H+1,1)`, requires all three rotations of that triangle, removes the witness in cleanup and checks the empty bag before measuring. A planted always-empty implementation must fail the positive control. A same-count wrong-triple mutation must also fail. This retains a nonvacuous semantics check even though the measured answer is empty. Only the eight new sweep rows are replaced; the original thirty-one keep their first reviewed re-pin.

### Provenance integration

Tried: the required provenance scan. It reported `.rs has no comment rule here; add one rather than guessing` for the repaired adapter, and reported the new MORK Python selftest outside the evidence globs. The evidence lane also could not resolve a bare Rust test name, because its collectors do not parse Rust tests.

Decided: add a `mork-rust` lane that runs the seven release-mode Cargo tests against the committed lock, serialized for the upstream process-global scratch counters. The Rust header cites that executable gate. Add Rust to the provenance tool's existing line/block comment rule, and add the MORK Python suite to the evidence scan. The provenance selftest plants both file classes and requires Rust code literals to remain unchanged. Its 32 planted placeholders in 14 files report zero defects. The README's existing source header stays unchanged; it needs no new evidence syntax.

### The complete re-pin and its positive control

The old-pair control uses the same final benchmark driver and workload, the unchanged engine at the cut, private MORK and PathMap worktrees at the old pins, and its own built Node output. Both runs loaded mork, node and python, with the C reader and writer active. The two dependency pairs and the required adapter repair are the treatment. These controls do not isolate individual upstream commits.

Ten original rows cross their existing band. Every one has a positive old-pair control below; the other twenty-one are shown too. The first complete update supplies every original new pin. CPU is advisory; all table counts are retired user instructions, net of the separately measured handshake floor.

| original row | previous pin | new pin | old-pair control | change | band | mechanism |
|---|---:|---:|---:|---:|---:|---|
| mork-batch-add-2000 | 52,433,376 | 52,582,515 | 52,448,529 | +0.284% | 1% | B |
| mork-batch-add-500 | 12,966,563 | 13,003,792 | 12,970,808 | +0.287% | 1% | B |
| mork-batch-add-8000 | 211,905,277 | 212,521,935 | 211,964,849 | +0.291% | 1% | B |
| mork-flush-2000 | 3,133,481 | 3,257,929 | 3,133,359 | +3.972% | 1% | P |
| mork-flush-500 | 793,634 | 823,926 | 791,601 | +3.817% | 1% | P |
| mork-flush-8000 | 12,722,456 | 13,237,670 | 12,722,291 | +4.050% | 1% | P |
| mork-mork-match-first-2000 | 14,355,393 | 14,184,519 | 14,348,187 | -1.190% | 1% | F |
| mork-mork-match-first-500 | 14,301,563 | 14,190,162 | 14,359,435 | -0.779% | 1% | F |
| mork-mork-match-first-8000 | 14,350,951 | 14,180,061 | 14,343,801 | -1.191% | 1% | F |
| mork-mork-match-last-2000 | 185,294,368 | 186,887,327 | 185,287,099 | +0.860% | 1% | L |
| mork-mork-match-last-500 | 64,532,986 | 65,402,732 | 64,707,426 | +1.348% | 1% | L |
| mork-mork-match-last-8000 | 847,230,279 | 862,837,725 | 847,222,876 | +1.842% | 1% | L |
| mork-mork-match-open-2000 | 56,489,538 | 49,780,853 | 56,489,503 | -11.876% | 1% | O |
| mork-mork-match-open-500 | 13,996,503 | 12,334,979 | 13,996,532 | -11.871% | 1% | O |
| mork-mork-match-open-8000 | 227,532,241 | 200,971,296 | 227,532,410 | -11.673% | 1% | O |
| mork-native-add-2000 | 25,167,493 | 25,360,289 | 25,360,303 | +0.766% | 1% | A |
| mork-native-add-500 | 6,298,841 | 6,347,553 | 6,348,123 | +0.773% | 1% | A |
| mork-native-add-8000 | 106,583,867 | 106,290,327 | 106,214,356 | -0.275% | 4% | A |
| mork-native-match-first-2000 | 1,170,609 | 1,169,640 | 1,173,793 | -0.083% | 1% | N |
| mork-native-match-first-500 | 1,180,261 | 1,173,793 | 1,173,783 | -0.548% | 1% | N |
| mork-native-match-first-8000 | 1,182,171 | 1,175,703 | 1,175,693 | -0.547% | 1% | N |
| mork-native-match-last-2000 | 1,191,071 | 1,184,603 | 1,184,593 | -0.543% | 1% | N |
| mork-native-match-last-500 | 1,191,061 | 1,184,593 | 1,184,583 | -0.543% | 1% | N |
| mork-native-match-last-8000 | 1,192,971 | 1,186,503 | 1,186,493 | -0.542% | 1% | N |
| mork-native-match-open-2000 | 4,016,905 | 4,016,773 | 4,016,764 | -0.003% | 1% | E |
| mork-native-match-open-500 | 1,010,896 | 1,010,763 | 1,010,753 | -0.013% | 1% | E |
| mork-native-match-open-8000 | 16,040,602 | 16,040,647 | 16,040,636 | +0.000% | 1% | E |
| mork-per-atom-add-2000 | 159,015,429 | 159,114,966 | 159,119,044 | +0.063% | 1% | Q |
| mork-per-atom-add-500 | 38,905,502 | 38,550,807 | 38,554,824 | -0.912% | 1% | Q |
| mork-per-atom-add-8000 | 636,538,936 | 636,885,586 | 636,901,563 | +0.054% | 1% | Q |
| mork-window-floor | 28,838 | 28,764 | 28,774 | -0.257% | 2% | W |

Mechanisms follow the executed paths in `mork_ffi/src/lib.rs`, `mork_ffi/morkspaces.pl`, `engine/spaces/native_matching.pl` and the published dependency source:

- B: one text batch parses and inserts through load_all_sexpr and PathMap::insert; the new pair adds about 0.26% over the old-pair control.
- Q: queue-atom appends text without inserting into the trie; the old-pair control reproduces the new count within 0.011%, so the historical movement is loaded-code layout, not changed trie work.
- A: the native write funnel is unchanged; the old-pair control reproduces the new count within 0.08%, isolating the historical movement to allocation/code layout.
- F: a bound prefix selects one trie path; the new expression application and binding representation lower the old-pair control by about 1.14-1.18%.
- L: a bound suffix scans candidate paths; the new zipper/unification implementation adds about 0.86-1.85% over the old-pair control, with unchanged Prolog inferences.
- O: one emitted result per atom uses ItemSink and the specialized pattern cycle/count pass; the new application path lowers the old-pair control by 11.67-11.88%, with unchanged answer counts and Prolog inferences.
- N: the unchanged warmed native clause index answers one row; the old-pair control differs by at most 0.36%, so the historical change is loaded-code layout.
- N: the unchanged warmed native clause index answers one row; the old-pair control differs by fewer than 0.001%, isolating the historical change to loaded-code layout.
- E: the unchanged native enumerator emits every row; its old-pair control differs by fewer than 0.001%.
- P: queued text is parsed and inserted by load_all_sexpr through PathMap::insert; the new pair increases this Rust-only publication work by 3.98-4.09%, while Prolog stays at 19 inferences.
- W: the unchanged perf disable/acknowledgement handshake is the window floor; the old-pair control differs by 10 instructions and both are within the original 2% band.

The per-output changes follow MORK's ItemSink application, specialized pattern count/cycle pass, ground-span skipping and reusable/direct-index binding storage. Prefix and suffix query controls separate one selected path from many rejected candidates. The unchanged local parser calls `PathMap::insert` for both flush and batch addition; parser source is unchanged between the upstream pins, while PathMap's write zipper and trie mutation implementations changed. The control attributes their added publication work to the rebuilt pair. Queue-only and native paths are controls on host cost and cannot establish a Rust speedup.

### The skewed triangle sweep

| route | N | instructions | old-pair control | inferences | CPU seconds |
|---|---:|---:|---:|---:|---:|
| native | 100 | 1,009,928 | 1,009,870 | 1,481 | 0.000041410 |
| mork | 100 | 7,997,175 | 7,849,405 | 196 | 0.000345000 |
| native | 400 | 3,915,471 | 3,915,461 | 5,681 | 0.000143140 |
| mork | 400 | 122,623,865 | 120,412,860 | 196 | 0.005173511 |
| native | 1600 | 15,537,045 | 15,537,033 | 22,481 | 0.000550470 |
| mork | 1600 | 1,567,416,445 | 1,550,624,339 | 196 | 0.065138345 |
| native | 3200 | 31,065,221 | 31,065,210 | 44,881 | 0.001068811 |
| mork | 3200 | 7,508,864,472 | 7,362,283,531 | 196 | 0.310242922 |

Least-squares regression of log(instructions) on log(N), using the four minima, gives native 0.988795 and MORK 1.951383. The same-workload old-pair controls give 0.988811 and 1.952079. The observed classes remain linear native and quadratic MORK; the pin bump does not remove the candidate product. At N=3200, MORK retires 241.712894 times the native instructions. Its inference count stays 196 even as Rust work grows from 7,997,175 to 7,508,864,472 instructions, which demonstrates why inferences cannot decide this comparison.

The path graph and skewed triangle have different measured classes on both pairs. The graph must be named with any class claim. No engine dispatch, provider claim or upstream feature selection changed.

### Load beside every measurement

Each cell records the one-, five- and fifteen-minute load averages before and after its three valid samples. Full `/proc/loadavg` strings and all raw samples were printed by the runner; the baseline stores the full load strings beside each row's explanation. The original-row control load was 9.01 at entry and 11.42 after its last original row. The corrected new sweep ran from 11.19 to 10.65. No bandwidth or CPU-time envelope was inferred from those loads.

| row | new load before / after (1, 5, 15 min) | old control load before / after |
|---|---|---|
| mork-batch-add-2000 | 14.06, 16.02, 13.11 / 13.81, 15.93, 13.10 | 10.97, 12.68, 12.47 / 10.97, 12.68, 12.47 |
| mork-batch-add-500 | 14.06, 16.05, 13.10 / 14.06, 16.05, 13.10 | 9.01, 12.38, 12.37 / 9.01, 12.38, 12.37 |
| mork-batch-add-8000 | 13.59, 15.85, 13.08 / 13.38, 15.77, 13.07 | 10.52, 12.53, 12.42 / 10.52, 12.53, 12.42 |
| mork-flush-2000 | 13.59, 15.85, 13.08 / 13.59, 15.85, 13.08 | 10.65, 12.59, 12.44 / 10.52, 12.53, 12.42 |
| mork-flush-500 | 14.06, 16.02, 13.11 / 14.06, 16.02, 13.11 | 10.97, 12.68, 12.47 / 10.97, 12.68, 12.47 |
| mork-flush-8000 | 12.86, 15.54, 13.04 / 12.71, 15.46, 13.03 | 11.22, 12.61, 12.45 / 11.42, 12.61, 12.45 |
| mork-mork-conjunction-100 | 11.19, 12.60, 12.79 / 11.19, 12.60, 12.79 | 9.69, 11.88, 12.53 / 9.69, 11.88, 12.53 |
| mork-mork-conjunction-1600 | 10.85, 12.51, 12.76 / 10.85, 12.51, 12.76 | 9.71, 11.84, 12.51 / 9.76, 11.78, 12.49 |
| mork-mork-conjunction-3200 | 10.70, 12.45, 12.74 / 10.65, 12.41, 12.72 | 9.54, 11.70, 12.46 / 9.25, 11.61, 12.42 |
| mork-mork-conjunction-400 | 10.85, 12.51, 12.76 / 10.85, 12.51, 12.76 | 9.69, 11.88, 12.53 / 9.71, 11.84, 12.51 |
| mork-mork-match-first-2000 | 13.81, 15.93, 13.10 / 13.81, 15.93, 13.10 | 10.97, 12.68, 12.47 / 10.65, 12.59, 12.44 |
| mork-mork-match-first-500 | 14.06, 16.05, 13.10 / 14.06, 16.05, 13.10 | 9.01, 12.38, 12.37 / 9.49, 12.42, 12.39 |
| mork-mork-match-first-8000 | 13.38, 15.77, 13.07 / 13.38, 15.77, 13.07 | 10.52, 12.53, 12.42 / 10.80, 12.55, 12.43 |
| mork-mork-match-last-2000 | 13.81, 15.93, 13.10 / 13.59, 15.85, 13.08 | 10.65, 12.59, 12.44 / 10.65, 12.59, 12.44 |
| mork-mork-match-last-500 | 14.06, 16.05, 13.10 / 14.06, 16.02, 13.11 | 9.49, 12.42, 12.39 / 9.49, 12.42, 12.39 |
| mork-mork-match-last-8000 | 13.19, 15.69, 13.06 / 12.86, 15.54, 13.04 | 10.80, 12.55, 12.43 / 10.80, 12.55, 12.43 |
| mork-mork-match-open-2000 | 13.59, 15.85, 13.08 / 13.59, 15.85, 13.08 | 10.65, 12.59, 12.44 / 10.65, 12.59, 12.44 |
| mork-mork-match-open-500 | 14.06, 16.02, 13.11 / 14.06, 16.02, 13.11 | 9.49, 12.42, 12.39 / 9.49, 12.42, 12.39 |
| mork-mork-match-open-8000 | 12.86, 15.54, 13.04 / 12.86, 15.54, 13.04 | 10.80, 12.55, 12.43 / 10.80, 12.55, 12.43 |
| mork-native-add-2000 | 13.81, 15.93, 13.10 / 13.81, 15.93, 13.10 | 10.97, 12.68, 12.47 / 10.97, 12.68, 12.47 |
| mork-native-add-500 | 14.06, 16.05, 13.10 / 14.06, 16.05, 13.10 | 9.01, 12.38, 12.37 / 9.01, 12.38, 12.37 |
| mork-native-add-8000 | 13.38, 15.77, 13.07 / 13.38, 15.77, 13.07 | 10.52, 12.53, 12.42 / 10.52, 12.53, 12.42 |
| mork-native-conjunction-100 | 11.19, 12.60, 12.79 / 11.19, 12.60, 12.79 | 9.69, 11.88, 12.53 / 9.69, 11.88, 12.53 |
| mork-native-conjunction-1600 | 10.85, 12.51, 12.76 / 10.85, 12.51, 12.76 | 9.71, 11.84, 12.51 / 9.71, 11.84, 12.51 |
| mork-native-conjunction-3200 | 10.85, 12.51, 12.76 / 10.70, 12.45, 12.74 | 9.76, 11.78, 12.49 / 9.54, 11.70, 12.46 |
| mork-native-conjunction-400 | 11.19, 12.60, 12.79 / 10.85, 12.51, 12.76 | 9.69, 11.88, 12.53 / 9.69, 11.88, 12.53 |
| mork-native-match-first-2000 | 13.81, 15.93, 13.10 / 13.81, 15.93, 13.10 | 10.65, 12.59, 12.44 / 10.65, 12.59, 12.44 |
| mork-native-match-first-500 | 14.06, 16.05, 13.10 / 14.06, 16.05, 13.10 | 9.49, 12.42, 12.39 / 9.49, 12.42, 12.39 |
| mork-native-match-first-8000 | 13.38, 15.77, 13.07 / 13.19, 15.69, 13.06 | 10.80, 12.55, 12.43 / 10.80, 12.55, 12.43 |
| mork-native-match-last-2000 | 13.59, 15.85, 13.08 / 13.59, 15.85, 13.08 | 10.65, 12.59, 12.44 / 10.65, 12.59, 12.44 |
| mork-native-match-last-500 | 14.06, 16.02, 13.11 / 14.06, 16.02, 13.11 | 9.49, 12.42, 12.39 / 9.49, 12.42, 12.39 |
| mork-native-match-last-8000 | 12.86, 15.54, 13.04 / 12.86, 15.54, 13.04 | 10.80, 12.55, 12.43 / 10.80, 12.55, 12.43 |
| mork-native-match-open-2000 | 13.59, 15.85, 13.08 / 13.59, 15.85, 13.08 | 10.65, 12.59, 12.44 / 10.65, 12.59, 12.44 |
| mork-native-match-open-500 | 14.06, 16.02, 13.11 / 14.06, 16.02, 13.11 | 9.49, 12.42, 12.39 / 10.97, 12.68, 12.47 |
| mork-native-match-open-8000 | 12.86, 15.54, 13.04 / 12.86, 15.54, 13.04 | 10.80, 12.55, 12.43 / 11.22, 12.61, 12.45 |
| mork-per-atom-add-2000 | 13.81, 15.93, 13.10 / 13.81, 15.93, 13.10 | 10.97, 12.68, 12.47 / 10.97, 12.68, 12.47 |
| mork-per-atom-add-500 | 14.06, 16.05, 13.10 / 14.06, 16.05, 13.10 | 9.01, 12.38, 12.37 / 9.01, 12.38, 12.37 |
| mork-per-atom-add-8000 | 13.38, 15.77, 13.07 / 13.38, 15.77, 13.07 | 10.52, 12.53, 12.42 / 10.52, 12.53, 12.42 |
| mork-window-floor | 13.98, 16.07, 13.09 / 14.06, 16.05, 13.10 | 9.01, 12.38, 12.37 / 9.01, 12.38, 12.37 |

### Focused verification before landing

The repaired seat builds, the seven Rust tests pass, and the MORK seat suite passes all 25 tests with its absent-artifact controls. The Python MORK file collects and passes all 28 tests, including the generated projected-bag differential. The corrected benchmark selftest passes seven tests, including wrong triples at the correct count and an always-empty query. Ruff reports no findings in the changed Python files. The provenance selftest reports zero defects across 32 placeholders in 14 files; the evidence check under the required Python reports zero unbacked tags.

The published MORK differential builds both default-product and leapfrog executables and reports 99 matching programs, zero failures and five documented skips out of 104. The skips are the unavailable min sink, two explicitly slow exponential fixtures, the declared comment-before-closing-bracket parser bug, and an empty file. Those are the upstream corpus's declared exclusions, not omitted PeTTa MORK tests.

Open: committed-tree gate results and the final provenance pin.

### Final fixture correction

The six native selective rows in the first table and the statement that every original row retains its first re-pin are superseded by the table below. The initial original-row measurements and their old-pair controls loaded the path-graph helper definitions. The eight corrected sweep rows loaded the final skewed-triangle definitions.

Tried: the first committed-tree `sh extensions/mork/check.sh` exited 1. The seat, Rust, lint and benchmark selftest lanes passed, but six native selective rows exceeded their unchanged 1% bands. Each repeated query window grew by about 14,400 instructions. The other thirty-three rows passed, including all eight sweep rows.

Tried: SHA-256 comparison found identical bytes in all five engine shared objects between the new-pair checkout and the old-pair control. In the old-pair checkout, `bench.windowed("window-floor", 500, 3)` followed by `bench.windowed("native-match-first", 500, 3)`, with the final skewed-triangle workload and short WORKTREE header, returned floor [28774, 28774, 28774] and raw [1216941, 1216941, 1216941], or 1,188,167 net instructions. Load was 11.86, 12.65, 11.89.

Tried: change only the new helper definitions in that old-pair workload back to the path-graph fixture, then run the same two calls. The floor stayed [28774, 28774, 28774]; raw counts became [1202665, 1202557, 1202509], whose net minimum is 1,173,735. Load was 10.03, 11.05, 11.38. The skewed fixture was then restored exactly. The 14,432-instruction difference isolates the added fixture definitions; the native query itself, dependency pair and compiled engine bytes stayed fixed. The exact native layout mechanism is not isolated.

Decided: retain the first re-pin for the other twenty-five original rows and the final skew pins for all eight new rows. Correct these six native pins from the three valid samples already obtained by the failing committed-tree check. A single final-fixture old-pair control measures all six, with all three seats loaded, at one-minute loads 9.27 to 9.09. Five controls differ from the new pair by 16 instructions; native first-at-500 differs by 2,176 because its three valid controls are [1188167, 1186007, 1188167]. The minimum is retained. No band is widened and no historical envelope is collected.

| row | first re-pin | final pin | final old-pair control | original-to-final |
|---|---:|---:|---:|---:|
| mork-native-match-first-2000 | 1,169,640 | 1,188,193 | 1,188,177 | +1.502% |
| mork-native-match-first-500 | 1,173,793 | 1,188,183 | 1,186,007 | +0.671% |
| mork-native-match-first-8000 | 1,175,703 | 1,190,093 | 1,190,077 | +0.670% |
| mork-native-match-last-2000 | 1,184,603 | 1,198,993 | 1,198,977 | +0.665% |
| mork-native-match-last-500 | 1,184,593 | 1,198,983 | 1,198,967 | +0.665% |
| mork-native-match-last-8000 | 1,186,503 | 1,200,893 | 1,200,877 | +0.664% |

| row | new load before / after | old control load before / after |
|---|---|---|
| mork-native-match-first-2000 | 11.90, 11.51, 11.43 / 11.90, 11.51, 11.43 | 9.27, 10.71, 11.15 / 9.09, 10.65, 11.12 |
| mork-native-match-first-500 | 11.75, 11.47, 11.42 / 11.75, 11.47, 11.42 | 9.27, 10.71, 11.15 / 9.27, 10.71, 11.15 |
| mork-native-match-first-8000 | 10.44, 11.20, 11.33 / 10.44, 11.20, 11.33 | 9.09, 10.65, 11.12 / 9.09, 10.65, 11.12 |
| mork-native-match-last-2000 | 11.90, 11.51, 11.43 / 11.90, 11.51, 11.43 | 9.09, 10.65, 11.12 / 9.09, 10.65, 11.12 |
| mork-native-match-last-500 | 11.75, 11.47, 11.42 / 11.75, 11.47, 11.42 | 9.27, 10.71, 11.15 / 9.27, 10.71, 11.15 |
| mork-native-match-last-8000 | 10.44, 11.20, 11.33 / 10.44, 11.20, 11.33 | 9.09, 10.65, 11.12 / 9.09, 10.65, 11.12 |

There are now eleven original rows outside their original bands. All eleven have same-workload old-pair controls: ten from the initial paired measurement and native first-at-2000 from the final-fixture control. The complete final numbers and their load strings are recorded beside the baseline rows.

Tried: `sh tools/check.sh petta parity examples plunit evidence provenance-pin-selftest llms llms-selftest build` exited 1 with only `llms` failing. The other eight requested lanes passed. The five findings were absent generated Node paths: `browser/`, `_runtime/`, `_runtime/`, `runtime.json` and `wasm/` at `extensions/node/llms.txt:308-310`. The package's existing `npm run prepare --silent` built those artifacts locally and exited 0; no Node source changed. The Python whole-suite MORK selection also exited 0: 30 passed, 4700 deselected, zero skips.

The functional and provenance commits remain intact. This correction adds a baseline-and-journal commit followed by a provenance-only commit. The passed behavior lanes remain evidence for the unchanged source. Open: rerun the failed `mork-bench` and `llms` lanes on the corrected committed tree; record their exits and the final provenance validation in the handoff.
