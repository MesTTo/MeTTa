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

Verified: CSV functional commit bd027d8b7a9ef1d96fb4cdb160c9b3eb4157d52e
is followed by provenance commit 02d05add8a092c5d83c853192fe442ea6e2b6a06.
There are 27 literal pin replacements in 15 files. A byte comparison proves
that replacing the new object ID with WORKTREE reconstructs each A file.
The first comparison incorrectly replaced executable placeholder fixtures as
well; the pin tool correctly preserves them. The pinned example, CSV/JSON
twins, evidence, face and libdoc pass. Evidence has zero pending placeholders.
The owned JSON control is removed after checking its diff, binary hashes and
absence of process working directories. Logs: ai-libraries-csv-pinned-example.log,
ai-libraries-csv-pinned-twins.log and ai-libraries-csv-pinned-evidence.log in ai-tmp.

## 2026-09-11: strings, formatting and similarity

Tried: the current native text/file/JSON suite passes 58 tests plus eight
subcases; Python text properties pass twelve tests in 6.58 seconds. Commands:
`sh engine/test.sh suites/libraries/lib_text.plt` and
`python -m pytest -q extensions/python/tests/ch08_data/test_text_libraries.py`.
Logs: ai-tmp/ai-libraries-string-native-baseline.log and
ai-tmp/ai-libraries-string-python-baseline.log.

Measured: ai-tmp/ai-string-baseline-bench.pl compares current literal
replacement with atomic_list_concat/3 followed by atomics_to_string/3.
For 1000/4000/16000/64000 one-character replacements, current CPU seconds are
.000400/.003385/.031335/.486955; the host control is
.000049/.000198/.000838/.003289. Every output is twice its input length.
Current inference counts are 5015/20014/80014/320014; host counts 7/6/6/6.
The initial probe lacked use_module(lib_string) and raised Unknown procedure:
lib_string:'string-repeat'/3. Explicit loading fixes the probe and contradicts
the old library header's default-loading claim. Log:
ai-tmp/ai-libraries-string-replacement-baseline.log.

Source: SWI's split_atom and sub_text compare at successive positions. Host
split/join removes the repeated suffix allocation, but matching is still
worst O(n*m). The replacement target is O(n+m+output bytes), shared with exact
splitting, search and counting. The original String coercions and empty-pattern
replacement behavior remain authoritative. Source:
https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-prims.c#L4626-L4661.

Tried: for input codes [97,0,98], native split_string with separator comma
returns ["a","b"], string_lines also returns ["a","b"], and format_paragraph
returns codes [97,32,98]. Native isub against "a", threshold zero, gives 1.0.
Log: ai-tmp/ai-libraries-string-nul-baseline.log. The report's NUL warnings are
therefore reproduced. These boundaries must preserve full String inputs;
restricting ordinary Strings to NUL-free data would leave the required surface
incomplete. Native ISub is a distinct ontology-label metric, not Levenshtein.

Research: RapidFuzz C++ v3.3.4 at
82662f3623b3ca3645e543f677fc32fb8bd1fb95 supplies exact codepoint Levenshtein
through explicit iterator ranges; the live release is dated 2026-08-30.
Its forty headers total 393533 bytes. Boost KMP and CPython two-way are the
literal-search candidates. SWI provides indentation, named interpolation and
paragraph layout, with the NUL boundaries above requiring correction.
Full primary-source leads are saved in ai-tmp/ai-string-research.md; selection,
native ownership and the complete head roster remain open before implementation.

## 2026-09-11: String design frozen before implementation

Decided: preserve the nineteen existing heads and add string-codes,
string-from-codes, string-split-exact, string-last-index-of, string-count,
string-center, string-lines, string-unlines, string-dedent, string-indent,
string-wrap, string-template, string-edit-distance, string-similarity and
string-isub. Text inputs retain String/Symbol/Number coercion. Scalar codes
include NUL and exclude surrogates. Indexes and widths count codepoints.
Exact split refuses an empty delimiter; replacement keeps its existing
empty-pattern identity. Count uses nonoverlapping matches by default, an
optional Bool enables overlap, and an empty pattern counts n+1 boundaries.
First/last indexes of an empty pattern are 0/n. Center puts the odd filler
character on the right. Existing negative clamp and empty filler cases stay.

Decided: one private C++ provider shares length-aware Unicode conversion and
KMP traversal across literal search, count, split and replacement. Adapt Boost
1.89.0's prefix table with size_t indexes and no retained caller iterators.
Traversal keeps overlap state rather than restarting at successive suffixes.
The target is O(n+m+output), with O(m) search state beyond converted inputs.
Character-set splitting adapts SWI split_string's scan with length-aware
membership. It preserves explicitly listed NUL delimiters and padding too.
SWI's indentation/line algorithms are a licensed private subset with that
split boundary replaced. Wrapping passes correctly split word tokens to
text_format:format_paragraph/2; widths must be positive, alignment is
left/right/center/justify, whitespace collapses and long words remain whole.

Decided: named templates use strings:interpolate_string/4 with goals(false).
Bindings are unique pairs whose names are Prolog variable identifiers; values
go through metta_console_text/2. Missing names raise, named defaults work,
and unrecognized brace syntax remains literal as in the provider. Existing
format-args remains the positional renderer. Lines use LF, omit one terminal
empty component, and unlines appends LF to each supplied line. Dedent removes
the common literal space/tab prefix; indent leaves blank space/tab lines alone.

Decided: vendor RapidFuzz v3.3.4's full transitive Levenshtein include closure:
21 headers, 220687 bytes, plus its MIT license. The first closure omitted two
relative SIMD includes; resolving quoted includes finds both. Use explicit
uint32 iterator ranges, unit costs and no cutoff, so the answer is exact.
Similarity is 1-distance/max(lengths), with two empty strings scoring 1.
Source: https://github.com/rapidfuzz/rapidfuzz-cpp/blob/82662f3623b3ca3645e543f677fc32fb8bd1fb95/rapidfuzz/distance/Levenshtein.hpp.
The source documents bit-vector O(ceil(n/64)*m) uniform distance. Its range
source confirms raw pointer convenience overloads stop at NUL; do not use them.
The release and commit activity establish current maintenance. The upstream
Python implementation uses the same core; no independent adoption claim is made.

Decided: adapt the SWI ISub core under its LGPL-2.0-or-later license, replacing
NUL-terminated buffers and int lengths with owned codepoint vectors and size_t.
Preserve its substring selection, threshold and edge scores. Explicit options
are normalize (default False), zero-to-one (False), and substring-threshold (2).
Normalization uses the existing lowercase operation and removes dot, underscore
and ASCII space; it is not Unicode normalization. Threshold is nonnegative.
Source: https://github.com/SWI-Prolog/packages-nlp/blob/dd69ae95342d7a0429a0f8bcc7deab2bd514570e/isub.c.

Decided: C++ RAII owns every temporary buffer. Exceptions stop at the foreign
boundary and become named Prolog resource/provider errors. KMP, conversion,
split and ISub check pending signals while walking. RapidFuzz completes its
native calculation before delivering a pending signal; it holds no external
resource. Native building keeps the existing atomic/thread/process protocol,
with explicit header dependencies in native_object/6 for every consumer.
String's recipe discovers all vendor headers; changed included inputs invalidate
the object. Wheels and source archives carry sources, headers and licenses.

Rejected: suffix copying and repeated sub_string search, because they retain
quadratic work; CPython's forward two-way source requires a sentinel and its
reverse path has a different bound. Revisit if a shared provider removes those
integration constraints. Rejected: no-NUL restrictions and a separate formatter,
because they drop required String cases or duplicate the engine's renderer.

Tried: native number_string fails normally for bad, empty, 1r0 and 1e99999
texts, while accepting +42, 0x10 and 1.0Inf. Remove parse-number's catch-all;
ordinary nonnumbers still fail and unexpected exceptions remain visible.

Verification plan: preserve the existing suite; add generated Unicode/NUL
oracles, native error and determinism checks, host layout/ISub differential
controls, exact-distance dynamic-programming goldens, cold/warm/concurrent/
cancelled/header-invalidated builds and an installed wheel. Measure replacement
and adversarial long-needle search, then run every-head example/twin, records,
docs, cards, evidence and A/B. Attribute shared startup changes using unchanged
library controls; do not reprice unrelated examples.

Tried: the native adapter builds and returns bXna for banana/ana/X and distance
3 for kitten/sitting. swipl-ld warns `Unknown option: -std=c++11`; its -help
documents `-cc-options,...`. Corrected the recipe to -cc-options,-std=c++11.
The original text/file/JSON suite still passes 58 cases plus eight subcases.

Tried: the new header-invalidation test proves changed headers trigger a failed
rebuild while preserving the object, but deleting isub.hpp incorrectly returns
success from the warm cache. Log: ai-tmp/ai-libraries-string-header-baseline.log,
one failure, thirteen deselections, 3.35 seconds. Directory discovery cannot
name a deleted dependency. Corrected the recipe to read the checksum manifest's
declared header paths, and track the manifest itself. Missing declared files now
reach the shared builder's time_file check. Add a closure/hash check so an
included vendor header cannot be omitted from that declaration.

Tried: applying the upstream header copies normalizes three terminal newlines;
the initial byte comparison raises `AssertionError: lib/lib_string/vendor/rapidfuzz/details/simd.hpp`.
All 21 headers compare equal after newline normalization. VENDOR.md records
the difference, and SHA256SUMS records the distributed bytes.

Tried: native String verification passes 31 cases and fails the template
case with `strings:interpolate_string/4: Procedure strings:interpolate_string/4
called from a deterministic procedure succeeded with a choicepoint`. The
provider's grammar has a residual search point after its unique String result.
Use once around the host interpolation call, after validating unique bindings;
named interpolation is a function and does not expose alternative parses.
The preserved text/file/JSON suite passes all 58 cases plus eight subcases.
Log: ai-tmp/ai-libraries-string-native-surface.log.

Tried: Python verification passes 28 tests and exposes two fixture errors.
Python 3.14 textwrap.dedent uses str.isspace for blank lines and turns CR into
empty text, while the frozen SWI contract preserves CR. Protect CR with a
character outside the generated alphabet while using Python's independent
dedent algorithm. The installed-wheel probe raises `ValueError: embedded null
byte` because the outer Python string decodes its source escapes; use a raw
source literal. Log: ai-tmp/ai-libraries-string-python.log, 18.31 seconds.
The inspected Python source has no _whitespace_only_re; probing that old private
name raises `AttributeError: module 'textwrap' has no attribute '_whitespace_only_re'`.
The corrected native suite passes all 29 cases plus three subcases.

Tried: the corrected Python run passes 29 tests and finds a provider discrepancy
for `" \na"`: SWI dedent retains the blank line's space when the common prefix
is empty. It can also retain excess spaces on a longer blank line. This violates
the frozen public contract that blank lines become empty. Normalize blank lines
inside the adapted dedent operation using its declared indentation characters.
Keep CR as data. Extend the native differential control with that explicit
normalization and add all three prefix-length regressions. Log:
ai-tmp/ai-libraries-string-python-fixed.log, one failure in 43.30 seconds.
The installed-wheel execution and all native build lifecycle tests pass.

Measured: the first 42-claim String example passes. Its initial minimum-of-three
cost is 120715 MeTTa and 126575 Python, ratio 1.0485. These figures precede the
blank-line correction and will be replaced by a fresh measurement before pinning.
jscpd inspects six owned files, 945 lines and 13857 tokens, finding no clones.
Vendor sources are excluded from that maintenance-cost check.

Clarified: the general replacement bound includes all input text, including
the replacement argument even when no match uses it. After text coercion the
bound is O(n+m+r+output); the original fixed-pattern/fixed-replacement benchmark
still distinguishes quadratic copying from linear traversal. Native and Python
verification of the corrected dedent passes 30+3 cases and ten tests respectively.
The eight deselected native-build cases are regex/crypto cases that passed in
the preceding full run. Two FBT003 suppressions state that MeTTa calls require
positional arguments; the owned Ruff check passes after sorting one import.

Recorded: the two reproduced NUL defects now have separate host-workaround
keys, source sites and plain-SWI reproductions. Dedent's blank-line normalization
and the functional template wrapper are deliberate public contracts, not claims
that the corresponding host predicates violate their documented contracts.

Measured: `swipl --on-error=status -q -s tests/prolog/lib_string_bench.pl`
passes every complete output and index assertion. At 1000/4000/16000/64000
characters, old replacement takes .000535/.002767/.026894/.387170 CPU seconds;
native takes .000043/.000071/.000382/.001361. Search with an absent final
character and a quarter-input-length repeated prefix takes 3.588987 seconds
for 256000 ASCII characters versus .001527 native; the supplementary-character
control takes 4.841229 versus .001277. Log: ai-tmp/ai-libraries-string-bench.log.
Native inferences do not count C++ comparisons; CPU figures are descriptive.
The former replacement copies quadratic suffix volume. Shared KMP traversal
and output assembly have the all-input-plus-output bound stated above.

Measured: final minimum-of-three String costs are 121067 MeTTa and 126928
Python, ratio 1.0484, after the blank-line correction. An unchanged control
at 02d05add8 with eight identical engine/MORK binaries measures the five
affected existing examples, then receives only String/provider and shared
native-builder source changes. The resulting costs exactly match this tree:

| Example | Before MeTTa/Python | After MeTTa/Python |
|---|---:|---:|
| text | 41471/36171 | 109796/110303 |
| regex | 108279/107645 | 108302/107668 |
| JSON | 78103/70088 | 136764/128844 |
| crypto | 77933/78285 | 126361/126822 |
| CSV | 107047/103630 | 167087/163857 |

The String face carries fifteen new heads and the private provider; importers
pay their declarations and build-input checks. The regex-only change is the
shared builder's explicit dependency argument. Repin these five attributable
movements through the twin owner. Logs: ai-tmp/ai-libraries-string-control-before.log,
ai-libraries-string-control-after.log and ai-libraries-string-final-measure.log.

Clarified: the old text twin's stored budget was 37228 while this unchanged
cut measures 36171. Its String change adds 74132 to that live baseline; the
new pin is 110303. The inherited 1057-inference discrepancy is not attributed
to String. The owner repins five changed twins and finds zero stored-content
divergences. The control is removed after checking its 37 owned source files,
all eight binary hashes and the absence of process working directories there.

Verified: `sh engine/test.sh suites/libraries/lib_text.plt
suites/libraries/lib_string_surface.plt` passes 58+8 existing and 31+3 String
cases, including NUL through retained case/slice/join/padding operations.
`python -m pytest -q extensions/python/tests/ch08_data/test_string_surface.py
extensions/python/tests/ch08_data/test_text_libraries.py
extensions/python/tests/ch08_data/test_library_native_build.py` passes thirty
tests in 23.15 seconds, including the source-archive wheel installation.
Logs: ai-tmp/ai-libraries-string-native-final.log and ai-libraries-string-python-final.log.

Tried: both host-workaround gates fail because the ISub reproduction passes a
variable options list to a compile-time expander. Exact error:
`swi_option:option/3: No rule matches swi_option:option(normalize(_2898),_2902,false)`.
The subsequent main call reports `catch/3: Unknown procedure: main/1`, and the
selftest's shipped-tree assertion fails. Log: ai-tmp/ai-libraries-string-host-gates.log.
Read isub.pl: its goal_expansion calls isub_options without a groundness guard;
normalize_int also binds variable Bool options to true. The earlier differential
test therefore did not exercise its apparent full product of options.

Decided: literal options keep the NUL reproduction focused. The differential
oracle calls the public host predicate through call/5 with runtime options.
Register the separate compiler defect as swi-isub-variable-options with a
compiled/runtime positive control. Both new plain-SWI probes print present.
Rerun the complete 588-case option product before claiming host equivalence.

Verified: the runtime oracle passes all 588 combinations within the 31+3
native suite. Both host-workaround gates pass: fourteen entries, nineteen
sites, every reproduction present, and ten checker selftests pass. The face
generator reads seven described sources with zero findings. Records report
143 derived and 204 original examples. Log: ai-libraries-string-host-fixed.log.

Tried: the six full twins prove all 173 claims with equal stored content and
the measured costs, but the new String twin has two notation findings:
`S["substring-threshold"] is S.substring_threshold` and
`S["zero-to-one"] is S.zero_to_one`. Use the direct symbol attributes and
rerun that twin before integration. The other five twins have no findings.
Log: ai-tmp/ai-libraries-string-twins-final.log.

Verified: the corrected String twin proves all42 claims with equal content,
cost126928 and zero findings. The named integration run passes all21 selected
and implied gates, including no-autoload, source/face drift, documentation,
Ruff, mypy and evidence. The origins gate reports no configured upstream;
rerun its direct checker with METTA_UPSTREAM before claiming attribution.
Evidence:7478 claims,13636 known tests,1126 executed files,zero unbacked tags.
Log: ai-tmp/ai-libraries-string-integration.log.

Tried: the card probe incorrectly assumes two examples and raises AssertionError.
The card actually reports34 heads,34 docs,37 arrows and five direct examples,
including the Prolog-alias and clock examples. Tracing file/JSON/dict/reflection
imports identifies ten more existing twins beyond the first five cost controls.
Extend attribution to that complete importer set before committing. The new
control at02d05add8 has eleven identical binaries: six engine, two MORK and
three C example objects. Selection: ai-tmp/ai-string-import-examples.txt.

Corrected: the Prolog-alias example and twin still described removed MeTTa
wrappers. Their prose now describes the retained native aliases. The random
fixture's comment describes its two draws rather than claiming collisions
are impossible. Executable claims remain unchanged. git diff --check also
finds one extra blank line after the copied SWI license; remove it and advance
the distributed checksum, then recheck the manifest and installed wheel.

Verified: the ten additional importers' Python costs match the changed-source
control exactly. The unchanged-cut baseline separates earlier stored-budget
drift from this String increment. Counts are MeTTa/Python except the three
explicit Python-only columns.

| Example | Old Python pin | CSV-cut baseline | String control | Earlier Python drift | String Python increment |
|---|---:|---:|---:|---:|---:|
| 12-dict_lib | 54190 | 70367/67459 | 128174/125362 | 13269 | 57903 |
| 14-reflect_lib | 117490 | 152660/133838 | 212681/193660 | 16348 | 59822 |
| 16-the_prolog_rung | 63602 | 154402/154793 | 202161/203169 | 91191 | 48376 |
| ch14/03-the_clock_and_the_command_line | 21614 | 26041/21924 | 85723/83710 | 310 | 61786 |
| 01-c_space | 40920 | 51968/41624 | 109923/99651 | 704 | 58027 |
| 01-c_extension | 26972 | 28415/27557 | 86377/85593 | 585 | 58036 |
| 02-handle | 33691 | 35157/33173 | 93119/91209 | -518 | 58036 |
| 01-mm2-operators | 48893 | 55621/49959 | 113574/107978 | 1066 | 58019 |
| 05-the-module-doors | 74240 | 74561/74314 | 133224/133051 | 74 | 58737 |
| 05-seeking-and-sizing | 31243 | 34066/31734 | 92028/89762 | 491 | 58028 |

The twin owner updates these ten pins; it creates no stored-content divergence.
The full run proves113/113 claims with zero findings, nine equal stores and
02-handle's existing declared divergence. The single MeTTa C-space run is
109922, one inference below the control; its declined hyperposed write has a
schedule-dependent count. All other MeTTa counts match the control. Logs:
ai-libraries-string-import-before.log, ai-libraries-string-import-after.log,
ai-libraries-string-import-repin.log and ai-libraries-string-import-twins.log.
The new budget prose explicitly distinguishes older drift from String's change.

Verified: the card has34 heads,34 documentation rows,37 arrows and five direct
examples. Its text, Rich and HTML displays all carry the heads and summary.
Direct `METTA_UPSTREAM=/home/user/Dev/PyPeTTa1/PeTTa-base python
extensions/python/tools/example_origins.py` reports143 derived/204 original
examples. Logs: ai-libraries-string-card-final.log and
ai-libraries-string-origins-live.log.

Tried: `LC_ALL=C sh engine/test.sh suites/libraries/lib_string_surface.plt`
reports `Illegal multibyte Sequence` and three failed tests, because the new
test source did not declare UTF-8. The assertions read corrupted literals;
the provider and existing codepoint-constructed tests still pass. Add the
established `encoding(utf8)` directive to that source and the new benchmark,
the only two new Prolog files containing non-ASCII literals. The repeated
suite passes31+3 cases with no warnings in0.087 seconds. Logs:
ai-libraries-string-native-locale.log and ai-libraries-string-native-locale-fixed.log.

Verified: the full benchmark under LC_ALL=C checks every result after that
source-encoding correction. At64000 replacement characters, old/native CPU
seconds are0.254360/0.000958; at256000 search characters, ASCII is
3.329132/0.001621 and supplementary Unicode is4.633524/0.001469. These are
descriptive CPU observations, not a PMU release result. The final manifest
and source-archive wheel tests pass2/2 in7.29 seconds after the license hash
change. Logs: ai-libraries-string-bench-locale.log and
ai-libraries-string-install-final.log.

Verified: the final records/docs/Ruff/evidence command passes all14 selected
and implied gates. Evidence finds zero unbacked tags in7479 claims against
13636 known tests in1126 executed files. There are53 functional-state pins to
resolve in the provenance commit. The separate correctly named prolog-face
lane and its13 selftests pass; `prologface` had selected no such lane in the
earlier command. Both direct examples pass61 assertions. The final duplicate
scan finds zero clones across six files; its Prolog inputs use its Perl lexer.
Logs: ai-libraries-string-final-gates.log, ai-libraries-string-face-final.log,
ai-libraries-string-examples-precommit.log and ai-libraries-string-jscpd-final.log.

The extended import control is removed after verifying its37 owned source
changes, eleven identical binary hashes and no process working directory in
the control. Its measurement logs remain outside that deleted checkout.
String is ready for its functional commit and header-only evidence pinning.

Tried: the functional state is committed as1b4b83542f2b187bb8d5e7b1a94608b2813e4a62.
The provenance writer resolves47 references, then reports four C++ references
as `.cpp has no comment rule here; add one rather than guessing`. The audit's
assumed53 replacement count raises `AssertionError: 47`; the gate's textual
placeholder count is not the writer's classified pin count. Restore only the
47 verified header substitutions and complete the writer before amending A.

Tried: the existing C rule also classifies `"/* commit=WORKTREE */"` as a
comment, including inside a #define. Pygments2.20.0 and Tree-sitter C++0.23.4
over Tree-sitter0.26.0 both classify the macro string's contents as a comment;
Tree-sitter also marks that valid directive as an error. Their ordinary string
and raw-string controls distinguish the other cases. Neither provider is
suitable for rewriting these source bytes. The Tree-sitter probe packages
are isolated under ai-tmp, with no project dependency change.

Decided: the C/C++ path scans lexical forms before locating comments. Reuse
the existing declaration of file classes, with a shared C-family scanner for
C and C++ spellings. Apply line splicing with an original-offset map, preserve
ordinary/character/raw literals and header names, and skip preprocessing
numbers so digit separators cannot open character literals. Raw strings use
the original unspliced text and their exact delimiter. Unterminated lexical
forms refuse before any file writes. Comment-local backtick spans prevent a
backtick inside code from suppressing a real header pin. The rules are
[C++23 N4950 translation phases](https://timsong-cpp.github.io/cppwp/n4950/lex.phases),
[preprocessing tokens](https://timsong-cpp.github.io/cppwp/n4950/lex.pptoken)
and [string literals](https://timsong-cpp.github.io/cppwp/n4950/lex.string).

Verification plan: end-to-end C++ plants cover line/block pins, emitted strings,
macro bodies, escaped quotes, raw delimiters, Unicode offsets, spliced comments,
header data and digit separators. C/header plants cover the shared string rule.
The original writer must fail these controls; the completed writer must leave
every code occurrence unchanged and resolve each real comment. No language
runtime behavior or previously measured String source is changed by this repair.

Verified: the provenance selftest passes 57 planted placeholders in 20 files,
69 C-family lexical cases and five refusals before writes. Running the new
fixture with the original writer exposes 32 defects, including rewritten C
macro strings and unresolved C++ comment pins. The real tree now classifies
all 53 current pins, including four native C++ header claims, and leaves one
backticked prose mention unchanged. The pre-pin `--check` exit 1 is expected.
Logs: ai-string-provenance-mutation.log and ai-string-provenance-check.log.

Decided: C++ module imports follow the directive-introducing token rule in
[N4950 cpp.pre paragraph 1](https://timsong-cpp.github.io/cppwp/n4950/cpp.pre#1).
The draft's proposed semicolon lookahead was wrong: the opening token and
logical line determine header-token context before the directive is validated.
Parenthesized comparisons retain ordinary comment syntax. Header-name quotes
have no escape processing, so the scanner consumes them before string literals.

Tried: the owned Ruff check reports PERF401 on the generated case loop and
TRY003/EM102 on an inline exception message. Use a generator passed to extend
and a named diagnostic message, preserving the test cases and refusal text.

Verified: `sh check.sh provenance-pin-selftest evidence evidence-selftest
ruff-drivers` passes all four gates. Evidence reads 7481 claims with zero
unbacked tags. The final duplicate check of the writer and its selftest finds
zero clones in two Python files. Logs: ai-string-provenance-gates.log and
ai-string-provenance-jscpd.log. The String behavior, import attribution and
installation evidence above still applies to the unchanged runtime sources.

String completion: functional commit 3aaad3435292e4c7d5cc3a01bfda39430aacc6e8
and provenance commit f0052a29b2bd13eb829129bf4be5b541b0022ba4 are verified.
B changes 53 header references in 37 files; reversing those substitutions
reproduces A byte-for-byte. The pinned example and twin prove 42 claims with
equal storage, 121067/126928 inferences and zero audit findings. Pinned evidence,
provenance, face and library-documentation gates and their selftests pass all
six gates. Release evidence reports zero unbacked tags and zero placeholders.

## 2026-09-11: Vector numerical investigation

Tried: the old library loses the residual in four cancellation/product/underflow
controls, returns NaN after cancelling overflowing products, and produces
infinity or zero for representable large or small norms. Unequal dimensions
return no answer. Empty dot/norm return 0.0; zero cosine returns NaN.
Negative random counts retain the accumulator and normalize it; count 1.5
draws twice. The initial Python measurement misused stats() as a snapshot and
raised its documented pre-exit RuntimeError. The corrected context-manager
probe records all 22 cases in ai-libraries-vector-baseline-fixed.log.

Measured: dot at dimensions 32/128/512/2048 uses 1563/4782/14382/52782
inferences and 0.00016253/0.00052409/0.00139378/0.004893081 CPU seconds,
minimum of three, through the Python call door. The existing compiler already
gives linear traversal. Every component must be read, so this dimension bound
is optimal; the native design targets accuracy and dispatch cost within it.

Rejected: an ordinary floating sum and sqrt(sum of squares) lose cancellation
and range. LAPACK's scaled norm avoids overflow for floating inputs, but does
not by itself specify mixed exact integers/rationals or cosine whose norms
cannot be represented as floats. Revisit a floating accumulator only if it
preserves the same contract and a measurement justifies a specialized path.

Investigated: exact rational accumulation through SWI's existing GMP arithmetic,
CPython 3.14 statistics' fraction square root, and integer quotient/remainder
rounding as used by CPython long_true_divide. The exact inputs are the stored
values: rational/1, not rationalize/1, converts each finite float before products.
The CPython sources and license are pinned at
ebf955df7a89ed0c7968f79faec1de49f61ed7cb. Norm, distance and direction can then
round only their final result. No new numerical runtime dependency is needed.

Measured: SWI 10.1.13 converts ((1<<54)+1) rdiv (1<<1129) to 0.0. The exact
value lies above half the smallest subnormal and must round to 2^-1074.
src/pl-gmp.c at fc7ef84b949378b729052c3ade79c90ce5416abb rounds a significand
before ldexp, causing the second rounding. A prospective adapter will round
integer quotient/remainder to the final binary64 quantum and pass only an
already representable dyadic to float/1. A tracked host reproduction must
identify when this workaround can lift.

Open: verify the numerical kernel's rounding, nonfinite arithmetic and cost in
an isolated probe before freezing the complete Vector implementation. For an
operation with at least one infinity or NaN, finite operands can be replaced
by signed zero or signed unit without changing the IEEE result. Check this
class/sign reduction and use the engine's existing flag-restoration owner.

## 2026-09-12: Vector kernel probe

Verified: the prospective integer-rounding kernel passes 4412 rational
conversions against Python Fraction and 2206 square roots against independent
exact squared-midpoint intervals. The first scalar check then fails:
`AssertionError: ('/', -0.0, -inf, -0.0, 0.0)`. Direct SWI, direct Janus and
each probe layer return the same wrong sign, locating the defect in the host.

Source: src/pl-arith.c:ar_divide at the pinned SWI revision computes X/inf with
`0.0*sign_f(X)*sign_f(Y)`. sign_f maps negative zero to zero, so it loses X's
sign. The ordinary finite-division controls preserve signs. The proxy-domain
division can instead multiply by the divisor's exact signed reciprocal.
Check this against the complete scalar matrix and register a second host
workaround if adopted.

Measured: setting max_rational_size=1 and max_rational_size_action=float turns
1 rdiv 3 into 0.3333333333333333. Exact reductions must detect and refuse that
configured approximation. The proposed exact_eval boundary checks its result
is rational and otherwise raises representation_error(exact_vector_arithmetic).

Verified: the corrected scalar probe passes 260 nonfinite/zero cases against
Decimal and restores all three float flags. The configured approximation
refuses by name. The unoptimized exact dot takes 88013 inferences and
0.008020292 CPU seconds at dimension 2048, against the old 52782 and
0.004893081. Dynamic arithmetic expression construction and repeated exact
conversion checks occur for both product and accumulation. The next probe
uses one compiled arithmetic expression for their shared product-sum reduction,
as SWI's sum_list uses a compiled expression for its accumulator, preserving
exactness and the nonfinite class/sign rule. No public library is written yet.

Verified: the fused probe passes 4412 rational rounds, 2206 exact squared-midpoint
root checks, 260 scalar class/sign cases, 405 exact dot controls and a further
243 product-sum class/sign controls. It restores the host's float flags and
refuses configured rational approximation. At dimensions 32/128/512/2048 it
uses 1964/6349/19405/71629 inferences and
0.000220890/0.000411820/0.001139821/0.004208181 CPU seconds through the call
door, minimum of three. These probes omit public validation and are not a
release speed claim. Commands and complete oracles are the scratch
ai-vector-kernel-check.py and ai-vector-kernel-probe.pl; final tests will carry
the independent checks against the public operations.

Tried: importing profile/1 and show_profile/1 from library(statistics) fails
because this host already imports them from prolog_profile. Direct Janus
queries also tried to convert an internal predicate indicator and unbound
collector variables. Moving the collector into the probe succeeds. For
300 native dots of dimension 8192, profile_data reports 4915200 float_class
and membership calls and 7376385 arithmetic evaluations. All sampled tick
counts are zero, so only the call counts are evidence. Keep the fused native
loop; a new floating-only provider would not satisfy the chosen Number model.

Baseline: `sh test.sh examples/ch08-data/08-03-the-shipped-libraries/13-vector_lib.metta`
passes all 17 existing claims. The full twin passes the same claims and equal
stores at 30798/32104 MeTTa/Python inferences but reports the Python budget
31537 exceeded beyond its allowance of 4. This cut already differs by 567;
keep that attribution separate from the new example and provider costs.

## 2026-09-12: Vector design frozen

Decided: publish thirteen heads at fourteen arities. Preserve dot, norm, cosine,
cosine-of-normalized and both random-normal-vector forms. Add vector-add,
vector-subtract, vector-multiply, vector-divide, vector-scale(Vector,Factor),
vector-normalize, vector-distance and vector-fill. Ordinary numeric expressions
remain the representation. The existing size-atom already gives dimension;
a second name would duplicate that operation. Matrices are outside this concern.

Inputs: validate complete proper numeric lists before reduction or random draws.
Paired lists must have equal dimensions or raise domain_error(vector_dimensions,
[LeftLength,RightLength]). Counts must be integers. Fill requires a nonnegative
count, including zero; random preserves historical negative-count clamping and
normalizes the supplied accumulator. Reject fractional random counts. Every
public operation preserves the formal exception and names itself through
rethrow_metta_operation_error/2. Control exceptions propagate unchanged.

Numbers: exact integers and rationals remain exact in elementwise arithmetic;
exact division uses rdiv and exact zero division raises. If either scalar
operand is floating, convert finite values with rational/1 before arithmetic
and round once. Dot always returns a float, retaining its empty 0.0 result.
Norm and distance round the exact sum of squares only at its square root.
Cosine uses sign(D)*sqrt(D^2/(A2*B2)); normalization uses signed coordinate
sqrt(X^2/A2). These ratios keep finite directions even when a separately
rounded norm would overflow or underflow. Every intermediate rational result
is checked; the host's configured approximation is a named refusal.

IEEE behavior: preserve infinities, NaNs and signed zeros. NaN propagates in
squared sums; infinity without NaN gives an infinite norm. Empty normalization
is empty, every coordinate of a zero vector normalizes to NaN, and cosine of
zero or nonfinite vectors is NaN. Infinity normalization yields signed zero
for finite coordinates and NaN for infinite ones. The normalized shortcut is
still dot on any inputs, including the existing nonunit result 25.

Mechanism: use the probed integer quotient/remainder rounding at the final
binary64 quantum and CPython 3.14's fraction square root with round-to-odd
intermediate precision. Include the pinned Python license and translation
notice. Register the measured SWI subnormal rounding and signed-zero/infinity
division defects with positive-control reproductions. Proxy arithmetic uses
the engine's existing flag restoration; no mutable numeric registry is added.
SWI's unbounded integer and rational arithmetic is required and a missing
capability names that requirement. Dimension traversal is O(n), already
optimal; exact arithmetic also costs the bit complexity of its operands.

Random: use the existing thread-local SWI generator and prepend each positive
uniform draw before normalizing the full accumulator. This is projection of
the positive cube, not Gaussian sampling or a uniform sphere. Preserve draw
order and the with-seed seam; validation consumes no draws. Returned vectors
are ordinary immutable values and no resources outlive a call.

Verification: preserve all seventeen example claims and call every added head
and both random arities. Native tests cover dimensional/type/count refusals,
exact/mixed arithmetic, zero/nonfinite signs, cancellation and restored host
flags and seeds. Python property tests use Fraction sums, squared-midpoint root
intervals and independent Decimal class/sign results, including extreme
exponents and engine-returned rationals through the public door. Check the
library card, generated face, example/twin, recorded costs, host ledger,
documentation records, evidence and provenance before A/B. Record the measured
dimension costs with complete-output assertions; do not widen unrelated pins.

## 2026-09-12: Vector integration requires preserving native rational atoms

Verified: the first native implementation passes 33 tests and eight subcases.
The initial suite had one missing closing parenthesis and supplied the compound
-Huge instead of an evaluated negative integer; correcting those test fixtures
makes the complete suite pass. The copied Python license now matches its source
SHA-256 b0e25a78cffb43f4d92de8b61ccfa1f1f98ecbc22330b54b5251e7b6ba010231.

Found: `m.fn.vector_divide((1,),(3,)).one()` returns `(1r3)`, but passing that
expression to vector-scale raises `number expected, found <py_Box>`.
Both wire._number_from_wire and its inline expression path build Grounded(Fraction).
Grounded.to_wire then boxes the Fraction as an opaque object. Commit
a0f1cc5f15a15e5ca6958fe02a20be8832c7237f correctly preserved Python-created
nonprimitive identity but removed native rational retransmission too. The older
da3f92c4ae42404d618c252ccbb05c871ccb3c6e preserved rationals by treating every
Fraction as native; restoring that approach would violate the later identity law.

Decided: represent a decoded native rational as a private Grounded species,
following the existing _NativeHandle distinction. Its wire tag, value equality,
hash, ordering and pickle remain native; Python-created Fraction objects retain
the existing opaque identity contract. Canonicalize denominator-one wire values
to integer atoms, as Janus and SWI already do. Keep the hot integer/float
expression decoder inline, and share only the uncommon rational construction.
Update the number ordering boundary to include exact rationals, IEEE NaNs and
signed-zero ties. The host orders NaN before negative infinity, -0.0 before
+0.0, and a float before an equal rational. Exact-type tests distinguish native
values from opaque Python numeric subclasses.

Rejected: unboxing Fractions inside Vector would patch one consumer and erase
the native-versus-host distinction. Merely retaining the wire tag would leave
equal native rationals unequal as dictionary keys and unable to pickle. The
repair belongs to the shared atom model and codec, with equality, hashing,
storage, matching, ordering, copy/pickle and public Vector composition checks.
No declaration or compiler module needs an edit.

Sources: the Janus data-conversion table maps rationals and Fraction in both
directions (https://www.swi-prolog.org/pldoc/man?section=janus-data). Python's
data model gives a subclass's reflected rich comparison priority and requires
equal hashable values to share a hash
(https://docs.python.org/3/reference/datamodel.html#object.__eq__). Source reads
cover Grounded, both wire number paths, Expression's equality/hash/encoding,
order_key, matcher dispatch and exact-Grounded consumers. The demand evaluator
already declines nonprimitive payloads; that boundary remains valid. MatchIndex
already reads the payload of Grounded subclasses and verifies candidates by
unification.

Verification design: the existing source-archive wheel test will require Vector's
provider, generated face, documentation and copied license, then compose an exact
rational after installation. The optional mypyc build test will execute its built
codec through a temporary package copy and the real Vector provider. The source
package is 8.9 MB and contains no shared objects; ignore bytecode and runtime
copies when completing the temporary compiled package. This tests the supported
optional backend without changing the modules selected for compilation.

The durable vector_numeric benchmark will time the public dot door at increasing
dimensions, checking each complete result. Record minimum-of-three inference and
process-CPU costs. Cancellation, overflow and underflow goldens execute before
timing. Dimension traversal remains linear; neither the old fold nor the exact
provider admits a lower asymptotic class when every coordinate must be read.

Tried: the expanded Python selection passes 213 tests but executing the optional
compiled codec raises `RuntimeError: Reached allegedly unreachable code!` at
factories.py's runtime lazy import. Its TYPE_CHECKING/else split was introduced
by cd62330ceacc8f1254eed9791c3f6203b48a1c9e; compilation alone never exercised it.
The generated C contains an unconditional RuntimeError at that existing line.
Mypyc 2.3.0's irbuild/statement.py:transform_block emits that refusal for a nonempty
block excluded from type analysis. Source:
https://github.com/python/mypy/blob/v2.3.0/mypyc/irbuild/statement.py#L142-L165.

Decided: the single _type_atom consumer imports type_atom_for inside the function,
after its already-an-Atom return. This preserves deferred annotation loading and
gives both mypy and runtime one ordinary import. Remove the unused conditional
catalogue imports. Reject changing TYPE_CHECKING's meaning or disabling mypyc;
neither repairs the supported backend. Extend the compiled execution probe to
call the annotation builders as well as native rational operations.

Verified: the corrected compiled execution test passes in 13.48 seconds. Both
wire and factories load from built extensions; native rationals retain wire,
pickle and ordering, typed/arrow accept Python annotations, and Vector's returned
ratios compose. The existing missing-mypyc refusal still names `pip install mypy`.

Verified: final native suite passes 33 tests and eight subcases. The extended
MeTTa example passes all 34 claims, including all thirteen heads and both random
arities. Host workarounds pass 16 entries, 21 sites and ten planted selftests;
both new native defects still reproduce. The first ledger run did not see the
new untracked files; adding them to the index resolves all four findings without
changing the ledger or its gate. Mypy passes its 176-source and three public
surface checks.

Measured: `PYTHONPATH=extensions/python python -m benchmarks.vector_numeric`
passes all four accuracy controls and every timed result. Minimum of three
public calls per dimension:

| Dimension | Previous inferences | Exact native inferences | Previous CPU seconds | Exact native CPU seconds |
| --- | ---: | ---: | ---: | ---: |
| 32 | 1563 | 1959 | .000162530 | .000179261 |
| 128 | 4782 | 6248 | .000524090 | .000390110 |
| 512 | 14382 | 18920 | .001393780 | .001115090 |
| 2048 | 52782 | 69608 | .004893081 | .003756770 |
| 8192 | unrun | 272360 | unrun | .016807914 |
| 32768 | unrun | 1083368 | unrun | .071840087 |

The previous values come from the unchanged String B baseline probe above.
Both traversals are linear. Native exact arithmetic adds validation and integer
work, while the previous fold loses the four numerical controls. CPU values are
descriptive and do not constitute a PMU release result. Logs:
ai-libraries-vector-native-final.log, ai-libraries-vector-example.log,
ai-libraries-vector-host-final.log and ai-libraries-vector-bench.log.

Measured: the extended twin's minimum-of-three is 58,375 MeTTa and 61,500 Python
inferences. The unchanged seventeen-claim baseline was 30,798/32,104 against its
older 31,537 Python pin. The new provider and seventeen added claims account for
the movement from that live baseline; the older 567-inference difference is
recorded separately. Price only this owned example.

Found: two unseeded pricing runs return 61,500 and 61,503. Exact rounding has
data-dependent branches, so the example's random inputs must be reproducible.
Use the existing with-seed scope for each positive-count example and its twin;
retain all assertions and leave the library's generator behavior unchanged.
Verify repeated fresh-process costs before writing the final pin. The existing
seeded-randomness example supplies the held-body Python spelling with S atoms.

## 2026-09-12: Vector completion

Measured: the seeded example passes all 34 claims. `python
extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/13-vector_lib.metta` -> 58,433
MeTTa and 62,208 Python inferences, ratio 1.0646; the 58,375/61,500 figures
above precede the with-seed change. Ten seeded fresh processes read 62,208
with zero spread (ai-libraries-vector-seeded-costs.log). `--repin` moves the
twin from 31,537 to 62,208 and records the mechanism, the seed and the 567
inferences of pre-Vector drift beside it. Logs:
ai-tmp/ai-lib2-vector-{example-resume,measure,repin}.log.

Verified: `sh engine/test.sh suites/libraries/lib_vector_surface.plt` passes
33 tests and eight subcases. `sh extensions/python/test.sh` over
test_vector_lib, test_rational_wire, test_library_card and
test_library_native_build passes 55 tests in 19.78 seconds, including the
source-archive wheel installation composing an exact rational. The optional
mypyc packaging test passes in 14.08 seconds; the one recorded failure of that
test (ai-libraries-vector-python-final.log) precedes the factories repair
above and its rerun passes. Logs: ai-tmp/ai-lib2-vector-{native-resume,
python-resume,mypyc}.log.

Verified: `prologface --write` reads eight described sources with zero
findings; cumulative syntax stays 284 constructs; origins stay 143 derived and
204 original; llms reads five sheets with zero findings; libdoc rewrites the
library reference, whose lib_vector row becomes 13 heads and 13 documented.
`llms.txt` counts 25 shipped Prolog halves. The 34-lane battery of prolog-face,
libdoc, corpus-coverage, cumulative-syntax, example-origins, llms, reference,
vocab-sync, fn-sync, phrasebook, face-sync, artifact-sync, lib-autoload,
no-autoload, host-workarounds, evidence, provenance-pin-selftest, ruff, mypy
and docs, with every selftest, passes. Logs:
ai-tmp/ai-lib2-vector-{records-regen,lanes}.log.

## 2026-09-12: File design frozen before implementation

Tried: the ten File-importing twins on the committed Vector tree with artifacts
purged (`find engine lib -name '*.qlf' -delete`, then `python
extensions/python/tools/twin_coverage.py --measure --rounds 3` over the ten
examples) -> text 109796/110303, JSON 136764/128844, crypto 126361/126822, CSV
167087/163857, c_space 109923/99651, c_extension 86377/85593, handle 93119/91209,
mm2-operators 113574/107978, module-doors 133224/133051, seeking-and-sizing
92028/89762 MeTTa/Python. Log: ai-tmp/ai-lib2-file-importers-before.log. These
are the controls for File's importer re-pins.

Tried: plain-SWI probes of the host's filesystem surface (ai-tmp/ai-lib3-file-probe).
`rename_file/2` across devices raises `existence_error(file, Source)` with the
context message `Invalid cross-device link` and leaves the source in place; a
file onto a directory and a directory onto a file raise the same formal with
`Is a directory` and `Not a directory`; a directory onto a nonempty directory
raises `permission_error(rename, file, Source)` with `Directory not empty`; a
directory onto an empty directory replaces it. `delete_directory_and_contents/1`
on a symbolic link to a directory unlinks the link only. `copy_directory/2` from
a directory into its own subdirectory recurses until
`representation_error(max_path_length)`. `directory_member/3` with
`follow_links(false)` omits links entirely. `expand_file_name/2` applies the
shell rule that `*` skips names starting with a dot and treats `**` as `*`.
`wildcard_match/2` raises `syntax_error` for an unmatched `[` or `{`, matches
`*` across `/`, knows no negated sets, and takes `\` as an escape. `write/2` of
a string holding codes 0 to 255 on a `type(binary)` stream writes exactly
those bytes and `read_stream_to_codes/2` reads them back; `get_byte/2` and
`put_byte/2` refuse a text stream, while `read_string/3` and `write/2` are
accepted on a binary stream under the default `stream_type_check=loose`.
`tmp_file/2` and `tmp_file_stream/3` create under the `tmp_dir` flag, `/tmp`
here, whatever `TMPDIR` says. `file_name_extension/3` gives `.env` the
extension `env` and an empty stem.

Tried: `(file-space! Path)` on an empty file answers a name no space was
registered for; `(space-atom-count)` reads 0 and `get-type` does not answer
`SpaceType`. A `temp-path!` prefix carrying a separator is already refused by
`tmp_file_stream/3`'s renamed path failing, but the exclusively created file
stays behind. A lambda evaluates to a Grounded closure and
`eval_metta_in_module(Module, [Function, Argument], Out)` applies a lambda, a
bound lambda or a function name, nondeterministically, as `par_map/3` does.
`setup_call_cleanup/3` propagates a cleanup exception after failure and
discards it after a goal exception.

Decided: keep all 32 heads and their names and publish 56 heads at 60 arities
from PlDoc declarations. Binary data is an expression of integers 0 to 255:
`read-bytes!`, `write-bytes!` and `append-bytes!` mirror the text path trio;
`file-open!` accepts the letter `b` beside HE's `r w c a t`, and
`file-read-bytes!` (all remaining, or at most a count) and `file-write-bytes!`
work on binary handles. Text operations refuse a binary handle and byte
operations refuse a text handle by name, because the host's loose type check
would otherwise decode octets as text. `replace-file!` writes text or bytes,
chosen by the content's structure, through the staged sibling directory,
close-then-rename protocol `copy-file!` already uses; `write-file!` and
`write-bytes!` stay in place, so an open handle or a hard link keeps seeing the
file. `rename-file!` is the host rename with POSIX replacement of a file by a
file and of an empty directory by a directory; a same-file rename, a
cross-device rename and a kind mismatch refuse by name and never fall back to
copying. `copy-dir!` validates the source kind, an absent destination and no
lexical overlap before allocating, copies into an exclusively created sibling
stage, preserves symbolic links as raw link text, refuses FIFOs, sockets and
devices, publishes with one rename and removes the stage on every exit; it
copies contents and links, never ownership, modes or times. `delete-tree!`
unlinks a link root, removes a directory tree or a file, and refuses a missing
path. `dir-walk` answers every descendant path, depth first, per-directory
sorted by codepoint, links reported and not followed unless
`(follow-links True)`, where a link whose target is an ancestor of the current
chain by `same_file/2` is reported and not entered. `dir-glob` takes a directory
and a relative pattern of `/`-separated components: a literal component is
joined without listing, a component with `* ? [ { \` lists the directory and
filters with the host's `wildcard_match/2`, and `**` matches zero or more
directory levels; wildcards skip names beginning with a dot unless
`(hidden True)`; `**` enters links only under `(follow-links True)`; answers
pass through `distinct/1` so two `**` components cannot answer one path twice.
`path-normalize`, `path-absolute`, `path-relative` and `path-resolve` translate
CPython 3.14.7's `posixpath.normpath`, `abspath`, `relpath` and non-strict
`realpath` at 823f0323ee6ec1402088b73bce1a38473cac36dc; `path-stem` and
`path-parts` follow the library's existing SWI conventions, so `.env` has stem
`""`. `file-kind` classifies without following the entry itself: `link`,
`directory`, `file`, `other`, `missing`. `same-file`, `read-link` and
`make-link!` expose physical identity and symbolic links. `with-file` and
`with-temp-dir` apply a function to the acquired handle or directory under
`setup_call_cleanup/3`, so every answer of a nondeterministic body streams
while the resource stays open and the close or removal runs on exhaustion, cut
or exception. `file-close!` reports a failed close instead of swallowing it;
closing twice stays silent because the second close finds no handle.
`file-space!` allocates through `new-space` so the answer is a registered space
even for an empty file. `temp-path!` refuses a separator in its prefix like
`temp-dir!` and removes the exclusively created file when the rename fails.
`list-dir!` answers names sorted by codepoint, the same order the traversal
uses. `file-lines!` splits through `lib_string`'s `string-lines`, which keeps
NUL.

Rejected: dispatching `write-file!` on content structure, because a Number
already coerces to text there and `(65)` next to `65` would be two different
files. Rejected: making `write-file!` staged, because the change would alter
inode identity under open handles in sixteen importing examples; a caller who
wants publication writes `replace-file!`. Rejected: SWI's `copy_directory/2`
and `directory_member/3` as the traversal engines, because the first recurses
into its own output and the second hides links. Rejected: following links by
default under `**` and `dir-walk`, because the host cannot bound a cycle
without a visited set and pathlib's 3.13 default is the same. Rejected: an
exclusive temporary file in an arbitrary directory, because the host exposes
no exclusive open; `temp-dir!` under `mkdir` is the exclusive primitive and
`replace-file!` composes it. Rejected: negated character sets and Python's
`[!...]`, because the declared grammar is the host's `wildcard_match/2`. Revisit
any of these when a host primitive appears.

Verification plan: extend `lib_file_surface.plt` with byte round trips of all
256 values, handle-type refusals, bytes validated before truncation, staged
replacement preserving the destination on failure, rename shapes, tree copy
with links and refusals, tree removal of a link root, traversal order and link
policy, glob literal, wildcard, `**`, dotfile and distinct cases, CPython
goldens for the four path functions, kinds for every entry class, scopes closing
on exhaustion, cut and exception with a close failure surfacing. Python tests
compare `path-normalize`, `path-absolute`, `path-relative`, `path-resolve`,
`dir-glob` and `dir-walk` with `os.path` and `glob` over generated trees. The
example `19-file_lib.metta` calls all 56 heads; its twin proves the same
claims; the ten importer twins re-pin against the control above.

## 2026-09-12: File verification findings

Tried: the first native suite -> 49 tests, four failures, each a contract this
implementation had not settled. `file-write!` on a binary handle named the
handle's kind as `text` where the handle carries `binary`; the message reads the
handle, so the refusal names what the handle IS. `replace-file!` into a missing
parent raised `file-operation-failed` wrapping the staging directory's own
existence error, which named a path the caller never wrote; the publisher checks
the destination's parent before acquiring a stage and raises
`file-not-found` for it. `copy-dir!` over a socket entry and `make-link!` under a
missing parent both wrapped a refusal this library had already named, so the
caller saw `file-operation-failed(copy-dir!, error(file-kind-mismatch(...)))`.
Decided: the refusal mapper passes its own nine formals through unchanged, so a
nested operation's name and remedy reach the caller once.

Tried: `assertion(Answers = [[H, "abc"], [H, 3]])` in the scope test leaves H
unbound, because SWI implements assertion/1 with double negation and discards
its bindings; the next line then read handle `_G123` and the test failed on
`nonvar`. Decided: bind outside the assertion and compare with `==`, the shape
the rest of the suite already uses.

Verified: `sh engine/test.sh suites/libraries/lib_file_surface.plt` passes 49
tests and 48 subcases, covering byte round trips of all 256 values through both
doors, handle-kind refusals in both directions, bytes validated before a
destination is touched, staged publication with an injected close failure, a
close failure reported rather than swallowed, the five rename shapes including
cross-device, tree copy with links preserved and a socket refused, link-root
removal, traversal order and the ancestor-cycle guard, the glob grammar
including escapes and `distinct`, the CPython path goldens, entry kinds, links
and the three scope exits. `sh engine/test.sh suites/libraries/lib_text.plt
suites/libraries/lib_json_surface.plt suites/libraries/lib_csv_surface.plt
suites/libraries/lib_string_surface.plt` still passes 58+8, 43+12, 40+40 and
31+3. Logs: ai-tmp/ai-lib3-file-surface-{first,third}.log and
ai-lib3-file-neighbours.log.

Tried: the first Python differential run -> 14 failures, all in the oracle
rather than the library. `str()` of a String atom quotes it, so every path
comparison read `"/tmp/..."` against `/tmp/...`; the atom's `.value` is the
path. `m.fn.path_relative(...)` is lazy, so `pytest.raises` saw no refusal until
the answers were drained. And `glob.glob` recurses THROUGH a symbolic link under
`**` and skips dot names, while `Path.glob` does neither: the two disagree with
each other, so one comparison cannot hold both policies.

Decided: compare each policy against the oracle that has it. With
`(follow-links True)` the library answers exactly `glob.glob(pattern,
recursive=True)`; with `(hidden True)` it answers exactly `Path.glob(pattern)`;
and a pattern ending in `**` answers the directories `Path.glob("**")` yields,
because `**` matches directory LEVELS. All three hold over twelve patterns.
Verified: `CHECK_PY=... sh extensions/python/test.sh tests/ch08_data/test_file_lib.py`
passes 33 tests, including the 256-value round trip, the four generated path
comparisons and the two traversal comparisons. Log:
ai-tmp/ai-lib3-file-python-third.log.

Measured: the example proves 90 claims over all 56 heads and 60 arities; its
twin proves the same 90 with equal stored content. Minimum of three fresh
processes: 245,536 MeTTa and 209,508 Python inferences, ratio 0.8533; five
single runs read 209,508 with zero spread (ai-tmp/ai-lib3-file-spread.log). The
209,500 measured before the lint repairs precedes the module space door the
twin now uses for a returned space name. The
twin's three scope bodies are named equations rather than inline lambdas on both
sides, so the stored content matches: a generator compiles to the example's two
`size-then-two` equations, and the scratch name is a PARAMETER, so the compiled
body carries no text and the scope receives the partial application
`(fill-and-list "scratch")`. Inside a compiled body a Python string literal
lowers to a MeTTa String while `G(...)` becomes a host object, which is why the
name arrives from outside. Logs: ai-tmp/ai-lib3-file-{example-third,twin-seventh}.log.

Measured: the ten twins that import File directly or through JSON move by the
face's growth from 32 heads to 56. The control is the unchanged branch cut at
8eb04b55a with artifacts purged (ai-tmp/ai-lib2-file-importers-before.log); the
after column is the same command on this tree
(ai-tmp/ai-lib3-file-importers-after.log). Commands:
`python extensions/python/tools/twin_coverage.py --measure --rounds 3 <paths>`.

| Example | Python before | Python after | Increment |
|---|---:|---:|---:|
| 03-text_lib | 110,303 | 140,561 | +30,258 |
| 05-json_lib | 128,844 | 151,582 | +22,738 |
| 06-crypto_lib | 126,822 | 151,609 | +24,787 |
| 17-csv_lib | 163,857 | 188,409 | +24,552 |
| 19-02/01-c_space | 99,651 | 122,130 | +22,479 |
| 19-03/01-c_extension | 85,593 | 108,072 | +22,479 |
| 19-03/02-handle | 91,209 | 113,688 | +22,479 |
| 19-04/01-mm2-operators | 107,978 | 130,457 | +22,479 |
| 20-03/05-the-module-doors | 133,051 | 157,913 | +24,862 |
| 20-06/05-seeking-and-sizing | 89,762 | 120,449 | +30,687 |

The four transitive importers pay exactly 22,479, the declarations and doc rows
alone; the six that call the library pay its compiled call sites as well. The
twin owner re-pinned all ten with that mechanism and reported zero
stored-content divergences. Log: ai-tmp/ai-lib3-file-importers-repin.log.

Verified: `sh check.sh prolog-face prolog-face-selftest libdoc libdoc-selftest
corpus-coverage cumulative-syntax example-origins llms llms-selftest reference
reference-selftest lib-autoload no-autoload host-workarounds evidence
provenance-pin-selftest ruff mypy` passes every lane. Coverage reads 744 carried
library heads and 251 engine callables with zero findings, cumulative syntax 327
examples and 284 constructs, origins 143 derived and 205 original, llms five
sheets and zero findings. Evidence reports zero unbacked tags in 7,510 claims
with 32 placeholders for the provenance commit. Three findings were repaired on
the way: the twin's docstring needed its summary line, two compiled-body
intermediates read as unused locals, and the Prolog header cited a test name
that does not exist (the four generated path comparisons are separate tests).
Ruff's pathlib preferences are answered by the comparison itself, which names
`posixpath` and `glob` as the oracles the heads translate. Logs:
ai-tmp/ai-lib3-file-{lanes,lint,lint2,lint3,lint4}.log.

## 2026-09-12: spaces and dict

Tried: probes of the operations these two compose (ai-tmp/ai-lib3-spaces-probe*.metta).
`(match $from $pattern (add-atom $to $pattern))` copies the matched atom, which
is the shape migrateAtoms already uses; `remove-atom` answers `true` for an atom
the space does not hold, so a subtraction reports work attempted rather than
failing; a match that removes from the space it is matching over completes,
which is what makes a drain one expression.

Decided: five heads for lib_spaces and four for lib_dict, each an equation over
published operations and none a synonym of one. `space-copy` with a bare
variable pattern IS the merge of two spaces, so no separate head; `find` already
answers the "any match" question and `space-atom-count` the emptiness one, so
neither is added; `remove-all-atoms` already clears, so `dict-clear` is not
added and the dict example says the space operation is the clear.

Decided: `migrateAtoms` keeps upstream's equation byte for byte. Upstream PeTTa
is the semantics arbiter and that equation names the source on both sides, so it
drains rather than moves; `move-atoms` is the head whose name matches what it
does, and both examples state the difference. Rejected: correcting migrateAtoms
in place, because the census's "correct it after reproducing the defect" reads
against the arbiter ruling once the reproduction shows the equation is upstream's
own. Revisit if upstream changes it.

Tried: the first spaces example -> `(collapse (remove-all-atoms &everything))`
answers `((true))` and not `(true)`: the library's own body is a collapse over
every atom's removal, so one call answers one expression of verdicts and a
second call over the emptied space answers the empty one. The example states
that shape rather than the shape a reader would guess.

Tried: the spaces twin passing `ledger.name` to succeedsPredicate ->
`=../2: Type error: atom expected, found "&ledger"`. The existing ch04 twin
passes the HANDLE, which the door converts; a name written as text is the thing
the seat's rules refuse anyway.

Verified: `sh test.sh examples/ch08-data/08-03-the-shipped-libraries/20-spaces_lib.metta`
passes 27 claims over all nine lib_spaces heads, and the extended
12-dict_lib.metta passes 25 over all eleven lib_dict heads. Both twins prove the
same claims with equal stored content: spaces 45,668 MeTTa against 43,720
Python, dict 168,008 against 166,909, minimum of three fresh processes. The
dict twin's re-pin from 125,362 first wrote a DIVERGENCE, because the twin was
measured before its four new claims existed; completing it made the two spaces
agree and the lane then refused the stale declaration by name, which is the
check working. Logs: ai-tmp/ai-lib3-{spaces-example3,dict-example,sd-twins2}.log.

## 2026-09-12: datastructures, and why a library value is an expression

Tried: a Prolog half whose map and queue values are the HOST's own terms, so
library(assoc) and library(heaps) could be the implementation with no adaptation
at all. A registered predicate's compound answer crosses into MeTTa as one
opaque Grounded value, compares by structure and crosses back unchanged: the
probe's seven claims pass, including `(== $a $b)` over two separately built maps
(ai-tmp/ai-lib3-ds/probe.metta).

Found: that value cannot be WRITTEN into a form. `!(bind! &m (map-from-pairs
...))` stores it and the next call answers itself, unreduced:
`['map-size', t(b,2,<,t(a,1,-,t,t),t)]`. bind! substitutes the value into the
form before evaluation, and the translator reads the compound as a nested call,
so the whole form stops being a program. A `let` over the bound name fails the
same way. A regex blob survives the same test, because a blob is atomic where a
compound is not.

Decided: the nodes are MeTTa EXPRESSIONS. An expression IS a list in this
engine, so a list-shaped node costs nothing to pass in either direction, and it
is a value every position accepts: bind! stores it, a program prints and
compares it, and a pattern can walk it. vendor/structures.pl carries SWI's AVL
insert, delete, adjust, rebalance and rotation clauses and its pairing-heap
meld, pop, merge and listing with `t(K,V,B,L,R)` written `(MapNode K V B L R)`,
`t` written `MapEmpty`, `heap(T,S)` written `(PqHeap T S)` and `t(V,P,Sub)`
written `(PqNode V P Sub)`; vendor/VENDOR.md pins both sources with their
installed checksums and records exactly that change, and SWI-LICENSE is beside
it. Rejected: converting between compound and list at the boundary, because it
is O(n) per call and would make a logarithmic operation linear. Rejected: a
handle table over host terms, because the values would then need freeing and
two maps built from the same pairs would not be equal.

Decided: 22 heads, none a synonym. A map answers no value for an absent key and
map-get-or takes the default, which is the distinction the dict library makes
too; pq-pop answers `(Priority Value Rest)` in one operation because reading and
removing separately walks the queue twice; a repeated key is refused where
map-from-pairs is written, and a repeated priority is kept, because a queue holds
what was inserted. Rejected: a deque, because the finger tree already pushes and
pops at both ends; rejected: a set, because census row 15 is its own library.

Verified: the adaptation is checked against its sources. `sh engine/test.sh
suites/libraries/lib_datastructures.plt` passes 12 tests and 15 subcases: for
key counts 0, 1, 2, 3, 7, 64 and 257 in a seeded random insertion order the map
answers exactly what library(assoc) answers for the pairs, the keys, the values,
every probed lookup and both extremes, and for 1, 2, 3, 8 and 65 keys deleted in
a different seeded order it agrees at EVERY step, which is what catches a
mistranscribed rotation; for 0, 1, 2, 3, 9 and 128 entries the queue agrees with
library(heaps) on the sorted listing, the size, the minimum and the pop, and on
merge and named removal. The suite also proves the bind! claim the design turns
on, immutability, the standard order over mixed key types, and the six refusals.
Two findings on the way: `numlist(1, 0, _)` fails, so the empty case needs its
own sequence, and the term writer the bind! test needs is `swrite/2` rather than
a `metta_write_term/2` that does not exist.

Measured: the example proves 41 claims over all 22 new heads and the queue and
finger-tree heads that were already there, and its twin the same 41 with equal
stored content: 229,830 MeTTa against 240,981 Python inferences, minimum of
three fresh processes. The two existing finger-tree twins move with the library's
new face, 236,727 to 291,869 and 208,121 to 262,458, and the 4,101-inference
OVERRUN the first one declared is gone: the face's own load now costs both sides
more than the distance the declaration was covering, so the twin fits its band
without one. Logs: ai-tmp/ai-lib3-ds-{suite2,example,twins-final,ft}.log.

## 2026-09-12: combinatorics

Decided: eight heads, and not one that already had a name. `chooseK` and
`chooseKl` are the k-subsets, so no `combinations`; what was missing is every
ORDERING (`permutations`), every subset (`subsets`, the powerset), one element
from each of several sets (`tuples`, the Cartesian product), the same set k times
(`cartesian-power`), a stride walk (`range-step`), and the three exact counts
`factorial`, `binomial` and `permutation-count`. The counts never build what they
count: `binomial` multiplies over the smaller side and divides as it goes, so a
52-choose-5 costs five multiplications and never reaches 52 factorial.

Tried: generating the face -> `weighted-subset-mass-independent/3: add a PlDoc
description and typed mode`. Once one export is described the generator requires
every non-private export to be, which is the drift rule working: the two
weighted-subset heads now declare their modes and the whole library's face is
generated, so its authored import line is gone.

Verified: `sh engine/test.sh suites/libraries/lib_combinatorics_surface.plt
suites/libraries/lib_combinatorics.plt` passes 11 tests with 73 subcases and the
5 existing weighted-subset tests. Each enumeration is counted and compared with
its closed form: permutations against factorial for 0 to 6 items, subsets against
2^n for 0 to 8, the subsets of each size against binomial for 0 to 7, a power
against size^length for 0 to 5, binomial against Pascal's rule for every pair up
to 20, and permutation-count against binomial times factorial up to 15. Every
answer is distinct where the structure says it should be, and each subset is an
ordered sublist rather than a permutation of one. Two findings on the way:
`numlist(1, 0, _)` FAILS rather than answering the empty list, so the size-zero
case of three generators needed its own sequence, and a `=` inside assertion/1
left the posterior's parts unbound, which is the binding-discard trap this suite
hit once before.

Measured: the example proves 49 claims, 27 of them new, and its twin the same 49
with equal stored content: 118,355 MeTTa against 122,318 Python inferences,
minimum of three fresh processes, re-pinned from 86,991. The 3,945-inference
OVERRUN the twin declared is gone: the enumerations and counts now cost both
sides more than the distance it was covering. Logs:
ai-tmp/ai-lib3-comb-{suite2,example,twin2}.log.

## 2026-09-12: distribution

Decided: eight heads in MeTTa over the existing weighted carrier, because each
is a fold over a finite support and the library's whole style is equations over
lib_measure's rows. `ws-variance` is computed about the mean in TWO passes; the
one-pass E[X^2] - E[X]^2 is algebraically identical and numerically useless at a
large mean, which the example proves rather than asserts: at a mean of a billion
the one-pass form answers something other than 1.0 for a law whose variance is
1.0. `ws-central-moment` generalises it, and its first moment is exactly 0.0.
`ws-mass-at-most` is the cumulative function and pairs with the existing
inclusive `ws-mass-at-least`; `ws-quantile` walks the sorted support adding mass
until the level is reached, `ws-median` is the quantile at one half, `ws-support`
is the ordered support with weights dropped, and `ws-sum-independent` convolves
the law with itself n times, so a total is a LAW rather than a simulation.

Rejected: a sampling head for moments, because the carrier is finite and exact
and `ws-sample!` already exists for a draw. Rejected: skew and kurtosis as their
own heads, because each is one division over `ws-central-moment`, which is the
head that earns its place.

Tried: the Python differential against `statistics.fmean` with weights ->
`assert 2.0 == 1.0` for the law `((2 1))`. `ws-expect` reads the weights it is
GIVEN, so on an unnormalized carrier it answers a weighted sum and not a mean;
the new heads normalize for themselves. The differential normalizes before
asking for the mean and takes the raw rows for the rest, which is the contract
each head actually has.

Verified: the example proves 43 claims, 27 of them new, and
`CHECK_PY=... sh extensions/python/test.sh tests/ch08_data/test_distribution.py`
passes 23 tests: the mean, variance, deviation and first two central moments
against `statistics` over 100 generated supports each, the cumulative function
against the running sum of the sorted support with the quantile never answering a
later value, the support against the sorted oracle, the sum of 0 to 3 independent
draws scaling both moments by n, and the four refusals. The example has no twin,
as it did not before: nine of its nineteen neighbours in that section have none.
Logs: ai-tmp/ai-lib3-dist-{example,python2}.log.
