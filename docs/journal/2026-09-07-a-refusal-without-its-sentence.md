<!-- Purpose: record why a refusal with the right class carried the wrong words, and what now holds the words. -->
# A refusal that arrived without its sentence
Goal: a refusal the engine composes reaches a Python caller as the sentence it
wrote, and stays that way.
Constraint: the reserved control envelope is how a refusal crosses, and the
kinds it may carry are named in three unrelated places.

## 2026-09-07

Tried: reproducing the reported `metta._json.loads('{"a": 1, "a": 2}')` ->
`ValueError: metta: Unknown error term:
metta_control_signal(value,"JSON object repeats the key a") (value)` on `petta`
at 70ac99da -> DOES NOT reproduce. Both the duplicate key and
`dumps({"n": float("inf")})` answer their own sentences, through the C reader
and through `library(json)`:

    METTA_C_JSON=on   loads dup -> ValueError: JSON object repeats the key a
    METTA_C_JSON=off  loads dup -> ValueError: JSON object repeats the key a
    METTA_C_JSON=on   dumps inf -> ValueError: JSON cannot carry the non-finite number 1.0Inf

Decided: the report was measured on 97c96e91 and is accurate for that tree.
`8d673074` repaired it four commits later, in the `MettaSyntaxError.line` work,
by giving `_reserved_message` an arm for the `syntax`, `value` and `type` kinds
whose detail IS the thrower's sentence. `git merge-base --is-ancestor 8d673074
97c96e91` fails and `... 8d673074 HEAD` holds, which is the whole story.

Tried: finding what would have caught it -> nothing would. Every JSON refusal
test in the tree asked `pytest.raises(ValueError)` and read no message, so the
kind survived and the words did not, and the lane stayed green through the
whole period. The codec's own plunit differential compares the two
implementations' TERMS over a corpus that already contains
`{"a":1,"a":2}` and its escaped spellings, so the engine half was pinned and
the crossing was not.

Decided: the tests read the sentence now, on both reader paths and for text and
bytes alike. `engine/json_codec.pl` chooses between `metta_c_json_read/3` and
`library(json)` at LOAD time, from `METTA_C_JSON`, so the two paths need two
processes; `test_a_refusal_reads_the_same_through_both_reader_paths` runs a
child per path rather than trying to toggle a decision already taken. Planted
by reverting `_reserved_message`'s arm to `if kind == "syntax"`: five tests red,
each printing the exact envelope text from the report.

Tried: asking why a `value` signal could lose its words at all, since the shim
had classified the kind since the codec landed -> because the kinds live in
three places that do not derive from each other. The thrower names one
(`metta_py_raise(value, Message)`, `throw(error(metta_control_signal(syntax,
...)))`); `metta_control_signal_info/3` in `shim.pl` decides whether the
envelope is classified at all; `_EXCEPTION_TYPES` in `_engine.py` decides what
Python raises. Drift is silent in both directions and has happened in both:
`restraint` was admitted by the shim and unknown to Python until the
cache-policies branch caught it by hand, and `value` was known to both while
the message arm covered only `syntax`.

Decided: `extensions/python/tests/repository/test_error_kinds.py` derives the
set from the tree instead of writing it down. It scrapes the two spellings that
NAME a kind, `metta_control_signal(<atom>,` and `metta_py_raise(<atom>,`, over
`engine/`, `lib/` and `extensions/` minus tests, and holds the result equal to
`_EXCEPTION_TYPES` with both differences named, then asks the LIVE shim to
classify each kind. Today both sides are
`{inference_limit, interrupted, restraint, syntax, time_limit, type, value}`.
Planted by adding an `invented` entry to `_EXCEPTION_TYPES`: two tests red.

Rejected: enumerating the shim's admitted kinds by reading the `memberchk/2`
list out of `shim.pl` as text, or by turning that list into enumerable facts.
The first is a source scrape of the thing being verified; the second changes a
classifier on every raising path to make a test easier. Probing the live
classifier per candidate answers the question that matters -- what
`metta_control_signal_info/3` DOES with a term of that kind, which is what
`_engine._raise` asks it at the moment of the failure. Revisit if a kind is
ever admitted by the shim, thrown by nothing, and named by nobody, which this
lane cannot see.

Open: the Node seat maps the same kinds by hand and does not know `restraint`,
which is the `fix/node-error-kinds` package's subject. The shared
`tests/data/` fixture that brief plans had not landed at 70ac99da, so the
derivation lives in `thrown_kinds(repo_root)` in the lane above and that seat
generates its fixture from it rather than from a second list. See
[the Node seat's own reading of the same ruling](2026-09-05-where-the-host-language-disagrees.md),
whose 2026-09-05 section records the duplicate-key refusal from the other side.

Open: the scrape's exclusion list is matched against the path RELATIVE to the
repository root, not its absolute parts. An agent worktree of this repository
sits under a directory literally named `ai-tmp`, and the first version of the
lane pruned itself down to zero files there and reported a green vacuum; the
anti-vacuity assertion caught it, which is the only reason this is a footnote.
