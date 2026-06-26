#!/usr/bin/env bash
#
# Ship the environment to the C++ action
#
set -eu

# Set-up the environment
%{env}

# Call the C++ compiler

%{cc} -E -x c++ -fmodules-ts -fdeps-file="$DEPS_SCANNER_OUTPUT_FILE".tmp -fdeps-format=p1689r5 "$@"

mv "$DEPS_SCANNER_OUTPUT_FILE".tmp "$DEPS_SCANNER_OUTPUT_FILE"
