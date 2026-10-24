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

collector="$1"
coverage_dir="$TEST_TMPDIR/coverage"
root="$TEST_TMPDIR/root"
manifest="$TEST_TMPDIR/manifest"
failing_tool="$TEST_TMPDIR/failing_tool"
mkdir -p "$coverage_dir" "$root"
: > "$manifest"

cat > "$failing_tool" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "gcov (GCC) 8.0.0"
  exit 0
fi
echo "fake coverage tool failed: $1" >&2
exit 1
EOF
chmod +x "$failing_tool"

assert_collection_fails() {
  local expected="$1"
  shift
  local output
  if output="$(env COVERAGE_DIR="$coverage_dir" COVERAGE_MANIFEST="$manifest" \
      "$@" "$collector" 2>&1)"; then
    echo "Expected coverage collection to fail after $expected failed" >&2
    exit 1
  fi
  if [[ "$output" != *"fake coverage tool failed: $expected"* ]]; then
    echo "Expected $expected failure, got: $output" >&2
    exit 1
  fi
}

touch "$coverage_dir/test.profraw"
assert_collection_fails merge \
    GENERATE_LLVM_LCOV=1 LLVM_PROFDATA="$failing_tool" LLVM_COV=true
assert_collection_fails export \
    GENERATE_LLVM_LCOV=1 LLVM_PROFDATA=true LLVM_COV="$failing_tool"

rm "$coverage_dir/test.profraw"
echo test.gcno > "$manifest"
touch "$root/test.gcno" "$coverage_dir/test.gcda"
assert_collection_fails -i \
    BAZEL_CC_COVERAGE_TOOL=GCOV COVERAGE_GCOV_PATH="$failing_tool" ROOT="$root"
if [[ -L "$coverage_dir/gcov" ]]; then
  echo "The temporary gcov symlink was not removed after failure" >&2
  exit 1
fi
