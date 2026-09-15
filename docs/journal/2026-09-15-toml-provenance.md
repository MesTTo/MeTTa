# TOML configuration provenance

Goal: resolve configuration evidence without changing configuration data.

## 2026-09-15

Tried: `python tests/checks/pin_provenance.py --commit
4c6e285e7581d3fc39969edffb50f569c6e901fb` resolved two Python pins, then
returned 1 because `pyproject.toml` was outside the evidence globs. The exact
diagnostic is in `ai-tmp/ai-classes-c60-pin.log`. The partial substitutions were
restored before changing the tool. New root and nested TOML controls expose
19 defects in the unchanged pinner, recorded in
`ai-tmp/ai-classes-c60-toml-before.log`.

Decided: include tracked TOML files in the existing provenance scan. Reuse
`tomllib.loads` to distinguish comments from keys and all four string forms:
a comment substitution leaves the parsed data unchanged. Preserve float
spelling during comparison so NaN does not reject a valid comment. A candidate
key collision is a value substitution and stays unchanged. The controls cover
root and nested configuration, trailing comments, embedded hashes, multiline
values, keys, collisions and NaN.

Rejected: treating every preceding hash as a comment opener or adding a TOML
lexer. Quoted hashes defeat the former; the standard parser already supplies
the distinction needed by the latter. Claim parsing for configuration commands
remains separate from checking their commit identities.

Verified: `python tests/checks/check_pin_provenance_selftest.py` reports zero
defects over 58 placeholders in 21 files after the change. The receipt is
`ai-tmp/ai-classes-c60-toml-after.log`.

The same self-test passes on Python 3.12.13. `sh check.sh evidence
evidence-selftest provenance-pin-selftest ruff` passes, including zero unbacked
references in 7,856 claims and all 36 planted evidence citations. The source
inventory suite was repeated on the resulting series: 13 tests pass on Python
3.14.4; 12 pass and the live-version oracle skips on 3.12.13. Receipts are
`ai-tmp/ai-classes-c60-toml-checks.log`, `ai-tmp/ai-classes-c60-toml312.log`,
`ai-tmp/ai-classes-c60-series-source314.log` and
`ai-tmp/ai-classes-c60-series-source312.log`.

`jscpd --reporters console,json --format python --min-lines 5 --min-tokens 50
--noTips --output ai-tmp/ai-classes-c60-toml-clones
tests/checks/pin_provenance.py tests/checks/check_pin_provenance_selftest.py`
reports zero clones in 868 lines and 6,127 tokens. The log is
`ai-tmp/ai-classes-c60-toml-clones.log`.
