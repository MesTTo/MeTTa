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

## 2026-09-12: functional

Decided: fourteen collection operations in Prolog and three control forms in
MeTTa. The split is what each one needs: a zip, a chunk, a window, a scan is one
pass over a list and the host does that in its own arithmetic, while a loop has
to decide whether to run its body at all, which needs a HELD parameter and the
evaluator. Each head that takes a function applies it through
`eval_metta_in_module/3`, the way `lib_thread:par_map/3` already applies one, so
a lambda, a defined name and a partial application all work and the library never
inspects what it was handed. `pipe`'s first parameter declares `'Atom'` in its
PlDoc mode, because an expression of function names is otherwise evaluated as a
call to the first of them.

Rejected: `while` and `repeat` as translator rules, the way `for` is one. A rule
rewrites the written form, so a RECURSIVE rule rewrites itself, and the two of
them exhausted the 8GB stack at translation time. The held parameter already
stops the body being evaluated too early, so the rule buys nothing and they are
ordinary equations whose body runs through `eval`.

Rejected: a `take`, because `takeK` is lib_combinatorics' and the library adds no
second spelling of a prefix; `drop` and the two chunking forms are what was
missing.

Tried: publishing the one-level flatten as `flatten/2` -> `!(flatten ((a (b c))
d))` answered `(a b c d)`, the EVERY-level answer, while
`lib_functional:flatten([[a,[b,c]],d], F)` answered `[a,[b,c],d]` in Prolog. A
registered head is reached by NAME through the module chain the calling space
resolves in, which is `space -> prelude -> metta_engine -> user -> system`; a
library's clauses are consulted into `user`, and `engine/metta.pl` imports the
whole of `library(lists)` into `metta_engine`, whose own `flatten/2` is the deep
one. The registration reported success, the arity matched, and every call reached
the host's clauses. Nothing warns: `metta_reference_prolog_owner/3` finds the
name in the chain and the import that would have collided is never attempted.
Probes: ai-tmp/ai-lib3-flatten-probe{,2,3}.pl.

Decided: the heads are `flatten-once` and `flatten-deep`, and neither takes the
bare name. Measured first: of the 255 heads the shipped faces register, that one
was the only collision, because the hyphenated, domain-qualified spelling every
other library uses is already clear of the chain. The alternative repairs were
both weighed and both rejected here. Binding the library's predicate into the
tier below the engine module (`prelude:import/1`) is refused by SWI, which
already holds `flatten/2` there from `library(lists)`
(`permission_error(import_into(prelude), ...) already_from(lists)`); binding it
into the execution module works, measured `(a (b c) d)` in `&self` and in a named
space after `abolish/1` then `import/1`, but a program defining its own equation
for that name then fails, because the engine's shadow-repair machinery only
abolishes an import it holds a `'$metta_repaired_shadow_import'/4` receipt for.
Doing it properly means teaching that receipt an explicit owner and carrying it
through four passes, pooled module recycling and the unimport lifecycle, which is
engine work with its own lane and not a libraries branch's to land. Revisit if a
library genuinely needs a name `library(lists)` exports.

Decided: the gate catches the class instead. `tests/prolog/library_autoload.pl`
already loads every `lib/*/*.pl` to ask what they call; it now also asks what
they PUBLISH, joining each face's registration forms (through the engine's own
`metta_registration_names/2`) to its module's export list, and walking
`default_module/2` from `prelude` with the two primitives the engine's shadow
bookkeeping uses. A head a tier above answers is a finding naming that module.
Reverting the rename makes it exit 1 with `lib_functional:flatten/2 answered by
lists`; each half has its own self-test, the resolution one planting a published
name a tier holds and the enumeration one requiring every library directory with
registrations to contribute a head, which caught the first version of the join
comparing a relative directory against an absolute one and reporting 0 heads
clean.

Rejected: `lib_patrick` importing this library so that either import gives both.
Measured: it costs every program that imports lib_patrick 19,326 inferences,
against 18,105 for the whole of 11-patrick's twin, for a library it may not use.
The two are separate imports and lib_patrick's comment points at this one.

Verified: `sh engine/test.sh suites/libraries/lib_functional.plt` passes 13 tests
with 75 subcases. Each operation is checked against a second way of computing the
same answer: zip against `nth1/3` and the smaller length, drop against
`append/3`, the chunks against `append/2` and the ceiling of the division, the
windows against the run at each offset, one-level flatten against `append/2`,
every-level flatten against `library(lists)`' own `flatten/2` over 200 generated
nestings, sort-by against `keysort/2` (stable, and documented to be), group-by
against first-appearance order with nothing lost, scan against the sum of each
prefix, unfold against the range it grows. The one-pass claim is measured rather
than asserted: ten times the input costs less than thirty times the inferences
for all six heads, where a quadratic pass would cost a hundred.

Measured: the example proves 51 claims and its twin the same 51, 127,108 MeTTa
against 134,567 Python inferences, minimum of three fresh processes, a first pin.
The twin declares one stored-content divergence, the loop's `tick` helper: four
Python statements compile to four nested one-binding `let*` forms where the
example writes four nested `let` forms.

Attributed: the four twins of the lib_patrick examples report the same findings
at the branch cut as here (11-patrick 18,105 against a pinned 17,788; the other
three BELOW their pins by more than the allowance), measured in a control
worktree at c75181adc with `engine/*.so`, `extensions/cmetta/libcmetta.so`,
`morklib.so` and `libmork_ffi.so` provisioned into it. Without those three
extension artifacts the same control read 17,889 for 11-patrick, which is the
isolated-checkout trap the 2026-09-05 benchmark thread already recorded: a
missing seat artifact silently changes the boot. Logs:
ai-tmp/ai-lib3-cut-patrick-{control,lane}.log, ai-tmp/ai-lib3-patrick-bisect.log.

## 2026-09-12: sets

Decided: a set IS an expression in the standard order of terms with no
duplicates, which is SWI's own ordered-set representation, so the library
introduces no value type of its own. That decides three heads out of existence:
the empty set is `()`, the cardinality is `size-atom`, and equality is `==`,
because the representation is canonical. `ord_seteq/2` exists upstream only
because its inputs may be unsorted; ours never are.

Decided: every head that takes a set CHECKS it, which is the library's whole
contribution over `library(ordsets)`. The host's merges read their arguments as
already ordered and answer nonsense otherwise: `ord_union([2,1], [1], U)` gives
`U = [2,1,1]`, which is not even a set, with nothing printed. The refusal names
the head and names `set-of` as the remedy.

Decided: hyphenated, domain-qualified names, which the functional row's flatten
finding makes mandatory rather than stylistic: `union/3`, `intersection/3`,
`subtract/3` and `subset/2` are all in `library(lists)`, which the engine module
imports whole, and `prelude` holds MeTTa's own `union` and `intersection` besides
[source: engine/prelude.pl, the Decides field naming both].

Rejected: a second spelling of lib_roman's `/?\`, `\?` and `\?/`. Those take the
COMPARISON as an argument and work over unordered lists in quadratic time; these
merge two ordered sets in one pass. Both libraries name the other's trade.
Rejected: a powerset head, because lib_combinatorics' `subsets` enumerates one
choice per answer already.

Verified: `sh engine/test.sh suites/libraries/lib_sets.plt` passes 8 tests with
198 subcases. Each merge is checked against its definition as a filter over
`member/2` for 300 generated set pairs, `set-of` against `sort/4`'s own dedup and
a hand count for 100 draws, and every answer of every head against `is_ordset/1`.
The laws are checked over 200 generated triples against a ten-element universe:
commutativity of both merges, associativity of the union, distribution of
intersection over union, De Morgan, the symmetric difference as the union of the
two differences, and subset and disjointness against their definitions.
Insertion and removal are checked to BE the merges with a one-element set.

Measured: the example proves 41 claims and its twin the same 41, 63,725 MeTTa
against 71,496 Python inferences, minimum of three fresh processes, a first pin.
The twin declares an OVERRUN of 1,399: the example nests each law claim in one
evaluation, where Python reads the same law as separate calls whose intermediate
sets cross into the host and back. Logs: ai-tmp/ai-lib3-sets-{example,suite}.log.

## 2026-09-12: pairs

Decided: the library owns the operations that only make sense once a collection
is READ as pairs, and nothing else. lib_functional's `zip` and `unzip` build a
relation and split it, and its `group-by` and `sort-by` take a key function over
arbitrary elements, so what is left is the pair shape itself: the two
projections, the converse, the two stable orderings, the multimap grouping and
its inverse, and the lookup. Nine heads.

Decided: `pairs-group` sorts by key itself. The host's `group_pairs_by_key/2`
gathers only ADJACENT pairs, so an unsorted relation answers the same key twice
and nothing says so; the sort is `keysort/2`, which is stable, so the values
still arrive in the relation's own order. That makes the head total, and the
differential against the host is then `keysort` plus its grouping rather than its
grouping alone.

Decided: `pairs-lookup` is the library's one nondeterministic head, answering
once per value the key has. A collapse over it is the list of values, an `if`
over that collapse is the presence test, and an absent key is no answer at all
rather than an empty one, which is what makes it compose. The key is compared
with `==`, as lib_sets' membership is, so a variable key matches nothing.

Tried: `if-empty` in the example -> there is no such head in this engine; the
emptiness test the corpus writes is `(== () (collapse ...))`, which four examples
already use. The claim became that, in both directions.

Tried: `refused(S.pairs_lookup(7, S.a))` in the twin -> False. A first argument
of the wrong TYPE is refused by the declaration rather than by the head, so it
answers `(Error (pairs-lookup 7 a) (BadArgType 1 Expression Number))` where the
head's own `type_error` raises. `if-error` reads both the same way, so the
example's claim held either way; the twin now asserts the Error atom.

Verified: `sh engine/test.sh suites/libraries/lib_pairs.plt` passes 7 tests. The
projections, the sort by key, the grouping and the converse are checked against
`library(pairs)` over 300 generated relations, and the host's
`transpose_pairs/2` is checked to BE this library's swap followed by its sort,
which is why no third head exists for it. Stability is checked by hand on a
five-row relation with repeated keys and values, including the two-pass sort;
duplicates are checked to survive all six row-preserving heads over 200
relations; and the grouping and ungrouping round trip is checked to answer the
relation sorted by key, with the one thing it cannot promise recorded: a group
with no values contributes no pair.

Measured: the example proves 28 claims and its twin the same 28, 47,975 MeTTa
against 47,584 Python inferences, minimum of three fresh processes, a first pin.
The twin is CHEAPER than the example: the example's `collapse` is `list()` here,
which the lookup's answers stream into directly. Logs:
ai-tmp/ai-lib3-pairs-{example,suite}.log.

## 2026-09-12: graph

Decided: a graph IS a collection of (Vertex Neighbours) pairs, which is SWI's own
S-representation with its `V-Ns` compounds written as expressions. The conversion
is forced rather than chosen: a host compound crosses into MeTTa as an opaque
value that a written form cannot hold, which the datastructures row measured, so
`bind!` over a host ugraph would store something no example could read back. The
shape that falls out is lib_pairs' multimap, so `graph-vertices` answers a
lib_sets set and `graph-edges` answers a lib_pairs relation, and the three
libraries compose with no adapters.

Decided: two refusals the host does not make. `neighbours/3` and `reachable/3`
FAIL for a vertex the graph does not hold, which a caller reads as an empty
answer, so a typo looks like a sink; these name the vertex and point at
`graph-vertices`. `top_sort/2` fails for a cyclic graph, which reads the same way,
so `graph-topological-order` refuses and NAMES a vertex that reaches itself,
found through the closure on the refusal path where one extra walk costs nothing.
`graph-is-acyclic` is the total question beside it.

Decided: `graph-of` takes the isolated vertices and the edges, in that order,
because every vertex an edge mentions is a vertex already; that is the invariant
`graph-is` checks and the one a hand-written graph misses. Rejected: `compose/3`
and `complement/2`, which the host has and the census does not name; neither has
a caller here yet.

Tried: the twin holding each intermediate graph through `.one()` -> 95,766
inferences against the example's 81,614. Writing the nested calls as the built
terms they are, `S.graph_transpose(tasks)` rather than `transpose(tasks).one()`,
took it to 92,465; the remaining 2,690 over the band is the graph value itself
crossing into the host and back on each of the sixteen calls that take it, where
the example's `bind!` keeps it inside the engine. Declared as OVERRUN with both
measurements.

Tried: comparing a graph in the twin as `Expression((S.coffee, S.shower))` -> the
twins lane refused eight of them, because a symbol-headed expression is what
calling the head builds. The comparison is now `(vertex, [neighbours])` tuples
through one helper, which reads better than either spelling.

Verified: `sh engine/test.sh suites/libraries/lib_graph.plt` passes 6 tests. Every
head that a host predicate backs is checked against that predicate over 300
generated graphs of five vertices and up to eight edges, which is dense enough
that most have a cycle; every answer that is a graph is checked against the
representation, including the neighbour-is-a-vertex condition; and the three
walks are checked against each other, a vertex being reachable exactly when the
closure holds the edge or it is the same vertex, and a topological order existing
exactly when no vertex reaches itself, with every edge's tail before its head.

Tried: the no-autoload lane over the new example -> `existence_error(procedure,
ugraphs:append/2)` on the topological-order claim. `ugraphs.pl` declares
`:- autoload(library(lists),[append/3])` and its `top_sort/2` also calls the OTHER
`append/2`, declared nowhere, which resolves by global autoload. Same trap and
same fix as lib_constraints' and lib_memo's own reach into that library:
`:- ugraphs:use_module(library(lists), [append/2])`, injected into the host
module's namespace, idempotent whichever library loads it first. With it,
`NO_AUTOLOAD=1 sh test.sh` over the example passes all 34 claims.

Measured: the example proves 34 claims and its twin the same 34, 81,614 MeTTa
against 92,465 Python inferences, minimum of three fresh processes, a first pin.
Logs: ai-tmp/ai-lib3-graph-{example,suite,noautoload}.log.

## 2026-09-12: unicode

Decided: one head per QUESTION with the variant as an argument, so the five
normalization forms, the thirteen properties and the fourteen classes are three
heads rather than thirty-two, and each refusal lists the names it knows. The
forms are stated as the flag sets the host's own convenience predicates use, so
`unicode-normalize` is one line per form over `unicode-map`, and the suite checks
each statement against the host's predicate over generated text.

Decided: no case CONVERSION here, because lib_string's `string-upper` and
`string-lower` are that; case FOLDING is the different operation of UAX#31, and
the example shows the difference on sharp s. `library(unicode)` is SWI's
ext/utf8proc pack, absent from swipl-wasm, so the library declares a new
`unicode` platform capability in the engine's census table, the seam that exists
for exactly this, and the platform_capabilities suite's 45 tests pass with the
row present.

Tried: `unicode-is` over `code_type/2` -> every claim passed under `sh test.sh`
and `(unicode-is "é" alpha)` answered False under the twins lane, which runs its
children under `LC_ALL=C`; `code_type(233, alpha)` is false there and true under
a UTF-8 locale. A classification that moves with the locale is not a Unicode
classification. Rewritten over the general category: letter, number, mark,
punctuation, symbol and separator are the category groups, upper, lower, title,
digit and control are single categories, white-space is the standard's own
White_Space list, ascii is the range and assigned is whether the database has a
category at all. The suite switches `setlocale(ctype, _, 'C')` and checks the
same twenty-five answers under both.

Tried: `unicode_map/3` with a runtime flag list -> `domain_error(unicode_map_options,
[decompose,stripmark,compose])`. The host refuses composing and decomposing at
once, and stripmark with neither, with that bare error and no reason; the
library refuses both combinations itself, naming the conflict, and the accent
strip is `(compose stripmark)`.

Tried: validating a numeric character with `unicode_codepoint_valid/1` -> that
predicate answers ASSIGNMENT, not range: 55295, 65534 and 1114111 are in range,
are not surrogates, and are invalid because they have no category, while a
private-use code point is valid. So `unicode-codepoint-valid` is documented as
the assignment question, the character check is the range, and an unassigned
number in range is a fair question for a property, which the database answers by
having nothing to say.

Tried: the grapheme claim as `("é" "x")` -> `["é","x"] does not match ["é","x"]`:
the answer is the decomposed form and the written one is composed, and they print
the same. The claim compares code points instead, which is what makes the
grouping visible at all.

Verified: `sh engine/test.sh suites/libraries/lib_unicode.plt` passes 8 tests.
Every form and the fold are checked against the host's predicate for it over 200
generated strings; idempotence and the nfc/nfd agreement of UAX#15 over the same;
the thirteen properties against the host's terms over seven characters; the
classes under both locales and against the category's initial letter; graphemes
rejoining to their text over 100 strings; and validity as assignment over the
eight boundary code points.

Measured: the example proves 54 claims and its twin the same 54, 139,207 MeTTa
against 129,667 Python inferences, minimum of three fresh processes, a first pin.
Logs: ai-tmp/ai-lib3-unicode-{example,suite,caps}.log.

## 2026-09-12: a verdict is read, not asked for

Tried: lib_parsing's `(char-if F)` as `eval_metta_in_module(Module, [F, Value],
true)` -> `Deterministic procedure lib_unicode:'unicode-is'/3 failed` on the
first character the test rejects. The engine compiles a call whose expected
answer is known as `( nonvar(Out) -> Tmp = Out ; true ), Head(Args, Tmp)`, so
passing `true` in threads it into the callee's output argument; a Bool head that
answers false then FAILS with its output bound, and SWI's det/1 declaration turns
that failure into an error. The same trap was already live in lib_functional's
`partition`, landed at a2a80061c: `(partition (|-> ($c) (unicode-is $c letter))
("a" "1"))` raised, while the same test written over `==` answered, which is why
no example had caught it.

Decided: every caller that wants "is it true?" evaluates into a fresh variable
and compares, `applied(Module, Test, Item, Verdict), Verdict == true`. Both
libraries do that now, the functional example carries the claim that used to
raise, and the twin's budget moves 134,567 to 151,546 for the claim and the
lib_unicode import it needs.

Open: the hazard belongs to any head declared det that answers a Bool, which is
most of this package's `*-is` and `*-member` heads. Nothing in the tree refuses a
caller that threads an expected answer in; the two places that did it were found
by running a det-declared test through them.

## 2026-09-12: parsing

Decided: a grammar is a VALUE, an expression built from fourteen primitives and
twelve combinators, and the library is one DCG that interprets it. The
alternative, generating a DCG per grammar, was rejected: a grammar a program can
build, inspect, store in a space and check with `grammar-is` is worth more than
the one dispatch per node it costs, and `grammar-forms` publishes the vocabulary
as data because the refusal has to list it anyway.

Decided: every way a grammar matches is an ANSWER. `alt` is a superposition
rather than a first-match choice, so an ambiguous grammar says so, and a text
that does not match has no answer rather than an error, which is what makes
`optional` and `alt` compose. The example's CSV row shows the cost of that
honesty: with a bare field of `(until ",")` the quoted row parsed two ways, so
the field stops at a quote as well and the grammar is unambiguous.

Decided: the classes are ASCII, written here rather than taken from
`code_type/2`, for the reason the unicode row measured: a class that moves with
the locale is not portable. A Unicode class is `(char-if f)` over lib_unicode's
`unicode-is`, which is the one primitive that takes a function, and the example
parses "héllo" through it.

Tried: `(char-if F)` as `eval_metta_in_module(Module, [F, Value], true)` -> the
verdict trap of the entry above. It reads the verdict and compares.

Tried: the twin's recursive grammar with `G("(")` inside a `@m.define` body ->
`Domain error: grammar expected, found [lit,<py_Grounded>]`. A `G(...)` inside a
compiled body is a host object, where a plain Python string literal lowers to the
String the form wants, which is what the file row's twin recorded for
`(write-file! ...)`. The three grammar-answering definitions use literals.

Verified: `sh engine/test.sh suites/libraries/lib_parsing.plt` passes 7 tests.
The primitives the host also has are checked against `dcg/basics` over 300
generated strings, with the one difference named: its `integer//1` accepts a
leading plus and this library's does not. A whole parse is checked to be exactly
the prefix parse whose rest is empty, over eight grammars and 200 strings. The
algebra is checked over 200 strings: `alt` of one branch is that branch, `many`
is `many1` or nothing, `many1` is one then `many`, a one-part `cat` wraps its
value, and `sep-by` with an absent separator is one part or none. The recursion
through `ref` is checked to three levels, the classes under `LC_ALL=C` as well,
and every malformed form to be named before any text is read.

Measured: the example proves 58 claims and its twin the same 58, 89,803 MeTTa
against 89,855 Python inferences, minimum of three fresh processes, a first pin:
a grammar is a term, so building one in Python and writing one in MeTTa are the
same work. Logs: ai-tmp/ai-lib3-parsing-{example,suite}.log.

## 2026-09-12: yaml

Decided: a YAML mapping is a SPACE, a sequence an expression and the scalars
their own types, which is lib_json's decision taken rather than re-made. The
whole point is that one traversal walks both formats: `json-at` follows a path
through a YAML document, `get-keys` and `get-value` query a YAML mapping, and
`dict-space` builds one. lib_yaml's Prolog half imports lib_json's `dict-space`
directly, the way lib_json imports lib_string's `metta_text/2`.

Decided: the file doors are DERIVED in the face. `yaml-read!` is
`(yaml-decode (read-file! $path))` and `yaml-write!` is
`(replace-file! $path (yaml-encode $value))`, one line each, so the library holds
no second copy of the staging-and-rename protocol. There are three in the tree
already (lib_file's sibling-directory stage, lib_json's tmp_file, lib_csv's), and
a fourth would have been the wrong answer to a solved problem.

Tried: reading a multi-document stream -> the host's `yaml_read/2` FAILS, and
fails on the FIRST document, whatever markers the stream carries (`---` between,
`---` before each, `...` then `---`). A second read after a single document
answers an unbound variable, which is the empty document. So the library refuses a
multi-document stream naming the marker, with the remedy: split the stream and
decode each piece. A silent first-document answer would have answered less than
the text says. Rejected: splitting the stream here, because a `---` line inside a
block scalar would mis-split and answer two wrong documents rather than refusing.

Measured: the host reads an omitted value as the EMPTY STRING, not null:
`yaml_read` over "k:\n" answers `yaml{k:""}` where YAML 1.2 reads an omitted value
as null, and it cannot be told from `k: ""`. Normalising it here would corrupt an
explicitly empty string, so the divergence is documented in the header, the face,
the example and the suite, and a document that means null writes `~` or `null`.

Tried: `with_outcome_cleanup(Setup, Goal, true)` for the nested-mapping release ->
`Unknown procedure: lib_yaml:true/1`; the cleanup is called with the outcome. The
rows are built before `dict-space` allocates instead, so a nested mapping that
raises leaves no space of the outer one behind and lib_json's own cleanup owns
what it made.

Verified: `sh engine/test.sh suites/libraries/lib_yaml.plt` passes 7 tests. The
twelve scalar shapes are checked against the host's reader, the mapping's keys
against its dict, the round trip over ten documents with a space equality that
compares pairs rather than handles, the multi-document failure against the host's
own silence, the tags both ways, and the four refusals.

Measured: the example proves 32 claims and its twin the same 32, 182,395 MeTTa
against 179,414 Python inferences, minimum of three fresh processes, a first pin.
The twin declares one stored-content divergence, the scope function's four
statements compiling to nested `let*` forms where the example writes `let`.
Logs: ai-tmp/ai-lib3-yaml-{example,suite}.log.

## 2026-09-12: markup

Decided: an element is `(element Name Attributes Children)` with each attribute an
`(attr Name Value)` row, and the tag on the attribute row is the whole finding of
this row. An untagged `(Name Value)` pair is an EXPRESSION whose head is the
attribute's name, and `id`, `class`, `type` and `value` are all names the engine
knows: `(element d ((id "7")) ())` answers `(element d ("7") ())`, because the
engine evaluated `(id "7")` as a call to the identity function and kept its answer.
Measured through the engine, both ways. With the tag the row's head is `attr`,
which names no function, and the whole document is inert data a program
pattern-matches.

Measured, and worth knowing for every library whose rows hold user symbols: the
hazard is LOUD rather than silent wherever a library checks its own shape.
`(pairs-keys ((id 1) (b 2)))` raises `type_error(pair, 1)`, because `(id 1)`
evaluated to `1` before lib_pairs saw it, and `(graph-of () ((id b)))` raises
`type_error(edge, b)`. The answer is never wrong; the message names the shape
rather than the cause, which the next entry fixes.

Decided: every parse is STRICT, through `max_errors(0)`. The host's parser repairs
a missing end tag, a stray close tag and character data outside any element, warns
on stderr and answers a DOM anyway, and an external SYSTEM entity is declined with
a warning that leaves the element silently empty. A document that needed repair is
a document its sender got wrong, so each is a refusal here; that is also what keeps
a parse from reading a file or a URL the document names.

Tried: catching only `syntax_error` from the loader -> the empty document raises
`representation_error(code_point)` from the reader instead, so nothing refused it.
Every complaint now maps to one `syntax_error(markup(Reason))`, with a control
signal rethrown untouched.

Decided: the selector language is an expression converted to the host's xpath term,
with three steps and three modifiers, and the modifiers attach to the step they
follow rather than being steps of their own, because that is how xpath spells them:
`//(item(text))` and not `//(item)/text`. Measured the host's own path shapes
before writing the converter: a child is the BARE name under a path, a descendant
is `//(Name)`, the element itself is `/(Name)`, and a path folds to the left.

Tried: `markup-attribute` with the name declared Symbol -> refused with
`BadArgType 2 Symbol (-> $_0 $_0)`, the identity function's own arrow, because `id`
is a name the engine knows a type for. Declared `%Undefined%` the name was
evaluated and matched nothing. The name is HELD, declared `'Atom'`, which is what
an attribute name has to be.

Verified: `sh engine/test.sh suites/libraries/lib_markup.plt` passes 6 tests. A
parse is checked against the host's own DOM in this shape, every selector against
the xpath term it stands for over nine forms, the write-and-parse round trip over
200 generated trees whose text and attribute values carry the characters the writer
escapes, the five malformed documents, the two external entities against an
internal one that IS expanded, and the refusals for an unknown selector form, a
modifier with nothing to modify and an untagged attribute row. The round trip's law
is stated up to text MERGING, which is the strongest one XML has: two adjacent text
nodes are one run of characters in the markup.

Measured: the example proves 30 claims and its twin the same 30, 104,676 MeTTa
against 110,488 Python inferences, minimum of three fresh processes, a first pin.
Logs: ai-tmp/ai-lib3-markup-{example,suite}.log.

## 2026-09-12: a row whose head names a function

Decided: the refusals in lib_pairs and lib_graph name the CAUSE, which the markup
row measured: a key or a vertex that names a function is evaluated where the row is
written, before any head sees it, so `((id 1) (b 2))` arrives as `(1 (b 2))` and
`((id b))` as `(b)`. The shape check caught both already, which is why no answer was
ever wrong, but its message named the shape it wanted and left the reader to
discover the evaluation. Each now says what happened and what to do: write such a
key as a String, or tag the row as lib_markup's `(attr Name Value)` does.

Rejected: tagging lib_pairs' and lib_graph's rows. A relation of (Key Value) pairs
is the shape lib_functional's zip answers, lib_json's dict-space takes and
group_pairs_by_key reads, and a tag there would fork all of those; the vertices and
keys that collide are the engine's own function names, which a program can spell as
Strings. Revisit if a caller turns up whose keys are symbols it does not choose.

Verified: both suites gain a test that the message names the cause and that the same
key written as a String answers, and pass at 8 and 6 tests.

## 2026-09-12: encoding

Decided: bytes are an expression of Numbers from 0 to 255, which is lib_file's own
byte shape, so `read-bytes!` answers what these heads take and `write-bytes!`
writes what they answer. Nothing here introduces a byte type.

Decided: the UTF-8 codec is lib_csv's vendored one, imported as a module. The tree
already had one implementation of text-to-bytes in `support/csv_codec.pl`, adapted
from SWI's own csv.pl, and a second would be a second place for it to disagree.

Tried: base64 through the host's `base64_encoded/3` with the bytes carried in a
string -> `(255 254)` encoded as "w7/Dvg==", the base64 of FOUR bytes, because the
predicate's default encoding is utf8 and it encoded the string's UTF-8. Naming
`encoding(iso_latin_1)`, which is the encoding base64 is defined over, makes a code
point a byte again and the same input answers "//4=". The suite checks every
generated byte string against the host's own encoder with that option, in both
alphabets.

Decided: base64 takes its ALPHABET as an argument rather than publishing two pairs
of heads, `standard` padded and `url` unpadded, which are the two RFC 4648 names.
The example shows where they differ, which is exactly the two characters the
standard names.

Verified: `sh engine/test.sh suites/libraries/lib_encoding.plt` passes 6 tests. All
three encodings round-trip over 300 generated byte strings and texts; UTF-8 is
checked byte for byte against the host's own conversion through a memory file, over
200 generated strings including an emoji; hex is checked over all 256 bytes for
lower case out and either case in; base64 against the host's encoder over 200
generated inputs and for the padding law. Every refusal names what it found.

Measured: the example proves 39 claims and its twin the same 39, 149,599 MeTTa
against 147,669 Python inferences, minimum of three fresh processes, a first pin.
Logs: ai-tmp/ai-lib3-encoding-{example,suite}.log.

## 2026-09-12: system

Decided: a read of an unset variable has NO answer, where an empty value answers the
empty String. Unset and empty are different states and a program that defaults one
has to be able to tell; a collapse over the read is the presence test, which the
example shows both ways.

Decided: the environment is a relation of (Name Value) pairs with STRING names, so
lib_pairs reads it and the row stays inert whatever a variable is called: a Symbol
key named like a function would be evaluated where the relation is written, which
the markup row measured.

Decided: the working directory is read and changed here rather than in lib_file,
because it is a property of the process and not of a path, and the header says the
write outlives the space that made it, as the environment's does.

Decided: no shell, and the header says so where a reader looks for one. lib_process
runs an executable with an argument vector; nothing in this library hands text to a
shell to interpret.

Verified: `sh engine/test.sh suites/libraries/lib_system.plt` passes 6 tests. The
environment relation is checked against the host's own environ/1 over the same
process, every platform key against the host's flag or predicate, the version text
against its three numbers, and the working directory against what the process
reports, with a refused move leaving it unchanged and a real move undone by the
test's own cleanup.

Tried: `environ/1` for the listing and `gethostname/1` for a hostname key -> the
lib-autoload lane named both: they are library(unix)'s and library(socket)'s, SWI's
ext/clib pack, reachable here only through the autoloader. The listing is worth a
census row, `environment-listing` over library(unix), because getenv/2 answers only
a variable a caller can already name; the hostname is not, because linking a whole
network library for one string is the wrong trade, so `platform-info` has ten keys
and not eleven. `env-all` refuses by name where the capability is lost.

Measured: the example proves 29 claims and its twin the same 29, 122,661 MeTTa
against 117,508 Python inferences, minimum of three fresh processes, a first pin.
Logs: ai-tmp/ai-lib3-system-{example,suite}.log.

## 2026-09-12: process

Decided: a program is named and its arguments are a COLLECTION, with no head anywhere
that hands text to a shell. That is the whole reason this library exists beside
lib_system's promise of no shell: `(process-run! "rm" ("; rm -rf /"))` deletes a file
with that name, and a caller who wants a shell writes one as the program,
`(process-run! "sh" ("-c" "..."))`, which is visible in the call.

Decided: a nonzero exit is a STATUS. `(process-result Code Output Error)` answers
whatever the program exited with, because a program that ran and failed is not one
that could not run, and only the second raises. A signalled death answers the negative
of the signal number, which is what a single Number can carry and what every shell
reports; `process-status` answers the same shape without blocking, and `running` while
the program is.

Decided: both pipes are read to completion before the wait. A program whose output
exceeds the pipe buffer would otherwise block writing while this process blocks
waiting; the suite runs `seq 1 30000`, 168,894 bytes against Linux's 65,536-byte pipe,
which deadlocks under the other order.

Decided: the LAUNCH is the setup of the cleanup that closes the pipes, rather than a
`setup_call_cleanup(true, ...)` after it. process_create/3 is what creates the
descriptors, so with the launch anywhere else there is a window in which they exist
and nothing is registered to close them. The suite counts open streams before and
after a large run, ten runs, and a refused launch.

Tried: `:- use_module(library(readutil), [read_string/3])` -> `import/1:
system:read_string/3 is not exported (still imported into lib_process)`. read_string/3
is a system builtin, not one of readutil's exports; the line is dropped and a comment
says so, because the next author's instinct is to add it back.

Decided: four signals and no more, `term`, `kill`, `int` and `hup`, listed by
`process-signals` and named in the refusal for any other. The host takes a number or
any signal name, and a library that passed one through would publish the whole POSIX
table as a typo surface; these four are what a program that starts a child needs.

Verified: `sh engine/test.sh suites/libraries/lib_process.plt` passes 8 tests: the
exit code and the two streams against `sh -c`, the argument that looks like a command,
a Symbol and a Number as argument text, the 168,894-byte read with the stream count
before and after, the fed input against `cat` and `wc -c`, the started process polled,
signalled twice over and waited for, the double wait and the missing program refused,
and every type refusal naming what it was given.

Measured: the example proves 24 claims and its twin the same 24, 50,892 MeTTa against
47,068 Python inferences, minimum of three fresh processes, a first pin. Both numbers
are less than half the other libraries' rows, because the work here is the child's and
not the engine's.
Logs: ai-tmp/ai-lib3-process-{measure,plt}.log, ai-tmp/ai-lib3-suite-lib_process.log.

## 2026-09-12: UUID design

Tried: library(uuid) on SWI 10.1.13 generates versions 1 and 4; namespace
versions 3 and 5 match the DNS example.com vectors. is_uuid/1 accepts 36
hyphens. An atom with codes [97,0,98] produces the same name UUID as "a";
U+00E9 produces 61372fd7-1aa6-5e91-8e3e-c1e3ecc18450 instead of the UTF-8
vector ebfe0af8-3997-5ade-b634-ba92cf69f557. U+6F22 raises
representation_error(encoding). The tracked reproductions in
tests/checks/host_workarounds/ record the two defects separately.

Decided: explicit host generation for versions 1 and 4, and the byte construction
for versions 3 and 5 from
[CPython 3.14 uuid3/uuid5](https://github.com/python/cpython/blob/v3.14.0/Lib/uuid.py#L763-L790).
lib_encoding owns UTF-8 and hexadecimal; lib_crypto owns the digest. One
construction covers standard and arbitrary UUID namespaces, Unicode, NUL and
empty names. Generation acquires no library-owned scope or handle. Version 1
discloses time and potentially MAC data; the default public random door selects 4.

Rejected: direct OSSP name calls, because their text boundary loses input; revisit
only after the tracked reproduction reports absent and arbitrary namespaces are
supported. Rejected: host is_uuid/1 as the validation authority, because it accepts
nonhex digits; revisit after its reproduction reports absent. Version 2 generation
is outside the host's working versions, and versions 6 through 8 have no selected
provider. Version 2 timestamp extraction is omitted because its local identifier
replaces timestamp bits; only RFC version 1 exposes a complete timestamp.

Verified: the 43-claim example and Python twin pass. The seven plunit tests include
40 host name comparisons, six independent Unicode/NUL vectors, 256 byte patterns
covering every value at every position, 36 malformed mutations and refusal checks.
The initial suite used a forall-local Random after forall returned and raised
domain_error(uuid, Variable); moving that assertion inside its quantified body
fixed the suite without changing the provider. The two host reproductions answer
present. jscpd over lib_uuid and its twin reports zero clones.

Measured: `twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/33-uuid_lib.metta` gives 198800
MeTTa and 195441 Python inferences, minimum of three fresh serial processes.
Logs: ai-tmp/ai-lib4-uuid-{example,twin,measure,suite-fixed,jscpd,records}.log.

## 2026-09-12: UUID verification and pricing

Tried: the full twins lane rejected the initial 195441 pin at 176007.
ai-tmp/ai-lib4-uuid-cost-probe.log separates two causes: the native crypto
dependency loads from source until its own example creates lib_crypto.qlf,
and decoding random UUID bytes varies with their hexadecimal digits.
engine/qlf_boot.pl:qlf_compile_argument compiles the requested library half;
it does not compile the closure of native use_module dependencies.

Decided: validate UUID digits with the host's native character predicate and
inspect version/variant fields directly. These queries need no byte collection.
The example now imports and exercises crypto-random-bytes alongside identifiers,
making the secret/identifier distinction executable and including that API's
import cost in both notations. Six observations before and after a separate crypto
example then gave the same 186022 twin count. The original measurement above is
superseded by this section's final fixture and measurement.

Tried: replacing any of the four UUID hyphens with NUL passed the host splitter,
total length and group lengths. The new delimiters_are_literal_hyphens regression
failed at true==false for all four positions. Requiring exact reserialization
with literal hyphens fixes it and names the existing swi-string-nul-membership
workaround. No existing library source or engine loader changed.

Verified: all eight plunit tests and all 45 example/twin claims pass. The new
claim rejects NUL separators, and the added crypto claim demonstrates the
separate secret-generation operation. The staged evidence checker accepts the
new tags. The additional host-workarounds lane exposed the earlier graph row's
missing swi-ugraphs-append2 ledger and reproduction; that repair is a separate
functional/provenance pair after UUID.

Measured: `twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/33-uuid_lib.metta` gives 190880
MeTTa and 188846 Python inferences, minimum of three fresh serial processes.
Logs: ai-tmp/ai-lib4-uuid-{example,twin,measure,suite,records}-complete.log and
ai-tmp/ai-lib4-uuid-nul-regression-before.log.

Verified: the required library lane batch passes, including staged evidence.
The full twins lane also reads UUID at 190880/188846 with equal stored contents
and all 45 claims. Its 263 remaining corpus findings exclude this row;
43/336 files pass with 3004/3004 claims proved, and twins-selftest passes.
Logs: ai-tmp/ai-lib4-uuid-{lanes,twins}-complete.log.

## 2026-09-12: track the graph host import repair

Tried: host-workarounds refused lib_graph's swi-ugraphs-append2 site because its
ledger entry and tracked reproduction were absent. Blame attributes the site
to this package's a5738e939. With autoload disabled, top_sort([a-[b],b-[]],Order)
raises existence_error(procedure,ugraphs:append/2); importing append/2 explicitly
restores Order=[a,b]. Scratch reproduction: ai-tmp/ai-lib4-graph-probe.log.

Decided: track the two-arm reproduction and ledger entry. The existing import
and all library code remain unchanged, so no library twin cost changes.

Verified: `sh check.sh host-workarounds host-workarounds-selftest evidence`
passes. All 19 reproductions answer present, 25 sites resolve, all 10 planted
negative controls are reported, and evidence has zero unbacked tags.
Log: ai-tmp/ai-lib4-graph-evidence.log.

## 2026-09-12: logging design

Tried: the host message probe confirms that a succeeding message_hook/3 consumes
the message, failure leaves the printer active, and a thrown handler error
propagates. The engine's existing thread_message_hook observes and fails before
user:message_hook. Sources: SWI-Prolog boot/messages.pl:print_message_guarded/2 at
fc7ef84b949378b729052c3ade79c90ce5416abb and library/debug.pl:debug_topic/1.
Log: ai-tmp/ai-lib4-logging-host-probe.log.

Decided: carry the handler and calling module inside each structured host message.
log-to! composes as a partial application; no scoped handler database or global
key is needed. log-topic! stores its Boolean under metta_log(Topic) in the host
debug registry. The host's topic declaration and update share prolog_debug's
mutex. Unknown topics are disabled. The private debug_topic/1 is the host's own
declaration mechanism, needed because public debug/1 warns on an unknown topic.
Its source is pinned at
https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/debug.pl.

Rejected: a second registry and ambient handler scope, because the host already
owns topic state and the message can carry its handler. Revisit a scoped handler
only for a requirement to intercept messages that do not carry an explicit one.

Tried: passing a constructed event directly to an eager callback evaluates a
nested (+ 1 2). Quoting the argument preserves it; an Atom-typed callback instead
receives the written quote. Log: ai-tmp/ai-lib4-logging-values-probe.log.
Decided: message payloads are held, and handlers accept an evaluated Expression
and answer Bool. The event crosses under quote, then follows normal function
argument semantics. True consumes; False delegates; a missing or non-Bool first
answer raises. Existing host hooks retain their precedence. log-format uses
the engine's diagnostic sdisplay/2 and the same message translation as log!.

## 2026-09-12: logging verification

Tried: the Python twin used module-level match as a built expression. Its runtime
meaning is a conjunction query against the default space, and evaluating that
query raised `EngineError: one() expected exactly one answer, got 0`. The captured
record was intact. The twin now queries records[pattern].one() and inspects the
payload value directly. Log: ai-tmp/ai-lib4-logging-twin-probe.log.

Tried: the exception test expected division by zero to throw a native exception.
The engine instead returns (Error (/ 1 0) DivisionByZero), correctly refused as
a non-Bool verdict. The test now covers both that value and a native log-format
domain error, which propagates unchanged. Log: ai-tmp/ai-lib4-logging-suite.log.

Verified: 28 example/twin claims and all 10 plunit tests pass. The suite checks
every level, host registry agreement, exact topic names, hook precedence,
held runnable and NUL payloads, first-verdict consumption, refusals and formatting.
Eight concurrent jobs toggle two shared topic names 32 times apiece, retaining
exactly one final host registry row per topic. jscpd reports zero clones.
Logs: ai-tmp/ai-lib4-logging-{example,twin-fixed,suite-complete,jscpd}.log.

Measured: `twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/34-logging_lib.metta` gives
53732 example and 54976 twin inferences. The twin's compiled capture helper
and explicit value inspection are within the required band.
Log: ai-tmp/ai-lib4-logging-measure.log.

Tried: the required library lanes passed except Ruff FBT003 at the twin's two
positional Python Bool arguments. The calls now pass the existing MeTTa TRUE
and FALSE values. Repeating the three-round measurement gives the same
53732/54976 counts. Log: ai-tmp/ai-lib4-logging-measure-final.log.

Verified: Ruff now passes, completing the required library lane batch. The full
twins lane reads logging at 53732/54976 with all 28 claims and equal stored
contents. It retains 263 unrelated findings; 44/337 files pass with 3032 claims
proved. UUID retains its exact 188846 pin. twins-selftest passes.
Logs: ai-tmp/ai-lib4-logging-{lanes,ruff-final,twins-lane}.log.

## 2026-09-12: math design

Decided: compose factorial and binomial from lib_combinatorics, whose exact
implementations landed in 08b2103. Add collection gcd/lcm, rational construction
and decomposition, host rationalization, exact integer roots, modular powers,
finite-domain factor pairs, scalar floating conversion and number classification.
One function/arity table supplies native floating dispatch and discovery for
hyperbolics, error functions, lgamma, log10, atan2, sign/adjacent-float operations,
floating parts and constants. Existing core arithmetic and bit names remain.

Tried: the native provider probe confirms negative odd roots, including
root(3,-28,-3,-1), and normalized modular powers, (-2)^3 mod5=2. The host's
powm requires nonnegative base/exponent and positive modulus; reduce the integer
base modulo that positive modulus before calling. Primary source:
https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-arith.c,
nth_integer_root_and_remainder and ar_powm. Log: ai-tmp/ai-lib4-math-host-probe.log.

Decided: positive factor pairs are a native clpfd query. The first factor is
bounded by the exact square root, eliminating mirrored pairs; labeling streams
solutions and zero is refused because it has infinitely many factor pairs.
The probe enumerates all five pairs of36 in2773 inferences. This is finite
constraint search, with no cryptographic factorization performance claim.

Tried: vector-scale([Value],1.0,[Float]) preserves signed zero and rounds the
known above-midpoint subnormal rational correctly. It also handles signed
overflow, infinities and NaN. The first probe passed unevaluated -Tiny compounds
and raised a number type error; explicitly calculating their values fixes it.
Logs: ai-tmp/ai-lib4-math-float-{probe,complete}.log.

Decided: scalar conversion is that multiplication by the floating unit. It uses
lib_vector's established rounding policy and requires no second numeric kernel.
dot is unsuitable because its zero accumulator loses a single negative zero.
Import the Vector and combinatorics faces before the native math half so their
compiled dependency state is consistent in isolated and corpus runs.

Verified: the host ar_rationalize source preserves exact numbers, rejects NaN
and infinity, and uses mpq_set_double for finite floats. Its documented result
is an approximation within floating rounding error, while rational/1 represents
the binary value exactly. The boundary probe covers both zeros, subnormal and
normal tiny numbers,0.1 and the largest finite float; 0.1 rationalizes to1r10.
Log: ai-tmp/ai-lib4-math-rationalize.log. Documentation:
https://www.swi-prolog.org/pldoc/man?function=rationalize%2F1.

Tried: the Python twin initially used div, while the binding's catalog maps
truediv to /. Correcting the alias passes all67 claims. The first three-round
measurement reads118966 example/121577 twin inferences.

Tried: configured_approximation_refuses_exact_construction exposed a contract
violation: max_rational_size=1 with max_rational_size_action=float made rdiv
return0.3333333333333333. The regression failed with assertion nonvar(Error).
Decided: inspect the constructed numeric species and refuse the host's explicit
approximation policy when it would replace an exact result. This follows Vector's
existing exact_result boundary and leaves process flags untouched. The runtime
configuration is not a host defect and needs no host-workaround key.

Verified: lib_math's13 tests pass, including exhaustive finite integer identities,
all factor pairs for1..256, exact big-integer boundaries and subnormal ties.
The67-claim example passes again after the approximation refusal. Three fresh
measurement processes give118980 example/121592 twin inferences, superseding the
initial price. jscpd finds zero clones in the native source and twin.

Verified: the required library, documentation, corpus, provenance and Python
lanes pass; host-workarounds reports 19 entries and 26 sites, all present.
The full twins lane matches all 67 math claims, equal stored contents and the
121592 pin against 118980. Its existing 263 findings remain across 301 twins;
45 of 338 corpus files pass, proving 3099 claims. The twins selftest passes.
Logs: ai-tmp/ai-lib4-math-{lanes,twins-lane}.log.

## 2026-09-12: random design

Decided: five heads provide occurrence choice, shuffling, sampling with a
replacement Bool, a finite draw stream and distribution discovery. A distribution
is held data, with ten forms: uniform, normal, lognormal, exponential, triangular,
gamma, beta, bernoulli, pareto and weibull. Collapse already collects a stream;
cutting it stops draws. Validate complete inputs before consuming random state.
Degenerate distributions consume none. The existing with-seed scope owns generator
restoration; each new draw declares seam:seeded_operation/1 beside its definition.

Decided: use library(random)'s occurrence selection, random-key permutation and
randseq. One population compound makes indexed sample reads constant-time after
an O(n) conversion, avoiding k linked-list walks. With replacement costs O(n+k);
without replacement adds randseq's index selection and O(k log k) permutation.
Shuffling keeps the host's O(n log n) algorithm. Weighted distribution algebra
and sampling stay in lib_measure/lib_distribution.

Decided: continuous parameters convert through math-float to finite binary64.
Normal sampling uses a stateless Box-Muller draw, with no cached spare beyond the
host generator. Uniform and triangular interpolation use Vector's exact dot
accumulator; final conversions follow its signed IEEE saturation policy. The
distribution laws use native floating precision and can round to support endpoints.
Source: CPython random.py at ebf955df7a89ed0c7968f79faec1de49f61ed7cb, gauss,
triangular, expovariate and weibullvariate.

Tried: a logarithmic gamma sample avoided underflow in beta ratios but changed
gamma(1e308,1) to1.0000000000000136e308, far beyond that distribution's spread.
Rejected: converting every product through log/exp. Revisit only with a numerical
representation that preserves the concentrated distribution at huge shapes.

Decided: retain the Marsaglia/Tsang factors and a separate logarithmic power
correction. Multiply ordinary factors exactly, using logarithms together only
when the power would be subnormal, zero or infinite before the final scale.
Beta divides exact products when the corrections cancel; otherwise it forms a
log-ratio and a bounded logistic expression. Exact rational log combinations
avoid overflow for subnormal shape parameters. This is the paper's boosting
identity with delayed multiplication, not an approximation to a different law.
Primary implementation and license:
https://github.com/rust-random/rand_distr/blob/d65b9bbf991e56d8a097a35d934e6f93d9194ac0/src/gamma.rs.
NumPy's logarithmic beta ratio motivated preserving underflowed powers:
https://github.com/numpy/numpy/blob/2f7fe64b8b6d7591dd208942f1cc74473d5db4cb/numpy/random/src/distributions/distributions.c.

Verified: ai-lib4-random-probe-final.log preserves gamma(1e308,1)=1e308,
beta(1e308,1e308)=0.5 and the large-scale tiny-power product1e308. Seed2 with
shape0.001 underflows at scale1 but gives2.6489501936835076e-34 at scale1e300.
Ten thousand draws give gamma(2,3) mean5.9453975406840645 and beta(2,5)
mean0.28835538137241828. These are provider probes, not library measurements.

## 2026-09-12: random verification

Tried: querying get-type on an unevaluated random-draw! expression reported
%Undefined%, as required by get-type's held argument. Binding its result first
gives Bool. The Python twin then exposed the existing rational wire boundary:
Answers.one() decodes a native rational into Fraction, which re-enters a held
distribution as a Python object. Answers[0] retains the native atom. The example
and twin now pass the same 59 claims, including computed rational parameters.

Verified: three measured rounds after deleting QLF artifacts price the twin at
117876 inferences against 122535 for the example. The initial measurement ran
before inspecting the twin helper's failure and returned twin[None,None,None];
it is not price evidence.

Tried: the initial native suite returned exit 0 after a syntax error omitted one
test. Correcting the missing parenthesis gives all 14 tests passing with no load
errors. The suite checks finite occurrence domains over 32 seeds, ten distribution
moments over 10000 draws each, extreme scales and shapes, parameter refusals before
state changes, early cuts, exceptions, inference cancellation and concurrent
generator replay. Logs: ai-lib4-random-{example-fixed,twin-fixed,measure-fixed,
suite-fixed}.log. No existing library implementation changed.

Verified: all required library lanes pass and jscpd finds zero clones. The full
twins lane gives equal stored contents, all 59 claims and the exact 117876 pin;
UUID, logging and math also retain their pins. The corpus still reports 263
older findings over 302 twins; twins-selftest passes. Logs:
ai-tmp/ai-lib4-random-{lanes,twins-lane,jscpd-final}.log.

## 2026-09-12: statistics design

Decided: fourteen heads cover totals, arithmetic/geometric/harmonic means,
median, individual and partition quantiles, tied modes, variance, deviation,
covariance, Pearson correlation, ranks and affine/proportional regression.
Degrees of freedom is an integer parameter, with N greater than that value.
Ranking both inputs composes Spearman correlation. Tied modes are an answer
stream in first-occurrence order, with terms compared by identity.

Decided: accept finite numeric observations and accumulate their exact stored
values. Exact inputs retain exact arithmetic results; floating observations
select one final binary64 rounding. Deviation and correlation use the existing
fraction square root. Exact moments make N*sum(x*x)-sum(x)^2 safe, as in CPython
statistics._ss at ebf955df7a89ed0c7968f79faec1de49f61ed7cb. Paired moments give
covariance and regression; a squared ratio gives correlation before its root.
Reductions use O(n) arithmetic operations; sorting for ranks, modes and quantiles
uses O(n log n), and a sorted compound indexes k quantiles in O(k).

Rejected: converting variance to float before sqrt. The plain host probe
ai-lib4-statistics-host-magnitudes.log overflows on sqrt(2^2000) and answers zero
for sqrt(2^-2000), though both roots are representable. Revisit only if the host
can preserve the fraction through its final root. Export Vector's existing
fraction_sqrt/2 using the native @private convention already used by metta_text/2;
its implementation and MeTTa surface stay the same. Reprice all affected twins.

Decided: quantiles follow CPython's inclusive and exclusive interpolation, with
explicit method validation even for one observation or one partition. Exclusive
interpolation can extrapolate beyond observed endpoints. Mode alone accepts
held nonnumeric terms. Empty totals are zero; other descriptive statistics need
observations. Affine fits need two observations and nonconstant x; proportional
fits need one observation and nonzero sum of squared x values.

Decided: geometric mean uses floating log/exp precision, summing binary exponents
as integers and native mantissa logs as exact rational images. Split the mean
exponent before exponentiating and round through math-float. Project the
approximation into the observed minimum/maximum interval before rounding, which
preserves the geometric-mean bound and equal-input identity. Validate complete
nonnegative inputs before handling zero for both geometric and harmonic means.
This adapts CPython's geometric_mean log reduction and the standard mantissa/
exponent decomposition; it constructs no product of all observations.

Verified: ai-lib4-statistics-probe.log gives geometric means36 for54,24,36;
one for2^2000 and2^-2000; 1e308 for equal large floats; and the smallest subnormal
for equal smallest subnormals. Vector's roots preserve both extreme magnitudes.
Source: https://github.com/python/cpython/blob/ebf955df7a89ed0c7968f79faec1de49f61ed7cb/Lib/statistics.py.

## 2026-09-12: statistics pricing

Verified: example and twin pass all 76 claims. Three rounds after purging QLFs
give statistics 141717/157714, Vector 58439/62215, math 118986/121599 and
random 122541/117883 inferences (example/twin). The new Vector export moves each
existing twin by seven; numerical implementations and declared MeTTa heads did
not change. Re-pin through the measured tool with that reason.

Tried: keep the geometric mean's huge reciprocal pair inside a built let* term.
The warm probe costs 950 against 1145 for the twin's three calls that name and
reinsert the values. Rejected: changing this one claim to recover 195 inferences;
the small reduction does not justify obscuring the direct Python values. The
twin's complete fn/eval assertions cross results where MeTTa test reads them
inside the engine. Declare its measured 1826 excess over the 1.1 band explicitly.
Logs: ai-lib4-statistics-{measure,crossing-probe}.log.

## 2026-09-12: statistics verification

Tried: the new native test directly called fraction_sqrt/2 without importing it;
the host raised Unknown procedure: plunit_lib_statistics:fraction_sqrt/2. Import
the native provider explicitly in the test too. The tied-mode fixture also left
the documented answer stream's choicepoint open; once now closes its single
answer probes, while findall verifies every tie. All 16 statistics tests pass.

Verified: the Python statistics and Vector files pass 19 tests. Five statistical
properties have generation limits totaling 820 datasets, plus extreme fixtures, comparing
Fraction arithmetic, independently centered moments, exact root midpoint bounds,
CPython quantile interpolation, Decimal geometric means and Counter modes.
The Vector tests also recheck their existing numerical and wire contracts.
Logs: ai-lib4-statistics-{suites-fixed,python}.log.

Verified: the combined statistics, Vector, math and random native suites pass
76 tests and eight subtests with no load errors or warnings. Each suite needs
an explicit -s option: a command with four bare paths loaded only the first
suite and left the other paths in argv. The corrected command and complete
result are ai-lib4-statistics-suites-all.log. jscpd finds zero clones.

Verified: the required library gates pass. Full twins proves all 76 statistics
claims with equal stored contents and the exact 157714 pin. Vector, math and
random also reach their refreshed pins exactly. The corpus result remains
263 pre-existing findings over 303 twins; 47 of 340 files pass, proving all
3234 claims in those files. twins-selftest passes. Logs:
ai-lib4-statistics-{lanes,twins-lane}.log.

## 2026-09-12: HTTP design

Decided: use the host HTTP client and threaded server. A request supplies a
method, URL and structured options; its response carries status, parsed header
fields and bytes. The streaming door substitutes a File handle for the bytes.
Scopes close that handle or stop a server on exhaustion, cut and exception.
UTF-8, JSON and file storage compose their existing libraries.

Decided: pass the calling module and a MeTTa handler as the native server Goal's
arguments. The handler receives (http-request Method Path Target Fields Bytes)
and returns its first (http-response Status Headers Bytes). MeTTa equations
route by method/path. Empty answers produce404; malformed answers become a
host500 response. No handler table, ambient scope key or route language is added.
Start returns (http-server Host Port), with0 requesting a free port; an explicit
URL door formats the endpoint. Stop is idempotent, graceful, and refuses a worker
trying to stop its own server. Native server options control workers and idle
timeouts. Plain HTTP and optional HTTPS client support have separate capabilities.

Decided: HTTP owns framing. Outgoing headers are String pairs and reject control
characters, invalid field names, duplicate single-valued options and user-supplied
framing headers before acquisition. Body options specify bytes and their media
type. Redirects default to false so every HTTP status is an answer; callers can
enable native bounded redirection. Timeouts otherwise keep the host defaults.
Parsed incoming fields use normalized String names and recursively preserve
native numeric, list and compound values. Repeated fields remain repeated;
header lookup enumerates every match. Final server statuses range200..599, and
204,205,304 require an empty body. HEAD exposes an empty body with its metadata.

Rejected: a process-wide http_handler table, because two servers must route the
same path independently. Revisit if a separately requested global router owns
that state. Rejected: reconstructing raw headers by printing native terms;
the provider has already parsed cookies, ports and media preferences. Retain
those structures and describe them instead of claiming the original wire text.

Verified: ai-lib4-http-native-reply-probe.log preserves all256 byte values,
duplicate X-Reply fields, HEAD's256-byte metadata with an empty body and a299
status. Use the native http_reply(bytes(...), Headers) response mechanism;
manual CGI Content-Length produced duplicate framing fields in the first probe.
ai-lib4-http-callback-probe.log evaluates a captured MeTTa equation on a worker
and returns201 with bytes0,128,255. Source:
https://github.com/SWI-Prolog/packages-http/tree/8e6b758778aed1986f81a4a7a8efeb475faa35aa.

Decided: publish File's native stream adoption through @private, keeping one
handle table for HTTP and later socket streams. The forced close race in
ai-lib4-file-close-before.log gives one success and one file-not-found exception
because both callers read the entry before either takes its mutex. Claim the
entry by retracting under the mutex, then close the claimed stream outside it.
Blame assigns the existing race to946e4fca1a, authored MesTTo. Existing File
tests pass49 tests and48 subtests before the change. Reprice affected twins.

Verified: after a server thread alias collision, the host leaves its newly
created worker and queue alive. ai-lib4-http-startup-probe-fixed.log reports
permission_error(create,thread,'http@40769') and one remaining worker. The first
probe used the queue prefix for the thread alias and did not cause a failure;
its result is discarded. Record swi-http-partial-startup with a strict tracked
reproduction. Own the bound socket before starting the server, serialize this
library's lifecycle calls, and roll back that fresh queue on startup failure.
The native server owns successful listeners and workers until stop.

Tried: a lambda first compiled on a server worker printed its compilation trace
to that worker's CGI stream. The host reported Illegal HTTP parameter: --> metta
lambda (lambda_1) -->, and the malformed response left the native client waiting.
The isolated smoke process was terminated after recording the error. Route handler
printing to standard error with the native with_output_to scope; only the returned
response supplies HTTP bytes. This also separates explicit println! calls from
framing. The earlier named-equation probe did not print on its worker.

Decided after the lifecycle review: identify a server by a monotone integer ID
carried in its native Goal, and return (http-server Host Port ID). A stale handle
must not stop a new server that reuses its port. Serialize stop on a mutex named
for that port, independently of the startup mutex. Holding one global lifecycle
mutex while waiting for workers would deadlock a worker starting another server.
The native port registry remains the sole live-server map; no dynamic scope
state is introduced. The damaged smoke process ignored SIGTERM and required
SIGKILL; the corrected smoke returns200 and bytes0,128,255, then stops normally.

Tried: replacing a HEAD response with open_string("") and changing that stream
to binary raised set_stream/2: No permission to encoding stream. Use the native
stream_range_open/3 with size0 over the real response, with its onclose callback
closing the parent. The same ownership rule handles no-content statuses.
The first example also had excess closing parentheses in six refusal claims;
the reader failed before running it. Correct the expressions before rerunning.

Tried: the first Python measurement hung after all request claims passed. A
native wrapper trace in ai-lib4-http-load-probe-mailbox.log rules out a source
transaction: both stops report TRANSACTIONS []. The first stop takes the host's
timeout-and-connect branch and leaves http_stopped in the caller mailbox. The
second consumes that stale acknowledgement, skips its wake-up connection and
joins an accept thread still blocked in tcp_accept/3. The original measurement
was aborted with exit137 after this diagnosis; it supplies no price.

Decided: give each native stop its own short-lived thread and await its completion
in cleanup. Its untagged acknowledgements cannot contaminate the caller's mailbox
or another stop. Do not drain the caller's messages, which might belong to an
unrelated native operation. Record swi-http-stop-ack with a real-server fixture
that forces the first acknowledgement wait to take its timeout branch.

Verified: the revised Python source load finishes39 claims and both stops leave
its mailbox empty. The first completed three-round measurement reports321151
twin inferences against325873 example inferences. This price precedes the two
transaction refusal claims added below. Eighteen of the first20 native tests
pass, including all256 byte values and a method/length cross-product, parsed
cookies, streaming cleanup and concurrent close. The capability test mistakenly
expected a scalar source where the census correctly declares a dependency list.

Decided: start and stop refuse inside a transaction before acquiring any resource.
lib_thread already refuses scopes and database-backed waits for the same reason:
the caller snapshot cannot share lifecycle changes with workers. The regression
initially reached an injected listener_was_entered instead of refusing, and a
stop returned normally. Add both public refusal claims and remeasure HTTP.

Verified: the final example and twin pass41 claims. Three fresh measurements
after QLF purge give324057 twin inferences against328687 for the example.
All22 HTTP tests and49 File tests pass, with48 File subtests. The suite also
proves a TLS request refuses a plaintext listener and that a worker can start
a second server while another thread stops its first server. There are no load
errors or warnings. Logs: ai-lib4-http-{example-transaction,twin-transaction,
measure-final,suites}.log. jscpd reports zero clones before the last two tests.

Verified: re-pricing File's six shipped-library consumers moves text to140583,
JSON to151596, crypto to151623, CSV to188422, File to209603 and YAML to179426.
Their stored-content comparison remains unchanged. The same command refused
HTTP's provisional price because its block was above the function; move that
block to the end and replace it with the final measurement above. The refusal
and six successful pin updates are in ai-lib4-http-repin.log.

## 2026-09-13: HTTP notation and final gates

Verified: every required library gate, including both host-workarounds lanes,
passes. The first full twins run reports281 findings. Twelve belong to HTTP:
eleven route strings were wrapped only after assignment rather than at their
data boundary, and a stored let used MeTTa's assignment spelling. Six belong
to previously passing File consumers whose import or close now costs more.
The remaining263 are the prior corpus findings. Logs: ai-lib4-http-{lanes,
twins-lane,new-findings}.log.

Decided: make each route literal ground data at its definition. Let the scoped
server callback return its whole response and project the status in the claim,
preserving metadata and removing the redundant inner destructuring. Both
examples still prove41 claims. Three rounds give323580 twin inferences against
328540 for the example, superseding the earlier HTTP price. The six additional
File consumers are being remeasured; native source remains unchanged.

Verified: all twelve File consumers have fresh prices. The final twins lane
reports equal HTTP contents,41 claims and exactly323580 inferences. Its263
findings are the existing corpus findings;48/341 files pass and3275 claims
are proved. twins-selftest passes. All19 required library gate summaries pass,
including both host-workarounds lanes. Logs: ai-lib4-http-{repin-additional,
lanes-final,twins-final}.log. The combined native suite passes71 tests and48
subtests; jscpd finds zero clones. No scope value requires a trailed-key merge.

## 2026-09-13: URI design

Tried: installed library(uri) against empty delimiters, URNs, userinfo and an
authority-only base. uri_components loses '?'; uri_resolve(g,'http://a',R)
returns http://a; resolving urn:Example:ABC returns urn:. uri_normalized
lowercases User:Pass and the URN namespace-specific string. Percent normalization
rewrites %FF to%C3%BF and an overlong UTF8 slash to a literal slash. Commands
and outputs: ai-lib4-uri-probe.pl, ai-lib4-uri-{probe,normalize-probe}.log.

Rejected: direct native component, normalization and resolution wrappers,
because their returned values lose case-sensitive or structural data. Revisit
when the tracked swi-uri-reference-loss reproduction prints absent. Native
percent encoding is correct across its four contexts, Unicode and NUL.

Decided: use RFC3986 AppendixB and sections5.2/5.3 for generic components and
resolution. Represent optional components as omitted String-key rows; an empty
String retains its delimiter. Keep authorities encoded and paths generic,
including URNs. Normalize only unreserved percent bytes and ASCII scheme/host
case; leave userinfo and reserved bytes intact. Relative paths retain dot
segments until resolution supplies a base. A reversed output stack gives dot
removal linear work over consumed characters, including parent segments.

Decided: expose the native four encoding contexts; strict decoding combines
percent octets with lib_encoding's verified UTF8 codec. Query pairs keep order,
duplicates and blank values. Their uri/form argument controls only plus-space
convention, following CPython v3.14.0 parse_qsl with keep_blank_values=True;
empty segments are ignored and bare keys become empty-valued. References use
ASCII URI spelling; percent encoding supplies Unicode data. Authorities remain
encoded data and are not a DNS or address validator. These nine heads require
the native URI capability, no resource registry and no scoped global value.

Verified: native smoke checks retain empty delimiters, opaque URNs, an empty
port spelling and strict decoded NUL; an authority-only base resolves g to/g.
The first executable example stopped at its NUL fixture: the reader interprets
the unrecognized backslash-u escape as literal u0000. Construct that String
through the existing utf8-decode byte door. The library's native NUL handling
was unchanged. Logs: ai-lib4-uri-{native-smoke,example}.log.

Decided: track four independent host defects with separate reproductions:
swi-uri-empty-query, swi-uri-empty-base-path, swi-uri-urn-resolution and
swi-uri-normalization-data. These replace the provisional combined key above.

Verified: the example and twin pass55 claims. Three fresh measurements give
118602 twin inferences against125852 for the example. All four independent
host reproductions print present. Initial native tests pass every RFC3986
resolution fixture; test defects were a missing parenthesis in the generated
case fixture, a hex-width field that counted the preceding percent character,
and an attempted surrogate String that the host refuses to construct. Fix the
fixtures; malformed UTF8 already tests surrogate rejection at the public door.
No library code changed. Logs: ai-lib4-uri-{twin,measure,host-reproductions,suite}.log.

Verified: all12 native tests pass. They include all42 RFC3986 resolution cases,
576 component combinations, all256 percent octets,84 scalar/context cases and
1002 generated Unicode query relations. No load warnings or errors remain.
The dot-removal fixture uses193760 inferences for1500 segment/parent pairs and
387260 for3000, consistent with the linear stack design. Exact command and
results are in ai-lib4-uri-suite-fixed.log. All record generators pass; jscpd
reports zero clones. URI owns no handles and adds no scoped state.

Verified: all19 required library gate summaries pass. The full twins run
reports305 findings:42 are ungrounded String literals in URI's expected values,
and263 are the existing corpus findings. Compare the returned typed expressions
directly against typed expected pairs. The corrected twin passes55 claims,
has equal stored contents and retains118602 inferences over three fresh rounds.
Its targeted lane reports zero findings. Logs: ai-lib4-uri-{lanes,twins-lane,
twin-grounded,measure-grounded,twin-targeted}.log.

Verified: the final full twins run retains263 existing findings over305 twins.
URI proves55 claims with equal stored contents and exactly118602 inferences;
49/342 corpus examples pass and3330 claims are proved. twins-selftest, Ruff,
mypy and evidence pass. Logs: ai-lib4-uri-{twins-final,notation-lanes}.log.

## 2026-09-13: socket design

Tried: library(socket) loopback streams preserve binary bytes and accept File's
stream operations. Native UDP receive aborts on IPv6 at socket.c:unify_address,
which handles only AF_INET. The isolated probe exits134 after its own datagram
arrives; IPv4 controls pass. Logs: ai-lib4-socket-{probe,udp6-probe}.log.

Rejected: restricting UDP to IPv4, because the repository's existing native
adapter builder permits a complete address-family repair. A second socket
registry would duplicate File ownership. Native tcp_accept reports no peer port;
recording zero or inferring it from the listening port would invent an endpoint.

Tried: a scratch adapter using PL_get_stream, Sfileno, getsockname, getnameinfo
and recvmsg. Both address families preserve zero/255 and empty datagrams;
wait_for_input returns the same stream-pair identity and a waiting thread exits
with exception(cancelled). Compile with swipl-ld -shared -Wall -Wextra -Werror.
Commands and fixtures: ai-lib4-socket-fli-probe.{c,pl}, its .log.

Decided: share File's integer handles and expose its existing known_file/2 as
a private borrowing door. TCP connect/listen/accept and UDP bind transfer owned
streams to File; file-close! and byte I/O retain their contracts. Endpoint values
are (endpoint ipv4|ipv6 HostString Port), with the actual local or peer address
queried from the locked descriptor. Port zero asks the OS to bind; destinations
require a positive port. Hostnames resolve through the requested native family.

Decided: a small adapter built by native_build supplies kind, endpoint, shutdown
and complete datagram receive. POSIX recvmsg reports truncation; Windows recvfrom
reports WSAEMSGSIZE. UDP streams are nonblocking before publication, and receive
retries only after native readiness, keeping cancellation outside a blocking
foreign call. A packet larger than the ordinary UDP bound raises, never truncates.
The native provider still creates sockets, connects, listens, accepts and sends.

Decided: socket-wait! preserves supplied handle order and duplicates; an empty
list returns immediately. Its timeout is nonnegative seconds or infinite.
socket-shutdown! accepts read/write/both and retains the descriptor until close;
write shutdown flushes pending output. with-socket holds an acquisition expression
and a function, transfers the first acquired socket into its scope, streams all
function answers, and closes on every exit. Handles and callbacks travel as
arguments. Opening sockets refuses database transactions before effects because
File's registration must survive until explicit release. No new global scope key.

Verified: the native adapter compiles with -Wall -Wextra -Werror and the first
example passes53 claims. The twin initially returns only second for its callback:
the Python write door replaces a repeated equation head. A direct callback
probe gives the same result before any socket scope runs. Use one superpose
equation in both notations to describe the two answers. The library is unchanged.
Logs: ai-lib4-socket-{native-build,example,twin,scope-probe}.log.

Verified: the initial write-replacement attribution was insufficient. The stored
superpose equation is intact, but first has type (-> %Undefined% Atom), while
second is untyped. Returning that function name under a Symbol result filters
it out. Numeric controls and fresh Symbol controls each return both answers,
directly and through with-socket. Use Number results1/2 for the scope fixture.
The final example and twin pass53 claims. Logs: ai-lib4-socket-{scope-types-probe,
example-numeric,twin-numeric}.log.

Decided: index the native ready set with library(assoc) before restoring input
order and duplicates. This avoids a quadratic membership scan when many sockets
are ready; the transformation costs O(k log k + n log k) for n handles and k
distinct ready streams. The native readiness operation remains the I/O authority.

Tried: the19-test socket suite passes18 tests and exposes a cancellation gap
after adopt_file_stream returns. The stream closes, but its registered handle
remains: socket_adopt_cancelled leaves handle39 in the table. The same outer
handover exists in HTTP. Log: ai-lib4-socket-suite.log.

Decided: File owns release_file_stream/1 for rollback before publication, both
before and after adoption. Socket and HTTP use that one withdrawal/close path.
HTTP acquires its final response stream in Setup, including the no-body range
filter, so cleanup retains its identity after an exception unwinds body bindings.
Add HTTP get/head cancellation cases and remeasure all affected File consumers.

Tried: the combined Socket/HTTP/File suite reaches a blocked IPv6 accept with
its cancellation pending. /proc/1110743/task shows inet_csk_accept; the only
owned listening endpoint is ::1:44843. A diagnostic connection wakes it and
allows cleanup. All91 tests and48 subtests then finish, but this assisted run
is not a passing cancellation gate. Logs: ai-lib4-socket-{suite-process,
suite-listener,suite-wake,suites-owned}.log.

Found: sig_atomic/1 documentation explicitly includes setup_call_cleanup Setup.
The blocking native accept currently runs there, so cancellation is deferred.
The native nonblock accept still retries internally; waiting for readiness first
does not settle races between acceptors. Research the acquisition protocol before
changing it. No host-defect label applies to the documented atomic Setup rule.

## 2026-09-13 socket acquisition ownership

Verified: opening a native binary stream before tcp_connect/2 works for IPv4
and IPv6. A scratch one-shot accept adapter using public Snew stream callbacks
passes bidirectional bytes, cancelled reads and shared owner-cell identity.
Logs: ai-lib4-socket-{connect-owned-probe,accept-probe,accept-probe-build}.log.
The independent File/HTTP repair passes72 tests and48 subtests in
ai-lib4-socket-http-file-owned.log.

Rejected: completion cleanup as the first owner of an acquisition result.
Exceptions unwind its ordinary variables, and generic acquisition can run more
goals before returning. Revisit only if an owner already retains the resource.
Rejected: an infinite readiness wait as the sole cancellation mechanism. Native
clib itself checks signals between250ms waits. A finite check interval also
observes cancellation that arrived immediately before the next wait.

Decided: install an empty native accept owner before attempting accept. The
foreign call records its descriptor immediately and roots each constructed
stream. Publication retains the final stream before File adoption. Rollback
withdraws any File registration and closes both halves before releasing the
owner. A successful handover leaves the stream halves as the descriptor owners.
The native owner handles partial construction and foreign-output failures.

Decided: the listener stays nonblocking; a losing acceptor returns to readiness.
Accepted sockets use separate input/output Snew streams and shared reference
counting. Public File byte operations retain their existing interface. Native
socket callbacks are not interchangeable with clib's private callback identity.
The OS and public SWI interfaces are the basis:
https://man7.org/linux/man-pages/man2/accept.2.html,
https://www.swi-prolog.org/pldoc/man?section=foreign-create-iostream,
and packages-clib a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da/sockcommon.c.

Decided: evaluate with-socket acquisition in guarded Goal. During that evaluation,
one thread-local key, '$metta_socket_acquisition', exposes a call-local allocation
set to socket publication. Failure closes the allocations; successful selection
transfers the first returned handle into the callback scope. Restore the previous
key before invoking the callback and on every exit. No database or global value
write occurs in Setup. The integrator converts this key to metta_with_trailed/3
and seam:context_reader/3, which this branch predates.

Decided: exception cleanup shuts down TCP before closing buffered streams, so
unwind does not wait for peer cooperation. Normal close retains File's flush
semantics. Owners keep listeners alive until their acceptors are cancelled and
joined. Windows uses its socket-width descriptor and clears inherited event
selection on accepted sockets; platform runtime verification here is Linux.

Tried: the first native ownership build names Sacquire/Srelease, which are not
declared by the installed public headers. Compilation refuses both implicit
declarations. Use rooted stream blobs and PL_get_stream_from_blob for rollback;
Sclose consumes its borrowed stream lock. The corrected build passes all
warnings as errors. Logs: ai-lib4-socket-owned-native-build{,-fixed}.log.

Tried: the concurrent accept fixture waits for a message after an unevaluated
lambda makes its worker fail. The isolated fixture probe prints
callback [[[lambda,_32678,true],3]], and the peer has already closed. The runner
has no remaining producer for the expected completion message; it was terminated
with exit143, not accepted as a gate. Use the registered native callback and
always report worker completion, including failure. Log:
ai-lib4-socket-suite-owned-barriers.log; probe:
ai-lib4-socket-accept-fixture-probe.log.

Found: aborting a scope with pending buffered output releases the descriptor,
but SWI prioritises close's io_error over the callback's atom exception. Preserve
the original outcome and all failed handles in socket_cleanup(Outcome,Failures),
after attempting every close. The corrected combined suite passes99 tests and
48 subtests, including actual empty-wait barriers, competing acceptors, nested
acquisition, partial native publication, module capture and buffered cleanup.
Logs: ai-lib4-socket-suites-{buffered,cleanup-errors}.log.

Verified: native TCP accept returns ip(0,0,0,0) for an IPv6 loopback peer while
the IPv4 control passes. The tracked swi-tcp-ipv6-peer reproduction prints
present; the endpoint adapter and ledger record the complete-address repair.
The UDP IPv6 reproduction separately prints present for its native assertion.

Verified: the final example and twin each pass53 claims. Three fresh serial
measurements give example189530 and twin178533, within the existing allowance.
All13 older File consumers are remeasured and repinned; HTTP moves323580 to
323706. Commands and every point are in ai-lib4-socket-price-owned.sh and
ai-lib4-socket-{measure-owned,repin-file-consumers}.log. The five record generators
pass in ai-lib4-socket-records-owned.log.

Verified: ordinary collapse lowers to findall in
engine/translator/special_forms.pl:translate_special_dl/5. A failed acquisition
after collecting a socket closes that socket and the two later allocations.
The27-test socket suite passes in ai-lib4-socket-suite-collected.log. Separate
cursors and worker tasks keep their own allocation responsibility; this scope's
call-local cell is not claimed to be shared across copied engine contexts.

Tried: the required lane batch passed18 of19 lanes; evidence mistook the new
reproduction helper child/0 for the word child in an existing Node test title.
Renaming the helper udp_reproduction_child/0 removes that collision. Evidence,
host-workarounds and its selftest then pass; all27 reproductions answer present.
Logs: ai-lib4-socket-{lanes,evidence-final}.log.

Verified: the final Socket suite passes27 tests in
ai-lib4-socket-suite-reaping.log. Full twins retains263 older findings over306
twins, with equal Socket contents and178534 inferences against its178533 pin,
inside the gate's existing deterministic allowance of4. All13 repriced File
consumers pass their price checks. The twins selftest passes. Log:
ai-lib4-socket-twins-final.log.

## 2026-09-13: compression and archive design

Tried: native zopen rejects truncated gzip/zlib input, bad checksums and trailing
junk; complete concatenated members produce concatenated bytes. Binary memory
streams preserve all256 octets. Commands and fixtures:
ai-lib4-compression-{read,memory}-probe.pl and their logs.

Tried: libarchive accepts gzip with a corrupt trailer, including gzip inside
bzip2 or xz. Its consume_trailer still omits CRC and size verification at
libarchive commit c719b9b1f56621d92063a85361cc8d114f5575a9. Wrapping a live
zopen stream in archive then loses the original read error and reports
"foreign predicate archive:archive_close/1 did not clear exception". Logs:
ai-lib4-compression-{read-default,layer-probe}.log.

Rejected: relying on libarchive's gzip filter or passing a failing zopen stream
through its callbacks. Revisit when both tracked reproductions answer absent.
Decided: detect gzip anywhere in the native filter chain, decode that chain
through owned intermediate files, and run zopen for every gzip layer. Other
layers use the native raw reader with gzip excluded from its declared filter
catalog. Close each decoder before another archive reader opens. Delete each
consumed intermediate; only adjacent layer files coexist. The final file is
seekable, preserving archive formats that require seeking. Gzip-free archives
use the native reader directly. The passing file-layer probe covers gzip,
bzip2/gzip, xz/gzip and an additional outer gzip, including bad inner trailers:
ai-lib4-compression-layer-files-probe.pl and its log.

Decided: eight heads cover the format roster, parametrized byte/file compression
and decompression, archive metadata, ordinal entry reads and extraction. Byte
forms own memory/decoder streams; file replacements reuse File's staged writer.
Expose metta_staged_publish/2 privately with its callback qualification. A native
fold over ordinal entries shares traversal and stream ownership across all three
archive operations. Duplicate names remain distinct in metadata and ordinal
reads. Inputs are stable archive files during a call; no reader promises a
snapshot against concurrent file modification.

Decided: extraction publishes regular files and directories into a missing or
empty destination directory. It refuses links, unknown types and special files;
the native metadata remains available for inspection. Native hardlinks report
filetype(0) and no target, so treating them as empty files would lose data.
No ownership, modes or times are restored. Reject file duplicates and file/tree
collisions; repeated directories and ./ root directory headers remain valid.

Decided: extraction accepts portable relative names. Reject parent segments,
absolute paths, backslashes, colon/ADS, control characters, trailing dots/spaces
and reserved Windows device components, including their extensions and
superscript digits. Normalize only empty and dot components. A new staging tree
contains no preexisting links. The path rules follow Microsoft's FileIO naming
specification at63e70903d18b0637e62ffab6656c4a388ef0f2ce and CPython's data
filter checks at v3.13.7, Lib/tarfile.py:_get_filtered_attrs. The extraction
policy preserves data only and refuses unsupported filesystem entities explicitly.

## 2026-09-13: compression verification

Corrected: the first native archive probe explicitly enabled raw. Default
formats(all) excludes raw, as the provider's enable_type bit check and
ai-lib4-compression-read-default.log establish. No raw-format repair is needed.

Tried: the input-error reproduction first used 32768 identical bytes. Archive
bidding consumed that short compressed input before the intended cleanup path,
producing unexpected_archive_input_result(error(archive_error(-30,fatal),_)).
The cyclic octet fixture reaches the entry read and cleanup. Both independent
host reproductions now print present; logs are
ai-lib4-compression-{input,trailer}-reproduction-cycle.log.

Measured: the 51-claim example and Python twin pass with equal expected values.
Three-round minima are 209206 and 189939 inferences, respectively. File's private
export/meta declaration changes fourteen existing consumers, all remeasured by
ai-lib4-compression-price.sh. Logs: ai-lib4-compression-{measure,
repin-file-consumers,example,twin}.log.

Tried: the first combined native command loaded suites from the repository root
and put the new module imports before File's consult initializers. Module
redefinition and consequent missing predicates made that command invalid. The
prescribed tests/prolog working directory and File-first loading pass. Two new
assertions also expected error/2 where File publishes publication_refused/2.
Python refusals return EngineError for these native errors; the initial suite
incorrectly required the narrower MettaOperationError. Corrected assertions
preserve the expected error reason rather than changing the implementation.

Verified: 65 native tests and 48 subcases pass for File and Compression in
ai-lib4-compression-suites-corrected.log. The 16 Compression cases cover all
octets/levels, 256 generated round trips, every truncated member prefix,
concatenation, publication, paths/kinds/collisions, seekable ZIP/7zip wrappers,
visitor errors and cancellation after stream acquisition. The 43 Python cases
pass in ai-lib4-compression-python-corrected.log, including Hypothesis byte
interoperability, independent TAR/ZIP writers and twelve nested-filter cases.

Observed: this SWI build reads TMP, not TMPDIR, for tmp_dir. Export TMP and TEMP
alongside TMPDIR for subsequent direct runners, matching check.sh's environment.
The native probe prints the requested project directory after that export;
temporary names alone never justify changing File's system-temp policy.

## 2026-09-13: archive names under a C locale

Tried: LC_ALL=C PYTHONCOERCECLOCALE=0 PYTHONUTF8=1 with the two Unicode archive
tests fails for both TAR and ZIP. The host raises archive_error(84, ...) because
the pathname cannot be converted from UTF8 to the current locale. Receipt:
ai-lib4-compression-python-c-locale.log. This newly tested environment invalidates
the assumption that native archive name conversion is independent of locale.

Source: packages-archive archive_next_header at
13a3f4af8f8219e10faf4895ce9fb189bc6aaefd rejects libarchive's conversion warning
before calling archive_entry_pathname_w. No reader character-set option is
exposed by that provider. SWI's locale_create only reads numeric conventions;
it does not establish a native character-decoding context.

Tried: a public-FLI callback inside newlocale/uselocale reads both Unicode
archives, preserves bytes, supports nesting and restores the C locale after
success, failure and exception. ai-lib4-compression-locale-probe.log prints
ANSI_X3.4-1968 before, UTF-8 inside and restored after. The adapter compiles with
-Wall -Wextra -Werror. The successful mechanism follows mpv's archive wrapper,
stream/stream_libarchive.c at14f2d48cbc7dda61adb4bd181e107a1f3f76e533.

Rejected: changing the process-wide locale, or inheriting an arbitrary locale
after a failed UTF8 selection. The former changes other threads; the latter
retains the demonstrated defect. Revisit only when the native reader itself
handles Unicode names under C, as the tracked reproduction must establish.

Decided: wrap the one shared archive operation in a native, single-answer UTF8
call. POSIX duplicates the calling thread's locale and changes only LC_CTYPE;
Windows enables per-thread locale changes and restores its previous mode and
LC_CTYPE. macOS names that character locale UTF-8; other POSIX builds require
C.UTF-8, and Windows UCRT uses .UTF8. A missing locale is a named refusal.
The callback closes all archives and streams before its C frame restores the
locale. No Prolog registry or scoped key is introduced. Runtime evidence here
is Linux; the other native branches require verification on their platforms.

Sources: POSIX Issue8 uselocale and newlocale specify thread ownership and
category inheritance; Microsoft's setlocale-wsetlocale and configthreadlocale
references specify UCRT UTF8 and per-thread restoration. The existing shared
native builder owns compilation, locking and atomic publication.

Tried: declaring meta_predicate before loading the foreign definition leaves
its mode metadata but loses module transparency. The archive suite then raises
"Unknown procedure: lib_compression_native:archive_file_utf8/4". Register the
callback with PL_FA_META and the "0" template, as SWI's foreign reference
specifies, so the FLI declaration supplies both metadata and transparency.
Receipts: ai-lib4-compression-{suites-locale-fixed,python-c-locale-fixed}.log.
The loaded archive_version_string reports libarchive3.8.5.

Verified: PL_FA_META plus PL_strip_module preserve the callback's defining
module. File and Compression pass all65 tests and48 subcases in
ai-lib4-compression-suites-locale-meta.log. All44 Python tests pass under C
in ai-lib4-compression-python-c-locale-meta.log. The locale test reads UTF8
inside nested callbacks while setlocale's process query remains unchanged,
and checks restoration after success, failure and a propagated exception.
The new host reproduction prints present in
ai-lib4-compression-locale-reproduction.log. The final C source compiles with
-Wall -Wextra -Werror in ai-lib4-compression-locale-build-final.log.

## 2026-09-13: ZIP names and native ownership

Tried: a valid unflagged ZIP name caf\x82 crashes archive_next_header in SWI's
wide-string call. The native libarchive call returns ARCHIVE_OK but its wide
pathname is NULL. Explicit ZIP hdrcharset=CP437 produces café and retains the
UTF8 flag control. Sources: PKWARE APPNOTE6.3.10, D.1-D.2; libarchive3.8.5
archive_read_support_format_zip.c atdd897a78c662a2c7a003e7ec158cea7909557bee.
Receipts: ai-lib4-compression-{python-final,legacy-probe,charset-unicode-control}.log.

Decided: keep a private copy of packages-archive's binding, with its own blob
type and registration module. Refuse NULL before PL_unify_wchars. Allocate an
empty archive owner before opening its parent reader; cleanup then includes
partial acquisition, errors and failure. Parent file ownership remains in its
enclosing Prolog scope. The binding's original stream protocol and parsers stay
in use. The independent charset and crash reproductions both print present.
File and Compression pass66 native tests and48 subcases, including failed
acquisition, borrowed-stream usability and callback failure/exception. Receipts:
ai-lib4-compression-{charset-reproduction,null-reproduction,suites-private}.log.

Tried: the49-case Python run under C passes48 but reveals an incorrect oracle
expectation. Python3.14 honors a valid Unicode extra field; after correcting the
expectation, native output still differs. The same fixture through ctypes reads
café/π🙂 with default options and café with hdrcharset=CP437. Libarchive computes
the extra field's filename CRC after converting CP437 to UTF8, so it compares
different bytes with the stored CRC and ignores a valid field. The current
upstream source atc719b9b1f56621d92063a85361cc8d114f5575a9 has the same code.
Receipts: ai-lib4-compression-{python-private,python-private-final,
unicode-extra-probe}.log.

Rejected: disabling CRC checks, because that also disables payload verification
and admits stale Unicode extra fields. Rejected: a second pathname parser in the
binding, because the public header position is not a reliable raw ZIP header
location around skipped data and seeking. The position probe reports0,32,68,113
for the seekable fixture and0,34,70,119 through bzip2. Revisit if the provider
exposes original filename bytes, encoding flags and extra fields together.

Decided: correct the CRC at its source in a private build of the pinned native
provider. Save the original filename CRC before character conversion and use it
for the extra-field check. Preserve the provider's parsers and payload checks.
The shared atomic native builder will own the final object; a qualified build
callback permits CMake to supply this multi-source compiler job under the same
locking, cancellation and publication protocol. Source configuration/build and
the corrected UTF8 extra-field fixture are being checked before that integration.

## 2026-09-13: private archive provider verification

Verified: the corrected provider preserves CP437 names, UTF8 flags and valid
Unicode extra fields, while rejecting stale fields through the provider's CRC
rule. All 53 Python compression cases pass under LC_ALL=C, including Hypothesis
byte round trips and the filename cross-product. File and Compression pass
66 native tests and 48 subcases. Receipts: ai-lib4-compression-python-source-provider.log
and ai-lib4-compression-suites-source-provider.log.

Verified: the native object exports only install_lib_compression and does not
link the system libarchive. The source archive and wheel carry every provider
input; a fresh wheel installation builds and executes the native libraries and
the Unicode extra-field fixture. Command: CHECK_PY=/home/user/Dev/.venv-pypetta/bin/python
sh extensions/python/test.sh tests/ch08_data/test_library_native_build.py
-k test_native_sources_build_after_wheel_install. Result: one passing test.
Receipts: ai-lib4-compression-{native-exports,native-links,wheel}.log.

Tried: the 18 build tests passed their acquisition, concurrency, cancellation,
warm-cache and dependency checks, but three final directory assertions assumed
build.lock sorted before every object filename. archive_locale sorts first.
Use exact set equality for the same two entries. The original run has 15 passes;
the three corrected cases all pass in ai-lib4-compression-native-build-tests-fixed.log.

Measured: the final 54-claim example costs 229505 inferences and its twin 204350,
the minimum of three serial fresh processes after engine/lib QLF removal.
This supersedes the earlier 51-claim price. Receipt:
ai-lib4-compression-measure-source-provider.log. Native builder consumers are
remeasured after the shared callback addition; source and recipe evidence pins
advance with the same verified dependency state.

Verified: all 22 priced consumers of File and the shared native builder were
remeasured over three rounds. Their stored contents remain unchanged; the
inference increase is 530..533, mostly 531, from loading the updated builder.
Receipt: ai-lib4-compression-repin-native-consumers.log. The File/Socket consumer
suite also passes 76 tests and 48 subcases after that dependency change in
ai-lib4-compression-socket-consumer-suite.log.

## 2026-09-13: native source isolation and CMake evidence

Tried: the required library batch passed 17 lanes and failed Ruff plus
lib-autoload. Ruff requires raw regex literals in two pytest match arguments.
Lib-autoload reported all ten Socket native predicates missing. Removing QLF
artifacts preserved that failure, and the loaded foreign-library list contained
Compression but no Socket object. A four-file SWI-only probe loaded only the
first native provider when both imports used compound support/native. Quoted
pathname atoms loaded both providers. Receipts: ai-lib4-compression-{lanes,
autoload-source-only,autoload-owners-cwd,compound-load-host,atom-load-host}.log.

Decided: use quoted relative pathname atoms in both libraries. SWI's
boot/init.pl:$register_resolved_source_path/2 caches every compound specification
by specification and dialect, omitting the importing directory. Record the
host defect as swi-relative-compound-source, with independent atom controls.
Reprice Compression and Socket after their import changes.

Tried: pin_provenance --check found five files outside its evidence globs:
the CMake recipe, provider configuration header and three nested host helpers.
Extend the existing source classes and recognize CMake's actual comments,
consuming quoted, bracket and escaped unquoted arguments first. The token
productions follow CMake 3.18's cmListFileLexer.in.l; bracket length remains
unbounded. The selftest passes 71 placeholders in 26 files, 69 C-family and
110 CMake lexical cases, plus eight refusals before any file is written.
Ruff, evidence, evidence-selftest and provenance-pin-selftest pass in
ai-lib4-compression-cmake-gates.log.

Verified: git diff --check reports only inherited space-before-tab indentation
in archive.h and archive_read_support_format_zip.c. Preserve those upstream
source lines and the header checksum. Receipt: ai-lib4-compression-diff-check.log.

Verified: the isolated relative-source reproduction prints atom=[a,b],
compound=[a], then present. The repaired lib-autoload lane passes over 46
Prolog files and 457 published heads. File, Compression and Socket loaded
together pass 93 native tests and 48 subcases; all 53 Compression Python
cases pass under C. Receipts: ai-lib4-compression-{relative-source-reproduction,
autoload-isolation,suites-isolation,python-isolation}.log.

Measured: after the import correction, Compression's 54-claim example/twin
costs 229506/204351 inferences and Socket costs 190074/179079, minimums of
three serial fresh processes after QLF removal. The Compression header now
carries this final point; Socket's existing point is unchanged. Receipt:
ai-lib4-compression-measure-isolation.log.

## 2026-09-13: Compression row complete

Verified: all19 required library lanes pass in ai-lib4-compression-lanes-final.log.
The host lane confirms34 ledger entries and42 sites, with every reproduction
answering present. The first full twin run identified two missed transitive
String consumers, Dict and Reflect, each531 inferences above its point.
Three-round measurements repin them to167440 and194191. This brings the
native/File consumer set to24. Receipt:
ai-lib4-compression-repin-indirect-consumers.log.

Verified: the repeated full twin lane retains263 older findings over307 twins;
51 of344 examples pass all twin checks and3437 claims are proved. Compression
has54 matching claims, equal stored contents and the exact204351 point against
229506. All24 affected consumers pass. Ruff, evidence and twins-selftest pass
in the same run. Receipt: ai-lib4-compression-twins-repinned.log.

## 2026-09-13: Database ownership and design

Goal: independent persistent stores with add, one-occurrence removal, pattern
queries, synchronization, close and reopening through MeTTa and Python.

Tried: native persistency keeps a newly asserted fact in memory after its
journal append fails. Unknown journal actions print an error and replay
continues. A failed db_detach close leaves file/options registration behind;
its next detach removes that bookkeeping. Receipts:
ai-lib4-database-{host,detach}-probe.log.

Tried: engine_post/3 serialized 400 request/reply pairs across four threads.
An engine owns its temporary schema and attachment through ordinary cleanup.
Its garbage collection runs cleanup on a native reaper, so the probe waits
for that cleanup's message. Loading a non-module source preserves the module's
temporary class, and unloading its source removes persistency's external
schema clauses. A module/2 directive changed the class and prevented module
destruction. Receipt: ai-lib4-database-engine-gc-probe.log.

Decided: one anonymous engine owns each store, with state passed as arguments.
Requests use the engine's native serialization. Close is a final request whose
answer arrives after cleanup; the completed handle remains safe for callers
already waiting. The protocol-close probe passes 1600 competing calls.
Use engine_destroy only while an acquisition is unpublished. A native handle
already crosses Python's generic blob wire and retains identity; ordinary,
numeric and sequence-pattern queries pass through that existing bridge.
Receipts: ai-lib4-database-{close,surface-opaque}-probe.log.

Rejected: a transaction around native persistency writes. It rolls back the
stream registration as well as memory, while the acquired stream remains an
external resource. A write or sync error instead ends the engine and its
attachment, so callers cannot observe the host's partially updated memory.
Opening validates the entire journal and refuses malformed or unsupported
records. No tail is trimmed automatically and flushing is not an fsync claim.

Tried: native lock(write) admits two descriptors in one process. A stream-owned
flock refuses another descriptor, hard link, thread and process; close releases
the claim. Locking the journal itself would conflict with later journal handles
on Windows and hosts where flock and fcntl interact. Receipt:
ai-lib4-database-lock-complete-probe.log.

Decided: a store is a directory containing journal.pl and a permanent lock file.
This follows LMDB's default environment representation at
700e10f91a65fae69520301926fb9819f16d292f, libraries/liblmdb/lmdb.h:605..636.
Directory aliases reach the same physical lock. POSIX uses flock; Windows uses
LockFileEx on the separate lock stream. Streams own those OS claims and the
shared native builder owns compilation. Runtime evidence is Linux; the Windows
branch follows MicrosoftDocs/sdk-api at 554e06be52a53ae819b1011353303a6c72fbdb5d,
sdk-api-src/content/fileapi/nf-fileapi-lockfileex.md. The store's directory and
contents remain exclusively managed through this API while it is open.

Decided: seven heads, database-open!, database-query, database-add!,
database-remove!, database-sync!, database-close! and with-database. The scope
takes Directory, Sync and a held function, so it owns creation directly.
Sync uses the existing journal-sync vocabulary. Stored values are ground
native Symbols, Strings, Numbers and proper expression lists. Query takes a
held pattern/template and applies the core matcher to one stored value at a
time; it retains insertion order, duplicates, numeric promotion and sequence
patterns. Removal deletes one exactly equal stored value. Queries collect a
snapshot in memory; persistent writes remain independent of caller backtracking
and in-memory transactions.

Decided: defer quasi-quotation handlers during journal validation, then reject
their syntax. Distinguish actual EOF from a literal end_of_file term through
the reader's end-of-stream state. Reject invalid records before native replay.
The reader probe checks both controls in ai-lib4-database-reader-probe.log.
Native floating infinities, NaN, signed zero and rationals round-trip through
the provider's writer/reader in ai-lib4-database-numeric-probe.log.

### Database cancellation ownership

Tried: interrupt persistency:db_open_file/3 after opening and before its caller
registers db_stream/2. The operation raised database_stream_cancelled, but one
journal stream remained open after the store ended. Receipt:
ai-lib4-database-stream-probe.log. This invalidates relying on db_detach alone
to finish journal ownership.

Decided: the exclusive store owner also closes open streams naming its journal
after native detach, including streams whose registration was interrupted.
The permanent directory lock prevents another API owner from opening that
journal concurrently. Reuse owned_resources:with_outcome_cleanup/3 so an
operation error survives alongside detach and stream-close errors. No global
wrapper or ambient ownership key is added. The host defect gets an independent
reproduction under swi-persistency-stream-owner.

Tried: the example's written \\u0000 escape produced ordinary text. Constructing
the String with string-from-codes (97 0 98) now exercises the intended NUL.
The corrected example and twin pass 58 claims. Their initial price is
196064/195138; the ownership correction requires a new measurement.

Tried: the abandoned-store test stopped at its cleanup message, including when
the creator ran in a joined thread. An isolated probe adds garbage_collect and
trim_stacks before the next yield and then receives cleanup. Dead engine-self
values on a suspended engine's stack remain atom-collection roots. The earlier
counter probe had not exercised schema loading or persistency. Receipts:
ai-lib4-database-gc-{isolation,apply-probe}.log. The stalled test and probe were
interrupted explicitly; neither is a passing verification result.

Decided: collect and trim the engine stack before each published answer,
including initial readiness. SWI's Engine resource usage section recommends
this sequence for inactive engines. It releases dead temporary values and
unused stack capacity while retaining the current reply. This is ordinary
engine memory management, and adds no ownership registry.

### Database journal boundaries and verification repairs

Tried: four malformed UTF-8 fixtures were accepted by native replay, two with
warnings. The bytes included overlong NUL, a surrogate and an out-of-range code.
The Python test log ai-lib4-database-python.log records all four failed refusal
checks. Reusing csv_codec:utf8_text/2 on binary lines rejects all four. ASCII
line boundaries cannot split a valid UTF-8 sequence, so this pass needs only
one line of storage. Journal opening now makes a byte-validation pass, a term
validation pass and the native replay pass, each linear in journal length.
No second UTF-8 implementation is introduced.

Tried: the garbage-collection fixture needs its creator in a joined thread to
remove references retained by its test stack. It then observes engine cleanup.
A thread signal must target the active database engine, which owns the request's
execution state; signaling its waiting caller does not interrupt that state.
The revised native suite passes its first 24 tests, including both controls,
in ai-lib4-database-suite-final.log. Its final argument test exposed blob/2
enumerating live handles for a variable input; a nonvar guard now refuses that
input before enumeration. This is an input validation fix in the new library.

Tried: the Python subprocess fixture initially selected extensions/ instead of
extensions/python for PYTHONPATH and raised ModuleNotFoundError: No module named
'metta'. Its corrected fixture and the strict-byte repair pass all eight Python
tests in ai-lib4-database-python-fixed.log, including 80 generated action sequences.

### Database pathname validation

Superseded: the preceding variable-handle diagnosis. The isolated argument
probe identifies nul_path-success; blob/2 on a variable simply fails, so its
existing domain refusal was already correct. The unnecessary nonvar guard
was removed. Receipts: ai-lib4-database-{invalid,variable-blob}-probe.log.

Tried: absolute_file_name/3 truncates "a" followed by NUL and "b" to the path
ending in /a. Direct file opening had refused the same String, which is why
the earlier provider probe missed this canonicalization boundary. The API now
rejects NUL before that call. The regression fixture's path stays inside its
temporary directory even if truncation returns. The two empty lock directories
created by the failed fixture and diagnostic are removed explicitly.

### Database verification before the lane batch

Verified: all 25 lib_database native tests pass in ai-lib4-database-suite-path.log.
The suite includes 1500 model operations over all three sync policies, 400
concurrent writes, 1600 concurrent closes, explicit and collected ownership,
failed append/sync/close, combined errors, native cancellation and replay refusal.
The example and twin pass the same 58 claims in
ai-lib4-database-{example,twin}-final.log. All eight Python tests pass; four
native provider build tests pass. A fresh source archive, wheel installation,
native build and database reopen pass in ai-lib4-database-wheel.log. No existing
native provider implementation changed.

Measured: python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/42-database_lib.metta reads
223237/222382 after purging engine/lib QLF artifacts. This replaces 196064/195138
before ownership and strict-input corrections. Receipt:
ai-lib4-database-measure-final.log. The ratio is 0.9962; no overrun allowance.

Verified: all six independent host reproductions print present. The five record
generators run in order with 32 described native sources, 143 derived examples,
228 original examples and 59 library imports; no generator findings. Receipts:
ai-lib4-database-host-*.log and ai-lib4-database-records.log. jscpd scans four
native files, 347 lines, and reports zero clones in ai-lib4-database-jscpd.log.

### Database row complete

Verified: all 19 required library lanes pass in ai-lib4-database-lanes.log.
The host lane checks 40 ledger entries and 48 sites. The full native-provider
matrix passes all 23 tests with pytest -p no:benchmark -n 3 in
ai-lib4-database-native-build-parallel.log. The first parallel invocation raised
PytestBenchmarkWarning before collection because that plugin disables itself
under xdist; disabling the unrelated plugin permits the intended build tests.

Verified: the full twins lane preserves Database's 58 claims, equal stored
contents and exact 222382 inference point. It reports 263 older findings over
308 twins, with 52/345 examples passing and 3495 claims. twins-selftest passes.
Receipt: ai-lib4-database-twins.log. Database introduces no additional finding.

## 2026-09-13: Testing generation and quantified assertions

Goal: supply bounded integer, choice and list families, quantified properties
and assertion helpers while preserving the engine's verdict and failure format.

Tried: SmallCheck separates a series from its quantifier and assertion runner.
Property.hs:109-143 and 283-325 at
[433ada587bf4ff898031aaa5530c0b7aaab10e3a](https://github.com/Bodigrim/smallcheck/blob/433ada587bf4ff898031aaa5530c0b7aaab10e3a/Test/SmallCheck/Property.hs#L109-L143)
show that separation; Series.hs:858 generates lists through constructor choice.
The local engine already supplies answer streams, Cartesian powers, core bag
comparison and assertion reporting. ai-lib4-testing-host-probe-final.log verifies
bag multiplicity, reordered answers, variable sharing and held runnable data.

Rejected: a second tagged domain language, because ordinary held generator
expressions already compose builtins, library heads and user definitions.
Revisit only if a consumer needs inspectable domains rather than executable
generators. Random sampling and shrinking remain the existing Random and
Hypothesis facilities; finite families require neither another random state nor
a shrink protocol. Core forall remains unchanged, including its existential
search for a True result from each predicate application.

Decided: five heads. test-integers uses inclusive finite integer bounds;
test-choices copies each held occurrence. test-lists snapshots a finite held
generator once and uses lib_combinatorics:cartesian-power/3 across an inclusive
length interval. Each list position copies its chosen value independently,
preserving sharing inside that value. Length zero needs no element generator;
an empty pool has only the empty list. Reversed intervals are empty.

Decided: test-forall takes a held generator, held function and held expected
answer bag. It checks every application with the core subtraction-atom/=alpha
comparison, reports failures through assert-answers, and returns the number of
cases checked. Zero makes a vacuous check observable. test-witness uses the same
comparison and returns the first matching input or no answer. Each application
quotes its input, so generated runnable data is not evaluated a second time.
Function answers and the exhausted generator must be finite; exceptions propagate.
Caller variables are copied together before evaluation. No ambient state or scope.

Decided: snapshot storage is O(n) for n generated elements; Cartesian output
adds O(k) working storage at length k. Complete enumeration necessarily emits
the sum of n^k lists across the requested lengths. The universal counter uses
library(aggregate):aggregate_all(count,...), whose native incremental path uses
constant counter storage. Property comparison retains one application's answer
bag at a time. No arbitrary input, length or case limit is introduced.

### Testing example corrections

Tried: an expected bag containing a separately copied variable failed both the
new helper and core assertEqualToResult. Receipt:
ai-lib4-testing-core-variable-probe.log. The example now asserts an explicit
=alpha property instead of changing core bag equality. A second fixture tried
to match a native exception ball as a MeTTa expression and answered no-bags.
The established repr door returns the complete call, missing and excess bags;
ai-lib4-testing-error-probe.log supplies the exact expected string. These are
fixture corrections; the library implementation is unchanged.

Tried: adding --on-error=status to the native suite command turned its three
deliberate assertion-reporting tests red with "Generated unexpected warning or
error". engine/test.sh:113-119 already records why that flag is inappropriate
for these tests. The prescribed invocation passes all 20 tests; the repository
runner checks load errors separately. Receipts: ai-lib4-testing-suite{,-complete}.log.

### Testing verification before lanes

Verified: the example and twin prove 48 claims. engine/test.sh
tests/prolog/suites/libraries/lib_testing.plt passes all 20 native tests under
the shipped extensions configuration. Independent models cover 121 integer
intervals, 80 list families and 81 answer-bag pairs; queue fixtures verify
snapshotting and generator cleanup. Three Python tests pass, with 80 generated
examples configured for each of the product and quantified-bag models, plus
opaque-value identity. Receipts: ai-lib4-testing-{example-complete,twin,
native-runner,python}.log.

Measured: three fresh serial processes, engine/lib QLF artifacts purged,
python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch08-data/08-03-the-shipped-libraries/43-testing_lib.metta yields
174886/175727, ratio 1.0048, with no overrun allowance. Clarifying variable
equality in PlDoc leaves both counts unchanged in ai-lib4-testing-measure-final.log.

Verified: five record generators ran in order, with 33 described native sources,
143 derived examples, 229 originals and 60 library imports. The initial jscpd
format prolog scanned no source; the required perl mapping scans 109 lines and
1991 tokens, finding zero clones. Receipts: ai-lib4-testing-records.log and
ai-lib4-testing-jscpd-final.log.

### Testing row completion

Verified: all 19 required library lanes pass in ai-lib4-testing-lanes.log.
The full twins lane retains 263 older findings over 309 twins, with 53/346
examples passing and 3543 claims. Testing proves 48/48 claims, equal stored
contents and the exact 175727 inference pin. twins-selftest passes. Receipt:
ai-lib4-testing-twins.log. Testing introduces no additional finding.

## 2026-09-13: CLI declarations, token boundaries and value conversion

Goal: parse typed options and operands, generate help from the same declarations,
and preserve the actual process argument strings.

Tried: the native optparse source at
[fc7ef84b949378b729052c3ade79c90ce5416abb](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/optparse.pl)
is byte-identical to the installed provider, SHA256
b6e20f2d28352b058c8c9abeecec1e0b97bc1eedbd74fa1ad2db559ec6738d36.
Its absent-value sentinel makes --text and --text followed by an explicit
empty argument indistinguishable. It treats -- as an operand and continues
parsing, emits --no-verbose twice under keepall, ignores declared count2,
accepts identical duplicate declarations and conflates short/long namespaces.
Conversion failure prints its flag to stdout but throws an error that omits it.
Receipt: ai-lib4-cli-host-probe-final.log. Empty help, short-only help and NUL
text controls pass. Literal underscore defaults are a documented native
sentinel convention; the adapter must represent absence separately.

Tried: Logtalk's adaptation at
[9d0906cf4a4344e01d26c6bf2b3d7844fe9856ac](https://github.com/LogtalkDotOrg/logtalk3/blob/9d0906cf4a4344e01d26c6bf2b3d7844fe9856ac/library/command_line_options/command_line_options.lgt)
uses literal dashed names and consumes a negated Boolean once. Its parser and
tests supply the closest correction, while its object declarations add no
value to a language that already carries expressions. The local Pure manual,
section 2.5.13, likewise separates named results from remaining operands.

Rejected: rewriting tokens before calling the untouched parser, because that
requires a second scanner to reconstruct information the provider has lost.
Rejected: importing Logtalk's runtime or introducing a separate parser
dependency. The selected implementation remains a private copy of optparse,
with its BSD license, pinned source and a recorded patch. Token recognition
adapts the literal-name approach above; the provider retains conversion,
default insertion, repeat policies and help layout. Revisit the private copy
when its tracked native reproductions answer absent.

Decided: four heads: cli-parse, cli-help, cli-types and cli-arguments!.
Declarations keep optparse's field expressions: opt, type, shortflags,
longflags, default, meta and help. opt is required; type defaults to string.
Every field occurs at most once. Keys and complete dashed names are unique;
short and long names have separate namespaces. Names are case-sensitive,
nonempty and contain no whitespace, control character or equals sign. Short
names contain one character; long names can contain digits and punctuation.
No option or alias count limit is introduced. Flagless default rows are valid.

Decided: built-in value types are boolean, integer, float, atom, string and
metta. The first four retain native conversion; atom returns a Symbol, string
retains the token, and metta reads one literal MeTTa form without evaluating it.
A (parse Type Function) descriptor applies an ordinary held function to the
quoted String token in the calling module. Exactly one answer is required;
the bounded collection stops after its second answer and closes the generator.
The result and any declared default use the engine's live argument-type check,
including aliases, refinements and gradual typing. The function may be a name,
lambda or partial application. Defaults are ground literal values. Declarations
are copied before parsing so lambda binders cannot bind the caller's template.

Tried: has_type witnesses a reported type, while the published argument check
also applies value refinements. For 3 against (Annotated Number (Gt 0)), the
former answers false and the latter true; both argument checks reject -1.
normalize_type_in/3, metta_argument_type_origins/2 and
check_argument_type_under_live_policy/3 supply the complete existing route.
Receipt: ai-lib4-cli-conversion-probe-final.log. No core type rule changes.

Decided: cli-parse takes the declarations, a held String token vector and
keepfirst, keeplast or keepall. It returns (Pairs Operands), with each pair
(Key Value). Missing options with no default contribute no pair. Defaults
precede supplied occurrences; supplied occurrences retain their selected
input order. Parse and convert every supplied occurrence before applying the
repeat policy, so an invalid earlier value cannot disappear behind a later one.
Syntax is validated before custom converters execute. Exceptions name the
option, retain the underlying cause and give the repair; parsing prints nothing.

Decided: support --name=value, --name value, -nvalue and -n value. A bare
Boolean implies true; explicit true/false and --no-name are supported. A
declared --no-name wins over generated negation. Short flags do not cluster;
-n=value is refused with the accepted forms. -- terminates option recognition
and disappears from operands. A lone dash and signed numeric operands remain
data. A missing value, a following option or malformed/unknown dashed token
raises; attach a dash-led value with equals to state that it is data. An
explicit empty token remains distinct from absence, including trailing operands.

Decided: cli-help validates the same declarations and formats types, literal
defaults, aliases and help through the provider's layout. It does not execute
custom converters. cli-arguments! returns the host argv as Strings exactly,
including runner arguments; the caller chooses which tokens belong to its app.
There is no shell tokenization, implicit process exit, global parser registry
or new ambient scope. All parse state travels in arguments.

### CLI implementation and verification

Corrected: the design's atom description above is too narrow. Native atom
conversion includes true/false, which the language represents as Booleans.
The final documentation states that distinction. Names accept either Strings
or atoms so numeric short names remain expressible; unclaimed numeric operands
remain data, while a declared numeric short flag wins.

Tried: a typed two-argument cli-plus underapplication returned no answers both
inside the converter and in direct core controls. The existing untyped curry
shape in examples/ch08-data/08-01-atoms-lists-and-folds/04-curry.metta returned
15 in both cases. The example uses that existing shape and retains its explicit
Number converter result type. Receipts: ai-lib4-cli-partial-controls.log and
ai-lib4-cli-partial-untyped.log. No evaluator rule changed. The structured literal
fixture quotes its expected expression because the core test evaluates that
argument. NUL uses string-from-codes rather than a nonexistent reader escape.

Verified: the example and twin each pass 64 claims. The 23 native tests include
375 independent repeat-policy cases, 100 aliases and 100 declarations, literal
NUL/Unicode/empty inputs, converter cardinality and cleanup, template copying,
refinements and calling-module separation. The three Python tests include two
Hypothesis models configured for 100 examples each and a real-process argv check.
Receipts: ai-lib4-cli-example-complete.log, ai-lib4-cli-twin.log,
ai-lib4-cli-native-fixed.log and ai-lib4-cli-python.log.

Corrected: the first native suite omitted integer type on numeric defaults and
expected a stripped flag in an error that correctly retained the full attached
token. Both fixture defects are repaired; the library implementation did not
change. Its original failure receipt is ai-lib4-cli-native.log.

Verified: all seven independent native optparse reproductions answer present
in ai-lib4-cli-host-reproductions.log. The provider's inherited namespace,
terminator and missing-default help descriptions were reconciled with its code.
The adapter introduces no ambient scope or acquisition key.

Measured: after the provider documentation repair and QLF purge, three fresh
serial rounds still read example 347414 and twin 366038 inferences, ratio 1.0536,
with no overrun. Receipt: ai-lib4-cli-measure-final.log. The final native suite
also passes after replacing its empty acquisition scope with call_cleanup/2:
ai-lib4-cli-native-final.log. jscpd reads 238 lines and 3905 tokens through its
Perl lexer and finds no clones in the handwritten adapter, ai-lib4-cli-jscpd.log.

Verified: all 19 required library lanes pass across ai-lib4-cli-lanes.log and
ai-lib4-cli-ruff-final.log. Ruff's four tuple-concatenation findings were fixed
with tuple unpacking; ai-lib4-cli-measure-ruff.log confirmed the same count.
The full twins lane then found 94 unmarked String literals in the Python twin.
The argv helper hid their data boundary from the source checker. Explicit G
literals and the example's string-contains operation replace that helper and
the four Python substring checks. No library behavior changed.

Measured: three serial rounds after QLF removal give example 347414 and twin
367784 inferences, ratio 1.0586, with no overrun. The complete twins lane
confirms all 64 claims, equal stored contents and that exact point. Its 263
remaining findings are the older corpus findings; twins-selftest and Ruff pass.
Receipts: ai-lib4-cli-measure-literals.log and ai-lib4-cli-twins-literals.log.

## 2026-09-13: derive library behavior through MeTTa composition

Constraint changed: composition in MeTTa takes precedence over native speed.
The native-first choice in the opening census no longer decides an operation
already expressible through the language's existing functions and answer streams.
The comparison is the complete behavior, including data, bindings and cleanup.

Tried: existing forall with test and assertEqualToResult, once over a filtered
generator, foldall for counting, map-atom with a branching function, and indexed
selection with copy_term. The 26-claim scratch probe passes, including a
two-answer function composed twice yielding (2 3 3 4), literal runnable values,
empty products and independent variable copies. foldall passes the generated
value before the accumulator; the original counting probe assumed the reverse
and answered 4 instead of 7. Expression parameters evaluate, so a runnable value
is quoted before passing it. sealed renames written syntax; copy_term copies an
evaluated value. Those differences follow the existing language operations.
Receipt: ai-lib4-composition-probe-complete.log.

Tried: tracked-generator observations around core forall and once. Exhaustion,
first-witness cut, failed assertion and raised callback exception all emit one
close. once retains the selected binding; forall leaves its quantified template
unbound. Receipt: ai-lib4-testing-composition-probe-evaluator.log, ending
CORE COMPOSITION EXITS PASS. The deliberately caught failed assertion prints
its existing diagnostic before the probe completes.

Decided for Testing: remove test-integers, test-choices, test-lists, test-forall
and test-witness. lib_testing becomes a MeTTa import of lib_combinatorics and
documentation of the composition. range, superpose and cartesian-power already
supply domains. index-atom selects held values and copy_term requests fresh
variables explicitly. forall traverses, test or assertEqualToResult judges,
foldall counts, and once commits to a witness. Keep normal language bindings.
There is no separate Prolog half, generator interpreter or assertion protocol.
The example and model suites must exercise those compositions, their empty and
duplicate cases, literal values, module resolution and each resource exit.

Rejected: retaining the five names as MeTTa wrappers, because the combined
operations would still obscure traversal, assertion and commitment as independent
choices. Revisit only if a distinct behavior cannot be expressed by the existing
operations. The general library's native algorithms and other rows are reviewed
separately; this decision does not assert that their native implementations are
all necessary.

Tried: `sh test.sh examples/ch08-data/08-03-the-shipped-libraries/43-testing_lib.metta`
passes 37 top-level assertions plus the assertions inside ordinary traversals.
`sh engine/test.sh tests/prolog/suites/libraries/lib_testing.plt` passes 14 tests;
`python -m pytest extensions/python/tests/ch08_data/test_testing_lib.py -q`
passes three tests, with 80 generated examples for each product and bag model.
The twin passes after spelling the existing underscore name as S["copy_term"];
attribute spelling had constructed the undefined copy-term instead. Its three
fresh-process measurement is 82978 inferences against the example's 76856.
The caught bag-error fixture uses repr because its payload is a native compound.
Generated records pass and jscpd reports zero clones in the two Python files.
Receipts: ai-lib4-testing-composition-{example-final,native,python,twin-final,
measure,records,jscpd}.log.

Tried: all 19 required library lanes pass. Full twins confirms the new example's
37 claims, stored contents and point pin, then reports 17 Python-idiom findings
in this twin in addition to the 263 older findings. Ordinary assignment, sorted
bags, next and solve replace those spelled control forms. Two local rung comments
retain the actual subjects that need the language boundary: copying variables
inside one answer, and reading a native assertion's missing/excess report.
The corrected twin passes with no idiom, scan, layout or retired-name findings;
three fresh processes price it at 74003 inferences against 76856.
Receipts: ai-lib4-testing-composition-{lanes,twins,twin-idioms-final,
measure-idioms}.log.

Verified: `sh check.sh ruff twins twins-selftest` confirms all 37 recorded
Testing claims, equal stored contents and the exact 74003 pin. Ruff and
twins-selftest pass; full twins returns to the same 263 older findings over
310 twins, with 54/347 passing files and 3596 proved claims.
Receipt: ai-lib4-testing-composition-twins-final.log.

## 2026-09-13: collection derivations and their boundaries

Constraint changed: the composition ruling above supersedes the native-speed
choice for Combinatorics, Functional, Pairs and Sets. These four libraries form
one dependency chain, so their replacement and consumer prices share one verified
state. The existing weighted-subset sparse probability algorithm remains native;
the ordinary enumeration and collection operations become equations.

Tried: the complete scratch composition passes 101 assertions covering positional
permutations, powers, subsets, exact counts, fractional range endpoints, tuple
validation after an empty population, empty huge powers, stable grouping and
sorting, branching callbacks, plain and runnable data, Error-headed collections,
and identity with the caller's variables. The four existing native suites also
pass before replacement. Receipts: ai-lib4-collections-identity-probe.log and
ai-lib4-collections-native-before.log.

Tried: returning an Error directly from a Number-result equation answers nothing.
The existing result-type rule rejects that non-number. Declaring the union of
Number and Expression instead makes an ordinary addition refuse the call's union
type. Core assertions provide operational preconditions that raise on failure
while preserving the successful Number result, including with type checking off.
Receipts: ai-lib4-size-guard-translated.log, ai-lib4-size-guard-union.log and
ai-lib4-size-assert-probe.log. Rejected: a new exception protocol or a weakened
numeric result type; the language already supplies the necessary assertion.

Decided: two shared equations in _support/collections.metta check a finite
expression's size and recognize integers. They support existing operations and
do not add another traversal or assertion protocol. Invalid domains use the core
assertion report or a caught host arithmetic refusal. A predicate that asks about
shape answers False. It does not use an exception as its ordinary negative case.

Decided: tuples maps a positional choice over its populations; cartesian-power
reuses tuples; permutations chooses positions and recurses; subsets chooses
inclusion after the tail so its prior answer order remains. range uses range-step
with a unit stride. A range validates finite endpoints and refuses a step that
makes no progress. permutation-count folds multiplication, factorial specializes
it, and binomial divides a falling product by a factorial over the smaller side.
Empty and out-of-range cases preserve their earlier results.

Decided: Functional uses map-atom, foldl-atom, forall, case and the finite-choice
library. Callbacks run in input order. Multiple answers remain multiple answers;
partition asks whether a True answer exists and keeps every input on one side.
unfold refuses a malformed step result instead of treating it as termination.
sort-by sorts unique-key groups and flattens their members, reusing group-by's
stable ties. repeat traverses range and evaluates its held body. Slicing and
growing collection accumulators can cost quadratic work; native speed no longer
justifies their separate loops, and the old linear-cost claim is removed.

Decided: Pairs reuses unzip, zip, group-by and sort-by; ungrouping retains the
caller's variable identity through map and flatten instead of a native findall.
Sets uses unique-atom and sort-atom for canonical values and the core multiset
intersection and subtraction over those values. The other set operations are
compositions and folds. Every input requiring a canonical set is checked,
including a lone input to set-intersection-all; no sets still raises there.

Tried: raw reverse and append re-evaluate runnable data at their untyped result
boundary. The core union-atom preserves a collection as a value. Naming groups
before sort-atom also preserves their data, whereas nesting a masked call beneath
that boundary can re-enter evaluation. The behavior follows the result-mask rule
recorded in engine/translator/runtime.pl:metta_masked_result/2, so the equations
use named values and explicit quote at application boundaries. Wrapping every
sort element in quote was rejected because a named sort preserves those wrappers
as data. Receipts: ai-lib4-collection-composition-{probe,quote-probe,
primitives-probe,values-probe,sort-probe,named-sort-probe}.log.

Verification required: keep the existing example claims, add the semantic cases
above, update the ordinary Python twins, and test the public MeTTa calls against
independent host models. Reprice every direct and transitive consumer after the
last library change, then run generated-record, required-lane and provenance
checks before committing the implementation and its evidence pins.

Tried after replacement: all four existing shipped examples pass. A literal-data
probe of the original chooseKl returns ((3) (a)) for quoted ((+ 1 2) a), where
the literal choice is (((+ 1 2)) (a)). Its native append re-evaluates the value.
Its chooseK also collects every choice before superposing them, contradicting
the example's claim that a consumer may stop before building the rest.
Receipt: ai-lib4-legacy-choice-values.log.

Decided: the failed literal-data contract changes the earlier decision to leave
those equations untouched. chooseK now makes each choice directly through held
values and superpose; chooseKl collapses that stream. The seven-claim prototype
preserves ordering, duplicate positions, literal values and caller identity.
The existing collected names remain as their upstream MeTTa compositions.
choose2 keeps its distinct later-index-first order and takeK keeps its prefix
equations; all original heads now declare their types and documentation.
Receipt: ai-lib4-choices-stream-probe.log.

## 2026-09-13: segments, variadic operations and the standard-library basis

The composition review includes lib_builtin_types, the prelude and existing
libraries. The 36 concern rows are the package's work census; the complete
standard library also includes facilities already supplied, including the
builtin type declarations. Evaluation masks, quote, ordinary variable binding,
answer streams, segments, variadic arrows and resource scopes are part of the
basis against which a proposed primitive is evaluated. Performance alone does
not justify a separate native implementation of derivable behavior.

Read: examples/ch08-data/08-02-sequence-variables/01-segments.metta through
03-the-one-sided-fragment.metta, examples/ch09-types/22-variadic_arrow_signature.metta,
lib_strategy:strategy-one and the 2026-09-09 splice-in-an-arrow journal. Segments
capture zero or more children in shortest-prefix-first order. Variadic arrows
repeat the same element contract at each arriving argument position.

Tried: a local segment bound by let does not enable equation-head RHS splicing.
Writing those markers inside a reconstructed value kept them literal; a scratch
permutation failed with an 8.0Gb stack-limit error. Selection can use the local
segment directly, and union-atom/cons-atom already reconstruct literal values.
A separate segment application adapter required another equation for behavior
that apply-to already derives with cons-atom and eval, so it was rejected.

Found: an empty expression bypassed the nested sequence matcher, and the
variadic family emitted metta_segment_body_result/4 without exporting and
protecting it. The new segment_equations regressions fail independently: one
has no answer, the other raises Unknown procedure for that helper in &self.
The general fixes admit an empty subject to the existing child matcher and
register the continuation beside metta_segment_rule_result/6. They introduce
no library-specific compiler case. The 10 segment-equation tests, 54 matcher
tests and 29 variadic-arrow tests with 10 subtests pass. Receipts:
ai-lib4-segments-engine-{before,fixed}.log.

Decided: choose2 and permutations select positions through segment patterns;
chooseK and subsets destructure head and tail through the same matcher. Tuples
maps an element selected by a segment pattern over its populations. Zip unfolds
pairs of heads until either side fails to match. Drop matches the prefix takeK
already supplies, then returns its captured remainder. Chunk and window unfold
those existing prefix/remainder operations. Scan reads its last accumulator
through a segment pattern. Pair lookup selects relation rows structurally and
then compares keys strictly. Existing ordered answers and literal values remain
the contract. The scratch collection probe and 247-case slicing comparisons
pass, including empty inputs and variable identity.

Decided: set-union and set-intersection accept a variadic run of canonical sets.
The former has empty identity; the latter requires at least one argument and
validates that first argument. Their folds subsume set-union-all and
set-intersection-all, which are removed. A runtime collection is passed through
the existing apply-to. No new spread adapter or fixed arity ceiling is added.
Receipt: ai-lib4-segments-collections-probe-after-engine.log and
ai-lib4-segments-slices-probe.log. Verification and final prices follow the
earlier collection procedure after the final source edit.

Verified: the four examples and twins pass 63, 73, 54 and 37 claims. The native
public-interface suites pass 44 tests with 346 subtests; the existing weighted
algorithm suite adds five passing tests. Python's 20 collection tests include
seven 100-example Hypothesis models, and the ten existing weighted tests pass.
Their independent models use itertools, integer arithmetic, Python slicing,
stable maps, finite sets and the host pairs/list libraries. Literal expressions,
Error-headed data, caller variable identity and branching callbacks are covered.
Receipts: ai-lib4-collections-segments-native-verified.log and
ai-lib4-collections-segments-python-{fixed,verified}.log.

Tried: moving native suites to the public evaluator exposed fixture assumptions.
The host extension bootstrap needs the engine imported into user; a generic
items/2 export collides with Janus; chooseK takes its population before its count.
The corrected shared fixture binds literal arguments before calling, commits
single-value checks explicitly and retains every answer for stream checks.
Collection callbacks are no longer falsely tested as deterministic native calls.

Measured: three fresh rounds after removing engine/lib QLF files give
example/twin 850820/747785 for Combinatorics, 1074085/1091943 for Functional,
348761/366379 for Sets, 837557/813769 for Pairs and 390681/364240 for Testing.
Sets no longer needs its earlier overrun declaration. Functional's stored-content
difference retains the tick helper's let/let* translation and now includes two
otherwise identical specializations whose generated lambda names shift by two
after the Python generator's two lambda bodies. The 73 matching claims cover
those callback paths. Receipts: ai-lib4-collections-segments-measure.log and
ai-lib4-functional-segments-repin.log. Every transitive consumer is remeasured
before the provenance commit.

Measured: the ten-consumer re-pin confirms the five collection/Testing points
above and updates System to 200522, Math to 192956, Random to 123955,
Statistics to 163787 and URI to 180593. All three runs of each twin complete;
no additional stored-content divergence changes. Receipt:
ai-lib4-collections-consumers-repin.log.

Tried: the corpus lane identified combinatorics-range-loop as a public head with
no direct example. Its unchecked continuation belongs to the private support
file, which the validated public range operation imports. Moving the unchanged
equation there preserves its contract without adding a public API or an exception
to the corpus gate. The five record generators pass. Three fresh rounds update
the ten affected twins to Combinatorics 749122, Functional 1093280, Sets 367716,
Pairs 815106, System 201865, Math 194299, Random 125298, Statistics 165130,
URI 181936 and Testing 365541; no stored-content divergence changes. Receipts:
ai-lib4-collections-private-records.log and ai-lib4-collections-private-repin.log.

Verified after the private continuation move: all 19 required lanes pass, and
the native suites retain 49 passing tests with 346 subtests. The full twins lane
reports 265 findings, including two new point mismatches in File and the module
loading example. Exporting the segment continuation changes their module setup
costs by 6 and 19 inferences. Three fresh rounds give 210172 and 158506, with
equal stored contents. After those two pins move, the focused twelve-consumer
lane passes all 661 claims with zero findings; twins-selftest also passes.
The other 263 findings have the same paths and categories as the earlier Testing
receipt. Logs: ai-lib4-collections-private-{lanes,native}.log,
ai-lib4-collections-fulltwins.log, ai-lib4-collections-engine-consumers-repin.log
and ai-lib4-collections-twins-verified.log.

Tried: prolog-static on this tree and the provisioned c75181adc control. Both
reach the same five static checks, then abort with the X server error
`BadValue (integer parameter out of range for operation)`, major opcode
`152 (GLX)`, minor opcode `3 (X_GLXCreateContext)`. The control also repeats its
known MORK build failure because its sibling kernel Cargo.toml is absent.
No static-check or graphics workaround is introduced. Receipts:
ai-lib4-collections-prolog-static.log and
ai-lib4-collections-prolog-static-control.log.

Found during provenance pinning: collection_test_support.pl is the first shared
Prolog helper under suites, whose source pattern previously covered only .plt.
The pin guard reports the helper outside the evidence globs and leaves it
unresolved. Decided: include recursive suite .pl sources in the evidence scope.
The existing checker selftests gain a nested helper with a backed and an absent
citation, and a comment pin beside a code atom that pinning must preserve.
The functional commit is amended before its provenance commit, retaining the
original unresolved-pin receipt in ai-lib4-collections-pin.log.

Verified: the evidence selftest reports zero defects, and the pin selftest
reports zero defects over 73 placeholders in 27 files, 69 C-family cases,
110 CMake cases and eight pre-write refusals. The repository evidence and Ruff
lanes pass with the helper's claim now read. Receipts:
ai-lib4-collections-evidence-selftest.log,
ai-lib4-collections-provenance-selftest.log and
ai-lib4-collections-helper-evidence.log.

## 2026-09-13: Statistics as a reflective domain

The consolidation and derivability ruling changes the opening census's
separate Distribution/Statistics ownership and native sample recipes.
Decided: put finite laws and observed-sample summaries in lib_statistics.
Measure remains the algebra of weighted answers and attention scores, which
need not be normalized probability laws. Sample quantiles interpolate;
finite-law quantiles invert cumulative mass.

Decided: derive all fourteen sample heads from the existing exact-number and
collection operations. A private native check validates finite expression
structure, including host-injected cycles. Math's shared fractional root is
the rounding boundary. Its gcd/lcm, factor choices, unary rational conversion
and floating conversion become equations as well. Native integer-root and
modular-power kernels and number representations remain in the numeric provider.

Decided: replace the binary independent map with a variadic map. Form product
tuples first, then map the function over that collection. Alternative rewrites
produce alternative complete laws. Collapsing function answers into the tuple
generator would incorrectly assign them probability mass. Average, Bernoulli
addition and repeated sums compose this operation; repeated sums merge partial
totals after each convolution.

Tried: the exact mean/reflection probe passes eight claims. The numerical-domain
probe passes eleven binary-range, variadic, branching and refusal claims plus
three imports. Its first run omitted conversion of float observations before
scaling and raised an exact-arithmetic assertion on infinity. Performing the
conversion required by the existing contract resolves it. Receipts:
ai-lib4-statistics-basis-probe-matched.log, ai-lib4-numerical-domain-probe.log
and ai-lib4-numerical-domain-probe-exact.log.

The geometric-mean recipe retains the pinned CPython exponent/log reduction.
Bit-shift-right and unfold derive its binary exponents; no new native
decomposition head is needed. The independent product follows the existing
pinned NumPy/ProbLog/Scallop product-law sources. No dependency is added.
The first source-edit script stopped at its dead-fragment guard before writing
anything; its multiline import match was incomplete. The direct patch removes
the complete FD import together with the replaced factor-search implementation.

The finite-expression check is shared with Math and the other collection
consumers. Their old native boundaries also rejected improper and open lists;
deriving their arithmetic must preserve that validation. The check now lives
under _support/collections and collections-size uses it without copying terms.
Nested cycles through space contents remain valid; only cyclic host terms
cannot be finite expressions.

Tried: Math's existing 67-claim example passes. The first sample run passes all
54 numerical claims, then exposes a nonnumeric observation disappearing through
typed dispatch. An exact get-type comparison rejects BigInt and is therefore
not the numeric acceptance relation. A case for no answers also misses a
reified typed Error. Check the conversion's Error result before traversing
numeric classes. The first native run passes Math's 14 tests and 16 of 17
Statistics tests; the same complete-input refusal is the failing test.

Tried: the distribution example rejects a forced 3.0 where its input arithmetic
previously returned integer 3. Average now inherits stats-mean's exact or
floating result type directly. It also catches a nonexistent range-list head
being treated as a three-element expression, producing three draws for count
one. Compose collapse with the existing range generator and fold the bound
result. Receipts: ai-lib4-statistics-equations-example.log,
ai-lib4-statistics-{math,samples,laws}-example.log,
ai-lib4-statistics-{samples,laws}-example-fixed.log and
ai-lib4-statistics-native.log.

Tried: the final collection/sample run passes 66 native tests and 346 subtests.
Python initially passes 55 tests and fails three normalization-refusal tests.
Compiled clauses show if-error evaluates both branch values before selecting
one. Guard each computation with lazy core if and use if-error only to inspect
the value. This is the documented prelude behavior, not a host workaround.
The corrected finite-law example passes all 51 claims. Receipts:
ai-lib4-statistics-collections-native-fixed.log, ai-lib4-statistics-python.log,
ai-lib4-statistics-laws-example-final.log.

Tried: reconstructing an equation as an already compiled lambda captures
unbound variables before matching. Quoting the lambda syntax during the match
and evaluating it afterwards produces the callable equation. Matching a fixed
degrees-of-freedom argument first specializes variance to population variance.
The sample example now passes 78 claims including both reflective uses. The
Python twin initially compares its native rational result to a boxed Fraction;
retain the expected native atom through Answers.__getitem__, as the existing
numeric boundary requires. Receipts: ai-lib4-statistics-reflection-probe.log,
ai-lib4-statistics-reflection-probe-syntax.log,
ai-lib4-statistics-samples-example-final.log, ai-lib4-statistics-twin-trace.log.

Tried: the new square-root regression finds that exact conversion loses the
sign of floating zero. Preserve that zero before converting other inputs.
The regression fails before the fix and all 14 Math tests pass after it;
the same run passes all 17 Statistics tests. The Math example passes 74 claims.
Receipts: ai-lib4-statistics-root-zero-before.log,
ai-lib4-statistics-math-native-final.log,
ai-lib4-statistics-math-example-final.log.

Verified: all 58 Python sample, finite-law and collection model tests pass.
The geometric-mean property run emits the configured 180-second diagnostic
stack dump and then completes; no runtime deadline was added. The corrected
sample twin passes. jscpd reports no exact clones across the four recognized
Python/Prolog files; its Perl tokenizer for .pl does not establish semantic
duplication coverage, and it does not parse MeTTa. The equations were reviewed
for shared reductions and orthogonal arguments. Five record generators pass;
the public roster now has 60 libraries. Receipts:
ai-lib4-statistics-python-final.log, ai-lib4-statistics-twin-final-fixed.log,
ai-lib4-statistics-clones.log and ai-lib4-statistics-records.log.

Measured: after purging engine/lib QLF artifacts, three fresh serial runs give
Math 359401 example / 362843 twin inferences and Statistics 40093976 / 40110888.
The equations deliberately cost more than the replaced native recipes; both
twins remain within the ordinary band. Retire Statistics' former 1826 overrun.
The same three-round protocol verifies every known consumer below and changes
ten point pins. Stored contents retain their existing parity. Receipt:
ai-lib4-statistics-prices.log; command: sh ai-tmp/ai-lib4-statistics-prices.sh.

| Consumer | Final twin inferences |
|---|---:|
| 11 Combinatorics | 742907 |
| 19 File | 210172 |
| 22 Functional | 1094922 |
| 23 Sets | 365308 |
| 24 Pairs | 808811 |
| 31 System | 207449 |
| 35 Math | 362843 |
| 36 Random | 137157 |
| 37 Statistics | 40110888 |
| 39 URI | 187333 |
| 43 Testing | 369669 |
| 20-03/05 Module doors | 158506 |

Tried: 17 of 19 required lanes pass. lib-autoload reports that _support's
registration cannot be joined to its native provider because the provider was
placed in a separate nested directory. Put collections_data.pl beside the
MeTTa support file, following owned_resources.pl's private-helper shape. Its
internal signature remains declared in the MeTTa file; ordinary native comments
avoid requesting a public generated face for an implementation detail. The
gate now sees the same exports that registration names. Ruff also identifies
one import-order error in the sample twin. Both repairs are local; no gate or
allowlist changes. Receipt: ai-lib4-statistics-lanes.log. Remeasure after the
provider path changes, retaining the preceding measurement as its earlier state.

Verified: the corrected lib-autoload and Ruff lanes pass. All 14 Math and
17 Statistics native tests pass after the private-provider move. The source
inventory includes 29 described providers and 17 private or undescribed sources,
with no generated face for the private guard. Receipts:
ai-lib4-statistics-private-{checks,native,records}.log.

The preceding price table is superseded by the final colocated-provider state.
Three fresh serial runs give Math 357731 example / 361166 twin and Statistics
40092306 / 40109211. All twelve consumers remeasure; ten points move and no
stored-content divergence changes. File remains 210172 and Module doors 158506.
Final changed points are Combinatorics 741230, Functional 1093245, Sets 363631,
Pairs 807134, System 205772, Math 361166, Random 135480, Statistics 40109211,
URI 185656 and Testing 367992. Receipt: ai-lib4-statistics-prices-final.log.
Each twin keeps its committed price history and records one move from its
previous committed point to this final point. An AST comparison proves that
reconciling provisional measurement comments changes no twin behavior.

Verified: all nineteen required lanes pass. Full twins reports 281 findings:
the 263 preceding corpus categories and eighteen new Python-notation findings
in the two sample reflection claims. Their explicit match/let/eval syntax
becomes ordinary space queries, Python bindings and the evaluation door. The
same rule variables remain shared when the callable equation is reconstructed.
Three fresh runs price the changed twin at 40107888 against example 40092306;
this supersedes only Statistics' point above. No library source changed.
The provenance reconciliation briefly reintroduced the retired overrun from
the committed pricing suffix; the lane refused it and that suffix is removed.
Receipts: ai-lib4-statistics-lanes-final.log,
ai-lib4-statistics-fulltwins.log,
ai-lib4-statistics-reflection-python.log,
ai-lib4-statistics-twin-idiomatic-price.log and
ai-lib4-statistics-twin-idiomatic.log.

Verified: the corrected 78-claim twin has zero findings. Comparing full-lane
finding identities to the preceding Testing run confirms that all eighteen
additions belonged to the repaired reflection syntax. The other 263 findings
retain the preceding identities. Receipts:
ai-lib4-statistics-twin-idiomatic-fixed.log and
ai-lib4-statistics-findings-diff.log.

Cleanup: the removed Distribution directory remained empty in this checkout,
so the directory-based roster generator still counted it. Removing that empty
directory and regenerating the roster produces 60 libraries and zero findings.
The initial manual roster removal exposed the stale directory, then the two
old count fields; the generator now owns all three values again. Receipts:
ai-lib4-statistics-final-edits-check.log,
ai-lib4-statistics-llms-clean-directory.log and
ai-lib4-statistics-final-roster.log.

## 2026-09-13: Persistent syntax composes with core matching

Goal: apply the later reflective-rewriting and derivability requirements to
Database, preserving its existing passive syntax and resource contracts.

Tried: generic let patterns do not interpret bound equality guards. superpose
evaluates expression values, and unify reduces a goal-free nonground branch
result. Direct let segment patterns preserve passive values; explicit guards
compose through a Boolean unify condition followed by quote. The two final
probes each pass seven claims covering numeric promotion, segment splits,
literal runnable data and reconstructed functions. Receipts:
ai-lib4-database-selection-composed.log and
ai-lib4-database-selection-direct-fixed.log. These are core semantics, so no
engine change or host workaround is needed.

Decided: replace database-query with database-atoms. The native half owns a
fresh snapshot, serialization and external resources. Selection, projection,
joins and rule reconstruction use ordinary MeTTa expressions. The later
composition requirement supersedes the original native-query and ground-only
rulings above. Variables retain sharing per occurrence; snapshots are fresh.
Removal compares canonical encodings and deletes one alpha-identical value.

Tried: numbervars with a private compound retains ground journal records under
persistency's numbervars(true) writer. mapsubterms plus varnumbers_names restores
sharing and allocates by variable count rather than an untrusted largest index.
Re-encoding checks canonical numbering before replay. Literal marker expressions
remain disjoint from that native compound. The actual writer probe passes in
ai-lib4-database-codec-probe.log. Existing ground journal bytes need no migration.

Rejected: automatically executable database spaces. The preceding contract
stores equations as passive data; making add compile them changes that behavior.
A borrowed space projection adds compiler replay, cleanup and another lifetime
to supply an executable world that this census did not request. Revisit when
persistent executable worlds are requested. Weak class lookup and engine cleanup
were probed, but no host concurrency defect was established by that research.

Adapted: the edge-reference model from metta-examples at
799ad9dbf92987cabeede6d1eca02ac7f8abb0ad, edges-to-edges/nte.metta. The example
uses ordinary PeTTa snapshot patterns to join two edges and their supporting
relation. No query DSL or repository-specific native integration is added.

Verified: the preceding native suite passes 25 tests. The revised example and
twin prove 71 claims with equal stored contents. Three fresh serial measurements
after deleting engine/lib QLF files give 244929 example and 226128 twin, replacing
the original 58-claim fixture's 223237/222382. The unpriced twin correctly refused
its old 222382 point before this measured update. Receipts:
ai-lib4-database-composition-before.log,
ai-lib4-database-snapshot-example.log,
ai-lib4-database-snapshot-twin.log and
ai-lib4-database-snapshot-price.log.

Verified: all 28 native tests pass, retaining resource, error, process and
cancellation cases and adding variable freshness, eighty sharing graphs and
noncanonical journal refusals. Receipt: ai-lib4-database-snapshot-native.log.

Tried: the combined Python model/build suite passes 31 tests, including wheel
installation, and fails concurrent native publication for Database at
test_library_native_build.py:155 with one child returning `(1, '', '')`.
Its executable probes all open the same probe.lock, so correct exclusive
locking makes concurrent probes compete after the build has succeeded.
Holding that fixture file externally reproduces precisely `(1, '', '')`;
releasing it makes the same built object pass. Receipts:
ai-lib4-database-snapshot-python.log and ai-lib4-database-build-lock-probe.log.
The runtime fixture now owns a separate temporary lock stream per probe.
The existing Database process-lock test continues to check actual contention;
the native-build test continues to require one publication across six processes
and their four builder threads. No production lock or builder behavior changes.

Verified: the held-lock control passes with independent probe streams. All 32
Python model and native-build tests pass with the original shuffled seed
2254016849, including process contention, variable-sharing models, compiler
cancellation and installed-wheel execution. Receipts:
ai-lib4-database-build-lock-fixed.log and
ai-lib4-database-snapshot-python-fixed.log. Ruff and the seven focused lanes
pass. Jscpd reports zero clones in two Python files and one .pl file classified
as Perl; it does not establish Prolog or MeTTa semantic duplication coverage.

Verified: all nineteen required library lanes pass. The full twins lane proves
the Database snapshot's 71 matching claims and equal stored contents at
244928/226127, within the deterministic allowance of the three-round points.
Its 263 findings retain the preceding Testing run's identities and multiplicities;
the Statistics reflection additions are gone. Twins-selftest passes. Receipts:
ai-lib4-database-snapshot-lanes.log,
ai-lib4-database-snapshot-fulltwins.log and
ai-lib4-database-snapshot-findings-diff.log.

## 2026-09-13: Inspect the live callable basis

Tried: `m.builtins()` on a MeTTa context raises `AttributeError: MeTTa has no
'builtins': it is a Space door, and a context is not its space.` The named
repair, `m.self.builtins()`, returns 307 callable names before additional
library imports. The inventory includes forall, foldall, map-atom, filter-atom,
for-each-in-atom, member, expression operations, reflection and random primitives.
Use their actual type and evaluation contracts in the remaining derivation
matrix. for-each-in-atom is the historical map-atom form; member binds through
native membership and yields True for each success. Neither name alone proves
the same held-value or numeric-matching contract as another operation.
Receipts: ai-lib4-builtins-census.log and ai-lib4-builtins-census-fixed.log.

## 2026-09-13: Graphs derive from relations, sets and rewrites

Tried: the preceding six native tests pass, but graph-is accepts
`((a ($x)) (b ()))` although the unbound neighbour is no vertex. Native
graph-neighbours also binds a fresh lookup variable to a. The reproduction
prints present in ai-lib4-graph-identity-before.log. These are library
unification errors, not host defects. Twelve MeTTa probe claims preserve
identity and derive construction, closure and ordering in
ai-lib4-graph-rewrite-probe.log.

Decided: the later derivability and identity requirements supersede the native
graph wrapper ruling. Keep canonical adjacency expressions; derive their
operations from Sets, Pairs and Functional. Closure folds intermediate vertices
and rewrites neighbour sets. Reachability and cycle detection share that closure.
Topological ordering unfolds zero-indegree layers, with canonical order within
each layer. Graph union accepts zero or any number of arguments. Core assertion
messages name unknown vertices and actual cycle vertices.

Prior art: the intermediate-vertex invariant and layer decomposition in
[SWI-Prolog V10.1.13 ugraphs.pl](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/ugraphs.pl)
remain the independent ground-graph reference. MeTTa folds, sets and unfold
replace its native recursion and degree counters. No source is copied.

Rejected: retaining a native graph algorithm for speed. The existing expression
operations cover its cases, and the later requirement accepts slower derived
recipes. Single-origin reachability computes closure before selecting its row;
this extra work shares one definition of paths. A separate walker is justified
only if a later requirement needs streamed or partial reachability. The census
still supplies no caller for complement or composition.

Tried: constructing a lambda directly in the match template compiled the body
before matching supplied its syntax. The resulting function returned that body
as data. Quote the reconstructed lambda and explicitly eval it, as the existing
Statistics example does. The repaired example proves 49 claims; its Python twin
proves the same 49 with equal stored contents. Receipts:
ai-lib4-graph-example.log and ai-lib4-graph-example-fixed.log.

Measured: three fresh serial processes after deleting engine/lib QLF files give
8675592 MeTTa and 8659169 Python inferences. The old 92402 point correctly fails
before replacement, and the former 2649 overrun is no longer needed. Receipts:
ai-lib4-graph-twin.log and ai-lib4-graph-price.log.

Tried: all three native generated-model loops pass, but the new arity fixture
calls =../2 before completing its argument list and raises
`=../2: Arguments are not sufficiently instantiated`. Building the list first
fixes the fixture. The two existential reflection checks now explicitly commit
their successful answers; their previous choicepoint is refused by the suite
runner. Twelve Python tests pass, and the literal-vertex fixture fails because
it re-enters an answered graph as runnable syntax: its (+ 1 2) vertex becomes 3.
Quote that graph on re-entry, matching the literal-input contract. Receipts:
ai-lib4-graph-native.log and ai-lib4-graph-python.log. No library change or new
host workaround follows from either fixture failure.

Tried: quoting the Python fixture's input exposes a library error: removing
a vertex also drops an Error-valued sink, and an Error-valued self-cycle reports
acyclic. Computed row keys passed straight to set-member take error propagation
instead of literal comparison. An ordinary vertex set spelled (Error a b)
exposes the same boundary in neighbours and reachability. Bind and quote
computed data before applying another library operation. This is a composition
repair, not an engine change. The probe and repaired answers are in
ai-lib4-graph-error-values-probe.log and ai-lib4-graph-error-values-fixed2.log.
An extra closing parenthesis during that repair prevented the source import;
the intermediate fixed.log contains unreduced calls and supplies no evidence.

Verified: the revised native suite passes all fourteen tests, including the
same three generated-model loops and eighteen graphs with runnable, Error or
mixed numeric vertices checked against the independent host oracle. The thirteen
Python tests pass with shuffled seed 2912975243. Both README snippets execute.
The example and twin now prove 52 matching claims with equal stored contents.
Three fresh measurements give 8991153/8975689, superseding the 49-claim points.
Receipts: ai-lib4-graph-native-literals.log, ai-lib4-graph-python-literals.log,
ai-lib4-graph-readme-metta.log, ai-lib4-graph-readme-python.log,
ai-lib4-graph-example-literals.log and ai-lib4-graph-price-literals.log.

Verified: eighteen required lanes pass; evidence rejects the abbreviated
test_graph_lib.py path in the Graph header. Qualifying its repository path
makes evidence and the four face/documentation lanes pass. Repeating all three
measurements after that header change retains 8991153/8975689. Full twins proves
52 equal claims and equal stored contents at those exact points. Its 263
findings have the preceding Testing run's identities and multiplicities;
twins-selftest passes. Receipts: ai-lib4-graph-lanes.log,
ai-lib4-graph-evidence-fixed.log, ai-lib4-graph-price-final.log,
ai-lib4-graph-fulltwins.log and ai-lib4-graph-findings-diff.log.

## 2026-09-13: Random samples are programs

Changed condition: the derivability requirement prefers MeTTa equations even
when their traversal costs more. The native registry and combined distribution,
count and drawing operation no longer determine the representation. The live
Python `m.self.builtins()` census lists 307 callables, including the arithmetic,
entropy, quotation, evaluation and collection basis used here.

Decided: eleven constructors return ordinary sample programs, comprising the
ten numeric families and occurrence choice. Construction validates without
drawing; `eval` runs one program, `repeat` streams it, and existing collection
forms control demand and sharing. Matching can reconstruct a constructor or
rewrite a program's entropy position. Distinct-position sampling unfolds an
immutable population, removing one position through segments. Shuffling samples
its size; independent choices with replacement compose choice and repetition.
The O(n × count) removal cost replaces the native index shuffle. No new seed,
scope, cached normal spare or distribution-tag interpreter is introduced.

Tried: returning a capturing lambda, with nested and open return declarations,
fails `process_loader_form/3` with `Could not translate MeTTa form`. Quoted
programs need no closure wrapper and support direct code inspection. Binding
the constructor result before `eval` preserves the evaluation stage. Passing
`(quote Items)` to an already held population makes `quote` an occurrence;
pass Items directly. A functional head in a destructuring pattern invokes that
function, so program inspection matches a variable head instead. These controls
and the corrected cases are in ai-lib4-random-{callable,basis,example}-*.log.

Retained: Box-Muller without a spare, Marsaglia/Tsang rejection with factor and
log-correction pairs, exact final interpolation, and stable extreme beta ratios.
The pinned Rand, CPython and NumPy sources and their licenses remain the basis
identified in `lib/lib_random/vendor/README.md`. An exact intermediate cannot
use Vector's floating `dot`: the scratch extreme-difference probe overflowed.
One higher-order adapter instead composes exact component operations and uses
`dot` only for final interpolation. The previously rejected always-log gamma
transform remains rejected because it loses large-shape precision.

Tried: recording a normal program identifies `dot` and `math-real` as oracleIO
despite their numeric bodies. Provider declarations existed, but their late
imports were ordinary functions and the effect reader required startup
`builtin_fun` registration. Decided: read the existing declaration seam after
native and semantic profiles, preserving their floors and narrower cache
admission. Vector, Math and the finite-expression validator declare their own
effects; no library names enter engine policy. Both native negative controls
fail before the repair, and all 25 effect tests then pass.

A second planner defect made a computed function head fail analysis entirely:
its clause required the pending-definition queue to remain unchanged. Carrying
the resulting queue preserves the called body's effects while retaining the
dynamic-call classification. The planted arithmetic and writer heads fail
before that two-variable repair; all 26 effect tests pass afterwards. Receipts:
ai-lib4-random-late-effects-{before,after}.log and
ai-lib4-random-computed-head-{before,after}.log.

Verified: the example and direct twin each prove 68 claims. Sixteen native tests
retain all ten 10000-draw moment checks, 32 seed/position cases, finite extremes,
signed zero, literal sharing, cut, errors, concurrent generators and cancellation
after an actual draw. Python's 35 tests include independent Fraction and
Box-Muller models, generated occurrence populations, reflected programs and
recording of every family. Seed 3019339591 passes, including the order that
previously exposed cold specialization. Forty-one existing Python effect and
recording tests also pass before the computed-head repair and are rerun below.

Recording keeps its initial content digest. A first sample run can publish
specialization equations; replay correctly refuses that changed space. The
next recording over those equations replays identically. Occurrence validation
retains assertions whose possible diagnostic output remains conservatively
unseeded I/O. These are explicit recording boundaries, not a new sampler state
mechanism. The fresh-process cold refusal and subsequent replay both pass in
ai-lib4-random-cold-contract.log. The clone experiment does not supply a matching
digest: compiling the copied equations creates further specializations. Its
exact refusal is retained in ai-lib4-random-recording-cold-replay.log.

Measured: three fresh processes read example=1075465 and twin=1134786
inferences for the 68 claims, ratio 1.0552. No overrun is required. The Python
clone scan reports no clones; it makes no MeTTa or Prolog coverage claim.
Receipts: ai-lib4-random-price.log, ai-lib4-random-jscpd.log,
ai-lib4-random-native-scope-fixed.log and ai-lib4-random-python-final.log.

Verified after the final planner change: Random16, Math14, Vector33 and
effects_lattice26 native tests pass. The 75 Python effect, recording and world
tests pass. Both README answers are checked. Five record generators pass in
their dependency order: 27 described native sources, 17 private sources,
284 constructs, 143 derived and 230 original examples, 319 live engine names
and 60 libraries. Thirteen consumer twins were measured three times; eleven
pins advanced and File and module-door points remain within their allowance.
The resulting points are recorded beside each twin. Receipts:
ai-lib4-random-native-final.log, ai-lib4-random-python-effect-final.log,
ai-lib4-random-readme.log, ai-lib4-random-records.log and
ai-lib4-random-consumer-prices.log.

Verified: all nineteen required lanes pass. Full twins proves 68 equal claims
and equal stored contents, with the same 263 older finding identities and
multiplicities as Graph; twins-selftest passes. Its example counter differs
from the three-process minimum, exposing an unseeded variable-sharing fixture.
Sampling two equal values can take different removal paths even though the
answer is identical: the ten-seed probe reads 13709 or 13746 inferences. Seed
that fixture in both examples before renewing its point. This supersedes the
1075465/1134786 measurement above. Receipts: ai-lib4-random-lanes.log,
ai-lib4-random-fulltwins.log and ai-lib4-random-occurrence-cost-fixed.log.

Verified: the seeded fixture's three-process measurement and full twin lane
both read example=1075529 and twin=1134846, with 68 equal claims and equal
stored contents. The five generators pass again. The final 263 findings match
Graph's identities and multiplicities; only inference numbers are normalized
when comparing budget findings, while other diagnostics are compared exactly.
Twins-selftest passes. Receipts: ai-lib4-random-price-seeded.log,
ai-lib4-random-records-seeded.log, ai-lib4-random-fulltwins-seeded.log and
ai-lib4-random-findings-diff.log.

## 2026-09-13: immutable collections as ordinary relations

The changed condition is the preference for deriving library operations in
MeTTa even at greater runtime cost. This supersedes the native AVL/pairing-heap
choice in the September 12 datastructures section. Immutable map and queue
values retain their distinct kinds, key identity, every queue occurrence,
absent answers, immutable updates and usable written representation.

Decided: `(SortedMap Rows)` and `(PriorityQueue Rows)`, with an ordinary ordered
pair expression as Rows. Pairs supplies projections and identity lookup; core
filters and segment decomposition supply replacement, selection and removal.
Map construction rejects repeated keys, so sorting whole pairs orders by their
unique keys without a separate key-function sort. Priority sorting is stable;
variadic merge concatenates inputs left-to-right and sorts once. Matching the
public equations can reconstruct or specialize the collection recipes.

Rejected: porting AVL rotations and heap meld clauses into MeTTa, because the
existing relation operations derive the complete public behavior with less
code. Revisit if an independently needed persistent search-tree abstraction
supplies semantics beyond this map API. Mutable Dict already uses a queryable
Space and remains distinct from these immutable values. The existing MeTTa
finger tree retains its 2-3 node invariant and endpoint/concatenation operations.

Found: the original duplicate-key validator uses findall, which copies keys,
and its pair validator unifies an unbound pair under forall. The expected
refusals for repeated variable keys and unbound pairs fail before the change;
the derived checks reject both without binding them. Original literal runnable
and Error-value finger-tree probes pass. Receipts:
ai-lib4-datastructures-before.log and ai-lib4-datastructures-native.log.

Decided: queue ties retain construction/insertion order and left-to-right
merge order. The old public contract specified priority order only; its tied
oracle fixture exposed the host heap's internal order. Retain that fixture's
contents, removal and immutable-input checks, and add an independent stable
ordered-list oracle. Preserve all other original oracle sizes and checks.

Tried: quoting a nested segment splice left `(:seg ...)` as literal data.
Join the captured prefix and suffix with union-atom before quoting the tagged
value. Two earlier probe failures were fixture syntax: an extra closing
parenthesis produced exit1 with no diagnostic, and an unquoted expected
`(+ 1 2)` evaluated to3. The corrected shape probe passes nine claims.
Receipts: ai-lib4-datastructures-shape-probe{,-fixed,-final,-passed}.log.

Verified: the public MeTTa suite passes19 tests and15 subtests, retaining the
257-key insertion,65-key deletion and128-entry heap models. Added checks cover
open/cyclic host input, malformed and cross-kind values, variable identity,
literal data, one-occurrence removal, zero-to24 queue arguments, alternative
rewrites and reconstructed/specialized equations. No engine or scoped state
change is needed. Receipt: ai-lib4-datastructures-native.log.

Verified: Python's23 model/refusal cases pass. A first run failed one literal
lookup because the fixture passed a returned collection containing runnable
syntax into a fresh call without S.quote; that re-evaluates its key by ordinary
expression semantics. Quote the collection when reusing it across Python calls,
as the README now explains. The same shuffled order then passes. Ruff's single
RUF005 finding is corrected; jscpd reports no clones across307 Python lines.
Receipts: ai-lib4-datastructures-python{,-final}.log,
ai-lib4-datastructures-ruff{,-final}.log and ai-lib4-datastructures-jscpd.log.

Measured: three fresh serial processes read example3172230/twin3062504 for
59 claims. The four direct consumers are renewed after the final library
change: finger-tree323363, finger-tree-internals293952, declared-types103861,
tile-puzzle31583779. Each measurement follows an engine/lib QLF purge; load
and memory readings are recorded instead of interpreting wall time. The five
record generators pass with26 described native sources and60 libraries.
Receipts: ai-lib4-datastructures-prices.log and ai-lib4-datastructures-records.log.

Verified: all nineteen required lanes pass. The first full twins pass confirms
59 equal claims and equal stored contents, and removes five older stale points
for this library and its four consumers. It also catches one new Python
notation finding: a written MeTTa let where Python should compose the public
calls. Replace that identity witness with lookup using the same variable key;
the native and Python model suites retain the full key-order/sharing checks.
Remeasure the changed example/twin; library sources and consumer fixtures stay
unchanged. Receipts: ai-lib4-datastructures-lanes.log,
ai-lib4-datastructures-fulltwins.log and ai-lib4-datastructures-findings-diff.log.

Verified: the final three-process measurement and full twins both read
example3172046/twin3062103, with59 equal claims and equal stored contents.
This supersedes the first primary measurement above. Full twins retains258
older findings, exactly the preceding263 minus the five renewed points for
Datastructures and its direct consumers; there are no added findings.
Twins-selftest and all five record generators pass. Receipts:
ai-lib4-datastructures-price-final.log,
ai-lib4-datastructures-records-final.log,
ai-lib4-datastructures-fulltwins-final.log and
ai-lib4-datastructures-findings-final-diff.log.

## 2026-09-13: literal code manipulation through the existing basis

The concrete symbolic caller needs exact arbitrary-term replacement with root
precedence, shared variables and every matching rule. atom-subst replaces one
written variable; is-member unifies; is-alpha-member tests unifiability despite
its name. Pairs already supplies exact lookup and all duplicate rows. Functional
supplies literal flattening, so variable collection composes filtering and
unique-atom. Python's Atom.vars, Atom.map and Atom.subs already inspect data;
map/subs are bottom-up and subs has one replacement per key, which differs from
this caller's topmost answer bag.

Found: Strategy rejects lambda values and its metta call evaluates an eager
callback's operand, handing3 to a rule inspecting (+ 1 2). Ordinary application
of a bound operand preserves the original syntax for eager, held and lambda
callbacks. Co-importing Strategy and Pairs exposes the two repeat/2 definitions:
zero numeric repetitions exceeds an explicit100000 inference envelope.
Receipts: ai-lib4-reflect-before.log and ai-lib4-reflect-shape.log.

Decided: keep Strategy's plan algebra and derive its traversal with map-atom,
segment positions and ordinary calls. Make sequence and choice variadic; rename
the direct rewrite loop to strategy-repeat while retaining the held repeat plan.
Add alltd, whose root-success stops descent, following Stratego's existing law:
https://github.com/metaborg/stratego/blob/35009963ebc99c4fa8c93cae064309186a877d0e/strategolib/trans/strategy/traversal/simple.str2#L306-L308
Reflect's atom-replace composes alltd with pairs-lookup over ordinary pairs.
No new substitution interpreter or Replace record is needed. Variables are
structural occurrences, including binder syntax; lexical capture avoidance is
not implied. The changed condition is the supplied concrete code-as-data caller.

Tried: an unquoted structural case over defined plan names. Case deliberately
supports functional patterns: it executed seq before selecting id and lowered
all into a partial application. The resulting example exceeded its8GiB stack.
Quote both the case subject and its keys; a four-case probe then preserves
literal constructor names and segment matching. An initial variadic arrow put
the splice before a final Atom, which the final_arrow_splice rule refuses.
One required Atom followed by a final Atom splice describes the same positive
arity language. These are language rules, not host workarounds. Receipts:
ai-lib4-reflect-strategy-{examples,examples-fixed,compiled}.log and
ai-lib4-reflect-literal-case.log.

Found during verification: Minimal's eval takes one equation step, so the old
typed function frames expose a newly ordinary strategy-eval body as data.
Derive those type queries and filters with ordinary let/match/if as well.
Ordinary callbacks can return the explicit Empty sentinel, which Strategy
interprets as a decline at its callback boundary. A nested equation head in a
partial-application fixture is rejected with an atom type error; use a normal
multi-argument equation and its partial application. The15 Reflect native cases
already pass after quoting; Strategy's remaining failures exercise these
integration boundaries. Receipt: ai-lib4-reflect-native-quoted.log.

Verified: all13 Strategy cases,15 literal-term cases,20 engine-reflection cases,
both Strategy examples and the extended Reflect example pass. The Python model
passes25 cases with seed473239404 after two model corrections. Native decoding
renames returned variables, so compare each answer together with its original
variable context up to alpha equivalence; alpha comparison of the answer alone
would miss broken sharing. Bind a literal Error answer before packaging it:
an eager lambda argument propagates Error before the packaging body runs.
Receipts: ai-lib4-reflect-native-final.log, ai-lib4-reflect-python-literal-model.log,
ai-lib4-reflect-strategy-examples-composed.log and ai-lib4-reflect-example.log.

Supersedes the Empty-sentinel choice above: the complete literal audit found
atom-replace(a,((a Empty))) returning a. A rule's no-answer result must differ
from a literal symbol. Removing the callback filter alone is insufficient:
collapse-bind invokes the engine's ordinary answer collector, which prunes bare
Empty. Collect one-element expressions and unwrap after restoring bindings.
This follows the engine's aggregation semantics and adds no host workaround.
Every caller that meant strategy failure now writes (empty). The new native
regression first loses three of four replacement combinations, then passes;
all16 literal-term and13 Strategy tests pass. Receipts:
ai-lib4-reflect-empty-{before,layers,regression-before,fixed,boxed}.log.

The phrasebook initially refuses three new Strategy declarations because its
separate _STRATEGY_LAWS table lacks their names. Every Strategy head now has
an @doc, so derive the explanation from that same declaration row instead of
maintaining another registry. Render parameter splices from the arrow. The
generator still refuses a missing description; positive and negative controls
cover a newly declared head and a removed @desc. The existing381-row phrasebook
denominator is unchanged. The pow-math note now describes its already-shipped
integer-preserving behavior while retaining the existing floating example.

README validation caught executable expected values and an equation-shaped let
pattern that evaluates instead of destructuring. Quote the literal expectations
and reconstruct a function directly in match's template, as the catalog example
already does. The resulting13 checks pass before the Empty examples are added.
Receipts: ai-lib4-reflect-readme{,-fixed,-literals,-final}.log.
Ruff passes; jscpd finds0 clones across1380 lines in four Python files. These
tools do not claim semantic clone coverage for MeTTa or Prolog.

## 2026-09-14: verified literal rewriting and derived Strategy documentation

Verified: 49 native tests, 26 Python model cases and 15 README claims pass.
The three examples pass; Reflect proves59 claims and Strategy internals23.
Fresh measurements read example1194613/twin1256535 for Reflect and
example395582/twin389508 for Strategy. The latter supersedes the intermediate
21-claim measurement. Full twins confirms equal claims and stored contents;
its257 findings are exactly the preceding258 minus the renewed Strategy point,
with no additions. Receipts: ai-lib4-reflect-native-empty-final.log,
ai-lib4-reflect-python-empty-final.log, ai-lib4-reflect-readme-complete.log,
ai-lib4-reflect-price-final.log, ai-lib4-reflect-strategy-price-final.log,
ai-lib4-reflect-fulltwins.log and ai-lib4-reflect-findings-expected.log.

All nineteen required lanes pass after two unused mock parameters are replaced
with keyword capture. The new strategy-choice-tail declaration needed an
executable caller; two internals claims supply it. The Reflect twin's binder
fixture is an ordinary tuple containing the let symbol, which both preserves
literal syntax and satisfies the Python notation rule. The generator's27 tests,
fn-sync's20 tests and reference's4 tests pass. Receipts:
ai-lib4-reflect-lanes-final.log, ai-lib4-reflect-ruff-complete.log,
ai-lib4-reflect-phrasebook-tests-complete.log,
ai-lib4-reflect-generated-checks.log and ai-lib4-reflect-twins-complete.log.

The final documentation review found five stale unary Strategy forms beside
the new two-argument signatures. Remove those forms and their unused metadata
field; the executable phrasebook rows already use held plans and explicit
terms. The source-derived Strategy table remains the authoritative inventory.

Verified after that removal: the full phrasebook gate has0 findings, its27 tests
pass, and fn-sync, reference, their24 selftests, Ruff and evidence pass.
Receipts: ai-lib4-reflect-phrasebook-final.log,
ai-lib4-reflect-phrasebook-tests-final.log and
ai-lib4-reflect-generated-checks-final.log. The library code and measured
fixtures are unchanged.

## 2026-09-14: derive exact additive conditioning in Statistics

The remaining Combinatorics provider is an exact probability algorithm. The
September5 journal maps it to polynomial coefficients and forward/backward
messages. Retain its sparse target-truncated rows and two-pointer convolution;
move the operations to Statistics with the other probability laws. The changed
condition is the package-wide ruling to derive from the MeTTa basis even when
the current engine needs more inferences. No approximation or subset enumeration
is introduced.

Found: is-ground is already a builtin. The fresh builtins() census lists307
heads. Ordinary pairs represent coefficient rows, while map/filter, folds and
unfold express their transitions. The candidate carrier can remain literal
syntax throughout validation and normalization. A ten-case probe preserves
runnable IDs and shadowed candidate/ratio names, distinguishes1 from1.0, and
merges empty and nonempty rows. Its first load refused a guessed binary
math-gcd call; the actual public operation takes an expression of integers.
Baseline native5 and Python10 pass. Receipts:
ai-lib4-weighted-builtins.log, ai-lib4-weighted-shape{,-fixed}.log,
ai-lib4-weighted-native-before.log and ai-lib4-weighted-python-before.log.

Decided before implementation: keep exact integer coefficients, canonicalize
ratios with math-gcd/floor-div, and avoid host rational construction because its
size-limit policy would change the contract. Mass retains a running row;
posterior retains prefix/suffix rows and maps their joins. O(NR) describes
coefficient arithmetic and retained posterior cells, not engine inference cost.
The implementation owns no mutable state or scoped value. Existing exhaustive
properties and the24-candidate/13-cell regression remain required evidence.

Found during verification: exact mass, the24-candidate row bound, all12
Combinatorics cases with73 subtests and all17 existing Statistics cases pass.
Four weighted cases fail because every inclusion marginal is zero. The join's
partial step works directly and through a lambda, but produces no unfold steps;
a plain-variable wrapper also fails, excluding the initial patterned-parameter
hypothesis. Receipts: ai-lib4-weighted-native.log,
ai-lib4-weighted-convolution{,-curried}.log and ai-lib4-weighted-python.log.

The shared boundary is apply-to: its inputs already are values. cons-atom builds
the call and reduce dispatches those finished arguments. Six probes preserve
native arithmetic, held/eager functions, lambdas, partial applications and shared
variables. Routing unfold through that boundary preserves literal runnable and
Error seeds as well. Apply the same correction to Functional's other callback
operators. A direct computed-head segment call was considered but this cut
retains the marker as one operand; reduce already provides the needed semantics.
Receipts: ai-lib4-weighted-bound-callbacks{,-reduce,-layers,-value-apply}.log.

The seven refusal tests initially expect EngineError, but the binding classifies
core assertions as AssertionFailure, a distinct language outcome. Require that
precise type and retain every remedy check. The generator initially refuses the
orphaned Combinatorics face after its provider is removed; retire the generated
region with that provider. Regeneration then reports25 described sources,
17 private sources and0 findings. Receipt: ai-lib4-weighted-face-final.log.

Verified after sharing value application: all15 weighted native cases pass,
and31 of32 Python weighted/collection cases pass. The new complete callback
matrix isolates two remaining data-evaluation boundaries. Grouping a literal
Error key propagates the freshly computed key through equality, leaving every
item in the remainder and recursing. Bind the key before comparing it, as the
literal equality probe already does. The named native reverse call evaluates
returned candidate syntax when the caller defines candidate/ratio; applying
reverse through apply-to retains the returned data. The shadowing probe then
isolates that boundary from normalization, row construction, zip and marginal
arithmetic, which already preserve the syntax. Receipts:
ai-lib4-weighted-functional-native.log, ai-lib4-weighted-functional-python.log,
ai-lib4-weighted-functional-layers.log and ai-lib4-weighted-shadow-reduce.log.

Verified after both corrections: weighted15, Functional17 with79 subtests,
Combinatorics12 with73 subtests and Statistics17 all pass. The32 Python
weighted/collection cases and the extended11-claim example pass. Every original
exhaustive bound and property remains. Receipts:
ai-lib4-weighted-native-final.log, ai-lib4-weighted-python-final.log and
ai-lib4-weighted-example-final.log.

Measured: the new eleven-claim twin costs1755787 against example1749167,
minimum of three fresh processes. The literal import closure identifies18
affected twins; all complete three runs, and17 existing points move. Functional
costs1189061 against1173251 in its isolated content audit. Its existing three
surplus atoms per side remain the tick helper's let/let* lowering and two unfold
specialization atoms. Normalizing only lambda_63/lambda_65 makes those two atoms
identical; their body now calls apply-to. Renew the divergence digest for that
specific source change, not for a new semantic discrepancy. Receipts:
ai-lib4-weighted-primary-measure.log, ai-lib4-weighted-consumers.log,
ai-lib4-weighted-prices.log and ai-lib4-weighted-functional-content-final.log.

Verified: all nineteen required lanes pass. Random16 and effects_lattice26
native cases pass, as do110 Python Random/effect/recording/world cases. These
checks retain seed, replay, effect admission, cancellation and callback behavior
after the shared application change. Ruff passes and jscpd finds0 clones in the
three changed Python files,530lines at8lines/70tokens. Receipts:
ai-lib4-weighted-lanes.log, ai-lib4-weighted-effect-{native,python}.log,
ai-lib4-weighted-ruff.log and ai-lib4-weighted-jscpd.log.

Verified: full twins reports257 older findings over311 pairs, and its selftest
passes. The new weighted pair has11equal claims, equal stored content and its
exact inference pin. Comparing the complete diagnostic multiset initially
raises AssertionError because eight existing empirical-protocol refusals name
the new311-pair protocol instead of310. An explicit eight-path comparison
changes only that current-protocol count and confirms no added or removed
findings. No empirical envelope is repinned by a point measurement. Receipts:
ai-lib4-weighted-fulltwins.log, ai-lib4-weighted-findings-diff.log and
ai-lib4-weighted-findings-expected.log. The whole lane still exits1 with
GATE FAILED: twins; that result is retained rather than reported as a pass.

## 2026-09-14: grammar plans compile to ordinary parser functions

The September12 design made grammars data but kept their composition in a native
interpreter. The changed condition is the package-wide ruling to derive the
library through MeTTa even when it needs more inferences. Hutton and Meijer's
parser is an input-to-value/remainder relation; PeTTa already supplies dependent
composition and nondeterministic answers. Primary source:
https://github.com/haskell-pkg-janitors/polyparse/blob/ac51dcebcdeeffea21cc4094513564d9247646c3/src/Text/ParserCombinators/HuttonMeijer.hs .
Use its relation/composition model, retaining both alternative streams instead
of its derived first-result choice. No source is copied.

Tried: the native seven-test suite still passes. A separate literal probe maps
to Symbol$skip and receives(), while cat drops that value and many(skip(lit"x"))
over"xx" leaks($skip $skip). Greedy many(cat)over empty text exceeds100000
inferences without answering. Receipts: ai-lib4-parsing-native-before.log,
ai-lib4-parsing-old-boundaries.log and ai-lib4-parsing-nullable-before-fixed.log.
The nullable probe's first suite load used the wrong working directory and
reported source_sink '../../lib/lib_parsing/lib_parsing.pl' does not exist;
loading the provider directly establishes the reproduction.

Tried: a twelve-claim MeTTa callable probe retains duplicate alternatives,
longest-first prefixes, empty sequence/choice, skipped repetitions, literal
Error/Empty and shared variables. Its first sequence binder reused a name for
both the input collection and its tail; the engine correctly refused mixed_roles.
Separate names pass every claim. Receipts:
ai-lib4-parsing-callable-shape{,-fixed}.log. No engine correction is needed.

Decided before implementation: one metadata relation supplies the26form names,
argument kinds and parsing functions. A generic analysis validates and prepares
closures; it never runs a parsing callback or ref target. grammar-parser exposes
the function value. Each answer holds an optional value contribution and its
remainder, distinguishing skip from every payload. The common closure checks
that result shape; ordinary let/apply-to composition implements the operators.
String supplies character conversion and numeric conversion. Decimal lexical
rules, ASCII spans and four quoted escapes are MeTTa recipes, so the native
Parsing provider can be removed completely.

Decided: retain all existing named tests and generated bounds. Correct the
sentinel collision and leak; reject a repeated step that does not shorten its
input with a named consumption remedy. Left recursion remains the caller's
contract. Empty alt becomes a well-formed parser with no answers, the identity
for variadic nondeterministic choice. These cases get explicit regression
evidence. No scoped state, resource owner or host workaround is introduced.

Tried: all58 original example claims pass. The first expanded native run has
14passing tests and one error: atomics_to_string/3 called from a deterministic
procedure failed. The old test supplied a prebound empty remainder to a native
output; the public functional fixture must produce the complete prefix answer
before filtering its remainder. Retain the original200x8case comparison in
that direction. Two single-result checks also need invoke/1 or once/1 to avoid
choicepoints, which the native runner refuses even when every assertion passes.
Receipts: ai-lib4-parsing-example-metadata-fixed.log and
ai-lib4-parsing-native-{initial,values}.log.

Tried: the first Python model run has11failures and13passes. A native partial
closure returns as (partial parsing-close (parsing-any ())) and applying that
printed expression has no answers. A written lambda preserves code and captures
through the same Python round trip and composes inside MeTTa too. Use written
lambdas for prepared parsers. A callback's held underapplication must be evaluated
when parsing reaches it, then applied to finished argument values. The same
normalization serves map, char-if, ref and metadata-supplied functions. Receipts:
ai-lib4-parsing-python-initial.log and
ai-lib4-parsing-callable-roundtrip{,-fixed}.log.

Tried: defining (lit $text) changes lit's metatype from Symbol to Grounded under
PeTTa's function-name semantics. Reject variable or expression heads and match
the identifier against metadata; a function name remains a valid literal grammar
identifier. Argument-kind membership is by identity, so an unbound metadata kind
cannot unify with the first case. Preparation still runs no callbacks.

Tried: written lambdas expose a mistaken use of superpose-bind on an ordinary
collection. That operator extracts the first field of a non-pair expression,
so alternatives produce |-> instead of a parser and collections-expression
refuses that atom. Enumerate parser occurrences with index-atom and range;
binding packets are unnecessary. The revised native suite has16passing tests,
and Python has25passes, including100independent grammar-model cases and60literal
tree cases. The expanded example has74passing claims. Receipts:
ai-lib4-parsing-native-values.log, ai-lib4-parsing-python-values.log and
ai-lib4-parsing-example-extended.log. The native runner still flags its two
choicepoints in that receipt; final verification follows their fixture repair.

Tried: adding an unbound metadata-kind test corrects the membership claim above.
Core is-member is relational and binds that variable to all three known kinds;
one() reports more than one answer. Explicitly reject a variable kind before
membership, keeping the known kind collection quoted. No public collection
semantics change is needed. Receipt: ai-lib4-parsing-python-final.log.

Verified: all16native tests pass without choicepoints, and all27Python cases
pass, retaining the100grammar-model and60literal-tree examples. All74example
claims and the README's four MeTTa results and one Python assertion pass.
The nineteen required lanes pass; jscpd finds no clones in511Python lines.
The import closure finds only Parsing's own twin. Receipts:
ai-lib4-parsing-native-kinds.log, ai-lib4-parsing-python-kinds.log,
ai-lib4-parsing-example-extended.log, ai-lib4-parsing-readme.log,
ai-lib4-parsing-lanes.log, ai-lib4-parsing-jscpd.log and
ai-lib4-parsing-consumers.log.

Tried: full twins reports260findings against the preceding257. Two new findings
correct the Python example: use a shared-context identity comparison directly,
and represent the unreachable ref assertion as literal tuple code. The third
is an HTTP point overrun,325260against324253with allowance4, while its example
and twin still prove41claims and have equal stored content. HTTP and its source
dependencies are unchanged by Parsing. A fresh three-run HTTP measurement
reaches324251, within the existing allowance; its point stays unchanged.
Receipts: ai-lib4-parsing-fulltwins.log, ai-lib4-parsing-findings-diff.log and
ai-lib4-parsing-http-control.log.

Measured: the final Parsing twin reaches4666705inferences, minimum of three
fresh serial processes, after its two authoring corrections. Its74claims and
stored content match the example; the standalone twins check reports0findings.
The initial expanded measurement was4666804, before the99-inference authoring
change. Receipts: ai-lib4-parsing-price{,-final}.log and
ai-lib4-parsing-twin-final.log.

Verified: the final full twins run reports257findings over311pairs. The complete
diagnostic multiset matches the preceding weighted run, with no added or removed
findings. Twins-selftest passes. The whole lane remains red for those recorded
older findings and exits1 with GATE FAILED: twins. Parsing's74claims, equal stored
content and exact4666705point pass. Receipts:
ai-lib4-parsing-fulltwins-final.log and ai-lib4-parsing-findings-final.log.

## 2026-09-14: Vector construction follows the answer stream

Goal: derive construction and the normalized-dot spelling through the existing
MeTTa basis while preserving the numeric and seeded contracts.

Decided before implementation: keep ten exact numerical kernels and derive
vector-fill, both random-normal-vector arities and cosine-of-normalized. The
native kernels round only the final exact result and preserve IEEE signs and
classes. Composing the exposed scalar operations would round each intermediate.
Math already imports Vector's conversion and fractional root; importing Math
back into Vector would introduce a dependency cycle. The kernel's licensed
CPython rounding sources and host-workaround reproductions remain unchanged.
Design snapshot:031f5cf5da5b5df87b365a15bad331be6cf5d528.

Tried: the first range probe returned one7for count0. builtins() has no range;
the unimported range expression was one unreduced answer. Import Combinatorics
explicitly. Core division also returns a float, and the MeTTa reader treats
SWI's1r3notation as a symbol. Obtain the rational fixture from vector-divide.
The corrected candidate agrees exactly with two native seeded constructions,
retains rational fill and signedzero, and validates before consuming entropy.
Receipts:ai-lib4-vector-recipes-probe{,-imported,-rational}.log.

Decided: fill collapses a range; random construction folds core random-float
answers with cons-atom before normalization. The generator is a let body so
each range answer triggers one fresh draw. Negative counts normalize the
unchanged accumulator. Empty vector-scale validates each Number without doing
arithmetic. Count refusals are named MeTTa assertions; numeric refusals name the
supplying vector-scale or dot. No additional random provider or scope key exists.

Tried: all33original native tests pass on the first implementation, while new
reflection fixtures expose two authoring mistakes. Quote a lambda in match's
result and compile it after the body is bound. Python Row.count is its tuple
method, so the constructor fixture uses n/x bindings. Number parameters evaluate
arithmetic expressions; use an irreducible expression for the refusal witness.
Receipts:ai-lib4-vector-{native,python,example,reflection-probe}.log.

Verified:37native tests with12subtests pass, retaining every original exact,
IEEE, cancellation and seeded-state test. All42example claims pass. The five
twinned consumers are Vector, Math, Random, Statistics and weighted subsets;
the sole native import consumer is Math, already in this closure. Receipts:
ai-lib4-vector-native-final.log, ai-lib4-vector-example-final.log and
ai-lib4-vector-consumers.log. Final Python, lane and price results follow.

Tried: a stronger literal-accumulator witness finds that validation passed a
quoted runnable component through the eager Number argument of vector-scale,
then drew before normalization rejected the original component. A structural
expression check is required before that scalar call. The assertion evaluates
its held body after values are bound, so its finite collection must also remain
quoted. Use foldl-atom over that quoted collection; this traverses components
once rather than repeatedly indexing a range. No extra native predicate is
needed. Direct Expression arguments retain ordinary evaluation; the Python
literal witness must quote its accumulator. The repaired suite passes37tests
and12subtests, including arithmetic and entropy-producing literal components
at negative, zero and positive counts. Receipts:ai-lib4-vector-native-{literal,
values,quoted}.log and ai-lib4-vector-literal-boundary-{python,full}.log.

Tried: the wider Python consumer run passes47cases and exposes the Statistics
card's old29-head assertion. The weighted transfer added two public heads at
e1be99ea1c08f70444c1c35cada441e089777906; the correct catalog count is31. Update
that assertion and its evidence, retaining all independent numeric oracles.
Receipt:ai-lib4-vector-consumer-python-found.log.

Verified: the final Vector suite passes37native tests with12subtests and30Python
cases. Its43example claims and the README's five MeTTa results and one Python
assertion pass. The consumer suites pass47native and48Python cases. Retained
construction assertions can print diagnostics, so recordings refuse replay
even with a seed; cosine-of-normalized inherits dot's replayable effect. These
four recording cases pass in ai-lib4-vector-python-effects.log. Other receipts:
ai-lib4-vector-native-quoted.log, ai-lib4-vector-example-quoted.log,
ai-lib4-vector-readme.log and ai-lib4-vector-consumer-{native,python}-final.log.

Measured: after removing QLFs, the fresh three-run minima for the complete
five-twin consumer closure are Vector244365, Math359493, Random1150796,
Statistics40976038 and weighted subsets1757926. Every pair preserves its claim
count and stored content. Vector's standalone check reports43claims and no
findings. Receipts:ai-lib4-vector-measure-host.log, ai-lib4-vector-prices.log
and ai-lib4-vector-twin.log.

Verified: all nineteen required lanes pass. The full twins run reports257
findings over311pairs, and its complete diagnostic multiset matches Parsing's
preceding run. Twins-selftest passes; the lane remains red for those recorded
older findings and exits1 with GATE FAILED: twins. Receipts:
ai-lib4-vector-lanes.log, ai-lib4-vector-fulltwins.log and
ai-lib4-vector-findings.log.

## 2026-09-14: String recipes compose the shared text boundary

Goal: derive ordinary text recipes while preserving the complete Unicode,
coercion, overlap and empty-input contracts.

Decided before implementation: derive contains, starts-with, ends-with,
from-chars, repeat, pad-left, pad-right, center and similarity. Padding shares
one equation parameterized by the function assigning padding to the left;
its three callers choose all, none or half. Repeat collects a range and joins
once. Empty text validates its count but needs no traversal. Similarity uses
the exact distance provider and retains 1.0 for two empty strings. Public names,
34 heads and 37 arities stay unchanged. Snapshot: e289439f372a0323d8959e619c7562c480bd072e.

Rejected: a second implementation of the licensed text and metric providers.
RapidFuzz 3.3.4 already owns exact unit-cost edit distance; the shared KMP code
owns search, count, split and replacement. Host grammars own Unicode mapping,
layout and templates. Retaining those authoritative implementations avoids
duplicating their maintenance; speed alone would not justify this boundary.
Revisit if a common MeTTa representation can replace the provider and its
complete contracts at lower total description cost.

Tried: 26 candidate claims pass against the original native face, including
Unicode, numeric coercion, huge empty outputs, empty/long suffixes, negative
counts, fractional refusals and literal nontext inputs. Existing native suites
also pass. Native consumers import only retained metta_text/2 and string-lines/2;
the MeTTa import closure names 27 twins. Receipts:
ai-lib4-string-recipes-probe.log, ai-lib4-string-native-control.log and
ai-lib4-string-consumers.log. Design:ai-lib4-string-derivation-plan.md.

Tried: the implementation passes 36 native surface tests with 3 subtests, all 58
legacy text/file/JSON tests with 8 subtests and 50 example claims. Python initially
passes 19 cases and fails two refusal fixtures with Failed: DID NOT RAISE
MettaError. Bool and String literals in a Number position return the engine's
typed Error value before the body runs; fractional Numbers reach the assertion
and raise. Preserve both behaviors and test their exact distinct outcomes.
The direct eval/fn/catch probe confirms the boundary. Receipts:
ai-lib4-string-native.log, ai-lib4-string-example.log,
ai-lib4-string-python.log and ai-lib4-string-count-boundary.log.

Verified: all 21 Python cases pass, retaining the 120 Unicode, 80 line and
80 edit-distance generated cases, and adding 100 padding/repetition cases.
The README's eight MeTTa results and one Python assertion pass. The six native
consumer suites pass 205 tests with 100 subtests; their Python counterparts
pass 121 cases. All nineteen required lanes pass. jscpd finds no clones in
314 Python lines. Receipts: ai-lib4-string-python-types.log,
ai-lib4-string-readme.log, ai-lib4-string-consumer-{native,python}.log,
ai-lib4-string-lanes.log and ai-lib4-string-jscpd.log.

Tried: explicitly calling main also runs its initialization(main,main), giving
two complete benchmark traversals. The final command supplies -g true -t halt
and runs it once. All 24 search/replacement cases still match their exact
expected values after moving fixture construction outside the public recipe.
Native comparison costs remain opaque to Prolog inference counters; the CPU
figures are descriptive only. Receipts: ai-lib4-string-benchmark{,-final}.log
and ai-lib4-string-benchmark-host.log.

Measured: all 27 consumer twins have fresh three-run inference minima; none
changes its stored-content divergence. String reaches 329461 inferences against
the example's 325512, proves all 50 claims, has equal stored content and reports
zero standalone findings. Receipts: ai-lib4-string-measure-host.log,
ai-lib4-string-prices.log and ai-lib4-string-twin.log.

Verified: the full twins lane reports 257 findings over 311 pairs. Its complete
diagnostic multiset matches Vector's preceding run, with none added or removed.
Twins-selftest passes; those recorded older findings keep the lane red with
exit 1 and GATE FAILED: twins. Receipts: ai-lib4-string-fulltwins.log and
ai-lib4-string-findings.log. The String pair retains all 50 claims, equal stored
content and the exact 329461 inference point in that full run.

## 2026-09-14: Encoding derivation and native UUID consumers

Goal: derive byte formulas through the MeTTa basis while preserving strict
byte/text boundaries and the exceptions that control evaluation.

Tried: a temporary wrapper on each actual decoder injects cancellation,
resource_error(stack) and an unrelated representation error after input
validation. Both library catch-all handlers replace all three with malformed
data errors. The probe restores each wrapper and ends with present; no timing
race or deadline is involved. Receipt: ai-lib4-encoding-control-before.log.
The defect belongs to these handlers, so it is not a host workaround.

Tried: the retained UTF8 provider rejects malformed sequences with
representation_error(utf8) or representation_error(unicode_scalar_value).
The host base64 provider fails normally, raises syntax_error(base64_char(...)),
or raises representation_error(encoding) when ISO-Latin1 cannot carry input
text. Valid NUL and supplementary UTF8 values still round-trip. Both standard
padded and URL unpadded base64 policies are probed. Receipt:
ai-lib4-encoding-malformed-probe.log. The existing Encoding and UUID native
suites pass before changes in ai-lib4-encoding-uuid-native-control.log.

Decided for exception handling: convert only those demonstrated malformed-input
cases to the existing named domain errors; propagate cancellation, resources
and unrelated exceptions unchanged. The boundary will have deterministic
injection regressions as well as malformed-input cases.

Found: UUID imports Encoding's native hex heads for name hashing and byte
conversion. A derivation must include those compositions; deleting exports
alone would break the native consumer, and adding hardcoded calls upward into
MeTTa would reverse the library dependency. Its strict UUID parser can remain
the shared boundary while byte/name formulas become ordinary equations.
The complete Encoding/UUID split is still under examination.

## 2026-09-14: shared byte boundaries and inspectable UUID composition

Tried: MeTTa hex and UUID recipes pass22 assertions including every byte value,
mixed-case ASCII digits, malformed alphabets, complete UTF8/NUL names and custom
namespaces. Measuring128 generated v4 identifiers gives one inference cost for
each query:14949 for version and14924 for variant. Commands and fixtures are
ai-lib4-encoding-uuid-recipes.metta and ai-lib4-uuid-inference-probe.pl; the latter
exits0 and ends with stable. String's native alphabet lookup removes the former
hex decoder's data-dependent Prolog branches. This changes the condition behind
the2026-09-12 decision to keep field inspection native.

Decided: Encoding keeps the UTF8/base64 providers and private strict byte/text
identity boundaries; hex is an ordinary alphabet, arithmetic and segment recipe.
UUID keeps generation, strict validation and the host timestamp. Its namespace
relation, byte formatting, name hashing and bit fields are MeTTa compositions.
One layout value supplies both native validation and formatting. The complete
UTF8 name workaround moves with its composition. Native modules no longer need
an upward evaluator call or their own duplicate hex implementation.

Rejected: using base64 to validate bytes, duplicating byte/hex validators, or
loosening Encoding inputs to String's Number coercions. Each would add an
unrelated operation or another authoritative boundary. Malformed recipe shapes
use named MeTTa assertions; host providers retain their precise malformed errors
and propagate interruption/resource exceptions.

Tried after implementation: all original39 Encoding and45 UUID example claims
still pass; adding reconstruction, alternatives and NUL claims gives43 and49.
The first native fixture constructed a lambda before match bound its body, so
it returned the body as data. The existing Vector pattern quotes the constructor
and evaluates it after matching; using that pattern passes all10 Encoding and11
UUID tests. Python likewise distinguishes the Number-in-String Error value from
a Symbol rejected by the strict byte-list boundary. The corrected36 cases and
all nine README values plus two Python blocks pass.

Found by extending provider injection: unification-based exception classification
can instantiate an unknown formal, representation kind or context into a known
codec error. Four of twelve cases are misclassified in
ai-lib4-encoding-control-nonground-before.log, which ends with present.
Decided: use subsumes_term against the error-pattern relation, so classification
cannot bind an incoming exception. The regression includes nonground throws.

Verified: Encoding10, UUID11 and URI12 native cases,38 Python cases,43/49 paired
claims, nine README values and two Python blocks pass. All19 required lanes
pass. Three fresh measurements give Encoding243765, UUID1291086, HTTP369064
and URI262887, with equal stored contents. No divergence declarations change.
Receipts: ai-lib4-encoding-uuid-{native-final,python-final,lanes,prices,twins}.log.

Found during full verification: both full runs add one HTTP import SIGSEGV to
the preceding257 findings. The core places PL_unregister_atom inside table
cleanup during PL_thread_destroy_engine; Python is still in library import.
Sixty-four isolated HTTP runs and a cold-artifact run pass. A plain SWI probe
that loads no PeTTa reproduces the same instruction and teardown stack:
`swipl -q -s ai-tmp/ai-lib4-table-destroy-agc.pl -g
'forall(between(1,20000,Round),observe(Round)),writeln(absent)' -t halt`, exit139
in ai-lib4-table-destroy-default-current.log. Disabling automatic atom collection
passes2000 engine lifetimes. The installed SWI binary remains unchanged.
Three runs from the pristine c75181adc control do not observe this intermittent
host race; they do not establish its absence. The explicit collector experiment
also finishes after correcting its mailbox call to thread_get_message/3.

Decided: retain the crash receipt and plain-host reproduction for the host owner;
do not alter global atom collection or library behavior to suppress it. The two
full logs have258 findings, exactly257 older findings plus the attributed host
crash; twins-selftest passes. The native fix remains outside this worktree's
library scope. Receipts: ai-lib4-http-{backtrace,unregister-disassembly}.log,
ai-lib4-encoding-uuid-fulltwins{,-repeat}.log and
ai-lib4-table-destroy-{default-current,no-agc,cut-1,cut-2,cut-3}.log.
