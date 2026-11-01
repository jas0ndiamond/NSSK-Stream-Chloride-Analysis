#!/usr/bin/env bash
# tests/docker-packages-setup-test.sh — drives a disposable Docker container to test
# util/packages_install.R (NSSK.R's package list, driven through packages_setup.R's
# generic check_installed_packages()) against a genuinely clean R environment: base R +
# the system build libraries it needs, but none of NSSK.R's CRAN packages.
#
# Workflow (run twice in the same container to check idempotency, with timing):
#   tests/docker-packages-setup-test.sh start     # once: create container, install r-base + system libs,
#                                                  # and time bare R interpreter startup (no packages)
#   tests/docker-packages-setup-test.sh run       # 1st call: real installs, timed — "not found, installing..."
#   tests/docker-packages-setup-test.sh run       # 2nd call: no-op, timed — "already installed, proceeding"
#   tests/docker-packages-setup-test.sh teardown  # remove the container
#
# Requires a working `docker` daemon (`docker info` should succeed before running this).

set -euo pipefail

CONTAINER_NAME="${NSSK_DOCKER_TEST_CONTAINER:-nssk-packages-setup-test}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# System libraries packages_setup.R's CRAN installs need to compile from source on Debian/Ubuntu
# (see doc/SETUP.md's "Unix / Linux" section — this list matches it).
SYSTEM_LIBS="r-base r-base-dev build-essential gfortran pkg-config \
  libcurl4-openssl-dev libssl-dev libxml2-dev libpng-dev libjpeg-dev \
  libtiff5-dev libfreetype6-dev libfontconfig1-dev libharfbuzz-dev \
  libfribidi-dev zlib1g-dev libicu-dev libbz2-dev liblzma-dev libpcre2-dev \
  libuv1-dev libv8-dev fonts-texgyre fonts-urw-base35 fonts-liberation"

usage() {
  echo "Usage: $0 {start|run|teardown}" >&2
  echo "  start     create the container, install base R + system build libraries, and" >&2
  echo "            time bare R interpreter startup (no packages loaded); once" >&2
  echo "  run       run util/packages_install.R inside the existing container, timed; repeatable" >&2
  echo "  teardown  remove the container" >&2
  exit 1
}

# Timed with bash's own `time` builtin *inside* the container, so the reported wall-clock
# time is the R process's own runtime, not inflated by `docker exec`'s connection overhead.
cmd_start() {
  if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container '$CONTAINER_NAME' already exists — run '$0 teardown' first, or '$0 run' to reuse it." >&2
    exit 1
  fi
  # Repo mounted read-only: util/packages_install.R only needs to read it, never write back to it.
  docker run -d --name "$CONTAINER_NAME" -v "$REPO_DIR:/repo:ro" debian:12-slim sleep infinity
  docker exec "$CONTAINER_NAME" bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq $SYSTEM_LIBS
  "
  echo "Container '$CONTAINER_NAME' ready: base R + system build libraries only, no CRAN packages installed."

  echo "R interpreter startup time (bare, no packages loaded), 3 runs:"
  docker exec "$CONTAINER_NAME" bash -c '
    for i in 1 2 3; do
      { TIMEFORMAT="  run $i: %R s"; time Rscript -e "invisible(1)" >/dev/null; } 2>&1
    done
  '
}

cmd_run() {
  docker exec "$CONTAINER_NAME" bash -c '
    cd /repo
    { TIMEFORMAT="util/packages_install.R run time: %R s"; time Rscript util/packages_install.R; } 2>&1
  '
}

cmd_teardown() {
  if docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container '$CONTAINER_NAME' removed."
  else
    echo "No container named '$CONTAINER_NAME' to remove."
  fi
}

case "${1:-}" in
  start) cmd_start ;;
  run) cmd_run ;;
  teardown) cmd_teardown ;;
  *) usage ;;
esac
