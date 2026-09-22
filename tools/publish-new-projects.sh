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
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# The same interpreter every other lane runs under, taken from $PY, which is
# what select-python.sh is documented to set and leaves EMPTY when it finds
# nothing. A bare `python3` fallback here was /usr/bin/python3, which carries
# no twine, and the run died before reaching the network -- harmless only
# because nothing had been spent yet. A fallback is the wrong shape for this
# script anyway: the cost of guessing wrong is an attempt against an hourly
# budget, so both checks below refuse rather than continue.
. "$HERE/tools/select-python.sh" > /dev/null 2>&1
set -u
DIST=${DIST:-$HERE/dist}
PYTHON=${PY:-}
if [ -z "$PYTHON" ]; then
    printf 'publish-new-projects: tools/select-python.sh found no interpreter; set CHECK_PY\n' >&2
    exit 1
fi
if ! "$PYTHON" -c 'import twine' 2>/dev/null; then
    printf 'publish-new-projects: %s cannot import twine; install it there with\n' "$PYTHON" >&2
    printf '  %s -m pip install twine\n' "$PYTHON" >&2
    exit 1
fi
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
