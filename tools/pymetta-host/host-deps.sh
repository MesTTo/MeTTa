#!/bin/bash
# The host packages the bundle is built against, named once.
#
# Both stages need them and for different reasons, which is why an earlier
# version had the list in build-swipl.sh only and auditwheel then failed with
# `Cannot repair wheel, because required library "libcrypto.so.3" could not be
# located`: the assemble stage must have the RUNTIME halves present in order to
# copy them into pymetta_host.libs. A wheel cannot vendor a library the
# container does not have.
#
# epel-release first and on its own: openssl3 lives there, and dnf cannot
# resolve a package from a repository the same transaction is installing.
install_host_packages() {
    dnf -y install epel-release > /dev/null
    dnf -y install patchelf \
        gmp-devel ncurses-devel readline-devel openssl3-devel libffi-devel \
        zlib-devel libarchive-devel libyaml-devel pcre2-devel libuuid-devel \
        unixODBC-devel libjpeg-turbo-devel libXpm-devel ninja-build > /dev/null
}
