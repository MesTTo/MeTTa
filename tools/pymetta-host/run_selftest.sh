#!/bin/sh
# Purpose: hold run.sh's reuse of a finished host build to the cases it can
#   get wrong, without docker, a network or a clone.
#
# Assumes: python3 with tomllib, and a writable ai-tmp. Runs this directory's
#   own run.sh and patch-root.sh in a planted repository whose docker and
#   fetch-source.sh are stubs that record each call and make the directories
#   a stage would, so no case passes or fails because an image or swipl-devel
#   moved.
# Guarantees:
#   - a run of the three stages compiles, mounts /src for the compile stages
#     alone, and writes OUT/host-inputs
#   - a second run over the same inputs skips both compile stages, fetches no
#     source, mounts no /src, still assembles, and leaves OUT/host-inputs as
#     it was
#   - another patch, another file of tools/pymetta-host, another interpreter
#     or another image each make the next run compile again and name the line
#     that differs
#   - a run of one compile stage, or one from a SRC the caller supplied, leaves
#     no OUT/host-inputs, and so does a run whose second compile stage fails
#   - a record whose OUT/swipl or OUT/janus is gone compiles again
# Decides: RUN_SH, the run.sh under test, defaulting to this directory's, and
#   RUN_SELFTEST_WORK, defaulting to ai-tmp/run-selftest:
#   tests/checks/check_host_reuse_mutations.py points both elsewhere to run
#   this against each mutant it makes.
# Fails when: run where ai-tmp is not writable.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
WORK=${RUN_SELFTEST_WORK:-$ROOT/ai-tmp/run-selftest}
REPO=$WORK/repo
failures=0; cases=0

rm -rf "$WORK"
mkdir -p "$REPO/tools/pymetta-host/host-only" "$REPO/tests/checks/host_workarounds" \
    "$REPO/extensions/python" "$WORK/bin" "$WORK/dist"
cp "${RUN_SH:-$HERE/run.sh}" "$REPO/tools/pymetta-host/run.sh"
cp "$HERE/patch-root.sh" "$REPO/tools/pymetta-host/"
printf 'build\n' > "$REPO/tools/pymetta-host/build-swipl.sh"
printf 'janus\n' > "$REPO/tools/pymetta-host/build-janus.sh"
printf 'ledger\n' > "$REPO/tests/checks/host_workarounds/a.patch"
printf 'host-only\n' > "$REPO/tools/pymetta-host/host-only/b.patch"
interpreters() {
    printf '[project]\nclassifiers = [%s]\n' "$1" > "$REPO/extensions/python/pyproject.toml"
}
interpreters '"Programming Language :: Python :: 3.12"'
# fetch-source.sh as run.sh calls it: it leaves the tree at DEST or
# ai-tmp/swipl-src, and here it only says it ran.
cat > "$REPO/tools/pymetta-host/fetch-source.sh" <<'EOF'
echo fetch >> "$(dirname "$0")/../../../calls"
mkdir -p "$(dirname "$0")/../../ai-tmp/swipl-src"
EOF
printf 'sha256:one\n' > "$WORK/image"
# docker as run.sh uses it: `image inspect` answers the planted image, and
# `run` records the stage and whether /src was mounted, makes what the stage
# would, and fails the stage named in $WORK/fail.
cat > "$WORK/bin/docker" <<'EOF'
#!/bin/sh
WORK=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case $1 in
    image) cat "$WORK/image" ;;
    pull) ;;
    run)
        out=; src=no
        for arg in "$@"; do
            case $arg in *:/out) out=${arg%:/out} ;; *:/src) src=yes ;; esac
        done
        last=; for arg in "$@"; do last=$arg; done
        stage=${last##*/}
        echo "$stage src=$src" >> "$WORK/calls"
        [ "$(cat "$WORK/fail" 2>/dev/null)" != "$stage" ] || exit 1
        case $stage in
            build-swipl.sh) mkdir -p "$out/swipl" ;;
            build-janus.sh) mkdir -p "$out/janus" ;;
            assemble.sh) mkdir -p "$out/dist" ;;
        esac ;;
esac
EOF
chmod +x "$WORK/bin/docker"

# One run of run.sh over the planted repository; its calls and output are
# what each case reads.
run() {
    : > "$WORK/calls"
    env -u DEST SRC="${RUN_SRC:-}" PATH="$WORK/bin:$PATH" OUT="$WORK/out" DIST="$WORK/dist" \
        bash "$REPO/tools/pymetta-host/run.sh" "$@" > "$WORK/log" 2>&1 ||
        echo "run.sh exit $?" >> "$WORK/calls"
}
calls() { tr '\n' ';' < "$WORK/calls"; }
expect() {
    cases=$((cases + 1))
    [ "$2" = "$3" ] && return 0
    printf '  %s: wanted [%s], got [%s]\n' "$1" "$2" "$3"
    failures=$((failures + 1))
}
recorded() { [ -f "$WORK/out/host-inputs" ] && echo recorded || echo absent; }
names() { grep -q -F -- "$1" "$WORK/log" && echo named || echo unnamed; }
all() { run build-swipl.sh build-janus.sh assemble.sh; }
compiled='fetch;build-swipl.sh src=yes;build-janus.sh src=yes;assemble.sh src=no;'

all
expect "a first run" "$compiled" "$(calls)"
expect "a first run's record" recorded "$(recorded)"
# Read tolerantly, so a run.sh that writes no record fails these cases rather
# than stopping the test.
first=$(cat "$WORK/out/host-inputs" 2>/dev/null || true)
expect "the record lists the patches in stack order" \
    "tests/checks/host_workarounds/a.patch;tools/pymetta-host/host-only/b.patch;" \
    "$(sed -n 's/^patch \([^ ]*\) .*/\1/p' "$WORK/out/host-inputs" | tr '\n' ';')"

all
expect "a run over the same inputs" 'assemble.sh src=no;' "$(calls)"
expect "the same inputs keep the record" "$first" "$(cat "$WORK/out/host-inputs")"

# Each input the key holds, changed alone, makes the next run compile and
# names its line.
for change in patch file tags image; do
    case $change in
        patch) printf 'ledger, revised\n' > "$REPO/tests/checks/host_workarounds/a.patch"
               line='patch tests/checks/host_workarounds/a.patch' ;;
        file)  printf 'build, other cmake arguments\n' > "$REPO/tools/pymetta-host/build-swipl.sh"
               line='file tools/pymetta-host/build-swipl.sh' ;;
        tags)  interpreters '"Programming Language :: Python :: 3.12", "Programming Language :: Python :: 3.13"'
               line='tags cp312 cp313' ;;
        image) printf 'sha256:two\n' > "$WORK/image"
               line='image quay.io/pypa/manylinux_2_28_x86_64:latest sha256:two' ;;
    esac
    all
    expect "another $change" "$compiled" "$(calls)"
    expect "another $change names its line" named "$(names "> $line")"
    expect "another $change is recorded" recorded "$(recorded)"
done

printf 'ledger, third\n' > "$REPO/tests/checks/host_workarounds/a.patch"
run build-swipl.sh
expect "one compile stage alone" 'fetch;build-swipl.sh src=yes;' "$(calls)"
expect "one compile stage alone leaves no record" absent "$(recorded)"
all
expect "the run after one stage alone" "$compiled" "$(calls)"

mkdir -p "$WORK/edited"
RUN_SRC=$WORK/edited
all
RUN_SRC=
expect "a supplied SRC" 'build-swipl.sh src=yes;build-janus.sh src=yes;assemble.sh src=no;' "$(calls)"
expect "a supplied SRC leaves no record" absent "$(recorded)"

all
printf 'build-janus.sh\n' > "$WORK/fail"
printf 'ledger, fourth\n' > "$REPO/tests/checks/host_workarounds/a.patch"
all
rm -f "$WORK/fail"
expect "a failed second compile stage" 'fetch;build-swipl.sh src=yes;build-janus.sh src=yes;run.sh exit 1;' "$(calls)"
expect "a failed second compile stage leaves no record" absent "$(recorded)"

all
rm -rf "$WORK/out/janus"
all
expect "a record whose OUT/janus is gone" "$compiled" "$(calls)"

run assemble.sh
expect "assembling alone" 'assemble.sh src=no;' "$(calls)"

printf 'run_selftest: %s of %s case(s) failed\n' "$failures" "$cases"
[ "$failures" -eq 0 ]
