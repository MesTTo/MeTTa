#!/bin/sh
# Purpose: write down which patches a SWI-Prolog carries, in the one shape the
#   engine's boot check reads, so a patched host can be told from a stock one
#   by something other than its version string.
#
# Usage:
#   declare-host.sh require [TREE]     print the requirement for the ledger's
#                                      patches to one tree of swipl-devel.
#                                      With no TREE, the patches to
#                                      swipl-devel itself:
#                                      engine/host_patches.pl, the set the
#                                      engine refuses to boot without. With
#                                      packages/swipy, the patches to janus,
#                                      which the Python host requires in its
#                                      own bridge
#   declare-host.sh declare SRC HOME [--built-by COMMAND...]
#                                      write HOME/metta-host.pl: the patches
#                                      of the stack the source tree SRC
#                                      carries, host-only ones included, for
#                                      a host installed from SRC into HOME
#
# Both write host_patch(File, Sha256) facts, one per patch, so the check
# compares two sets of identical terms. The digest is of the patch file, which
# makes a host built from an OLDER version of a patch fail the same way a
# stock host does rather than passing on its name. The check asks only that
# the declaration hold every fact a requirement names, so a host-only patch
# is declared as what the host carries and required by nothing, as the janus
# patches were never in the engine's requirement: a fact of another kind
# would be refused as malformed by every engine written before it [source
# 2026-09-25T13:46:22+10:00: engine/host_check.pl,
# metta_require_host_patches/2 and read_declaration/5].
#
# `declare` also writes host_build(CompiledAt), the compiled_at flag of the
# build installed in HOME, because the C patches live in the binary and the
# declaration lives in the home, and SWI_HOME_DIR can put any binary in front
# of any home: the venv here exports it to every process, and a stock
# /usr/bin/swipl started under it reports the patched home and would read its
# declaration [measured 2026-09-23: the stock /usr/bin/swipl, compiled_at
# 'Aug 30 2026, 09:21:19', reported the venv's patched home as its own, the
# patched build's compiled_at being 'Sep 16 2026, 22:48:43'].
#
# The flag is read by RUNNING the host, and there is one way to do that: run a
# command and take the one line it prints. By default the command is the
# launcher installed at HOME/bin/<arch>/swipl. `--built-by` names another, for
# a host whose home has no launcher: the WebAssembly build packs its home into
# a data image and runs only under a JavaScript loader, so tools/wasm-host
# passes `--built-by node tools/wasm-host/host.mjs compiled-at DIR`, which
# boots the artefacts it is about to ship and prints their flag. The command is
# argv, not a string a shell re-reads.
#
# Why a declaration at all: /usr/bin/swipl and the patched build both report
# "SWI-Prolog version 10.1.14 for x86_64-linux", so the version cannot tell
# them apart, and the reproductions that can are separate processes a boot
# cannot afford [measured 2026-09-23: both --version lines identical].
#
# Assumes: git and sha256sum on PATH; SRC is the swipl-devel tree HOME was
#   installed from, with its patches applied in the working tree the way
#   fetch-source.sh leaves them.
# Guarantees:
#   - `require TREE` lists exactly the patches that sit under TREE in
#     tests/checks/host_workarounds (the top level for no TREE), in byte order,
#     and never a host-only one, so each requirement file is a function of
#     that directory and every ledger patch lands in exactly one of them
#     [tested 2026-09-25T13:56:49+10:00: tests/checks/check_host_declaration_selftest.py]
#   - `require` refuses two patches with one file name, in different trees or
#     in different layers, since the name is the key a declaration and a
#     requirement share
#     [tested 2026-09-25T13:56:49+10:00: tests/checks/check_host_declaration_selftest.py]
#   - `declare` lists a patch exactly when it comes off the stack
#     fetch-source.sh put on the tree patch-root.sh routes it to: every file
#     those patches name is copied, and the patches are reverse-applied to the
#     copy last first, host-only ones before the ledger's, so each is checked
#     against the tree as it stood right after it was applied and a patch
#     another one builds on still reads as carried. A patch the tree lacks is
#     absent from the declaration
#     [tested 2026-09-25T13:56:49+10:00: tests/checks/check_host_declaration_selftest.py]
#   - `declare` records the one line the identity command prints, run with
#     SWI_HOME_DIR unset so the answer is that build's own: HOME/bin/<arch>/swipl
#     reporting its compiled_at, or the command after --built-by. It refuses,
#     writing nothing, when there is no launcher and no --built-by, and when the
#     command exits nonzero, prints nothing, or prints more than one line, since
#     none of those is one build's identity
#     [tested: tests/checks/check_host_declaration_selftest.py; commit=02dc5471b552c74826880441400114c798ea66ca]
#   - the declaration is replaced whole, by rename, so a reader never sees a
#     half-written one
#   - `declare` exits 1 when the tree lacks any patch of the stack, a
#     host-only one included, after writing the declaration, so a build stops
#     where a half-patched host would otherwise reach a wheel and a rebuild
#     cannot drop a host-only fix unseen, and the file still names exactly
#     what the tree carries
#     [tested 2026-09-25T13:56:49+10:00: tests/checks/check_host_declaration_selftest.py]
# Fails when: SRC is not a git tree, or HOME does not exist; both refuse with
#   exit 1 rather than writing a declaration nothing was checked against.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
. "$HERE/patch-root.sh"
patch_layers "$ROOT"
NL='
'

usage() {
    echo "usage: declare-host.sh require [TREE] | declare SRC HOME [--built-by COMMAND...]" >&2
    exit 2
}

fact() {
    printf "host_patch('%s', '%s').\n" "$(basename "$1")" \
        "$(sha256sum "$1" | cut -d' ' -f1)"
}

case "${1:-}" in
    require)
        TREE=${2:-}
        [ -z "$TREE" ] || [ -d "$PATCHES/$TREE" ] || {
            printf 'declare-host: no patches sit under %s\n' "$PATCHES/$TREE" >&2; exit 1; }
        shared=$(every_patch | sed 's|.*/||' | LC_ALL=C sort | uniq -d)
        [ -z "$shared" ] || {
            printf 'declare-host: more than one patch is named %s, and the name is the key\n' \
                "$shared" >&2; exit 1; }
        if [ -z "$TREE" ]; then
            module=metta_host_patches
            what='the host-workaround patches to swipl-devel itself, the set this engine refuses to boot without'
        else
            module=metta_host_patches_$(printf '%s' "$TREE" | tr '/-' '__')
            what="the host-workaround patches to swipl-devel's $TREE, which a host loading it requires"
        fi
        cat <<HEADER
% Purpose: $what,
%   one host_patch(File, Sha256) fact per patch at tests/checks/host_workarounds${TREE:+/$TREE}.
% Generated by \`sh tools/pymetta-host/declare-host.sh require${TREE:+ $TREE}\`; the
%   host-declaration lane regenerates it and fails on any difference, so edit
%   the patches and rerun the command rather than this file.
:- module($module, [host_patch/2]).

HEADER
        # A requirement is the ledger's layer alone: the host-only layer is
        # what a host is built with and nothing requires.
        for patch in $(layer_patches "$PATCHES"); do
            if [ "$(patch_tree "$patch")" = "$TREE" ]; then fact "$patch"; fi
        done
        ;;
    declare)
        [ $# -ge 3 ] || usage
        SRC=$2; HOME_DIR=$3; shift 3
        if [ $# -gt 0 ]; then
            [ "$1" = --built-by ] && [ $# -ge 2 ] || usage
        fi
        git -c safe.directory='*' -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || {
            printf 'declare-host: %s is not a git tree, so nothing says which patches it carries\n' \
                "$SRC" >&2; exit 1; }
        [ -d "$HOME_DIR" ] || {
            printf 'declare-host: %s does not exist; install the host first\n' "$HOME_DIR" >&2
            exit 1; }
        # What remains of argv becomes the identity command.
        if [ $# -gt 0 ]; then
            shift
        else
            LAUNCHER=$(ls "$HOME_DIR"/bin/*/swipl 2>/dev/null | head -1)
            [ -n "$LAUNCHER" ] || {
                printf 'declare-host: no launcher under %s/bin/<arch>/ and no --built-by, so nothing says which build this home belongs to\n' \
                    "$HOME_DIR" >&2; exit 1; }
            set -- "$LAUNCHER" -q -g 'current_prolog_flag(compiled_at, C), write(C)' -t halt
        fi
        BUILT=$(env -u SWI_HOME_DIR "$@" < /dev/null) || {
            printf 'declare-host: `%s` exited nonzero, so nothing says which build this home belongs to\n' \
                "$*" >&2; exit 1; }
        case $BUILT in
            '') printf 'declare-host: `%s` reported no compiled_at\n' "$*" >&2; exit 1 ;;
            *"$NL"*) printf 'declare-host: `%s` printed more than one line, which is not one build identity:\n%s\n' \
                "$*" "$BUILT" >&2; exit 1 ;;
        esac
        OUT="$HOME_DIR/metta-host.pl"
        {
            echo "% The patches this SWI-Prolog was built with, written by"
            echo "% tools/pymetta-host/declare-host.sh from the tree it was installed from."
            echo "% The engine refuses to boot unless the running build is the one named"
            echo "% here and every patch it requires is listed with the same sha256."
            printf "host_build('%s').\n" "$BUILT"
        } > "$OUT.$$"
        # Whether the tree carries a patch is read off its stack the way
        # fetch-source.sh put the stack on, as quilt pops a series: every file
        # a tree's patches name is copied, and the patches come off the copy
        # last first, so each is reverse-applied to the tree as it stood right
        # after it was applied. Asked of each patch alone, `git apply --reverse
        # --check` refuses one whose hunk context a later patch rewrites,
        # though it is applied [measured 2026-09-24T09:58:25+10:00: the
        # swipl-devel tree the host compiled Sep 24 2026, 09:57:51 was built
        # from read 25 of 26, missing
        # swi-concurrent-import-removal-resets-provider, beneath
        # swi-unlinked-definition-uninitialised]. Last first is every_patch
        # read backwards, which sed's `1!G;h;$!d` does where tac(1) is not
        # POSIX [source 2026-09-25T13:45:54+10:00:
        # https://www.pement.org/sed/sed1line.txt version 5.5, sha256 prefix
        # 1938a44bedf566f0, `reverse order of lines (emulates "tac")`,
        # method 1], so the host-only layer comes off before the ledger's
        # whatever the two directories are called.
        mkdir -p "$ROOT/ai-tmp"
        STACK=$(mktemp -d "$ROOT/ai-tmp/declare-host.XXXXXX")
        trap 'rm -rf "$STACK"' EXIT
        off=' '
        for patch in $(every_patch | sed '1!G;h;$!d'); do
            tree=$(patch_tree "$patch")
            copy=$STACK/tree$(printf '%s' "$tree" | tr '/' '_')
            root=$(patch_root "$SRC" "$patch") || continue
            if [ ! -d "$copy" ]; then
                git init --quiet "$copy"
                for named in $(every_patch); do
                    [ "$(patch_tree "$named")" = "$tree" ] || continue
                    for path in $(sed -n 's|^--- a/||p; s|^+++ b/||p' "$named"); do
                        [ -f "$root/$path" ] || continue
                        mkdir -p "$copy/$(dirname "$path")"
                        cp "$root/$path" "$copy/$path"
                    done
                done
            fi
            if git -C "$copy" apply --reverse "$patch" 2>/dev/null; then
                off="$off$(basename "$patch") "
            fi
        done
        carried=0; missing=''
        for patch in $(every_patch); do
            case $off in
                *" $(basename "$patch") "*)
                    fact "$patch" >> "$OUT.$$"
                    carried=$((carried + 1)) ;;
                *) missing="$missing $(basename "$patch" .patch)" ;;
            esac
        done
        mv "$OUT.$$" "$OUT"
        total=$(every_patch | wc -l)
        printf 'declare-host: %s carries %s of %s patch(es)%s\n' "$SRC" "$carried" \
            "$total" "${missing:+; missing:$missing}" >&2
        [ -z "$missing" ]
        ;;
    *)
        usage
        ;;
esac
