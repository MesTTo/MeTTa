#!/bin/sh
# Purpose: reproduce Janus keeping every exception a Python callback raised into Prolog alive for the process.
# Assumes: CHECK_PY names the Python host with janus_swi, or python3 imports it.
# Guarantees: prints `present` when a callback's exception survives atom GC and
#   the deferred-release drain with no Python referrer left, which is what
#   janus-swi 1.5.3's check_error leaves by never releasing the references
#   PyErr_Fetch handed it, and `absent` on a host that releases them
#   [measured 2026-09-16: 1.5.3 as shipped answers present, each exception at
#   refcount 2 with one tracked referrer; the build carrying
#   janus-callback-exception-leak.patch answers absent;
#   command=sh check.sh host-workarounds; fixture=Janus 1.5.3, SWI 10.1.13;
#   commit=WORKTREE].
# Owns resources: one Python child, joined; no engine source is loaded.
set -eu
exec "${CHECK_PY:-python3}" - <<'PY'
import gc

import janus_swi as janus


class Planted(Exception):
    pass


def raiser():
    raise Planted("callback")


janus.query_once("py_call(builtins:len([]), _)")
for _ in range(3):
    try:
        janus.query_once("py_call('__main__':raiser(), _)")
    except janus.PrologError:
        pass
# Atom GC reclaims the blobs that carried the exceptions across; the next
# Prolog-to-Python call drains janus's deferred Py_DECREF queue.
for _ in range(3):
    janus.query_once("garbage_collect_atoms, garbage_collect, py_call(builtins:len([]), _)")
    gc.collect()
survivors = [o for o in gc.get_objects() if isinstance(o, Planted)]
print("present" if survivors else "absent")
PY
