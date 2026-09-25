#!/bin/sh
# Purpose: answer whether SWI-Prolog recompiles a .qlf file whose source is
#   newer by modification time but unchanged in content, the defect
#   swi-qlf-recompiles-unchanged-newer-source.patch beside this file fixes.
#   That patch is upstream swipl-devel b5da8260476b, which V10.1.15 ships:
#   10.1.14's '$qlf_out_of_date'/3 in boot/init.pl calls a .qlf old whenever
#   its .pl is newer, and a load then compiles the source and writes a new
#   .qlf over the old one. A tree that arrives by install, copy or unpack
#   carries whatever times its writer gave it, so a fresh install of the
#   pymetta 0.9.2 wheel by uv rewrote 2, 25 or 51 of the bundled library
#   .qlf files its first boot looked up, each one whose .pl the installer
#   happened to write after it. This compiles two one-clause modules, dates
#   each source a minute after its .qlf, changing the content of one of
#   them, and loads both in a fresh process. Prints `present` when the
#   unchanged one's .qlf was rewritten, and `absent` when it was loaded as
#   it was.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL a native host interpreter
# Guarantees:
#   - `absent` needs the fresh process to answer from both modules and the
#     changed source's .qlf to be rewritten, so a host that has stopped
#     recompiling anything, or cannot run the program, is a broken
#     reproduction rather than an absence
#   - a rewrite is a new inode, new bytes or a time after the load began,
#     which covers SWI staging the new .qlf and renaming it over the old one
#     as well as a write in place
#   - it answers `present` on 10.1.14 without the patch
#     [measured 2026-09-25T15:33:03+10:00: swipl-patched.6, compiled Sep 25
#     2026, 12:27:40, and the stock /usr/bin/swipl, each rewriting same.qlf
#     and recompiling edited.qlf]
#   - it answers `absent` on a host built with the patch
#     [measured 2026-09-25T23:19:27+10:00: the home tools/pymetta-host/run.sh
#     built from fetch-source.sh's 39 patches, compiled Sep 25 2026, 13:16:40
#     in the build container's UTC, loading same.qlf as it was and
#     recompiling edited.qlf]
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
cd "$scratch"

printf ':- module(same, [same/1]).\nsame(1).\n' > same.pl
printf ':- module(edited, [edited/1]).\nedited(1).\n' > edited.pl
"$swipl" -q -f none -g "qcompile(same), qcompile(edited)" -t halt < /dev/null
printf 'edited(2).\n' >> edited.pl
# A minute past each .qlf, which SWI's strict comparison of the two times
# reads as newer on any file system's resolution.
"$swipl" -q -f none -g "forall(member(B, [same, edited]),
        ( file_name_extension(B, pl, P), file_name_extension(B, qlf, Q),
          time_file(Q, T), Later is T + 60,
          set_time_file(P, [], [modified(Later)]),
          time_file(P, After), After > T ))" -t halt < /dev/null

for unit in same edited; do
    ls -i "$unit.qlf" > "$unit.inode"
    cp "$unit.qlf" "$unit.before"
done
touch loading
"$swipl" -q -f none -g "use_module(same), use_module(edited),
        same(A), findall(E, edited(E), Es), print(A-Es), nl" -t halt < /dev/null > answered
[ "$(cat answered)" = '1-[1,2]' ] || {
    printf 'the fresh process answered %s, not 1-[1,2]\n' "$(cat answered)" >&2; exit 1; }

# ls -i is how POSIX reads an inode, and the names are this file's own.
# shellcheck disable=SC2012
untouched() {
    ls -i "$1.qlf" | cmp -s - "$1.inode" &&
        cmp -s "$1.qlf" "$1.before" &&
        [ -z "$(find "$1.qlf" -newer loading)" ]
}
if untouched edited; then
    echo 'edited.qlf was not recompiled although its source changed' >&2
    exit 1
fi
if untouched same; then echo absent; else echo present; fi
