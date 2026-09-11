<!-- Purpose: record the standard-library census, binding design and verified library deliveries. -->
# A standard library for a language

Goal: supply the common libraries a MeTTa programmer expects, with native Prolog
implementations, declared types and documentation, executable examples and measured
costs.
Constraint: keep the lib_patrick idioms and names; derive foreign faces from their
backing declarations; preserve nondeterministic answers; keep Python framework
integrations in separate distributions; one complete library per commit.

## 2026-09-11: opening census, before implementation

Tried: `metta.library.roster()` and `metta.library.rows(name)` on
`c75181adc999adf0028616ee69565e2bbfbf739f` -> 38 libraries, 680 carried rows,
660 distinct heads. The initial estimate of 39 libraries is not the live roster.
`sh check.sh corpus-coverage cumulative-syntax example-origins llms
llms-selftest reference docs lib-autoload` -> coverage 251 engine callables,
660 library heads, four allowed constructors/types and zero findings;
cumulative syntax 324 examples, 284 constructs and zero findings; library
autoload 22 files and zero findings. The llms lane initially reports five Node
asset-path claims before assets have been built. Origins and docs initially
skip their missing inputs. With METTA_UPSTREAM naming PeTTa-base and the existing
website dependencies provisioned, `sh check.sh example-origins docs` -> 143
derived examples, 202 original examples, ten passing origin selftests and a
successful VitePress build.

Tried: `sh check.sh llms` after the asset build -> five sheets, 319 live
engine names, 223 corpus-used callable names covered and zero findings. The
five initial path findings were missing build artifacts, not source defects.

The concern yardstick is the [Python 3.14 library index](https://docs.python.org/3.14/library/index.html).
Native providers are checked against the [SWI library index](https://www.swi-prolog.org/pldoc/man?section=libpl)
and the installed source files resolved with
`absolute_file_name(library(Name), File, [file_type(prolog), access(read)])`.
The running host is SWI-Prolog 10.1.13. Every named native library in the table
resolves locally, including yaml, unicode, sgml, xpath, archive and optparse.

`swipl -g "forall(pack_property(P, version(V)), (write(P-V), nl))" -t halt`
reports: lambda 1.0.0, edcg 0.9.1.8, scasp 1.1.4, rtchecks 0.0.1,
assertions 0.0.1, wsdl 0.1, egraph 0.6.0, rdet 1.0.2, xlibrary 0.0.2,
fluents 0.1.2, race 0.1.0, ciao 0.0.1, prolog_lsp 0.0.10 and log4p 0.0.9. No SQLite or TOML pack is installed.

The order below is the implementation order. Existing minimal libraries precede
new concerns. A row describes a concern's complete contract, rather than claiming
to reproduce every Python module or platform-specific API.

| Order / concern | Python 3.14 yardstick | SWI implementation | PeTTa at the cut, by head | Decision |
|---|---|---|---|---|
| 1. Dates and calendars | datetime, calendar, time, zoneinfo | date; format_time/3, stamp_date_time/3 | `lib_datetime`: `now`, `format_date`, `day_of_week`, `format-date`, `day-of-week` | Extend: parsing, timestamp/date conversion, calendar fields, date arithmetic, weekday/year-day and formatting with an explicit zone. Keep existing names. |
| 2. Regular expressions | re | pcre | `lib_regex`: `regex_match`, `regex_find`, `regex_captures`, `regex_split`, `regex_replace`, `regex_replace_all`, `re-match`, `re-find`, `re-captures`, `re-split`, `re-replace`, `re-replace-all` | Extend: compilation, capture enumeration, ranges, counting, escaping and full-match, alongside all existing matching, splitting and replacement heads. |
| 3. JSON | json | http/json; engine JSON codec | `lib_json`: `json-decode`, `json-encode`, `dict-space`, `get-keys`, `get-value` | Extend: text and file round trips, formatting, line documents and structural path lookup. Preserve objects as spaces, arrays as expressions and native scalar types. |
| 4. Hashing and cryptography | hashlib, hmac, secrets | crypto, sha | `lib_crypto`: `crypto_hash`, `crypto_random_hex`, `crypto-hash`, `crypto-random-hex` | Extend: bytes and file digests, HMAC, secure bytes and bounded integers, password derivation and verification. Preserve reduced-platform SHA support and named capability refusals. |
| 5. Delimited records | csv | csv | `lib_csv`: `csv-space`, `csv-snapshot!` | Extend: parse and encode records, file write and append, dialect options and streaming rows, preserving strings, quoting, width validation and existing provider ownership. |
| 6. Strings, formatting and similarity | str, string, textwrap, difflib | strings, isub; built-in text predicates | `lib_string`: `string-length`, `string-slice`, `string-split`, `string-join`, `string-trim`, `string-upper`, `string-lower`, `string-starts-with`, `string-ends-with`, `string-contains`, `string-index-of`, `string-replace`, `string-chars`, `string-from-chars`, `string-repeat`, `string-pad-left`, `string-pad-right`, `parse-number`, `number-to-string` | Extend: character/code conversion, exact splitting, search/count, alignment, templates, wrapping, edit distance and similarity; keep text coercions and empty-string cases explicit. |
| 7. Numeric vectors | array, math | lists; arithmetic | `lib_vector`: `dot`, `cosine-of-normalized`, `norm`, `cosine`, `random-normal-vector` | Extend: validated dot/norm/cosine, elementwise arithmetic, scale, normalization, distance and vector construction through native loops; preserve existing heads and clarify random unit-vector semantics. |
| 8. Files, directories and paths | io, pathlib, os.path, tempfile, glob, shutil, stat | filesex, readutil; stream and path predicates | `lib_file`: `file-open!`, `file-read-to-string!`, `file-read-exact!`, `file-write!`, `file-seek!`, `file-get-size!`, `file-close!`, `read-file!`, `write-file!`, `append-file!`, `file-lines!`, `file-space!`, `delete-file!`, `temp-path!`, `temp-dir!`, `list-dir!`, `file-exists`, `dir-exists`, `make-dir!`, `delete-dir!`, `copy-file!`, `file-metadata!`, `path-join`, `path-parent`, `path-name`, `path-extension`, `stdin`, `stdout`, `stderr`, `stderr!`, `stdin-to-string!`, `exit!` | Extend: binary data, traversal/globbing, renaming, directory copying/removal, path normalization and scoped streams. Preserve handles and close every owned resource. |
| 9. Queryable spaces | no direct counterpart; collections and query iterators | published engine space services | `lib_spaces`: `migrateAtoms`, `find`, `succeedsPredicate`, `remove-all-atoms`, `match-count` | Extend: bulk selection/copy/move, snapshots and predicates through existing space operations. Correct migrateAtoms only after reproducing its source/destination defect. |
| 10. Mutable dictionaries | dict, collections | native spaces and existing dict-space/get-value heads | `lib_dict`: `dict-put`, `dict-remove`, `dict-remove-pair`, `dict-has`, `dict-size`, `dict-pairs`, `dict-values` | Extend: construction, lookup defaults, updates, merge, pop and clear as a space; preserve key and value multiplicity contracts. |
| 11. Persistent collections and priority queues | collections, heapq, bisect | assoc, rbtrees, heaps, lists | `lib_datastructures`: `enqueue`, `dequeue`, `empty-queue`, `add-unique-or-fail`, `FTree`, `FTEmpty`, `FTSingle`, `FTDeep`, `ft-empty`, `ft-is-empty`, `ft-push-front`, `ft-push-back`, `ft-node-digit`, `ft-pop-front`, `ft-borrow-l`, `ft-pop-back`, `ft-borrow-r`, `ft-front`, `ft-back`, `ft-from-list`, `ft-to-list`, `ft-nodes`, `ft-push-list-front`, `ft-push-list-back`, `ft-app3`, `ft-concat` | Extend: native association and red-black maps, heaps/priority queues, queues and deques, retaining finger-tree heads. Empty removal and missing keys have explicit contracts. |
| 12. Combinatorial generators | itertools, math | lists, aggregate, between/3 | `lib_combinatorics`: `weighted-subset-mass-independent`, `weighted-subset-posterior-independent`, `range`, `choose2`, `choose2l`, `chooseKl`, `chooseK`, `takeK` | Extend: products, permutations, combinations, powersets, stepped ranges and exact counts. Preserve answer multiplicity, finite-domain refusals and exact weighted posteriors. |
| 13. Finite probability distributions | statistics; no weighted-space counterpart | aggregate; exact arithmetic | `lib_distribution`: `ws-map`, `ws-map2-independent`, `ws-mass-at-least`, `ws-prob-gt-independent`, `ws-condition-joint`, `ws-average-independent`, `ws-add-bernoulli-independent` | Extend: moments, variance, CDF, quantile and sampling over the established weighted carrier; preserve explicit independence and zero-mass refusals. |
| 14. Functional and iteration utilities | functools, itertools, operator | apply, aggregate, solution_sequences; translator rules | `lib_patrick`: `compose`, `@`, `for`, `iterate` | Add lib_functional: pipe, unfold, zip/unzip, group/sort by key, take/drop/chunk/window, partition, flatten, scan and foldall faces, plus while/repeat/unless rules. lib_patrick imports it and keeps compose, @, for and iterate in place. |
| 15. Sets and ordered sets | set, frozenset | ordsets, lists | None | Add lib_sets: construction, membership, union/intersection/difference, subset/disjointness and insertion/removal; distinguish term order from unification. |
| 16. Pairs and grouped records | dict.items, itertools.groupby | pairs, keysort/2 | None | Add lib_pairs: key/value projection, conversion, stable sorting and key grouping; preserve duplicate pairs and document sorted-input requirements. |
| 17. Directed graphs | graphlib | ugraphs | None | Add lib_graph: vertices/edges, insertion/removal, neighbors, reachability, transpose, union, closure and topological ordering; refuse cycles where ordering requires a DAG. |
| 18. Unicode | unicodedata, stringprep | unicode; code_type/2 | None | Add lib_unicode: normalization forms, Unicode properties/categories, case folding and codepoint validation using the host database. |
| 19. Parsing and grammars | shlex; parser interfaces | dcg/basics, dcg/high_order | None | Add lib_parsing: composable DCG-backed grammar values, whole-input and remainder parsing, token/number/quoted-text primitives, alternatives and repetition; failed matches remain no answers. |
| 20. YAML | no standard module | yaml | None | Add lib_yaml: read/write strings and files, preserving scalar, sequence and mapping structure with explicit unsupported-tag refusals. |
| 21. XML, HTML and XPath | xml, html | sgml, sgml_write, xpath | None | Add lib_markup: parse/write XML and HTML, DOM selection and attributes, XPath queries as multiple answers. Prevent accidental external entity fetches. |
| 22. Binary encodings | base64, binascii, codecs, struct | base64, crypto; code conversion | None | Add lib_encoding: UTF-8, byte/hex and base64 round trips, URL-safe base64 and explicit malformed-input refusals. Arbitrary ABI struct layouts remain a host FFI concern. |
| 23. Environment and platform | os, platform, errno | environment and Prolog flags | None | Add lib_system: read/set/unset/enumerate environment, current directory and platform metadata; no implicit shell command evaluation. |
| 24. Child processes | subprocess | process | None | Add lib_process: executable plus argument-vector invocation, captured output/status, spawn/wait/terminate and explicit stream ownership. Nonzero exit is a status; launch failures raise. |
| 25. Identifiers | uuid | uuid | None | Add lib_uuid: generation by supported version/options and validation; deterministic namespace/name cases accompany random identifiers. |
| 26. Logging | logging, warnings | print_message/2, debug | None | Add lib_logging: structured messages by topic/level, enable/disable topics and captureable handlers using the host message mechanism. |
| 27. Numbers and number theory | math, fractions, decimal, cmath | arithmetic, clpfd | Existing core arithmetic, comparison, bit and random heads; 193 declared rows in lib_builtin_types | Add lib_math for missing integer/rational and floating functions, exact gcd/lcm/factorial/binomial and finite-domain number theory; retain the existing arithmetic and bit families. |
| 28. Random generation | random | random | Existing core arithmetic, comparison, bit and random heads; 193 declared rows in lib_builtin_types | Add lib_random: choice, sampling, shuffling and common distributions; compose with the existing scoped with-seed contract. |
| 29. Descriptive statistics | statistics | aggregate, lists; arithmetic | None | Add lib_statistics: totals, means, median, quantiles, mode, variance, standard deviation, covariance/correlation and regression with defined empty/small-sample refusals. |
| 30. HTTP | urllib.request, http.client, http.server | http/http_open, http/http_server, http/http_dispatch | None | Add lib_http: request methods, body/headers/status and streaming ownership, local server start/routes/stop. Verify client and server together over loopback. |
| 31. URLs and URIs | urllib.parse | uri | None | Add lib_uri: components, normalization, resolution, percent coding and query pairs. Preserve duplicate query keys and distinguish encoding contexts. |
| 32. Sockets | socket, selectors | socket; wait_for_input/3 | None | Add lib_socket: TCP connect/listen/accept and UDP send/receive with explicit close, endpoint values, binary-safe payloads and loopback tests. |
| 33. Compression and archives | zlib, gzip, tarfile, zipfile, bz2, lzma | zlib, archive | None | Add lib_compression: gzip/zlib bytes and files, archive entries and extraction with path validation; expose only formats the linked host supports. |
| 34. Persistent local storage | shelve, dbm, sqlite3 | persistency; sqlite pack absent | None | Add lib_database using persistency: independent stores, query/add/remove, sync/close and reopening tests. SQLite is conditional on an installed pack, absent here. |
| 35. Assertions and property generation | unittest, doctest; random for generated cases | plunit, random; engine test/assertions | `lib_conformance`: `metta_check_space_provider`, `check-space-provider` | Add lib_testing: generated integer/list/choice domains, quantified properties and assertion helpers; retain engine test and bag assertions as the verdict authority. |
| 36. Command-line options | argparse, optparse | optparse | None | Add lib_cli: typed option declarations, defaults, short/long names, help and positional arguments; malformed/unknown options name their repair. |

### Facilities already supplied and boundaries

| Concern | Python yardstick | Native source | Current PeTTa | Decision |
|---|---|---|---|---|
| Threads, futures, channels, timers and locks | threading, concurrent.futures, queue, sched | thread, thread_pool, broadcast and alarms | lib_thread: 58 carried heads, including spawn/await/cancel, channels, pools, after/every and scopes | Existing implementation supplies this concern; retain its lifecycle and cost contracts. No second timer mechanism. |
| Memoization and tabling | functools | tabling and engine memoization | lib_memo: 9; lib_tabling: 11 | Existing implementation supplies the concern; preserve its owner and transaction behavior. |
| Constraint solving | no direct module | clpq, clpb, clpfd | lib_constraints: 5; relational arithmetic in core | Existing solvers remain authoritative; the math library composes finite-domain operations. |
| Weighted measures | no direct module | native weighted carriers | lib_measure: 17 | Existing normalization, ranking, folding and sampling support distribution extensions. |
| Reflection, tracing and documentation | inspect, traceback, pydoc, dis | engine declaration and observation services | lib_reflect: 19; lib_observe: 2; lib_doc: 0, documentation now in core | Existing engine services supply the concern; no parallel metadata registry. |
| Imports and packages | importlib, pkgutil | source loader and host registration seam | lib_import: 8; lib_zar: 4; lib_gitimport: Prolog-only | Retain loader behavior. Package equations are a separate package; this work produces a mechanically migratable backing declaration. |
| Language types and compatibility equations | typing, types, enum | engine type and prelude services | lib_builtin_types: 193; lib_he: 18; lib_derived: 1 | Retain compiler-owned and vendored semantics. Do not regenerate vendored sources. |
| Graph rewriting and reasoning dialects | no direct module | engine and extension seams | lib_mm2: 5; lib_nars: 38; lib_pln: 49; lib_pln2: 9; lib_soft: 9; lib_strategy: 24; lib_roman: 36 | These established domain libraries remain in place; standard-library work does not redesign their calculi. |
| Redis | no standard module | redis | lib_redis: redis-attach, redis-detach | Existing provider exposes a Redis-backed space; verify its retained example and named missing-server refusal. A second command wrapper would duplicate the space API. |
| Python compute/data frameworks | third-party ecosystem | Python distribution entry points | generated lib_torch face; extensions/python/ext distributions | Framework-specific expansion is outside core. Prove the declaration shape against an existing external distribution through metta.libraries. |
| TOML | tomllib | no installed TOML pack | None | Out of scope on this host under the explicit pack condition. Revisit when a maintained pack is installed and declared with its remedy. |
| Specialized protocols and desktop interfaces | email, mailbox, ftplib, poplib, imaplib, smtplib, tkinter, curses, turtle, webbrowser | independent host packages | Host calls and extension seams | Out of scope: independent application/GUI protocol domains, not required by the ruling's standard-library concerns. |
| Host ABI, interpreter internals and deployment | ctypes, sys, gc, marshal, import machinery, packaging tools | Prolog foreign and host seams | Published engine, host and package interfaces | Out of scope: copying another interpreter's ABI or deployment machinery would create a second runtime. Binary codecs remain in scope. |
| Decimal/complex backends and unsupported compression formats | decimal, cmath, compression.zstd | no selected native provider | Exact integers/rationals and native floats already available | Out of scope without a declared provider; do not approximate exact arithmetic or claim an unavailable codec. |

Decided: the library face is a projection, analogous to bindings derived from an
interface definition and a database view derived from source records. SWI already
provides the parser and metadata through
[`prolog_xref`](https://www.swi-prolog.org/pldoc/man?section=prologxref);
its [V10.1.13 source](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/library/prolog_xref.pl)
supplies xref_exported/2, xref_mode/3 and xref_comment/4. A plain-SWI probe on
library(date) returned its five exported predicates, typed modes and summaries.
Use those declarations instead of parsing Prolog with a Python regular expression.
A mode retains the host's final-output calling convention; a nondeterministic
predicate keeps its answer stream.

Rejected: one handwritten list each for exports, import names, types and docs,
because those copies can disagree. Rejected: wrapping every primitive in another
MeTTa equation, because the registered predicate already compiles to a native
call. Keep handwritten equations only when they express actual MeTTa composition
or preserve an existing public name.

Open: verify detailed contracts and native edge cases before each library's
implementation; settle generator failure cases and the generated-region boundary
before the first library changes. The census fixes concerns and order; subsequent
dated sections record measurements and justified design corrections.

## 2026-09-11: the library declaration shape

Tried: xref_source/2 over all 22 shipped Prolog halves -> each has an export
list, none has PlDoc mode declarations. A separate probe with an initialization
that throws was read without executing it; process_modes/6 retained argument
names, types, determinism and the documentation body.

Decided: the Prolog module owns its exports and typed PlDoc comments. The
generator uses prolog_xref and PlDoc to emit one import, arrow rows and @doc
rows in a delimited region of the adjacent MeTTa face. Pure MeTTa equations
and their documentation remain outside that region. Existing exported host
services that are not MeTTa heads use PlDoc's @private tag with their reason.
No new engine registration protocol is needed.

Decided: standard Prolog scalar types map to the existing MeTTa types; lists
map to Expression, and term/any map to %Undefined%. An explicitly named MeTTa
type remains that type. Arguments require named, explicit types. A forward
mode must put its single result last. Other relational modes do not change
the emitted arrow. Different arities and distinct typed overloads remain
distinct rows. Nondeterminism is left to the native call, with no collecting
wrapper.

Decided: discovery reads Prolog source modes as well as generated regions.
Removing the region marker or deleting the face therefore remains detectable.
A source with no export modes is reported as an unmigrated source; once any
export is described, missing metadata for another non-private export refuses
generation. Explicitly requested sources also require complete metadata.
Generation checks all inputs before writing, preserves handwritten bytes and
atomically replaces each changed file beside itself.

Rejected: a new Prolog parser or a hand-maintained face manifest, because the
host already supplies both syntax and public declarations. Rejected: loading
a library to inspect it, because an initializer can perform I/O. Rejected:
inferring a missing type or silently converting a relation's extra outputs to
a list, because neither is the declared interface.

Verification plan: native metadata fixtures with punctuation, nullary results,
overloads and multiple answers; real generated calls; planted type/doc/export,
module-name, syntax and region drift; a non-executed initializer; preservation
of handwritten equations; installed Python distribution discovery through
metta.libraries. The generated-artifact manifest owns the regions and the
gate's invocation. Documentation and corpus records use their existing
sources, with a regeneration command where the current checker has none.

Tried: the first face self-test run -> nine passes, a syntax-refusal failure,
and a fixture-loader error. xref_source/2 with silent(true) discards syntax
diagnostics; silent(false) lets --on-error=status refuse the source. Relative
CLI paths now resolve before output ownership is checked. The fixture uses
MeTTa.load, and generated native paths are relative to the standard library
root so the same projection reaches both libraries and source fixtures.
The corrected command, `python tests/checks/check_prologface_selftest.py`,
passes 12 tests in 3.094 seconds. jscpd over the new Python emitter and its
tests reports zero duplicate lines. Logs: ai-tmp/ai-libraries-face-selftest.log.

## 2026-09-11: datetime

Tried: `sh test.sh examples/ch08-data/08-03-the-shipped-libraries/07-datetime.metta`
before changes -> five passing assertions. Read library(date) and the native
date conversion documentation. SWI accepts UTC, local time and integer offsets
west of Greenwich; date_time_stamp/2 normalizes overflowing calendar fields.

Decided: keep the five existing heads and Symbol formatting results. Add
strictly reported parsing, explicit-zone String formatting, visible date
records, field queries, weekday/year-day, leap-year/month lengths and calendar
addition. A full record is `(date Y M D H Min S Offset Zone DST)`; a date-only
record is `(date Y M D)` at UTC midnight. Calendar addition normalizes overflow
and recomputes the local offset after the addition. Numeric seconds remain
ordinary arithmetic. The native calls do constant calendar work; parsing and
formatting depend on text length. No duplicate time-zone database or timer.

Rejected: changing TZ globally to emulate an IANA-zone API, because that
changes concurrent callers' environment. Revisit with a declared provider
that resolves named zones per call. The host's supported explicit-zone
interface remains available.

Tried: the datetime twin -> the idiom checker recommended S._ for S["-"].
The runtime probe returned `_` for S._ and `-` for S["-"], so following the
advice changed a date record. The hyphen branch copied an incomplete inverse
name map. Decided: require attribute_name(candidate) == name before suggesting
an attribute, using the factory's existing map. The same guard protects
trailing hyphens, whose trailing underscore is a keyword escape. Added both
to the existing exact-name regression. No declaration or compiler code changes.

Decided: library documentation and cards retain every declaration in
HeadRow.types. Both previously selected only the final arrow, hiding one of
parse-date's call forms. HeadCard now stores types as a tuple; its text, Rich
and HTML renderers share that representation. The regression checks both
arrows in the reference, the card data and all three displays.

Tried: `sh test.sh examples/ch08-data/08-03-the-shipped-libraries/07-datetime.metta`
after implementation -> 25 passing assertions; `sh engine/test.sh
suites/libraries/lib_datetime.plt` -> 15 passing tests. The card census reports
16 heads and 17 types, every head documented and called in the same example.
`python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/07-datetime.metta` measures
46,283 MeTTa inferences and 44,390 Python inferences, ratio 0.9591. The twin
then passes all 25 claims with equal stored content and zero findings. Only
its own budget was repinned; the point allowance is unchanged.

Tried: the built metta-arrays wheel -> the metta.libraries entry point locates
the installed generated face; both array and ordinary-list answers pass.
The distribution and record-projection run passes five tests. Native face
generation passes 12 tests; artifact ownership passes 14 tests; the README
count projection passes two tests; llms falsification passes 68 cases; the
card's overload and documentation checks pass two tests. jscpd reports zero
duplicate lines across the five new Python files. Changed Python files pass
ruff. Source and face syntax, metadata defects, malformed output regions,
concurrent edits and replacement errors all have refusal witnesses.

Tried: the per-library record lanes -> coverage grows from 660 to 671 carried
heads with zero findings; cumulative syntax remains 324 examples and 284
constructs; lineage remains 143 derived and 202 original files. llms, reference
and docs pass. The first gate invocation exposed a fixture assumption that
the working directory was the repository root. The test now uses a relative
path that can include parent components; `sh check.sh prolog-face reference`
passes both lanes and their witnesses from the gate's tests/prolog directory.
`sh check.sh artifact-sync face-sync no-autoload lib-autoload` also passes,
including the full corpus with autoload disabled and the wheel witness.

Tried: `pin_provenance.py --check` -> the installed distribution's nested module
and the two native face fixtures were outside the evidence source globs. The
distribution glob now recurses through packages, and the fixture directory is
included explicitly. Planted stale citations exercise all three paths; ignored
build copies remain outside the tracked-source scan. The evidence selftest
reports zero defects across 36 citation cases and all source-scope probes.

Evidence logs: ai-tmp/ai-libraries-datetime-{before,after,prolog,card,records}.log,
ai-tmp/ai-libraries-datetime-twin-{measure,repin,final}.log,
ai-tmp/ai-libraries-{distribution-projections,card-tests,face-reference-fixed,shape-final}.log.
