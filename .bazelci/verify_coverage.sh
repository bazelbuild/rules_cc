#!/usr/bin/env bash
#
# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Asserts that a preceding `bazel coverage` invocation actually collected line
# coverage.
#
# `bazel coverage` exits successfully even when every report it produces is
# empty, so a broken coverage collector looks exactly like a green build. Worse,
# a partially broken collector can emit well-formed LCOV that names source files
# but attributes no executed lines to them. This script therefore works per
# `SF:` block, pairing each source file with the `DA:` records inside its own
# block, and only counts a file as covered when at least one of those records
# has a non-zero hit count.
#
# Not every test yields coverage: `--instrumentation_filter` defaults to the
# package under test, so a test that only exercises sources in other packages
# legitimately produces an empty report. Files that are linked in but never
# entered legitimately report zero hits too. The check is consequently a floor
# plus an explicit list of source files that must be covered, rather than a
# per-test or per-file assertion.
#
# Usage:
#   verify_coverage.sh [--expect=SOURCE_PATH]...
#
#   --expect=PATH     Require a covered source file whose `SF:` path contains
#                     PATH. May be repeated. Implies requiring at least one
#                     covered file overall, which is also the default.
#
# Whenever an expected file is missing, the script prints the tail of the
# test logs in that file's package: the collector's own output only survives
# there, and with `--test_env=VERBOSE_COVERAGE=1` it includes the collector's
# view of its environment and the coverage directory.

set -euo pipefail

expected=()

for arg in "$@"; do
  case "${arg}" in
    --expect=*) expected+=("${arg#--expect=}") ;;
    *)
      echo "ERROR: unrecognized argument '${arg}'" >&2
      exit 1
      ;;
  esac
done

# Bazel merges every test's report into a single LCOV file per invocation
# (`--combined_report=lcov`, requested explicitly in presubmit.yml). Reading
# that one file rather than walking bazel-testlogs means only tests from this
# invocation count: a report left behind by an earlier build in a reused
# output base can never satisfy the check.
report="bazel-out/_coverage/_coverage_report.dat"
if [[ ! -f "${report}" ]]; then
  report="$(bazel info output_path 2>/dev/null || true)/_coverage/_coverage_report.dat"
fi
if [[ ! -f "${report}" ]]; then
  echo "ERROR: no combined coverage report at bazel-out/_coverage/; was" >&2
  echo "       'bazel coverage --combined_report=lcov' run?" >&2
  exit 1
fi

# Only needed to show test logs when something is missing.
testlogs="bazel-testlogs"
if [[ ! -d "${testlogs}" ]]; then
  testlogs="$(bazel info bazel-testlogs 2>/dev/null || true)"
fi

covered="$(mktemp)"
covered_paths="$(mktemp)"
trap 'rm -f "${covered}" "${covered_paths}"' EXIT

# Emit "<executed lines>\t<source path>" for each source that ended up with a
# non-zero hit count. Accumulating per SF: block is what distinguishes "this
# file has coverage data" from "this file was merely listed in the report".
awk '
  /^SF:/ { sf = substr($0, 4); listed[sf] = 1; next }
  /^DA:/ {
    split(substr($0, 4), record, ",")
    if (sf != "" && record[2] + 0 > 0) { hits[sf]++ }
    next
  }
  /^end_of_record/ { sf = ""; next }
  END { for (s in hits) { print hits[s] "\t" s } }
' "${report}" | sort -k2 >"${covered}"
cut -f2 "${covered}" >"${covered_paths}"

listed_files="$(grep -c '^SF:' "${report}" || true)"
covered_files="$(wc -l <"${covered}" | tr -d '[:space:]')"
covered_lines="$(awk -F'\t' '{ total += $1 } END { print total + 0 }' "${covered}")"

echo "Combined report:             ${report}"
echo "Source files listed:         ${listed_files}"
echo "Source files with hit lines: ${covered_files}"
echo "Executed lines recorded:     ${covered_lines}"
awk -F'\t' '{ printf "  %6d hit lines  %s\n", $1, $2 }' "${covered}"

status=0

if [[ "${covered_files}" -eq 0 ]]; then
  echo >&2
  echo "ERROR: no source file came back with executed lines. Coverage" >&2
  echo "       collection is broken -- see //cc/coverage." >&2
  status=1
fi

for want in ${expected[@]+"${expected[@]}"}; do
  if grep -Fq -- "${want}" "${covered_paths}"; then
    continue
  fi
  echo >&2
  echo "ERROR: no executed lines recorded for a source file matching" >&2
  echo "       '${want}'. Either coverage collection regressed, or the test" >&2
  echo "       that exercises it no longer runs on this platform. The" >&2
  echo "       expected paths are listed in .bazelci/presubmit.yml." >&2
  status=1
  while IFS= read -r log; do
    echo "--- last 60 lines of ${log#"${testlogs}"/} ---" >&2
    tail -n 60 "${log}" >&2
  done < <(find -L "${testlogs}/$(dirname "${want}")" -name test.log -type f 2>/dev/null | head -n 2)
done

exit "${status}"
