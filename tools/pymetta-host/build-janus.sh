#!/bin/bash
# Build the janus bridge against the staged SWI, one wheel per interpreter.
#
# The module stays `janus_swi`: janus names that package in both its Python and
# its Prolog halves and the extension exports PyInit__swipl, so a rename is a
# rebuild of the extension rather than a move of package data. It is vendored
# under pymetta_host/_vendor so no second distribution can own the name.
set -euxo pipefail
dnf -y install patchelf > /dev/null

# The home arrives canonical and relocatable from build-swipl.sh, so libswipl
# already carries the soname it ships under and the bridge links that name
# directly. Nothing is patched here.
export SWI_HOME_DIR=/out/swipl/lib/swipl
/out/swipl/lib/swipl/bin/x86_64-linux/swipl --version

# setuptools-scm reads git metadata, and root inside the container does not own
# the mounted checkout, so git refuses it. The error names its own fix.
git config --global --add safe.directory /src
git config --global --add safe.directory /src/packages/swipy
cd /src/packages/swipy
rm -rf build dist janus_swi.egg-info
for TAG in $TAGS; do
    PY=/opt/python/$TAG-$TAG
    rm -rf build janus_swi.egg-info
    SWIPL=/out/swipl/lib/swipl/bin/x86_64-linux/swipl \
      "$PY/bin/python" -m pip wheel --no-deps --wheel-dir /out/janus .
done
ls -la /out/janus
