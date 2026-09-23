#!/bin/sh
# Purpose: prove tools/publish-new-projects.sh refuses every way a run could
#   spend a project-creation attempt it should not, and reports cleanly when
#   nothing is wrong.
# Assumes: publish-new-projects.sh sits beside this file; a writable ai-tmp/;
#   a python that can run http.server.
# Guarantees: exits nonzero if any refusal below stops refusing, or if the
#   clean case stops passing. No case reaches PyPI and none uploads anything:
#   the index is a local http.server, which answers 200 for a planted path and
#   404 otherwise, and that IS the contract the tool reads.
# Fails when: run concurrently with itself, since it owns one fixture path and
#   one port.
# Decides: the cases are the refusal table exhausted rather than sampled.
#   Every way the tool can decide is here, because the cost of the one it
#   misses is a public project created from an incomplete set, which PyPI does
#   not let anyone take back.
set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
TOOL="$HERE/publish-new-projects.sh"
ROOT=$(cd -- "$HERE/.." && pwd)
FIXTURE="$ROOT/ai-tmp/publish-selftest"
PORT=8917
failures=0
served=""

cleanup() {
    [ -n "$served" ] && kill "$served" 2>/dev/null
    rm -rf "$FIXTURE"
}
trap cleanup EXIT

rm -rf "$FIXTURE"
mkdir -p "$FIXTURE/index/pypi" "$FIXTURE/dist" "$FIXTURE/bin"

# Every distribution the tool will ask about, read the way the tool reads it,
# so a new one under ext/ joins these cases without an edit here.
projects=$(for m in "$ROOT"/ext/*/pyproject.toml; do
    [ -f "$m" ] && sed -n 's/^name *= *"\([^"]*\)".*/\1/p' "$m" | head -1
done)

# THE SUBJECT of the three cases that need a project still to be created. Each
# of them puts every OTHER project into the fixture index, so the subject is
# the only one the tool still has to create and therefore the only one whose
# artifacts the rule under test reads.
#
# Taken from the list rather than named. It used to be pymetta-host, spelled
# out here and in three cases; that distribution was retired on 2026-09-23
# when the patched SWI host moved inside pymetta's own manylinux wheels, and a
# fixture naming a distribution encodes a fact about the release that goes
# stale under it.
#
# TWO names, at the ends of the list, because the fixture index is SHARED
# across the cases below and they want opposite things from it. $HELD is the
# one a case plants into that index, to prove a project the index already has
# is not offered for creation. $SUBJECT must still be missing from it when the
# last three cases run, so it cannot be $HELD -- taking the ends is what makes
# them distinct without either being written down.
#
# $projects is NEWLINE-separated, so the unquoted expansion collapses it to
# spaces first. Fewer than two names means ext/ is empty or nearly so, which
# happens in a worktree whose submodule pointer was never updated: the cases
# would then run against a fixture with nothing in it and report the TOOL as
# broken. That cost a real diagnosis, because "exit 0, wanted 1" says nothing
# about a stale submodule, so refuse here instead, naming the cause.
HELD=$(echo $projects | awk '{print $1}')
SUBJECT=$(echo $projects | awk '{print $NF}')
HELD_STEM=$(echo "$HELD" | tr '-' '_')
SUBJECT_STEM=$(echo "$SUBJECT" | tr '-' '_')
if [ -z "$SUBJECT" ] || [ "$SUBJECT" = "$HELD" ]; then
    printf 'publish-selftest: ext/ names fewer than two distributions, so the\n' >&2
    printf '  fixture cannot plant the cases that need one project held by the\n' >&2
    printf '  index and another still to create. This is usually a worktree whose\n' >&2
    printf '  submodules were never updated; run\n' >&2
    printf '  git submodule update --init --recursive here.\n' >&2
    exit 1
fi

# A complete release for each: a pure wheel plus an sdist. Empty files are
# enough, because nothing here uploads. The binary shape -- platform wheels
# and no sdist -- is planted in the one case that is about it, rather than
# given to a distribution here, because which distributions are binary is a
# fact about the release and this fixture should not carry one.
for name in $projects; do
    stem=$(echo "$name" | tr '-' '_')
    touch "$FIXTURE/dist/$stem-0.9.0-py3-none-any.whl" "$FIXTURE/dist/$stem-0.9.0.tar.gz"
done

( cd "$FIXTURE/index" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 ) \
    > "$FIXTURE/http.log" 2>&1 &
served=$!
# The server answers before the first case, or every case reads 000 and the
# suite passes for the wrong reason.
ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")" != 000 ]; then
        ready=1; break
    fi
    sleep 0.3
done
if [ "$ready" -eq 0 ]; then
    printf 'publish-selftest: the fixture index never answered on port %s\n' "$PORT" >&2
    exit 1
fi
LOCAL="http://127.0.0.1:$PORT"

# $1 what the case is for, $2 expected exit, $3 a string the output must carry,
# then the command.
case_is() {
    what=$1; want=$2; carries=$3; shift 3
    out=$("$@" 2>&1); got=$?
    if [ "$got" -ne "$want" ]; then
        printf '  %s: exit %s, wanted %s\n    %s\n' "$what" "$got" "$want" "$(echo "$out" | tail -2)"
        failures=$((failures + 1))
    elif ! printf '%s' "$out" | grep -qF "$carries"; then
        printf '  %s: exit %s as wanted, but nothing said %s\n    %s\n' \
               "$what" "$got" "$carries" "$(echo "$out" | tail -2)"
        failures=$((failures + 1))
    fi
}

# No interpreter at all.
case_is "an interpreter that does not exist" 1 "found no interpreter" \
    env CHECK_PY="$FIXTURE/bin/absent" DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL"

# An interpreter that cannot import twine, which is how the first real run
# died: /usr/bin/python3 carries none.
cat > "$FIXTURE/bin/python" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && case "$2" in *twine*) exit 1 ;; esac
exit 0
FAKE
chmod +x "$FIXTURE/bin/python"
case_is "an interpreter without twine" 1 "cannot import twine" \
    env CHECK_PY="$FIXTURE/bin/python" DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL"

# An index that answers neither 200 nor 404 says nothing about existence, and
# guessing "absent" is the guess that costs an attempt.
case_is "an index that cannot answer" 1 "neither present nor absent" \
    env DIST="$FIXTURE/dist" INDEX="http://127.0.0.1:1" sh "$TOOL"

# Classifying against one index and uploading to twine's own is the split this
# refuses; it must refuse BEFORE reaching the network.
case_is "a non-default index with --publish" 1 "INDEX is for checking" \
    env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL" --publish

# Nothing built at all.
case_is "a dist holding nothing" 1 "(nothing)" \
    env DIST="$FIXTURE/empty" INDEX="$LOCAL" sh "$TOOL"

# A pure wheel with no sdist: the shape metta-arrays really shipped in on
# 2026-09-21, and the one PyPI will not let anyone repair afterwards. Planted
# on $HELD rather than on that name, because the case is about the SHAPE and a
# fixture naming a distribution outlives the release that made it true.
mkdir -p "$FIXTURE/partial"
touch "$FIXTURE/partial/$HELD_STEM-0.9.0-py3-none-any.whl"
case_is "a pure wheel with no sdist" 1 "no sdist" \
    env DIST="$FIXTURE/partial" INDEX="$LOCAL" sh "$TOOL"

# A project the index HAS is not offered for creation. The expected line is
# built with the tool's OWN column width, because a hand-counted run of spaces
# between the name and the words is a second copy of a format string.
mkdir -p "$FIXTURE/index/pypi/$HELD"
printf '{}' > "$FIXTURE/index/pypi/$HELD/json"
case_is "a project the index already holds" 0 \
    "$(printf '%-24s on PyPI already' "$HELD")" \
    env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL"

# An sdist with no wheel is the row the rule did not decide, so it passed.
# Planted on $SUBJECT, a project the index does NOT hold: the fixture index is
# shared and the case above put $HELD into it, which took that project out of
# the to-create set and would make this case pass for the wrong reason.
mkdir -p "$FIXTURE/sdistonly"
touch "$FIXTURE/sdistonly/$SUBJECT_STEM-0.9.0.tar.gz"
case_is "an sdist with no wheel" 1 "$SUBJECT(sdist, no wheel)" \
    env DIST="$FIXTURE/sdistonly" INDEX="$LOCAL" sh "$TOOL"

# A binary distribution owes no sdist, so the completeness rule must not fire
# on the one whose wheels carry a platform tag. Every OTHER project has to be
# on the index for this to isolate it: the check reads the whole to-create
# set, so a dist holding one project's files reports the other thirteen as
# empty, which is what this case said the first time it ran.
for name in $projects; do
    [ "$name" = "$SUBJECT" ] && continue
    mkdir -p "$FIXTURE/index/pypi/$name"
    printf '{}' > "$FIXTURE/index/pypi/$name/json"
done
mkdir -p "$FIXTURE/binary"
touch "$FIXTURE/binary/$SUBJECT_STEM-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl"
case_is "platform wheels without an sdist" 0 "1 project(s) to create" \
    env DIST="$FIXTURE/binary" INDEX="$LOCAL" sh "$TOOL"

# And with everything in place the report is clean and spends nothing.
case_is "a complete set, reporting" 0 "reporting only" \
    env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL"

# Two runs must not share an upload log path, or a verdict's cited evidence is
# overwritten by whatever ran next. The upload loop itself cannot be reached
# from here without defeating the index guard that stops a test publishing, so
# the assertion is on the stamp the report prints, which is what names the log.
first=$(env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL" | sed -n 's/^run \([^;]*\);.*/\1/p')
second=$(env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL" | sed -n 's/^run \([^;]*\);.*/\1/p')
if [ -z "$first" ]; then
    printf '  two runs share no log path: the report named no run stamp at all\n'
    failures=$((failures + 1))
elif [ "$first" = "$second" ]; then
    printf '  two runs share no log path: both runs stamped %s\n' "$first"
    failures=$((failures + 1))
fi

# A version this repository does not publish. Read off the ARTIFACT, so it
# fires on what would actually be uploaded rather than on a manifest that can
# disagree. Planted on $SUBJECT because by here every other project is in the
# shared fixture index, so it is the only one still to create and the only one
# whose artifacts the check reads.
mkdir -p "$FIXTURE/badversion"
cp "$FIXTURE/dist"/* "$FIXTURE/badversion/" 2>/dev/null
touch "$FIXTURE/badversion/$SUBJECT_STEM-1.0.0-cp312-cp312-manylinux_2_28_x86_64.whl"
case_is "an artifact carrying the refused version" 1 "1.0.0 is not a version" \
    env DIST="$FIXTURE/badversion" INDEX="$LOCAL" sh "$TOOL"

mkdir -p "$FIXTURE/badzip"
cp "$FIXTURE/dist"/* "$FIXTURE/badzip/" 2>/dev/null
touch "$FIXTURE/badzip/$SUBJECT_STEM-1.0.0.zip"
case_is "a refused version in an extension no list names" 1 "1.0.0 is not a version" \
    env DIST="$FIXTURE/badzip" INDEX="$LOCAL" sh "$TOOL"

printf 'publish-selftest: %s defect(s) over 13 cases, every refusal the tool can make\n' "$failures"
[ "$failures" -eq 0 ]
