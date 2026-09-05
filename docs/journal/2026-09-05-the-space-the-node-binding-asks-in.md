# The space the Node binding asks in
Goal: the Node binding must answer the whole space registry, mean the same
thing by `&self` at both of its execution doors, load a program into the space
it was given, and refuse a host callable where one cannot run.
Constraint: reproduce each before fixing; the Python binding is the sibling to
compare against, not to copy blindly.

## 2026-09-05

### One un-prefixed name cost the whole registry

`engine.spaces()` threw `WireError: the p tag carries an ampersand-prefixed
space name, not "my_space_name"` and listed NOTHING, so a caller photographing
every space to put it back afterwards lost every one of them. Reproduced from
`(= (space) my_space_name)` plus a write through it, which is
`examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/07-add_atom_fun_space.metta`.

The engine builds a space operation as `Term =.. [Space, Rel|Args]`, so any
symbol something writes through is a registered space name; the `&` is how the
built-in spaces are spelled. The Python binding lists such a name without
trouble, and only refuses to ADDRESS it: `space('my_space_name')` says a space
name starts with `&` and `space('&my_space_name')` answers a different, empty
space.

Rejected: catching the decode failure in `spaces()` and reporting what could not
be read, which is what the port had to do. It keeps a wall this host put up
itself: the `p` TAG is what says a name is a space, so requiring a spelling
inside it is redundant, and because the registry crosses as one expression the
wall costs every other entry rather than the one.

Decided: the tag carries the engine's own name. `spaces()` then lists the bare
name as a handle and `m.space(handle)` reaches that space, which is strictly
more than the Python binding offers; `m.space("name")` still MINTS `&name`, and
the test pins both so the difference is visible rather than silent. `spaces()`
also stopped `filter`ing, which answered a shorter list with nothing said.

### `&self` meant two different spaces at two doors

Reported as `MeTTa.self` being the engine root where the Python surface gives
each engine a private space, so a program's rows are visible twice while it is
copied into an analysis scratch.

Tried: reproducing the double visibility from the stated cause. Running the
three candidate corpus programs with their home as `&self` and as a named space
gave IDENTICAL status rows, and copying `&self`'s atoms into a scratch showed
each atom and each function once. The private-space difference alone does not
produce it.

Tried: the two DOORS, which is where it is. Asked in a scratch space,
`(get-atoms &self)` answered the ENGINE ROOT's atoms through `eval` and the
scratch's through `runstatus`. The Python binding's doors already agree, and its
own comment states the rule: "&self resolves to the evaluation receiver at both
input doors." `&self` is a tokenizer substitution for the running space that
`rewrite_parsed_form/4` applies during a source load, and a term built on the
host side never reaches it.

Decided: the bridge substitutes at both execution doors, gated on the text door
by the same substring probe the engine's own rewrite uses. Only execution
targets; stored data keeps its literal atoms, which is the line the Python
binding draws.

### `run` took no space

True as reported. `run` and `load` passed `'&self'` whatever the caller was
working in, while every other command took the space, so a program could not be
loaded into a space of its own through them at all.

Decided: both take the space, defaulting to the surface's own.

NOT decided, and left to the user: making `MeTTa.self` a private space per
surface, the way `MeTTa()` gets `&pyspace_N`. The symptom attributed to it does
not reproduce once the doors agree, the change reshapes every door on the
surface, and what a Node program's home is belongs to whoever owns the surface.
The one-line site is `this.self = this.space("&self")` in
`extensions/node/src/metta.ts`.

### A callable in a scope that cannot call one

`Space.transaction` already refused a host callable at the door, naming the
architectural reason: this seat reaches JavaScript by SUSPENDING the engine and
`engine_yield/1` cannot unwind through the nested query frame `transaction/1` or
`snapshot/1` opens. `MeTTa.speculate` did not. A callable is a `Term`, so `lift`
turned it into a grounded atom and the scope answered `(js Function)` with the
callback never called and nothing said.

Decided: the same refusal at both doors, extracted because this was the second
copy. What the refusal does NOT claim: even where a callable runs, as it does on
the Python seat whose crossing is a direct call, the engine's rollback covers
the engine's writes and a host effect it performed is the host's to compensate.

Open: a bridge command given the wrong number of arguments FAILS rather than
refusing, and a synchronous caller reads that as "no answers". Giving `run` its
second argument silently disarmed `Space.capacity`'s admission guard and
silently stopped the conformance kit's streaming definitions from loading; the
suites caught both, which is the only reason they were caught. The dispatcher
refuses an unknown VERB and deliberately has no catch-all under the command
table, because a catch-all would fire when a real command runs out of answers.
Closing it wants either an arity beside each verb in `metta_node_verb/1` or a
dispatcher that separates "no clause matched" from "no more answers".
