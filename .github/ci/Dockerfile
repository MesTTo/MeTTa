FROM swipl:latest

# Install system build tools for your Python/native deps.
#
# linux-perf is the parity lane's counter. The base is Debian trixie, where
# that package is what provides /usr/bin/perf; without it check.sh's
# parity-perf lane cannot measure anything and refuses. The lane also needs
# the container's seccomp profile off, which checks.yml sets on the gate job,
# because Docker's default profile denies perf_event_open [measured
# 2026-09-06: this image's base plus linux-perf answers `No permission to
# enable instructions:u event` under the default profile and
# `130379,,instructions:u,249770,100.00,,` with it off].
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential python3-dev git linux-perf \
 && rm -rf /var/lib/apt/lists/*
