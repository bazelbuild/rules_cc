#!/usr/bin/env bash
set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function test_windows_linker_param_files_with_spaces() {
  if ! is_windows; then
    return
  fi

  cat > BUILD <<'EOF'
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "library with spaces",
    srcs = ["source with spaces.cc"],
)

cc_binary(
    name = "binary with spaces",
    srcs = ["main.cc"],
    deps = [":library with spaces"],
)

cc_binary(
    name = "shared library with spaces",
    srcs = ["source with spaces.cc"],
    linkshared = True,
)
EOF

  cat > 'source with spaces.cc' <<'EOF'
__declspec(dllexport) int value() { return 42; }
EOF
  cat > main.cc <<'EOF'
int value();
int main() { return value() == 42 ? 0 : 1; }
EOF

  # Exercise both archiving and linking, with spaces in input and output paths.
  # C++ compilation uses its own response-file quoting; keep this test focused
  # on the linker's response files.
  bazel build --features=-compiler_param_file --min_param_file_size=0 \
    ':library with spaces' ':binary with spaces' ':shared library with spaces' \
    >& "$TEST_log" || fail "Build with spaces in response files failed"
  'bazel-bin/binary with spaces.exe' >> "$TEST_log" || fail "Binary failed"
}

run_suite "Integration tests for C++ linking"
