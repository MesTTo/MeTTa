# Two seats, one error taxonomy
Goal: every refusal the engine raises reaches every host seat as the same
kind, with the parts a caller acts on, and the seats cannot drift apart about
which refusals have a class.
Constraint: the Python seat's own wire does not change; refusal kinds become
catalog rows later (section 22, package AK, after the remedies package AD), so
until then each seat maps kinds by hand and the maps have to agree.

## 2026-09-07

The Node seat classified an engine refusal by matching the RENDERED MESSAGE.
`extensions/node/src/errors.ts`'s `engineError(text)` recognised seven kinds
that way, over nine patterns: the two control-signal words, two spellings of a
stack ceiling, `MeTTa assertion failed`, three syntax wordings, `source_sink`
or `does not exist`, and the letters `capabilit`.
The Python seat asked the engine four questions instead
(`metta_control_signal_info/3`, `metta_assertion_failure/6`,
`metta_py_space_capability_error/4`, `metta_py_operation_error/5`) and knew ten
kinds. The two lists were never compared, and they had already drifted.

The difference, measured by reading both classifiers at a0a34ea5:

| kind | Python seat | Node seat, before | Node seat, now |
|---|---|---|---|
| `syntax` | `MettaSyntaxError`, `.line` from the envelope's context | `MettaSyntaxError` from three prose patterns, no line | `MettaSyntaxError`, `.line` |
| `time_limit` | `TimeLimitError` | `TimeLimitError`, bound scraped from `its (\d+)` | `TimeLimitError`, `.limit` |
| `inference_limit` | `InferenceLimitError` | same scrape | `InferenceLimitError`, `.limit` |
| `restraint` | `RestraintError`, `.restraint`, `.bound`, `.call` | **none**: a generic `EngineError` | `RestraintError`, `.restraint`, `.limit`, `.call` |
| `interrupted` | `Interrupted` | **none** | `InterruptedError` |
| `value` | `ValueError` | **none** | `WireError` |
| `type` | `TypeError` | **none** | `CastError` |
| `assertion` | `AssertionFailure`, `.operation`, `.actual`, `.expected`, `.missing`, `.excess` | `AssertionError` from the words `MeTTa assertion failed`, no fields | `AssertionError`, `.operation` |
| `capability` | `SpaceCapabilityError`, `.space`, `.operation`, `.capability` | `CapabilityError` from the letters `capabilit`, no fields | `CapabilityError`, all three |
| `operation` | `MettaOperationError`, `.operation`, `.kind`, `.expected`, `.culprit` | **none** | `OperationError`, all four |
| `stack` | **none**: a generic `EngineError` | `StackLimitError`, ceiling scraped from `Stack limit (1.0Gb)` | `StackLimitError`, `.limit` from the ball |
| `source` | **none** from the ball; `SourceNotFound` comes from the seat's own file check before the crossing | `SourceNotFoundError` from `source_sink`, no path | `SourceNotFoundError`, `.source` |
| `engine` | `EngineError` | `EngineError` | `EngineError` |

Five kinds the Python seat knew reached the Node seat as a generic
`EngineError`, and no refusal that HAD a class there carried a single field.
Two kinds run the other way and are still open, at the bottom.

Decided: the engine owns the table and every seat reads it.
`engine/metta/registration.pl` declares `metta_host_error_kind_row/3`, one row
per kind with its origin and its fields, and `metta_host_error_kind/3` reads
one off a raised ball. This is the errno/SQLSTATE shape: one table where the
raising happens, one hand-written map per binding, and a test per binding that
its map covers the table [source: PostgreSQL src/backend/utils/errcodes.txt,
which generates the C, PL/pgSQL and documentation spellings from one row list].
The rows are what package AK's catalog atoms get built from.

Rejected: a second classifier in `extensions/node/bridge.pl`. The shim's own
note records that exact drift happening once already -- a
`metta_py_control_exception/1` holding a second copy of the list, missing three
of the engine's signals, that nothing called. A second copy is how the seats
got here.

Tried: moving the shim's three classifiers engine-side and leaving one-clause
delegations behind (`metta_control_signal_info/3` maps the engine's unbound
absence back to janus's `@none`; `metta_control_signal_line/2` and
`metta_py_space_capability_error/4` keep the names the Python door's own goal
text asks for). Result: `_engine.py` is untouched, `sh extensions/python/test.sh
tests/ch10_errors_and_refusals` stays green, and `metta_control_signal_kind/2`
turned out to be dead (nothing in the tree called it since 2026-08-28) and went
with the move.

Decided: the wire carries `[error, Text, Kind, Fields]`, fields FLAT and as
text, name then value. Flat because that is what crosses swipl-wasm's `toJSON`
at constant depth, which is the same reason the atom wire is flat; text because
this transport already decided a number crosses as its canonical Prolog text.

Decided: a stack ceiling comes from the ball, not from the message and not from
the flag. SWI records the ceiling in force at the overflow in the ball's own
context dict, in Kb [source: /usr/lib/swi-prolog/boot/messages.pl,
`human_stack_size(Context.stack_limit, Limit)`], while the flag answers the
ceiling in force NOW, which a scope that raised the limit and unwound has
already put back. The prose was also wrong: for a 40,000,000-byte limit SWI
renders `38.1Mb`, and the old regex answered 39,950,745.6 bytes against the
ball's own 39,999,488, off by 48,742 and not even an integer
[measured 2026-09-07, `node -e` over the shipped regex and SWI's own
`stack_overflow{stack_limit: 39062}`].

Decided: a bound the engine could not name is `undefined`, not 0. A budget that
expires inside a NESTED query raises SWI's own resource ball, which names the
resource and not the number, because the number lives in the frame that
installed it and that frame has unwound; the old Node code answered `0`, which
reads as a bound of zero.

Decided: `value` and `type` stay inside the Node family as `WireError` and
`CastError` where the Python seat spells them with the language's own
`ValueError` and `TypeError`. Rejected mapping them onto the platform's
`TypeError` and `RangeError` to mirror Python: this seat's tested guarantee is
that catching `MettaError` catches every refusal it raises, and it already has
a class for each of those two meanings. Each host spells a meaning its own way;
the shared list records both spellings, which is what makes the difference
visible instead of hidden.

Decided: `tests/data/error-kinds.json` is the list, with each seat's class,
code and attribute names, a ball that raises each kind, and what that ball
carries. Three suites read it: `tests/prolog/suites/host/error_kinds.plt`
(the engine's own rows and classifier),
`extensions/python/tests/repository/test_error_kinds.py` (the fixture against
`_EXCEPTION_TYPES`, against the live rows, and against what this seat raises
when the ball is thrown) and `extensions/node/test/errors.test.ts` (the map,
and the same balls through a live engine). A kind added to one seat and
forgotten in another goes red in two of them.

Measured: the Node suite is 617 tests over 138 suites, all passing, with the
live restraint case answering `max-answers`, 2 and `(nx-upto 10)` from a real
`(cache nx-upto (max-answers 2))` row. The Python side is 41 cases over the
thirteen kinds.

Open: the Python seat does not classify `stack` or `source` from the ball. A
stack overflow arrives there as `EngineError` and `SourceNotFound` is raised by
the seat's own file check before the crossing. Closing it means a new public
Python condition and its documentation, in the file another package is editing
this wave; the two rows carry `python: null` with a note, and
`test_a_thrown_ball_raises_the_class_the_fixture_names` goes red the day it
closes so the shared list is updated with it.

Open: a failed assertion's two answer BAGS stay in the rendered message on the
Node side rather than crossing as fields. They are answer atoms, not names or
numbers, so carrying them would mean running the atom codec on a path that is
already raising; the message already names them and the seat's own test reads
them there. Revisit if a caller needs them as atoms rather than as text.
