# A bare space name poisons the plane, and three more defects a consumer met
Goal: fix four defects a downstream workspace reported against the Node seat at
0.8.0 -- a bare-named space taking every later program on an engine down, a
browser boot with no memo per root, a wasm module the browser cannot cache, and
a `file:` install that carries no engine -- at their roots rather than at the
symptom, with a lane behind each.
Constraint: two of the four came with a diagnosis attached, and both diagnoses
turned out to name the wrong mechanism. Reproduce before believing.

## 2026-09-07

### The bare-named space

Tried: reproduce from the consumer's own probes, ported into
`ai-tmp/repro-1-barespace.mjs` and `ai-tmp/probe-decoder.mjs` ->
`metta_node_decode([p,my_space_name], T)` throws
`metta_node_undecodable([p,my_space_name])`, and the reported wire
`[e,2,s,collapse,e,2,s,'get-atoms',p,my_space_name]` throws the consumer's
error byte for byte. The encoder writes that wire: with `my_space_name`
registered, `m.engine.encodeAtom(expr(collapse, expr(get-atoms, space)))`
answers exactly it.

Decided: the defect is INBOUND and is one clause,
`extensions/node/bridge.pl:344`, which demanded `sub_atom(T, 0, 1, _, '&')` of
a `p` payload. The host side was corrected when a bare name first cost the
registry read, and the file's own header has said since then that the tag
carries the registered name "ampersand-prefixed or not"; the engine-side
decoder was the one place still demanding the prefix. Two facts make the
demand wrong rather than strict: `metta_space_writable_name/1` accepts ANY atom
(engine/spaces/catalog.pl, matching upstream's
`Term =.. [Space, Rel|Args]`), and a failing decode raises
`metta_node_undecodable/1` over the WHOLE wire, so refusing one leaf refuses
every term that mentions it. That is why a workspace with one engine and one
space per program lost four of twenty-four programs rather than one.

Rejected: relaxing `metta_node_require_space_name/1` as well. It is a different
door, for a space a HOST implements through `seam:foreign_space/1`, where the
engine's own `metta_space_operand/1` tests the prefix before it probes either
registry, so an unprefixed provider name is not an error but silence. Its
demand is correct where it stands.

Tested: `decodes a space the engine registered without an ampersand` and
`walks a program that names a bare space and then another on one engine`, both
in `extensions/node/test/binding.test.ts`. The second walks
`08-spacefunction`, `09-selfprog`, `10-subtract_atom` and
`04-02/01-matchsingle` -- the four the consumer measured drawing nothing --
before and after `07-add_atom_fun_space`, each in a space of its own, and
compares. Both fail with the clause restored (`node --test
build/test/binding.test.js` -> `# fail 2`) and pass without it (`# pass 71`).

### The browser boot's missing memo

Tried: count the requests twelve boots make, in Chromium over HTTP
(`ai-tmp/measure-browser.mjs`) -> twelve `runtime.json`, twelve
`swipl-web.wasm` and twelve `swipl-web.data` per twelve boots, against one of
each once the root is prepared only once. Three runs, identical counts.
Wall clock over the twelve, on a box at load 38: 10496/14077, 10440/10392,
9456/9610 ms memoised against un-memoised, which is noise and not a result;
the request counts are the measurement.

Decided: memoise the PROMISE per resolved root, not the result. Two boots that
start together would otherwise both miss and both fetch, which is the case a
worker pool hits first, and coalescing an in-flight request is the standard
shape for a cache in front of a network read. A rejected preparation is dropped
from the table, so a refusal is never remembered.

Tested: `prepares one root once however many engines boot on it`,
`shares one preparation between concurrent boots`,
`asks again after a runtime it refused` and
`forgets a prepared root when asked to`, in `tools/browser.test.mjs`.

### The wasm module the browser recompiles

Tried: time `WebAssembly.compile(bytes)` against
`WebAssembly.compileStreaming(fetch(url))` across page loads of one persistent
profile -> 5-15 ms either way for a 2.1 MB module. That is not compilation. V8
compiles wasm functions LAZILY and tiers up on background threads, so the
compile call returns before the work happens.

Tried: time the whole boot instead, six page loads per arm, streamed against
compiled-from-bytes -> 1245 ms against 1225 ms as the minimum of the five warm
loads, on a box at load 56 where the streamed arm's own spread was
1245..2669 ms. No result either way.

Tried: ask V8 rather than a stopwatch. Chromium's `v8.wasm` trace category
emits the compilation pipeline's own events
[source: https://v8.dev/docs/wasm-compilation-pipeline], collected over CDP in
`ai-tmp/measure-wasmtrace.mjs` -> on a boot-and-stop workload, `wasm.Deserialize`
appears on NO load of either arm and `wasm.CompileBaseline` is 1061 on every
load. The cache was never written, and the reason is in the same page: "code
caching gets triggered whenever the amount of generated TurboFan code reaches a
certain threshold", and only ~180 of 1061 functions had tiered up in a 1.3 s
boot.

Tried: the same trace with the module made HOT first, 4000 directives after the
boot (`ai-tmp/measure-wasmtrace2.mjs`) -> the arms separate completely.

    streamed  load 1 (cold)  1062 CompileBaseline  1062 CompileLazy  290 TopTier   no Deserialize
    streamed  load 2 (warm)   812 CompileBaseline     1 CompileLazy  102 TopTier    1 Deserialize
    streamed  load 3 (warm)   812 CompileBaseline     1 CompileLazy  100 TopTier    1 Deserialize
    bytes     load 1         1061 CompileBaseline  1061 CompileLazy  233 TopTier   no Deserialize
    bytes     load 2         1062 CompileBaseline  1062 CompileLazy  277 TopTier   no Deserialize

So the consumer's inference was right and their reason was incomplete: the
bytes path recompiles all 1061 functions on every page load, and the streaming
path does not once the module has been hot enough for the cache to be written.
`wasm.CompileLazy` falling from 1062 to 1 is the whole of it.

Tried: the boot timing again, in that same regime -- boot, then 4000 directives
so the cache is written, six page loads per arm
(`ai-tmp/measure-codecache.mjs`) -> the arms separate here too, on a box at
load 38.

    streamed     1624  883  792  849  829  785 ms   (warm minimum  785)
    from bytes   1063 1183 1239 1042 1199 1063 ms   (warm minimum 1042)

The streamed arm's own cold load costs 1624 ms and its warm loads 785-883, so
the cache is worth about half the boot to a returning page and about a quarter
against the bytes path. The earlier 1245-against-1225 reading was taken in the
regime where neither arm had a cache to hit, which is the reading a
boot-and-stop probe will always get.

Decided: compile the module in `prepareRuntime` with `compileStreaming` from
its URL and hand the loader the compiled `WebAssembly.Module` through
Emscripten's `instantiateWasm` hook, rather than handing it `wasmBinary`. Three
things fall out of doing it there rather than in the loader: the module joins
the per-root memo, so a second boot in a page neither fetches nor compiles; a
fetch that fails is refused by name from a function that can throw, which is
what keeps `names a missing swipl-web.wasm before instantiating wasm` true; and
a module that will not compile is refused by name instead of aborting inside
the loader.

Rejected: letting Emscripten's own `instantiateAsync` stream, by simply not
passing `wasmBinary`. It streams and falls back correctly
[source: node_modules/swipl-wasm/dist/swipl/swipl-web.js, `instantiateAsync`],
but the module then never reaches the memo, and a missing asset surfaces as
`Aborted(...)` from inside the loader rather than as `ERR_METTA_SOURCE` naming
the file.

Decided: the hook calls `new WebAssembly.Instance(module, imports)`
SYNCHRONOUSLY. The loader calls it inside a `new Promise` executor whose only
resolution is the hook's callback, so a synchronous throw rejects the boot
where a rejected promise inside would leave the factory pending forever -- the
hazard this file's existing comment already names for the data preload.

Tested: `compiles the engine from its URL so the browser can cache the compiled
code` (compileStreaming 1, compile 0, instantiate 0),
`compiles the fetched bytes when the response cannot be streamed`, and
`names a wasm asset it cannot compile rather than aborting inside the loader`.

### The install that carries no engine

Tried: `npm install --install-links file:<seat>` into a fresh directory ->
165 files where `npm pack --dry-run` lists 300, with all 135 of `_runtime/`
missing. That matches the consumer's report and its diagnosis: `browser/` and
`_runtime/` are gitignored and listed in `files`, so npm's directory fetcher
was said to apply the gitignore where `npm pack` does not.

Tried: the diagnosis, before the fix it implies. Rebuilt `_runtime/` and ran
the same install -> 300 files, `_runtime/` included. Ran `npm-packlist` 7.0.4
directly against the package -> 300 files,
`{"_runtime":135,"browser":54,"dist":104,...}`. The gitignore is not the
mechanism and never was: a `files` array in package.json nulls both ignore
files at the package root
[source: /usr/share/nodejs/npm-packlist/lib/index.js, `filterEntries`;
npm docs, "Files included with the package.json#files field cannot be excluded
through .npmignore or .gitignore"].

Rejected: adding an `.npmignore`. It is the standard fix for a mechanism this
package does not have, and it would have been a file added to fix nothing,
under a `files` array that already overrides both ignore files.

Decided: the real mechanism is the LIFECYCLE. `_runtime/` and `browser/` were
made by `prepack` and `_runtime/` was removed again by `postpack --clean`; npm's
directory fetcher runs `prepare` and no other script
[source: /usr/share/nodejs/pacote/lib/dir.js, "we *only* run prepare"], and
`prepare` built `dist/` alone. So a `file:` consumer got a package with no
engine and no browser build, and the first list above was taken after a `npm
pack` whose `postpack` had just deleted `_runtime/` from the checkout. `prepare`
now builds all three and `prepack`/`postpack` are gone; npm runs `prepare` on a
pack too, so publishing is unchanged.

Decided: with `prepare` writing `_runtime/`, the checkout carries a COPY of
`engine/` and `lib/`, and `platform.ts` preferred that copy whenever it existed.
That would have made an engine edit invisible to this seat's own suite from the
first `npm install`. The precedence is reversed: the enclosing checkout wins,
and the packed copy answers only where there is no checkout, which is what an
installed package is. `tools/browser.test.mjs` no longer deletes `_runtime/` in
its teardown either; it was deleting an artefact the package needs, for the
same shadowing reason, and the reason is now fixed at the source.

Decided: two root-gate lanes walk `extensions/node` by name and would have read
the copy -- `codespell` as a second copy of this tree's own prose, and
`jscpd-prolog` as a 100% clone of `engine/` and `lib/`. `_runtime` and `browser`
join `build` and `dist` in `.codespellrc`'s skips, and `**/_runtime/**` joins
`**/vendor/**` in the jscpd lane's ignores.

Tried: the `node-dist` lane against the packed shape rather than a symlink ->
`import.meta.resolve("metta-node")` from a scratch directory under
`extensions/node/ai-tmp/` answered `extensions/node/dist/index.js`, the
checkout's own copy. Node's ESM resolver lets a package import itself by name
wherever a `package.json` with an `exports` map encloses the importer, and
self-reference beats the `node_modules` lookup. The scratch directory moved to
the repository's `ai-tmp/`, outside the package. The old lane's symlink hid
this: the self-reference and the symlink pointed at the same tree.

Tested: `tools/dist-consumer.mjs` packs the package, unpacks it into a
`node_modules/metta-node` that no checkout encloses, links the two runtime
dependencies rather than fetching them, asserts `_runtime/engine/metta.pl`,
`_runtime/runtime.json`, `_runtime/wasm/swipl-web.wasm`, `browser/index.js` and
`dist/index.js` are all there, and runs a consumer that boots, evaluates, reads
a term 4096 deep, and reports the `repoRoot` it resolved -- which must be the
package's own `_runtime/`.

Open: whether Chromium writes the wasm code cache for a page that boots the
engine and does no further work. Measured here it does not, because the module
never tiers up far enough; a real application that then runs MeTTa will, and
that is the case the streamed path serves. The threshold itself is V8's and is
not something this seat can set.

## 2026-09-07, later: the other seat

Tried: the same probe on the Python seat, which the Node fix left holding the
opposite ruling -> `metta_py_decode(["p", "my_space_name"], T)` FAILS, and so
does everything containing it. The damage has a different SHAPE here, and it
is worse to read: this seat's decode failure does not raise the way
`metta_node_undecodable/1` does, it just fails, so
`m.eval(S.collapse(S["get-atoms"](space)))` answers NOTHING and a host reads an
empty photograph as an empty space. Measured with the demand still in place:
every registered space photographed its own atoms except `my_space_name`,
which photographed `[]`.

Tried: reaching the defect from the Python surface at all -> two more doors
above the wire refused first. `metta.space("my_space_name")` raised
`a space name starts with &`, and `_space_from_wire` refused the same payload
on the Python side of the codec. So the seat could not even MINT what the Node
host mints from its own registry: `space_names()` listed `my_space_name` and
`space()` refused it, which is one seat disagreeing with the engine about what
a space is.

Decided: all three, because fixing only the shim leaves the defect
unobservable from Python and the regression unwritable. The wire clause
(`extensions/python/metta/shim.pl`), the Python decoder
(`_atom_wire._space_from_wire`) and the handle door (`Space.__init__`).

Decided: a STRING names the space EXACTLY and the Symbol door keeps supplying
the prefix. That is not a new rule, it is this surface's own bracket-door rule
-- `S["add"]` is the symbol `add` while `S.add` is the operator word -- and it
makes `space(name)` open every name `space_names()` reports while
`space(S.kb)` stays `&kb`. The Node seat draws the same line from the other
end: its `spaceIdentityOf` prefixes a string or a Sym and passes a
`SpaceHandle` through untouched, and a handle is what its registry hands back.

Rejected: widening `metta_py_encode/2` to tag a bare registered name `p`. The
encoder asks `metta_space_operand/1`, which tests the prefix before probing
either registry, and that is the SPECIES question the tag encodes; changing it
would move the language's own notion of what a space atom is, which is a
different question from what a decoder must accept. A bare registered name
therefore still crosses OUT as `s`, and only a host minting the tag itself puts
one in -- which is exactly how the Node seat's `spacenames` command produces
one. Revisit only if the engine's species test moves.

Rejected: relaxing the `$` refusal with it. A `$` name reads back as a
VARIABLE, so a term mentioning such a space would stop being the term it
crossed as; that and the empty name are what `Space` still refuses, and they
are the two the old message named as real reasons.

Measured, per tag, because the block above that clause records that a per-tag
change needs a per-tag measurement: 10,000 decodes of one leaf minus a bare
loop of the same count, three identical runs each side. The probe is recorded
below rather than left in a scratch directory, so the numbers can be re-taken:
save it beside the repository root as `wire-cost.pl` and run
`swipl -g true -t halt wire-cost.pl`.

```prolog
% Per-tag decode cost, the protocol the block comment above metta_py_decode_/3
% records: 10,000 decodes of one leaf, minus a bare loop of the same count,
% divided by the count.
:- initialization(main, main).
:- consult('extensions/python/metta/shim.pl').

metta_space_operand('&self').
metta_space_operand('&metta').
metta_match_atoms(L, R) :- unify_with_occurs_check(L, R).
metta_py_tuple_arguments(T, A) :-
    compound(T), compound_name_arity(T, -, _), compound_name_arguments(T, -, A).

count(10000).

bare(0) :- !.
bare(N) :- M is N - 1, bare(M).

decodes(0, _) :- !.
decodes(N, Wire) :- ( metta_py_decode(Wire, _) -> true ; true ), M is N - 1, decodes(M, Wire).

per_leaf(Label, Wire) :-
    count(N),
    statistics(inferences, B0), bare(N), statistics(inferences, B1),
    statistics(inferences, D0), decodes(N, Wire), statistics(inferences, D1),
    Base is B1 - B0, Total is D1 - D0,
    Per is (Total - Base) / N,
    format("~w~t~24| ~4f~n", [Label, Per]).

main :-
    forall(member(Label-Wire,
                  ['s atom'-['s', foo], 's string'-['s', "foo"],
                   'g string'-['g', "foo"], 'g atom'-['g', foo],
                   'n'-['n', 1],
                   'b atom'-['b', true], 'b string'-['b', "true"],
                   'v atom'-['v', x], 'v string'-['v', "x"],
                   'p & atom'-['p', '&self'], 'p & string'-['p', "&self"],
                   'p bare atom'-['p', my_space_name],
                   'p bare string'-['p', "my_space_name"]]),
           per_leaf(Label, Wire)).
```

    tag             before          after
    p  atom          3.00            2.00
    p  string        4.00            3.00
    p  bare atom     4.00 (failing)  2.00
    p  bare string   5.00 (failing)  3.00
    s g n b v        unchanged to the inference

The `sub_atom/5` is the whole difference, and `p` now costs exactly what `s`
costs, which is what it should: the two clauses do the same work.

Tested: `tests/prolog/suites/host/shim.plt` gains four `decodes/3` rows, a
`wrong_class/1` row for a non-text payload, and two named cases; five pytest
cases in
`extensions/python/tests/ch04_spaces_and_matching/test_bare_space_names.py`,
one of them the consumer's walk -- four programs before and after the poisoning
one, on one engine, photographing what its own programs registered after each.
`test_space_name_validation` and the `p` half of
`test_malformed_space_handle_wire_payloads_are_refused` said the old rule and
say the new one.

Planted, once per layer, because a lane that cannot fail is not a lane. The
shim clause restored -> 2 of 5 fail. `_space_from_wire`'s demand restored -> the
r2 handle case fails. `Space.__init__`'s demand restored -> 6 fail.

Open: this seat answers NOTHING for a wire term it cannot decode, where the
Node seat raises. That is `metta_py_decode/2`'s contract for every tag and not
this fix's to change, but it is the reason the defect was silent here and loud
there, and a silent wrong answer at a boundary is the worse of the two.
