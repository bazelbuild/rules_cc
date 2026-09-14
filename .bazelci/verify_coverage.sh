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
#   verify_coverage.sh [--report-only] [--expect=SOURCE_PATH]...
#
#   --expect=PATH     Require a covered source file whose `SF:` path contains
#                     PATH. May be repeated. Implies requiring at least one
#                     covered file overall, which is also the default.
#   --report-only     Print the tally and exit 0 without asserting anything.
#                     Any --expect is ignored. Used on platforms where coverage
#                     collection is known to be unreliable.

set -euo pipefail

report_only=false
expected=()

for arg in "$@"; do
  case "${arg}" in
    --report-only) report_only=true ;;
    --expect=*) expected+=("${arg#--expect=}") ;;
    *)
      echo "ERROR: unrecognized argument '${arg}'" >&2
      exit 1
      ;;
  esac
done

testlogs="bazel-testlogs"
if [[ ! -d "${testlogs}" ]]; then
  testlogs="$(bazel info bazel-testlogs 2>/dev/null || true)"
fi
if [[ -z "${testlogs}" || ! -d "${testlogs}" ]]; then
  echo "ERROR: could not locate bazel-testlogs; was 'bazel coverage' run?" >&2
  exit 1
fi

reports=()
populated=0
while IFS= read -r report; do
  reports+=("${report}")
  if [[ -s "${report}" ]]; then
    populated=$((populated + 1))
  fi
done < <(find -L "${testlogs}" -name coverage.dat -type f)

covered="$(mktemp)"
covered_paths="$(mktemp)"
trap 'rm -f "${covered}" "${covered_paths}"' EXIT

# One pass over every report, emitting "<executed lines>\t<source path>" for
# each source that ended up with a non-zero hit count. Accumulating per SF:
# block is what distinguishes "this file has coverage data" from "this file was
# merely listed in the report".
if [[ "${#reports[@]}" -gt 0 ]]; then
  awk '
    /^SF:/ { sf = substr($0, 4); next }
    /^DA:/ {
      split(substr($0, 4), record, ",")
      if (sf != "" && record[2] + 0 > 0) { hits[sf]++ }
      next
    }
    /^end_of_record/ { sf = ""; next }
    END { for (s in hits) { print hits[s] "\t" s } }
  ' "${reports[@]}" | sort -k2 >"${covered}"
fi
cut -f2 "${covered}" >"${covered_paths}"

covered_files="$(wc -l <"${covered}" | tr -d '[:space:]')"
covered_lines="$(awk -F'\t' '{ total += $1 } END { print total + 0 }' "${covered}")"

echo "Coverage reports found:      ${#reports[@]}"
echo "Reports with content:        ${populated}"
echo "Source files with hit lines: ${covered_files}"
echo "Executed lines recorded:     ${covered_lines}"
awk -F'\t' '{ printf "  %6d hit lines  %s\n", $1, $2 }' "${covered}"

if [[ "${report_only}" == "true" ]]; then
  exit 0
fi

status=0

if [[ "${covered_files}" -eq 0 ]]; then
  echo >&2
  echo "ERROR: no source file came back with executed lines. Coverage" >&2
  echo "       collection is broken -- see //cc/private/coverage." >&2
  status=1
fi

for want in ${expected[@]+"${expected[@]}"}; do
  if ! grep -Fq -- "${want}" "${covered_paths}"; then
    echo >&2
    echo "ERROR: no executed lines recorded for a source file matching" >&2
    echo "       '${want}'. Either coverage collection regressed, or the test" >&2
    echo "       that exercises it no longer runs on this platform. The" >&2
    echo "       expected paths are listed in .bazelci/presubmit.yml." >&2
    status=1
  fi
done

exit "${status}"
