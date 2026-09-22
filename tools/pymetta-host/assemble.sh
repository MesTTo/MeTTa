#!/bin/bash
# Assemble pymetta-host: the canonical SWI home plus the bridge built against
# it, as one wheel per interpreter, repaired so it carries its own libraries.
#
# auditwheel repair is the step whose absence made every earlier build a lie.
# It copies each external NEEDED into pymetta_host.libs under a content-hashed
# name, rewrites the references, and retags the wheel manylinux. Both halves
# matter: without it the wheel borrows eleven libraries from whatever box it
# lands on, and PyPI refuses a linux_x86_64 tag outright.
#
# Nothing but package content lives under /pkg, so the cleanup below cannot
# reach the build tooling. An earlier layout kept these scripts at
# <package>/build/ and `rm -rf "$PKG/build"`, meant for setuptools' output
# directory, deleted them through the bind mount.
set -euxo pipefail
# The same host packages the SWI build used. auditwheel VENDORS these runtime
# libraries into the wheel, so it can only find them if they are installed
# here too; with only patchelf present it failed on libcrypto.so.3.
source /repo/tools/pymetta-host/host-deps.sh
install_host_packages
/opt/python/cp312-cp312/bin/pip install -q auditwheel

# STAGED, never in place. The package root under /pkg is a bind mount of the
# repository, and a build that populates it leaves 2,404 files of SWI's own
# tree behind whenever it fails: 21 of them are Python, so mypy, ruff, vulture,
# codespell and pytest collection all walk into swiplserver and SWI's protobuf
# examples, and one run reported 72 errors none of which were about this
# project. Copying the sources out first makes that unrepresentable rather
# than cleaned up afterwards, which is the same source-tree/build-tree
# separation the scripts themselves needed.
PKG=/out/stage
rm -rf "$PKG" /out/dist /out/unrepaired && mkdir -p "$PKG" /out/dist /out/unrepaired
cp -a /pkg/pyproject.toml /pkg/setup.py /pkg/README.md /pkg/pymetta_host "$PKG/"
cp -a /out/swipl "$PKG/pymetta_host/swipl"

for TAG in $TAGS; do
    PY=/opt/python/$TAG-$TAG
    rm -rf "$PKG/pymetta_host/_vendor" "$PKG/build" "$PKG"/*.egg-info
    mkdir -p "$PKG/pymetta_host/_vendor"
    "$PY/bin/python" -m zipfile -e "/out/janus/janus_swi-1.5.3-$TAG-$TAG-linux_x86_64.whl" \
        "$PKG/pymetta_host/_vendor"
    rm -rf "$PKG/pymetta_host/_vendor"/janus_swi-*.dist-info
    # The bridge is three directories from the library tree where the home's
    # own foreign objects are one; both answers come from the same computation.
    "$PY/bin/python" /repo/tools/pymetta-host/relocate.py "$PKG/pymetta_host"
    # Isolated, so the build requirements come from this package's own
    # `[build-system] requires` rather than from a second list here. An
    # earlier version passed --no-isolation and needed setuptools preinstalled
    # in each interpreter, which is the same fact written twice and which
    # failed with BackendUnavailable when only one copy was updated.
    "$PY/bin/pip" install -q build
    ( cd "$PKG" && "$PY/bin/python" -m build --wheel --outdir /out/unrepaired )
done

for WHEEL in /out/unrepaired/*.whl; do
    "/opt/python/cp312-cp312/bin/auditwheel" repair \
        --plat manylinux_2_28_x86_64 -w /out/dist "$WHEEL"
done

# The bytes that ship, checked as they ship. A wheel that installs and imports
# proves nothing about a launcher or an unvendored dependency: the previous
# build answered 6*7=42 while bin/swipl could not start and libswipl borrowed
# libgmp from the host.
for WHEEL in /out/dist/*.whl; do
    /opt/python/cp312-cp312/bin/python /repo/tests/checks/check_host_bundle.py "$WHEEL"
done
ls -la /out/dist
