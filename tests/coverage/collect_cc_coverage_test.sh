#!/usr/bin/env bash
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

set -euo pipefail

readonly SCRIPT="${TEST_SRCDIR}/${TEST_WORKSPACE}/cc/coverage/collect_cc_coverage.sh"
readonly WORK_DIR="$(mktemp -d "${TEST_TMPDIR:-/tmp}/cc-coverage-args.XXXXXXXX")"
trap 'rm -rf "${WORK_DIR}"' EXIT

mkdir -p "${WORK_DIR}/coverage" "${WORK_DIR}/object files"
readonly OBJECT_WITH_SPACE="${WORK_DIR}/object files/runtime.o"
readonly SECOND_OBJECT="${WORK_DIR}/second.o"
touch "${WORK_DIR}/coverage/coverage.profraw" "${OBJECT_WITH_SPACE}" "${SECOND_OBJECT}"
printf '%s\n' "${OBJECT_WITH_SPACE}" "${SECOND_OBJECT}" > "${WORK_DIR}/runtime_objects_list.txt"
printf '%s\n' "${WORK_DIR}/runtime_objects_list.txt" > "${WORK_DIR}/manifest.txt"

cat > "${WORK_DIR}/llvm-profdata" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$#" -eq 4 && "$1" == merge && "$2" == -output ]]
touch "$3"
EOF

cat > "${WORK_DIR}/llvm-cov" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${LLVM_COV_ARGS}"
printf 'TN:\n'
EOF
chmod +x "${WORK_DIR}/llvm-profdata" "${WORK_DIR}/llvm-cov"

COVERAGE_DIR="${WORK_DIR}/coverage" \
COVERAGE_MANIFEST="${WORK_DIR}/manifest.txt" \
GENERATE_LLVM_LCOV=1 \
LLVM_PROFDATA="${WORK_DIR}/llvm-profdata" \
LLVM_COV="${WORK_DIR}/llvm-cov" \
LLVM_COV_ARGS="${WORK_DIR}/llvm-cov.args" \
  bash "${SCRIPT}"

printf '%s\n' \
  export \
  -instr-profile "${WORK_DIR}/coverage/_cc_coverage.dat.data" \
  -format=lcov \
  '-ignore-filename-regex=^/tmp/.+' \
  -object "${OBJECT_WITH_SPACE}" \
  -object "${SECOND_OBJECT}" > "${WORK_DIR}/expected.args"
diff -u "${WORK_DIR}/expected.args" "${WORK_DIR}/llvm-cov.args"
