#!/bin/sh
# Purpose: reproduce Janus's first failed text query paying an uncached autoload walk.
# Assumes: CHECK_PY names the Python host with janus_swi, or python3 imports it.
# Guarantees: an eager dependency removes the cache-state delta while the
#   unmodified host exposes it [measured 2026-09-10: 226 inferences with cache disabled;
#   command=sh check.sh host-workarounds; fixture=Janus 1.5.3, SWI 10.1.13;
#   commit=WORKTREE].
# Owns resources: each fresh Python child is joined; no engine source is loaded.
set -eu
exec "${CHECK_PY:-python3}" - <<'PY'
import json
import subprocess
import sys

child = r'''
import json
import sys
from pathlib import Path
import janus_swi as janus

eager, lifetime = sys.argv[1], int(sys.argv[2])
if eager == "eager":
    assert janus.query_once("janus:use_module(library(apply),[maplist/2])")["truth"]
assert janus.query_once("call(Goal)", {"Goal": "true"})["truth"]
assert janus.query_once(
    "absolute_file_name(library(apply),_,[file_type(prolog),access(read),"
    "file_errors(fail),relative_to(File)]),set_prolog_flag(file_search_cache_time,Lifetime)",
    {"File": str(Path(janus.__file__).with_name("janus.pl")), "Lifetime": lifetime},
)["truth"]
try:
    before = janus.apply_once("system", "statistics", "inferences")
    answer = janus.query_once("call(Goal)", {"Goal": "fail"})
    after = janus.apply_once("system", "statistics", "inferences")
finally:
    assert janus.query_once("set_prolog_flag(file_search_cache_time,10)")["truth"]
assert answer["truth"] is False
print(json.dumps(after - before))
'''

costs = {}
for eager in ("lazy", "eager"):
    for lifetime in (10, 0):
        ran = subprocess.run(
            [sys.executable, "-c", child, eager, str(lifetime)],
            capture_output=True, text=True, check=False,
        )
        if ran.returncode:
            sys.stderr.write(ran.stderr)
            raise SystemExit(ran.returncode)
        costs[eager, lifetime] = json.loads(ran.stdout)
assert costs["eager", 0] == costs["eager", 10], costs
delta = costs["lazy", 0] - costs["lazy", 10]
assert delta >= 0, costs
print("present" if delta else "absent")
PY
