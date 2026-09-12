#!/bin/sh
# Purpose: test a Unicode extra field after native CP437 conversion.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${CHECK_PY:-python3}" "$script_dir/support/zip_charset.py" unicode-crc
