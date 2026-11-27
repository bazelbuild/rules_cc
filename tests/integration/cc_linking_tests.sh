#!/usr/bin/env bash
set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function test_linker_param_files_with_spaces() {
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
#ifdef _WIN32
__declspec(dllexport)
#endif
int value() { return 42; }
EOF
  cat > main.cc <<'EOF'
int value();
int main() { return value() == 42 ? 0 : 1; }
EOF

  # TODO: compiler_param_file is broken with spaces on Windows
  bazel build --features=-compiler_param_file --min_param_file_size=0 \
    ':library with spaces' ':binary with spaces' ':shared library with spaces' \
    >& "$TEST_log" || fail "Build with spaces in response files failed"
  local binary='bazel-bin/binary with spaces'
  if is_windows; then
    binary+='.exe'
  fi
  "$binary" >> "$TEST_log" || fail "Binary failed"
}

function test_cc_static_library_path_mapping() {
  # Linux toolchains enable archive_param_file by default.
  is_linux || return 0

  mkdir -p path_mapping
  cat > path_mapping/BUILD <<'EOF'
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")

cc_library(
    name = "input",
    srcs = ["input.cc"],
)

cc_static_library(
    name = "archive",
    deps = [":input"],
)
EOF
  echo 'int value() { return 42; }' > path_mapping/input.cc

  bazel build //path_mapping:archive \
    --spawn_strategy=sandboxed \
    --experimental_output_paths=strip \
    --modify_execution_info='^CppTransitiveArchive$=+supports-path-mapping' \
    --materialize_param_files \
    >& "$TEST_log" || fail "Build with archive path mapping failed"
  grep -Fxq 'bazel-out/cfg/bin/path_mapping/libarchive.a' bazel-bin/path_mapping/libarchive.a-0.params \
    || fail "Mapped archive output path is missing from the response file"
}

run_suite "Integration tests for C++ linking"
