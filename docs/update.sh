#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "Must be run via 'bazel run'" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  src=$1
  dst=$2
  shift 2
  cp -f "$src" "$BUILD_WORKSPACE_DIRECTORY/$dst"
  chmod 0644 "$BUILD_WORKSPACE_DIRECTORY/$dst"
done
