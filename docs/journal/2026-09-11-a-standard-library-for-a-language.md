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

## 2026-09-11: regex provider investigation

Tried: the existing regex example -> seven passing assertions. The installed
provider is SWI-Prolog 10.1.13 library(pcre), pinned by its release's submodule
to [52a0e9486c4770f2fbfac3f4fb8a1cd9e8c77af1](https://github.com/SWI-Prolog/packages-pcre/tree/52a0e9486c4770f2fbfac3f4fb8a1cd9e8c77af1).
Its re_foldl_ loop increments a byte after an empty match, including at the
subject's end. Folding the empty pattern over both ASCII and Unicode text
raises `representation_error(regex-offset)`. Starting re_matchsub at character
index 1 of either "a" or "é" raises `domain_error(offset,1)` because utf8_seek
rejects the end position. A Prolog loop over that predicate therefore cannot
fix the complete empty-match contract on this host.

Tried: a compiled regex round trip through a MeTTa let and Python's native
handle -> matching succeeds in both seats. Python repr raises
`AttributeError: 'metta._atoms.model._NativeHandle' object has no attribute 'value'`.
The handle deliberately has no Grounded.value payload; its display method
must use the native identity and text, as its wire encoding already does.
The defining lines were authored by MesTTo. Calling native re_split with a
compiled blob raises `type_error(text, <regex>(...))`; native split's range
compiler expects source text. Native capture types therefore need to remain
available beside any public compiled value.

Decided: native handle repr reads its identity and retained display text.
Its regression first failed with the AttributeError above while the other
three wire and persistence cases passed. SpaceHandle already supplies its
own repr, and ordinary Grounded values retain their payload representation.

Rejected: rewriting patterns to force progress, because extra captures and
lookarounds change numbering, anchors, backreferences and control verbs.
Rejected: dropping empty matches or suppressing the host error, because both
lose valid answers. Rejected: repeated whole-subject searches as the complete
fix, because the host refuses the end offset and each restart rescans a UTF-8
prefix. Target the provider's iteration boundary and retain native capture,
split and replacement semantics. A targeted primary-source research request
is checking available fixes and project-local integration choices.

Open: settle the provider repair before implementing the regex face. JSON
preparation verified that empty objects and duplicate object keys already
round-trip; preserve these space and bag semantics when its turn arrives.

### Provider design, before implementation

Tried: an isolated copy of the pinned SWI binding, with a separate module and
blob type, passes five probes for empty ASCII/Unicode matches, the empty
subject, end offsets and a nonempty alternative after an empty match. The
stock provider remains usable in the same process. The upstream suite passes
158 of 160 cases; one expects the defective end-offset refusal and the other
lacks its save/load input fixture in the scratch copy.

Decided: vendor that binding under lib_regex, retain its license and pin, and
repair its native iteration using the complete algorithm in
[PCRE2 10.46 pcre2demo.c](https://github.com/PCRE2Project/pcre2/blob/pcre2-10.46/src/pcre2demo.c).
This retries an empty match at the same position, then advances one Unicode
character or a configured CRLF pair. Keep its progress rule for backtracking
control and \\K. The installed 10.46 header has no pcre2_next_match declaration;
the pinned 10.47 NEWS introduces that API. Rejected: upgrading the linked
engine solely to obtain it, because that also changes Unicode data and global
matching behavior. Revisit when the supported host version advances.

Decided: retain actual compiled blobs across both seats. Split and replacement
request a private capture projection from the same compiled code: range(S,L)
for text geometry, value(Term) for parsed captures. A parsed term such as 1-2
therefore cannot be mistaken for geometry. Omit unmatched groups before using
their PCRE2_UNSET offsets. Build a character-boundary index only when ranges
are requested; conversion then costs O(subject bytes + capture count), with
O(subject bytes) temporary space, instead of repeatedly scanning prefixes.
The PCRE matching cost and materialized answers remain additional costs.

Decided: build the private native object on first import in an adjacent
ignored .native directory. A Prolog mutex and an OS file lock serialize
threads and processes; build to a temporary sibling and rename only after a
successful synchronous compiler exit. The loader owns and cleans the stage
and lock. The object name includes the host architecture and SWI version;
source and recipe timestamps invalidate it. Wheels carry the portable source
and recipe, and first import builds in the installed library. A missing
compiler, PCRE2 headers or writable artifact directory raises with an install
and prebuild remedy. No global SWI files or environment settings change.

Verification plan: adapt the upstream suite only for the private namespace
and corrected end-offset contract; test empty/optional/typed captures, Unicode
and CRLF progress, compiled operations, native error propagation, concurrent
builds, failed-build cleanup, cache reuse, and installed-wheel import. Every
public regex head appears in the MeTTa example and its Python twin.

Tried: the first private provider build emits `swipl-ld: warning: Unknown
option: --home=/usr/lib/swi-prolog`. library(process)'s prolog(Tool) adapter
adds the interpreter option to swipl-ld. Use the compiler next to the active
SWI executable, following that adapter's path resolution without its unsupported
option. A Janus probe confirms the active executable resolves to the same SWI
installation. The corrected build emits no warning.

Tried: the first vendored upstream run reports `Syntax error: Operator
expected` in the edited end-offset test and four `wrong error` failures.
The test edit had retained the re_ prefix before a comment. The error payload
exposed private range tags. Restore the test macro and strip private projection
tags only when constructing the existing missing-key error, preserving the
upstream error assertions rather than weakening them.

Tried: all 160 adapted upstream tests pass, including save/load and the original
missing-key error payloads. A literal-quoting boundary probe then reproduces
`representation_error(nul_byte)` for a pattern containing U+0000. PCRE2's
compile call already receives the full explicit byte length; the binding's
strlen precheck alone rejects the value. Remove that precheck, compare patterns
with their explicit lengths, and print diagnostic patterns by character count.
The normal blob display and save/load already carry lengths. Quote properties
will include U+0000 and embedded quoting terminators.

Tried: `sh engine/test.sh suites/libraries/lib_regex.plt` -> 188 passing tests.
The upstream wb_2 case retains its existing blocked(javascript_compat) marker.
The first run's callback-release case named its closure in the provider module;
qualifying the test closure repairs the fixture. The suite covers optional
capture holes, typed minus terms, end offsets, CRLF/Unicode progression,
compiled operations, NUL patterns, callback errors and 200,001 counted matches.

Tried: `python -m pytest extensions/python/tests/ch08_data/test_regex_lib.py -q`
-> six passes, including generated checks against Python re over common syntax
and literal-quoting round trips. `test_regex_native_build.py` -> four passes:
reuse and failed rebuild, six processes with four threads each, cancellation
while the compiler waits on an include FIFO, and a wheel built from its source
archive then installed and executed. Cancellation joins the compiler, discards
the stage and preserves the previous object. No .native content enters either
distribution. The face-generator selftest passes 13 cases; its new case plants
invalid private sources that discovery must leave outside the public layout.

Tried: `swipl -q --on-error=status -s lib/lib_regex/support/benchmark.pl -g
regex_benchmark -t halt` compares precompiled two-capture Unicode scans. Minimum
CPU seconds of three runs, with equal checksums at every size:

| Characters | Installed binding | Private binding | Checksum |
|---:|---:|---:|---:|
| 1,024 | 0.000697 | 0.000387 | 787456 |
| 4,096 | 0.006410 | 0.001521 | 12587008 |
| 16,384 | 0.085111 | 0.006212 | 201342976 |

Decided: retain the single lazy boundary index. A fourfold size increase from
4,096 to 16,384 costs 13.3 times the CPU in the installed prefix scan and
4.1 times in the indexed conversion. The indexed case is 13.7 times faster at
16,384 characters. This is a range-conversion fixture, not a bound on arbitrary
PCRE pattern matching. Counting skips capture materialization entirely.

Tried: the expanded MeTTa example -> 25 passing assertions. It calls all 18
heads, including the six retained native spellings. Logs are
ai-tmp/ai-libraries-regex-{prolog,python-first,build-tests-first,after}.log and
ai-tmp/ai-libraries-regex-ranges-benchmark.log.

Tried: targeted Ruff -> two new style findings, repaired in the regex tests,
and seven existing findings in setup.py. Blame attributes the header and
optional-compiler branch to MesTTo; clarify the header, retain the necessary
lazy import with its reason, and bind the refusal message before raising it.
The unchanged build_py_with_runtime class name and missing run-method docstring
belong to Leul Negash. Their N801 and D102 findings remain outside this library
change; the established Ruff lane does not select setup.py.

Tried: native `index-atom(0-1,0,V)` answers `-`, while the same range capture
with the Python seat loaded answers `0`. Python's Janus tuple provider claims
the native minus functor. Decided: project compound capture values to explicit
MeTTa expressions at the library boundary. Preserve the functor, including
minus; proper lists remain expressions and improper lists use `(cons Head
Tail)`, following the shared wire grammar recorded in the Node runtime journal
on 2026-09-05. Variables keep their identity. Cyclic terms raise a named
refusal because a finite expression cannot represent the cycle. Replacement
still consumes native values inside the provider, before this projection.

Tried: the new example initially evaluates minus in its expected value, giving
`(span -1)` where the capture correctly holds `(span (- 0 1))`. Quote the
expected expression. Native tests now pass 191 cases with the same upstream
blocked case; the combined regex, native-build and handle-wire Python tests
pass all 15 cases.

Tried: the final example passes 26 assertions. Minimum-of-three fresh runs
measure 103,895 MeTTa inferences and 103,248 Python inferences, ratio 0.9938.
Only this twin's budget changes, from 28,947 to 103,248, retaining every
committed historical entry. Its uncommitted intermediate measurements remain
in this journal rather than claiming that the final evidence commit supplied
an earlier implementation. Regeneration leaves origins, cumulative syntax,
the llms roster and vocabularies unchanged; the library reference gains the
18 declared regex heads and their types and documentation.

Tried: integration checks find `Unknown procedure:
lib_regex_native_build:directory_file_path/3` with autoload disabled. Declare
its filesex import explicitly; the nine missing native names are consequences
of that loader failure. Evidence reports the still-untracked native/build test
files, an individual unittest method outside its collected file citation, and
a missing measurement date. Stage the owned files, cite the executed selftest
file, and date the measurement. VitePress reports `1 dead link(s) found` for
the provider record linked from the mirrored engine guide. Name its repository
path as code, which remains valid in both guide locations.

Tried: the repaired autoload check passes all 22 library files, and VitePress
builds successfully. The remaining evidence finding names `regex_upstream`,
whose vendored path is outside the named-test index. Cite the executed native
gate command that includes that suite; its 160 upstream cases remain executed
and unchanged. The evidence and provenance mutation selftests pass.

Tried: the full twin check proves 26 of 26 claims and equal stored content,
then rejects 29 bare expected strings under the corpus's explicit Grounded
data convention. Wrap those expected values with G, preserving the assertions.
The explicit filesex import changes the twin's inference count by ten; measure
and price the final import graph before pinning its evidence commit.

Verified: the final regex native gate passes 191 tests, with the upstream
javascript_compat case still blocked. The combined Python regression command
passes 15 tests, including installed-wheel execution, failed and cancelled
builds, and concurrent first imports. The full twin check proves 26 claims,
equal stored content and zero findings. Minimum-of-three costs are 103,904
MeTTa and 103,258 Python inferences, ratio 0.9938. Ruff passes the nine changed
Python files selected for this library. jscpd finds zero clones in five changed
Python implementation/example/test files, 897 lines and 8,589 tokens.

Verified: coverage reports 251 engine callables, 677 library heads, four
allowed entries and no findings. Cumulative syntax remains 324 examples and
284 constructs; origins remain 143 derived and 202 original examples. llms
passes five sheets and 68 mutation cases. Reference, docs, face generation,
library documentation, artifact declarations and their selected mutation
witnesses pass. Engine no-autoload and the 22-file library autoload check
pass. Evidence reports zero unbacked tags in 7,448 claims; the evidence and
provenance mutation selftests pass. Logs use the ai-libraries-regex prefix in
ai-tmp; the final combined integration corrections are recorded separately
from their initial failures.

## 2026-09-11: JSON design before implementation

Tried: the existing JSON example passes 13 assertions. The existing lib_text
and json_codec native suites pass. A direct lib_json import raises
`Unknown procedure: lib_json:metta_text/2`; its MeTTa face had supplied the
dependency through lib_string. Import metta_text/2 explicitly.

Tried: native constructor and encoder probes reproduce four defects. A later
malformed pair throws `type_error(key_value_pair,[invalid])` after registering
an object. A pre-existing next `&json-N` receives the new object's fields.
The key `from` invokes import handling and raises
`existence_error(source_sink,'.../engine/../lib/')`; `internal` raises
`type_error(atom,[])`. A self-reference exhausts the explicitly bounded
10,000-inference reproduction. A non-pair stored atom disappears on encoding.
The bound contains that known cyclic probe only. Baseline logs are
ai-tmp/ai-libraries-json-{before,native-before}.log.

Decided: preserve classic JSON objects as spaces, duplicate fields, arrays,
scalars and the existing number codec. Add file reading and atomic writing,
native width-based formatting, streaming JSON Lines and structural path
lookup. Thirteen heads have fourteen arities. Every declared mode receives a
generated type, documentation row and example call. Object path components
use the same key values as get-value; array components are nonnegative
integer indexes. Missing paths have no answers; malformed paths raise.

Decided: validate all constructor pairs before allocation. Allocate global
data carriers under the existing native-storage mutex, skip occupied names,
register even empty objects, and store fields with published add_sexp/2.
Track allocations until an answer is returned and release them on failure.
Attempt every release if one fails and report the original outcome together
with cleanup failures. Successful objects retain the established data
lifetime; advancing or cutting a JSON Lines reader does not revoke its values.

Decided: encode through one memoized snapshot per object. Insert each native
JSON term into library(assoc) before traversing its fields and reject cyclic
terms after construction. Repeated aliases stay valid. The graph conversion
cost is O((V + E) log V + S) for atomic names, where V is distinct objects, E
object references and S their stored term size; emitted JSON can be larger
because JSON repeats aliases. Native acyclic_term supplies the graph cycle
check. Reject non-pair stored atoms explicitly instead of losing them.
The CPython check_circular behavior establishes the cycle/alias distinction:
https://github.com/python/cpython/blob/v3.14.0/Lib/json/encoder.py.

Rejected: switch the allocator to new-space/1, because it assigns the current
equation world while existing JSON carriers are global data. Revisit if JSON
receives an explicit world-owned lifetime. Rejected: repeat ancestor-list
membership checks and reread aliased spaces, because both redo graph work.

Decided: add json_codec_write/4 for a nonnegative layout width. Width zero
delegates to the existing compact C/Prolog codec; positive widths use the
same native options and finite-number validation with SWI's writer. Keep
json_codec_write/3's fast path and option contract. Native step/tab require
positive integers, so do not invent indent-zero behavior or fork formatting.

Tried: a UTF-8 text stream with representation_errors(error) warns
`Illegal UTF-8 continuation` and substitutes U+FFFD. string_bytes/3 and
library(utf8) also accept some malformed or obsolete encodings. Decided:
read bytes, use native string_bytes/3, verify canonical byte round-trip and
Unicode scalar bounds. This preserves valid Unicode and rejects malformed,
overlong and surrogate encodings under RFC 3629 sections 3 and 4:
https://www.rfc-editor.org/rfc/rfc3629. JSON Lines reads one physical LF/CRLF
line at a time; empty input has no records, blank lines and BOMs raise with
their line number, and a final LF is optional. Writers append LF per record.
The format contract is https://jsonlines.org/.

Decided: reuse the file library's publication algorithm locally: acquire a
sibling staging directory, write its contents file, close before rename,
then remove staging on every exit. Both JSON writers share this helper.
The existing file-library journal supplies the rejected direct-truncation
approach and close-failure evidence. File readers and line generators use
setup_call_cleanup for exhaustion, cuts and exceptions.

Open: verify constructor rollback and concurrent name ownership, cycles and
aliases, special keys, non-pair refusal, every new interface, formatting
against SWI, Unicode against Python, line/error/cut behavior, failed writes
and close/publication faults. Preserve the thirteen original assertions and
all codec differential cases; regenerate records and measure the JSON twin.

## 2026-09-11: JSON verification findings

Tried: the first native gate -> ten failed surface cases before an invalid
unwind fixture terminated that suite; all 26 codec tests with four subcases
and 58 existing text/file/JSON tests with eight subcases pass. The allocation
log's nb_linkarg shared bindings that backtracking undid; cleanup then received
a variable and raised `permission_error(clear,metta_base_space,'&self')`.
Decided: nb_setarg copies each new cell and shares the old tail. SWI 9.3.18
already implements this constant-cost push, so no custom linked allocator is
needed. The installed version is 10.1.13. The upstream change is
https://github.com/SWI-Prolog/swipl-devel/commit/7de5ef58661b9d776627ad0f1167197a89430d0c.
A two-push/backtracking probe retains owned([b,a]).

Tried: the new exact-output assertions assumed whitespace-free JSON. Native
width(0) retains spaces around arrays and nested objects. The codec's native
differential passes; compare document structure and preserve its spelling.
The engine refuses a partial stored atom before the JSON writer can see it;
constructor tests cover partial pairs at their actual boundary.

Tried: throw(unwind(json_surface_stop)) -> `Unknown "unwind" exception:
json_surface_stop`, even with an explicit catch pattern. SWI bypasses ordinary
catch for unwind, so the custom rethrow clause was unreachable. Remove it and
verify reader cancellation with a joined thread and an explicit stop signal.
The initial log remains ai-tmp/ai-libraries-json-native-first.log.

Verified: the repaired native gate passes 41 surface tests with twelve
subcases, 26 codec tests with four subcases, and 58 existing text/file/JSON
tests with eight subcases. The expanded example passes 28 assertions.
The first Python gate's six failures were fixture assumptions: the public
function API already returns Python strings, and SWI renders instantiation
errors as `Arguments are not sufficiently instantiated`. Correcting those
assumptions yields 25 passing tests, including recursive JSON and JSON Lines
properties against Python's json codec and the existing dictionary story.
Two RUF043 findings required raw regular-expression strings. Ruff then passes;
jscpd reports zero clones across two Python files, 425 lines and 3,383 tokens.

Tried: message_to_string on a JSON Lines error prints `Unknown error term:
json_line(...)`. Decided: use prolog:error_message//1, matching lib_file and
lib_csv, to render the record number and native cause while retaining the
structured exception. Add a message assertion and preserve the file reader's
Python refusal checks. All remaining generated records, integration checks
and the final twin cost must run on this completed source.

Verified: the completed native source passes 42 surface tests with twelve
subcases, 26 codec tests with four subcases, and 58 existing tests with eight
subcases. The Python gate passes 25 tests. Logs are
ai-tmp/ai-libraries-json-{native-final,python-final}.log.

Tried: the per-library integration battery passes every requested record,
reference, documentation and generated-face check, but no-autoload fails in
14-reflect_lib.metta. Its string-length call stays unreduced and the numeric
comparison raises `> expects two numbers`. The old JSON face imported
lib_string, which that consumer uses. Decided: preserve that existing import
outside the generated region, alongside the native module's explicit helper
import. Regeneration owns native declarations, not authored dependencies.
The first integration log is ai-tmp/ai-libraries-json-integration.log.

Verified: restoring the authored import passes all 319 no-autoload examples.
The resulting four-line reference offset makes libdoc report
`metta-libraries.md no longer matches the libraries' @doc atoms`; its owning
generator refreshes the page and the final libdoc and docs lanes pass.
Corpus coverage now has 685 carried library heads, 251 callable engine heads,
four allowed omissions and zero findings. Cumulative syntax has 324 examples
and 284 constructs; origins retains 143 derived and 202 original examples.
The five llms sheets and their 68 planted checks pass. Prolog-face, its
thirteen selftests, reference, its four selftests and lib-autoload pass.

Measured: `python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/05-json_lib.metta` -> 73,856
MeTTa inferences, 65,839 Python inferences, ratio 0.8915. Both programs prove
all 28 claims and have equal stored content with zero findings. Only this
twin's budget changes, from 24,799 to 65,839, for its expanded public surface,
allocation ownership, graph conversion and generated declarations.

Verified: Ruff passes both changed Python files. The evidence lane reports
zero unbacked tags in 7,445 claims, 13,361 known tests and 1,109 runner files;
provenance-pin-selftest passes. Fifteen WORKTREE tags await the standard
header-only pin. Final logs are ai-tmp/ai-libraries-json-{twin-final,
twin-measure-final,ruff-final,records-final}.log. The native/Python tests,
example, records, docs and pricing obligations for JSON are closed.

## 2026-09-11: crypto design before implementation

Goal: extend the four existing hashing/randomness heads with byte and file
digests, HMAC, secure bytes and integer intervals, password records and Boolean
verification. Keep the five reduced-platform SHA algorithms. Twelve heads and
thirteen arities derive their faces from the native declarations.

Tried: the original example passes three assertions and the Python suite passes
three tests. `sh engine/test.sh suites/seams/platform_capabilities.plt` passes
41 and fails four clean-boot assertions: the regex loader unconditionally
imports absent `library(process)`. Logs are
ai-tmp/ai-libraries-{json-crypto-baseline,crypto-python-before,crypto-platform-before}.log.

Tried: SWI 10.1.13's private PBKDF2 function accepts zero iterations and returns
a 64-byte value. The probe printed only its length. OpenSSL rejects this
parameter, but the SWI binding ignores that return. The same source ignores
digest/HMAC finalization status and uses Prolog unification to verify password
digests. Its random-byte count narrows size_t to int. These are present in
[the installed ssl revision](https://github.com/SWI-Prolog/packages-ssl/blob/07e4afd5087a5decdff1de63ab25dc4f28af24dc/crypto4pl.c)
and unchanged at upstream 7673a282d2868d69172ecfbcc0824eb6b47d373a.

Rejected: public SWI crypto wrappers for the new operations, because boundary
checks cannot repair ignored native returns or make unification a constant-time
comparison. No compatible maintained repair was confirmed. Revisit when that
binding checks each native failure and exposes a suitable comparison. A Rust
password stack adds a toolchain and changes the established record parameters;
it does not improve this integration over checked calls to the installed provider.

Decided: a private OpenSSL 3 adapter checks allocation, fetch, init, update,
finalization, entropy and derivation results. It raises a named native error
even when the provider's error queue is empty. Each call owns its contexts and
temporary buffers and releases them on failure, output mismatch and success.
Temporary secret copies are cleansed before release. No mutable native state
crosses calls. The default OpenSSL context owns its thread-safe random generator.
[CPython's PBKDF2 and comparison bindings](https://github.com/python/cpython/blob/v3.14.0/Modules/_hashopenssl.c)
supply the checked-status and CRYPTO_memcmp precedents. Algorithms remain
OpenSSL's fixed-output digest names, including SWI's underscore SHA-3 aliases.

Decided: sources are UTF-8 text, checked byte lists or binary input streams.
Text preserves the existing atom/string/code-list conversion, including NUL.
File hashing opens once, streams through a 64 KiB buffer, checks read errors
and signals, and closes on every exit. Time is O(n), the lower bound for
reading content; auxiliary file space is O(1), instead of a whole-file O(n)
list. The reduced provider folds SWI sha contexts through the same bounded
reads, including the empty file. Reduced HMAC supports SWI sha's actual SHA-1
and SHA-256 algorithms and names crypto for the others.

Decided: secure byte counts include zero. RAND_priv_bytes_ex uses size_t and
must return one. Integer intervals are [Lower, Upper), reject empty/reversed
bounds, and use BN_priv_rand_range without modulo bias. Native hexadecimal
interchange avoids a GMP build dependency and a repeated large-integer byte
fold. A singleton needs no entropy. The native sampler's own failure remains
an exception, as in
[OpenSSL's implementation](https://github.com/openssl/openssl/blob/openssl-3.5.0/crypto/bn/bn_rand.c).

Decided: password records preserve SWI's PBKDF2-SHA512 format, a 64-byte digest
and unpadded Base64. New records have 16 random salt bytes. The explicit cost
is log2(iterations); validate against the C int ABI before shifting. Default
cost 18 gives 262144 iterations, above the current
[OWASP PBKDF2-SHA512 recommendation](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
of 220000. This policy preserves the native record format; it does not claim
PBKDF2 is preferable to Argon2id for a new authentication system. Verification
accepts valid legacy salt lengths, parses the complete record without a Prolog
term reader, checks positive representable iterations and canonical Base64,
then compares equal-length digests through CRYPTO_memcmp. A well-formed wrong
password returns False. Malformed records and native failures raise. Record
parsing and derivation time depend on public record parameters; only the digest
comparison carries the constant-time claim.

Decided: both native libraries use the existing atomic build protocol through
one private helper. Per-object mutexes, process file locks, freshness checks,
staging rename and compiler cancellation cleanup remain. A missing process
library is harmless for a current object and refuses a cold build with an
explicit prebuild remedy. Each owner supplies its own link flags and dependency
instructions. Wheels and sdists keep source and omit host objects.

Verification plan: native and Python hash/HMAC vectors, generated Unicode and
byte inputs, streamed empty/large/error files, SWI/Python password-format
interoperation, malformed-record properties, wrong-password False, arbitrary
integer bounds, zero/singleton cases, and injected provider failures. Compile
test copies with native calls replaced by failure returns, including an empty
error queue; no runtime test switch enters the library. Extend the native build
tests to both consumers and prove the reduced boot regression is closed. The
example calls every head and both password arities; its twin proves the same
claims and stored content. Price only this library's measured twin.

### Crypto verification findings

Tried: the first native suite passes 33 cases and exposes five failures.
`must_be(list(byte), ...)` is invalid because SWI has no byte type. The native
type `between(0,255)` requires integers when its bounds are integers; a probe
accepts 0 and 255 and rejects 1.5 and 256. Decided: use that native parametric
type, retaining the list/cycle check. The SHAKE refusal must check the XOF flag
before asking for a fixed digest size; OpenSSL returns no fixed size for SHAKE.

Tried: full and reduced streamed hashes agree for empty input, byte 255 and
140003 bytes of 255. The test's SWI crypto_file_hash comparison disagrees on
non-ASCII bytes because its default encoding is UTF-8. Decided: request
encoding(octet) from that independent oracle. Both library paths already read
the file's actual bytes. Log: ai-tmp/ai-libraries-crypto-native-first.log.

Verified: the corrected native suite passes all 25 tests and 13 subcases.
The example then catches an inter-seat representation error:
`'True' does not match true`. Native Boolean results use Prolog true/false;
uppercase atoms remain Symbols. Decided: return PL_unify_bool from the adapter
and assert native booleans in its direct tests. The example remains the MeTTa
contract. Logs: ai-tmp/ai-libraries-crypto-{native-second,example-first}.log.

Verified: the expanded example passes all 18 claims. The first combined Python
run passes 52 tests, including 21 injected provider failures, the comparison
control, both libraries' build/cancellation/concurrency/reduced-platform cases,
and an installed wheel built from the source archive. One file-refusal test
expects EngineError, while the existing Python boundary correctly classifies
the native existence error as SourceNotFound. Decided: assert that existing
structured error. Log: ai-tmp/ai-libraries-crypto-python-first.log.

Tried: the repaired loader passes warm and cold imports with process.pl and
its cached autoload entries removed. The next platform run passes 42 tests
and fails three stderr assertions, all from duplicate type declarations.
Two imports alone emit no warnings. Saving &self and loading that image into
the same &self emits one warning per existing arrow: a different source is
adding a declaration already owned by the original library. The warnings
are the documented declaration behavior, not an import regression. Logs:
ai-tmp/ai-crypto-{repeat-import,fast-import}.log and
ai-tmp/ai-libraries-crypto-platform-final.log.

Rejected: changing duplicate diagnostics or import semantics to satisfy the
capability fixture. The fixture saved unrelated prior probes and restored
them over their originals. Merely changing its target also fails with
metta_fast_translator_rule_conflict('and-then',[],'$metta_exec:&self'), because
that global rule belongs to the original source. Revisit only for a requested
change to image relocation or declaration ownership.

Decided: isolate the capability probe's source and destination spaces. Save
one type and two equal data occurrences, restore into an empty space, and
verify that exact bag. Release both spaces through setup_call_cleanup. The
throwaway isolated-space probe passes without diagnostics. The existing
clean-boot assertions remain strict. No engine or generated-face change is
needed. Logs: ai-tmp/ai-crypto-fast-{fresh,isolated}.log.

Tried: Valgrind's adapter-load-only control exits 99 with 11 contexts and
99984 definitely lost bytes, all allocated inside SWI startup. The installed
release deliberately skips reclamation in PL_halt. Decided: use an embedded
probe calling PL_cleanup(0), which reclaims memory, before comparing adapter
operations. This follows
[SWI's cleanup implementation](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-init.c#L1909-L2099).
The initial run establishes no adapter leak result. Log:
ai-tmp/ai-libraries-crypto-valgrind-baseline.log.

Tried: the isolated fixture emits no warnings, but its new bag check initially
fails: grouped execution returns named-answer carriers for a variable match.
Decided: use the existing metta_answer_term/2 seam before comparing atoms,
as filereader_source_reload already does. The exact failure is
`unexpected fast-load failed without refusing`; the saved count is three and
the probe shows all three correct atoms inside their carriers. Logs:
ai-tmp/ai-libraries-crypto-platform-repaired.log and
ai-tmp/ai-crypto-fast-bag.log.

Verified: the combined crypto, native failure-injection, shared native-build
and existing regex Python suites pass all 53 tests in 14.51 seconds. This
includes 270 generated input cases and the source-archive-to-installed-wheel
check. jscpd finds zero clones in the four Python files and native adapter:
1301 lines and 10957 tokens. Logs:
ai-tmp/ai-libraries-crypto-{python-final,clones}.log.

Verified: native crypto passes 27 tests and 13 subcases, including cancellation
and output-mismatch cleanup. All 45 platform tests pass, including four real
reduced-platform boots. The evidence selftest passes all planted cases and
now includes native support C. Logs:
ai-tmp/ai-libraries-crypto-{native-platform-verified,evidence-selftest}.log.

Measured: the embedded PL_cleanup control and 1000 repetitions of thirteen
native success, mismatch and refusal operations both exit 99 with exactly
five identical SWI contexts: 32872 definitely lost and 72 indirectly lost
bytes. There are no new reported errors or lost bytes in the exercised run.
Reachable memory rises by 56 bytes in one block. These are differential
results, not a claim that this SWI process is leak-free. The C runner is
ai-tmp/ai-crypto-memcheck.c; compile with
`swipl-ld -Wall -Wextra -Werror -o ai-tmp/ai-crypto-memcheck ai-tmp/ai-crypto-memcheck.c`.
The exact goals are in the command headers of
ai-tmp/ai-libraries-crypto-valgrind-{cleanup-control,exercise}.log. Both use
`valgrind --leak-check=full --show-leak-kinds=definite,indirect --errors-for-leak-kinds=definite,indirect --error-exitcode=99`.

Decided: lib/.gitignore owns the common .native exclusion now that two
libraries use the shared builder. Remove the redundant regex-only ignore
file. Packaging already excludes those host objects and the installed-wheel
test verifies this for both consumers.

Verified: the example passes eighteen claims. The record and documentation
lanes all pass: coverage is 693 carried heads, 251 engine callables and four
allowed constructors/types, with zero findings; cumulative syntax remains
324 examples and 284 constructs. Origins remains 143 derived and 202 original
examples against PeTTa-base 43705f5d9ff8958ffe7f0aa6777fb8477f2401f2.
The no-autoload corpus, library autoload, thirteen face-generator selftests,
sixty-eight llms selftests, cards, reference and VitePress build pass. Ruff
passes all six changed Python files. Logs:
ai-tmp/ai-libraries-crypto-{example-final,records-final,ruff}.log.

Measured: minimum of three fresh processes gives crypto 77933 MeTTa and
78285 Python inferences, ratio 1.0045. Regex gives 108279 and 107645,
ratio .9941. To attribute the latter, a detached control at
6dab7f8c1cc17e3d37c6ab512c2770ebcb1ec971, with the same nine native artifacts,
reproduces regex's prior 103904/103258. Applying only the new regex recipe
and lib/_support/native_build.pl to that control gives exactly
108279/107645. Shared source loading adds 4375/4387; neither regex's program
nor matching implementation changed. Decided: record that measured loader
movement on the regex twin as part of this shared repair, alongside crypto's
expanded program. No unrelated twin is repriced. Commands:
`python extensions/python/tools/twin_coverage.py --measure --rounds 3` with
the respective 04-regex_lib.metta and 06-crypto_lib.metta paths. Logs:
ai-tmp/ai-libraries-crypto-{twin-measure-corrected,regex-control,regex-loader-control}.log.

Verified: the repriced crypto and regex twins prove all 44 claims, preserve
equal stored content and report zero findings. The first evidence run reports
seven missing-test citations: six refer to new tests not yet staged in its
tracked-source census; setup.py still names the old regex-only wheel test.
Decided: stage the completed test sources and update that consumer header to
test_native_sources_build_after_wheel_install, the passing shared test.
The provenance selftest already passes. Logs:
ai-tmp/ai-libraries-crypto-{twins-final,evidence-final}.log.

Verified: after staging, evidence reports zero unbacked tags in 7456 claims,
13435 known test names and 1115 runner files. All planted evidence and
provenance checks pass; 33 placeholders await the normal provenance commit.
Log: ai-tmp/ai-libraries-crypto-evidence-staged.log.

Tried: including setup.py in the manual Ruff command finds I001 on the
optional import this thread annotated earlier, plus the same N801/D102
findings recorded in the regex section. Blame still attributes the class
and method declarations to Leul Negash; the established Ruff lane excludes
setup.py. Decided: format the owned import as Ruff requests. Keep the earlier
scope ruling for the other two findings. Log:
ai-tmp/ai-libraries-crypto-ruff-final.log.

Verified: the final six owned Python files pass Ruff, and setup.py passes
its owned import-order check. The final clone scan after pricing finds zero
clones in 1306 lines and 10967 tokens. Logs:
ai-tmp/ai-libraries-crypto-ruff-owned-final.log,
ai-tmp/ai-libraries-crypto-ruff-setup-import.log and
ai-tmp/ai-crypto-clones-final/jscpd-report.json. The staged diff passes
`git diff --cached --check`.

## 2026-09-11: CSV design before implementation

Verified: crypto A is 28c6146d805b5adba3047ffc72b2508c11816636; B is
e5efe36f7e55d81b1b8ea61c783fabbd58a6cd84. B changes thirty literal pins in
eighteen files. Pinned examples, twins, evidence, libdoc and the direct
prologface check pass. Evidence has zero placeholders. CSV's existing
native suite passes all 28 tests. Logs:
ai-tmp/ai-libraries-crypto-pinned-{example,twins,evidence}.log and
ai-tmp/ai-libraries-csv-baseline-native.log.

Tried: SWI V10.1.13 csv_read_row/3 on quoted CRLF produces LF; its
strip(true) branch splits a whitespace-prefixed quoted field at its comma.
An unquoted single quote also makes the physical-line reader fail. The
native grammar has no public single-record entry, and its line reader
counts quotes rather than threading the grammar's remainder. Source:
[pinned csv.pl](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/csv.pl).
The public lazy input API is stream_to_lazy_codes/2. Log:
ai-tmp/ai-csv-native-framing-probe.log.

Tried: an occupied &metta-space-1 with a sentinel, followed by resetting the
allocator in an isolated process, makes csv-snapshot! return that same
space containing the sentinel and its new row. Command:
`swipl -q -s ai-tmp/ai-csv-snapshot-probe.pl -- extensions`.
Log: ai-tmp/ai-csv-snapshot-probe.log.

Tried: string_bytes/3 accepts nonminimal UTF-8, surrogate encodings and
out-of-range values. A byte round trip rejects the first two; the last
also needs a scalar-range check, as JSON already does. read_term_from_atom/3
accepts a complete first term followed by another term, so descriptor
validation must compare the complete canonical encoding. Log:
ai-tmp/ai-csv-text-boundary-probe.log.

Rejected: unversioned private csv:row//2 calls, because private layout is not
a supported provider interface. Revisit after a public lossless row parser
ships. Rejected: the native physical-line reader, because it changes field
characters. Rejected: decoding entire lazy input chunks before parsing,
because invalid bytes in a prefetched later row would refuse a valid bounded
query. Rejected: libcsv's C parser, because its byte-valued delimiter excludes
Unicode delimiters and no maintained SWI binding was verified. Source:
[libcsv](https://github.com/rgamble/libcsv/tree/b1d5212831842ee5869d99bc208a21837e4037d5).

Decided: extract and adapt SWI's deterministic field and quoting grammar
under lib_csv/support, retaining its license and immutable source reference.
Thread one lazy binary code list per file traversal. Parse UTF-8 byte
sequences for delimiters and quotes, then validate and decode each completed
field. Double the configured quote to escape it. This preserves embedded
CR, LF, CRLF, NUL and Unicode without an incremental codec or a size limit.
The adaptation shares a parser across text, streamed rows, live spaces and
snapshots. No installed module is changed. Errors distinguish clean EOF,
malformed quoting, invalid UTF-8 and row-width mismatch with logical position.

Decided: seven heads with default and explicit-option arities: csv-parse,
csv-encode, csv-read!, csv-write!, csv-append!, csv-space and csv-snapshot!.
csv-parse returns the row list; csv-read! yields one field list per answer.
Keep live (row Field...) and snapshot (row Number Field...) bags, with the
physical file's one-based logical number after skipped header records.
Options are a proper list of unique (Name Value) expressions: separator,
quote, newline, width and skip. Defaults are comma, double quote, CRLF,
inferred width and zero skipped records. Separator is one Unicode scalar;
quote is one scalar or an empty String to disable quoting. Neither may be
CR/LF, and a present quote differs from separator. Newline is CRLF, LF or CR
for writing; readers recognize all three. Width is infer, any or a nonnegative
integer. Skip is a nonnegative count applied only to reads; skipped records
still establish and validate width. Writers preserve every supplied row.
Unknown, repeated, malformed or unbound options raise. There is no numeric,
case, whitespace or header-name coercion.

Decided: distinguish a blank record with zero fields from a quoted empty
field. Encode a singleton empty field with quotes. This closes the native
writer's ambiguous zero/singleton representation and follows
[CPython's tests](https://github.com/python/cpython/blob/823f0323ee6ec1402088b73bce1a38473cac36dc/Lib/test/test_csv.py).
It changes the old implicit blank-line result from one empty field to zero
fields. Quoting-disabled output refuses values that need escaping, including
a singleton empty field. All write-side fields must be Strings.

Decided: retain &csv:<absolute-path> for the default live descriptor. Other
configurations use a separate versioned prefix and the complete canonical
serialization of the ground path and options. Validate shape and canonical
round trip on decoding; never evaluate a descriptor. Streams, inferred width
variables and query positions remain local. No registry or core change is
needed. Each query owns its stream through setup_call_cleanup/3.

Decided: snapshots allocate a vacant &csv-snapshot-N under the engine's
native-storage mutex. Record ownership before creation hooks, fill directly
from the row iterator, and release on failed output unification, parse/write
failure or cancellation. A returned snapshot transfers ownership to the
engine. Release failure retains the primary outcome in a named error.

Decided: write and append stage a complete file beside the destination,
close it, then rename it. Append validates the existing file, copies its
bytes unchanged through copy_stream_data/2, and inserts a record terminator
only when a nonempty addition follows a valid unterminated record. Preserve
the inferred/fixed width across old and new rows. Use one canonical-path
mutex and an advisory lock on <path>.metta-csv.lock for both write operations.
The lock file remains: unlinking it could separate waiting writers onto
different lock inodes. Readers need no lock and observe an atomic publication.
The protocol coordinates callers using the same canonical path; external
writers and crash durability are outside that guarantee. The native open/4
[lock contract](https://www.swi-prolog.org/pldoc/man?predicate=open/4) supplies
the process lock. A failed validation, conversion, close or publication
preserves the old destination and removes staging. Empty append leaves
existing bytes unchanged and creates an empty file when absent.

Complexity: consumed input must be examined, giving an O(bytes) lower bound.
Streaming auxiliary space targets O(current record + read buffer); retained
answers and snapshot storage are output costs. Append is O(existing bytes +
new bytes), including validation and native copying; batches avoid repeated
whole-file transactions. Text parse/encode necessarily materialize their
returned value. Verify scaling through discarded answers, not findall/3.

Verification plan: preserve the 28 original tests; add dialect, zero-width,
UTF-8, quoting and buffer-boundary cases; compare generated documents with
CPython; exercise MeTTa and Python answer bags, descriptor round trips,
independent queries, cut and cancellation; inject allocation, storage, close,
publication and cleanup failures; test concurrent thread/process appends;
measure discarded-row memory and inference scaling; cover every head and
arity in an example and twin; regenerate records/docs and run the native,
Python, face, autoload, evidence and provenance checks before A/B.

Tried: the new CSV suite first reports 23 failed and 53 passed instances.
The text door lacks lib_string's explicit metta_text/2 import; seek/4 names
the end position eof, not end. The cyclic-list fixture instead constructed
a cyclic field, correctly getting type_error(string, ...) rather than its
expected list error. Fix those local mistakes. The new fixture must derive
its directory from TMPDIR because this host's tmp_file/2 uses /tmp despite
that environment setting. Log: ai-tmp/ai-libraries-csv-surface-first.log.

Tried: simultaneous read/write and cleanup faults preserve only the original
exception. The standalone probe
`setup_call_catcher_cleanup(true,throw(primary),_,throw(secondary))` throws
primary. JSON's new simultaneous write/release probe reproduces the same
loss. SWI's documented cleanup exception priority causes it; adding another
throw inside Cleanup cannot combine the errors. Logs:
ai-tmp/ai-libraries-csv-json-cleanup-reproduction.log and
ai-tmp/ai-csv-cleanup-priority-docs.log.

Decided: share a deterministic resource guard between CSV and JSON. Capture
exit, failure or exception as data before running each owner's cleanup, then
restore the outcome. Refuse an accidentally nondeterministic operation; the
streaming read path continues to use its nondeterministic native guard.
The owner can now report both primary and release errors without SWI
suppressing its combined exception. JSON's affected constructor uses this
same correction and retains its existing aggregate error format.

Decided: publication and acknowledgement are separate facts. Record the
publication flag atomically with rename, and include it in a staging-cleanup
error. Validation, conversion, close and publication failures preserve the
old destination; an error removing staging after publication must say that
the new file is already committed. The injected cleanup test exercises both
sides. This refines the wording of the original file-failure guarantee.

Tried: the CSV language example evaluates the option (quote "") as a call
and raises domain_error(csv_option, ""). Quoting the complete option list
preserves it. A function whose body returns the quoted options also works.
A bind! constant is substituted before argument evaluation and needs quoting
at its use site. Probe: ai-tmp/ai-csv-option-probe.metta, first two assertions
pass; its later unquoted constant reproduces the failure.

Decided: retain the evaluating Expression parameter and use the language's
existing quote barrier for literal option data. Changing the type to Atom
would prevent computed options from being called. Renaming quote would leave
the same collision with user-defined option names. The existing rule is in
engine/prelude.pl:unquote/2 and tests/prolog/suites/evaluation/metatype_mask.plt.
The source reader supports five escapes; a written backslash-u0000 becomes
the literal text u0000. The language example now uses Unicode and CRLF;
native tests and Python properties supply actual NUL characters directly.

Tried: forty CSV surface tests now exercise simultaneous snapshot allocation,
snapshot cancellation and an injected input-close error. Seventy-nine test
instances pass; the close case receives raw io_error(close, Stream) instead
of csv_io_error(Path, close). The existing error boundary covers open only.
Log: ai-tmp/ai-libraries-csv-close-reproduction.log.

Decided: one input scope owns open, the nondeterministic traversal and close,
with the CSV file-error mapping around that complete scope. The same scope
validates a live descriptor. Cancellation and malformed-record exceptions
retain their original shapes through the existing catch-all rethrow.

Tried: the native gate passes 28 original CSV tests, 40 surface tests with
40 additional instances, and 43 JSON surface tests with 12 additional
instances. Python's first run reports 8 failed and 24 passed. Seven tests
used fn["csv-read!"], whose trailing bang deliberately drains the answers;
the streaming interface is Space.answers(call). The generated snapshot case
assumed native storage order across different arities. Native spaces are bags;
sorting by the stored logical record number reconstructs file order. Preserve
both established contracts and correct the tests. Logs:
ai-tmp/ai-libraries-csv-native-final.log and
ai-tmp/ai-libraries-csv-python-first.log.

Measured: the corrected Python suite passes 32 tests, including 180 text
and 60 file property cases, six process writers, seven malformed UTF-8
encodings and installation from a source-built wheel. Log:
ai-tmp/ai-libraries-csv-python-verified.log. jscpd finds zero clones in three
Python files, 568 lines and 7,057 tokens. Ruff flags PERF401 in the process
fixture; list.extend over its generator preserves partial-start cleanup.

Measured: a discarded-answer scan still retains the input root in the goal
passed to setup_call_cleanup. At 1,000/10,000/100,000 fixed 20-byte records,
live global storage after collection is 481848/4810296/48094072 bytes.
Local storage stays 936 bytes. The materialized-answer control retains
152088/1520088/15200088 bytes. Log: ai-tmp/ai-csv-stream-scaling-first.log.

Tried: a throwaway predicate wrapper puts stream_to_lazy_codes/2 and the
tail-recursive row iterator in an ordinary worker predicate, leaving only the
stream and row outputs in the resource scope's retained goal. Live global
storage is 98808 bytes at all three sizes; checksums and record counts match
the original and the materialized control. At 100,000 rows the scan executes
19015312 inferences and 0.482150 CPU seconds in the probe. Log:
ai-tmp/ai-csv-stream-scaling-discard-probe.log.

Decided: use that worker boundary for both streamed rows and append's existing
file validation. The resource scope must never capture the lazy input root.
SWI's pure-input contract reclaims committed list prefixes only when they are
unreachable. Source: https://www.swi-prolog.org/pldoc/man?section=pureinput.
Keep a reproducible benchmark with a materialized-output control; measure
live global and local storage separately from retained answers.

Measured: the implemented benchmark reports the following peaks after
collection. Counts and checksums agree in all modes. Command:
`swipl --on-error=status -q -s tests/prolog/lib_csv_stream_bench.pl`.
Log: ai-tmp/ai-libraries-csv-stream-bench-verified.log.

| Records | Stream global bytes | Materialized global bytes | Append global bytes | Stream inferences | Append inferences |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 98,808 | 152,096 | 101,568 | 190,382 | 193,513 |
| 10,000 | 98,800 | 1,520,080 | 101,568 | 1,901,742 | 1,931,869 |
| 100,000 | 98,800 | 15,200,080 | 101,568 | 19,015,312 | 19,315,439 |

Local storage is 936 bytes for streaming and 4,488 bytes for instrumented
append. The fixed-record scan changes auxiliary storage from O(input bytes)
to O(current record + buffer). Time remains linear because every input byte
must be checked. The first append observation wrapper copied its statistics
term and left the caller's count zero; the benchmark correctly failed. Linking
the one owned statistics term during the wrapper's lifetime fixes observation.
The benchmark now raises a named mismatch if counts or checksums differ.

Measured: the full CSV example and Python twin prove 22 assertions, covering
seven heads at both arities. Minimum-of-three costs are 107047 MeTTa and
103630 Python, ratio .9681. The original live and snapshot examples pass
their 3 and 9 assertions; run_example's three fresh-process samples are
70609/70609/70609 and 81973/81973/81973 inferences. Logs:
ai-tmp/ai-libraries-csv-example-quoted.log and
ai-tmp/ai-libraries-csv-existing-examples-verified.log.

Measured: JSON's unchanged-cut control at e5efe36f7 reports 73856 MeTTa and
65839 Python. Applying only lib_json's resource-guard change and the shared
owned_resources.pl module gives 78103/70088, exactly the current worktree's
result. The +4247/+4249 costs belong to this necessary constructor correction.
No unrelated twin is repinned. Logs: ai-tmp/ai-libraries-csv-json-control-before.log,
ai-tmp/ai-libraries-csv-json-control-after.log and
ai-tmp/ai-libraries-csv-twin-measure.log. The control's eight native objects
were copied from the working tree, and its only source changes are those two
files. The final Python run after the input-root repair passes 32 tests in
12.50 seconds: 12 CSV, 11 JSON and 9 native-build tests, including the installed
wheel proof. Log: ai-tmp/ai-libraries-csv-python-bounded-final.log.

Tried: the complete CSV/JSON twin lane passes 50 assertions and both stored
content comparisons, but reports 33 syntax findings. Six identify the local
`parse = m.fn.csv_parse` alias as the source parser; the rest require expected
MeTTa Strings to use `G`, as existing library twins do. The records battery
passes every requested lane except evidence: the CSV memory measurement lacks
its required date. Logs: ai-tmp/ai-libraries-csv-twins-final.log and
ai-tmp/ai-libraries-csv-records-final.log.

Decided: trace single-assignment local aliases before classifying source
calls. Resolve tuple/list destructuring and alias chains from their assigned
expressions; reject a factory exemption when any parameter, rebinding, loop,
context, import, pattern, deletion or indirect scope declaration makes the
origin uncertain. Keep scope-local proof: unresolved closures, class bodies
and lambda bodies retain the existing conservative source-name rule. A known
alias of a source door must also be reported under its original door name.
This applies the same structural classification as direct factory access and
needs no new dependency. Bandit's `get_call_name` resolves aliases before
classifying a call, while explicitly separating syntactic origin from runtime
identity: https://github.com/PyCQA/bandit/blob/92ae8b82fb422a639f0ed8d99e96cea769594e08/bandit/core/utils.py#L20-L53.

Rejected: rename `parse` in the CSV example, because another library alias
would reproduce the checker defect. Do not exempt bare expected strings or
add a CSV-specific name list. The checker remains a syntax audit, not a
Python runtime identity proof.

Tried: new alias regressions before the correction -> 10 failures, 18 passes.
The first complete checker run after the correction -> 107 passes and two
cost-control failures: tabling's cache-age witness reports 50463 versus 50410;
identity costs 2586 against its existing 2478 budget and allowance 20. No
runtime or budget in those examples changed. Their unchanged-cut controls
remain required before attribution. Logs: ai-tmp/ai-libraries-csv-alias-before.log
and ai-tmp/ai-libraries-csv-alias-after.log.

Tried: a 2000-link alias chain raises `RecursionError: maximum recursion depth
exceeded` in the first resolver. Decided: follow earlier assignment edges
iteratively and memoize resolved origins per scope. Rebinding in function
defaults, decorators and class bases must count in the enclosing scope too.
The structural regressions include those cases and a chain with 2001 calls.
Ruff initially names three B023 captures in loop-local functions; explicit
mapping arguments remove those captures.

Verified: the final alias, source-scan and numeric-idiom selection passes
38 tests; the preceding checker run excluding the three existing runtime
cost cases passes 110 tests. The unchanged checker at e5efe36f7 reproduces
both failures: identity is again 2586 against 2478 with allowance 20, and
tabling's forced-age equality is 50438 versus 50410. Its third case passes.
The control's only source changes are the previously measured JSON guard and
its consumer; all six engine and both MORK objects have equal SHA256 hashes.
Logs: ai-tmp/ai-libraries-csv-alias-complete.log,
ai-tmp/ai-libraries-csv-alias-owned-final.log and
ai-tmp/ai-libraries-csv-alias-control.log. These existing cost failures remain
open; no allowance or unrelated pin changes.

Verified: owned Ruff passes. jscpd with its default 1000-line ceiling silently
omits the large checker and selftest; rerunning with `--max-lines 100000
--max-size 2mb` examines all three selected files, 5528 lines and 37696 tokens.
It reports two existing declaration-reader clones, ten duplicated lines,
0.18 percent. The clone sites predate this change and apply different value
validation; the new alias implementation adds none. Report:
ai-tmp/ai-csv-clones-alias-complete/jscpd-report.json.

Verified: after grounding expected String values, minimum-of-three costs stay
107047/103630 for CSV and 78103/70088 for JSON. The complete twin lane proves
50 of 50 assertions, both stored-content comparisons equal, zero findings.
The final scaling benchmark reproduces every count, checksum, inference and
storage value in the table above; all nine modes/sizes pass. Logs:
ai-tmp/ai-libraries-csv-twin-measure-final.log,
ai-tmp/ai-libraries-csv-twins-verified.log and
ai-tmp/ai-libraries-csv-stream-bench-final.log.

Verified: evidence reports 7468 claims, 13562 known tests in 1120 executed
source files, zero unbacked tags and 31 provisional pins. Provenance selftests
pass 44 planted placeholders across 19 files; face generation reports six
described sources and zero findings, its 13 selftests pass, and libdoc with
both selftests passes. Log: ai-tmp/ai-libraries-csv-evidence-final.log.

Tried: CSV's library card has all seven documented heads and fourteen arrows,
but its summary begins with the README's fenced example. Move the existing
field-contract paragraph before that example so the companion README's
opening-paragraph convention supplies prose. The first standalone probe
omitted the Python seat's PYTHONPATH and raised `ModuleNotFoundError: No
module named 'metta'`; the explicit seat path reaches the card and reproduces
the summary failure.

Verified: the corrected card has seven documented heads, fourteen arrows,
three importing examples and the intended prose in its text rendering; every
head appears in text and HTML. Log: ai-tmp/ai-libraries-csv-card-final.log.
The CSV functional state is complete. Its 31 evidence placeholders are the
only remaining provenance operation before the next census concern.
