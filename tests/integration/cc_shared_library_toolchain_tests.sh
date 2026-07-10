set -euo pipefail

source "$(rlocation rules_cc/tests/test_utils.sh)"
source "$(rlocation rules_cc/tests/unittest.bash)"

# Verify that cc_shared_library doesn't cause runtime libraries linked from
# toolchains to be pruned from the final binary.
function setup_tests() {
  mkdir -p foo

  cat > foo/shared_lib.cc << EOF
#include "runtime_lib.h"
void shared_lib() { runtime_lib(); }
EOF
  cat > foo/shared_lib.h << EOF
void shared_lib();
EOF

  cat > foo/runtime_lib.cc << EOF
#include <cstdio>
void runtime_lib() { printf("calling runtime_lib"); }
EOF

  cat > foo/runtime_lib.h << EOF
void runtime_lib();
EOF

cat > foo/main_direct.cc << EOF
#include "runtime_lib.h"
int main() { runtime_lib(); return 0; }
EOF

cat > foo/main_indirect.cc << EOF
#include "shared_lib.h"
int main() { shared_lib(); return 0; }
EOF

cat > foo/misc.cc << EOF
void misc() { }
EOF

  cat > foo/toolchain.bzl << EOF
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")


def _runtimes_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(info = SampleToolchainInfo(runtime = ctx.attr.runtime_lib))]

SampleToolchainInfo = provider(
    doc = "Provides a runtime.",
    fields = {
        "runtime": "The runtime.",
    },
)

runtimes_toolchain = rule(
    implementation = _runtimes_toolchain_impl,
    attrs = {
        "runtime_lib": attr.label(default = ":runtime_lib"),
    },
    provides = [platform_common.ToolchainInfo],
)

def _toolchain_using_rule_impl(ctx):
    runtime = ctx.toolchains["//foo:toolchain_type"].info.runtime
    return [runtime[CcInfo], runtime[DefaultInfo]]

toolchain_using_rule = rule(
    implementation = _toolchain_using_rule_impl,
    provides = [CcInfo],
    toolchains = ["//foo:toolchain_type"],
    attrs = {
        "deps": attr.label_list(default = []),
    },
)

EOF

  cat > foo/BUILD << EOF
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("//foo:toolchain.bzl", "runtimes_toolchain", "toolchain_using_rule")

cc_library(
    name = "runtime_lib",
    srcs = ["runtime_lib.cc"],
    hdrs = ["runtime_lib.h"],
)

runtimes_toolchain(
    name = "runtimes_toolchain",
    runtime_lib = ":runtime_lib",
)

toolchain_type(name = "toolchain_type")
toolchain(
    name = "toolchain",
    toolchain = ":runtimes_toolchain",
    toolchain_type = "toolchain_type",
)

toolchain_using_rule(
    name = "toolchain_using_rule",
)

cc_library(
    name = "shared_lib_base",
    alwayslink = True,
)

cc_shared_library(
    name = "shared_lib",
    deps = [":shared_lib_base"],
)

cc_binary(
    name = "static_dependency",
    srcs = ["main_direct.cc", "runtime_lib.h"],
    deps = [":toolchain_using_rule"],
    dynamic_deps = [":shared_lib"],
)

cc_library(
    name = "shared_lib_with_runtime_deps_base",
    srcs = ["shared_lib.cc"],
    hdrs = ["shared_lib.h", "runtime_lib.h"],
    alwayslink = True,
    deps = [":toolchain_using_rule"],
)

cc_shared_library(
    name = "shared_with_runtime_deps",
    deps = [":shared_lib_with_runtime_deps_base"],
)

cc_library(
    name = "misc",
    srcs = ["misc.cc"],
    alwayslink = True,
)

cc_library(
    name = "shared_lib_with_runtime_deps_toolchainless_base",
    srcs = ["shared_lib.cc"],
    hdrs = ["shared_lib.h"],
    deps = [":runtime_lib"],
    alwayslink = True,
)

cc_shared_library(
    name = "shared_with_runtime_deps_toolchainless",
    deps = [":shared_lib_with_runtime_deps_toolchainless_base"],
)

cc_binary(
    name = "dynamic_dependency",
    srcs = ["main_indirect.cc", "shared_lib.h"],
    dynamic_deps = [":shared_with_runtime_deps_toolchainless"],
)

cc_binary(
    name = "dynamic_dependency_toolchain",
    srcs = ["main_indirect.cc", "shared_lib.h"],
    deps = [":misc"],
    dynamic_deps = [":shared_with_runtime_deps"],
)


EOF
}

# Test basic usage of cc_shared_library.
#
# :dynamic_dependency depends on a shared library that depends
# on :runtime_lib, and calls the shared_lib which calls runtime_lib.
function test_dynamic_dependency() {
setup_tests

bazel run \
    //foo:dynamic_dependency >& "${TEST_log}" || fail "Expected build to succeed"

expect_log "calling runtime_lib"
}

# Test cc_shared_library with a toolchain.
#
# :dynamic_dependency_toolchain depends on a shared library that depends on
# :toolchain_using_rule, and calls shared_lib which calls runtime_lib.
function test_dynamic_dependency_toolchain() {
setup_tests

bazel build \
    //foo:dynamic_dependency_toolchain >& "${TEST_log}" && fail "Expected build to fail without toolchain"

bazel run \
    --extra_toolchains=//foo:toolchain \
    //foo:dynamic_dependency_toolchain >& "${TEST_log}" || fail "Expected build to succeed"

expect_log "calling runtime_lib"
}


# Test cc_shared_libary side-effects.
#
# :static_dependency directly depends on :toolchain_using_rule, and calls runtime_lib
# A dynamic library is present, triggering cc_shared_library pruning.
function test_direct_dependency() {
setup_tests

bazel build \
    //foo:static_dependency >& "${TEST_log}" && fail "Expected build to fail without toolchain"

bazel run \
    --extra_toolchains=//foo:toolchain \
    //foo:static_dependency >& "${TEST_log}" || fail "Expected build to succeed"

expect_log "calling runtime_lib"
}



run_suite "Integration tests for cc_shared_library"
