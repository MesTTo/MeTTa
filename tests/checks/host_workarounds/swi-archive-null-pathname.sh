#!/bin/sh
# Purpose: isolate the native null-pathname crash and suppress core dumps.
set -eu
ulimit -c 0
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${SWIPL:-swipl}" -q -f none -s "$script_dir/support/archive_null_pathname.pl" -g main -t halt
