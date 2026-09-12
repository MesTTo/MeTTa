#!/bin/sh
# Purpose: compare libarchive's default ZIP decoder with explicit CP437.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${CHECK_PY:-python3}" "$script_dir/support/zip_charset.py"
