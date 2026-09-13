# Argument expansion retains native values

Goal: assemble Python positional expansion without changing its atom elements.

## 2026-09-14

Tried: the call assembler drains py-iter-once over both native expressions and
borrowed Python tuples. The former converts symbols and nested expressions
into Python strings and lists; the latter returns opaque Python atom objects.
All four combinations of native/borrowed sequence and lone/mixed expansion
fail in ai-classes-c34-expansion-atoms-before.log. Command:
```sh
python -m pytest -q -n3 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_expanded_call_values.py::test_expanded_arguments_preserve_native_atom_values
```

The pristine c75181adc iterator control returns Grounded(<Expression>) for
an Expression stored in a borrowed tuple, preserving its host identity.
That is the host iterator boundary's contract, not native call assembly.
The control command and output are in ai-classes-c34-iterator-atom-control.log.

Decided: the call assembler collects values through the existing build and
argument codecs. Native expressions iterate their atoms, borrowed iterables
retain their Python values, and registered values use their ordinary catalog
projection. Expansion already requires consuming the complete iterable before
the call. One owned argument operation returns the collected native expression;
the compiler retains Python's distinct timings for lone and mixed expansion.

Rejected: modifying the host iterator's result policy or recognizing atom
objects by spelling. The existing value codec owns that conversion, and the
call boundary owns materialization.

The materializer is a named host-type value in the existing annotation codec.
The compiler supplies list for LIST_EXTEND and tuple for CALL_FUNCTION_EX.
CPython v3.14.4 Objects/listobject.c:list_extend_iter_lock_held reads the
iterable's length hint; Objects/abstract.c:PySequence_Tuple drains its iterator
without that hint. Passing the materializer preserves this observable
difference without another argument-mode table. Sources:
https://github.com/python/cpython/blob/v3.14.4/Objects/listobject.c#L1157-L1169
and https://github.com/python/cpython/blob/v3.14.4/Objects/abstract.c#L1867-L1937.
The Python oracle covers both call forms with successful, ignored and
raising length implementations.

The first isolated run passes1097cases and fails9. A mixed operand was
passed unevaluated into the Atom-typed collector; binding it before
collection restores source effects. Two fixture names collided with
existing operations. The length oracle also exposed the twin dispatcher's
module/name key: later closures ran the first closure's marker functions.
The oracle now calls the actual source function directly. That dispatcher
ownership issue is retained as a separate obligation. Logs:
ai-classes-c34-expansion-atoms-A-python.log and
ai-classes-c34-expansion-atoms-repaired.log.

The other shuffled failure is the earlier answer-type fixture's global
absent operation surviving into a vocabulary test's declaration. It is
independent of positional assembly and needs explicit fixture cleanup.
