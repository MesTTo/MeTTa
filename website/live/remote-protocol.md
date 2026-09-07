<!--
Purpose: specify the HTTP remote-space protocol and its satellite cursor lifecycle.
Guarantees: comparisons distinguish eager core queries from remote satellite streaming.
[tested: npm run docs:build; commit=ec64336e16ebb0299f9794d277daaee3cf234493]
-->

# The remote space protocol

`metta.remote.serve()` exposes spaces over HTTP and `attach()` consumes
them, and the wire between them is small enough to implement in an
afternoon in any language. This page is the contract for the other end:
what a server must answer so that `(match &yours ...)` in a MeTTa
program reaches atoms your process holds.

Two reference implementations ship in the repository under
`extensions/python/examples/integration/typescript_space/`: a zero-dependency
TypeScript server, and a variant whose atoms live in a MeTTaScript
space, so two MeTTa engines meet through this one interface. Both pass the
conformance kit through `attach()`.

## Operations

Eight POST operations, JSON bodies both ways. `Content-Length` is
required (no `Transfer-Encoding`), bodies are capped at 16 MiB, and the
body must be one JSON object.

| request | body | answer |
|---|---|---|
| `POST /match` | `{"space": "&self", "pattern": <atom>, "bound": <n>?}` | `{"atoms": [<atom>...]}` |
| `POST /ask` | `{"space": "&self", "pattern": <atom>, "batch": <n>?, "bound": <n>?}` | `{"atoms": [...], "cursor": <id>\|null}` |
| `POST /next` | `{"cursor": <id>, "batch": <n>?}` | `{"atoms": [...], "cursor": <id>\|null}` |
| `POST /stop` | `{"cursor": <id>}` | `{"stopped": <bool>}` |
| `POST /atoms` | `{"space": "&self"}` | `{"atoms": [...]}` |
| `POST /add` | `{"space": "&self", "atom": <atom>}` | `{"added": true}` |
| `POST /remove` | `{"space": "&self", "atom": <atom>}` | `{"removed": <bool>}` |
| `POST /add_many` | `{"space": "&self", "atoms": [<atom>...]}` | `{"added": <n>}` |

`space` defaults to `&self` and selects which of the server's spaces
answers. `add_many` carries a batch in one request, the engine's own
bulk-write law on the wire: a batch is a transport optimisation and
never a semantic one. A bulk add carries all atoms in one POST; the Python
client also reads health before a mutation to negotiate recovery.

`bound` on `/match` and `/ask` is optional and carries the caller's
answer limit. A server MAY honor it, and only exactly: at most `bound`
answers, every one a true match, which is only sound for a matcher that
filters by real unification, because truncating an over-approximated
candidate list can drop true answers past the cut. A server that cannot
honor it ignores the field entirely, which over-answers and stays sound.
A malformed bound (negative, fractional, or not a number) is a 400.

`GET /health` answers

```json
{"ok": true, "atoms": <n>, "protocol": 3,
 "capabilities": ["match", "enumerate", "add", "add-many", "remove", "stream"],
 "bound": <bool>}
```

the wire contract naming its own revision before anyone speaks it.
Revision 2 added the reflection the in-process interface already has:
`capabilities` names the operations the server admits, so a client
can ask before writing, and `bound` says whether `/match` honors the
bound field. Revision 3 adds `stream`, the ask/next/stop lifecycle
below, which every gateway at this revision speaks.
`RemoteSpace.server_capabilities()` reads it from the
client side. An error is `{"error": "<sentence>"}` with a 4xx status; an
unknown operation is a 400 naming it; a non-POST method other than
`GET /health` is a 405. With a Bearer token configured,
a missing or wrong credential is refused with a 401 before the body is
read, and the comparison must be constant-time.

## The documents a server publishes

`GET /openapi.json` answers an OpenAPI 3.1.1 document for the spaces this
server serves, so a consumer generates its client from the server rather
than from this page. It carries one path per operation, with the gateway
door's own name as each `operationId`; `components.schemas.Atom`, which is
the tagged grammar of "Atoms on the wire" below written as JSON Schema
2020-12, recursive through its `e` arm; and `x-metta-heads`, one entry per
served space listing the
heads that space DECLARES with each argument's and the result's schema.

```json
{"x-metta-heads": {"&self": [
  {"name": "users", "arrow": "(-> Number String Bool)",
   "arguments": [{"type": "number"}, {"type": "string"}],
   "result": {"type": "boolean"},
   "description": "users: who is registered"}]}}
```

The argument schemas come from one type table, the same one that decides a
generated Python stub's annotations and an Arrow column's type: `Number` is a
JSON number, `String` a string, `Bool` a boolean, and every other MeTTa type
is an `Atom`, because its values cross whole. A space that declares nothing
publishes an empty list; declaring is what puts a head in the document.

A server configured with a token carries `securitySchemes.bearer` and a
top-level `security`; without one it carries neither. The document is derived
per request from an indexed read of the `(: ...)` rows, which does not grow
with the space, so there is no cache between it and the truth.

`GET /graphql` answers the same catalog as GraphQL SDL, `text/plain`, and
`POST /graphql` executes a query against it.

```graphql
type UsersRow { x1: Number, x2: String }

type Query {
  match(pattern: String!, limit: Int, space: String): [Atom!]!
  users(x1: Atom, x2: Atom, space: String): [UsersRow!]!
}
```

`scalar Atom` carries any atom as canonical MeTTa text; `scalar Number` carries
a MeTTa number, because GraphQL's `Int` is 32-bit signed and its `Float` is a
double while a MeTTa number is exact at any width. Row fields are `x1..xn`: a
`(@param ...)` row carries a type and a description and never a name, so the
description becomes the field's, and the names are the ones the generated Python
stub and `inspect.signature` already use. A head whose name is outside
GraphQL's `[_A-Za-z][_0-9A-Za-z]*`, or that collides with a field already taken,
is listed in the OpenAPI document's `x-metta-unnameable` with the `match`
pattern that still reaches it.

The SDL is text and is published whether or not the server can execute a query;
executing needs a GraphQL implementation, which the Python server takes from
`pymetta[graphql]` and refuses by name without.

## Answers as Arrow record batches

`POST /ask` and `POST /next` carrying
`Accept: application/vnd.apache.arrow.stream` answer an Arrow IPC stream
instead of the JSON body above. The request is unchanged; a server that does
not speak Arrow ignores the header and answers JSON, which every client must
still read.

Each response is a COMPLETE IPC stream: a schema message, one record batch for
that chunk, and the end-of-stream marker `0xFFFFFFFF 0x00000000`. A fragment of
one stream is not readable on its own, and a response body is what a reader is
handed, so the chunks are one stream each at one schema rather than pieces of a
single stream. The cursor token travels in the `x-metta-cursor` response
header, and its absence ends the stream exactly as a null `cursor` does in the
JSON reply.

The columns are the pattern's variables, in the order the pattern first
mentions each, at the type the served space DECLARES for that position, then
`atom`, the canonical MeTTa text of the instantiated answer. `Number` is
`float64`, `String` is `utf8`, `Bool` is `bool`, and every other position is
`utf8` canonical text with `metta.kind=mixed` in the field's metadata; every
field also carries `metta.type`, the MeTTa type name it projects from. A cell a
typed column cannot hold is null in that column and exact in `atom`, which is
what makes the typed columns safe to read.

The schema is decided when the cursor OPENS and never changes, so a client may
read it once. That is why it comes from the space's declarations rather than
from the first chunk's cells: the next chunk's cells do not exist yet, and an
IPC stream cannot revise a schema a consumer has already read.



## Mutation recovery

Revision 3 supports an optional idempotency extension. A gateway advertising
it adds an `idempotency` object to health:

```json
{"scope": "<gateway instance>", "expires": 123456.75}
```

The client copies both values verbatim into the mutation body and adds its own
random `key`, a nonempty string of at most 255 characters. `expires` is a finite
number on the server's monotonic clock; clients must not interpret it as wall
time. The same logical mutation must reuse the entire request:

```json
{"space": "&self", "atom": ["s", "example"],
 "idempotency": {"scope": "<gateway instance>", "expires": 123456.75,
                 "key": "<random client key>"}}
```

The gateway reserves the key before executing and retains the first response
before delivery. Reusing it with a different operation, space, atom, atom batch
or expiry is refused. Identical requests replay the retained response. This
follows [Stripe's saved-result contract](https://docs.stripe.com/api/idempotent_requests)
and [AWS EC2's parameter-bound, scoped client tokens](https://docs.aws.amazon.com/ec2/latest/devguide/ec2-api-idempotency.html).

`serve()` and `Gateway()` accept `mutation_ttl` (300 seconds by default) and
`mutation_limit` (4096 entries). The expiry is issued during negotiation, so
network delay consumes part of the retention window. A full ledger refuses
new keys before execution; it never evicts a live entry to admit another.
Expired keys and keys issued by an earlier gateway instance are refused.
The ledger is in memory. Restart, expiry, and a provider's partial failure
require reconciliation with the serving application; they do not establish
that a mutation failed or that its effects were rolled back.

The Python transport performs GET health before each new mutation, followed
by its POST. Authorization policies must allow that health read. This adds a
round trip and the server's health-count work per mutation. Servers without
replay metadata remain usable, but their mutations cannot be safely resent
through automatic recovery. The client never blindly retries an unkeyed write.

A lost, invalid or indeterminate mutation response raises
`metta.remote.OutcomeUnknown`, with `outcome == "unknown"`. The server uses
`{"error": "<reason>", "outcome": "unknown"}` for an indeterminate execution.
Recover using the exception's `retry()`, which retains the original request
and returns its wire acknowledgement. Calling the original mutation method
again would create a new logical write:

```python
try:
    remote_space.add(atom)
except metta.remote.OutcomeUnknown as uncertain:
    acknowledgement = uncertain.retry()
```

A retry that remains indeterminate raises another `OutcomeUnknown` retaining
the same recovery request. An expired or restarted gateway cannot turn this
recovery into a fresh write. Without negotiated replay, `retry()` refuses to
send. A provider failure after possible effects is retained as unknown, so
replaying it never calls that provider again. A directly shared `Gateway`
requires caller serialization; `serve()` serializes requests on its worker.

## Response validation

The client validates response envelopes at the transport boundary. Boolean
fields must be JSON booleans; counts must be nonnegative integers, with
`add_many` acknowledging the exact requested count. Every atom in a response
is decoded before any atom from that response is delivered. A malformed
response raises `metta.remote.ProtocolError`, a transport failure that cannot
be turned into data by the engine's `keep` or `empty` error policies.
Malformed mutation acknowledgements instead raise `OutcomeUnknown`, because
the mutation may already have executed.

A cursor response requires a nonempty string token or `null`. A continuation
cannot change its token, exceed its requested batch or keep a short chunk
live. A failed stop acknowledgement retains the release token for retry.
If validation rejects the initial response after receiving a valid token,
the client attempts to stop it. If that cleanup also fails, both exceptions
are reported and `ProtocolError.cursor` retains the token for recovery.

## Lazy answers: the ask/next/stop lifecycle

This is the part of the contract every binding inherits, in any
language, over any transport. `/match` computes the whole answer set
before anything crosses, which is what `m.match()` does in-process.
`/ask` opens a cursor and answers the first chunk, `/next` pulls the
next one, and `/stop` releases it, which is what `RemoteSpace.stream()` does
on the satellite client. A client that wants two answers of a million-answer join
takes them and stops, and the serving engine computes two.

```
POST /ask   {"space": "&hq", "pattern": ["e", [["s","users"],["v","id"],["v","n"]]], "batch": 1}
     ->     {"atoms": [ ...one atom... ], "cursor": "Yy8mB1Rk..."}
POST /next  {"cursor": "Yy8mB1Rk...", "batch": 1}
     ->     {"atoms": [ ...one atom... ], "cursor": "Yy8mB1Rk..."}
POST /stop  {"cursor": "Yy8mB1Rk..."}
     ->     {"stopped": true}
```

The lineage is SWI's own `library(pengines)`, whose create/ask/next/stop is
the same lifecycle over the same kind of wire. It is also Tarau's engines
(*A Hitchhiker's Guide to Reinventing a Prolog Machine*, ICLP 2017), which
state it as a design law: an engine yields one answer and, if asked,
resumes.

**A batch is a chunk, a bound is a cut.** `batch` says how many answers
one reply may carry and defaults to 1, pengines' own default for the
same field. Chunking is sound for every server, because it hands back
part of an answer set with the rest still reachable. Bounding is only
sound for an exact matcher, for the reason `bound` already carries
above. A reply may carry fewer atoms than the batch and never more.

**The cursor is the continuation, and it is also the more-flag.** A
reply whose `cursor` is a string names the token `/next` and `/stop`
take. A reply whose `cursor` is `null` ends the stream: the server has
already released it, and a client that keeps the token gets a refusal
rather than an empty answer. This is what keeps the promise honest,
because a boolean "is there another one" could only be answered by
computing another one, and the whole point is not to.

**A short chunk ends the stream.** A server that has nothing further
answers the atoms it has and a `null` cursor. An empty chunk beside a
live cursor is a protocol violation, since it would spin a client
forever; the shipped client refuses one rather than looping.

**`/next` on a cursor the server no longer holds is an error, not an
empty answer.** Answering nothing would say the enumeration ended, and
under-approximating is the one thing this protocol forbids. `/stop` on
one is the plain `{"stopped": false}`, because a client calls stop from
a finally-block where the stream may have ended already, and stop is
idempotent by design.

**A cursor is server state, so it is bounded and owned.** A server releases a cursor nobody has pulled from once an idle deadline passes. It refuses to hold more than a ceiling of them at once, and releases every one it still holds when it shuts down. pengines bounds the same resource the
same two ways and picks 300 seconds for the first; `metta.remote.serve`
takes `cursor_idle` and `cursor_limit`, and the TypeScript reference
server takes `--cursor-idle` and `--cursor-limit`.

**Whether a server actually defers the work is its own affair.** The contract fixes only the shape that makes deferring possible, so a client can rely on it. A store holding ten atoms in an array has nothing to defer; a gateway over a real query engine has everything to defer. MeTTa's own gateway defers: each cursor is an SWI engine holding the
join's state between pulls, so taking two answers costs two answers'
work. Measured 2026-08-20 over real HTTP, 1,250 inferences for two
answers whether the enumeration held ten or ten thousand, against 1,839
and 1,490,407 for the eager form over the same spaces
[`test_two_answers_cross_the_wire_without_the_third_being_computed`].

**An answer set past the body cap crosses only in chunks.** Bodies are
capped at 16 MiB in both directions, so `/match` cannot answer a set
larger than that at all; the lifecycle is what carries it
[`test_an_answer_set_too_large_for_one_body_still_crosses_in_chunks`].

On the client side `RemoteSpace.stream(pattern, batch=...)` is the lazy
form and `match()` stays the eager one. The core `Space.match()` is eager.
`metta.attach("&hq", metta.remote.RemoteSpace(metta.remote.connect(url), batch=1))`
makes an attached space's matching lazy, so a MeTTa `once`
over it stops the serving engine too.

## What crosses the wire, and what does not

The in-process interface carries more than five operations, and the subset
that crosses is a decision, not drift. The projection:

| capability | on the wire | why |
|---|---|---|
| `match` | `POST /match` | the protocol's center |
| bounded match | `"bound"` on `/match` and `/ask`, advertised in health | trusted-Exact: only an exact matcher may truncate |
| streamed remote answers | `POST /ask`, `/next`, `/stop`, advertised as `stream` | lazy answers belong to the remote satellite |
| `enumerate` | `POST /atoms` | one shot: fetching everything has no early exit to protect |
| `add` | `POST /add` | |
| bulk add | `POST /add_many` | a transport batch, never a semantic one |
| `remove` | `POST /remove` | |
| capabilities | `"capabilities"` in health | reflection, ask before writing |
| `clear` | does not cross | destructive and tenant-wide; spell it `remove` with `$everything` |
| `plan` | does not cross | request-per-operation economics: a plan negotiation per match would cost more than it saves |
| pushdown classification | does not cross | the wire's match law is over-approximation, so exactness claims buy nothing remotely |
| `subscribe` | does not cross | request-response has no push channel; `lib_redis` is the standing-query story across processes |
| `rules` (equations) | does not cross | an equation compiles in the engine that stores it, and shipping source to another engine is a program migration, not a write |

## Atoms on the wire

An atom is a tagged JSON array, the same wire the local Python boundary
speaks: `["e", [["s","edge"], ["s","a"], ["v","x"]]]` is `(edge a $x)`.

`CODEC.md` in the repository root is the grammar, and it is the one
authority for it: the tags and their payloads, the identity law for
variables, the exactness law for numbers, and
`tests/codec/corpus.json`, the golden corpus your server can be run
against. A gateway speaks the CORE PROFILE, `s v n g e`. Read that page
before writing the parsing half of a server; everything below is the
HTTP half, which is this page's own.

Two of its rules bite a gateway in particular, both about answering a
different atom than the one you were given. MeTTa's numbers are exact at
any width, so a server whose JSON parser rounds past 2^53 must refuse
the payload; the reference implementation answers 400 naming the
literal. And an integer and a float are different atoms even at the same
value, `!(== 1.0 1)` being `False`, so a language with one number type
has to carry the distinction some other way or refuse it.

## Semantics a server must keep

**Match may over-approximate and may never under-approximate.** The
attaching engine keeps unification for itself and re-unifies every
candidate, which is how bindings enter the local program; answering
every stored atom for every pattern is always correct, answering fewer
than the engine's own matching is never allowed to be. That
re-unification binds raw, with no occurs check, so a repeated pattern
variable may bind to a term that contains it: `(f $y $y)` against a
stored `(f (g $x) $x)` builds a rational tree, and that candidate IS an
answer a server owes. The single cycle test the engine runs sits on the
ANSWER it builds and not on the bindings, so whether the candidate
survives is the client's decision rather than the server's. An out
template that does not carry the cyclic binding answers; the pattern
itself as the template does not. A server must not occurs-check on the
client's behalf, because refusing a candidate whose bindings the
client's template never mentions is exactly the under-approximation the
law forbids.

A server may answer candidates as the stored atoms themselves or as the
pattern instantiated by each match, both of which preserve the
pattern's answer set; the conformance suite accepts either. The one
case where the two forms part is this one: a rational tree has no
finite tagged-array form, so a server that answers instantiations
cannot encode that candidate and answers the stored atom for it
instead. A server that answers stored atoms never meets the question,
since a stored atom is acyclic.

This is what makes the protocol implementable in an afternoon:
filtering is an optimisation, not a correctness burden.
`metta.testing.check_space_provider` over an attached `RemoteSpace`
verifies exactly this, and its repeated-variable probes are the ones
that catch real matchers being subtly narrower than the law.

**Removal is by unification, one occurrence.** `remove` carries an atom
that may contain variables, and ONE stored atom unifying with it goes.
Two stored copies need two removals. That is the PROVIDER's grain and it
is finer than the language's: `remove-atom` drains every unifying
occurrence, and it does so by reading them and then asking once
for each, so a provider that takes one per call is what the engine above
it expects. Rename the pattern's and the stored atom's variables
apart before unifying: `(f $x 1)` must remove a stored `(f 2 $x)`.

**A space is a multiset.** Adding twice stores twice; `atoms` answers
duplicates; order promises nothing.

**Certifying an implementation.** `metta.testing.GatewayComplianceSuite` is this page made executable. Subclass it with a `gateway_url` fixture and every promise above is checked against your running server.

It covers the operations' semantics, the refusal ladder, the health
reflection, `bound` being honoured or ignored soundly, wide integers being
exact or refused, and the ask/next/stop lifecycle, which must answer the
eager form's answer set at every batch and refuse a cursor it no longer
holds. It also runs the conformance kit's match contract and round-trip law
through an attached `RemoteSpace`. Both reference servers pass it, and it
caught real divergences on both sides. MeTTaScript's unifier is narrower
than the wire unifier on some pairs, so its server carries the reference
unifier as a soundness envelope; over-approximating is always legal, and
that server also ignores `bound` and says so. On the other side, an early
revision of the suite itself demanded rational-tree answers, which the
occurs-checked matcher of the day never produced. Under the
per-answer template law that demand was the correct one. The suite's
own join still carries an occurs check and so skips those pairs instead
of requiring them, which means a server that drops them is not caught
here.

Measured on localhost with the reference server [2026-08-17]: a match
round trip is about 243 microseconds and an add about 216. The wire is
request-per-operation deliberately; a space whose queries are chatty
belongs behind the in-process interface instead, and `EXTENDING.md`
section 5 is that story.
