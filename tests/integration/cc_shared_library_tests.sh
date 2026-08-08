set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

function test_cc_shared_library_doesnt_link_libs_unnecessarily() {
  mkdir -p foo/bar

  cat > foo/baz.cc << EOF
#include "foo/baz.h"
int baz() { return 0; }
EOF
  cat > foo/baz.h << EOF
int baz();
EOF
  cat > foo/foo2.cc << EOF
#include "foo/foo2.h"

int foo2() { return 0; }
EOF
  cat > foo/foo2.h << EOF
int foo2();
EOF
  cat > foo/foo.cc << EOF
#include "foo/bar/bar.h"
// Included but symbol not used.
#include "foo/baz.h"
#include "foo/foo2.h"

int foo() { return foo2() + bar() + 0; }
EOF
  cat > foo/BUILD << EOF
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
cc_library(
    name = "foo2",
    srcs = ["foo2.cc"],
    hdrs = ["foo2.h"],
)
cc_library(
    name = "foo",
    srcs = ["foo.cc",],
    deps = [
        ":baz",
        ":foo2",
        "//foo/bar",
    ],
)
cc_library(
    name = "baz",
    srcs = ["baz.cc",],
    hdrs = ["baz.h",],
)
cc_shared_library(
    name = "foo_shared",
    dynamic_deps = [
        "//foo/bar:bar_shared",
    ],
    deps = [
        ":foo",
    ],
)
EOF
  cat > foo/bar/bar2.cc << EOF
#include "foo/bar/bar2.h"
int bar2() { return 0; }
EOF
  echo "int bar2();" > foo/bar/bar2.h
  cat > foo/bar/bar.cc << EOF
#include "foo/bar/bar.h"

#include "foo/bar/bar2.h"

int bar() { return bar2() + 0; }
EOF
  echo "int bar();" > foo/bar/bar.h
  cat > foo/bar/BUILD << EOF
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
package(
    default_visibility = [
        "//visibility:public",
    ],
)
cc_library(
    name = "bar2",
    srcs = ["bar2.cc"],
    hdrs = ["bar2.h"],
)
cc_library(
    name = "bar",
    srcs = ["bar.cc"],
    hdrs = ["bar.h"],
    deps = [":bar2"],
)
cc_shared_library(
    name = "bar_shared",
    deps = [":bar"],
)
EOF

  bazel build \
    --experimental_cc_shared_library \
    //foo:foo_shared >& "${TEST_log}" || fail "Expected build to succeed"

  so_file="bazel-bin/foo/libfoo_shared.so"

  nm -D "$so_file" | grep -q "T _Z3foov" || fail "_Z3foov not linked statically"
  nm -D "$so_file" | grep -q "T _Z4foo2v" || fail "_Z4foo2v not linked statically"
  nm -D "$so_file" | grep -q "U _Z3barv" || fail "_Z3barv not linked dynamically"
  nm -D "$so_file" | grep -q "baz" && fail "baz shoulod not be linked in anyway"
  nm -D "$so_file" | grep -q "bar2" && fail "bar2 shoulod not be linked in anyway"

  return 0
}

run_suite "Integration tests for cc_shared_library"
