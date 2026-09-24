#!/bin/sh
# Purpose: prove tools/battery.sh refuses a battery tree that is not a copy of
#   its source, by planting each shape of drift in a fixture and requiring a
#   refusal that names it; prove it can CLEAR what a previous run left,
#   including a git repository a fixture wrote and a cache inside a directory
#   the source does not have; prove a provisioned battery answers `git`
#   about ITSELF rather than about the checkout it sits inside, and that git
#   run in one never reaches that checkout; prove a battery re-provisioned
#   from another source reads that source's installs; prove BATTERY_KEEP
#   carries the kept paths and holds every other path at its repository's
#   base, in the tree and in a component, a component ahead of its pin held
#   at the pin with its own components at what the pin records, one the pin
#   lacks dropped, and one holding a kept path carried at its own HEAD; prove
#   verify refuses a repository whose git left its base; and prove a run
#   naming no index takes the
#   lowest free one and reuses it, and prune removes only what no run holds
#   and nothing touched within its window.
# Assumes: tools/battery.sh sits beside this file; a writable ai-tmp/.
# Guarantees: exits nonzero if any planted drift goes unreported, or if
#   anything the snapshot leaves out on purpose is reported as drift: scratch,
#   caches, a compiled artifact, the record's lock directory.
# Fails when: run concurrently with itself, since it owns one fixture path; or
#   where `git worktree add` is unavailable, which the identity case needs.
# Decides: the drift shapes are enumerated rather than sampled. The space is
#   closed -- a file can differ, be extra, or be absent -- so exhausting it
#   discharges the claim outright instead of supporting it.
set -eu

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
BATTERY="$HERE/battery.sh"
# Every spawn goes through the repository's one bound, so a killed selftest
# cannot leave a provision rsyncing with nothing holding its ceiling.
bounded() { sh "$HERE/bounded.sh" "$@"; }
FIXTURE=$(cd "$HERE/.." && pwd)/ai-tmp/battery-selftest
INDEX=selftest
failures=0

# Asked for rather than recomputed: a second copy of the layout rule here is a
# second thing to keep in step, and it was wrong the first time. The battery
# is removed at both ends, because one a failed run leaves behind carries
# state, a git identity among it, into the next run's first cases.
TREE=$(bounded sh "$BATTERY" path "$INDEX")
cleanup() { rm -rf "$FIXTURE" "$TREE"; }
trap cleanup EXIT
rm -rf "$TREE"

plant_source() {
    rm -rf "$FIXTURE"
    mkdir -p "$FIXTURE/src/package/inner"
    printf 'one\n'   > "$FIXTURE/src/top.txt"
    printf 'two\n'   > "$FIXTURE/src/package/mid.txt"
    printf 'three\n' > "$FIXTURE/src/package/inner/deep.txt"
}

# Each case names what it planted, so a failure says which shape went unseen
# rather than only that something did.
expect() {
    what=$1; want=$2; shift 2
    if BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" verify "$INDEX" > "$FIXTURE/out" 2>&1
    then got=0; else got=$?; fi
    if [ "$got" -eq 0 ] && [ "$want" -eq 0 ]; then
        echo "  ok   $what: accepted, as it should be"
    elif [ "$got" -ne 0 ] && [ "$want" -ne 0 ]; then
        if [ $# -gt 0 ] && ! grep -q -- "$1" "$FIXTURE/out"; then
            echo "  FAIL $what: refused, but did not name $1"; cat "$FIXTURE/out"
            failures=$((failures + 1))
        else
            echo "  ok   $what: refused, naming ${1:-the drift}"
        fi
    else
        echo "  FAIL $what: wanted exit ${want} and got ${got}"; cat "$FIXTURE/out"
        failures=$((failures + 1))
    fi
}

plant_source
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"

echo "battery selftest:"
expect "an untouched copy" 0

printf 'CHANGED\n' > "$TREE/package/inner/deep.txt"
expect "a modified file" 1 "deep.txt"

BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
printf 'stray\n' > "$TREE/package/extra.txt"
expect "a file the source does not have" 1 "extra.txt"

BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
rm "$TREE/package/mid.txt"
expect "a file the battery is missing" 1 "mid.txt"

# The regression this tool was born with: provision writes ai-tmp/ into the
# tree it has just copied, which moves the parent directory's mtime. Before -O
# that read as drift, so the checker failed on its own writes.
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
mkdir -p "$TREE/ai-tmp" "$TREE/package/__pycache__"
printf 'log\n' > "$TREE/ai-tmp/run.log"
printf 'bytes\n' > "$TREE/package/__pycache__/mid.pyc"
expect "excluded scratch written into the battery" 0

# Two runs that pick one free index at once must not provision it together:
# the claim is taken before anything is written, and a second claimant is
# refused while the first holds it. The holder here is this shell, on its own
# descriptor, so no background process and no wait are needed; releasing it
# frees the index again.
exec 8>"$(dirname "$TREE")/wt-battery-$INDEX.lock"
flock -n 8
if BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
       > "$FIXTURE/out" 2>&1
then
    echo "  FAIL a battery another run has claimed: provisioned anyway"
    failures=$((failures + 1))
elif grep -q 'claimed by another run' "$FIXTURE/out"; then
    echo "  ok   a battery another run has claimed: refused, naming the claim"
else
    echo "  FAIL a battery another run has claimed: refused for another reason"
    cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
exec 8>&-
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
expect "a battery whose claim was released" 0

# A command run in a battery must never reach the checkout the battery sits
# inside through git. This source is not a repository, so the battery has no
# .git of its own, and before the discovery ceiling git walked up and answered
# about the enclosing checkout, which is how a `git reset --hard HEAD` meant
# for a battery reverted every uncommitted file in wt-merge [2026-09-24 11:06].
home=$(cd "$HERE/.." && git rev-parse --show-toplevel)
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" run "$INDEX" -- \
    sh -c 'git rev-parse --show-toplevel' > "$FIXTURE/out" 2>&1 || true
ceiling_log=$(sed -n 's/^battery [^:]*: exit [0-9]*, log //p' "$FIXTURE/out")
if [ ! -f "$ceiling_log" ]; then
    echo "  FAIL the run named no log it kept:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
elif grep -qxF "$home" "$ceiling_log"; then
    echo "  FAIL git in a battery reached the enclosing checkout $home"
    failures=$((failures + 1))
elif [ -e "$TREE/.git" ]; then
    echo "  FAIL a battery of a directory that is not a repository's top was given a git identity"
    failures=$((failures + 1))
else
    echo "  ok   git in a battery stops at the battery instead of reaching the enclosing checkout"
fi
rm -f "$ceiling_log"

# A compiled Prolog artifact is a cache whose copy is wrong rather than stale:
# SWI loads a .qlf found outside the directory it was compiled in as moved and
# charges 8 inferences per recorded source for it. So the source's is never
# copied, the battery's own is not drift, and the next provision sweeps it.
printf 'compiled in the source\n' > "$FIXTURE/src/package/mid.qlf"
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/package/mid.qlf" ]; then
    echo "  FAIL the source's compiled artifact: copied into the battery"
    failures=$((failures + 1))
else
    echo "  ok   the source's compiled artifact: left behind"
fi
rm "$FIXTURE/src/package/mid.qlf"
printf 'compiled in the battery\n' > "$TREE/package/own.qlf"
expect "an artifact the battery compiled itself" 0
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/package/own.qlf" ]; then
    echo "  FAIL the battery's compiled artifact: kept by the next provision"
    failures=$((failures + 1))
else
    echo "  ok   the battery's compiled artifact: swept by the next provision"
fi

# The record tool's lock directory moves whenever any session writes the
# record, so it is never copied, a lock written after the copy is not drift in
# either tree, and the next provision sweeps whatever the battery holds.
mkdir -p "$FIXTURE/src/.agenticmind/locks"
printf 'held\n' > "$FIXTURE/src/.agenticmind/locks/record.lock"
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/.agenticmind" ]; then
    echo "  FAIL the record's lock directory: copied into the battery"
    failures=$((failures + 1))
else
    echo "  ok   the record's lock directory: left behind"
fi
printf 'rewritten\n' > "$FIXTURE/src/.agenticmind/locks/record.lock"
mkdir -p "$TREE/.agenticmind/locks"
printf 'written in the battery\n' > "$TREE/.agenticmind/locks/record.lock"
expect "a record lock written after the copy, in either tree" 0
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/.agenticmind" ]; then
    echo "  FAIL the battery's record lock directory: kept by the next provision"
    failures=$((failures + 1))
else
    echo "  ok   the battery's record lock directory: swept by the next provision"
fi
rm -rf "$FIXTURE/src/.agenticmind"

# Drift is one half of the contract and clearing it is the other: a battery
# that cannot be re-provisioned is a battery lost. A gate run leaves what the
# source does not have, and some of it is git repositories -- the packaging
# fixtures write repos/<name>/.git. While the .git rule was an `--exclude` it
# protected those at the receiver, so `repos/` could never be emptied and
# survived the provision that was supposed to remove it -- loudly on the real
# tree, `cannot delete non-empty directory: repos` and exit 1, leaving that
# index unusable [measured 2026-09-20 on wt-battery-6], and SILENTLY at this
# fixture's depth, exit 0 with the directory still there. The quiet one is
# why this asserts the tree rather than the status.
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
mkdir -p "$TREE/repos/fixture_lib/.git/refs/heads"
printf 'ref: refs/heads/master\n' > "$TREE/repos/fixture_lib/.git/HEAD"
printf 'built\n' > "$TREE/repos/fixture_lib/setup.py"
if BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
       > "$FIXTURE/out" 2>&1
then
    if [ -e "$TREE/repos" ]; then
        echo "  FAIL a run's leftover git repository: provision said it worked" \
             "and repos/ is still there"
        failures=$((failures + 1))
    else
        echo "  ok   a run's leftover git repository: cleared by the next provision"
    fi
else
    echo "  FAIL a run's leftover git repository: provision refused"
    cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
expect "the tree that provision has just cleared" 0

# The same stranding one level along: a PROTECTED entry inside a directory the
# source does not have keeps that directory non-empty, and rsync will not
# remove a non-empty directory. A run left .mutmut/mutants/**/__pycache__ and
# `.mutmut/` became permanent [measured 2026-09-20]. Naming .mutmut in the
# exclusions would fix that directory and strand on the next tool's scratch,
# so the caches are swept instead and this is what says so.
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
mkdir -p "$TREE/scratch/inner/__pycache__"
printf 'bytes\n' > "$TREE/scratch/inner/__pycache__/mid.pyc"
if BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
       > "$FIXTURE/out" 2>&1
then
    if [ -e "$TREE/scratch" ]; then
        echo "  FAIL a cache in a directory the source lacks: scratch/ survived"
        failures=$((failures + 1))
    else
        echo "  ok   a cache in a directory the source lacks: cleared with it"
    fi
else
    echo "  FAIL a cache in a directory the source lacks: provision refused"
    cat "$FIXTURE/out"
    failures=$((failures + 1))
fi

# A battery has to answer `git` about ITSELF. It lives inside the checkout, so
# without its own .git every git command and every root-marker walk run in one
# reports on the ENCLOSING tree: the submodules lane refused all eight
# components, root-walks resolved a marker in the parent, and the llms selftest
# resolved a path that exists only under ai-tmp/ [measured 2026-09-20, in a
# whole-gate run where none of it was about the tree under test]. This needs a
# real repository as the source, which the layout fixture above is not.
REPO="$FIXTURE/repo"
mkdir -p "$REPO"
(   cd "$REPO" && git init -q .
    printf 'one\n' > top.txt
    git add top.txt
    git -c user.email=selftest@example.invalid -c user.name=selftest \
        commit -qm "fixture" ) > "$FIXTURE/out" 2>&1
BATTERY_SOURCE="$REPO" bounded sh "$BATTERY" provision "$INDEX" > "$FIXTURE/out" 2>&1
answered=$(git -C "$TREE" rev-parse --show-toplevel 2>/dev/null)
if [ "$answered" = "$(cd "$TREE" && pwd -P)" ]; then
    echo "  ok   the battery answers git about itself, not about its parent"
else
    echo "  FAIL the battery answers git about '$answered', wanted '$TREE'"
    failures=$((failures + 1))
fi
git -C "$REPO" worktree remove --force "$TREE" > /dev/null 2>&1 || true
rm -rf "$TREE/.git"

# An install directory is excluded so a battery's own is not swept, which also
# means one that never had it never gets it: the lane needing it then fails in
# the battery and passes in the checkout. provision LINKS what the source has,
# and the exclusion must protect a SYMLINK, which a pattern ending in `/` does
# not match -- with one, verify reported the link it had just been given as
# drift [measured 2026-09-20].
mkdir -p "$FIXTURE/src/node_modules/pkg"
printf 'dep\n' > "$FIXTURE/src/node_modules/pkg/index.js"
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/node_modules/pkg/index.js" ]; then
    echo "  ok   an install directory: reachable from the battery"
else
    echo "  FAIL an install directory: the battery cannot reach it"
    failures=$((failures + 1))
fi
expect "the battery holding a linked install directory" 0

# The same battery provisioned from ANOTHER source must read that source's
# installs. The link is excluded from the snapshot, so it survived a change of
# BATTERY_SOURCE and the battery ran the first source's dependencies under the
# second source's code [measured 2026-09-23 on battery 4].
rm -rf "$FIXTURE/other"
cp -R "$FIXTURE/src" "$FIXTURE/other"
printf 'other dep\n' > "$FIXTURE/other/node_modules/pkg/index.js"
BATTERY_SOURCE="$FIXTURE/other" bounded sh "$BATTERY" provision "$INDEX"
if [ "$(cat "$TREE/node_modules/pkg/index.js" 2>/dev/null)" = "other dep" ]; then
    echo "  ok   a second source: the battery reads that source's install directory"
else
    echo "  FAIL a second source: the battery still reads $(readlink "$TREE/node_modules")"
    failures=$((failures + 1))
fi
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
rm -rf "$FIXTURE/other"

# A battery provisioned a SECOND time takes the source's current revision. It
# used to keep whatever identity it already had, because the check asked only
# whether a .git existed: on 2026-09-22 ai-tmp/wt-battery-1 held files from
# 01287442c and a git that answered cf282de8f, so `git ls-files` omitted every
# file added between them and each lane reading the tracked set passed over a
# tree that was short. Nothing said so except the worktree lane, whose probe
# could not check components out.
( cd "$FIXTURE/src" && git init -q . 2>/dev/null; \
  git -c user.name=t -c user.email=t@t add -A >/dev/null 2>&1; \
  git -c user.name=t -c user.email=t@t commit -qm first >/dev/null 2>&1 ) || true
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
printf 'second\n' > "$FIXTURE/src/second.txt"
( cd "$FIXTURE/src" && git -c user.name=t -c user.email=t@t add -A >/dev/null 2>&1; \
  git -c user.name=t -c user.email=t@t commit -qm second >/dev/null 2>&1 ) || true
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
want=$(git -C "$FIXTURE/src" rev-parse HEAD 2>/dev/null)
have=$(git -C "$TREE" rev-parse HEAD 2>/dev/null)
if [ -n "$want" ] && [ "$want" = "$have" ]; then
    echo "  ok   re-provisioning: the battery's git identity followed the source"
else
    echo "  FAIL re-provisioning: source is $want and the battery answers $have,"
    echo "       so every lane reading the tracked set would read the older tree"
    failures=$((failures + 1))
fi
if git -C "$TREE" ls-files --error-unmatch second.txt >/dev/null 2>&1; then
    echo "  ok   re-provisioning: a file added since the first provision is tracked"
else
    echo "  FAIL re-provisioning: second.txt is on disk and not in the battery's index"
    failures=$((failures + 1))
fi

# A battery a COMPONENT holds is not part of a snapshot. ai-tmp/ covers the
# trees this script makes, and a component's own ai-battery-N sits outside it:
# one such copy, 127 MB of a stale engine, was being rsynced into every
# provision, and a stale engine inside a battery is a tree a reader or a path
# walk finds and believes. Asserted on the TREE rather than on verify's exit,
# because the copy is silent: it drifts nothing, it just should not be there.
mkdir -p "$FIXTURE/src/component/ai-battery-9"
printf 'stale\n' > "$FIXTURE/src/component/ai-battery-9/engine.pl"
BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX"
if [ -e "$TREE/component/ai-battery-9" ]; then
    echo "  FAIL a component's own battery was copied into the snapshot"
    failures=$((failures + 1))
else
    echo "  ok   a component's own battery stayed out of the snapshot"
fi

# BATTERY_KEEP restricts a battery to what is committed plus the named paths,
# so a verdict about one session's change does not also carry another's. The
# source here and a component inside it each hold a kept change and an unkept
# modification, deletion and untracked file; the battery must carry the kept
# ones and hold HEAD at every other.
# The component mounts a repository of its own, as the seat mounts its twins,
# declared only in the component's .gitmodules.
(   mkdir -p "$FIXTURE/src/comp/inner" && cd "$FIXTURE/src/comp/inner" && git init -q . &&
    printf 'inner one\n' > e.txt && git add e.txt &&
    git -c user.name=t -c user.email=t@t commit -qm inner &&
    cd .. && git init -q . &&
    printf 'comp one\n' > c.txt && printf 'comp two\n' > d.txt &&
    printf '[submodule "inner"]\n\tpath = inner\n\turl = ./inner\n' > .gitmodules &&
    git add c.txt d.txt .gitmodules inner &&
    git -c user.name=t -c user.email=t@t commit -qm comp ) > "$FIXTURE/out" 2>&1
(   cd "$FIXTURE/src" &&
    printf '[submodule "comp"]\n\tpath = comp\n\turl = ./comp\n' > .gitmodules &&
    git add .gitmodules comp top.txt package &&
    git -c user.name=t -c user.email=t@t commit -qm component ) > "$FIXTURE/out" 2>&1
printf 'ours\n' > "$FIXTURE/src/top.txt"
printf 'theirs\n' > "$FIXTURE/src/package/mid.txt"
rm "$FIXTURE/src/package/inner/deep.txt"
printf 'stray\n' > "$FIXTURE/src/package/stray.txt"
printf 'comp ours\n' > "$FIXTURE/src/comp/c.txt"
printf 'comp theirs\n' > "$FIXTURE/src/comp/d.txt"
printf 'comp stray\n' > "$FIXTURE/src/comp/new.txt"
printf 'inner theirs\n' > "$FIXTURE/src/comp/inner/e.txt"
holds() {
    if [ "$3" = absent ]; then
        [ ! -e "$TREE/$2" ] && echo "  ok   $1" ||
            { echo "  FAIL $1: $2 is present"; failures=$((failures + 1)); }
    elif [ "$(cat "$TREE/$2" 2>/dev/null)" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: $2 reads '$(cat "$TREE/$2" 2>/dev/null)', wanted '$3'"
        failures=$((failures + 1))
    fi
}
restricted() {
    BATTERY_KEEP="top.txt comp/c.txt" BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" "$@"
}
if restricted provision "$INDEX" > "$FIXTURE/out" 2>&1; then
    holds "a kept change is carried" top.txt ours
    holds "an unkept modification is put back to HEAD" package/mid.txt two
    holds "an unkept deletion is put back" package/inner/deep.txt three
    holds "an unkept untracked file is dropped" package/stray.txt absent
    holds "a kept change inside a component is carried" comp/c.txt "comp ours"
    holds "an unkept change inside a component is put back" comp/d.txt "comp two"
    holds "an unkept untracked file inside a component is dropped" comp/new.txt absent
    holds "an unkept change inside a component's own component is put back" comp/inner/e.txt "inner one"
    if restricted verify "$INDEX" > "$FIXTURE/out" 2>&1; then
        echo "  ok   a restricted battery verifies against HEAD plus its kept paths"
    else
        echo "  FAIL a restricted battery did not verify:"; cat "$FIXTURE/out"
        failures=$((failures + 1))
    fi
    if BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" verify "$INDEX" > "$FIXTURE/out" 2>&1; then
        echo "  FAIL an unrestricted verify accepted a battery that differs from the working tree"
        failures=$((failures + 1))
    else
        echo "  ok   an unrestricted verify refuses a restricted battery"
    fi
    printf 'tampered\n' > "$TREE/package/mid.txt"
    if restricted verify "$INDEX" > "$FIXTURE/out" 2>&1; then
        echo "  FAIL a restricted path that no longer holds HEAD was accepted"
        failures=$((failures + 1))
    elif grep -q 'package/mid.txt' "$FIXTURE/out"; then
        echo "  ok   a restricted path that no longer holds HEAD is refused, naming it"
    else
        echo "  FAIL a tampered restricted path was refused without naming it:"; cat "$FIXTURE/out"
        failures=$((failures + 1))
    fi
else
    echo "  FAIL a restricted provision refused:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
if BATTERY_KEEP='' BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
       > "$FIXTURE/out" 2>&1; then
    holds "an empty BATTERY_KEEP gives the committed tree" top.txt one
    holds "an empty BATTERY_KEEP gives a component's committed tree" comp/c.txt "comp one"
    holds "an empty BATTERY_KEEP gives a nested component's committed tree" comp/inner/e.txt "inner one"
else
    echo "  FAIL a provision with an empty BATTERY_KEEP refused:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi

# A component's own HEAD can be ahead of the commit its parent pins, and the
# committed tree holds the pin: a committed-tree battery once carried
# extensions/node at its unpinned e0874c3 where the superproject pins
# 2ea06e2e, and the evidence lane failed a Node test title e0874c3 had renamed
# [the record, i-keep-component-head, superproject 59c432756]. Here comp moves
# to c2, which adds g.txt, records inner at i2 and mounts a new component,
# extra; inner then moves on to i3, which nothing records. The superproject
# still pins comp at c1, which records inner at i1 and has no extra.
c1=$(git -C "$FIXTURE/src/comp" rev-parse HEAD)
i1=$(git -C "$FIXTURE/src/comp/inner" rev-parse HEAD)
(   cd "$FIXTURE/src/comp/inner" &&
    printf 'inner later\n' > f.txt && git add f.txt &&
    git -c user.name=t -c user.email=t@t commit -qm 'inner later' &&
    mkdir -p ../extra && cd ../extra && git init -q . &&
    printf 'extra\n' > x.txt && git add x.txt &&
    git -c user.name=t -c user.email=t@t commit -qm extra &&
    cd .. &&
    printf '[submodule "inner"]\n\tpath = inner\n\turl = ./inner\n' > .gitmodules &&
    printf '[submodule "extra"]\n\tpath = extra\n\turl = ./extra\n' >> .gitmodules &&
    printf 'comp later\n' > g.txt &&
    git add g.txt inner extra .gitmodules &&
    git -c user.name=t -c user.email=t@t commit -qm 'comp later' &&
    cd inner && printf 'inner latest\n' > i.txt && git add i.txt &&
    git -c user.name=t -c user.email=t@t commit -qm 'inner latest' ) > "$FIXTURE/out" 2>&1
c2=$(git -C "$FIXTURE/src/comp" rev-parse HEAD)
i2=$(git -C "$FIXTURE/src/comp/inner" rev-parse HEAD~1)
i3=$(git -C "$FIXTURE/src/comp/inner" rev-parse HEAD)
extra=$(git -C "$FIXTURE/src/comp/extra" rev-parse HEAD)
answers() {
    have=$(git -C "$TREE/$2" rev-parse HEAD 2>/dev/null || true)
    if [ "$have" = "$3" ]; then echo "  ok   $1"; else
        echo "  FAIL $1: $2 answers '${have:-nothing}', wanted $3"
        failures=$((failures + 1))
    fi
}
# Provisions and verifies with the named BATTERY_KEEP, or none when unnamed.
keeping() {
    if [ $# -eq 0 ]; then
        BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
            > "$FIXTURE/out" 2>&1 &&
        BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" verify "$INDEX" \
            >> "$FIXTURE/out" 2>&1
    else
        BATTERY_KEEP=$1 BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" provision "$INDEX" \
            > "$FIXTURE/out" 2>&1 &&
        BATTERY_KEEP=$1 BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" verify "$INDEX" \
            >> "$FIXTURE/out" 2>&1
    fi
}
if keeping ''; then
    answers "the committed tree holds a component ahead of its pin at the pin" comp "$c1"
    holds "a file the component added after its pin is absent" comp/g.txt absent
    holds "the component's uncommitted change is put back to the pin" comp/c.txt "comp one"
    answers "its own component holds the commit the pin records" comp/inner "$i1"
    holds "a file that component added after that commit is absent" comp/inner/f.txt absent
    holds "a component the pin does not record is dropped" comp/extra absent
    git -C "$TREE/comp" update-ref --no-deref HEAD "$c2"
    if BATTERY_KEEP='' BATTERY_SOURCE="$FIXTURE/src" bounded sh "$BATTERY" verify "$INDEX" \
           > "$FIXTURE/out" 2>&1; then
        echo "  FAIL a component whose git left its pin was accepted"
        failures=$((failures + 1))
    elif grep -q "comp answers $c2" "$FIXTURE/out"; then
        echo "  ok   a component whose git left its pin is refused, naming it"
    else
        echo "  FAIL a component whose git left its pin was refused without naming it:"
        cat "$FIXTURE/out"; failures=$((failures + 1))
    fi
else
    echo "  FAIL a committed-tree battery of a component ahead of its pin:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
if keeping comp/c.txt; then
    answers "a component holding a kept path is carried at its own HEAD" comp "$c2"
    holds "so its file added after the pin is present" comp/g.txt "comp later"
    holds "and the kept path is carried" comp/c.txt "comp ours"
    answers "its own component holds the commit that HEAD records" comp/inner "$i2"
    holds "a file added after that commit is absent" comp/inner/i.txt absent
    answers "a component that HEAD records is held there" comp/extra "$extra"
else
    echo "  FAIL a battery keeping a path inside a component ahead of its pin:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
if keeping comp; then
    answers "a component inside a kept one is carried at its own HEAD" comp/inner "$i3"
    holds "with its uncommitted change" comp/inner/e.txt "inner theirs"
    holds "and the kept component's untracked file" comp/new.txt "comp stray"
else
    echo "  FAIL a battery keeping a whole component ahead of its pin:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
if keeping; then
    answers "unrestricted, a component is at its own HEAD" comp "$c2"
    answers "unrestricted, its own component is at its own HEAD" comp/inner "$i3"
else
    echo "  FAIL an unrestricted battery of components ahead of their pins:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi

# A source that changes while its battery is copied made verify refuse a sound
# copy: a commit moves a base, and a rebuild rewrites output the copy has just
# taken [2026-09-24 22:18, batteries 119 and 121 on the Node seat's build]. run
# copies again while verify's findings change, and stops when two copies find
# the same drift. A stand-in rsync first on PATH runs the real one and then,
# during a copy but never during verify's itemised dry run, does what
# SHIM_ACTION names to the source: commit once, rewrite a file once, or rewrite
# it on every copy. Each rewrite is dated an hour after the file's own mtime, not
# after the clock, so two rewrites in one second still differ.
SHIM="$FIXTURE/shim"
mkdir -p "$SHIM"
real_rsync=$(command -v rsync)
cat > "$SHIM/rsync" <<SHIMEOF
#!/bin/sh
"$real_rsync" "\$@"; shim_status=\$?
case " \$* " in
    *" -in "*) ;;
    *) shim_count=\$(cat "$FIXTURE/shim-count" 2>/dev/null || echo 0)
       shim_count=\$((shim_count + 1))
       echo "\$shim_count" > "$FIXTURE/shim-count"
       case \$SHIM_ACTION:\$shim_count in
           commit-once:1)
               git -C "$FIXTURE/src" -c user.name=t -c user.email=t@t \
                   commit -q --allow-empty -m moved ;;
           rewrite-once:1|rewrite-always:*)
               shim_then=\$(stat -c %Y "$FIXTURE/src/package/mid.txt")
               touch -d "@\$((shim_then + 3600))" "$FIXTURE/src/package/mid.txt" ;;
       esac ;;
esac
exit \$shim_status
SHIMEOF
chmod +x "$SHIM/rsync"
shimmed() {
    rm -f "$FIXTURE/shim-count"
    SHIM_ACTION=$1 PATH="$SHIM:$PATH" BATTERY_SOURCE="$FIXTURE/src" \
        bounded sh "$BATTERY" run "$INDEX" -- true > "$FIXTURE/out" 2>&1
}
if BATTERY_KEEP='' shimmed commit-once && grep -q 'copying again' "$FIXTURE/out"; then
    answers "a commit during the copy is copied again rather than refused" . \
        "$(git -C "$FIXTURE/src" rev-parse HEAD)"
else
    echo "  FAIL a commit during the copy refused the run:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
rm -f "$(sed -n 's/^battery [^:]*: exit [0-9]*, log //p' "$FIXTURE/out")"
if shimmed rewrite-once && grep -q 'copying again' "$FIXTURE/out"; then
    echo "  ok   a file rewritten during the copy is copied again rather than refused"
else
    echo "  FAIL a file rewritten during the copy refused the run:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
rm -f "$(sed -n 's/^battery [^:]*: exit [0-9]*, log //p' "$FIXTURE/out")"
if shimmed rewrite-always; then
    echo "  FAIL a file rewritten on every copy was accepted:"; cat "$FIXTURE/out"
    failures=$((failures + 1))
elif grep -q 'package/mid.txt' "$FIXTURE/out"; then
    echo "  ok   a file rewritten on every copy stops the run, naming it"
else
    echo "  FAIL a file rewritten on every copy stopped the run without naming it:"
    cat "$FIXTURE/out"; failures=$((failures + 1))
fi

# The battery now holds an identity from the repository above. Provisioned
# again from a directory that is not a repository, it must lose that identity,
# or git in it answers about the earlier repository's worktree.
mkdir -p "$FIXTURE/plain"
printf 'plain\n' > "$FIXTURE/plain/plain.txt"
BATTERY_SOURCE="$FIXTURE/plain" bounded sh "$BATTERY" provision "$INDEX" > "$FIXTURE/out" 2>&1
if [ -e "$TREE/.git" ]; then
    echo "  FAIL a battery re-provisioned from a non-repository kept its earlier git identity"
    failures=$((failures + 1))
else
    echo "  ok   a battery re-provisioned from a non-repository drops its earlier git identity"
fi

# A battery reused for a source that lacks one of its directories strands that
# directory when something the excludes keep sits inside it, here an install
# link; rsync reports it and exits 0, and verify then refuses for ever.
# Provision removes the stranded directory and copies again.
mkdir -p "$FIXTURE/first/gone/node_modules/pkg" "$FIXTURE/second"
printf 'first\n' > "$FIXTURE/first/gone/file.txt"
printf 'dep\n' > "$FIXTURE/first/gone/node_modules/pkg/index.js"
printf 'second\n' > "$FIXTURE/second/file.txt"
BATTERY_SOURCE="$FIXTURE/first" bounded sh "$BATTERY" provision "$INDEX" > "$FIXTURE/out" 2>&1
BATTERY_SOURCE="$FIXTURE/second" bounded sh "$BATTERY" provision "$INDEX" > "$FIXTURE/out" 2>&1
if BATTERY_SOURCE="$FIXTURE/second" bounded sh "$BATTERY" verify "$INDEX" > "$FIXTURE/out" 2>&1; then
    echo "  ok   a directory the next source lacks is removed even with an excluded entry inside"
else
    echo "  FAIL a battery reused for a source without one of its directories cannot verify:"
    cat "$FIXTURE/out"
    failures=$((failures + 1))
fi

# Callers used to name their own index, each settling on a range of its own, so
# batteries only accumulated. A run naming none takes the lowest free index and
# reuses it once free, and prune removes what no run holds and nothing touched.
# A pool of its own, so allocation here never takes one of this checkout's
# real batteries: a copy of the script in a repository of its own derives its
# pool from where it sits.
POOL="$FIXTURE/pool"
mkdir -p "$POOL/tools" "$FIXTURE/poolsource"
cp "$BATTERY" "$HERE/bounded.sh" "$POOL/tools/"
printf 'pooled\n' > "$FIXTURE/poolsource/file.txt"
( cd "$POOL" && git init -q . &&
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m pool ) > "$FIXTURE/out" 2>&1
pooled() {
    BATTERY_SOURCE="$FIXTURE/poolsource" bounded sh "$POOL/tools/battery.sh" run -- true 2>&1 |
        sed -n 's/^battery \([^:]*\): exit.*/\1/p'
}
allotted() {
    if [ "$2" = "$3" ]; then echo "  ok   $1"; else
        echo "  FAIL $1: took battery '$2', wanted $3"; failures=$((failures + 1)); fi
}
allotted "a run naming no index takes the lowest" "$(pooled)" 1
exec 7>"$POOL/ai-tmp/wt-battery-1.lock"
flock -n 7
allotted "a run naming no index passes over one another run holds" "$(pooled)" 2
exec 7>&-
allotted "a finished battery is reused rather than a new one made" "$(pooled)" 1

# A finished battery is the next run's lowest free index, so a log kept inside
# it was rewritten by that run: battery 4's read empty a minute after its run
# exited 0 [2026-09-24 17:25]. Each run's log is a file of its own beside the
# batteries, opening with the provenance of the tree it ran in.
logged() {
    BATTERY_SOURCE="$FIXTURE/poolsource" bounded sh "$POOL/tools/battery.sh" run -- echo "$1" 2>&1 |
        sed -n 's/^battery [^:]*: exit [0-9]*, log //p'
}
first_log=$(logged first-run)
second_log=$(logged second-run)
case ${first_log##*/}${second_log##*/} in
    battery-1-*battery-1-*) one_battery=yes ;;
    *) one_battery= ;;
esac
if [ -n "$one_battery" ] && [ "$first_log" != "$second_log" ] &&
   grep -qx first-run "$first_log" && ! grep -q second-run "$first_log" &&
   head -1 "$first_log" | grep -q '^source:'; then
    echo "  ok   a run's log survives the next run of its battery and names its tree"
else
    echo "  FAIL a run's log did not survive the next run of battery 1: '$first_log', '$second_log'"
    cat "$first_log" 2>/dev/null
    failures=$((failures + 1))
fi
touch -d '2 days ago' "$first_log"
aged() {
    find "$POOL/ai-tmp/wt-battery-$1" "$POOL/ai-tmp/wt-battery-$1/ai-tmp" -maxdepth 1 \
         -exec touch -h -d '2 days ago' {} +
}
aged 1
aged 2
exec 7>"$POOL/ai-tmp/wt-battery-1.lock"
flock -n 7
bounded sh "$POOL/tools/battery.sh" prune 6 > "$FIXTURE/out" 2>&1
exec 7>&-
if [ -e "$POOL/ai-tmp/wt-battery-2" ]; then
    echo "  FAIL prune kept a battery no run holds and nothing touched for two days"
    failures=$((failures + 1))
else
    echo "  ok   prune removes a battery no run holds and nothing touched within the window"
fi
if [ -e "$POOL/ai-tmp/wt-battery-1" ]; then
    echo "  ok   prune keeps a battery another run holds, however old"
else
    echo "  FAIL prune removed a battery another run held"
    failures=$((failures + 1))
fi
if [ -e "$first_log" ]; then
    echo "  FAIL prune kept a run log older than its window"
    failures=$((failures + 1))
elif [ ! -e "$second_log" ]; then
    echo "  FAIL prune removed a run log written within its window"
    failures=$((failures + 1))
else
    echo "  ok   prune removes run logs older than its window and keeps newer ones"
fi
touch "$POOL/ai-tmp/wt-battery-1/ai-tmp/battery.provenance"
bounded sh "$POOL/tools/battery.sh" prune 6 > "$FIXTURE/out" 2>&1
if [ -e "$POOL/ai-tmp/wt-battery-1" ]; then
    echo "  ok   prune keeps a battery touched within the window"
else
    echo "  FAIL prune removed a battery whose log was just written"
    failures=$((failures + 1))
fi

rm -rf "$TREE"
[ "$failures" -eq 0 ] || { echo "battery selftest: $failures case(s) failed"; exit 1; }
echo "battery selftest: every planted drift was refused, no excluded write was,"
echo "  and a leftover git repository did not strand the tree"
