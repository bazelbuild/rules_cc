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

function test_incremental_link_with_linkstamp_header() {
  mkdir -p foo
  cat > foo/BUILD <<'EOF'
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
cc_library(name = "lib",
           linkstamp = "linkstampfile.cc",
           srcs = ["lib.cc"],
           hdrs = ["other.h"])
cc_binary(name = "foo",
          deps = [":lib"],
          srcs = ["foo.cc"])
EOF
  cat > foo/foo.cc << EOF
int main() {
  return 0;
}
EOF
  touch foo/lib.cc
  cat > foo/linkstampfile.cc << EOF
#include "foo/other.h"
EOF
  touch foo/other.h

  bazel build --experimental_ui_debug_all_events --stamp //foo:foo \
      >& "${TEST_log}" || fail "Build failed"
  expect_log "Linking foo/foo"
  bazel build --experimental_ui_debug_all_events --stamp //foo:foo \
      >& "${TEST_log}" || fail "Build failed"
  expect_not_log "Linking"
  echo "int new_int = 0;" > foo/other.h
  bazel build --experimental_ui_debug_all_events --stamp //foo:foo >& "${TEST_log}" \
      || fail "Build failed"
  expect_log "Linking foo/foo"
}

function test_shutdowns_dont_trigger_linkstamp_recompilation() {
  mkdir -p foo
  cat > foo/BUILD << EOF
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
cc_library(name = "lib",
           linkstamp = "linkstampfile.cc",
           srcs = ["lib.cc"],
           hdrs = ["other.h"])
cc_binary(name = "foo",
          deps = [":lib"],
          srcs = ["foo.cc"])
EOF
  cat > foo/foo.cc << EOF
int main() {
  return 0;
}
EOF
  touch foo/lib.cc
  cat > foo/linkstampfile.cc << EOF
#include "foo/other.h"
EOF
  touch foo/other.h

  bazel build --experimental_ui_debug_all_events --nostamp //foo:foo \
      >& "${TEST_log}" || fail "Build failed"
  expect_log "Compiling foo/linkstampfile.cc"

  bazel shutdown >& "${TEST_log}" || fail "Shutdown failed"
  bazel build --experimental_ui_debug_all_events --nostamp //foo:foo \
      >& "${TEST_log}" || fail "Build failed"
  expect_not_log "Compiling foo/linkstampfile.cc"
}

function test_cc_rule_api_with_aspect() {
  mkdir -p foo
  cat > foo/extension.bzl << EOF
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
def _cc_aspect_impl(target, ctx):
    toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    (compilation_context, compilation_outputs) = cc_common.compile(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = toolchain,
        name = ctx.label.name + "_aspect",
        srcs = ctx.rule.files.srcs,
        public_hdrs = ctx.rule.files.hdrs,
    )
    (linking_context, linking_outputs) = (
      cc_common.create_linking_context_from_compilation_outputs(
          actions = ctx.actions,
          feature_configuration = feature_configuration,
          name = ctx.label.name + "_aspect",
          cc_toolchain = toolchain,
          compilation_outputs = compilation_outputs,
      )
    )
    return []
_cc_aspect = aspect(
    implementation = _cc_aspect_impl,
    fragments = ["google_cpp", "cpp"],
    toolchains = use_cc_toolchain(),
)
def _cc_skylark_library_impl(ctx):
    dep_linking_contexts = []
    dep_compilation_contexts = []
    for dep in ctx.attr.deps:
        dep_linking_contexts.append(dep[CcInfo].linking_context)
        dep_compilation_contexts.append(dep[CcInfo].compilation_context)
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain=cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features)
    (compilation_context, compilation_outputs) = cc_common.compile(
        actions=ctx.actions,
        cc_toolchain=cc_toolchain,
        feature_configuration=feature_configuration,
        srcs=ctx.files.srcs,
        public_hdrs=ctx.files.hdrs,
        compilation_contexts = dep_compilation_contexts,
        name = ctx.label.name)
    (linking_context,
     linking_outputs) = (
       cc_common.create_linking_context_from_compilation_outputs(
          actions=ctx.actions,
          cc_toolchain=cc_toolchain,
          feature_configuration=feature_configuration,
          linking_contexts = dep_linking_contexts,
          name = ctx.label.name,
          compilation_outputs=compilation_outputs)
     )
    return [CcInfo(
              compilation_context=compilation_context,
              linking_context=linking_context)]
cc_skylark_library = rule(
    implementation = _cc_skylark_library_impl,
    attrs = {
      "srcs": attr.label_list(allow_files=True),
      "hdrs": attr.label_list(allow_files=True),
      "deps": attr.label_list(),
      "aspect_deps": attr.label_list(aspects=[_cc_aspect]),
    },
    fragments = ["google_cpp", "cpp"],
    toolchains = use_cc_toolchain(),
)
EOF
  cat > foo/BUILD << EOF
load(":extension.bzl", "cc_skylark_library")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
cc_skylark_library(
    name = "skylark_lib_aspect",
    srcs = ["skylark_lib.cc"],
    hdrs = ["skylark_lib.h"],
)

cc_skylark_library(
    name = "skylark_lib",
    srcs = ["skylark_lib.cc"],
    hdrs = ["skylark_lib.h"],
    deps = ["skylark_lib_aspect"],
    aspect_deps = ["skylark_lib_aspect"],
)

cc_binary(
    name = "bin",
    srcs = ["bin.cc"],
    deps = ["skylark_lib"],
)
EOF
  cat > foo/skylark_lib.cc << EOF
#include "foo/skylark_lib.h"

int skylark_lib() {
  return 42;
}
EOF
  echo "int skylark_lib();" > foo/skylark_lib.h
  cat > foo/bin.cc << EOF
#include "foo/skylark_lib.h"

int main(void) {
  return skylark_lib();
}
EOF

  bazel build //foo:bin || fail "Build failed"

  # Binary should output value from library (42).
  local exit_code=0
  bazel-bin/foo/bin || exit_code=$?
  assert_equals 42 "${exit_code}"
}

function test_cc_rule_cc_with_tree_artifacts() {
  if is_darwin; then
    # The default linker on Mac does not support --start-lib --end-lib which this test requires
    echo "Skipping incompatible test on Mac"
    return 0;
  fi
  mkdir -p foo
  cat > foo/extension.bzl << EOF
def _cc_tree_artifact_files_impl(ctx):
    directory = ctx.actions.declare_directory(ctx.attr.name + "_artifact.cc")
    ctx.actions.run_shell(
      inputs = ctx.files.srcs,
      outputs = [directory],
      mnemonic = "MoveTreeArtifact",
      use_default_shell_env = True,
      command = "mkdir -p %s; cp %s %s %s; ls %s" %
          (directory.path,
          ctx.files.srcs[0].path,
          ctx.files.srcs[1].path,
          directory.path,
          directory.path),
    )
    return [DefaultInfo(files = depset([directory]))]

cc_tree_artifact_files = rule(
    implementation = _cc_tree_artifact_files_impl,
    attrs = {
      "srcs": attr.label_list(allow_files=True),
    },
)
EOF
  cat > foo/BUILD << EOF
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load(":extension.bzl", "cc_tree_artifact_files")
cc_tree_artifact_files(
    name = "tree_artifact",
    srcs = ["skylark_lib1.cc", "skylark_lib2.cc"],
)

cc_binary(
    name = "bin",
    srcs = ["skylark_lib.h", "bin.cc", ":tree_artifact"],
)
EOF
  cat > foo/skylark_lib1.cc << EOF
int skylark_lib1() {
  return 42;
}
EOF
cat > foo/skylark_lib2.cc << EOF
int skylark_lib2() {
  return 43;
}
EOF
cat > foo/skylark_lib.h << EOF
int skylark_lib1();
int skylark_lib2();
EOF
  cat > foo/bin.cc << EOF
#include "foo/skylark_lib.h"

int main(void) {
  return skylark_lib1() + skylark_lib2();
}
EOF

  bazel build //foo:bin >& "${TEST_log}" || fail "Build failed"

  # Binary should output value from library.
  local exit_code=$?
  bazel-bin/foo/bin || exit_code=$?
  assert_equals 85 "${exit_code}"
}

run_suite "Integration tests for rules_cc"
