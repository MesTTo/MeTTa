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
#   - a verdict's cited upload log is never overwritten by a later run
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
# One log per RUN, not one per project. A verdict reads "see <log>", and a
# name reused across runs means the next attempt overwrites the evidence the
# last verdict pointed at: the 2026-09-22 14:29 failure cannot be read now
# because a 17:40 attempt rewrote its log, and the two failed for different
# reasons. The PID rather than the clock alone, because two runs inside one
# second would otherwise share a stamp; uniqueness by shape, not by luck.
RUN=${RUN:-$(date -u +%Y%m%dT%H%M%SZ).$$}
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
#: The index whose JSON API answers the existence question, and the ONLY thing
#: it changes. twine uploads to its own configured repository, so pointing
#: this elsewhere would classify against one index and publish to another,
#: which is why --publish refuses whenever it is not the default. It exists to
#: exercise the refusal below against a host that cannot answer.
INDEX=${INDEX:-https://pypi.org}
DEFAULT_INDEX=https://pypi.org

publish=0
[ "${1:-}" = "--publish" ] && publish=1
if [ "$publish" -eq 1 ] && [ "$INDEX" != "$DEFAULT_INDEX" ]; then
    printf 'publish-new-projects: INDEX is %s but twine uploads to its own configured\n' "$INDEX" >&2
    printf 'repository, so this run would decide what is missing from one index and\n' >&2
    printf 'create it on another. INDEX is for checking; drop --publish.\n' >&2
    exit 1
fi

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
#
# Only 404 means absent. Treating everything-but-200 as absent is fail-open in
# the one direction that costs something: a 429, a 502 or a DNS failure would
# read as "this project does not exist" and send a creation attempt against a
# budget that takes an hour to refill. Every other status is UNKNOWN and stops
# the run.
status_of() {
    curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$INDEX/pypi/$1/json"
}

new=""
for name in $(projects); do
    # Asked ONCE and decided from that answer, so the status the refusal names
    # is the status that refused rather than a second call's.
    code=$(status_of "$name")
    case "$code" in
        200) printf '  %-24s on PyPI already\n' "$name" ;;
        404) printf '  %-24s NOT on PyPI\n' "$name"; new="$new $name" ;;
        *)   printf '%s answered %s for %s, which says neither present nor absent.\n' \
                 "$INDEX" "$code" "$name" >&2
             printf 'Stopping rather than risk a creation attempt on a project that may\n' >&2
             printf 'already exist, against a budget that takes an hour to refill.\n' >&2
             exit 1 ;;
    esac
done
set -- $new
printf '%s project(s) to create\n' "$#"
printf 'run %s; an upload log of this run is ai-tmp/upload.%s.<project>.log\n' "$RUN" "$RUN"

# Checked while REPORTING too, so the rule can be verified without spending
# anything. It sat after the reporting exit, and proving it worked therefore
# took a --publish run that spent an attempt on a shut window.
#
# A project's release is its whole set, not any one file. metta-arrays went
# out on 2026-09-21 as a wheel with NO sdist, which nothing noticed until an
# upload to it on 2026-09-22 printed "Skipping ... already exist" for the
# wheel and then uploaded the tar.gz: a release nobody can build from source,
# and unfixable in place because PyPI does not accept a replacement file.
#
# What the set should be is DERIVED from the wheels rather than listed. A
# wheel tagged py3-none-any is pure Python, and a pure distribution owes an
# sdist; one carrying a platform tag is a binary build, for which an sdist is
# optional and the wheels are per-interpreter. So the rule reads the artifacts
# and needs no per-project table to go stale.
missing=""
for name in "$@"; do
    stem=$(echo "$name" | tr '-' '_')
    wheels=$(find "$DIST" -maxdepth 1 -name "$stem-*.whl" 2>/dev/null | wc -l)
    sdists=$(find "$DIST" -maxdepth 1 -name "$stem-*.tar.gz" 2>/dev/null | wc -l)
    pure=$(find "$DIST" -maxdepth 1 -name "$stem-*-py3-none-any.whl" 2>/dev/null | wc -l)
    # Total over (wheels, sdists, all-pure). The sdist-with-no-wheel row was
    # the one nobody wrote: it matched neither refusal and passed, which is
    # what a missing rule looks like from the outside. Every distribution here
    # is built wheel-and-sdist by the same workflow, so no wheel is a gap
    # whatever the sdist says.
    if [ "$wheels" -eq 0 ] && [ "$sdists" -eq 0 ]; then
        missing="$missing $name(nothing)"
    elif [ "$wheels" -eq 0 ]; then
        missing="$missing $name(sdist, no wheel)"
    elif [ "$wheels" -eq "$pure" ] && [ "$sdists" -eq 0 ]; then
        missing="$missing $name(pure wheel, no sdist)"
    fi
done
if [ -n "$missing" ]; then
    printf 'publish-new-projects: %s does not hold a complete release for:%s\n' "$DIST" "$missing" >&2
    printf 'Build them first. A run that starts without them spends one creation\n' >&2
    printf 'attempt per project before reaching the first gap, and a project created\n' >&2
    printf 'from an incomplete set cannot be repaired: PyPI refuses a replacement file.\n' >&2
    exit 1
fi

# A version this repository does not publish, stated here because nothing
# else on this path reads one. The release policy lived only in the head of
# whoever ran the tool, and an upload cannot be taken back: PyPI never frees a
# version once used, so a mistake here is permanent and a refusal afterwards
# is worthless. Read off the ARTIFACT rather than a manifest, because the
# filename is what gets uploaded and a manifest can disagree with what was
# built.
REFUSED_VERSION=1.0.0
refused=""
for name in "$@"; do
    stem=$(echo "$name" | tr '-' '_')
    for artifact in "$DIST/$stem"-*; do
        [ -e "$artifact" ] || continue
        base=$(basename "$artifact")
        case "$base" in
            "$stem-$REFUSED_VERSION"-*|"$stem-$REFUSED_VERSION".*)
                refused="$refused $base" ;;
        esac
    done
done
if [ -n "$refused" ]; then
    printf 'publish-new-projects: %s is not a version this repository publishes,\n' "$REFUSED_VERSION" >&2
    printf 'and these artifacts carry it:%s\n' "$refused" >&2
    printf 'Set the version and rebuild. This refuses BEFORE any attempt because an\n' >&2
    printf 'upload cannot be undone: PyPI never frees a version once it is taken.\n' >&2
    exit 1
fi

if [ "$publish" -eq 0 ]; then
    printf 'reporting only; pass --publish to spend one attempt on each\n'
    exit 0
fi
[ "$#" -eq 0 ] && exit 0

# Every artifact is located before the first upload. Without this the run
# spends an attempt per project until it reaches the one nobody built, so a
# missing wheel costs a creation budget rather than a message: twine fails
# locally on a path that is not there, which is safe but only after the
# projects before it are gone from the budget.
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
    log="$HERE/ai-tmp/upload.$RUN.$name.log"
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
    # Between uploads, not after the last one.
    [ "$name" = "${ordered##* }" ] || sleep "$GAP"
done
