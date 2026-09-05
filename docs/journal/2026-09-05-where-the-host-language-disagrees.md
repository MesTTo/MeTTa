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
