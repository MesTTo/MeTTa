# Purpose: run a single MeTTa file (or the interactive demo with no file)
#   through the engine, with every seat whose declared needs hold.
# Guarantees:
#   - `extensions` names none of them: which seats exist is
#     extensions/*/extension.pl, and whether one is usable is that seat's own
#     declaration. This script used to test for MORK's shared library and
#     LD_PRELOAD it, which meant a second backend needed a second branch here;
#     the backend opens its own library with global visibility, so the preload
#     was never load-bearing.
#   - NO_AUTOLOAD=1 boots with set_prolog_flag(autoload, false) already in
#     effect before engine/main.pl, and so engine/metta.pl, ever loads, via
#     tests/fixtures/no_autoload_boot.pl (a -g goal cannot do this: see that file's
#     header) [measured 2026-08-18: NO_AUTOLOAD=1 sh test.sh, 200/200
#     examples/ pass; unset, the default GATE_ONLY=1 sh check.sh is
#     unaffected, all 35 lanes still green].
#   - `--verbose` preserves SWI informational reports while the default stays
#     quiet [tested: tests/shell/test_run_verbose.sh; commit=694dff934a11dbc2ee99267b60f39564053baf87].
#   - swipl runs under the stack ceiling the seats boot under: $METTA_STACK_LIMIT
#     when set, else the Setting's default, both read from tools/settings.sh,
#     which boundsgen.py generates from the Setting declarations; a value that
#     is not a positive decimal integer stops the launch with the seats' words
#     before swipl starts [tested: tests/shell/test_run_stack_limit.sh;
#     commit=WORKTREE].
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
# The repository root, which is this script's PARENT: the drivers live in
# tools/ so the root stays short enough to read at a glance.
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
QUIET=-q
for argument do
    if [ "$argument" = --verbose ]; then
        QUIET=
    fi
done
if [ "${NO_AUTOLOAD:-}" = "1" ]; then
    BOOT=$SCRIPT_DIR/tests/fixtures/no_autoload_boot.pl
else
    BOOT=$SCRIPT_DIR/engine/main.pl
fi
# Through bounded.sh, because this is the command a person types to run one
# file and it is where a runaway lands: a MeTTa program with a non-terminating
# equation spins at 100% with nothing watching it, and a session killed while
# it runs used to leave it running. The ceiling is bounded.sh's hour unless the
# caller says otherwise; test.sh sets 290 for the corpus.
bounded() { sh "$SCRIPT_DIR/tools/bounded.sh" "$@"; }
# The stack ceiling, and the variable that replaces it, are the Setting the
# seats read. The variable is named by the fragment, so it is read indirectly.
. "$SCRIPT_DIR/tools/settings.sh"
eval "stack_limit=\${$MT_STACK_LIMIT_ENVIRONMENT-$MT_STACK_LIMIT_DEFAULT}"
case $stack_limit in
    '' | *[!0-9]*)
        echo "$MT_STACK_LIMIT_ENVIRONMENT must be a positive integer, got '$stack_limit'" >&2
        exit 2 ;;
    *[1-9]*) ;;
    *)
        echo "$MT_STACK_LIMIT_ENVIRONMENT must be positive, got 0" >&2
        exit 2 ;;
esac
bounded swipl "--$MT_STACK_LIMIT_FLAG=$stack_limit" $QUIET -s "$BOOT" -- "$@" extensions
