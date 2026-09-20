"""Purpose: the two planted controls the `memray` REPORT lane is proved by.

A lane that cannot fail is not a lane, and an allocation lane is the kind that
goes quiet without anybody noticing: it prints numbers on a green run whether or
not it can still see. So the lane runs this pair on every pass and turns red
unless the leaking half FAILS and the clean half PASSES.

Both halves open two hundred cursors over the same space. Each cursor holds an
SWI engine, which is why cursors are the handle this is written against: the
engine's own stacks are what make a retained one visible at all, and a smaller
handle is not. That was measured rather than assumed, and it is the reason
neither half of this pair lives in the suite proper:

  - two hundred cursors OPENED AND CLOSED retain 924.6 KiB at their largest
    single location and about 15,984 KiB across every location; two hundred
    KEPT retain 19,968.0 KiB at their largest, 21.6x more at that location.
    The 8 MB bound below sits between them, 8.9x above the clean floor and
    2.4x below the leak [measured 2026-09-07 on this tree at loadavg 58 to 66,
    command=`pytest --memray -p no:benchmark -p no:randomly -n 0` over this
    file's two tests with BOUND set to `1 B` so both halves report; the clean
    figure was 924.6 KiB in each of three runs, totals within 0.03%];
  - two hundred CHANNELS, the suite's other many-handle test, are NOT
    distinguishable: kept and dropped both peak at 2,150.4 KiB with totals of
    17,930.5 KiB and 17,742.3 KiB, 1.1% apart, because an SWI message queue is
    small beside the engine's own retention. A `limit_leaks` mark there could
    not fail, so none is written [measured 2026-09-07, same command over
    tests/ch17_concurrency_and_the_loop/test_parallel.py's channel churn];
  - a `limit_leaks` mark is NOT inert without `--memray`. pytest-memray 1.10.0
    enforces the marker on a plain `pytest` run whenever the plugin is
    installed [measured 2026-09-07: this file's leaking half reported MEMORY
    PROBLEMS under `pytest -p no:benchmark -n 0` with no flag], so a mark on a
    collected test would put the whole GATE suite under allocation tracking
    and make it depend on a package only the `checks` extra installs.

The file is therefore named so that pytest's own file discovery never reaches
it: `python_files` defaults to `test_*.py`, and this is collected only because
the lane names its path outright.

Both halves exclude the engine's own stack arena, for the reason recorded on
ENGINE_ARENA below: it is not a function of what the caller retains, it moved
by 8.8x in thirteen days, and while it was counted the control was failing on
the engine's growth rather than on anything about cursors.

Assumes: `metta` imports, which the lane's interpreter is the one that can do
Guarantees:
  - the kept half exceeds the bound and the dropped half stays under it
    [tested: sh check.sh memray]
  - both halves measure the same quantity, so the comparison between them means
    something. One mark OBJECT carries the bound and the filter to both, so
    there is no second spelling that could drift from the first
    [source: LEAK_MARK, the only `limit_leaks` mark in this file, applied at
    both halves; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
Owns resources: the module list below deliberately outlives the leaking test,
  which is the leak; the process ends with the lane
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import gc

import pytest
from pytest_memray import Stack

from metta import S, V
from metta._faces.space import Space

#: How many cursors each half opens. Two hundred is where the separation above
#: was measured; fewer narrows it toward the engine's own retention.
CURSORS = 200

#: The bound, sitting between the measured clean floor and the measured leak.
BOUND = "8 MB"

#: SWI's own stack grower. An allocation made below it is the engine's ARENA:
#: Prolog stacks that grow to hold a term and are never returned to the OS, so
#: they read as leaked whatever the caller does with its handles. Excluding
#: them is what makes both halves measure the same thing -- what the CALLER
#: retains -- instead of racing a frozen bound against a quantity that belongs
#: to the engine.
#:
#: It moved: 924.6 KiB at the largest single location on 2026-09-07, 8.1 MiB on
#: 2026-09-20, which crossed BOUND and turned the control red without anything
#: about cursors changing. The stack was tmp_realloc, stack_realloc,
#: growStacks, f_ensureStackSpace___LD, pl_collect_findall_bag2_va -- findall
#: growing the global stack, 8.1 MiB over 200 cursors, about 41 KiB each.
#:
#: Warming the arena first was the alternative and cannot work here: each
#: cursor opens its OWN engine, so the growth is per-cursor and pre-growing one
#: engine pre-grows nothing. Raising BOUND was the other, and only defers this:
#: the bound would still be a frozen guess racing a moving quantity, and a
#: wider one hides a real cursor leak of the size it was widened by.
#:
#: Matched on the frame name because a stack is all memray offers and SWI's own
#: source is where the name comes from. A rename breaks the match, the arena
#: reappears in the measurement and the control fails loudly, which is the
#: direction a stale filter should fail in.
ENGINE_ARENA = "growStacks"


def outside_the_engine_arena(stack: Stack) -> bool:
    """Report this allocation unless SWI made it growing its own stacks."""
    return all(frame.function != ENGINE_ARENA for frame in stack.frames)


#: What the leaking half keeps. A module-level list is the smallest leak there
#: is: nothing is wrong with any object, they are simply still referenced.
_HELD: list = []


def _stocked() -> Space:
    """A fresh space with two edges in it, which is enough for a cursor."""
    space = Space()._new_space()
    space.add(S.edge(S.a, S.b), S.edge(S.b, S.c))
    return space


def _cursor(space):
    """One open cursor, advanced once so its engine exists."""
    cursor = space.stream(S.edge(V.x, V.y))
    next(iter(cursor))
    return cursor


# One mark object rather than two identical spellings of it. The pair is only a
# comparison while both halves measure the same quantity, and two spellings is an
# invariant somebody has to hold; one object says the same thing with nothing to
# hold, because there is no second mark to drift from.
LEAK_MARK = pytest.mark.limit_leaks(BOUND, filter_fn=outside_the_engine_arena)


@LEAK_MARK
def test_two_hundred_dropped_cursors_stay_under_the_bound():
    """The control. It has to PASS, or the bound is too tight to be a lane."""
    space = _stocked()
    try:
        for _ in range(CURSORS):
            _cursor(space).close()
        gc.collect()
    finally:
        space.drop()


@LEAK_MARK
def test_two_hundred_kept_cursors_are_reported():
    """The plant. It has to FAIL, or the lane has stopped being able to see."""
    space = _stocked()
    _HELD.append(space)
    _HELD.extend(_cursor(space) for _ in range(CURSORS))
    gc.collect()
