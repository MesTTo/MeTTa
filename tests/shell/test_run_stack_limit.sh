#!/bin/sh
# Purpose: prove the launcher starts swipl under the stack ceiling the seats
#   boot under, read from the generated tools/settings.sh: the Setting's
#   default when the variable the fragment names is unset, the variable's value
#   when it is a positive decimal integer, and no launch at all, in the seats'
#   words, when it is anything else.
# Assumes: a timeout on PATH, which tools/bounded.sh needs. No swipl is needed:
#   a stand-in first on PATH records the arguments run.sh passes and starts
#   nothing.
# Guarantees:
#   - run.sh passes --<MT_STACK_LIMIT_FLAG>=<value>, the value being the
#     fragment's MT_STACK_LIMIT_DEFAULT, or the variable when it is set
#   - an empty value, one that is not decimal digits, and zero each exit
#     nonzero naming the variable, and swipl never starts
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$ROOT/tools/settings.sh"

mkdir -p "$ROOT/ai-tmp"
probe=$(mktemp -d "$ROOT/ai-tmp/run-stack-limit.XXXXXX")
trap 'rm -rf "$probe"' EXIT HUP INT TERM

cat >"$probe/swipl" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$SWIPL_ARGS"
EOF
chmod +x "$probe/swipl"

# Launch through run.sh with env's arguments first: `-u NAME` or `NAME=value`.
launch() {
    rm -f "$probe/args"
    status=0
    env "$@" SWIPL_ARGS="$probe/args" PATH="$probe:$PATH" \
        sh "$ROOT/tools/run.sh" program.metta >"$probe/out" 2>&1 || status=$?
}

fail() {
    echo "run.sh stack limit: $1" >&2
    cat "$probe/out" >&2
    exit 1
}

# swipl is given ceiling $1 when env's arguments are the rest.
boots_under() {
    want=$1
    shift
    launch "$@"
    [ "$status" -eq 0 ] || fail "the launch exited $status"
    grep -Fx -- "--$MT_STACK_LIMIT_FLAG=$want" "$probe/args" >/dev/null ||
        fail "swipl was not given --$MT_STACK_LIMIT_FLAG=$want"
}

refuses() {
    launch "$MT_STACK_LIMIT_ENVIRONMENT=$1"
    [ "$status" -ne 0 ] || fail "'$1' launched"
    [ ! -e "$probe/args" ] || fail "'$1' started swipl"
    grep -F -- "$MT_STACK_LIMIT_ENVIRONMENT must be $2" "$probe/out" >/dev/null ||
        fail "'$1' was not refused as: must be $2"
}

boots_under "$MT_STACK_LIMIT_DEFAULT" -u "$MT_STACK_LIMIT_ENVIRONMENT"
boots_under 3000000000 "$MT_STACK_LIMIT_ENVIRONMENT=3000000000"
refuses 'eight gigabytes' "a positive integer, got 'eight gigabytes'"
refuses '' "a positive integer, got ''"
refuses +3000000000 "a positive integer, got '+3000000000'"
refuses 0 "positive, got 0"
refuses 000 "positive, got 0"

printf 'run.sh stack limit checks passed\n'
