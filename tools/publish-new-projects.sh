#!/bin/sh
# Purpose: create the distributions PyPI does not have yet, one attempt each.
#
# Assumes: twine and curl on PATH, credentials in the environment or ~/.pypirc,
#   and built artifacts in $DIST (tools/build.sh, or the publish workflow).
# Guarantees:
#   - reports and writes nothing unless --publish is given
#   - spends at most ONE upload attempt per project, and stops at the first 429
#   - the project list is read from the tree and from PyPI, never from a file
#     somebody has to keep up to date
# Fails when: a project already exists. Then this is the wrong tool and the
#   publish workflow is the right one: it uploads from GitHub with OIDC and
#   needs no project-creation budget at all.
# Decides: the drain wait and the gap between uploads, below.
#
# WHY A TOOL RATHER THAN A COMMAND. PyPI's project-creation limiter counts
# ATTEMPTS, not successes: warehouse sets project.create.user to "20 per hour"
# and project.create.ip to "40 per hour" [source: warehouse/config.py,
# PROJECT_CREATE_USER_RATELIMIT_STRING]. A loop that retries the whole set on
# failure therefore spends its budget on requests that cannot succeed AND
# pushes the window's expiry out, which is how one session spent about 190
# attempts on 2026-09-21 and kept the window permanently shut while only four
# projects had ever been created.
#
# So: wait for the window to drain, then one attempt per project, and STOP at
# the first 429 rather than burning the rest. Fourteen projects is under the
# twenty a clean window allows, so one pass lands everything.
#
# DETECTING THE 429 IS THE PART THAT WAS WRONG. twine prints only the generic
# `429 Too Many Requests`; the specific "Too many new projects created" lives
# in the response's HTML TITLE and reaches the log only under --verbose. A
# detector matching the title classified every rate limit as a real failure,
# so the stop-on-429 rule did nothing and two more attempts went out before
# anyone noticed. Match the status line.
set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST=${DIST:-$HERE/dist}
PYTHON=${CHECK_PY:-python3}
#: 65 minutes: the limiter's hour plus a margin. Only spent with --publish,
#: and only when a previous run reported the window shut.
DRAIN=${DRAIN:-0}
#: A gap between uploads. Nothing requires it; it keeps one burst from looking
#: like a scripted flood to any limiter this does not know about.
GAP=${GAP:-20}

publish=0
[ "${1:-}" = "--publish" ] && publish=1

# Derived, not listed. Every distribution this repository ships is a directory
# under ext/ carrying a pyproject.toml, and the name in that file is the name
# PyPI knows. A hand-kept list goes stale the first time one is added.
projects() {
    for manifest in "$HERE"/ext/*/pyproject.toml; do
        [ -f "$manifest" ] || continue
        sed -n 's/^name *= *"\([^"]*\)".*/\1/p' "$manifest" | head -1
    done
}

# Existence is a GET, which costs nothing against the creation budget, so the
# set of projects still to create is read rather than remembered.
exists() {
    [ "$(curl -s -o /dev/null -w '%{http_code}' "https://pypi.org/pypi/$1/json")" = 200 ]
}

new=""
for name in $(projects); do
    if exists "$name"; then
        printf '  %-24s on PyPI already\n' "$name"
    else
        printf '  %-24s NOT on PyPI\n' "$name"
        new="$new $name"
    fi
done
set -- $new
printf '%s project(s) to create\n' "$#"

if [ "$publish" -eq 0 ]; then
    printf 'reporting only; pass --publish to spend one attempt on each\n'
    exit 0
fi
[ "$#" -eq 0 ] && exit 0

if [ "$DRAIN" -gt 0 ]; then
    printf '%s waiting %ss for the creation window to drain\n' "$(date -Is)" "$DRAIN"
    sleep "$DRAIN"
fi

# pymetta-host first where it is one of the new ones: `pip install
# pymetta[engine]` resolves to it on Linux x86_64, so until it exists that
# install cannot resolve at all.
ordered=""
for name in "$@"; do [ "$name" = pymetta-host ] && ordered="pymetta-host"; done
for name in "$@"; do [ "$name" = pymetta-host ] || ordered="$ordered $name"; done

for name in $ordered; do
    log="$HERE/ai-tmp/upload.$name.log"
    if $PYTHON -m twine upload --non-interactive --disable-progress-bar \
            --skip-existing "$DIST/$(echo "$name" | tr '-' '_')"-* > "$log" 2>&1; then
        printf '%s  ok      %s\n' "$(date -Is)" "$name"
    elif grep -qE '429|Too Many Requests|Too many new projects' "$log"; then
        printf '%s  429     %s: the window is shut. Stopping, because every further\n' "$(date -Is)" "$name"
        printf '           attempt fails AND pushes the expiry out. Re-run with DRAIN=3900.\n'
        exit 2
    else
        printf '%s  FAILED  %s, not a rate limit; see %s\n' "$(date -Is)" "$name" "$log"
        exit 1
    fi
    sleep "$GAP"
done
