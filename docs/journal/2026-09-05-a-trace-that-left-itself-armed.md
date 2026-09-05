# A trace that left itself armed
Goal: a trace whose program abolished a wrapped predicate must not disarm every
later trace on the same engine.
Constraint: reproduce before fixing, and gate a regression that fails on the
tree before the fix.

## 2026-09-05

Reported by the graph port as `metta_trace_unwrap/1` catching an error and not a
failure, with `unwrap_predicate/2` failing for a predicate the traced program
abolished. Ten calls across seven of its programs each lost their whole trace
channel.

Tried: reproducing it. `unwrap_predicate/2` is semidet and its documentation
says so: it removes the outermost wrapper whose name unifies and FAILS when
there is none. On the reported fixture, a `&self` holding `lib_spaces` with its
atoms copied into `&box` and a traced `!(remove-all-atoms &box)`, the engine is
left at `session=yes wrapped=12` and the next trace raises
`permission_error(trace, evaluation, nested)`.

The MECHANISM is not the one the report guessed, and the difference matters
because that reading suggests the wrapper is destroyed. It is not. Inspecting
each recorded target at three points:

```text
--- armed ---            12 targets, all from=local, all wrapped=[metta_tracer]
--- after the program -- the six &box targets read from='$metta_exec:&self'
--- unwrapping in order  the six &box targets -> ok, the six &self targets -> failed
```

`clear_generated_predicate/3` abolishes the child module's copy and
`metta_restore_inherited_predicate/3` imports the parent's in its place, so the
child's recorded indicator starts denoting the PARENT's procedure. Unwrapping
the six children removes the six parents' wrappers, and the parents' own
recorded targets then find nothing to remove. `maplist/2` stops at the seventh,
`metta_trace_end_unlocked/0` never reaches its nine retractalls, and
`metta_trace_source/6` runs that teardown as a cleanup, whose failure is not
reported, so the trace answers normally.

Decided: `ignore(catch(...))`, the shape `extensions/python/metta/shim.pl`
already uses for the saga receipt's unwrap, so the teardown is total in both
directions. It also unwraps the targets AFTER the failing one, which the old
form skipped even when they could be unwrapped.

Minimised the fixture to two equations in `&self`, a copy of them in a second
space and a traced program that clears it, which reproduces at four wrapped
targets with no library:
`tracer:a_trace_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed`
fails on the old code with the reported `No permission to trace evaluation
'nested'` and passes on the new, and it is the only failing test in its suite
either way.

The test's own cleanup runs `metta_trace_end` through `ignore/1` for the same
reason the fix exists: on a tree where the teardown still fails, a cleanup that
failed with it would report the cleanup instead of the assertions that name the
defect.
