"""Purpose: per-predicate call counts, or b_setval keys, over one Python twin.

Mirrors the twins lane's own child (extensions/python/tools/twin_coverage.py,
run_twin): the same preamble, the same `twin(m)` call, the same
`m.stats()` bracket, with SWI's statistical profiler or a b_setval/2 wrapper
around it. Two trees can then be diffed predicate by predicate, or key by
key, for a cost the lane reports but does not attribute.

Assumes: run from a checkout root, with that root, the twin's path and the
output path as arguments, and `keys` as a fourth argument for the b_setval
count instead of the profile. The interpreter is the one with janus.

Guarantees: the first line of the output is `inferences<TAB>N`, the rest
`Calls<TAB>Module:Name/Arity` descending, or `Writes<TAB>Key-changed|same`
under `keys`. The counts are for diffing two trees under one shape; the
profiler and the wrapper both move the inference total, so it is never a pin.
"""
import importlib.util
import sys

root, twin, out = sys.argv[1:4]
mode = sys.argv[4] if len(sys.argv) > 4 else "profile"
sys.path.insert(0, "extensions/python")
import janus_swi  # noqa: E402  -- the path above is what makes the seat importable

janus_swi.cmd("system", "set_prolog_flag", "file_search_cache_time", 9223372036854775807)
from metta import MeTTa  # noqa: E402  -- same reason

m = MeTTa(metta_path=".").self
spec = importlib.util.spec_from_file_location("metta_twin", twin)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
janus_swi.consult(root + "/tests/prolog/probes/twin_profile.pl")
if mode == "keys":
    janus_swi.query_once("twin_profile_watch_keys")
    with m.stats() as spent:
        module.twin(m)
    janus_swi.query_once("twin_profile_key_report(Out)", {"Out": out})
else:
    janus_swi.query_once("use_module(library(prolog_profile))")
    janus_swi.query_once("profiler(_Old, cputime)")
    with m.stats() as spent:
        module.twin(m)
    janus_swi.query_once("profiler(_Was, false)")
    janus_swi.query_once(
        "twin_profile_dump(Out, Spent)", {"Out": out, "Spent": spent.inferences}
    )
print(f"twin inferences {spent.inferences} written {out}")
