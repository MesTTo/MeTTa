# Purpose: the container every CI job runs in: Debian with the PATCHED
#   SWI-Prolog this engine runs on, plus the toolchain the gate needs.
#
# The engine refuses to boot on a host that does not declare every patch in
# tests/checks/host_workarounds at its current digest (engine/host_check.pl),
# and this image used to be FROM swipl:latest, a stock build, so every CI lane
# ran on the defects the patches fix. The host is now built the way the
# release builds the one it ships: tools/pymetta-host/fetch-source.sh clones
# swipl-devel at the pin and applies every patch, and declare-host.sh records
# them in the home. It installs to /usr, so `swipl` on PATH is the patched one
# exactly as it was the stock one.
#
# The build dependencies and the package set follow SWI-Prolog's own image
# for this version, so the libraries a lane loads are the ones swipl:latest
# had [source: https://github.com/SWI-Prolog/docker-swipl/blob/1b525b159d2723339328e9c83f5209547fcbe0a4/10.1.14/trixie/Dockerfile].
# Release rather than that image's PGO, because the pins this gate compares
# against were measured on a Release build of the same source.
#
# The image's inputs are this file, tools/pymetta-host/ and
# tests/checks/host_workarounds/, and ci.yml and ci-image.yml rebuild it when
# any of them changes. One that does not rebuild it leaves CI on an older host,
# which the engine then refuses by name as built from an older version of the
# patch, so that drift fails rather than passing quietly.
#
# /opt/swipl-src stays in the image: its packages/swipy is the PATCHED janus
# source, and CI builds its bridge from there, since janus's C half is not in
# libswipl and a PyPI build would lack janus-callback-exception-leak.
#
# linux-perf is the parity lane's counter. The base is Debian trixie, where
# that package is what provides /usr/bin/perf; without it check.sh's
# parity-perf lane cannot measure anything and refuses. The lane also needs
# the container's seccomp profile off, which checks.yml sets on the gate job,
# because Docker's default profile denies perf_event_open [measured
# 2026-09-06: this image's base plus linux-perf answers `No permission to
# enable instructions:u event` under the default profile and
# `130379,,instructions:u,249770,100.00,,` with it off].
#
# valgrind is the C seat's second counter: extensions/cmetta/benchmarks/bench.py
# prices each row's window under Cachegrind, and Debian's valgrind package also
# carries the <valgrind/cachegrind.h> its benchmark driver marks that window
# with. Without it the c-bench lane stamps its simulator `absent` and refuses.
FROM debian:trixie-slim
ENV LANG=C.UTF-8
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git make cmake ninja-build gcc g++ pkg-config m4 \
      libtool automake autoconf libutf8proc-dev libarchive-dev libgmp-dev \
      libossp-uuid-dev libpcre2-dev libreadline-dev libedit-dev libssl-dev \
      zlib1g-dev libdb-dev unixodbc-dev libsqlite3-dev libserd-dev \
      libraptor2-dev libyaml-dev libgoogle-perftools-dev libpython3-dev \
      python3 python3-dev python3-venv build-essential linux-perf valgrind \
 && rm -rf /var/lib/apt/lists/*
COPY tools/pymetta-host /opt/metta-host/tools/pymetta-host
COPY tests/checks/host_workarounds /opt/metta-host/tests/checks/host_workarounds
RUN DEST=/opt/swipl-src sh /opt/metta-host/tools/pymetta-host/fetch-source.sh \
 && cmake -S /opt/swipl-src -B /opt/swipl-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
      -DSWIPL_PACKAGES_GUI=OFF -DSWIPL_PACKAGES_JAVA=OFF -DSWIPL_PACKAGES_X=OFF \
      -DINSTALL_DOCUMENTATION=OFF \
 && cmake --build /opt/swipl-build \
 && cmake --install /opt/swipl-build \
 && sh /opt/metta-host/tools/pymetta-host/declare-host.sh declare /opt/swipl-src /usr/lib/swipl \
 && rm -rf /opt/swipl-build
