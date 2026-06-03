set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function test_simple_compile() {
  cat > "BUILD" << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(
  name = "hello",
  srcs = ["hello.cc"],
)
EOF

  cat > "hello.cc" << EOF
#include <stdio.h>

int main() { printf("Hit me baby one more time!\n"); }
EOF

  bazel build //:hello >& "$TEST_log" || fail "Build failed"
  bazel-bin/hello >> "$TEST_log"
  expect_log "Hit me baby one more time!"
}

function test_simple_compile_stripped() {
  cat > "BUILD" << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(
  name = "hello",
  srcs = ["hello.cc"],
)
EOF

  cat > "hello.cc" << EOF
#include <stdio.h>

int main() { printf("Oops! I did it again!\n"); }
EOF

  bazel build //:hello.stripped >& "$TEST_log" || fail "Build failed"
  bazel-bin/hello.stripped >> "$TEST_log"
  expect_log "Oops! I did it again!"
}

function test_compiling_with_source_files_with_same_basename() {
  cat > BUILD << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(
  name = "hello",
  srcs = [
    "hello.cc",
    "hello.h",
    "lib/hello.cc",
  ],
)
EOF

    cat > hello.cc << EOF
#include "hello.h"
int main() {
    printf("This is a story about a girl named Lucky.\n");
}
EOF
    cat > hello.h << EOF
#include <stdio.h>
EOF
    mkdir -p lib
    cat > lib/hello.cc << EOF
void dummy() {}
EOF

  bazel build :hello >& "${TEST_log}" || fail "Build failed"
  bazel-bin/hello >> "${TEST_log}"
  expect_log "This is a story about a girl named Lucky."

  find_out="find_out.dat"
  find -L bazel-bin/_objs/hello -type f | tee "${find_out}" >> "${TEST_log}" || fail "Expected success"
  # pipe through awk to get rid of leading spaces on Mac OS
  assert_equals "4" "$(wc -l < "${find_out}" | awk '{print $1}')"
  if is_windows; then
    expect_log "bazel-bin/_objs/hello/0/hello.obj"
    expect_log "bazel-bin/_objs/hello/0/hello.obj.params"
    expect_log "bazel-bin/_objs/hello/1/hello.obj"
    expect_log "bazel-bin/_objs/hello/1/hello.obj.params"

  else
    expect_log "bazel-bin/_objs/hello/0/hello\(.pic\)*.o"
    expect_log "bazel-bin/_objs/hello/0/hello\(.pic\)*.d"
    expect_log "bazel-bin/_objs/hello/1/hello\(.pic\)*.o"
    expect_log "bazel-bin/_objs/hello/1/hello\(.pic\)*.d"
  fi
}

function test_conflict_between_binary_and_so() {
  cat > BUILD << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
cc_binary(name="clang", srcs=["clang.cc"])
cc_binary(name="libclang.so", linkshared=1)
EOF
  echo "int main() {}" > clang.cc
  bazel build //:clang //:libclang.so >& "${TEST_log}" || fail "Build failed"
}

run_suite "Integration tests for rules_cc"
