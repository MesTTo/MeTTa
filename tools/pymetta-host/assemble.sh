#!/bin/bash
# Assemble pymetta's Linux wheels: the pure pymetta wheel with the canonical
# SWI home and the bridge built against it grafted in as metta/_host, one
# wheel per interpreter, repaired so it carries its own libraries.
#
# A GRAFT, not a second build of pymetta. The pure wheel is what
# tools/build-distributions.sh produces from the root setup.py, runtime tree
# and all; building pymetta again in here would be a second description of
# that build, and the two would drift. So this unpacks that wheel, adds the
# host beside the code that activates it (metta/_host/__init__.py), retags it
# for one interpreter, and packs it again: every byte that is not the host is
# the pure wheel's own.
#
# auditwheel repair is the step whose absence made every earlier build a lie.
# It copies each external NEEDED into pymetta.libs under a content-hashed
# name, rewrites the references, and retags the wheel manylinux. Both halves
# matter: without it the wheel borrows eleven libraries from whatever box it
# lands on, and PyPI refuses a linux_x86_64 tag outright.
#
# Assumes: /out/swipl is the home build-swipl.sh staged and declared, /out/janus
#   holds one bridge wheel per TAG from build-janus.sh, and /dist holds exactly
#   one pymetta-*-py3-none-any.whl.
# Guarantees:
#   - each wheel in /out/dist is the pure wheel plus metta/_host/swipl,
#     metta/_host/_vendor and pymetta.libs, tagged for its interpreter and
#     manylinux_2_28_x86_64, and passes tests/checks/check_host_bundle.py
#     [tested: tests/checks/check_host_bundle.py, run on every wheel by the last
#     loop below; commit=WORKTREE]
set -euxo pipefail
# The same host packages the SWI build used. auditwheel VENDORS these runtime
# libraries into the wheel, so it can only find them if they are installed
# here too; with only patchelf present it failed on libcrypto.so.3.
source /repo/tools/pymetta-host/host-deps.sh
install_host_packages
# One interpreter carries the tools: unpacking, packing and repairing a wheel
# do not depend on which interpreter the wheel is for.
TOOLS=/opt/python/cp312-cp312/bin
"$TOOLS/pip" install -q auditwheel wheel

shopt -s nullglob
pure=(/dist/pymetta-*-py3-none-any.whl)
[ "${#pure[@]}" -eq 1 ] || { echo "want exactly one pure pymetta wheel in /dist, found ${#pure[@]}"; exit 1; }

# STAGED under /out, never in the repository: an interrupted graft there would
# leave SWI's own Python files for every linter and collector to walk into,
# which one earlier layout did, at 2,404 files.
rm -rf /out/graft /out/dist /out/unrepaired && mkdir -p /out/graft /out/dist /out/unrepaired
for TAG in $TAGS; do
    PY=/opt/python/$TAG-$TAG
    ROOT=/out/graft/$TAG
    "$TOOLS/python" -m wheel unpack --dest "$ROOT" "${pure[0]}"
    TREE=$(echo "$ROOT"/pymetta-*)
    HOST=$TREE/metta/_host
    [ -f "$HOST/__init__.py" ] || { echo "the pure wheel has no metta/_host/__init__.py to graft beside"; exit 1; }
    cp -a /out/swipl "$HOST/swipl"
    mkdir -p "$HOST/_vendor"
    "$PY/bin/python" -m zipfile -e "/out/janus/janus_swi-1.5.3-$TAG-$TAG-linux_x86_64.whl" "$HOST/_vendor"
    rm -rf "$HOST/_vendor"/janus_swi-*.dist-info
    # The bridge is three directories from the library tree where the home's
    # own foreign objects are one; both answers come from the same computation.
    "$PY/bin/python" /repo/tools/pymetta-host/relocate.py "$HOST"
    # The WHEEL file says what the wheel is: impure, and for this interpreter.
    # `wheel pack` names the file from these tags and rewrites RECORD.
    WHEEL_FILE=$(echo "$TREE"/pymetta-*.dist-info/WHEEL)
    sed -i -e 's/^Root-Is-Purelib: true$/Root-Is-Purelib: false/' \
           -e "s/^Tag: py3-none-any\$/Tag: $TAG-$TAG-linux_x86_64/" "$WHEEL_FILE"
    grep -qx "Tag: $TAG-$TAG-linux_x86_64" "$WHEEL_FILE" || { echo "retagging $WHEEL_FILE failed"; exit 1; }
    "$TOOLS/python" -m wheel pack --dest-dir /out/unrepaired "$TREE"
done

for WHEEL in /out/unrepaired/*.whl; do
    "$TOOLS/auditwheel" repair \
        --plat manylinux_2_28_x86_64 -w /out/dist "$WHEEL"
done

# The bytes that ship, checked as they ship. A wheel that installs and imports
# proves nothing about a launcher or an unvendored dependency: an earlier
# build answered 6*7=42 while bin/swipl could not start and libswipl borrowed
# libgmp from the host.
for WHEEL in /out/dist/*.whl; do
    "$TOOLS/python" /repo/tests/checks/check_host_bundle.py "$WHEEL"
done
ls -la /out/dist
