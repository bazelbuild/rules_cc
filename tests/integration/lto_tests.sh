set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

LTO_TESTS_ENABLED=1

function set_up() {
  if is_bazel; then
    local -r clang="$(which clang || true)"
    if [[ ! -x "$clang" ]]; then
      echo "clang not installed. Skipping test."
      LTO_TESTS_ENABLED=0
      return
    fi
    if ! linker_supports_start_end_lib "$clang"; then
      echo "Linker does not support --start-lib/--end-lib. Skipping test."
      LTO_TESTS_ENABLED=0
      return
    fi
    add_to_bazelrc "common --repo_env=CC=$clang"
  else
    add_to_bazelrc "common --compiler=llvm"
  fi
}

function test_thin_lto() {
  [[ "$LTO_TESTS_ENABLED" == 1 ]] || return 0
  mkdir -p hello
  cat > hello/BUILD << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(name = "hello",
  srcs = ["hello1.cc", "hello2.cc", "hello.h"],
)
EOF
  cat > hello/hello.h << EOF
#include <string>
using namespace std;
string x = "Hello World!";
EOF
  cat > hello/hello1.cc << EOF
extern void foo();
int main() {
  foo();
}
EOF
  cat > hello/hello2.cc << EOF
#include <iostream>
#include "hello/hello.h"
void foo() {
  cout << x << endl;
}
EOF

  bazel build \
      --experimental_ui_debug_all_events \
      -c opt \
      --features=thin_lto \
      --features=nonhost \
      hello:hello >& "${TEST_log}" || fail "Build failed"

  expect_log "LTO indexing hello/hello"
  expect_log "Linking hello/hello"
}

function test_thin_lto_only_dep_has_source() {
  [[ "$LTO_TESTS_ENABLED" == 1 ]] || return 0
  mkdir -p hello
  cat > hello/BUILD << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_binary(name = "dep_has_source.so",
  deps = [":foo.so"],
  linkshared = 1,
)
cc_library(name = "foo.so",
  srcs = ["foo.cc"],
)
EOF
  touch hello/foo.cc

  bazel build \
      --experimental_ui_debug_all_events \
      -c opt \
      --features=thin_lto \
      --features=nonhost \
      hello:dep_has_source.so >& "${TEST_log}" || fail "Build failed"
  expect_log "LTO indexing hello/dep_has_source.so"
  expect_log "Linking hello/dep_has_source.so"
}

run_suite "Integration tests for LTO with rules_cc"
