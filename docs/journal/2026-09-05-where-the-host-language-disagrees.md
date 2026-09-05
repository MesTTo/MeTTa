<!-- Purpose: record why three Node-seat mechanisms stopped using JavaScript's obvious tool. -->
# Where the host language disagrees with the other seat
Goal: three places where the Node seat reads or writes something the Python
seat also reads or writes, and JavaScript's obvious tool for the job quietly
answers something else.
Constraint: the Python seat and the engine decide the semantics. This seat
matches them; where they would disagree with each other, that is a finding
rather than a choice.

## 2026-09-05, a repeated JSON key

The seat read every wire body with `JSON.parse`. Its reviver runs after each
object is BUILT, so a repeated key has already collapsed to the last value
before anything can look at it; Python's `object_pairs_hook` is handed every
pair as it is read, and the two hosts therefore see a different document.

Asked the Python seat and the engine what the ruling is before writing
anything. It is a REFUSAL, and it is the engine's:
`extensions/python/metta/shim.pl` asks `json_codec_read/3` for `shape(dicts)`
and turns `duplicate_key(Key)` into "JSON object repeats the key <k>", pinned
by `test_json_codec_refuses_duplicate_keys` ("silently dropping the first
value would let a wire peer smuggle one value past a reader that saw the
other") and by the hazard documents in
`tests/prolog/suites/libraries/json_codec.plt`. The Python gateway reads its
body through that codec and answers 400.

Measured it rather than reading it off:

    '{"a":1,"a":2}'             ValueError: JSON object repeats the key a
    '{"a":1,"\u0061":2}'        ValueError: JSON object repeats the key a
    '{"\u00e9":1,"é":2}'        ValueError: JSON object repeats the key é
    '{"a":{"b":1,"b":2}}'       ValueError: JSON object repeats the key b
    '[{"a":1},{"a":2}]'         [{'a': 1}, {'a': 2}]

So the comparison is on the DECODED key, and two sibling objects each naming
a key once are not a repeat.

The MeTTa surface is a DIFFERENT door with a different ruling and stays as it
is: `lib/lib_json/lib_json.pl` asks the same codec for `shape(classic)`, which
keeps both pairs, and `!(json-decode "{\"a\": 1, \"a\": 2}")` answers a space
holding both. One codec, two shapes, and the wire is the strict one.

Rejected: a dependency. `json-bigint` has a `strict` option that raises on a
repeat, and `lossless-json`, `clarinet` and `@streamparser/json` all expose
keys as read. Each brings a whole number model this seat does not want, into a
package whose only two runtime dependencies are `acorn` and `swipl-wasm`, to
answer one question `JSON.parse` cannot. Revisit if this seat ever needs
lossless numbers off the wire as well, which is the same parser's other job.

Rejected: a hand-rolled parser. It would have to reproduce `JSON.parse`'s
number and string semantics exactly to be equivalent, which is a larger
surface than the question.

Decided: parse with `JSON.parse`, then walk the same text for its keys. That
is protobuf.js's shape for the same law
(`protobufjs/protobuf.js ext/protojson.js`, `checkDuplicateKeys`: "JSON.parse
keeps the last duplicate key, but ProtoJSON rejects duplicates"), whose own
tests cover the escaped-duplicate case this suite has. Two changes from it: a
`Set` rather than a null-prototype object, and a key decoded through
`JSON.parse` only when the token contains a backslash, since a backslash-free
JSON string IS its own decoding. The walk runs AFTER the parse, so it only
ever sees valid JSON and a malformed body keeps `JSON.parse`'s own syntax
message.

Both ends read through it, not just the server: `Response.json` is
`JSON.parse` too, and the Python CLIENT refuses a repeated key in an ANSWER
(`extensions/python/metta/remote.py` calls `_json.loads` on every reply).

Red, against 3c025a0e's `src/remote.ts` with `readJson` shimmed to a bare
`JSON.parse` so the cases fail on behaviour rather than on a missing symbol:
3 of 3 fail, the gateway one reading `200 !== 400` because it served the
smuggled request. Green on this tree, 3 of 3, and the seat's suite goes 578 to
581 with no other change.

Left alone, said here so the next reader does not have to re-derive it:
`src/integrate.ts`'s manifest read (a package author's `package.json`, where
npm itself is last-wins and refusing to load a package over an unrelated
repeat is worse than the repeat), `src/platform.ts` and the tools (this
package's own files), and `kit/driver.ts` (a line of protocol this
repository's own test writes).

## 2026-09-05, a float's text

`floatText` took `String(value)` and added a point when the spelling had none.
The digits are right that way, but the LAYOUT is JavaScript's, and JavaScript's
is a third spelling that neither authority uses.

The obvious target is Python's `repr`, and it is the wrong one. Reading the
Python seat is what says so:
`extensions/python/metta/_atoms_core.py`'s `_float_text` names the four places
`repr` differs from the law it implements, "the plus sign (1e+16), the exponent
padding (1e-05), the small-magnitude threshold (1e-05 where the law says
0.00001), and nan against the engine's NaN". So the target is the ARBITER's
layout, which the Python seat reaches by relaying repr's digits, and which the
engine reaches at `engine/parser.pl` `metta_float_layout/4` and again in C at
`engine/writer.c` `emit_finite_float`, both over LeaTTa
RyuLean4/Runtime.lean:371-396.

Checked that the two authorities agree before matching either. 4,030 finite
doubles (the eight hard cases, the layout's boundaries, and 4,000 generated),
printed by `swrite/2` and by `_float_text`:

    engine against Python seat      0 mismatches of 4,030
    Node seat against Python seat   796 mismatches of 4,033

Three classes, all layout and none digits: the exponent's plus sign
(`1.7976931348623157e+308` against `...e308`), the top of the positional range
(`1e16` printed `10000000000000000.0`), and the bottom of it (`1e-6` printed
`0.000001`).

Decided: port the five branches, taking the digits from
`Number.prototype.toString`. ECMAScript defines those as the shortest decimal
that reads back to the same double, ties to even, which is the same selection
CPython's `repr` and SWI's `number_codes/2` make; the 4,033-value diff going to
zero is what says the three agree in practice and not only on paper.

Left alone: `src/wire.ts`'s `numberToText`, which is the TRANSPORT spelling and
a different job. It writes `1.0e+21` where the atom now prints `1e21`, and the
cross-host kit says in as many words that this is allowed, comparing a
transport number as the number because "only the engine's own writer is
canonical about how it spells"
(`test_node_binding.py`, `_comparable_transport`). Checked it anyway: all 4,030
spellings read back through SWI to the identical double. A comment now says
why it differs, because the obvious next edit is to make it match and that
would be the wrong fix.

Red, with 3c025a0e's `src/atom.ts`: both cases fail, the first on
`10000000000000000.0` against `1e16`. Green on this tree; the seat's suite goes
581 to 583 and `test_node_binding.py`'s four cross-host cases stay green.

The sweep is in the suite rather than only in the evidence: 2,000 seeded
doubles plus one per power of ten from -20 to 24, each compared against the
engine in the same process, 67ms. The engine beside the test is the oracle, so
the cases only have to reach the branches.

## 2026-09-05, the order two hosts compute

`Array.prototype.sort` with no comparator orders strings by UTF-16 code UNIT.
Python's `sorted` orders by code POINT. They agree on the whole BMP and part on
every astral character, so a corpus without one cannot tell them apart, which
is why nothing had.

    U+1D400 (astral, surrogates D835 DC00) against U+F900 (BMP)
    python  sorted([...])   ->  ['0xf900', '0x1d400']
    js      [...].sort()    ->  ['0x1d400', '0xf900']

The comparator was already here and already right: `compareText` in
`src/atom.ts`, walking code points because SWI does, private to
`byStandardOrder`. So the fix is to EXPORT it rather than write one:
`byCodePoint`, one comparator, used everywhere the order is an answer.

Which sorts those are took a survey, and the survey found the classification
in two places that a reading of the call sites alone would have got wrong:

- `integrate.ts`'s ready set looks like a message and is not. It decides the
  order integrations install in, and the function's own comment fixes it as
  name order "so the answer is reproducible rather than dependent on which
  manifest was read first".
- `algebra.ts`'s `equational` list looks like a message and is not. It is also
  what `checkLaw` walks, so it decides WHICH counterexample an algebra failing
  two laws reports.

Two more were not a host-order question at all. `algebra.ts`'s answer signature
and `lint.ts`'s arity message sort NUMBERS with the default comparator, which
compares them as text: a head defined at 2 and at 10 linted as "defined with 10
or 2". The signature was not mis-deduplicating, because a lexicographic order
is still a canonical spelling of a set, but it was not the order the code
means. Both take `(a, b) => a - b`.

Decided: leave the sorts whose order really is only a sentence, and say so
where they stand rather than in a document nobody reads at the call site. Four
of those, plus four multiset comparisons that give BOTH sides the same order
and are therefore decided identically by any total order.

Decided: make the invariant a lane rather than a habit. A comparator-less
`.sort()` in `src/` is a finding unless the line or the comment block above it
carries `sort order is not an answer`, and the failure message names the exact
edit. The lane proves its own eyesight on a planted call and on the same call
with the declaration added, which is the shape the file's other rules already
take. Run against 3c025a0e it names all sixteen sites, which is the survey the
work started from, produced by the tool instead of by hand.

Red, with the five changed sources at 3c025a0e and `byCodePoint` shimmed to the
default order: 6 of 6 fail, the algebra one reading `(requires 𝐀 豈)` against
`(requires 豈 𝐀)` and the lint one `defined with 10 or 2` against `2 or 10`.
Green here; the seat's suite goes 583 to 589 and the browser suite stays at 9.

## 2026-09-05, the number two seats could not exchange

Found while surveying the float text above, and larger than it: the Node
remote wire and the Python remote wire could not carry a number to each other
at all.

    node   toTransport(...)     ["e",[["s","f"],["n","1.5"],["n","42"],["g","hi"]]]
    python atom.to_wire()       ["e",[["s","f"],["n",1.5],  ["n",42],  ["g","hi"]]]
    node   fromTransport(["n", 1.5])    WireError: expected text from the engine
    python atom_from_wire(["n","1.5"])  ValueError: wire number payload must be numeric

`CODEC.md`'s `n` row reads "exact integer or float" and
`tests/codec/corpus.json` holds `["n", 1.0]`, `["n", 0]` and
`["n", 9007199254740993]`, so the Node seat was the one out of spec, in both
directions at once: it SENT text and REFUSED the value. `src/remote.ts`'s
header claimed "either end interoperates with the Python seat's".

The seat has three number spellings and the defect was one layer using
another's. The ENGINE transport, flat and arity-prefixed, carries decimal TEXT
and always will: swipl-wasm's value conversion renders the float 2.0 and the
integer 2 as one JavaScript number, and `(== 2 2.0)` is `False`. The PORTABLE
transport is a JSON document and JSON can spell the two apart, so the grammar
says it carries the value. `toTransport` was handing the engine's spelling to
the portable one.

Decided: `bigint` for an integer at any width, `number` for a float, which is
the pair the seat's `Wire` type already used and the same split Python makes
with `int` and `float`. The kit's comparison form already relied on it
(`["n","i",digits]` against `["n","f",bits]`), so nothing new had to be
invented for the distinction; only the transport had to stop erasing it.

Decided: a text payload is a REFUSAL, not a legacy form with a compatibility
read. The two spellings belong to two transports, and accepting either here
would accept a document the written-down wire does not have. The message names
the tag, what arrived, and which transport spells a number as text.

    the n tag carries an exact integer or a float, not a string ("42"); this
    transport spells a number as the VALUE, and the engine's own flat
    transport is the one that spells it as decimal text

JSON's own two problems, and the mechanism for each, which is the one CODEC.md
already points at ("the TypeScript reference server does this from
`JSON.parse`'s reviver, which can see the source text of each literal"):

- `JSON.parse` has one numeric kind, so `["n", 1]` and `["n", 1.0]` arrive
  identical and `["n", 9007199254740993]` arrives rounded. The reviver's
  `context.source` is the literal's text, so an integer literal becomes a
  `bigint` and a float literal a `number`. Shipped in V8 12.4, which every
  Node this package's `engines` field admits carries.
- `JSON.stringify` writes the float 1.0 as `1`. `JSON.rawJSON` places a
  literal verbatim.

Tried: the writing half as a `JSON.stringify` REPLACER, the symmetric shape.
It looked right and was wrong, and the way it was wrong is this branch's own
subject a fourth time. `JSON.stringify` asks each value for `toJSON` BEFORE it
calls the replacer, and booting this seat's engine installs
`BigInt.prototype.toJSON`, which answers the decimal string:

    typeof BigInt.prototype.toJSON   undefined before metta(), function after
    JSON.stringify({a: 1n})          '{"a":"1"}'

So the gateway answered `["n", "1"]` for the integer 1, a string where the
grammar says a number, and the replacer was never reached. The unit probe
passed because it never booted an engine. Decided: put the literal in the
STRUCTURE first, on an explicit worklist like the file's other walks, and let
`JSON.stringify` see no bigint at all. A bigint anywhere OTHER than an `n`
payload is refused rather than handed to it.

Evidence, three layers:

- the golden corpus through both seats' codecs, both ways, every row equal: 39
  round-trip cases and 32 transport cases, no disagreement. The transport leg
  runs fewer because the JSON wire carries neither a boolean nor a non-finite
  float.
- a live exchange each way, a Python `RemoteSpace` against this seat's
  `serve()` and this seat's `RemoteSpace` against the Python `serve()`,
  carrying an integer, a float, a float whose value is whole, a negative
  fraction, and integers past both 2^53 and i64.
- both seats refusing a non-finite float on the JSON wire, in the engine's own
  sentence.

Open: the engine's refusal names the culprit with `~w`, so it says
"JSON cannot carry the non-finite number 1.0Inf" where its own writer prints
`inf` for the same float. This seat writes what the engine PRINTS, and the
test pins both spellings so the day the engine's message uses its own writer,
it says so.

Red, against af0eeb6c with `transportToJson`/`transportFromJson` shimmed to a
bare `JSON.stringify` and `JSON.parse`: 3 of 4 wire cases fail and 6 of 8
cross-seat cases fail, the client one reading
`ValueError: wire number payload must be numeric, got '0'` and the non-finite
one reading `ACCEPTED`. Green here, with the seat's suite at 590 and the
cross-seat lane at 8.

## 2026-09-05, an atom without an engine

A consumer of this package wanted `Symbol`, `Expression`, `Grounded` and the
rest without the engine behind them, and had written a shim to get there. The
exports map named thirty subpaths and none of them was `./atom`, so the only
door was the main entry, and the main entry reaches the module that boots
WebAssembly.

Measured what each door actually costs, through a `module.registerHooks`
resolve recorder in a child process, which is the ESM answer to
`require.cache`:

    import("metta-node")        166 specifiers, three of them node: builtins
                                (node:fs, node:path, node:url)
    import("metta-node/atom")   3 specifiers, none of them

So the cost is NOT swipl-wasm, which is loaded lazily by an `await import`
inside src/wasm.ts and never reached by merely importing the root. It is the
static reach into the `node:` builtins, which is what a browser bundler trips
over. Recorded because the obvious claim, "the root pulls in the engine", is
the wrong one and would have made the test assert something vacuous.

Checked the two shims the consumer wrote. The `./atom` one is answered here.
The other, a browser field for `node:util`, targets an older published
version: an installed metta-node 0.0.1-alpha.0 found in a sibling checkout's
node_modules carries `dist/present.js:24: import { inspect } from "node:util"`,
and its exports map has thirty subpaths and no browser key, while this tree's
`src/present.ts` reaches the same hook through
`Symbol.for("nodejs.util.inspect.custom")` and imports nothing. Already fixed
here; the shim can go when that consumer updates.

`src/atom.ts` imports `./errors.ts` and `./present.ts` and nothing else,
`errors.ts` and `present.ts` import nothing at all, so the subpath is browser
clean transitively without any source change. `./errors` ships beside it
because they sit on one import path and a consumer of the atom classes catches
what they throw.

Decided: no build-script edit. `tools/build-browser.mjs` derives its esbuild
entry points from the exports map, so the two new subpaths produce
`browser/atom.js` and `browser/errors.js` on their own.

Three checks, at three layers, because each can pass while another fails:

- the seat's own suite walks `src/atom.ts`'s SOURCE imports and requires that
  none leaves the package, which fails before anything is emitted;
- the browser lane bundles a consumer that imports the two subpaths BY NAME,
  so the exports map's `browser` key is what resolves, and asserts the page
  fetched no engine asset and started no engine;
- the `node-dist` lane resolves both through Node's own resolver, from a
  directory whose `node_modules` links to the package, which is the only way
  to exercise the map rather than a path the test already knows.

Red without the two entries: `Could not resolve "metta-node/atom"` from
esbuild takes all ten browser tests down, and the dist lane answers
`ERR_PACKAGE_PATH_NOT_EXPORTED`. Green with them, at 592 Node tests and 10
browser tests.

Open: `MettaError` sets `this.name` from `new.target.name`, deliberately, so a
bundler that renames the class renames the error too; the browser case asserts
`code`, which src/errors.ts pins as the stable identity, and says so where it
does.

## 2026-09-05, what the number wire cost

The whole benchmark suite, run after the wire change, put `wire-roundtrip`
outside its band as an IMPROVEMENT the two-sided harness refuses to leave
unpinned. A/B in one worktree, same configuration, to attribute it rather than
assume it:

    af0eeb6c   2,942,976,441 instructions   inside the band
    this tree  2,706,907,747               -8.02%

So it is this work's own. The portable transport stopped spelling every
numeric leaf as decimal text: a `String()` and a concat out, two regex tests
and a `BigInt()` back, per number. The measured term carries three numeric
leaves and the case runs 50,000 trips, so 150,000 numbers, and the saving is
1,573 instructions a number.

Re-pinned to 2,706,729,143 with the mechanism beside it. Only that row's two
values move; the rest of the file's diff is the shared harness normalising the
indent from one space to two, which is what `json.dump(..., indent=2)` writes
and what any `--update` would do. Checked by a semantic diff of the parsed
document against HEAD rather than by reading the textual one.

`wall_seconds_per_operation` rose in the same step and decides nothing here:
the row is an instructions row and the box was at loadavg 29 to 45 against the
loadavg 9 of the 08-28 pin.

`define-call` stays red and stays unpinned. It reads 85262 at af0eeb6c and
85262 here, identically, so it is not this work's; it is attributed elsewhere
and being re-pinned there.
