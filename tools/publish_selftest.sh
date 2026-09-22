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

# A complete release for each: a pure wheel plus an sdist, except the one
# binary distribution, whose platform wheels owe no sdist. Empty files are
# enough, because nothing here uploads.
for name in $projects; do
    stem=$(echo "$name" | tr '-' '_')
    if [ "$name" = pymetta-host ]; then
        touch "$FIXTURE/dist/$stem-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl"
    else
        touch "$FIXTURE/dist/$stem-0.9.0-py3-none-any.whl" "$FIXTURE/dist/$stem-0.9.0.tar.gz"
    fi
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

# A pure wheel with no sdist: the shape metta-arrays actually shipped in, and
# the one PyPI will not let anyone repair afterwards.
mkdir -p "$FIXTURE/partial"
cp "$FIXTURE/dist"/metta_arrays-0.9.0-py3-none-any.whl "$FIXTURE/partial/" 2>/dev/null
case_is "a pure wheel with no sdist" 1 "no sdist" \
    env DIST="$FIXTURE/partial" INDEX="$LOCAL" sh "$TOOL"

# A project the index HAS is not offered for creation.
mkdir -p "$FIXTURE/index/pypi/metta-arrays"
printf '{}' > "$FIXTURE/index/pypi/metta-arrays/json"
case_is "a project the index already holds" 0 "metta-arrays             on PyPI already" \
    env DIST="$FIXTURE/dist" INDEX="$LOCAL" sh "$TOOL"

# An sdist with no wheel is the row the rule did not decide, so it passed.
# Named on a project the index does NOT hold: the fixture index is shared and
# the case above planted metta-arrays in it, which took that project out of
# the to-create set and made this case pass for the wrong reason.
mkdir -p "$FIXTURE/sdistonly"
cp "$FIXTURE/dist"/metta_pandas-0.9.0.tar.gz "$FIXTURE/sdistonly/" 2>/dev/null
case_is "an sdist with no wheel" 1 "metta-pandas(sdist, no wheel)" \
    env DIST="$FIXTURE/sdistonly" INDEX="$LOCAL" sh "$TOOL"

# A binary distribution owes no sdist, so the completeness rule must not fire
# on the one whose wheels carry a platform tag. Every OTHER project has to be
# on the index for this to isolate it: the check reads the whole to-create
# set, so a dist holding one project's files reports the other thirteen as
# empty, which is what this case said the first time it ran.
for name in $projects; do
    [ "$name" = pymetta-host ] && continue
    mkdir -p "$FIXTURE/index/pypi/$name"
    printf '{}' > "$FIXTURE/index/pypi/$name/json"
done
mkdir -p "$FIXTURE/binary"
cp "$FIXTURE/dist"/pymetta_host-* "$FIXTURE/binary/" 2>/dev/null
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
# disagree. Planted on pymetta-host because by here every other project is in
# the shared fixture index, so it is the only one still to create and the only
# one whose artifacts the check reads.
mkdir -p "$FIXTURE/badversion"
cp "$FIXTURE/dist"/* "$FIXTURE/badversion/" 2>/dev/null
cp "$FIXTURE/dist"/pymetta_host-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl \
   "$FIXTURE/badversion/pymetta_host-1.0.0-cp312-cp312-manylinux_2_28_x86_64.whl" 2>/dev/null
case_is "an artifact carrying the refused version" 1 "1.0.0 is not a version" \
    env DIST="$FIXTURE/badversion" INDEX="$LOCAL" sh "$TOOL"

mkdir -p "$FIXTURE/badzip"
cp "$FIXTURE/dist"/* "$FIXTURE/badzip/" 2>/dev/null
cp "$FIXTURE/dist"/pymetta_host-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl \
   "$FIXTURE/badzip/pymetta_host-1.0.0.zip" 2>/dev/null
case_is "a refused version in an extension no list names" 1 "1.0.0 is not a version" \
    env DIST="$FIXTURE/badzip" INDEX="$LOCAL" sh "$TOOL"

printf 'publish-selftest: %s defect(s) over 13 cases, every refusal the tool can make\n' "$failures"
[ "$failures" -eq 0 ]
